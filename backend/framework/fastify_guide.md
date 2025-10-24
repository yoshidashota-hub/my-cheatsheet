# Fastify 完全ガイド

## 目次
- [Fastifyとは](#fastifyとは)
- [セットアップ](#セットアップ)
- [ルーティング](#ルーティング)
- [プラグイン](#プラグイン)
- [バリデーション](#バリデーション)
- [フック](#フック)
- [データベース連携](#データベース連携)

---

## Fastifyとは

高速で低オーバーヘッドなNode.jsフレームワーク。

### 特徴
- ⚡ 超高速（Expressより2倍高速）
- 📝 TypeScript完全サポート
- 🔒 JSONスキーマベースのバリデーション
- 🔌 プラグインアーキテクチャ

---

## セットアップ

### インストール

```bash
npm init -y
npm install fastify
npm install -D @types/node typescript
```

### 基本的なサーバー

```typescript
import fastify from 'fastify'

const server = fastify({ logger: true })

server.get('/', async (request, reply) => {
  return { hello: 'world' }
})

server.listen({ port: 3000 }, (err, address) => {
  if (err) throw err
  console.log(`Server listening at ${address}`)
})
```

---

## ルーティング

### 基本的なルート

```typescript
// GET
server.get('/users', async (request, reply) => {
  return { users: [] }
})

// POST
server.post('/users', async (request, reply) => {
  const body = request.body
  return { created: true }
})

// PUT
server.put('/users/:id', async (request, reply) => {
  const { id } = request.params
  return { updated: true }
})

// DELETE
server.delete('/users/:id', async (request, reply) => {
  const { id } = request.params
  return { deleted: true }
})
```

### パラメータ

```typescript
interface Params {
  id: string
}

interface Query {
  page?: number
  limit?: number
}

server.get<{ Params: Params; Querystring: Query }>(
  '/users/:id',
  async (request, reply) => {
    const { id } = request.params
    const { page = 1, limit = 10 } = request.query
    return { id, page, limit }
  }
)
```

---

## プラグイン

### CORS

```bash
npm install @fastify/cors
```

```typescript
import cors from '@fastify/cors'

server.register(cors, {
  origin: true
})
```

### JWT

```bash
npm install @fastify/jwt
```

```typescript
import jwt from '@fastify/jwt'

server.register(jwt, {
  secret: 'your-secret-key'
})

// 保護されたルート
server.get('/protected', {
  onRequest: [server.authenticate]
}, async (request, reply) => {
  return { user: request.user }
})
```

---

## バリデーション

### JSONスキーマ

```typescript
const schema = {
  body: {
    type: 'object',
    required: ['email', 'password'],
    properties: {
      email: { type: 'string', format: 'email' },
      password: { type: 'string', minLength: 6 }
    }
  }
}

server.post('/register', { schema }, async (request, reply) => {
  const { email, password } = request.body
  return { success: true }
})
```

---

## フック

### リクエストフック

```typescript
server.addHook('onRequest', async (request, reply) => {
  console.log('Request received')
})

server.addHook('preParsing', async (request, reply, payload) => {
  // ペイロード解析前
})

server.addHook('preHandler', async (request, reply) => {
  // ハンドラー実行前
})
```

---

## データベース連携

### Prisma

```typescript
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

server.get('/users', async () => {
  return await prisma.user.findMany()
})
```

---

## 参考リンク

- [Fastify Documentation](https://www.fastify.io/)
