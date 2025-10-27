# WebSocket & Socket.io 完全ガイド

## 目次
1. [WebSocketとは](#websocketとは)
2. [Socket.io基本](#socketio基本)
3. [イベント処理](#イベント処理)
4. [ルーム・ネームスペース](#ルームネームスペース)
5. [認証・認可](#認証認可)
6. [スケーリング](#スケーリング)
7. [React統合](#react統合)
8. [ベストプラクティス](#ベストプラクティス)

---

## WebSocketとは

WebSocketは双方向通信を実現するプロトコルです。

### HTTPとの違い

| 特徴 | HTTP | WebSocket |
|------|------|-----------|
| 通信方向 | 単方向 | 双方向 |
| 接続 | リクエストごと | 持続的 |
| オーバーヘッド | 大きい | 小さい |
| リアルタイム性 | 低い | 高い |

### 主な用途

- **チャット**: リアルタイムメッセージング
- **通知**: プッシュ通知
- **ダッシュボード**: リアルタイムデータ更新
- **ゲーム**: マルチプレイヤーゲーム

---

## Socket.io基本

### セットアップ

```bash
npm install socket.io
npm install socket.io-client # フロントエンド用
```

### サーバー実装

```typescript
import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';

const app = express();
const httpServer = createServer(app);

const io = new Server(httpServer, {
  cors: {
    origin: process.env.CLIENT_URL || 'http://localhost:3000',
    credentials: true,
  },
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

httpServer.listen(3001, () => {
  console.log('Server running on port 3001');
});
```

### クライアント実装

```typescript
import { io } from 'socket.io-client';

const socket = io('http://localhost:3001', {
  autoConnect: true,
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionAttempts: 5,
});

socket.on('connect', () => {
  console.log('Connected:', socket.id);
});

socket.on('disconnect', () => {
  console.log('Disconnected');
});

socket.on('connect_error', (error) => {
  console.error('Connection error:', error);
});
```

---

## イベント処理

### メッセージ送信

```typescript
// サーバー
io.on('connection', (socket) => {
  // クライアントからのメッセージ受信
  socket.on('message', (data) => {
    console.log('Received:', data);

    // 送信者以外の全員に送信
    socket.broadcast.emit('message', data);

    // 送信者を含む全員に送信
    io.emit('message', data);

    // 特定のクライアントに送信
    socket.to(targetSocketId).emit('message', data);

    // 送信者にのみ返信
    socket.emit('message', { reply: 'Received!' });
  });
});

// クライアント
socket.emit('message', { text: 'Hello!' });

socket.on('message', (data) => {
  console.log('Received:', data);
});
```

### Acknowledgement（応答確認）

```typescript
// サーバー
socket.on('message', (data, callback) => {
  console.log('Received:', data);

  // 処理完了を通知
  callback({ status: 'ok', timestamp: Date.now() });
});

// クライアント
socket.emit('message', { text: 'Hello' }, (response) => {
  console.log('Server response:', response);
});
```

### 型安全なイベント

```typescript
// 型定義
interface ServerToClientEvents {
  message: (data: { text: string; userId: string }) => void;
  userJoined: (data: { userId: string; username: string }) => void;
  userLeft: (data: { userId: string }) => void;
}

interface ClientToServerEvents {
  message: (data: { text: string }) => void;
  join: (data: { roomId: string }) => void;
}

// サーバー
const io = new Server<ClientToServerEvents, ServerToClientEvents>(httpServer);

io.on('connection', (socket) => {
  socket.on('message', (data) => {
    // data.text は型安全
    io.emit('message', {
      text: data.text,
      userId: socket.id,
    });
  });
});

// クライアント
import { Socket } from 'socket.io-client';

const socket: Socket<ServerToClientEvents, ClientToServerEvents> = io('http://localhost:3001');

socket.emit('message', { text: 'Hello' }); // 型チェック
```

---

## ルーム・ネームスペース

### ルーム

```typescript
// サーバー
io.on('connection', (socket) => {
  // ルームに参加
  socket.on('join', ({ roomId }) => {
    socket.join(roomId);
    console.log(`${socket.id} joined room ${roomId}`);

    // ルーム内の他のユーザーに通知
    socket.to(roomId).emit('userJoined', {
      userId: socket.id,
      username: socket.data.username,
    });
  });

  // ルームから退出
  socket.on('leave', ({ roomId }) => {
    socket.leave(roomId);
    socket.to(roomId).emit('userLeft', { userId: socket.id });
  });

  // ルーム内にメッセージ送信
  socket.on('roomMessage', ({ roomId, text }) => {
    io.to(roomId).emit('message', {
      text,
      userId: socket.id,
      roomId,
    });
  });

  // 切断時に全ルームから退出
  socket.on('disconnect', () => {
    const rooms = Array.from(socket.rooms);
    rooms.forEach((roomId) => {
      socket.to(roomId).emit('userLeft', { userId: socket.id });
    });
  });
});

// クライアント
socket.emit('join', { roomId: 'room-123' });
socket.emit('roomMessage', { roomId: 'room-123', text: 'Hello!' });
```

### ネームスペース

```typescript
// サーバー
const chatNamespace = io.of('/chat');
const notificationNamespace = io.of('/notifications');

chatNamespace.on('connection', (socket) => {
  console.log('Chat connection:', socket.id);

  socket.on('message', (data) => {
    chatNamespace.emit('message', data);
  });
});

notificationNamespace.on('connection', (socket) => {
  console.log('Notification connection:', socket.id);

  socket.on('subscribe', ({ userId }) => {
    socket.join(`user-${userId}`);
  });
});

// クライアント
const chatSocket = io('http://localhost:3001/chat');
const notificationSocket = io('http://localhost:3001/notifications');

chatSocket.on('message', (data) => {
  console.log('Chat message:', data);
});

notificationSocket.emit('subscribe', { userId: 'user-123' });
```

---

## 認証・認可

### JWT認証

```typescript
import jwt from 'jsonwebtoken';

// ミドルウェア
io.use((socket, next) => {
  const token = socket.handshake.auth.token;

  if (!token) {
    return next(new Error('Authentication error'));
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!);
    socket.data.user = payload;
    next();
  } catch (error) {
    next(new Error('Invalid token'));
  }
});

io.on('connection', (socket) => {
  console.log('Authenticated user:', socket.data.user);

  // ユーザー専用ルームに参加
  socket.join(`user-${socket.data.user.id}`);
});

// クライアント
const socket = io('http://localhost:3001', {
  auth: {
    token: 'your-jwt-token',
  },
});
```

### ルームアクセス制御

```typescript
io.on('connection', (socket) => {
  socket.on('join', async ({ roomId }) => {
    // アクセス権限チェック
    const hasAccess = await checkRoomAccess(socket.data.user.id, roomId);

    if (!hasAccess) {
      socket.emit('error', { message: 'Access denied' });
      return;
    }

    socket.join(roomId);
    socket.emit('joined', { roomId });
  });
});

async function checkRoomAccess(userId: string, roomId: string): Promise<boolean> {
  // データベースでアクセス権限を確認
  const member = await prisma.roomMember.findFirst({
    where: {
      userId,
      roomId,
    },
  });

  return !!member;
}
```

---

## スケーリング

### Redis Adapter

```bash
npm install @socket.io/redis-adapter redis
```

```typescript
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';

const pubClient = createClient({ url: process.env.REDIS_URL });
const subClient = pubClient.duplicate();

Promise.all([pubClient.connect(), subClient.connect()]).then(() => {
  io.adapter(createAdapter(pubClient, subClient));
  console.log('Redis adapter connected');
});

io.on('connection', (socket) => {
  // 複数サーバー間でイベントが共有される
  socket.on('message', (data) => {
    io.emit('message', data); // 全サーバーの全クライアントに送信
  });
});
```

### クラスターモード

```typescript
import cluster from 'cluster';
import os from 'os';

if (cluster.isPrimary) {
  console.log(`Master ${process.pid} is running`);

  // ワーカープロセスを起動
  const numCPUs = os.cpus().length;
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }

  cluster.on('exit', (worker) => {
    console.log(`Worker ${worker.process.pid} died`);
    cluster.fork();
  });
} else {
  // ワーカープロセスでサーバーを起動
  const app = express();
  const httpServer = createServer(app);
  const io = new Server(httpServer);

  // Redis adapter使用
  io.adapter(createAdapter(pubClient, subClient));

  httpServer.listen(3001);
  console.log(`Worker ${process.pid} started`);
}
```

---

## React統合

### カスタムフック

```typescript
import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';

let socket: Socket | null = null;

export function useSocket(url: string, token?: string) {
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    if (!socket) {
      socket = io(url, {
        auth: { token },
      });
    }

    socket.on('connect', () => {
      setIsConnected(true);
    });

    socket.on('disconnect', () => {
      setIsConnected(false);
    });

    return () => {
      if (socket) {
        socket.off('connect');
        socket.off('disconnect');
      }
    };
  }, [url, token]);

  return { socket, isConnected };
}
```

### チャットコンポーネント

```typescript
import { useState, useEffect } from 'react';
import { useSocket } from './useSocket';

interface Message {
  id: string;
  text: string;
  userId: string;
  timestamp: number;
}

export function Chat({ roomId }: { roomId: string }) {
  const { socket, isConnected } = useSocket('http://localhost:3001');
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');

  useEffect(() => {
    if (!socket || !isConnected) return;

    // ルームに参加
    socket.emit('join', { roomId });

    // メッセージ受信
    socket.on('message', (message: Message) => {
      setMessages((prev) => [...prev, message]);
    });

    return () => {
      socket.emit('leave', { roomId });
      socket.off('message');
    };
  }, [socket, isConnected, roomId]);

  const sendMessage = () => {
    if (!socket || !input.trim()) return;

    socket.emit('roomMessage', {
      roomId,
      text: input,
    });

    setInput('');
  };

  if (!isConnected) {
    return <div>Connecting...</div>;
  }

  return (
    <div>
      <div>
        {messages.map((msg) => (
          <div key={msg.id}>
            <strong>{msg.userId}:</strong> {msg.text}
          </div>
        ))}
      </div>

      <input
        value={input}
        onChange={(e) => setInput(e.target.value)}
        onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
      />
      <button onClick={sendMessage}>Send</button>
    </div>
  );
}
```

---

## ベストプラクティス

### 1. 接続管理

```typescript
const connectedUsers = new Map<string, { userId: string; socketId: string }>();

io.on('connection', (socket) => {
  const userId = socket.data.user.id;

  connectedUsers.set(socket.id, {
    userId,
    socketId: socket.id,
  });

  socket.on('disconnect', () => {
    connectedUsers.delete(socket.id);
  });
});

// ユーザーがオンラインか確認
function isUserOnline(userId: string): boolean {
  return Array.from(connectedUsers.values()).some((u) => u.userId === userId);
}
```

### 2. レート制限

```typescript
import rateLimit from 'express-rate-limit';

const messageRateLimiter = new Map<string, number[]>();

io.on('connection', (socket) => {
  socket.on('message', (data) => {
    const now = Date.now();
    const userMessages = messageRateLimiter.get(socket.id) || [];

    // 直近1分間のメッセージ数をカウント
    const recentMessages = userMessages.filter((time) => now - time < 60000);

    if (recentMessages.length >= 10) {
      socket.emit('error', { message: 'Too many messages' });
      return;
    }

    recentMessages.push(now);
    messageRateLimiter.set(socket.id, recentMessages);

    // メッセージ処理...
  });
});
```

### 3. エラーハンドリング

```typescript
io.on('connection', (socket) => {
  socket.on('error', (error) => {
    console.error('Socket error:', error);
  });

  socket.use(([event, ...args], next) => {
    try {
      // イベントハンドラーのラッパー
      next();
    } catch (error) {
      console.error(`Error in ${event}:`, error);
      socket.emit('error', { message: 'Internal error' });
    }
  });
});
```

### 4. タイピングインジケーター

```typescript
// サーバー
io.on('connection', (socket) => {
  socket.on('typing', ({ roomId }) => {
    socket.to(roomId).emit('userTyping', {
      userId: socket.id,
      username: socket.data.user.username,
    });
  });

  socket.on('stopTyping', ({ roomId }) => {
    socket.to(roomId).emit('userStoppedTyping', {
      userId: socket.id,
    });
  });
});

// クライアント（React）
const [typingUsers, setTypingUsers] = useState<Set<string>>(new Set());

useEffect(() => {
  if (!socket) return;

  socket.on('userTyping', ({ userId }) => {
    setTypingUsers((prev) => new Set(prev).add(userId));
  });

  socket.on('userStoppedTyping', ({ userId }) => {
    setTypingUsers((prev) => {
      const next = new Set(prev);
      next.delete(userId);
      return next;
    });
  });
}, [socket]);

const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
  setInput(e.target.value);

  if (e.target.value) {
    socket?.emit('typing', { roomId });
  } else {
    socket?.emit('stopTyping', { roomId });
  }
};
```

### 5. 再接続ロジック

```typescript
// クライアント
const socket = io('http://localhost:3001', {
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 5000,
  reconnectionAttempts: 5,
});

let reconnectAttempts = 0;

socket.on('disconnect', () => {
  console.log('Disconnected');
});

socket.on('reconnect', (attemptNumber) => {
  console.log('Reconnected after', attemptNumber, 'attempts');
  reconnectAttempts = 0;
});

socket.on('reconnect_attempt', () => {
  reconnectAttempts++;
  console.log('Reconnect attempt:', reconnectAttempts);
});

socket.on('reconnect_failed', () => {
  console.error('Reconnection failed');
  // ユーザーに通知
});
```

---

## 参考リンク

- [Socket.io Documentation](https://socket.io/docs/v4/)
- [WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455)
- [Socket.io Redis Adapter](https://socket.io/docs/v4/redis-adapter/)
