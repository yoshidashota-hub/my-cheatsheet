# Redis ガイド

Redisは、高速なインメモリデータストアです。

## 特徴

- **高速**: メモリ内で動作し、非常に高速
- **多様なデータ構造**: String, List, Set, Hash, Sorted Set など
- **永続化**: ディスクへの保存も可能
- **Pub/Sub**: リアルタイム通信
- **トランザクション**: ACID特性をサポート
- **レプリケーション**: マスター・スレーブ構成

## インストール

### macOS

```bash
brew install redis

# 起動
brew services start redis

# 停止
brew services stop redis

# 手動起動
redis-server
```

### Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install redis-server

# 起動
sudo systemctl start redis-server
sudo systemctl enable redis-server

# 状態確認
sudo systemctl status redis-server
```

### Docker

```bash
# 起動
docker run --name redis -p 6379:6379 -d redis:7-alpine

# 永続化付き
docker run --name redis \
  -p 6379:6379 \
  -v redis-data:/data \
  -d redis:7-alpine redis-server --appendonly yes
```

## Redis CLI

### 接続

```bash
# ローカルに接続
redis-cli

# リモートホストに接続
redis-cli -h localhost -p 6379

# パスワード認証
redis-cli -a password

# データベース選択
redis-cli -n 1
```

### 基本コマンド

```bash
# 接続確認
PING
# PONG

# キー一覧（本番環境では注意）
KEYS *

# キーの存在確認
EXISTS mykey

# キーの削除
DEL mykey

# キーの有効期限設定（秒）
EXPIRE mykey 60

# TTL確認
TTL mykey

# キーのリネーム
RENAME oldkey newkey

# データベースのクリア
FLUSHDB

# 全データベースのクリア
FLUSHALL

# サーバー情報
INFO

# クライアント一覧
CLIENT LIST
```

## データ構造

### String

```bash
# 設定
SET name "John Doe"

# 取得
GET name

# 複数設定
MSET key1 "value1" key2 "value2"

# 複数取得
MGET key1 key2

# 存在しない場合のみ設定
SETNX key "value"

# 有効期限付き設定（秒）
SETEX key 60 "value"

# 有効期限付き設定（ミリ秒）
PSETEX key 60000 "value"

# 値の追加
APPEND key "additional"

# インクリメント
SET counter 0
INCR counter
# 1

# デクリメント
DECR counter

# 指定値だけインクリメント
INCRBY counter 5

# 浮動小数点のインクリメント
INCRBYFLOAT price 0.1
```

### List

```bash
# 左から追加
LPUSH mylist "item1"
LPUSH mylist "item2"

# 右から追加
RPUSH mylist "item3"

# 左から取得・削除
LPOP mylist

# 右から取得・削除
RPOP mylist

# 範囲取得
LRANGE mylist 0 -1

# 長さ取得
LLEN mylist

# インデックス指定取得
LINDEX mylist 0

# インデックス指定設定
LSET mylist 0 "new value"

# 値の削除
LREM mylist 1 "item1"

# トリム（指定範囲のみ残す）
LTRIM mylist 0 99
```

### Set

```bash
# メンバー追加
SADD myset "member1"
SADD myset "member2" "member3"

# メンバー削除
SREM myset "member1"

# メンバー一覧
SMEMBERS myset

# メンバー数
SCARD myset

# メンバーの存在確認
SISMEMBER myset "member1"

# ランダムに取得
SRANDMEMBER myset

# ランダムに取得・削除
SPOP myset

# 集合演算（和集合）
SUNION set1 set2

# 集合演算（積集合）
SINTER set1 set2

# 集合演算（差集合）
SDIFF set1 set2
```

### Hash

```bash
# フィールド設定
HSET user:1 name "John Doe"
HSET user:1 age 30

# 複数フィールド設定
HMSET user:1 name "John Doe" age 30 email "john@example.com"

# フィールド取得
HGET user:1 name

# 複数フィールド取得
HMGET user:1 name age

# 全フィールド取得
HGETALL user:1

# フィールド削除
HDEL user:1 age

# フィールド存在確認
HEXISTS user:1 name

# フィールド数
HLEN user:1

# 全フィールド名
HKEYS user:1

# 全値
HVALS user:1

# インクリメント
HINCRBY user:1 age 1
```

### Sorted Set

```bash
# メンバー追加（スコア付き）
ZADD leaderboard 100 "player1"
ZADD leaderboard 200 "player2" 150 "player3"

# 範囲取得（スコア昇順）
ZRANGE leaderboard 0 -1

# 範囲取得（スコア付き）
ZRANGE leaderboard 0 -1 WITHSCORES

# 範囲取得（スコア降順）
ZREVRANGE leaderboard 0 -1

# スコア範囲取得
ZRANGEBYSCORE leaderboard 100 200

# メンバー削除
ZREM leaderboard "player1"

# スコア取得
ZSCORE leaderboard "player2"

# ランク取得（昇順）
ZRANK leaderboard "player2"

# ランク取得（降順）
ZREVRANK leaderboard "player2"

# メンバー数
ZCARD leaderboard

# スコア範囲のメンバー数
ZCOUNT leaderboard 100 200

# スコアのインクリメント
ZINCRBY leaderboard 10 "player2"
```

## Node.js での使用

### インストール

```bash
npm install redis
# or
npm install ioredis
```

### 基本的な接続（redis）

```typescript
import { createClient } from 'redis'

const client = createClient({
  url: 'redis://localhost:6379',
  // password: 'your-password',
  // database: 0,
})

client.on('error', (err) => console.error('Redis Error:', err))
client.on('connect', () => console.log('Redis Connected'))

await client.connect()

// 使用例
await client.set('key', 'value')
const value = await client.get('key')
console.log(value) // 'value'

// 終了
await client.disconnect()
```

### ioredis の使用

```typescript
import Redis from 'ioredis'

const redis = new Redis({
  host: 'localhost',
  port: 6379,
  // password: 'your-password',
  // db: 0,
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000)
    return delay
  },
})

redis.on('connect', () => console.log('Redis Connected'))
redis.on('error', (err) => console.error('Redis Error:', err))

// 使用例
await redis.set('key', 'value')
const value = await redis.get('key')

// 終了
await redis.quit()
```

## キャッシング

### 基本的なキャッシュ

```typescript
import { createClient } from 'redis'

const redis = createClient()
await redis.connect()

async function getUser(userId: string) {
  const cacheKey = `user:${userId}`

  // キャッシュを確認
  const cached = await redis.get(cacheKey)
  if (cached) {
    console.log('Cache hit')
    return JSON.parse(cached)
  }

  // データベースから取得
  console.log('Cache miss')
  const user = await db.users.findUnique({ where: { id: userId } })

  // キャッシュに保存（1時間）
  await redis.setEx(cacheKey, 3600, JSON.stringify(user))

  return user
}
```

### キャッシュの無効化

```typescript
// 単一キャッシュの削除
await redis.del(`user:${userId}`)

// パターンマッチで削除
const keys = await redis.keys('user:*')
if (keys.length > 0) {
  await redis.del(keys)
}

// より効率的な方法（SCAN使用）
async function deleteByPattern(pattern: string) {
  let cursor = 0
  do {
    const result = await redis.scan(cursor, {
      MATCH: pattern,
      COUNT: 100,
    })
    cursor = result.cursor

    if (result.keys.length > 0) {
      await redis.del(result.keys)
    }
  } while (cursor !== 0)
}

await deleteByPattern('user:*')
```

### キャッシュアサイドパターン

```typescript
class UserCache {
  constructor(private redis: Redis, private db: PrismaClient) {}

  async get(userId: string) {
    const key = `user:${userId}`
    const cached = await this.redis.get(key)

    if (cached) {
      return JSON.parse(cached)
    }

    const user = await this.db.user.findUnique({ where: { id: userId } })

    if (user) {
      await this.redis.setEx(key, 3600, JSON.stringify(user))
    }

    return user
  }

  async update(userId: string, data: any) {
    const user = await this.db.user.update({
      where: { id: userId },
      data,
    })

    // キャッシュを更新
    const key = `user:${userId}`
    await this.redis.setEx(key, 3600, JSON.stringify(user))

    return user
  }

  async delete(userId: string) {
    await this.db.user.delete({ where: { id: userId } })

    // キャッシュを削除
    await this.redis.del(`user:${userId}`)
  }
}
```

## セッション管理

### Express でのセッション管理

```bash
npm install express-session connect-redis
```

```typescript
import express from 'express'
import session from 'express-session'
import RedisStore from 'connect-redis'
import { createClient } from 'redis'

const app = express()

const redisClient = createClient()
await redisClient.connect()

app.use(
  session({
    store: new RedisStore({ client: redisClient }),
    secret: 'your-secret-key',
    resave: false,
    saveUninitialized: false,
    cookie: {
      secure: process.env.NODE_ENV === 'production',
      httpOnly: true,
      maxAge: 1000 * 60 * 60 * 24, // 24時間
    },
  })
)

app.post('/login', (req, res) => {
  req.session.userId = '123'
  res.json({ success: true })
})

app.get('/profile', (req, res) => {
  if (!req.session.userId) {
    return res.status(401).json({ error: 'Not authenticated' })
  }

  res.json({ userId: req.session.userId })
})

app.post('/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ error: 'Logout failed' })
    }
    res.json({ success: true })
  })
})
```

### カスタムセッション管理

```typescript
import { randomUUID } from 'crypto'

class SessionManager {
  constructor(private redis: Redis) {}

  async create(userId: string): Promise<string> {
    const sessionId = randomUUID()
    const key = `session:${sessionId}`

    await this.redis.setEx(
      key,
      3600 * 24, // 24時間
      JSON.stringify({ userId, createdAt: Date.now() })
    )

    return sessionId
  }

  async get(sessionId: string) {
    const key = `session:${sessionId}`
    const data = await this.redis.get(key)

    if (!data) return null

    return JSON.parse(data)
  }

  async extend(sessionId: string) {
    const key = `session:${sessionId}`
    await this.redis.expire(key, 3600 * 24)
  }

  async destroy(sessionId: string) {
    const key = `session:${sessionId}`
    await this.redis.del(key)
  }
}
```

## Pub/Sub

### Publisher

```typescript
import { createClient } from 'redis'

const publisher = createClient()
await publisher.connect()

// メッセージ送信
await publisher.publish('notifications', JSON.stringify({
  type: 'new_message',
  userId: '123',
  message: 'Hello!',
}))
```

### Subscriber

```typescript
import { createClient } from 'redis'

const subscriber = createClient()
await subscriber.connect()

// チャンネルを購読
await subscriber.subscribe('notifications', (message) => {
  const data = JSON.parse(message)
  console.log('Received:', data)
})

// パターンマッチで購読
await subscriber.pSubscribe('user:*:notifications', (message, channel) => {
  console.log(`Message from ${channel}:`, message)
})
```

### 実践例（チャット）

```typescript
// chat-service.ts
class ChatService {
  private publisher: Redis
  private subscriber: Redis

  constructor() {
    this.publisher = createClient()
    this.subscriber = createClient()
  }

  async init() {
    await this.publisher.connect()
    await this.subscriber.connect()
  }

  async sendMessage(roomId: string, userId: string, message: string) {
    const data = {
      userId,
      message,
      timestamp: Date.now(),
    }

    await this.publisher.publish(
      `chat:${roomId}`,
      JSON.stringify(data)
    )

    // メッセージ履歴に保存
    await this.publisher.lPush(
      `chat:${roomId}:history`,
      JSON.stringify(data)
    )
    await this.publisher.lTrim(`chat:${roomId}:history`, 0, 99)
  }

  async joinRoom(roomId: string, callback: (data: any) => void) {
    await this.subscriber.subscribe(`chat:${roomId}`, (message) => {
      callback(JSON.parse(message))
    })
  }

  async getHistory(roomId: string, limit = 50) {
    const messages = await this.publisher.lRange(
      `chat:${roomId}:history`,
      0,
      limit - 1
    )
    return messages.map(msg => JSON.parse(msg))
  }
}
```

## レート制限

### シンプルなレート制限

```typescript
async function rateLimit(userId: string, maxRequests = 10, windowSeconds = 60): Promise<boolean> {
  const key = `ratelimit:${userId}`

  const current = await redis.incr(key)

  if (current === 1) {
    await redis.expire(key, windowSeconds)
  }

  return current <= maxRequests
}

// 使用例
app.get('/api/data', async (req, res) => {
  const userId = req.session.userId

  if (!await rateLimit(userId)) {
    return res.status(429).json({ error: 'Too many requests' })
  }

  res.json({ data: 'some data' })
})
```

### スライディングウィンドウ

```typescript
async function slidingWindowRateLimit(
  userId: string,
  maxRequests = 10,
  windowSeconds = 60
): Promise<boolean> {
  const key = `ratelimit:${userId}`
  const now = Date.now()
  const windowStart = now - windowSeconds * 1000

  // 古いエントリを削除
  await redis.zRemRangeByScore(key, 0, windowStart)

  // 現在のリクエスト数を取得
  const count = await redis.zCard(key)

  if (count >= maxRequests) {
    return false
  }

  // 新しいリクエストを追加
  await redis.zAdd(key, { score: now, value: `${now}` })
  await redis.expire(key, windowSeconds)

  return true
}
```

## トランザクション

### MULTI/EXEC

```typescript
// トランザクション開始
const multi = redis.multi()

multi.set('key1', 'value1')
multi.set('key2', 'value2')
multi.incr('counter')

// 実行
const results = await multi.exec()
console.log(results)
```

### WATCH（楽観的ロック）

```typescript
async function transferBalance(fromId: string, toId: string, amount: number) {
  const fromKey = `balance:${fromId}`
  const toKey = `balance:${toId}`

  while (true) {
    await redis.watch(fromKey)

    const balance = parseInt(await redis.get(fromKey) || '0')

    if (balance < amount) {
      await redis.unwatch()
      throw new Error('Insufficient balance')
    }

    const multi = redis.multi()
    multi.decrBy(fromKey, amount)
    multi.incrBy(toKey, amount)

    const results = await multi.exec()

    if (results) {
      // 成功
      break
    }

    // 競合が発生したので再試行
  }
}
```

## パイプライン

```typescript
// 複数のコマンドをまとめて送信
const pipeline = redis.pipeline()

pipeline.set('key1', 'value1')
pipeline.set('key2', 'value2')
pipeline.get('key1')
pipeline.incr('counter')

const results = await pipeline.exec()
console.log(results)
```

## Lua スクリプト

```typescript
// カウンターのインクリメント（原子性保証）
const script = `
  local current = redis.call('GET', KEYS[1])
  if not current then
    current = 0
  end
  local next = current + ARGV[1]
  redis.call('SET', KEYS[1], next)
  return next
`

const result = await redis.eval(script, {
  keys: ['counter'],
  arguments: ['5'],
})

console.log(result) // 5

// スクリプトのキャッシュ
const sha = await redis.scriptLoad(script)
const result2 = await redis.evalSha(sha, {
  keys: ['counter'],
  arguments: ['10'],
})

console.log(result2) // 15
```

## ベストプラクティス

1. **適切なキー命名**: `object:id:field` のような階層構造
2. **TTLの設定**: メモリ不足を防ぐため必ず設定
3. **KEYSコマンドを避ける**: 本番環境では`SCAN`を使用
4. **パイプライン活用**: 複数のコマンドをまとめて実行
5. **接続プール**: 適切な接続数を維持
6. **エラーハンドリング**: 接続エラーに対処
7. **監視**: メモリ使用量、ヒット率を監視

## 監視とメンテナンス

### メモリ使用量

```bash
# メモリ情報
INFO memory

# メモリ使用量の多いキー
MEMORY USAGE key

# メモリサンプリング
MEMORY STATS
```

### パフォーマンス

```bash
# 統計情報
INFO stats

# スロークエリログ
SLOWLOG GET 10

# クライアント一覧
CLIENT LIST
```

### 永続化

```bash
# RDB（スナップショット）
SAVE        # 同期的に保存
BGSAVE      # バックグラウンドで保存

# AOF（追記ログ）
CONFIG SET appendonly yes
BGREWRITEAOF
```

## Docker Compose での構成

```yaml
# docker-compose.yml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes --requirepass your-password

  app:
    build: .
    environment:
      - REDIS_URL=redis://:your-password@redis:6379
    depends_on:
      - redis

volumes:
  redis-data:
```

## 参考リンク

- [Redis 公式ドキュメント](https://redis.io/docs/)
- [Redis コマンドリファレンス](https://redis.io/commands/)
- [node-redis Documentation](https://github.com/redis/node-redis)
- [ioredis Documentation](https://github.com/redis/ioredis)
- [Redis University](https://university.redis.com/)
