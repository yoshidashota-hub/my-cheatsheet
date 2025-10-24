# WebSocket 完全ガイド

## 目次
- [WebSocketとは](#websocketとは)
- [基本的な使い方](#基本的な使い方)
- [イベント処理](#イベント処理)
- [Socket.IO](#socketio)
- [再接続処理](#再接続処理)
- [セキュリティ](#セキュリティ)

---

## WebSocketとは

双方向通信を実現するプロトコル。リアルタイムアプリケーションに最適。

### 特徴
- 🔄 双方向通信
- ⚡ 低レイテンシー
- 📡 リアルタイム
- 🔌 持続的な接続

### 使用例
- チャットアプリ
- リアルタイム通知
- オンラインゲーム
- 株価表示

---

## 基本的な使い方

### クライアント（ブラウザ）

```typescript
// 接続
const ws = new WebSocket('ws://localhost:8080')

// 接続成功
ws.onopen = (event) => {
  console.log('Connected')
  ws.send('Hello Server!')
}

// メッセージ受信
ws.onmessage = (event) => {
  console.log('Received:', event.data)
}

// エラー
ws.onerror = (error) => {
  console.error('WebSocket error:', error)
}

// 接続終了
ws.onclose = (event) => {
  console.log('Disconnected')
}

// メッセージ送信
ws.send('Hello')
ws.send(JSON.stringify({ type: 'message', text: 'Hello' }))

// 接続終了
ws.close()
```

---

## イベント処理

### ReadyState

```typescript
const ws = new WebSocket('ws://localhost:8080')

console.log(ws.readyState)
// 0: CONNECTING
// 1: OPEN
// 2: CLOSING
// 3: CLOSED

// 接続確認
if (ws.readyState === WebSocket.OPEN) {
  ws.send('message')
}
```

---

## Socket.IO

WebSocketを簡単に使えるライブラリ。自動再接続やフォールバック機能あり。

### インストール

```bash
# クライアント
npm install socket.io-client

# サーバー
npm install socket.io
```

### クライアント

```typescript
import { io } from 'socket.io-client'

const socket = io('http://localhost:3000')

// 接続
socket.on('connect', () => {
  console.log('Connected')
})

// メッセージ受信
socket.on('message', (data) => {
  console.log('Received:', data)
})

// メッセージ送信
socket.emit('message', { text: 'Hello' })

// 切断
socket.on('disconnect', () => {
  console.log('Disconnected')
})
```

### サーバー（Node.js）

```typescript
import { Server } from 'socket.io'
import { createServer } from 'http'

const httpServer = createServer()
const io = new Server(httpServer, {
  cors: {
    origin: '*'
  }
})

io.on('connection', (socket) => {
  console.log('Client connected')

  socket.on('message', (data) => {
    console.log('Received:', data)

    // 送信者に返信
    socket.emit('message', { text: 'Received' })

    // 全員にブロードキャスト
    io.emit('message', data)

    // 送信者以外にブロードキャスト
    socket.broadcast.emit('message', data)
  })

  socket.on('disconnect', () => {
    console.log('Client disconnected')
  })
})

httpServer.listen(3000)
```

---

## 再接続処理

### Native WebSocket

```typescript
let ws: WebSocket
let reconnectInterval = 1000

function connect() {
  ws = new WebSocket('ws://localhost:8080')

  ws.onopen = () => {
    console.log('Connected')
    reconnectInterval = 1000
  }

  ws.onclose = () => {
    console.log('Disconnected, reconnecting...')
    setTimeout(() => {
      reconnectInterval = Math.min(reconnectInterval * 2, 30000)
      connect()
    }, reconnectInterval)
  }

  ws.onerror = (error) => {
    console.error('Error:', error)
    ws.close()
  }
}

connect()
```

### Socket.IO（自動再接続）

```typescript
const socket = io('http://localhost:3000', {
  reconnection: true,
  reconnectionAttempts: 5,
  reconnectionDelay: 1000
})
```

---

## セキュリティ

### WSS（暗号化）

```typescript
// HTTPS環境ではWSSを使用
const ws = new WebSocket('wss://example.com')
```

### 認証

```typescript
// トークンを含める
const socket = io('http://localhost:3000', {
  auth: {
    token: 'your-jwt-token'
  }
})

// サーバー側
io.use((socket, next) => {
  const token = socket.handshake.auth.token
  if (isValidToken(token)) {
    next()
  } else {
    next(new Error('Authentication error'))
  }
})
```

---

## 参考リンク

- [WebSocket API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [Socket.IO Documentation](https://socket.io/docs/v4/)
