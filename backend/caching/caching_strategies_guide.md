# キャッシング戦略 完全ガイド

## 目次
1. [キャッシングとは](#キャッシングとは)
2. [キャッシング戦略](#キャッシング戦略)
3. [Redis](#redis)
4. [Memcached](#memcached)
5. [アプリケーションレベルキャッシュ](#アプリケーションレベルキャッシュ)
6. [CDNキャッシュ](#cdnキャッシュ)
7. [実装例](#実装例)
8. [ベストプラクティス](#ベストプラクティス)

---

## キャッシングとは

キャッシングは、頻繁にアクセスされるデータを高速なストレージに保存し、レスポンス時間を短縮する手法です。

### 主な利点

- **パフォーマンス向上**: レスポンス時間の短縮
- **負荷軽減**: データベースへの負荷削減
- **コスト削減**: リソース使用量の最適化
- **スケーラビリティ**: トラフィック増加への対応

---

## キャッシング戦略

### 1. Cache-Aside（Lazy Loading）

```typescript
async function getCacheAside(key: string) {
  // キャッシュ確認
  const cached = await redis.get(key);
  if (cached) {
    return JSON.parse(cached);
  }

  // キャッシュミス → DBから取得
  const data = await database.query(key);

  // キャッシュに保存
  await redis.setex(key, 3600, JSON.stringify(data));

  return data;
}
```

### 2. Write-Through

```typescript
async function writeThrough(key: string, data: any) {
  // DBとキャッシュに同時書き込み
  await Promise.all([
    database.save(key, data),
    redis.setex(key, 3600, JSON.stringify(data)),
  ]);
}
```

### 3. Write-Behind（Write-Back）

```typescript
async function writeBehind(key: string, data: any) {
  // キャッシュに即座に書き込み
  await redis.setex(key, 3600, JSON.stringify(data));

  // DBへの書き込みは非同期
  writeQueue.add({ key, data });
}
```

### 4. Refresh-Ahead

```typescript
async function refreshAhead(key: string) {
  const ttl = await redis.ttl(key);

  // TTLが短くなったら更新
  if (ttl < 300) { // 5分
    const data = await database.query(key);
    await redis.setex(key, 3600, JSON.stringify(data));
  }
}
```

---

## Redis

### セットアップ

```typescript
import Redis from 'ioredis';

const redis = new Redis({
  host: 'localhost',
  port: 6379,
  password: 'your-password',
  db: 0,
  retryStrategy: (times) => {
    return Math.min(times * 50, 2000);
  },
});

export default redis;
```

### 基本操作

```typescript
// String
await redis.set('key', 'value');
await redis.setex('key', 3600, 'value'); // TTL付き
const value = await redis.get('key');

// Hash
await redis.hset('user:123', 'name', 'John');
await redis.hgetall('user:123');

// List
await redis.lpush('queue', 'task1');
await redis.rpop('queue');

// Set
await redis.sadd('tags', 'nodejs', 'redis');
await redis.smembers('tags');

// Sorted Set
await redis.zadd('leaderboard', 100, 'player1');
await redis.zrange('leaderboard', 0, 9);
```

### キャッシュパターン

```typescript
class CacheService {
  async get<T>(key: string): Promise<T | null> {
    const cached = await redis.get(key);
    return cached ? JSON.parse(cached) : null;
  }

  async set(key: string, value: any, ttl: number = 3600): Promise<void> {
    await redis.setex(key, ttl, JSON.stringify(value));
  }

  async delete(key: string): Promise<void> {
    await redis.del(key);
  }

  async invalidatePattern(pattern: string): Promise<void> {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  }
}

// 使用例
const cache = new CacheService();

async function getUser(userId: string) {
  const cacheKey = `user:${userId}`;

  let user = await cache.get(cacheKey);
  if (user) return user;

  user = await db.users.findById(userId);
  await cache.set(cacheKey, user, 3600);

  return user;
}
```

---

## アプリケーションレベルキャッシュ

### Node.js メモリキャッシュ

```typescript
import NodeCache from 'node-cache';

const cache = new NodeCache({
  stdTTL: 600, // 10分
  checkperiod: 120, // 2分ごとにチェック
});

// 使用例
cache.set('myKey', { foo: 'bar' });
const value = cache.get('myKey');
cache.del('myKey');
```

### LRU Cache

```typescript
import LRU from 'lru-cache';

const cache = new LRU({
  max: 500, // 最大アイテム数
  maxAge: 1000 * 60 * 60, // 1時間
});

cache.set('key', 'value');
const value = cache.get('key');
```

---

## 実装例

### Express.js ミドルウェア

```typescript
import express from 'express';
import Redis from 'ioredis';

const app = express();
const redis = new Redis();

// キャッシュミドルウェア
function cacheMiddleware(duration: number) {
  return async (req: express.Request, res: express.Response, next: express.NextFunction) => {
    const key = `cache:${req.originalUrl}`;

    const cached = await redis.get(key);
    if (cached) {
      return res.json(JSON.parse(cached));
    }

    // レスポンスをキャッシュ
    const originalSend = res.json;
    res.json = function(data) {
      redis.setex(key, duration, JSON.stringify(data));
      return originalSend.call(this, data);
    };

    next();
  };
}

// 使用例
app.get('/api/users', cacheMiddleware(300), async (req, res) => {
  const users = await db.users.findAll();
  res.json(users);
});
```

---

## ベストプラクティス

### 1. TTL設定

```typescript
const TTL = {
  SHORT: 60,        // 1分
  MEDIUM: 3600,     // 1時間
  LONG: 86400,      // 1日
};

await redis.setex('frequently-changing', TTL.SHORT, data);
await redis.setex('rarely-changing', TTL.LONG, data);
```

### 2. キャッシュ無効化

```typescript
// 特定のキャッシュ削除
await redis.del('user:123');

// パターンマッチで削除
const keys = await redis.keys('user:*');
await redis.del(...keys);

// タグベースの無効化
await redis.sadd('tag:users', 'user:123', 'user:456');
const userKeys = await redis.smembers('tag:users');
await redis.del(...userKeys);
```

### 3. キャッシュウォーミング

```typescript
async function warmCache() {
  const users = await db.users.find({ active: true });

  const pipeline = redis.pipeline();
  users.forEach(user => {
    pipeline.setex(`user:${user.id}`, 3600, JSON.stringify(user));
  });

  await pipeline.exec();
}
```

---

## 参考リンク

- [Redis Documentation](https://redis.io/documentation)
- [Caching Strategies](https://docs.aws.amazon.com/AmazonElastiCache/latest/mem-ug/Strategies.html)
