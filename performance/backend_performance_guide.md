# バックエンドパフォーマンス最適化ガイド

## 目次
1. [パフォーマンス最適化とは](#パフォーマンス最適化とは)
2. [データベース最適化](#データベース最適化)
3. [キャッシング](#キャッシング)
4. [非同期処理](#非同期処理)
5. [接続プール](#接続プール)
6. [クエリ最適化](#クエリ最適化)
7. [ベストプラクティス](#ベストプラクティス)

---

## パフォーマンス最適化とは

サーバーサイドアプリケーションのレスポンス時間とスループットを向上させる技術です。

### 主な指標

- **レスポンスタイム**: リクエストからレスポンスまでの時間
- **スループット**: 単位時間あたりの処理数
- **CPU使用率**: CPUリソースの使用状況
- **メモリ使用率**: メモリリソースの使用状況

---

## データベース最適化

### インデックス作成

```sql
-- 単一カラムインデックス
CREATE INDEX idx_users_email ON users(email);

-- 複合インデックス
CREATE INDEX idx_posts_user_date ON posts(user_id, created_at);

-- 部分インデックス
CREATE INDEX idx_active_users ON users(email) WHERE active = true;
```

```typescript
// Prisma
model User {
  id    Int    @id @default(autoincrement())
  email String @unique
  name  String

  @@index([email])
  @@index([name, email])
}
```

### N+1問題の解決

```typescript
// 悪い例: N+1問題
const users = await db.user.findMany();
for (const user of users) {
  const posts = await db.post.findMany({
    where: { userId: user.id },
  });
}

// 良い例: Include で一括取得
const users = await db.user.findMany({
  include: {
    posts: true,
  },
});
```

---

## キャッシング

### Redis キャッシュ

```typescript
import Redis from 'ioredis';

const redis = new Redis();

async function getCachedData(key: string, fetchFn: () => Promise<any>) {
  // キャッシュ確認
  const cached = await redis.get(key);
  if (cached) {
    return JSON.parse(cached);
  }

  // キャッシュミス → データ取得
  const data = await fetchFn();

  // キャッシュに保存（TTL: 1時間）
  await redis.setex(key, 3600, JSON.stringify(data));

  return data;
}

// 使用例
const user = await getCachedData(`user:${userId}`, async () => {
  return await db.user.findUnique({ where: { id: userId } });
});
```

### キャッシュ戦略

```typescript
// Cache-Aside
async function getUserCacheAside(userId: string) {
  const cached = await redis.get(`user:${userId}`);
  if (cached) return JSON.parse(cached);

  const user = await db.user.findUnique({ where: { id: userId } });
  await redis.setex(`user:${userId}`, 3600, JSON.stringify(user));

  return user;
}

// Write-Through
async function updateUserWriteThrough(userId: string, data: any) {
  await Promise.all([
    db.user.update({ where: { id: userId }, data }),
    redis.setex(`user:${userId}`, 3600, JSON.stringify(data)),
  ]);
}
```

---

## 非同期処理

### バックグラウンドジョブ

```typescript
import Bull from 'bull';

const emailQueue = new Bull('email', {
  redis: { host: 'localhost', port: 6379 },
});

// ジョブの追加
async function sendWelcomeEmail(userId: string) {
  await emailQueue.add({
    userId,
    type: 'welcome',
  });
}

// ジョブの処理
emailQueue.process(async (job) => {
  const { userId, type } = job.data;

  const user = await db.user.findUnique({ where: { id: userId } });
  await sendEmail(user.email, type);
});
```

### Promise.all で並列処理

```typescript
// 悪い例: 順次処理
const user = await fetchUser(userId);
const posts = await fetchPosts(userId);
const comments = await fetchComments(userId);

// 良い例: 並列処理
const [user, posts, comments] = await Promise.all([
  fetchUser(userId),
  fetchPosts(userId),
  fetchComments(userId),
]);
```

---

## 接続プール

### データベース接続プール

```typescript
// PostgreSQL
import { Pool } from 'pg';

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: 'password',
  database: 'mydb',
  max: 20, // 最大接続数
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

async function query(text: string, params: any[]) {
  const client = await pool.connect();
  try {
    return await client.query(text, params);
  } finally {
    client.release();
  }
}
```

### Redis 接続プール

```typescript
import Redis from 'ioredis';

const redis = new Redis({
  host: 'localhost',
  port: 6379,
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  lazyConnect: true,
});
```

---

## クエリ最適化

### SELECT最適化

```typescript
// 悪い例: 全カラム取得
const users = await db.user.findMany();

// 良い例: 必要なカラムのみ
const users = await db.user.findMany({
  select: {
    id: true,
    name: true,
    email: true,
  },
});
```

### ペジネーション

```typescript
// Cursor-based Pagination
async function getPaginatedPosts(cursor?: string, limit: number = 10) {
  const posts = await db.post.findMany({
    take: limit,
    skip: cursor ? 1 : 0,
    cursor: cursor ? { id: cursor } : undefined,
    orderBy: { createdAt: 'desc' },
  });

  return {
    posts,
    nextCursor: posts.length === limit ? posts[posts.length - 1].id : null,
  };
}
```

### バルク操作

```typescript
// 悪い例: ループで個別更新
for (const user of users) {
  await db.user.update({
    where: { id: user.id },
    data: { status: 'active' },
  });
}

// 良い例: バルク更新
await db.user.updateMany({
  where: { id: { in: users.map(u => u.id) } },
  data: { status: 'active' },
});
```

---

## ベストプラクティス

### 1. 圧縮

```typescript
import compression from 'compression';

app.use(compression({
  level: 6,
  threshold: 1024, // 1KB以上のみ圧縮
}));
```

### 2. クラスタリング

```typescript
import cluster from 'cluster';
import os from 'os';

if (cluster.isPrimary) {
  const numCPUs = os.cpus().length;

  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }

  cluster.on('exit', (worker) => {
    console.log(`Worker ${worker.process.pid} died`);
    cluster.fork();
  });
} else {
  // ワーカープロセス
  app.listen(3000);
}
```

### 3. ストリーミング

```typescript
import { createReadStream } from 'fs';

app.get('/download', (req, res) => {
  const stream = createReadStream('large-file.pdf');
  stream.pipe(res);
});
```

### 4. データベーストランザクション

```typescript
// Prisma トランザクション
await prisma.$transaction([
  prisma.user.update({ where: { id: 1 }, data: { balance: { decrement: 100 } } }),
  prisma.user.update({ where: { id: 2 }, data: { balance: { increment: 100 } } }),
]);
```

### 5. リクエストタイムアウト

```typescript
import timeout from 'connect-timeout';

app.use(timeout('5s'));
app.use((req, res, next) => {
  if (!req.timedout) next();
});
```

---

## 参考リンク

- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)
- [Database Performance Tips](https://use-the-index-luke.com/)
- [Redis Best Practices](https://redis.io/docs/manual/patterns/)
