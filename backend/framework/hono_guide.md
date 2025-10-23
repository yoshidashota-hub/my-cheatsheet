# Hono ガイド

Honoは、超高速で軽量なWebフレームワークです。

## 特徴

- **超高速**: 最速クラスのパフォーマンス
- **軽量**: 14KB以下の小さなバンドルサイズ
- **マルチランタイム対応**: Cloudflare Workers, Deno, Bun, Node.js などで動作
- **型安全**: TypeScriptで完全な型サポート
- **Express風**: 使いやすいAPI設計
- **ミドルウェア**: 豊富な組み込みミドルウェア

## インストール

### Cloudflare Workers

```bash
npm create hono@latest my-app
cd my-app
npm install
npm run dev
```

### Node.js

```bash
npm install hono
npm install -D @types/node tsx
```

### Deno

```typescript
import { Hono } from 'https://deno.land/x/hono/mod.ts'
```

### Bun

```bash
bun create hono my-app
cd my-app
bun run dev
```

## 基本的な使い方

### Hello World

```typescript
import { Hono } from 'hono'

const app = new Hono()

app.get('/', (c) => {
  return c.text('Hello Hono!')
})

export default app
```

### Node.js で実行

```typescript
import { Hono } from 'hono'
import { serve } from '@hono/node-server'

const app = new Hono()

app.get('/', (c) => {
  return c.text('Hello Hono!')
})

serve(app)
// または
// serve({ fetch: app.fetch, port: 3000 })
```

## ルーティング

### 基本的なルート

```typescript
const app = new Hono()

// GET
app.get('/', (c) => c.text('GET /'))

// POST
app.post('/posts', (c) => c.text('POST /posts'))

// PUT
app.put('/posts/:id', (c) => c.text('PUT /posts/:id'))

// DELETE
app.delete('/posts/:id', (c) => c.text('DELETE /posts/:id'))

// PATCH
app.patch('/posts/:id', (c) => c.text('PATCH /posts/:id'))

// 複数のメソッド
app.on(['GET', 'POST'], '/multi', (c) => {
  return c.text('GET or POST /multi')
})

// 全てのメソッド
app.all('/all', (c) => {
  return c.text('All methods')
})
```

### パラメータ

```typescript
// パスパラメータ
app.get('/users/:id', (c) => {
  const id = c.req.param('id')
  return c.text(`User ID: ${id}`)
})

// 複数のパラメータ
app.get('/posts/:postId/comments/:commentId', (c) => {
  const postId = c.req.param('postId')
  const commentId = c.req.param('commentId')
  return c.json({ postId, commentId })
})

// オプショナルパラメータ
app.get('/posts/:id?', (c) => {
  const id = c.req.param('id')
  return c.text(id || 'All posts')
})

// ワイルドカード
app.get('/files/*', (c) => {
  const path = c.req.param('*')
  return c.text(`File: ${path}`)
})
```

### クエリパラメータ

```typescript
app.get('/search', (c) => {
  const query = c.req.query('q')
  const page = c.req.query('page')

  // 全てのクエリパラメータ
  const queries = c.req.queries()

  return c.json({ query, page, queries })
})
```

### グループ化

```typescript
const app = new Hono()

// /api/v1 グループ
const api = app.basePath('/api/v1')

api.get('/users', (c) => c.json({ users: [] }))
api.get('/posts', (c) => c.json({ posts: [] }))

// /admin グループ
const admin = app.basePath('/admin')

admin.get('/dashboard', (c) => c.text('Admin Dashboard'))
```

### ルートのチェーン

```typescript
app
  .get('/chain', (c) => c.text('GET'))
  .post('/chain', (c) => c.text('POST'))
  .put('/chain', (c) => c.text('PUT'))
```

## レスポンス

### テキスト

```typescript
app.get('/text', (c) => {
  return c.text('Hello World')
})

// ステータスコード指定
app.get('/text', (c) => {
  return c.text('Not Found', 404)
})
```

### JSON

```typescript
app.get('/json', (c) => {
  return c.json({ message: 'Hello' })
})

// ステータスコード指定
app.get('/json', (c) => {
  return c.json({ error: 'Not Found' }, 404)
})
```

### HTML

```typescript
app.get('/html', (c) => {
  return c.html('<h1>Hello Hono!</h1>')
})
```

### リダイレクト

```typescript
app.get('/redirect', (c) => {
  return c.redirect('/new-path')
})

// 301リダイレクト
app.get('/redirect', (c) => {
  return c.redirect('/new-path', 301)
})
```

### ストリーム

```typescript
app.get('/stream', (c) => {
  return c.streamText(async (stream) => {
    for (let i = 0; i < 5; i++) {
      await stream.write(`Message ${i}\n`)
      await stream.sleep(1000)
    }
  })
})
```

### カスタムレスポンス

```typescript
app.get('/custom', (c) => {
  return new Response('Custom Response', {
    status: 200,
    headers: {
      'Content-Type': 'text/plain',
      'X-Custom-Header': 'value',
    },
  })
})
```

## リクエスト

### ボディの取得

```typescript
// JSON
app.post('/json', async (c) => {
  const body = await c.req.json()
  return c.json(body)
})

// テキスト
app.post('/text', async (c) => {
  const body = await c.req.text()
  return c.text(body)
})

// FormData
app.post('/form', async (c) => {
  const body = await c.req.formData()
  const name = body.get('name')
  return c.text(`Name: ${name}`)
})

// ArrayBuffer
app.post('/binary', async (c) => {
  const body = await c.req.arrayBuffer()
  return c.json({ size: body.byteLength })
})
```

### ヘッダー

```typescript
app.get('/headers', (c) => {
  const userAgent = c.req.header('User-Agent')
  const auth = c.req.header('Authorization')

  return c.json({ userAgent, auth })
})

// ヘッダーの設定
app.get('/set-header', (c) => {
  c.header('X-Custom-Header', 'value')
  return c.text('Header set')
})
```

## ミドルウェア

### カスタムミドルウェア

```typescript
// ロガー
app.use('*', async (c, next) => {
  console.log(`[${c.req.method}] ${c.req.url}`)
  await next()
})

// 認証
app.use('/admin/*', async (c, next) => {
  const token = c.req.header('Authorization')

  if (!token) {
    return c.json({ error: 'Unauthorized' }, 401)
  }

  await next()
})

// タイミング
app.use('*', async (c, next) => {
  const start = Date.now()
  await next()
  const ms = Date.now() - start
  c.header('X-Response-Time', `${ms}ms`)
})
```

### 組み込みミドルウェア

#### Logger

```typescript
import { logger } from 'hono/logger'

app.use('*', logger())
```

#### CORS

```typescript
import { cors } from 'hono/cors'

app.use('*', cors({
  origin: 'https://example.com',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowHeaders: ['Content-Type', 'Authorization'],
  maxAge: 600,
  credentials: true,
}))
```

#### JWT

```typescript
import { jwt } from 'hono/jwt'

app.use('/api/*', jwt({
  secret: 'my-secret-key',
}))

app.get('/api/protected', (c) => {
  const payload = c.get('jwtPayload')
  return c.json(payload)
})
```

#### Basic Auth

```typescript
import { basicAuth } from 'hono/basic-auth'

app.use('/admin/*', basicAuth({
  username: 'admin',
  password: 'secret',
}))
```

#### Bearer Auth

```typescript
import { bearerAuth } from 'hono/bearer-auth'

app.use('/api/*', bearerAuth({
  token: 'your-secret-token',
}))
```

#### Pretty JSON

```typescript
import { prettyJSON } from 'hono/pretty-json'

app.use('*', prettyJSON())
```

#### Secure Headers

```typescript
import { secureHeaders } from 'hono/secure-headers'

app.use('*', secureHeaders())
```

#### ETag

```typescript
import { etag } from 'hono/etag'

app.use('*', etag())
```

#### Cache

```typescript
import { cache } from 'hono/cache'

app.use('*', cache({
  cacheName: 'my-cache',
  cacheControl: 'max-age=3600',
}))
```

## バリデーション

### Zod Validator

```bash
npm install @hono/zod-validator zod
```

```typescript
import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

const schema = z.object({
  name: z.string(),
  email: z.string().email(),
  age: z.number().int().positive(),
})

app.post('/users', zValidator('json', schema), async (c) => {
  const data = c.req.valid('json')
  // data は自動的に型推論される
  return c.json({ success: true, data })
})

// クエリパラメータのバリデーション
const querySchema = z.object({
  page: z.string().transform(Number),
  limit: z.string().transform(Number),
})

app.get('/posts', zValidator('query', querySchema), (c) => {
  const { page, limit } = c.req.valid('query')
  return c.json({ page, limit })
})

// パラメータのバリデーション
const paramSchema = z.object({
  id: z.string().uuid(),
})

app.get('/users/:id', zValidator('param', paramSchema), (c) => {
  const { id } = c.req.valid('param')
  return c.json({ id })
})
```

## エラーハンドリング

```typescript
import { HTTPException } from 'hono/http-exception'

// カスタムエラー
app.get('/error', (c) => {
  throw new HTTPException(404, { message: 'Not Found' })
})

// グローバルエラーハンドラ
app.onError((err, c) => {
  if (err instanceof HTTPException) {
    return c.json(
      { error: err.message },
      err.status
    )
  }

  console.error(err)
  return c.json({ error: 'Internal Server Error' }, 500)
})

// Not Found
app.notFound((c) => {
  return c.json({ error: 'Not Found' }, 404)
})
```

## JSX/TSX サポート

```typescript
import { Hono } from 'hono'
import { jsxRenderer } from 'hono/jsx-renderer'

const app = new Hono()

app.get('*', jsxRenderer(({ children }) => {
  return (
    <html>
      <head>
        <title>My App</title>
      </head>
      <body>{children}</body>
    </html>
  )
}))

app.get('/', (c) => {
  return c.render(
    <div>
      <h1>Hello Hono!</h1>
      <p>Welcome to my app</p>
    </div>
  )
})
```

## RPC (hono/client)

### サーバー側

```typescript
// server.ts
import { Hono } from 'hono'
import { z } from 'zod'
import { zValidator } from '@hono/zod-validator'

const app = new Hono()

const route = app
  .get('/posts', (c) => {
    return c.json([
      { id: 1, title: 'Post 1' },
      { id: 2, title: 'Post 2' },
    ])
  })
  .post('/posts', zValidator('json', z.object({
    title: z.string(),
    content: z.string(),
  })), (c) => {
    const data = c.req.valid('json')
    return c.json({ id: 3, ...data })
  })

export type AppType = typeof route

export default app
```

### クライアント側

```typescript
// client.ts
import { hc } from 'hono/client'
import type { AppType } from './server'

const client = hc<AppType>('http://localhost:3000')

// GET
const res = await client.posts.$get()
const posts = await res.json()
console.log(posts) // 型推論される

// POST
const res2 = await client.posts.$post({
  json: {
    title: 'New Post',
    content: 'Content here',
  },
})
const newPost = await res2.json()
console.log(newPost) // 型推論される
```

## 実践例

### RESTful API

```typescript
import { Hono } from 'hono'
import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

const app = new Hono()

// スキーマ定義
const createUserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
})

const updateUserSchema = z.object({
  name: z.string().min(1).optional(),
  email: z.string().email().optional(),
})

// ユーザー一覧
app.get('/api/users', async (c) => {
  const users = await db.user.findMany()
  return c.json(users)
})

// ユーザー詳細
app.get('/api/users/:id', async (c) => {
  const id = c.req.param('id')
  const user = await db.user.findUnique({ where: { id } })

  if (!user) {
    throw new HTTPException(404, { message: 'User not found' })
  }

  return c.json(user)
})

// ユーザー作成
app.post('/api/users', zValidator('json', createUserSchema), async (c) => {
  const data = c.req.valid('json')
  const user = await db.user.create({ data })
  return c.json(user, 201)
})

// ユーザー更新
app.put('/api/users/:id', zValidator('json', updateUserSchema), async (c) => {
  const id = c.req.param('id')
  const data = c.req.valid('json')

  const user = await db.user.update({
    where: { id },
    data,
  })

  return c.json(user)
})

// ユーザー削除
app.delete('/api/users/:id', async (c) => {
  const id = c.req.param('id')
  await db.user.delete({ where: { id } })
  return c.json({ success: true })
})

export default app
```

### 認証付きAPI

```typescript
import { Hono } from 'hono'
import { jwt, sign, verify } from 'hono/jwt'
import { HTTPException } from 'hono/http-exception'

const app = new Hono()

// ログイン
app.post('/auth/login', async (c) => {
  const { email, password } = await c.req.json()

  const user = await db.user.findUnique({ where: { email } })

  if (!user || !await verifyPassword(password, user.password)) {
    throw new HTTPException(401, { message: 'Invalid credentials' })
  }

  const token = await sign(
    { sub: user.id, exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 },
    'secret'
  )

  return c.json({ token })
})

// 認証ミドルウェア
app.use('/api/*', jwt({ secret: 'secret' }))

// 認証が必要なエンドポイント
app.get('/api/me', async (c) => {
  const payload = c.get('jwtPayload')
  const user = await db.user.findUnique({ where: { id: payload.sub } })
  return c.json(user)
})

export default app
```

### ファイルアップロード

```typescript
app.post('/upload', async (c) => {
  const body = await c.req.formData()
  const file = body.get('file') as File

  if (!file) {
    throw new HTTPException(400, { message: 'No file provided' })
  }

  // ファイルの保存処理
  const buffer = await file.arrayBuffer()
  // ... 保存ロジック

  return c.json({
    success: true,
    filename: file.name,
    size: file.size,
  })
})
```

### WebSocket (Cloudflare Workers)

```typescript
import { Hono } from 'hono'

const app = new Hono()

app.get('/ws', (c) => {
  const upgradeHeader = c.req.header('Upgrade')

  if (upgradeHeader !== 'websocket') {
    return c.text('Expected websocket', 400)
  }

  const webSocketPair = new WebSocketPair()
  const [client, server] = Object.values(webSocketPair)

  server.accept()

  server.addEventListener('message', (event) => {
    server.send(`Echo: ${event.data}`)
  })

  return new Response(null, {
    status: 101,
    webSocket: client,
  })
})

export default app
```

## Cloudflare Workers での使用

```typescript
// wrangler.toml
name = "my-app"
main = "src/index.ts"
compatibility_date = "2023-01-01"

[vars]
API_KEY = "your-api-key"
```

```typescript
// src/index.ts
import { Hono } from 'hono'

type Bindings = {
  API_KEY: string
  DB: D1Database
  BUCKET: R2Bucket
}

const app = new Hono<{ Bindings: Bindings }>()

// 環境変数
app.get('/env', (c) => {
  return c.text(c.env.API_KEY)
})

// D1 Database
app.get('/users', async (c) => {
  const { results } = await c.env.DB.prepare('SELECT * FROM users').all()
  return c.json(results)
})

// R2 Bucket
app.get('/files/:key', async (c) => {
  const key = c.req.param('key')
  const object = await c.env.BUCKET.get(key)

  if (!object) {
    return c.notFound()
  }

  return new Response(object.body)
})

export default app
```

## Deno での使用

```typescript
import { Hono } from 'https://deno.land/x/hono/mod.ts'

const app = new Hono()

app.get('/', (c) => c.text('Hello Deno!'))

Deno.serve(app.fetch)
```

## Bun での使用

```typescript
import { Hono } from 'hono'

const app = new Hono()

app.get('/', (c) => c.text('Hello Bun!'))

export default {
  port: 3000,
  fetch: app.fetch,
}
```

## テスト

```typescript
import { describe, it, expect } from 'vitest'
import app from './app'

describe('API Tests', () => {
  it('GET /', async () => {
    const res = await app.request('/')
    expect(res.status).toBe(200)
    expect(await res.text()).toBe('Hello Hono!')
  })

  it('POST /users', async () => {
    const res = await app.request('/users', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: 'John',
        email: 'john@example.com',
      }),
    })

    expect(res.status).toBe(201)
    const data = await res.json()
    expect(data.name).toBe('John')
  })
})
```

## ベストプラクティス

1. **型定義**: TypeScriptの型を活用
2. **バリデーション**: Zodで入力を検証
3. **エラーハンドリング**: 適切なHTTPステータスコード
4. **ミドルウェア**: 共通処理をミドルウェア化
5. **ルートの整理**: basePath でグループ化
6. **セキュリティ**: secureHeaders ミドルウェアを使用
7. **CORS設定**: 適切なCORS設定

## パフォーマンス比較

| Framework | Requests/sec |
|-----------|--------------|
| Hono | ~400,000 |
| Express | ~15,000 |
| Fastify | ~50,000 |
| Koa | ~30,000 |

※ Cloudflare Workers環境での測定値

## 参考リンク

- [Hono 公式ドキュメント](https://hono.dev/)
- [Hono GitHub](https://github.com/honojs/hono)
- [Hono Examples](https://github.com/honojs/examples)
- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
