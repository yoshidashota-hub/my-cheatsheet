# Sentry 完全ガイド

## 目次
- [Sentryとは](#sentryとは)
- [セットアップ](#セットアップ)
- [エラートラッキング](#エラートラッキング)
- [パフォーマンス監視](#パフォーマンス監視)
- [コンテキスト情報](#コンテキスト情報)
- [アラート設定](#アラート設定)
- [統合](#統合)

---

## Sentryとは

エラートラッキングとパフォーマンス監視のプラットフォーム。

### 特徴
- 🐛 リアルタイムエラー検出
- 📊 パフォーマンス監視
- 🔍 詳細なスタックトレース
- 📱 マルチプラットフォーム対応

### 対応環境
- JavaScript, TypeScript, Python, Go, Ruby, PHP, Java, .NET等
- React, Vue, Angular, Next.js, Node.js等

---

## セットアップ

### アカウント作成

```
1. https://sentry.io でアカウント作成
2. プロジェクト作成
3. DSN（Data Source Name）取得
```

### React

```bash
npm install @sentry/react
```

```typescript
// index.tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import * as Sentry from '@sentry/react'
import App from './App'

Sentry.init({
  dsn: 'https://xxxxxx@sentry.io/xxxxxx',
  environment: process.env.NODE_ENV,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration()
  ],
  tracesSampleRate: 1.0, // 100%のトランザクションを追跡
  replaysSessionSampleRate: 0.1, // 10%のセッションを記録
  replaysOnErrorSampleRate: 1.0 // エラー時は100%記録
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
```

### Next.js

```bash
npx @sentry/wizard@latest -i nextjs
```

```typescript
// sentry.client.config.ts
import * as Sentry from '@sentry/nextjs'

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 1.0,
  debug: false
})

// sentry.server.config.ts
import * as Sentry from '@sentry/nextjs'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 1.0
})
```

### Node.js (Express)

```bash
npm install @sentry/node @sentry/profiling-node
```

```typescript
import express from 'express'
import * as Sentry from '@sentry/node'
import { ProfilingIntegration } from '@sentry/profiling-node'

const app = express()

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
    new Sentry.Integrations.Express({ app }),
    new ProfilingIntegration()
  ],
  tracesSampleRate: 1.0,
  profilesSampleRate: 1.0
})

// RequestHandlerを最初に設定
app.use(Sentry.Handlers.requestHandler())
app.use(Sentry.Handlers.tracingHandler())

// ルート定義
app.get('/', (req, res) => {
  res.send('Hello')
})

// ErrorHandlerを最後に設定
app.use(Sentry.Handlers.errorHandler())

app.listen(3000)
```

### Vue

```bash
npm install @sentry/vue
```

```typescript
// main.ts
import { createApp } from 'vue'
import * as Sentry from '@sentry/vue'
import App from './App.vue'

const app = createApp(App)

Sentry.init({
  app,
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration()
  ],
  tracesSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0
})

app.mount('#app')
```

---

## エラートラッキング

### 自動キャプチャ

```typescript
// エラーは自動的にキャプチャされる
throw new Error('Something went wrong')

// 未処理のPromise拒否も自動キャプチャ
Promise.reject('Unhandled rejection')
```

### 手動キャプチャ

```typescript
import * as Sentry from '@sentry/react'

// エラーをキャプチャ
try {
  throw new Error('Error occurred')
} catch (error) {
  Sentry.captureException(error)
}

// メッセージをキャプチャ
Sentry.captureMessage('User action completed', 'info')

// カスタムエラー
Sentry.captureException(new Error('Custom error'), {
  tags: { section: 'payment' },
  level: 'error',
  extra: { userId: '123', amount: 1000 }
})
```

### エラーバウンダリ (React)

```typescript
import * as Sentry from '@sentry/react'

const SentryErrorBoundary = Sentry.ErrorBoundary

function App() {
  return (
    <SentryErrorBoundary
      fallback={({ error, resetError }) => (
        <div>
          <h1>エラーが発生しました</h1>
          <p>{error.message}</p>
          <button onClick={resetError}>再試行</button>
        </div>
      )}
      showDialog
    >
      <MyComponent />
    </SentryErrorBoundary>
  )
}
```

---

## パフォーマンス監視

### トランザクション

```typescript
import * as Sentry from '@sentry/react'

// トランザクション開始
const transaction = Sentry.startTransaction({
  name: 'User Profile Load',
  op: 'page_load'
})

Sentry.getCurrentHub().configureScope((scope) => {
  scope.setSpan(transaction)
})

// スパン作成
const span = transaction.startChild({
  op: 'db_query',
  description: 'SELECT * FROM users'
})

try {
  await fetchUserData()
} finally {
  span.finish()
}

transaction.finish()
```

### 自動計測

```typescript
// React
import * as Sentry from '@sentry/react'
import { useEffect } from 'react'
import { useLocation, useNavigationType, createRoutesFromChildren, matchRoutes } from 'react-router-dom'

Sentry.init({
  integrations: [
    Sentry.reactRouterV6BrowserTracingIntegration({
      useEffect,
      useLocation,
      useNavigationType,
      createRoutesFromChildren,
      matchRoutes
    })
  ]
})
```

### カスタムメトリクス

```typescript
import * as Sentry from '@sentry/react'

// カスタムメトリクス
Sentry.metrics.distribution('page.load.time', loadTime, {
  unit: 'millisecond',
  tags: { page: 'home' }
})

Sentry.metrics.increment('button.click', 1, {
  tags: { button: 'submit' }
})
```

---

## コンテキスト情報

### ユーザー情報

```typescript
import * as Sentry from '@sentry/react'

// ユーザー設定
Sentry.setUser({
  id: '123',
  email: 'user@example.com',
  username: 'john_doe',
  ip_address: '{{auto}}'
})

// ユーザークリア
Sentry.setUser(null)
```

### タグ

```typescript
// グローバルタグ
Sentry.setTag('environment', 'production')
Sentry.setTag('version', '1.2.3')

// イベント固有タグ
Sentry.captureException(error, {
  tags: {
    section: 'checkout',
    payment_method: 'credit_card'
  }
})
```

### 追加情報

```typescript
// グローバル追加情報
Sentry.setContext('character', {
  name: 'John',
  age: 30,
  level: 10
})

// イベント固有情報
Sentry.captureException(error, {
  extra: {
    requestBody: JSON.stringify(body),
    timestamp: Date.now()
  }
})
```

### ブレッドクラム

```typescript
// 手動ブレッドクラム
Sentry.addBreadcrumb({
  category: 'auth',
  message: 'User logged in',
  level: 'info'
})

// ナビゲーションブレッドクラム（自動）
// ユーザーの操作履歴が自動記録される
```

---

## アラート設定

### Issue Alert

```
Settings → Alerts → Create Alert

条件:
- エラーが初めて発生した時
- エラーが X 回以上発生した時
- エラー率が Y% を超えた時

アクション:
- Slack通知
- Email送信
- PagerDuty統合
- Webhook送信
```

### Metric Alert

```
パフォーマンスメトリクスに基づくアラート:
- レスポンスタイムが閾値を超えた時
- エラー率が上昇した時
- Apdex スコアが低下した時
```

---

## 統合

### Slack

```
Settings → Integrations → Slack → Install

通知内容:
- 新しいエラー発生
- エラーの再発
- リリースのデプロイ
```

### GitHub

```
Settings → Integrations → GitHub → Install

機能:
- コミットとリリースの追跡
- Issue自動作成
- Pull Requestへのコメント
```

### GitLab

```
Settings → Integrations → GitLab → Install
```

---

## 環境設定

### 本番環境

```typescript
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: 'production',

  // サンプリング
  tracesSampleRate: 0.1, // 10%のトランザクション

  // センシティブ情報の除外
  beforeSend(event) {
    // パスワードをマスク
    if (event.request?.data?.password) {
      event.request.data.password = '[Filtered]'
    }
    return event
  },

  // 無視するエラー
  ignoreErrors: [
    'ResizeObserver loop limit exceeded',
    'Non-Error promise rejection'
  ],

  // 無視するURL
  denyUrls: [
    /extensions\//i,
    /^chrome:\/\//i
  ]
})
```

### ソースマップ

```bash
# アップロード
npm install --save-dev @sentry/cli

# sentry-cli設定
export SENTRY_AUTH_TOKEN=xxxxx
export SENTRY_ORG=my-org
export SENTRY_PROJECT=my-project

# アップロード
sentry-cli sourcemaps upload --release=1.0.0 ./dist
```

```json
// package.json
{
  "scripts": {
    "build": "vite build",
    "sentry:upload": "sentry-cli sourcemaps upload --release=$npm_package_version ./dist"
  }
}
```

### リリース追跡

```typescript
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  release: process.env.SENTRY_RELEASE || '1.0.0',
  environment: process.env.NODE_ENV
})
```

---

## ベストプラクティス

### ✓ 推奨

```typescript
// コンテキスト情報を追加
Sentry.setUser({ id: userId })
Sentry.setTag('feature', 'payment')

// 意味のあるエラーメッセージ
throw new Error('Payment failed: Insufficient funds')

// センシティブ情報をフィルタ
beforeSend(event) {
  if (event.request?.data) {
    delete event.request.data.password
    delete event.request.data.creditCard
  }
  return event
}

// 適切なサンプリング
tracesSampleRate: 0.1 // 本番環境では10%程度
```

### ✗ 避けるべき

```typescript
// 汎用的すぎるエラー
throw new Error('Error')

// センシティブ情報の漏洩
Sentry.captureException(error, {
  extra: { password: userPassword }
})

// 過度なサンプリング
tracesSampleRate: 1.0 // 本番環境で100%は高コスト
```

---

## 料金プラン

```
Developer (無料):
- 5,000 errors/月
- 10,000 performance units/月
- 30日間データ保持

Team ($26/月):
- 50,000 errors/月
- 100,000 performance units/月
- 90日間データ保持

Business (カスタム):
- カスタム上限
- 無制限データ保持
```

---

## 参考リンク

- [Sentry Documentation](https://docs.sentry.io/)
- [Sentry React](https://docs.sentry.io/platforms/javascript/guides/react/)
- [Sentry Next.js](https://docs.sentry.io/platforms/javascript/guides/nextjs/)
- [Sentry Node.js](https://docs.sentry.io/platforms/node/)
