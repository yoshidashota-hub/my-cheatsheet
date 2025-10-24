# HTTP Client（Axios / Fetch API）完全ガイド

## 目次
- [Fetch API](#fetch-api)
- [Axios](#axios)
- [エラーハンドリング](#エラーハンドリング)
- [インターセプター](#インターセプター)
- [キャンセル処理](#キャンセル処理)
- [比較](#比較)

---

## Fetch API

ブラウザネイティブのHTTPクライアント。

### 基本的なGETリクエスト

```typescript
// シンプルなGET
const response = await fetch('https://api.example.com/users')
const data = await response.json()

// エラーチェック
if (!response.ok) {
  throw new Error(`HTTP error! status: ${response.status}`)
}
```

### POSTリクエスト

```typescript
const response = await fetch('https://api.example.com/users', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    name: 'John Doe',
    email: 'john@example.com'
  })
})

const data = await response.json()
```

### その他のHTTPメソッド

```typescript
// PUT
await fetch('/api/users/1', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ name: 'Jane' })
})

// DELETE
await fetch('/api/users/1', {
  method: 'DELETE'
})

// PATCH
await fetch('/api/users/1', {
  method: 'PATCH',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ age: 26 })
})
```

### ヘッダー設定

```typescript
const response = await fetch('/api/data', {
  headers: {
    'Authorization': 'Bearer token123',
    'Content-Type': 'application/json',
    'X-Custom-Header': 'value'
  }
})
```

### AbortController（キャンセル）

```typescript
const controller = new AbortController()

fetch('/api/data', {
  signal: controller.signal
})

// 5秒後にキャンセル
setTimeout(() => controller.abort(), 5000)
```

---

## Axios

人気のHTTPクライアントライブラリ。

### インストール

```bash
npm install axios
```

### 基本的な使い方

```typescript
import axios from 'axios'

// GET
const response = await axios.get('/api/users')
const data = response.data

// POST
const response = await axios.post('/api/users', {
  name: 'John',
  email: 'john@example.com'
})

// PUT
await axios.put('/api/users/1', { name: 'Jane' })

// DELETE
await axios.delete('/api/users/1')

// PATCH
await axios.patch('/api/users/1', { age: 26 })
```

### インスタンス作成

```typescript
const api = axios.create({
  baseURL: 'https://api.example.com',
  timeout: 5000,
  headers: {
    'Authorization': 'Bearer token123'
  }
})

// 使用
const response = await api.get('/users')
```

### パラメータ

```typescript
// クエリパラメータ
await axios.get('/api/users', {
  params: {
    page: 1,
    limit: 10,
    sort: 'name'
  }
})
// => /api/users?page=1&limit=10&sort=name
```

---

## エラーハンドリング

### Fetch API

```typescript
try {
  const response = await fetch('/api/data')

  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`)
  }

  const data = await response.json()
} catch (error) {
  console.error('Fetch error:', error)
}
```

### Axios

```typescript
try {
  const response = await axios.get('/api/data')
} catch (error) {
  if (axios.isAxiosError(error)) {
    if (error.response) {
      // サーバーエラー（4xx, 5xx）
      console.log(error.response.status)
      console.log(error.response.data)
    } else if (error.request) {
      // リクエストエラー（ネットワーク等）
      console.log('No response received')
    } else {
      // その他のエラー
      console.log(error.message)
    }
  }
}
```

---

## インターセプター

Axiosのみの機能。リクエスト/レスポンスを加工。

### リクエストインターセプター

```typescript
api.interceptors.request.use(
  (config) => {
    // リクエスト送信前の処理
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)
```

### レスポンスインターセプター

```typescript
api.interceptors.response.use(
  (response) => {
    // 正常レスポンス
    return response.data
  },
  (error) => {
    // エラーレスポンス
    if (error.response?.status === 401) {
      // 認証エラー時の処理
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)
```

---

## キャンセル処理

### Fetch API

```typescript
const controller = new AbortController()

fetch('/api/data', { signal: controller.signal })
  .then(res => res.json())
  .catch(err => {
    if (err.name === 'AbortError') {
      console.log('Fetch aborted')
    }
  })

// キャンセル
controller.abort()
```

### Axios

```typescript
const controller = new AbortController()

axios.get('/api/data', {
  signal: controller.signal
})

// キャンセル
controller.abort()
```

---

## 比較

| 特徴 | Fetch API | Axios |
|------|-----------|-------|
| ブラウザサポート | ネイティブ | ライブラリ |
| バンドルサイズ | 0 | ~13KB |
| JSONパース | 手動 | 自動 |
| エラーハンドリング | 手動 | 自動 |
| タイムアウト | 手動 | 組み込み |
| インターセプター | なし | あり |
| プログレス | 手動 | あり |
| レスポンス変換 | 手動 | 自動 |

---

## 参考リンク

- [Fetch API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
- [Axios Documentation](https://axios-http.com/)
