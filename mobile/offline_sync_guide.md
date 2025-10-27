# モバイルオフライン同期 完全ガイド

## 目次
1. [オフライン同期とは](#オフライン同期とは)
2. [ローカルストレージ](#ローカルストレージ)
3. [データ同期戦略](#データ同期戦略)
4. [競合解決](#競合解決)
5. [ネットワーク監視](#ネットワーク監視)
6. [キューイング](#キューイング)
7. [実装例](#実装例)
8. [ベストプラクティス](#ベストプラクティス)

---

## オフライン同期とは

オフライン同期は、ネットワーク接続がない状態でもアプリが動作し、オンライン復帰時にサーバーとデータを同期する技術です。

### 主な課題

- **データの一貫性**: オフライン中の変更を管理
- **競合解決**: 同じデータへの同時編集
- **パフォーマンス**: 大量データの同期
- **ストレージ制限**: モバイルデバイスの容量制限

---

## ローカルストレージ

### WatermelonDB

```bash
npm install @nozbe/watermelondb @nozbe/with-observables
```

```typescript
import { Database } from '@nozbe/watermelondb';
import SQLiteAdapter from '@nozbe/watermelondb/adapters/sqlite';
import { Model, Q } from '@nozbe/watermelondb';
import { field, date, readonly } from '@nozbe/watermelondb/decorators';

// スキーマ定義
const schema = {
  version: 1,
  tables: [
    {
      name: 'posts',
      columns: [
        { name: 'title', type: 'string' },
        { name: 'body', type: 'string' },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
        { name: 'synced_at', type: 'number', isOptional: true },
      ],
    },
  ],
};

// モデル定義
class Post extends Model {
  static table = 'posts';

  @field('title') title!: string;
  @field('body') body!: string;
  @readonly @date('created_at') createdAt!: Date;
  @readonly @date('updated_at') updatedAt!: Date;
  @date('synced_at') syncedAt?: Date;
}

// データベース初期化
const adapter = new SQLiteAdapter({
  schema,
});

export const database = new Database({
  adapter,
  modelClasses: [Post],
});
```

### CRUD操作

```typescript
import { database } from './database';

// 作成
async function createPost(title: string, body: string) {
  await database.write(async () => {
    await database.collections.get('posts').create((post) => {
      post.title = title;
      post.body = body;
    });
  });
}

// 読み取り
async function getPosts() {
  return await database.collections.get('posts').query().fetch();
}

// 更新
async function updatePost(postId: string, title: string) {
  const post = await database.collections.get('posts').find(postId);

  await database.write(async () => {
    await post.update((post) => {
      post.title = title;
    });
  });
}

// 削除
async function deletePost(postId: string) {
  const post = await database.collections.get('posts').find(postId);

  await database.write(async () => {
    await post.destroyPermanently();
  });
}
```

### React統合

```typescript
import { withObservables } from '@nozbe/with-observables';
import { database } from './database';

function PostList({ posts }: { posts: Post[] }) {
  return (
    <FlatList
      data={posts}
      renderItem={({ item }) => (
        <View>
          <Text>{item.title}</Text>
          <Text>{item.body}</Text>
        </View>
      )}
    />
  );
}

const enhance = withObservables([], () => ({
  posts: database.collections.get('posts').query().observe(),
}));

export default enhance(PostList);
```

---

## データ同期戦略

### Last-Write-Wins

```typescript
interface SyncableItem {
  id: string;
  updatedAt: number;
  data: any;
}

async function syncWithLastWriteWins(localItem: SyncableItem, serverItem: SyncableItem) {
  if (localItem.updatedAt > serverItem.updatedAt) {
    // ローカルが新しい → サーバーに送信
    await uploadToServer(localItem);
  } else if (serverItem.updatedAt > localItem.updatedAt) {
    // サーバーが新しい → ローカルに保存
    await saveToLocal(serverItem);
  }
  // 同じタイムスタンプの場合は何もしない
}
```

### Operation-Based CRDT

```typescript
interface Operation {
  id: string;
  type: 'create' | 'update' | 'delete';
  timestamp: number;
  data: any;
}

class OperationQueue {
  private operations: Operation[] = [];

  add(operation: Operation) {
    this.operations.push(operation);
    this.operations.sort((a, b) => a.timestamp - b.timestamp);
  }

  async sync() {
    for (const operation of this.operations) {
      await this.applyOperation(operation);
    }
    this.operations = [];
  }

  private async applyOperation(operation: Operation) {
    switch (operation.type) {
      case 'create':
        await createLocal(operation.data);
        break;
      case 'update':
        await updateLocal(operation.id, operation.data);
        break;
      case 'delete':
        await deleteLocal(operation.id);
        break;
    }
  }
}
```

### Delta Sync

```typescript
interface SyncResult {
  lastSyncedAt: number;
  changes: {
    created: any[];
    updated: any[];
    deleted: string[];
  };
}

async function deltaSync(lastSyncedAt: number): Promise<SyncResult> {
  // サーバーから差分取得
  const serverChanges = await fetchChanges(lastSyncedAt);

  // ローカル変更を取得
  const localChanges = await database.collections
    .get('posts')
    .query(Q.where('updated_at', Q.gt(lastSyncedAt)))
    .fetch();

  // ローカルにサーバー変更を適用
  await applyServerChanges(serverChanges);

  // サーバーにローカル変更を送信
  await uploadLocalChanges(localChanges);

  return {
    lastSyncedAt: Date.now(),
    changes: serverChanges,
  };
}
```

---

## 競合解決

### 3-Way Merge

```typescript
interface MergeResult<T> {
  resolved: T;
  conflicts: Array<{
    field: keyof T;
    local: any;
    server: any;
    base: any;
  }>;
}

function threeWayMerge<T extends Record<string, any>>(
  base: T,
  local: T,
  server: T
): MergeResult<T> {
  const resolved: any = { ...base };
  const conflicts: any[] = [];

  for (const key in base) {
    const baseValue = base[key];
    const localValue = local[key];
    const serverValue = server[key];

    if (localValue === serverValue) {
      // 変更なし、またはどちらも同じ変更
      resolved[key] = localValue;
    } else if (localValue === baseValue) {
      // ローカルで変更なし → サーバーの変更を採用
      resolved[key] = serverValue;
    } else if (serverValue === baseValue) {
      // サーバーで変更なし → ローカルの変更を採用
      resolved[key] = localValue;
    } else {
      // 競合
      conflicts.push({
        field: key,
        local: localValue,
        server: serverValue,
        base: baseValue,
      });

      // デフォルトはサーバーの値を採用
      resolved[key] = serverValue;
    }
  }

  return { resolved, conflicts };
}
```

### 手動競合解決UI

```typescript
function ConflictResolver({ conflicts, onResolve }: {
  conflicts: Array<{ field: string; local: any; server: any }>;
  onResolve: (resolutions: Record<string, any>) => void;
}) {
  const [resolutions, setResolutions] = useState<Record<string, any>>({});

  return (
    <View>
      <Text>競合が発生しました</Text>

      {conflicts.map((conflict) => (
        <View key={conflict.field}>
          <Text>{conflict.field}</Text>

          <TouchableOpacity
            onPress={() =>
              setResolutions({ ...resolutions, [conflict.field]: conflict.local })
            }
          >
            <Text>ローカル: {conflict.local}</Text>
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() =>
              setResolutions({ ...resolutions, [conflict.field]: conflict.server })
            }
          >
            <Text>サーバー: {conflict.server}</Text>
          </TouchableOpacity>
        </View>
      ))}

      <Button title="解決" onPress={() => onResolve(resolutions)} />
    </View>
  );
}
```

---

## ネットワーク監視

### NetInfo

```bash
npx expo install @react-native-community/netinfo
```

```typescript
import NetInfo from '@react-native-community/netinfo';
import { useEffect, useState } from 'react';

export function useNetworkStatus() {
  const [isConnected, setIsConnected] = useState<boolean>(true);
  const [isInternetReachable, setIsInternetReachable] = useState<boolean>(true);

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener((state) => {
      setIsConnected(state.isConnected ?? false);
      setIsInternetReachable(state.isInternetReachable ?? false);
    });

    return () => {
      unsubscribe();
    };
  }, []);

  return { isConnected, isInternetReachable };
}

// 使用例
export function App() {
  const { isConnected, isInternetReachable } = useNetworkStatus();

  useEffect(() => {
    if (isConnected && isInternetReachable) {
      // オンライン復帰時に同期
      syncData();
    }
  }, [isConnected, isInternetReachable]);

  return (
    <View>
      {!isConnected && (
        <View style={{ backgroundColor: 'red' }}>
          <Text>オフラインモード</Text>
        </View>
      )}
    </View>
  );
}
```

---

## キューイング

### リクエストキュー

```typescript
interface QueuedRequest {
  id: string;
  url: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: any;
  timestamp: number;
  retries: number;
}

class RequestQueue {
  private queue: QueuedRequest[] = [];
  private processing = false;

  async add(request: Omit<QueuedRequest, 'id' | 'timestamp' | 'retries'>) {
    const queuedRequest: QueuedRequest = {
      ...request,
      id: generateId(),
      timestamp: Date.now(),
      retries: 0,
    };

    this.queue.push(queuedRequest);
    await this.saveQueue();

    if (!this.processing) {
      this.processQueue();
    }
  }

  private async processQueue() {
    if (this.queue.length === 0) {
      this.processing = false;
      return;
    }

    this.processing = true;
    const request = this.queue[0];

    try {
      await fetch(request.url, {
        method: request.method,
        headers: { 'Content-Type': 'application/json' },
        body: request.body ? JSON.stringify(request.body) : undefined,
      });

      // 成功 → キューから削除
      this.queue.shift();
      await this.saveQueue();
    } catch (error) {
      // 失敗 → リトライ
      request.retries++;

      if (request.retries >= 3) {
        // 最大リトライ数超過 → キューから削除
        this.queue.shift();
      }

      await this.saveQueue();
    }

    // 次のリクエストを処理
    setTimeout(() => this.processQueue(), 1000);
  }

  private async saveQueue() {
    await AsyncStorage.setItem('requestQueue', JSON.stringify(this.queue));
  }

  async loadQueue() {
    const data = await AsyncStorage.getItem('requestQueue');
    if (data) {
      this.queue = JSON.parse(data);
      this.processQueue();
    }
  }
}

// グローバルインスタンス
export const requestQueue = new RequestQueue();
```

---

## 実装例

### オフライン対応Todo アプリ

```typescript
import { database } from './database';
import { requestQueue } from './requestQueue';
import { useNetworkStatus } from './useNetworkStatus';

interface Todo {
  id: string;
  title: string;
  completed: boolean;
  syncStatus: 'synced' | 'pending' | 'error';
  updatedAt: number;
}

export function useTodos() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const { isConnected } = useNetworkStatus();

  useEffect(() => {
    loadTodos();
  }, []);

  useEffect(() => {
    if (isConnected) {
      syncTodos();
    }
  }, [isConnected]);

  async function loadTodos() {
    const localTodos = await database.collections.get('todos').query().fetch();
    setTodos(localTodos);
  }

  async function addTodo(title: string) {
    const todo = {
      id: generateId(),
      title,
      completed: false,
      syncStatus: 'pending' as const,
      updatedAt: Date.now(),
    };

    // ローカルに保存
    await database.write(async () => {
      await database.collections.get('todos').create((t) => {
        Object.assign(t, todo);
      });
    });

    // オンラインの場合はサーバーに送信
    if (isConnected) {
      await requestQueue.add({
        url: '/api/todos',
        method: 'POST',
        body: todo,
      });
    }

    await loadTodos();
  }

  async function updateTodo(id: string, completed: boolean) {
    // ローカルを更新
    await database.write(async () => {
      const todo = await database.collections.get('todos').find(id);
      await todo.update((t: any) => {
        t.completed = completed;
        t.syncStatus = 'pending';
        t.updatedAt = Date.now();
      });
    });

    // サーバーに送信
    if (isConnected) {
      await requestQueue.add({
        url: `/api/todos/${id}`,
        method: 'PUT',
        body: { completed },
      });
    }

    await loadTodos();
  }

  async function syncTodos() {
    try {
      // サーバーから最新データ取得
      const response = await fetch('/api/todos/sync', {
        method: 'POST',
        body: JSON.stringify({
          lastSyncedAt: await getLastSyncTime(),
        }),
      });

      const serverTodos = await response.json();

      // ローカルに反映
      await database.write(async () => {
        for (const serverTodo of serverTodos) {
          const localTodo = await database.collections
            .get('todos')
            .find(serverTodo.id)
            .catch(() => null);

          if (localTodo) {
            await localTodo.update((t: any) => {
              Object.assign(t, serverTodo);
              t.syncStatus = 'synced';
            });
          } else {
            await database.collections.get('todos').create((t) => {
              Object.assign(t, serverTodo);
              t.syncStatus = 'synced';
            });
          }
        }
      });

      await setLastSyncTime(Date.now());
      await loadTodos();
    } catch (error) {
      console.error('Sync failed:', error);
    }
  }

  return { todos, addTodo, updateTodo, syncTodos };
}
```

---

## ベストプラクティス

### 1. 楽観的UI更新

```typescript
async function updatePost(postId: string, title: string) {
  // すぐにUIを更新（楽観的更新）
  setPost({ ...post, title });

  try {
    // サーバーに送信
    await api.updatePost(postId, { title });
  } catch (error) {
    // 失敗したら元に戻す
    setPost(post);
    showError('更新に失敗しました');
  }
}
```

### 2. プログレッシブローディング

```typescript
function PostList() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      // まずローカルから読み込み
      const localPosts = await loadFromLocal();
      setPosts(localPosts);
      setLoading(false);

      // バックグラウンドでサーバーから取得
      try {
        const serverPosts = await loadFromServer();
        setPosts(serverPosts);
      } catch (error) {
        // エラーでもローカルデータは表示済み
      }
    }

    load();
  }, []);

  return <FlatList data={posts} />;
}
```

### 3. バックグラウンド同期

```bash
npx expo install expo-background-fetch expo-task-manager
```

```typescript
import * as BackgroundFetch from 'expo-background-fetch';
import * as TaskManager from 'expo-task-manager';

const BACKGROUND_SYNC_TASK = 'background-sync';

TaskManager.defineTask(BACKGROUND_SYNC_TASK, async () => {
  try {
    await syncData();
    return BackgroundFetch.BackgroundFetchResult.NewData;
  } catch (error) {
    return BackgroundFetch.BackgroundFetchResult.Failed;
  }
});

async function registerBackgroundSync() {
  await BackgroundFetch.registerTaskAsync(BACKGROUND_SYNC_TASK, {
    minimumInterval: 15 * 60, // 15分
    stopOnTerminate: false,
    startOnBoot: true,
  });
}
```

### 4. ストレージ容量管理

```typescript
async function cleanupOldData() {
  const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;

  await database.write(async () => {
    const oldPosts = await database.collections
      .get('posts')
      .query(Q.where('created_at', Q.lt(thirtyDaysAgo)))
      .fetch();

    await database.batch(
      ...oldPosts.map((post) => post.prepareDestroyPermanently())
    );
  });
}
```

### 5. 同期状態の可視化

```typescript
function SyncStatus() {
  const [syncStatus, setSyncStatus] = useState<{
    syncing: boolean;
    lastSyncedAt: number | null;
    pendingChanges: number;
  }>({
    syncing: false,
    lastSyncedAt: null,
    pendingChanges: 0,
  });

  return (
    <View>
      {syncStatus.syncing && <ActivityIndicator />}

      {syncStatus.pendingChanges > 0 && (
        <Text>{syncStatus.pendingChanges} 件の変更が未同期です</Text>
      )}

      {syncStatus.lastSyncedAt && (
        <Text>
          最終同期: {new Date(syncStatus.lastSyncedAt).toLocaleString()}
        </Text>
      )}
    </View>
  );
}
```

---

## 参考リンク

- [WatermelonDB](https://watermelondb.dev/)
- [Expo NetInfo](https://docs.expo.dev/versions/latest/sdk/netinfo/)
- [Offline First Design](https://offlinefirst.org/)
- [CRDTs](https://crdt.tech/)
