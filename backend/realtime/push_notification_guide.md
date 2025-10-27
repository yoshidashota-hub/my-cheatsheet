# Push通知 完全ガイド

## 目次
1. [Push通知とは](#push通知とは)
2. [Firebase Cloud Messaging (FCM)](#firebase-cloud-messaging-fcm)
3. [Apple Push Notification Service (APNs)](#apple-push-notification-service-apns)
4. [Web Push](#web-push)
5. [通知管理](#通知管理)
6. [マルチプラットフォーム](#マルチプラットフォーム)
7. [トピック・セグメント](#トピックセグメント)
8. [ベストプラクティス](#ベストプラクティス)

---

## Push通知とは

Push通知は、サーバーからユーザーのデバイスにメッセージを送信する技術です。

### 主なプラットフォーム

- **FCM**: Android, iOS, Web
- **APNs**: iOS, macOS
- **Web Push**: ブラウザ

### 用途

- **アプリ通知**: 新着メッセージ、イベント通知
- **リエンゲージメント**: ユーザーの再訪問促進
- **トランザクション通知**: 注文確認、配送通知
- **マーケティング**: プロモーション、キャンペーン

---

## Firebase Cloud Messaging (FCM)

### セットアップ

```bash
npm install firebase-admin
```

### 初期化

```typescript
import admin from 'firebase-admin';
import serviceAccount from './firebase-service-account.json';

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
});

const messaging = admin.messaging();
```

### 単一デバイスへの送信

```typescript
async function sendNotification(token: string, title: string, body: string) {
  const message: admin.messaging.Message = {
    token,
    notification: {
      title,
      body,
    },
    data: {
      type: 'message',
      timestamp: Date.now().toString(),
    },
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        color: '#2196F3',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await messaging.send(message);
    console.log('Successfully sent message:', response);
    return response;
  } catch (error) {
    console.error('Error sending message:', error);
    throw error;
  }
}

// 使用例
await sendNotification(
  'device-token-here',
  '新着メッセージ',
  'あなた宛のメッセージが届きました'
);
```

### 複数デバイスへの送信

```typescript
async function sendMulticast(
  tokens: string[],
  title: string,
  body: string
) {
  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: {
      title,
      body,
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);

    console.log('Success count:', response.successCount);
    console.log('Failure count:', response.failureCount);

    // 失敗したトークンを処理
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        console.error('Failed token:', tokens[idx], resp.error);
      }
    });

    return response;
  } catch (error) {
    console.error('Error sending multicast:', error);
    throw error;
  }
}
```

### トピック通知

```typescript
// トピックに購読
async function subscribeToTopic(tokens: string[], topic: string) {
  try {
    const response = await messaging.subscribeToTopic(tokens, topic);
    console.log('Successfully subscribed:', response.successCount);
    return response;
  } catch (error) {
    console.error('Error subscribing to topic:', error);
    throw error;
  }
}

// トピックに通知送信
async function sendToTopic(topic: string, title: string, body: string) {
  const message: admin.messaging.Message = {
    topic,
    notification: {
      title,
      body,
    },
  };

  const response = await messaging.send(message);
  return response;
}

// 使用例
await subscribeToTopic(['token1', 'token2'], 'news');
await sendToTopic('news', 'ニュース速報', '最新のニュースをお届けします');
```

### 条件付き送信

```typescript
async function sendToCondition(condition: string, title: string, body: string) {
  const message: admin.messaging.Message = {
    condition, // "'news' in topics && 'premium' in topics"
    notification: {
      title,
      body,
    },
  };

  const response = await messaging.send(message);
  return response;
}

// 使用例
await sendToCondition(
  "'sports' in topics || 'entertainment' in topics",
  'おすすめコンテンツ',
  '新しいコンテンツが追加されました'
);
```

---

## Apple Push Notification Service (APNs)

### セットアップ（APNs通信）

```bash
npm install apn
```

```typescript
import apn from 'apn';

const provider = new apn.Provider({
  token: {
    key: './AuthKey.p8',
    keyId: process.env.APNS_KEY_ID!,
    teamId: process.env.APNS_TEAM_ID!,
  },
  production: process.env.NODE_ENV === 'production',
});
```

### 通知送信

```typescript
async function sendAPNsNotification(
  deviceToken: string,
  title: string,
  body: string
) {
  const notification = new apn.Notification();

  notification.alert = {
    title,
    body,
  };
  notification.sound = 'default';
  notification.badge = 1;
  notification.topic = process.env.APNS_BUNDLE_ID!;
  notification.payload = {
    type: 'message',
    timestamp: Date.now(),
  };

  try {
    const result = await provider.send(notification, deviceToken);

    if (result.failed.length > 0) {
      console.error('Failed to send:', result.failed);
    }

    if (result.sent.length > 0) {
      console.log('Successfully sent:', result.sent.length);
    }

    return result;
  } catch (error) {
    console.error('Error sending APNs notification:', error);
    throw error;
  }
}
```

### FCM経由でAPNs送信

```typescript
// FCMを使えばAPNsも統合可能
const message: admin.messaging.Message = {
  token: 'ios-device-token',
  notification: {
    title: '新着メッセージ',
    body: 'メッセージが届きました',
  },
  apns: {
    headers: {
      'apns-priority': '10',
    },
    payload: {
      aps: {
        alert: {
          title: '新着メッセージ',
          body: 'メッセージが届きました',
        },
        sound: 'default',
        badge: 1,
        'content-available': 1,
      },
      customData: {
        messageId: '123',
      },
    },
  },
};

await messaging.send(message);
```

---

## Web Push

### セットアップ

```bash
npm install web-push
```

### VAPID Key生成

```typescript
import webpush from 'web-push';

// VAPID Keyを生成
const vapidKeys = webpush.generateVAPIDKeys();

console.log('Public Key:', vapidKeys.publicKey);
console.log('Private Key:', vapidKeys.privateKey);

// .env に保存
// VAPID_PUBLIC_KEY=...
// VAPID_PRIVATE_KEY=...
// VAPID_EMAIL=mailto:your-email@example.com
```

### サーバー設定

```typescript
import webpush from 'web-push';

webpush.setVapidDetails(
  process.env.VAPID_EMAIL!,
  process.env.VAPID_PUBLIC_KEY!,
  process.env.VAPID_PRIVATE_KEY!
);

// Push購読情報を保存
interface PushSubscription {
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
}

app.post('/api/push/subscribe', async (req, res) => {
  const subscription: PushSubscription = req.body;
  const userId = req.user?.id;

  // データベースに保存
  await prisma.pushSubscription.create({
    data: {
      userId,
      endpoint: subscription.endpoint,
      p256dh: subscription.keys.p256dh,
      auth: subscription.keys.auth,
    },
  });

  res.json({ success: true });
});

// 通知送信
async function sendWebPush(subscription: PushSubscription, payload: any) {
  try {
    await webpush.sendNotification(subscription, JSON.stringify(payload));
    console.log('Web push sent successfully');
  } catch (error: any) {
    if (error.statusCode === 410) {
      // 購読が無効になった
      console.log('Subscription expired');
      // データベースから削除
    }
    console.error('Error sending web push:', error);
  }
}
```

### クライアント実装

```typescript
// service-worker.js
self.addEventListener('push', (event) => {
  const data = event.data?.json();

  const options = {
    body: data.body,
    icon: '/icon.png',
    badge: '/badge.png',
    data: data.data,
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    clients.openWindow(event.notification.data.url)
  );
});

// アプリケーション
async function subscribeToPush() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
    console.error('Push notifications not supported');
    return;
  }

  try {
    // Service Worker登録
    const registration = await navigator.serviceWorker.register('/service-worker.js');

    // 通知許可リクエスト
    const permission = await Notification.requestPermission();

    if (permission !== 'granted') {
      console.log('Notification permission denied');
      return;
    }

    // Push購読
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY!),
    });

    // サーバーに送信
    await fetch('/api/push/subscribe', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(subscription),
    });

    console.log('Push subscription successful');
  } catch (error) {
    console.error('Error subscribing to push:', error);
  }
}

function urlBase64ToUint8Array(base64String: string) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }

  return outputArray;
}
```

---

## 通知管理

### データベース設計

```prisma
model DeviceToken {
  id        String   @id @default(cuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  token     String   @unique
  platform  Platform
  active    Boolean  @default(true)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([userId])
  @@index([token])
}

enum Platform {
  IOS
  ANDROID
  WEB
}

model Notification {
  id          String   @id @default(cuid())
  userId      String
  user        User     @relation(fields: [userId], references: [id])
  title       String
  body        String
  data        Json?
  read        Boolean  @default(false)
  sentAt      DateTime @default(now())
  readAt      DateTime?

  @@index([userId])
  @@index([read])
}
```

### トークン登録

```typescript
app.post('/api/device-tokens', async (req, res) => {
  try {
    const { token, platform } = req.body;
    const userId = req.user?.id;

    // 既存のトークンをチェック
    const existing = await prisma.deviceToken.findUnique({
      where: { token },
    });

    if (existing) {
      // 更新
      await prisma.deviceToken.update({
        where: { token },
        data: {
          userId,
          active: true,
          updatedAt: new Date(),
        },
      });
    } else {
      // 新規作成
      await prisma.deviceToken.create({
        data: {
          userId,
          token,
          platform,
          active: true,
        },
      });
    }

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to register token' });
  }
});
```

### 通知送信

```typescript
async function sendNotificationToUser(
  userId: string,
  title: string,
  body: string,
  data?: any
) {
  // デバイストークン取得
  const tokens = await prisma.deviceToken.findMany({
    where: {
      userId,
      active: true,
    },
  });

  if (tokens.length === 0) {
    console.log('No active tokens for user:', userId);
    return;
  }

  // 通知履歴を保存
  await prisma.notification.create({
    data: {
      userId,
      title,
      body,
      data: data || {},
    },
  });

  // 各プラットフォームに送信
  const promises = tokens.map((token) => {
    switch (token.platform) {
      case 'IOS':
      case 'ANDROID':
        return sendFCMNotification(token.token, title, body, data);
      case 'WEB':
        return sendWebPushNotification(token.token, title, body, data);
      default:
        return Promise.resolve();
    }
  });

  const results = await Promise.allSettled(promises);

  // 失敗したトークンを無効化
  results.forEach((result, index) => {
    if (result.status === 'rejected') {
      prisma.deviceToken.update({
        where: { token: tokens[index].token },
        data: { active: false },
      });
    }
  });
}
```

---

## マルチプラットフォーム

### 統一インターフェース

```typescript
interface NotificationService {
  send(token: string, title: string, body: string, data?: any): Promise<void>;
  sendMultiple(tokens: string[], title: string, body: string, data?: any): Promise<void>;
}

class FCMService implements NotificationService {
  async send(token: string, title: string, body: string, data?: any) {
    const message: admin.messaging.Message = {
      token,
      notification: { title, body },
      data,
    };
    await messaging.send(message);
  }

  async sendMultiple(tokens: string[], title: string, body: string, data?: any) {
    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: { title, body },
      data,
    };
    await messaging.sendEachForMulticast(message);
  }
}

class WebPushService implements NotificationService {
  async send(token: string, title: string, body: string, data?: any) {
    const subscription = await this.getSubscription(token);
    await webpush.sendNotification(
      subscription,
      JSON.stringify({ title, body, data })
    );
  }

  async sendMultiple(tokens: string[], title: string, body: string, data?: any) {
    await Promise.all(
      tokens.map((token) => this.send(token, title, body, data))
    );
  }

  private async getSubscription(token: string): Promise<PushSubscription> {
    // トークンから購読情報を取得
    return {} as PushSubscription;
  }
}

// 使用例
const notificationService = new FCMService();
await notificationService.send('token', 'タイトル', '本文');
```

---

## トピック・セグメント

### ユーザーセグメント

```typescript
async function sendToSegment(
  segment: 'active' | 'inactive' | 'premium',
  title: string,
  body: string
) {
  let users: User[] = [];

  switch (segment) {
    case 'active':
      users = await prisma.user.findMany({
        where: {
          lastActiveAt: {
            gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
          },
        },
      });
      break;

    case 'inactive':
      users = await prisma.user.findMany({
        where: {
          lastActiveAt: {
            lt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
          },
        },
      });
      break;

    case 'premium':
      users = await prisma.user.findMany({
        where: {
          subscription: {
            status: 'ACTIVE',
          },
        },
      });
      break;
  }

  for (const user of users) {
    await sendNotificationToUser(user.id, title, body);
  }
}
```

---

## ベストプラクティス

### 1. 通知頻度制限

```typescript
async function canSendNotification(userId: string): Promise<boolean> {
  const lastNotification = await prisma.notification.findFirst({
    where: { userId },
    orderBy: { sentAt: 'desc' },
  });

  if (!lastNotification) {
    return true;
  }

  // 1時間以内に送信していたらスキップ
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  return lastNotification.sentAt < oneHourAgo;
}
```

### 2. バッチ送信

```typescript
async function sendBatchNotifications(
  userIds: string[],
  title: string,
  body: string
) {
  const batchSize = 100;

  for (let i = 0; i < userIds.length; i += batchSize) {
    const batch = userIds.slice(i, i + batchSize);

    await Promise.all(
      batch.map((userId) => sendNotificationToUser(userId, title, body))
    );

    // レート制限回避のため少し待つ
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
}
```

### 3. リトライロジック

```typescript
async function sendWithRetry(
  token: string,
  title: string,
  body: string,
  maxRetries = 3
) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await sendFCMNotification(token, title, body);
      return;
    } catch (error) {
      if (i === maxRetries - 1) {
        throw error;
      }
      await new Promise((resolve) => setTimeout(resolve, Math.pow(2, i) * 1000));
    }
  }
}
```

---

## 参考リンク

- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)
- [Web Push Protocol](https://datatracker.ietf.org/doc/html/rfc8030)
