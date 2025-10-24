# CORS（Cross-Origin Resource Sharing）完全ガイド

## 目次
- [CORSとは](#corsとは)
- [Express](#express)
- [Fastify](#fastify)
- [Next.js](#nextjs)
- [設定オプション](#設定オプション)
- [プリフライトリクエスト](#プリフライトリクエスト)

---

## CORSとは

異なるオリジン間でのリソース共有を制御するセキュリティ機能。

### オリジンとは

`プロトコル://ドメイン:ポート` の組み合わせ

- `https://example.com`
- `https://example.com:3000`
- `http://localhost:3000`

---

## Express

### インストール

```bash
npm install cors
```

### 基本設定

```typescript
import express from 'express'
import cors from 'cors'

const app = express()

// 全オリジンを許可（開発環境のみ）
app.use(cors())

// 特定オリジンのみ許可
app.use(cors({
  origin: 'https://example.com'
}))

// 複数オリジン
app.use(cors({
  origin: ['https://example.com', 'https://app.example.com']
}))

// 動的オリジン
app.use(cors({
  origin: (origin, callback) => {
    const allowedOrigins = ['https://example.com']
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true)
    } else {
      callback(new Error('Not allowed by CORS'))
    }
  }
}))
```

---

## Fastify

### インストール

```bash
npm install @fastify/cors
```

### 基本設定

```typescript
import fastify from 'fastify'
import cors from '@fastify/cors'

const server = fastify()

server.register(cors, {
  origin: true // 全オリジン許可
})

// 特定オリジン
server.register(cors, {
  origin: 'https://example.com'
})

// 複数オリジン
server.register(cors, {
  origin: ['https://example.com', 'https://app.example.com']
})
```

---

## Next.js

### API Routes

```typescript
// pages/api/data.ts
import type { NextApiRequest, NextApiResponse } from 'next'

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // CORSヘッダー設定
  res.setHeader('Access-Control-Allow-Credentials', 'true')
  res.setHeader('Access-Control-Allow-Origin', 'https://example.com')
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE')
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Content-Type, Authorization'
  )

  // プリフライト対応
  if (req.method === 'OPTIONS') {
    res.status(200).end()
    return
  }

  // 通常の処理
  res.status(200).json({ data: 'success' })
}
```

---

## 設定オプション

### 詳細設定

```typescript
app.use(cors({
  // オリジン
  origin: 'https://example.com',

  // メソッド
  methods: ['GET', 'POST', 'PUT', 'DELETE'],

  // 許可ヘッダー
  allowedHeaders: ['Content-Type', 'Authorization'],

  // 公開ヘッダー
  exposedHeaders: ['X-Total-Count'],

  // 認証情報
  credentials: true,

  // Preflightキャッシュ時間（秒）
  maxAge: 86400
}))
```

---

## プリフライトリクエスト

OPTIONSリクエストで事前確認。

### 対象リクエスト
- PUT, DELETE, PATCH
- カスタムヘッダー使用時
- Content-Type が `application/json` など

### レスポンス例

```
OPTIONS /api/data HTTP/1.1
Origin: https://example.com

HTTP/1.1 200 OK
Access-Control-Allow-Origin: https://example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Max-Age: 86400
```

---

## セキュリティ

### 本番環境設定

```typescript
// ✗ 開発環境のみ
app.use(cors({ origin: '*' }))

// ○ 本番環境
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(','),
  credentials: true
}))
```

---

## 参考リンク

- [CORS - MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
