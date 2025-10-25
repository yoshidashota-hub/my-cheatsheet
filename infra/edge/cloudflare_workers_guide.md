# Cloudflare Workers 完全ガイド

## 目次
- [Cloudflare Workersとは](#cloudflare-workersとは)
- [セットアップ](#セットアップ)
- [基本的な Worker](#基本的な-worker)
- [KV Storage](#kv-storage)
- [Durable Objects](#durable-objects)
- [D1 Database](#d1-database)
- [R2 Storage](#r2-storage)
- [環境変数とシークレット](#環境変数とシークレット)
- [Honoフレームワーク](#honoフレームワーク)
- [ベストプラクティス](#ベストプラクティス)

---

## Cloudflare Workersとは

Cloudflare のエッジコンピューティングプラットフォーム。世界中の CDN エッジで JavaScript/TypeScript コードを実行。

### 特徴

- ⚡ 超低レイテンシ: エッジで実行（<1ms起動）
- 🌍 グローバル配信: 275+ データセンター
- 💰 無料枠: 100,000 リクエスト/日
- 🔒 セキュア: V8 Isolate で実行
- 📦 小さいコード: 1MB まで
- 🚀 コールドスタートなし

### ユースケース

```
✓ API エンドポイント
✓ リバースプロキシ
✓ A/B テスト
✓ 認証ゲートウェイ
✓ 画像リサイズ
✓ エッジキャッシング
✓ ボット対策
```

---

## セットアップ

### Wrangler CLI インストール

```bash
npm install -g wrangler

# バージョン確認
wrangler --version

# ログイン
wrangler login
```

### プロジェクト作成

```bash
# 新規プロジェクト作成
npm create cloudflare@latest my-worker

# テンプレート選択
# - Hello World worker
# - Common Worker Examples
# - Framework Starter (Hono, Remix, etc.)

cd my-worker

# 開発サーバー起動
npm run dev

# デプロイ
npm run deploy
```

---

## 基本的な Worker

### Hello World

```typescript
// src/index.ts
export default {
  async fetch(request: Request): Promise<Response> {
    return new Response('Hello, Cloudflare Workers!', {
      headers: {
        'content-type': 'text/plain'
      }
    })
  }
}
```

### JSON API

```typescript
export default {
  async fetch(request: Request): Promise<Response> {
    const data = {
      message: 'Hello, World!',
      timestamp: new Date().toISOString()
    }

    return Response.json(data)
  }
}
```

### ルーティング

```typescript
export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url)

    if (url.pathname === '/api/users' && request.method === 'GET') {
      return Response.json({ users: [] })
    }

    if (url.pathname.startsWith('/api/users/') && request.method === 'GET') {
      const userId = url.pathname.split('/').pop()
      return Response.json({ user: { id: userId } })
    }

    if (url.pathname === '/api/users' && request.method === 'POST') {
      const body = await request.json()
      return Response.json({ created: body }, { status: 201 })
    }

    return new Response('Not Found', { status: 404 })
  }
}
```

### リクエスト処理

```typescript
export default {
  async fetch(request: Request): Promise<Response> {
    // URL パース
    const url = new URL(request.url)
    const pathname = url.pathname
    const searchParams = url.searchParams

    // ヘッダー取得
    const userAgent = request.headers.get('User-Agent')
    const authorization = request.headers.get('Authorization')

    // メソッド
    const method = request.method

    // ボディ取得
    let body
    if (method === 'POST' || method === 'PUT') {
      const contentType = request.headers.get('Content-Type')

      if (contentType?.includes('application/json')) {
        body = await request.json()
      } else if (contentType?.includes('text/')) {
        body = await request.text()
      } else {
        body = await request.arrayBuffer()
      }
    }

    return Response.json({
      method,
      pathname,
      params: Object.fromEntries(searchParams),
      userAgent,
      body
    })
  }
}
```

### CORS 対応

```typescript
function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
  }
}

export default {
  async fetch(request: Request): Promise<Response> {
    // プリフライトリクエスト
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: corsHeaders()
      })
    }

    // 実際の処理
    const data = { message: 'Hello' }

    return Response.json(data, {
      headers: corsHeaders()
    })
  }
}
```

---

## KV Storage

### KV Namespace 作成

```bash
# KV Namespace 作成
wrangler kv:namespace create MY_KV

# プレビュー用
wrangler kv:namespace create MY_KV --preview
```

```toml
# wrangler.toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[kv_namespaces]]
binding = "MY_KV"
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
preview_id = "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
```

### KV の使用

```typescript
interface Env {
  MY_KV: KVNamespace
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)

    // GET: KVから取得
    if (request.method === 'GET') {
      const key = url.searchParams.get('key')
      if (!key) {
        return new Response('Key required', { status: 400 })
      }

      const value = await env.MY_KV.get(key)

      if (!value) {
        return new Response('Not found', { status: 404 })
      }

      return new Response(value)
    }

    // POST: KVに保存
    if (request.method === 'POST') {
      const { key, value } = await request.json() as { key: string; value: string }

      await env.MY_KV.put(key, value, {
        expirationTtl: 3600 // 1時間後に期限切れ
      })

      return Response.json({ success: true })
    }

    // DELETE: KVから削除
    if (request.method === 'DELETE') {
      const key = url.searchParams.get('key')
      if (!key) {
        return new Response('Key required', { status: 400 })
      }

      await env.MY_KV.delete(key)
      return Response.json({ success: true })
    }

    return new Response('Method not allowed', { status: 405 })
  }
}
```

### KV メソッド

```typescript
// 取得
const value = await env.MY_KV.get('key')
const json = await env.MY_KV.get('key', { type: 'json' })
const buffer = await env.MY_KV.get('key', { type: 'arrayBuffer' })

// 保存
await env.MY_KV.put('key', 'value')
await env.MY_KV.put('key', JSON.stringify(data))
await env.MY_KV.put('key', 'value', {
  expirationTtl: 3600,           // 秒単位の有効期限
  expiration: 1735689600,        // Unix timestamp
  metadata: { userId: '123' }    // メタデータ
})

// 削除
await env.MY_KV.delete('key')

// リスト取得
const list = await env.MY_KV.list({ prefix: 'user:' })
for (const key of list.keys) {
  console.log(key.name)
}
```

---

## Durable Objects

### Durable Object 定義

```typescript
// src/counter.ts
export class Counter {
  private state: DurableObjectState
  private count: number = 0

  constructor(state: DurableObjectState) {
    this.state = state
  }

  async fetch(request: Request): Promise<Response> {
    // 初回ロード時に復元
    if (this.count === 0) {
      this.count = (await this.state.storage.get<number>('count')) || 0
    }

    const url = new URL(request.url)

    if (url.pathname === '/increment') {
      this.count++
      await this.state.storage.put('count', this.count)
      return Response.json({ count: this.count })
    }

    if (url.pathname === '/decrement') {
      this.count--
      await this.state.storage.put('count', this.count)
      return Response.json({ count: this.count })
    }

    if (url.pathname === '/get') {
      return Response.json({ count: this.count })
    }

    return new Response('Not found', { status: 404 })
  }
}
```

```toml
# wrangler.toml
[[durable_objects.bindings]]
name = "COUNTER"
class_name = "Counter"
script_name = "my-worker"

[[migrations]]
tag = "v1"
new_classes = ["Counter"]
```

### Durable Object の使用

```typescript
// src/index.ts
import { Counter } from './counter'

interface Env {
  COUNTER: DurableObjectNamespace
}

export { Counter }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)
    const userId = url.searchParams.get('userId') || 'default'

    // Durable Object ID 取得
    const id = env.COUNTER.idFromName(userId)

    // Durable Object Stub 取得
    const stub = env.COUNTER.get(id)

    // リクエスト転送
    return stub.fetch(request)
  }
}
```

### チャットルーム例

```typescript
export class ChatRoom {
  private state: DurableObjectState
  private sessions: Set<WebSocket> = new Set()

  constructor(state: DurableObjectState) {
    this.state = state
  }

  async fetch(request: Request): Promise<Response> {
    // WebSocket アップグレード
    if (request.headers.get('Upgrade') === 'websocket') {
      const pair = new WebSocketPair()
      const [client, server] = Object.values(pair)

      this.handleSession(server)

      return new Response(null, {
        status: 101,
        webSocket: client
      })
    }

    return new Response('Expected WebSocket', { status: 400 })
  }

  async handleSession(ws: WebSocket) {
    ws.accept()
    this.sessions.add(ws)

    ws.addEventListener('message', (event) => {
      // 全クライアントにブロードキャスト
      for (const session of this.sessions) {
        session.send(event.data)
      }
    })

    ws.addEventListener('close', () => {
      this.sessions.delete(ws)
    })
  }
}
```

---

## D1 Database

### D1 データベース作成

```bash
# データベース作成
wrangler d1 create my-database

# マイグレーション実行
wrangler d1 execute my-database --file=schema.sql
```

```toml
# wrangler.toml
[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### スキーマ定義

```sql
-- schema.sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  published BOOLEAN DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
```

### D1 の使用

```typescript
interface Env {
  DB: D1Database
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)

    // ユーザー一覧取得
    if (url.pathname === '/api/users' && request.method === 'GET') {
      const { results } = await env.DB.prepare(
        'SELECT * FROM users ORDER BY created_at DESC'
      ).all()

      return Response.json({ users: results })
    }

    // ユーザー作成
    if (url.pathname === '/api/users' && request.method === 'POST') {
      const { email, name } = await request.json() as { email: string; name: string }

      const result = await env.DB.prepare(
        'INSERT INTO users (email, name) VALUES (?, ?)'
      ).bind(email, name).run()

      return Response.json({ id: result.meta.last_row_id }, { status: 201 })
    }

    // ユーザーの投稿取得
    if (url.pathname.startsWith('/api/users/') && url.pathname.endsWith('/posts')) {
      const userId = url.pathname.split('/')[3]

      const { results } = await env.DB.prepare(`
        SELECT posts.*, users.name as author_name
        FROM posts
        JOIN users ON posts.user_id = users.id
        WHERE posts.user_id = ?
        ORDER BY posts.created_at DESC
      `).bind(userId).all()

      return Response.json({ posts: results })
    }

    return new Response('Not found', { status: 404 })
  }
}
```

### トランザクション

```typescript
const result = await env.DB.batch([
  env.DB.prepare('INSERT INTO users (email, name) VALUES (?, ?)').bind('user@example.com', 'User'),
  env.DB.prepare('INSERT INTO posts (user_id, title) VALUES (?, ?)').bind(1, 'Post 1'),
  env.DB.prepare('INSERT INTO posts (user_id, title) VALUES (?, ?)').bind(1, 'Post 2')
])
```

---

## R2 Storage

### R2 バケット作成

```bash
# バケット作成
wrangler r2 bucket create my-bucket
```

```toml
# wrangler.toml
[[r2_buckets]]
binding = "MY_BUCKET"
bucket_name = "my-bucket"
```

### R2 の使用

```typescript
interface Env {
  MY_BUCKET: R2Bucket
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)
    const key = url.pathname.slice(1) // 先頭の / を除去

    // ファイルアップロード
    if (request.method === 'PUT') {
      const body = await request.arrayBuffer()

      await env.MY_BUCKET.put(key, body, {
        httpMetadata: {
          contentType: request.headers.get('Content-Type') || 'application/octet-stream'
        }
      })

      return Response.json({ success: true, key })
    }

    // ファイル取得
    if (request.method === 'GET') {
      const object = await env.MY_BUCKET.get(key)

      if (!object) {
        return new Response('Not found', { status: 404 })
      }

      return new Response(object.body, {
        headers: {
          'Content-Type': object.httpMetadata?.contentType || 'application/octet-stream',
          'ETag': object.httpEtag
        }
      })
    }

    // ファイル削除
    if (request.method === 'DELETE') {
      await env.MY_BUCKET.delete(key)
      return Response.json({ success: true })
    }

    // ファイル一覧
    if (request.method === 'GET' && key === '') {
      const list = await env.MY_BUCKET.list()

      return Response.json({
        objects: list.objects.map(obj => ({
          key: obj.key,
          size: obj.size,
          uploaded: obj.uploaded
        }))
      })
    }

    return new Response('Method not allowed', { status: 405 })
  }
}
```

---

## 環境変数とシークレット

### wrangler.toml

```toml
[vars]
ENVIRONMENT = "production"
API_URL = "https://api.example.com"
```

### シークレット設定

```bash
# シークレット設定
wrangler secret put API_KEY

# シークレット一覧
wrangler secret list

# シークレット削除
wrangler secret delete API_KEY
```

### 使用例

```typescript
interface Env {
  ENVIRONMENT: string
  API_URL: string
  API_KEY: string
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const response = await fetch(env.API_URL, {
      headers: {
        'Authorization': `Bearer ${env.API_KEY}`
      }
    })

    return Response.json({
      environment: env.ENVIRONMENT,
      data: await response.json()
    })
  }
}
```

---

## Honoフレームワーク

### セットアップ

```bash
npm create hono@latest my-app
cd my-app
npm install
npm run dev
```

### 基本的な使用

```typescript
import { Hono } from 'hono'

const app = new Hono()

app.get('/', (c) => {
  return c.text('Hello, Hono!')
})

app.get('/api/users', (c) => {
  return c.json({ users: [] })
})

app.post('/api/users', async (c) => {
  const body = await c.req.json()
  return c.json({ created: body }, 201)
})

export default app
```

### ルーティング

```typescript
import { Hono } from 'hono'

const app = new Hono()

// パスパラメータ
app.get('/users/:id', (c) => {
  const id = c.req.param('id')
  return c.json({ user: { id } })
})

// クエリパラメータ
app.get('/search', (c) => {
  const query = c.req.query('q')
  return c.json({ query })
})

// グループルーティング
const api = app.basePath('/api')

api.get('/users', (c) => c.json({ users: [] }))
api.post('/users', async (c) => {
  const body = await c.req.json()
  return c.json(body, 201)
})

export default app
```

### ミドルウェア

```typescript
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { bearerAuth } from 'hono/bearer-auth'

const app = new Hono()

// ロガー
app.use('*', logger())

// CORS
app.use('*', cors())

// 認証
app.use('/api/*', bearerAuth({ token: 'secret-token' }))

app.get('/api/protected', (c) => {
  return c.json({ message: 'Protected route' })
})

export default app
```

### D1統合

```typescript
import { Hono } from 'hono'

type Bindings = {
  DB: D1Database
}

const app = new Hono<{ Bindings: Bindings }>()

app.get('/users', async (c) => {
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM users'
  ).all()

  return c.json({ users: results })
})

app.post('/users', async (c) => {
  const { email, name } = await c.req.json()

  const result = await c.env.DB.prepare(
    'INSERT INTO users (email, name) VALUES (?, ?)'
  ).bind(email, name).run()

  return c.json({ id: result.meta.last_row_id }, 201)
})

export default app
```

---

## ベストプラクティス

### 1. エラーハンドリング

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      // 処理
      return Response.json({ success: true })
    } catch (error) {
      console.error('Error:', error)
      return Response.json(
        { error: 'Internal server error' },
        { status: 500 }
      )
    }
  }
}
```

### 2. キャッシング

```typescript
export default {
  async fetch(request: Request): Promise<Response> {
    const cacheKey = new Request(request.url, request)
    const cache = caches.default

    // キャッシュチェック
    let response = await cache.match(cacheKey)

    if (response) {
      return response
    }

    // データ取得
    response = await fetch('https://api.example.com/data')

    // キャッシュに保存
    const responseToCache = response.clone()
    await cache.put(cacheKey, responseToCache)

    return response
  }
}
```

### 3. レート制限

```typescript
interface Env {
  RATE_LIMITER: KVNamespace
}

async function rateLimit(ip: string, env: Env): Promise<boolean> {
  const key = `rate_limit:${ip}`
  const current = await env.RATE_LIMITER.get(key)

  if (current && parseInt(current) >= 100) {
    return false // レート制限超過
  }

  const newCount = current ? parseInt(current) + 1 : 1
  await env.RATE_LIMITER.put(key, newCount.toString(), { expirationTtl: 60 })

  return true
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const ip = request.headers.get('CF-Connecting-IP') || 'unknown'

    if (!(await rateLimit(ip, env))) {
      return new Response('Too many requests', { status: 429 })
    }

    return Response.json({ success: true })
  }
}
```

### 4. 型安全性

```typescript
// types.ts
export interface User {
  id: number
  email: string
  name: string
}

export interface Env {
  DB: D1Database
  MY_KV: KVNamespace
  API_KEY: string
}

// index.ts
import { User, Env } from './types'

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { results } = await env.DB.prepare(
      'SELECT * FROM users'
    ).all<User>()

    return Response.json({ users: results })
  }
}
```

---

## 参考リンク

- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [Hono Framework](https://hono.dev/)
- [D1 Database](https://developers.cloudflare.com/d1/)
