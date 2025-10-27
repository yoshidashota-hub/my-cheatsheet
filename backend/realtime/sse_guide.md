# Server-Sent Events (SSE) 完全ガイド

## 目次
1. [SSEとは](#sseとは)
2. [基本実装](#基本実装)
3. [イベントタイプ](#イベントタイプ)
4. [再接続処理](#再接続処理)
5. [React統合](#react統合)
6. [チャネル管理](#チャネル管理)
7. [本番環境](#本番環境)
8. [ベストプラクティス](#ベストプラクティス)

---

## SSEとは

Server-Sent Events (SSE) は、サーバーからクライアントへの一方向のリアルタイム通信を実現する技術です。

### WebSocketとの比較

| 特徴 | SSE | WebSocket |
|------|-----|-----------|
| 通信方向 | サーバー→クライアント | 双方向 |
| プロトコル | HTTP | WebSocket |
| 再接続 | 自動 | 手動実装必要 |
| ブラウザ対応 | 広い | 広い |
| オーバーヘッド | 小さい | 中程度 |

### 適用場面

- **通知**: リアルタイム通知
- **ダッシュボード**: データの定期更新
- **進捗表示**: タスク進捗のリアルタイム表示
- **ログストリーミング**: サーバーログの配信

---

## 基本実装

### サーバー実装（Express）

```typescript
import express from 'express';

const app = express();

app.get('/api/events', (req, res) => {
  // SSE用のヘッダー設定
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  // データ送信
  const sendEvent = (data: any) => {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  // 初回メッセージ
  sendEvent({ message: 'Connected', timestamp: Date.now() });

  // 定期的にデータ送信
  const interval = setInterval(() => {
    sendEvent({
      message: 'Update',
      timestamp: Date.now(),
    });
  }, 5000);

  // クライアント切断時のクリーンアップ
  req.on('close', () => {
    clearInterval(interval);
    res.end();
  });
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

### クライアント実装

```typescript
const eventSource = new EventSource('http://localhost:3000/api/events');

eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Received:', data);
};

eventSource.onerror = (error) => {
  console.error('SSE Error:', error);
};

// 接続を閉じる
eventSource.close();
```

---

## イベントタイプ

### カスタムイベント

```typescript
// サーバー
app.get('/api/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  // カスタムイベント送信
  const sendEvent = (event: string, data: any) => {
    res.write(`event: ${event}\n`);
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  sendEvent('user-joined', { userId: '123', username: 'John' });
  sendEvent('message', { text: 'Hello', userId: '123' });
  sendEvent('notification', { title: 'New message', body: 'You have a new message' });

  req.on('close', () => {
    res.end();
  });
});

// クライアント
const eventSource = new EventSource('http://localhost:3000/api/events');

eventSource.addEventListener('user-joined', (event) => {
  const data = JSON.parse(event.data);
  console.log('User joined:', data);
});

eventSource.addEventListener('message', (event) => {
  const data = JSON.parse(event.data);
  console.log('Message:', data);
});

eventSource.addEventListener('notification', (event) => {
  const data = JSON.parse(event.data);
  console.log('Notification:', data);
});
```

### イベントID

```typescript
// サーバー
let eventId = 0;

const sendEvent = (event: string, data: any) => {
  eventId++;
  res.write(`id: ${eventId}\n`);
  res.write(`event: ${event}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
};

// クライアント
eventSource.onmessage = (event) => {
  console.log('Event ID:', event.lastEventId);
  console.log('Data:', event.data);
};
```

---

## 再接続処理

### リトライ設定

```typescript
// サーバー
app.get('/api/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  // 再接続までの待ち時間（ミリ秒）
  res.write('retry: 3000\n\n');

  const sendEvent = (data: any) => {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  // イベント送信...
});

// クライアント（自動再接続）
const eventSource = new EventSource('http://localhost:3000/api/events');

eventSource.onopen = () => {
  console.log('Connected');
};

eventSource.onerror = () => {
  console.log('Connection lost, reconnecting...');
};
```

### Last-Event-ID

```typescript
// サーバー
app.get('/api/events', (req, res) => {
  const lastEventId = req.headers['last-event-id'];

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  let eventId = lastEventId ? parseInt(lastEventId as string) : 0;

  // 最後のイベントID以降のイベントを送信
  const sendEvent = (data: any) => {
    eventId++;
    res.write(`id: ${eventId}\n`);
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  // 未送信のイベントを取得して送信
  const missedEvents = getMissedEvents(eventId);
  missedEvents.forEach((event) => sendEvent(event));

  // 新しいイベント送信...
});

function getMissedEvents(lastEventId: number) {
  // データベースから未送信のイベントを取得
  return [];
}
```

---

## React統合

### カスタムフック

```typescript
import { useEffect, useState } from 'react';

interface UseSSEOptions {
  url: string;
  events?: {
    [key: string]: (event: MessageEvent) => void;
  };
}

export function useSSE<T = any>({ url, events }: UseSSEOptions) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Event | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    const eventSource = new EventSource(url);

    eventSource.onopen = () => {
      setIsConnected(true);
      setError(null);
    };

    eventSource.onmessage = (event) => {
      const parsedData = JSON.parse(event.data);
      setData(parsedData);
    };

    eventSource.onerror = (error) => {
      setIsConnected(false);
      setError(error);
    };

    // カスタムイベント
    if (events) {
      Object.entries(events).forEach(([eventName, handler]) => {
        eventSource.addEventListener(eventName, handler);
      });
    }

    return () => {
      eventSource.close();
    };
  }, [url]);

  return { data, error, isConnected };
}
```

### 使用例

```typescript
export function Dashboard() {
  const { data, isConnected } = useSSE<{ value: number }>({
    url: '/api/events/dashboard',
    events: {
      'user-joined': (event) => {
        const data = JSON.parse(event.data);
        console.log('User joined:', data);
      },
      'user-left': (event) => {
        const data = JSON.parse(event.data);
        console.log('User left:', data);
      },
    },
  });

  if (!isConnected) {
    return <div>Connecting...</div>;
  }

  return (
    <div>
      <h1>Dashboard</h1>
      <p>Current value: {data?.value}</p>
    </div>
  );
}
```

### 通知コンポーネント

```typescript
import { useState, useEffect } from 'react';

interface Notification {
  id: string;
  title: string;
  body: string;
  timestamp: number;
}

export function Notifications() {
  const [notifications, setNotifications] = useState<Notification[]>([]);

  useEffect(() => {
    const eventSource = new EventSource('/api/events/notifications');

    eventSource.addEventListener('notification', (event) => {
      const notification = JSON.parse(event.data) as Notification;
      setNotifications((prev) => [notification, ...prev]);

      // ブラウザ通知
      if (Notification.permission === 'granted') {
        new Notification(notification.title, {
          body: notification.body,
        });
      }
    });

    return () => {
      eventSource.close();
    };
  }, []);

  return (
    <div>
      <h2>Notifications</h2>
      {notifications.map((n) => (
        <div key={n.id}>
          <strong>{n.title}</strong>
          <p>{n.body}</p>
        </div>
      ))}
    </div>
  );
}
```

---

## チャネル管理

### クライアント管理

```typescript
interface Client {
  id: string;
  res: express.Response;
  userId?: string;
  channels: Set<string>;
}

const clients = new Map<string, Client>();

app.get('/api/events', (req, res) => {
  const clientId = generateId();
  const userId = req.query.userId as string | undefined;

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const client: Client = {
    id: clientId,
    res,
    userId,
    channels: new Set(),
  };

  clients.set(clientId, client);

  // 初期メッセージ
  res.write(`data: ${JSON.stringify({ type: 'connected', clientId })}\n\n`);

  req.on('close', () => {
    clients.delete(clientId);
  });
});

function generateId(): string {
  return Math.random().toString(36).substring(7);
}
```

### ブロードキャスト

```typescript
// 全クライアントに送信
function broadcast(event: string, data: any) {
  const message = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;

  clients.forEach((client) => {
    client.res.write(message);
  });
}

// 特定のユーザーに送信
function sendToUser(userId: string, event: string, data: any) {
  const message = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;

  clients.forEach((client) => {
    if (client.userId === userId) {
      client.res.write(message);
    }
  });
}

// 特定のチャネルに送信
function sendToChannel(channel: string, event: string, data: any) {
  const message = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;

  clients.forEach((client) => {
    if (client.channels.has(channel)) {
      client.res.write(message);
    }
  });
}

// 使用例
app.post('/api/broadcast', (req, res) => {
  const { event, data } = req.body;
  broadcast(event, data);
  res.json({ success: true });
});

app.post('/api/notify/:userId', (req, res) => {
  const { userId } = req.params;
  const { event, data } = req.body;
  sendToUser(userId, event, data);
  res.json({ success: true });
});
```

### チャネル購読

```typescript
app.post('/api/events/subscribe', (req, res) => {
  const { clientId, channel } = req.body;

  const client = clients.get(clientId);
  if (!client) {
    return res.status(404).json({ error: 'Client not found' });
  }

  client.channels.add(channel);
  res.json({ success: true });
});

app.post('/api/events/unsubscribe', (req, res) => {
  const { clientId, channel } = req.body;

  const client = clients.get(clientId);
  if (!client) {
    return res.status(404).json({ error: 'Client not found' });
  }

  client.channels.delete(channel);
  res.json({ success: true });
});
```

---

## 本番環境

### CORS設定

```typescript
import cors from 'cors';

app.use(
  cors({
    origin: process.env.CLIENT_URL,
    credentials: true,
  })
);

app.get('/api/events', (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', process.env.CLIENT_URL!);
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  // イベント送信...
});
```

### 認証

```typescript
import jwt from 'jsonwebtoken';

app.get('/api/events', (req, res) => {
  const token = req.query.token as string;

  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!);
    const userId = (payload as any).userId;

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const client: Client = {
      id: generateId(),
      res,
      userId,
      channels: new Set(),
    };

    clients.set(client.id, client);

    req.on('close', () => {
      clients.delete(client.id);
    });
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// クライアント
const token = 'your-jwt-token';
const eventSource = new EventSource(`/api/events?token=${token}`);
```

### プロキシ設定（Nginx）

```nginx
server {
  listen 80;
  server_name example.com;

  location /api/events {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Connection '';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_buffering off;
    proxy_cache off;
    chunked_transfer_encoding off;
  }
}
```

---

## ベストプラクティス

### 1. ハートビート

```typescript
app.get('/api/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  // 30秒ごとにハートビート送信
  const heartbeat = setInterval(() => {
    res.write(':heartbeat\n\n');
  }, 30000);

  req.on('close', () => {
    clearInterval(heartbeat);
    res.end();
  });
});
```

### 2. エラーハンドリング

```typescript
// クライアント
const eventSource = new EventSource('/api/events');

let retryCount = 0;
const maxRetries = 5;

eventSource.onerror = (error) => {
  retryCount++;

  if (retryCount > maxRetries) {
    console.error('Max retries exceeded');
    eventSource.close();
    return;
  }

  console.log(`Connection error. Retry ${retryCount}/${maxRetries}`);
};

eventSource.onopen = () => {
  retryCount = 0; // リセット
};
```

### 3. メモリリーク防止

```typescript
// React
useEffect(() => {
  const eventSource = new EventSource('/api/events');

  // イベントリスナー
  const messageHandler = (event: MessageEvent) => {
    const data = JSON.parse(event.data);
    setData(data);
  };

  eventSource.addEventListener('message', messageHandler);

  return () => {
    // クリーンアップ
    eventSource.removeEventListener('message', messageHandler);
    eventSource.close();
  };
}, []);
```

### 4. 進捗表示

```typescript
// サーバー
app.post('/api/process', async (req, res) => {
  const taskId = generateId();

  // SSEでクライアントに進捗を通知
  sendToClient(req.clientId, 'progress', {
    taskId,
    progress: 0,
    status: 'started',
  });

  // 長時間処理
  for (let i = 0; i <= 100; i += 10) {
    await processStep(i);

    sendToClient(req.clientId, 'progress', {
      taskId,
      progress: i,
      status: 'processing',
    });

    await sleep(1000);
  }

  sendToClient(req.clientId, 'progress', {
    taskId,
    progress: 100,
    status: 'completed',
  });

  res.json({ taskId });
});

// クライアント
function ProcessStatus({ taskId }: { taskId: string }) {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const eventSource = new EventSource('/api/events');

    eventSource.addEventListener('progress', (event) => {
      const data = JSON.parse(event.data);
      if (data.taskId === taskId) {
        setProgress(data.progress);
      }
    });

    return () => {
      eventSource.close();
    };
  }, [taskId]);

  return (
    <div>
      <progress value={progress} max={100} />
      <span>{progress}%</span>
    </div>
  );
}
```

### 5. Redis Pub/Sub統合

```typescript
import Redis from 'ioredis';

const redis = new Redis();
const subscriber = new Redis();

// Redisからのメッセージを購読
subscriber.subscribe('events', (err, count) => {
  console.log(`Subscribed to ${count} channels`);
});

subscriber.on('message', (channel, message) => {
  const { event, data } = JSON.parse(message);

  // 全クライアントに送信
  broadcast(event, data);
});

// メッセージ発行
app.post('/api/publish', async (req, res) => {
  const { event, data } = req.body;

  await redis.publish('events', JSON.stringify({ event, data }));

  res.json({ success: true });
});
```

---

## 参考リンク

- [Server-Sent Events Spec](https://html.spec.whatwg.org/multipage/server-sent-events.html)
- [MDN: Server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [EventSource API](https://developer.mozilla.org/en-US/docs/Web/API/EventSource)
