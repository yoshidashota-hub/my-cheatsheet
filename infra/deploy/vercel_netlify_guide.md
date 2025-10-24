# Vercel & Netlify デプロイガイド

## 目次
- [Vercel](#vercel)
- [Netlify](#netlify)
- [比較](#比較)
- [環境変数](#環境変数)
- [カスタムドメイン](#カスタムドメイン)
- [プレビューデプロイ](#プレビューデプロイ)
- [ベストプラクティス](#ベストプラクティス)

---

## Vercel

Next.js開発元が提供するホスティングプラットフォーム。Next.jsに最適化。

### セットアップ

```bash
# Vercel CLIインストール
npm install -g vercel

# ログイン
vercel login

# デプロイ
vercel

# 本番デプロイ
vercel --prod
```

### Gitデプロイ

1. GitHubリポジトリを接続
2. 自動デプロイ設定
   - `main` ブランチ → 本番環境
   - その他のブランチ → プレビュー環境

### vercel.json 設定

```json
{
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "devCommand": "npm run dev",
  "installCommand": "npm install",
  "framework": "vite",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        }
      ]
    }
  ]
}
```

### Next.js デプロイ

```json
// next.config.js
module.exports = {
  images: {
    domains: ['example.com']
  },
  env: {
    CUSTOM_KEY: process.env.CUSTOM_KEY
  }
}
```

### Edge Functions

```typescript
// pages/api/hello.ts
import type { NextRequest } from 'next/server'

export const config = {
  runtime: 'edge'
}

export default function handler(req: NextRequest) {
  return new Response(
    JSON.stringify({ message: 'Hello from Edge' }),
    {
      status: 200,
      headers: {
        'content-type': 'application/json'
      }
    }
  )
}
```

---

## Netlify

Jamstackに特化したホスティングプラットフォーム。

### セットアップ

```bash
# Netlify CLI インストール
npm install -g netlify-cli

# ログイン
netlify login

# 初期化
netlify init

# デプロイ
netlify deploy

# 本番デプロイ
netlify deploy --prod
```

### netlify.toml 設定

```toml
[build]
  command = "npm run build"
  publish = "dist"
  functions = "netlify/functions"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
    X-XSS-Protection = "1; mode=block"

[dev]
  command = "npm run dev"
  port = 3000
  targetPort = 3000
```

### ビルド設定例

```toml
# React / Vite
[build]
  command = "npm run build"
  publish = "dist"

# Next.js
[build]
  command = "npm run build"
  publish = ".next"

# Vue
[build]
  command = "npm run build"
  publish = "dist"
```

### Netlify Functions

```typescript
// netlify/functions/hello.ts
import { Handler } from '@netlify/functions'

export const handler: Handler = async (event, context) => {
  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'Hello from Netlify' })
  }
}
```

### フォーム処理

```html
<form name="contact" method="POST" data-netlify="true">
  <input type="hidden" name="form-name" value="contact" />
  <input type="email" name="email" required />
  <textarea name="message" required></textarea>
  <button type="submit">Send</button>
</form>
```

---

## 比較

| 特徴 | Vercel | Netlify |
|------|--------|---------|
| Next.js最適化 | ◎ | ○ |
| Edge Functions | ○ | ○ |
| フォーム処理 | - | ○ |
| 分析 | ○ | ○ |
| 無料枠ビルド時間 | 6,000分/月 | 300分/月 |
| 帯域幅（無料） | 100GB | 100GB |
| カスタムドメイン | ○ | ○ |
| 価格 | $20~/月 | $19~/月 |

---

## 環境変数

### Vercel

```bash
# CLIで設定
vercel env add VITE_API_URL

# .env.local（ローカル開発のみ）
VITE_API_URL=http://localhost:3000

# ダッシュボードで設定
# Settings > Environment Variables
```

### Netlify

```bash
# CLIで設定
netlify env:set VITE_API_URL https://api.example.com

# netlify.toml
[context.production.environment]
  VITE_API_URL = "https://api.example.com"

[context.deploy-preview.environment]
  VITE_API_URL = "https://api-preview.example.com"
```

---

## カスタムドメイン

### Vercel

1. Domains セクションでドメイン追加
2. DNS設定
   - A レコード: `76.76.21.21`
   - CNAME: `cname.vercel-dns.com`

### Netlify

1. Domain settings でドメイン追加
2. DNS設定
   - Netlify DNS使用（推奨）
   - または外部DNS設定

---

## プレビューデプロイ

### Vercel

- 全てのプルリクエストで自動プレビュー
- URL: `<project-name>-<branch>-<team>.vercel.app`

### Netlify

- 全てのプルリクエストで自動プレビュー
- URL: `deploy-preview-<pr-number>--<site-name>.netlify.app`

---

## ベストプラクティス

### 1. 環境変数の管理

```bash
# 本番環境のみ
VERCEL_ENV=production

# プレビュー環境
VERCEL_ENV=preview

# 開発環境
VERCEL_ENV=development
```

### 2. ビルドキャッシュ

```toml
# netlify.toml
[build]
  command = "npm run build"
  publish = "dist"

[build.environment]
  NODE_VERSION = "18"
  NPM_FLAGS = "--legacy-peer-deps"
```

### 3. パフォーマンス最適化

- 画像最適化（Vercel Image Optimization）
- CDN活用
- キャッシュヘッダー設定

---

## 参考リンク

- [Vercel Documentation](https://vercel.com/docs)
- [Netlify Documentation](https://docs.netlify.com/)
