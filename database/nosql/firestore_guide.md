# Cloud Firestore 完全ガイド

## 目次
1. [Cloud Firestoreとは](#cloud-firestoreとは)
2. [基本概念](#基本概念)
3. [セットアップ](#セットアップ)
4. [CRUD操作](#crud操作)
5. [クエリ](#クエリ)
6. [リアルタイムリスナー](#リアルタイムリスナー)
7. [トランザクションとバッチ](#トランザクションとバッチ)
8. [セキュリティルール](#セキュリティルール)
9. [インデックス](#インデックス)
10. [ベストプラクティス](#ベストプラクティス)

---

## Cloud Firestoreとは

Cloud Firestoreは、Googleが提供するNoSQLドキュメントデータベースです。

### 主な特徴

- **リアルタイム同期**: データ変更の即座な同期
- **オフラインサポート**: ローカルキャッシュと自動同期
- **スケーラビリティ**: 自動スケーリング
- **強力なクエリ**: 複合クエリとソート
- **セキュリティルール**: 宣言的なアクセス制御

### ユースケース

- リアルタイムチャットアプリ
- コラボレーションツール
- モバイルアプリバックエンド
- IoT データ管理
- ゲームのリーダーボード

---

## 基本概念

### データ構造

```
Database
├── Collection (users)
│   ├── Document (user_id_1)
│   │   ├── Field: value
│   │   ├── Subcollection (posts)
│   │   │   └── Document
│   │   └── Field: value
│   └── Document (user_id_2)
└── Collection (posts)
```

### ドキュメント例

```typescript
{
  userId: "user123",
  name: "John Doe",
  email: "john@example.com",
  age: 30,
  address: {
    street: "123 Main St",
    city: "New York",
    country: "USA"
  },
  hobbies: ["reading", "gaming"],
  createdAt: Timestamp.now(),
  metadata: {
    lastLogin: Timestamp.now(),
    loginCount: 5
  }
}
```

---

## セットアップ

### Firebase プロジェクトの作成

1. [Firebase Console](https://console.firebase.google.com/) でプロジェクト作成
2. Firestore Databaseを有効化
3. サービスアカウントキーをダウンロード

### Node.js SDK のインストール

```bash
npm install firebase-admin
# または Web SDK
npm install firebase
```

### 初期化（Admin SDK）

```typescript
import admin from 'firebase-admin';
import serviceAccount from './serviceAccountKey.json';

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
  databaseURL: 'https://your-project.firebaseio.com',
});

const db = admin.firestore();

export { db };
```

### 初期化（Web SDK）

```typescript
import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'YOUR_API_KEY',
  authDomain: 'your-project.firebaseapp.com',
  projectId: 'your-project',
  storageBucket: 'your-project.appspot.com',
  messagingSenderId: '123456789',
  appId: '1:123456789:web:abcdef',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

export { db };
```

---

## CRUD操作

### Create（作成）

```typescript
import {
  collection,
  doc,
  setDoc,
  addDoc,
  serverTimestamp,
} from 'firebase/firestore';

// 自動生成IDで追加
async function createUser(userData: any) {
  try {
    const docRef = await addDoc(collection(db, 'users'), {
      ...userData,
      createdAt: serverTimestamp(),
    });

    console.log('Document created with ID:', docRef.id);
    return docRef.id;
  } catch (error) {
    console.error('Error creating document:', error);
    throw error;
  }
}

// カスタムIDで作成
async function createUserWithId(userId: string, userData: any) {
  try {
    await setDoc(doc(db, 'users', userId), {
      ...userData,
      createdAt: serverTimestamp(),
    });

    console.log('Document created with ID:', userId);
    return userId;
  } catch (error) {
    console.error('Error creating document:', error);
    throw error;
  }
}

// マージ（存在すれば更新、なければ作成）
async function upsertUser(userId: string, userData: any) {
  await setDoc(doc(db, 'users', userId), userData, { merge: true });
}

// 使用例
await createUser({
  name: 'John Doe',
  email: 'john@example.com',
  age: 30,
});

await createUserWithId('user123', {
  name: 'Alice',
  email: 'alice@example.com',
  age: 25,
});
```

### Read（読み取り）

```typescript
import { doc, getDoc, collection, getDocs, query, where } from 'firebase/firestore';

// 単一ドキュメント取得
async function getUser(userId: string) {
  try {
    const docRef = doc(db, 'users', userId);
    const docSnap = await getDoc(docRef);

    if (docSnap.exists()) {
      console.log('User data:', docSnap.data());
      return { id: docSnap.id, ...docSnap.data() };
    } else {
      console.log('No such document');
      return null;
    }
  } catch (error) {
    console.error('Error getting document:', error);
    throw error;
  }
}

// 全ドキュメント取得
async function getAllUsers() {
  try {
    const querySnapshot = await getDocs(collection(db, 'users'));

    const users = querySnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    console.log('Users:', users);
    return users;
  } catch (error) {
    console.error('Error getting documents:', error);
    throw error;
  }
}

// 条件付き取得
async function getAdultUsers() {
  try {
    const q = query(collection(db, 'users'), where('age', '>=', 18));

    const querySnapshot = await getDocs(q);
    const users = querySnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return users;
  } catch (error) {
    console.error('Error querying documents:', error);
    throw error;
  }
}
```

### Update（更新）

```typescript
import { doc, updateDoc, increment, arrayUnion, arrayRemove } from 'firebase/firestore';

// フィールド更新
async function updateUser(userId: string, updates: any) {
  try {
    const docRef = doc(db, 'users', userId);

    await updateDoc(docRef, {
      ...updates,
      updatedAt: serverTimestamp(),
    });

    console.log('Document updated');
  } catch (error) {
    console.error('Error updating document:', error);
    throw error;
  }
}

// 数値のインクリメント
async function incrementLoginCount(userId: string) {
  const docRef = doc(db, 'users', userId);

  await updateDoc(docRef, {
    'metadata.loginCount': increment(1),
    'metadata.lastLogin': serverTimestamp(),
  });
}

// 配列操作
async function addHobby(userId: string, hobby: string) {
  const docRef = doc(db, 'users', userId);

  await updateDoc(docRef, {
    hobbies: arrayUnion(hobby), // 追加（重複なし）
  });
}

async function removeHobby(userId: string, hobby: string) {
  const docRef = doc(db, 'users', userId);

  await updateDoc(docRef, {
    hobbies: arrayRemove(hobby), // 削除
  });
}

// ネストされたフィールドの更新
async function updateAddress(userId: string, city: string) {
  const docRef = doc(db, 'users', userId);

  await updateDoc(docRef, {
    'address.city': city, // ドット記法
  });
}
```

### Delete（削除）

```typescript
import { doc, deleteDoc, deleteField } from 'firebase/firestore';

// ドキュメント削除
async function deleteUser(userId: string) {
  try {
    await deleteDoc(doc(db, 'users', userId));
    console.log('Document deleted');
  } catch (error) {
    console.error('Error deleting document:', error);
    throw error;
  }
}

// フィールド削除
async function removeField(userId: string) {
  const docRef = doc(db, 'users', userId);

  await updateDoc(docRef, {
    tempField: deleteField(),
  });
}

// サブコレクションを含む削除（再帰的）
async function deleteUserWithSubcollections(userId: string) {
  const userRef = doc(db, 'users', userId);

  // サブコレクション削除
  const postsSnapshot = await getDocs(collection(userRef, 'posts'));
  const deletePromises = postsSnapshot.docs.map((doc) => deleteDoc(doc.ref));
  await Promise.all(deletePromises);

  // ドキュメント削除
  await deleteDoc(userRef);
}
```

---

## クエリ

### 基本的なクエリ

```typescript
import { query, where, orderBy, limit, startAfter } from 'firebase/firestore';

// 等価クエリ
const q1 = query(collection(db, 'users'), where('age', '==', 30));

// 比較クエリ
const q2 = query(collection(db, 'users'), where('age', '>', 25));
const q3 = query(collection(db, 'users'), where('age', '>=', 18), where('age', '<=', 65));

// 配列クエリ
const q4 = query(
  collection(db, 'users'),
  where('hobbies', 'array-contains', 'reading')
);

const q5 = query(
  collection(db, 'users'),
  where('hobbies', 'array-contains-any', ['reading', 'gaming'])
);

// IN クエリ
const q6 = query(collection(db, 'users'), where('city', 'in', ['Tokyo', 'Osaka', 'Kyoto']));

// 複合クエリ
const q7 = query(
  collection(db, 'users'),
  where('age', '>=', 18),
  where('country', '==', 'USA'),
  orderBy('age', 'desc')
);

// ソート
const q8 = query(collection(db, 'users'), orderBy('createdAt', 'desc'));

// リミット
const q9 = query(collection(db, 'users'), orderBy('age'), limit(10));

// ページネーション
const firstPage = query(collection(db, 'users'), orderBy('name'), limit(10));

const firstSnapshot = await getDocs(firstPage);
const lastVisible = firstSnapshot.docs[firstSnapshot.docs.length - 1];

const nextPage = query(
  collection(db, 'users'),
  orderBy('name'),
  startAfter(lastVisible),
  limit(10)
);
```

### 複合インデックスが必要なクエリ

```typescript
// 複数フィールドでのフィルタリングとソート
const q = query(
  collection(db, 'posts'),
  where('published', '==', true),
  where('category', '==', 'tech'),
  orderBy('createdAt', 'desc')
);
// → 複合インデックス必要: published, category, createdAt

// 範囲クエリ + ソート
const q2 = query(
  collection(db, 'products'),
  where('price', '>', 100),
  where('price', '<', 1000),
  orderBy('price'),
  orderBy('rating', 'desc')
);
```

---

## リアルタイムリスナー

### ドキュメントリスナー

```typescript
import { doc, onSnapshot } from 'firebase/firestore';

// 単一ドキュメントの変更を監視
function watchUser(userId: string, callback: (user: any) => void) {
  const docRef = doc(db, 'users', userId);

  const unsubscribe = onSnapshot(
    docRef,
    (docSnap) => {
      if (docSnap.exists()) {
        console.log('User data updated:', docSnap.data());
        callback({ id: docSnap.id, ...docSnap.data() });
      } else {
        console.log('User deleted');
        callback(null);
      }
    },
    (error) => {
      console.error('Error watching document:', error);
    }
  );

  // クリーンアップ関数を返す
  return unsubscribe;
}

// 使用例
const unsubscribe = watchUser('user123', (user) => {
  console.log('User updated:', user);
});

// 監視停止
// unsubscribe();
```

### コレクションリスナー

```typescript
import { collection, query, where, onSnapshot } from 'firebase/firestore';

// コレクション全体の変更を監視
function watchUsers(callback: (users: any[]) => void) {
  const q = query(collection(db, 'users'), where('status', '==', 'active'));

  const unsubscribe = onSnapshot(
    q,
    (querySnapshot) => {
      const users = querySnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      console.log('Users updated:', users);
      callback(users);
    },
    (error) => {
      console.error('Error watching collection:', error);
    }
  );

  return unsubscribe;
}

// 変更の種類を検出
function watchUsersWithChanges(callback: (changes: any) => void) {
  const unsubscribe = onSnapshot(collection(db, 'users'), (snapshot) => {
    snapshot.docChanges().forEach((change) => {
      if (change.type === 'added') {
        console.log('New user:', change.doc.data());
      }
      if (change.type === 'modified') {
        console.log('Modified user:', change.doc.data());
      }
      if (change.type === 'removed') {
        console.log('Removed user:', change.doc.data());
      }
    });

    callback(snapshot.docChanges());
  });

  return unsubscribe;
}
```

### React での使用例

```typescript
import { useState, useEffect } from 'react';
import { collection, query, onSnapshot } from 'firebase/firestore';

function useUsers() {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'users'));

    const unsubscribe = onSnapshot(
      q,
      (querySnapshot) => {
        const usersData = querySnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        setUsers(usersData);
        setLoading(false);
      },
      (error) => {
        console.error('Error fetching users:', error);
        setLoading(false);
      }
    );

    // クリーンアップ
    return () => unsubscribe();
  }, []);

  return { users, loading };
}

// コンポーネントで使用
function UserList() {
  const { users, loading } = useUsers();

  if (loading) return <div>Loading...</div>;

  return (
    <ul>
      {users.map((user) => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}
```

---

## トランザクションとバッチ

### トランザクション

```typescript
import { runTransaction, doc } from 'firebase/firestore';

// トランザクション
async function transferPoints(fromUserId: string, toUserId: string, points: number) {
  try {
    await runTransaction(db, async (transaction) => {
      const fromRef = doc(db, 'users', fromUserId);
      const toRef = doc(db, 'users', toUserId);

      // 読み取り
      const fromDoc = await transaction.get(fromRef);
      const toDoc = await transaction.get(toRef);

      if (!fromDoc.exists() || !toDoc.exists()) {
        throw new Error('User not found');
      }

      const fromPoints = fromDoc.data().points || 0;

      if (fromPoints < points) {
        throw new Error('Insufficient points');
      }

      // 書き込み
      transaction.update(fromRef, {
        points: fromPoints - points,
      });

      transaction.update(toRef, {
        points: (toDoc.data().points || 0) + points,
      });
    });

    console.log('Transfer successful');
  } catch (error) {
    console.error('Transaction failed:', error);
    throw error;
  }
}

// 使用例
await transferPoints('user1', 'user2', 100);
```

### バッチ書き込み

```typescript
import { writeBatch, doc } from 'firebase/firestore';

// バッチ処理（最大500件）
async function batchUpdateUsers(userUpdates: any[]) {
  const batch = writeBatch(db);

  userUpdates.forEach((update) => {
    const docRef = doc(db, 'users', update.id);
    batch.update(docRef, update.data);
  });

  await batch.commit();
  console.log('Batch update successful');
}

// 複数操作をバッチで実行
async function performBatchOperations() {
  const batch = writeBatch(db);

  // 作成
  const newUserRef = doc(collection(db, 'users'));
  batch.set(newUserRef, {
    name: 'New User',
    email: 'new@example.com',
  });

  // 更新
  const updateRef = doc(db, 'users', 'user123');
  batch.update(updateRef, {
    lastActive: serverTimestamp(),
  });

  // 削除
  const deleteRef = doc(db, 'users', 'user456');
  batch.delete(deleteRef);

  await batch.commit();
}
```

---

## セキュリティルール

### 基本的なルール

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 全て拒否（デフォルト）
    match /{document=**} {
      allow read, write: if false;
    }

    // 認証済みユーザーのみ読み取り可能
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // 公開データ（全員読み取り可、認証済みユーザーのみ書き込み可）
    match /posts/{postId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null
        && request.auth.uid == resource.data.authorId;
    }
  }
}
```

### 高度なルール

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // カスタム関数
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    function hasRole(role) {
      return isSignedIn()
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == role;
    }

    function isValidUser() {
      let data = request.resource.data;
      return data.name is string
        && data.name.size() >= 2
        && data.email is string
        && data.email.matches('.*@.*\\..*');
    }

    // ユーザードキュメント
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && isOwner(userId) && isValidUser();
      allow update: if isOwner(userId) && isValidUser();
      allow delete: if isOwner(userId) || hasRole('admin');
    }

    // 投稿ドキュメント
    match /posts/{postId} {
      allow read: if resource.data.published == true || isOwner(resource.data.authorId);
      allow create: if isSignedIn()
        && request.resource.data.authorId == request.auth.uid
        && request.resource.data.title is string
        && request.resource.data.content is string;
      allow update: if isOwner(resource.data.authorId)
        && request.resource.data.authorId == resource.data.authorId; // 作者変更不可
      allow delete: if isOwner(resource.data.authorId) || hasRole('admin');

      // サブコレクション
      match /comments/{commentId} {
        allow read: if true;
        allow create: if isSignedIn();
        allow update, delete: if isOwner(resource.data.authorId);
      }
    }
  }
}
```

---

## インデックス

### 単一フィールドインデックス

自動的に作成されます。

### 複合インデックス

Firebase Consoleまたは `firestore.indexes.json` で定義：

```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "published",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "category",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "country",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "age",
          "order": "ASCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

## ベストプラクティス

### 1. データモデリング

```typescript
// 良い例: フラットな構造
{
  userId: "user123",
  name: "John Doe",
  postCount: 5,
  latestPostId: "post456"
}

// 悪い例: 深いネスト
{
  userId: "user123",
  profile: {
    personal: {
      name: {
        first: "John",
        last: "Doe"
      }
    }
  }
}
```

### 2. 非正規化

```typescript
// 投稿に著者情報を含める（非正規化）
{
  postId: "post123",
  title: "My Post",
  content: "...",
  author: {
    id: "user123",
    name: "John Doe",
    avatar: "https://..."
  }
}

// 更新時は両方を更新
async function updateUserProfile(userId: string, name: string, avatar: string) {
  const batch = writeBatch(db);

  // ユーザープロフィール更新
  batch.update(doc(db, 'users', userId), { name, avatar });

  // 投稿の著者情報も更新
  const postsSnapshot = await getDocs(
    query(collection(db, 'posts'), where('author.id', '==', userId))
  );

  postsSnapshot.docs.forEach((postDoc) => {
    batch.update(postDoc.ref, {
      'author.name': name,
      'author.avatar': avatar,
    });
  });

  await batch.commit();
}
```

### 3. ページネーション

```typescript
async function getPaginatedPosts(pageSize: number = 10, lastDoc?: any) {
  let q = query(collection(db, 'posts'), orderBy('createdAt', 'desc'), limit(pageSize));

  if (lastDoc) {
    q = query(q, startAfter(lastDoc));
  }

  const snapshot = await getDocs(q);

  const posts = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  const lastVisible = snapshot.docs[snapshot.docs.length - 1];

  return {
    posts,
    lastDoc: lastVisible,
    hasMore: snapshot.docs.length === pageSize,
  };
}
```

### 4. カウンターの最適化（分散カウンター）

```typescript
// 分散カウンター
async function incrementDistributedCounter(counterId: string) {
  const numShards = 10;
  const shardId = Math.floor(Math.random() * numShards);

  const shardRef = doc(db, 'counters', counterId, 'shards', shardId.toString());

  await updateDoc(shardRef, {
    count: increment(1),
  });
}

async function getDistributedCounterValue(counterId: string) {
  const shardsSnapshot = await getDocs(
    collection(db, 'counters', counterId, 'shards')
  );

  let total = 0;
  shardsSnapshot.docs.forEach((doc) => {
    total += doc.data().count || 0;
  });

  return total;
}
```

### 5. オフライン対応

```typescript
import { enableIndexedDbPersistence } from 'firebase/firestore';

// オフラインキャッシュを有効化
try {
  await enableIndexedDbPersistence(db);
  console.log('Offline persistence enabled');
} catch (error: any) {
  if (error.code === 'failed-precondition') {
    console.error('Multiple tabs open');
  } else if (error.code === 'unimplemented') {
    console.error('Browser does not support persistence');
  }
}
```

---

## 参考リンク

- [Cloud Firestore 公式ドキュメント](https://firebase.google.com/docs/firestore)
- [Firestore データモデリングガイド](https://firebase.google.com/docs/firestore/manage-data/structure-data)
- [セキュリティルールリファレンス](https://firebase.google.com/docs/firestore/security/rules-structure)
- [Firestore 料金](https://firebase.google.com/pricing)
