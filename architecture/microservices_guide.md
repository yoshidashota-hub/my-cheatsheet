# マイクロサービスアーキテクチャ完全ガイド

## 目次
- [マイクロサービスとは](#マイクロサービスとは)
- [サービス分割](#サービス分割)
- [通信パターン](#通信パターン)
- [API Gateway](#api-gateway)
- [データ管理](#データ管理)
- [デプロイ戦略](#デプロイ戦略)
- [モニタリング](#モニタリング)
- [課題と対策](#課題と対策)

---

## マイクロサービスとは

アプリケーションを小さな独立したサービスの集合として構築するアーキテクチャスタイル。

### 特徴

- 🎯 単一責任: 各サービスは1つのビジネス機能に集中
- 🔄 独立デプロイ: サービスごとに独立してデプロイ可能
- 🛠️ 技術多様性: サービスごとに最適な技術を選択可能
- 📦 疎結合: サービス間の依存を最小化
- 🔀 分散システム: ネットワーク越しに通信

### メリット

```
✓ スケーラビリティ: 必要なサービスのみスケール
✓ 開発速度: チーム独立、並行開発可能
✓ 障害分離: 1サービスの障害が全体に波及しない
✓ 技術選択の自由: サービスごとに最適な技術スタック
✓ 段階的リプレース: 部分的な書き換えが可能
```

### デメリット

```
✗ 複雑性増加: 分散システムの複雑さ
✗ データ整合性: トランザクション管理が困難
✗ ネットワーク遅延: サービス間通信のオーバーヘッド
✗ デバッグ困難: 複数サービスにまたがる問題の追跡
✗ 運用コスト: デプロイ・モニタリングの複雑化
```

---

## サービス分割

### ドメイン駆動設計による分割

```
境界づけられたコンテキスト（Bounded Context）を基準に分割

例: ECサイト
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  User       │  │  Product    │  │  Order      │
│  Service    │  │  Service    │  │  Service    │
├─────────────┤  ├─────────────┤  ├─────────────┤
│ - 認証      │  │ - 商品管理  │  │ - 注文処理  │
│ - プロフィ  │  │ - 在庫管理  │  │ - 決済      │
│ - 権限      │  │ - カテゴリ  │  │ - 配送      │
└─────────────┘  └─────────────┘  └─────────────┘
```

### ビジネス機能による分割

```typescript
// サービス例
- User Service: ユーザー管理
- Product Service: 商品管理
- Order Service: 注文処理
- Payment Service: 決済処理
- Notification Service: 通知
- Search Service: 検索
- Recommendation Service: レコメンド
```

### 分割の原則

```
1. 単一責任の原則
   各サービスは1つのビジネス機能に集中

2. 自律性
   他サービスに依存せず動作可能

3. ドメイン知識のカプセル化
   ビジネスロジックをサービス内に閉じ込める

4. データの所有権
   各サービスが自分のデータを所有・管理

5. APIファースト
   明確なインターフェースで通信
```

### サービスサイズ

```
Two Pizza Team Rule (Amazon):
- 2枚のピザで養えるチームサイズ (5-8人)
- サービスはこのチームで管理できるサイズ

実装規模:
- Small: 数百〜数千行
- Medium: 数千〜1万行
- Large: 1万行以上（大きすぎる場合は分割検討）
```

---

## 通信パターン

### 同期通信（REST API）

```typescript
// User Service → Order Service
import axios from 'axios'

async function createOrder(userId: string, items: CartItem[]) {
  // ユーザー情報取得
  const user = await axios.get(`http://user-service/users/${userId}`)

  // 在庫確認
  const inventory = await axios.post('http://product-service/inventory/check', {
    items
  })

  if (!inventory.available) {
    throw new Error('在庫不足')
  }

  // 注文作成
  const order = await axios.post('http://order-service/orders', {
    userId,
    items,
    user: user.data
  })

  return order.data
}
```

### 非同期通信（メッセージング）

```typescript
// Order Service: イベント発行
import { publishEvent } from './message-broker'

async function createOrder(data: OrderData) {
  const order = await db.orders.create(data)

  // イベント発行
  await publishEvent('order.created', {
    orderId: order.id,
    userId: order.userId,
    items: order.items,
    total: order.total
  })

  return order
}

// Payment Service: イベント購読
import { subscribeToEvent } from './message-broker'

subscribeToEvent('order.created', async (event) => {
  const { orderId, total } = event.data

  // 決済処理
  await processPayment(orderId, total)

  // 完了イベント発行
  await publishEvent('payment.completed', { orderId })
})

// Notification Service: イベント購読
subscribeToEvent('payment.completed', async (event) => {
  const { orderId } = event.data

  // 通知送信
  await sendNotification(orderId)
})
```

### gRPC

```protobuf
// user.proto
syntax = "proto3";

service UserService {
  rpc GetUser (GetUserRequest) returns (User);
  rpc CreateUser (CreateUserRequest) returns (User);
}

message GetUserRequest {
  string user_id = 1;
}

message User {
  string id = 1;
  string name = 2;
  string email = 3;
}
```

```typescript
// サーバー側
import { Server, ServerCredentials } from '@grpc/grpc-js'

const server = new Server()

server.addService(UserServiceService, {
  getUser: async (call, callback) => {
    const user = await db.users.findById(call.request.user_id)
    callback(null, user)
  }
})

server.bindAsync('0.0.0.0:50051', ServerCredentials.createInsecure(), () => {
  server.start()
})

// クライアント側
import { UserServiceClient } from './generated/user_grpc_pb'

const client = new UserServiceClient('localhost:50051', grpc.credentials.createInsecure())

client.getUser({ user_id: '123' }, (err, response) => {
  console.log(response.toObject())
})
```

---

## API Gateway

クライアントとマイクロサービス間の単一エントリーポイント。

### 役割

```
1. ルーティング
   リクエストを適切なサービスに転送

2. 認証・認可
   統一的な認証処理

3. レート制限
   API呼び出しの制御

4. ロードバランシング
   複数インスタンスへの負荷分散

5. レスポンス集約
   複数サービスの結果を集約

6. プロトコル変換
   HTTP → gRPC等の変換
```

### 実装例（Express + http-proxy-middleware）

```typescript
import express from 'express'
import { createProxyMiddleware } from 'http-proxy-middleware'
import jwt from 'jsonwebtoken'

const app = express()

// 認証ミドルウェア
const authenticate = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1]

  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' })
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!)
    req.user = decoded
    next()
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' })
  }
}

// User Service
app.use('/api/users', authenticate, createProxyMiddleware({
  target: 'http://user-service:3001',
  changeOrigin: true,
  pathRewrite: { '^/api/users': '' }
}))

// Product Service
app.use('/api/products', createProxyMiddleware({
  target: 'http://product-service:3002',
  changeOrigin: true,
  pathRewrite: { '^/api/products': '' }
}))

// Order Service
app.use('/api/orders', authenticate, createProxyMiddleware({
  target: 'http://order-service:3003',
  changeOrigin: true,
  pathRewrite: { '^/api/orders': '' }
}))

app.listen(3000)
```

### Kong / Nginx

```nginx
# nginx.conf
upstream user_service {
  server user-service:3001;
}

upstream product_service {
  server product-service:3002;
}

server {
  listen 80;

  location /api/users {
    proxy_pass http://user_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

  location /api/products {
    proxy_pass http://product_service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

---

## データ管理

### Database per Service

各サービスが専用のデータベースを持つ。

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ User        │  │ Product     │  │ Order       │
│ Service     │  │ Service     │  │ Service     │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
│ User DB     │  │ Product DB  │  │ Order DB    │
│ (PostgreSQL)│  │ (PostgreSQL)│  │ (MongoDB)   │
└─────────────┘  └─────────────┘  └─────────────┘
```

### Saga パターン

分散トランザクションの管理。

```typescript
// Orchestration-based Saga
class OrderSagaOrchestrator {
  async createOrder(orderData: OrderData) {
    const sagaId = generateId()

    try {
      // Step 1: 注文作成
      const order = await orderService.createOrder(sagaId, orderData)

      // Step 2: 在庫確保
      await inventoryService.reserve(sagaId, order.items)

      // Step 3: 決済処理
      await paymentService.charge(sagaId, order.total)

      // Step 4: 配送手配
      await shippingService.arrange(sagaId, order.id)

      // 成功
      await orderService.confirmOrder(order.id)

    } catch (error) {
      // 補償トランザクション（ロールバック）
      await this.compensate(sagaId, error)
      throw error
    }
  }

  async compensate(sagaId: string, error: Error) {
    // 逆順でロールバック
    await shippingService.cancel(sagaId)
    await paymentService.refund(sagaId)
    await inventoryService.release(sagaId)
    await orderService.cancelOrder(sagaId)
  }
}
```

### Event Sourcing

イベントを記録してデータを再構築。

```typescript
// イベント定義
interface OrderEvent {
  eventId: string
  orderId: string
  type: string
  timestamp: Date
  data: any
}

// イベント保存
class OrderEventStore {
  async appendEvent(event: OrderEvent) {
    await db.events.insert(event)
    await this.publishEvent(event)
  }

  async getEvents(orderId: string): Promise<OrderEvent[]> {
    return await db.events.find({ orderId }).sort({ timestamp: 1 })
  }
}

// 状態再構築
class OrderProjection {
  async getOrderState(orderId: string) {
    const events = await eventStore.getEvents(orderId)

    let state = { status: 'pending', items: [], total: 0 }

    for (const event of events) {
      state = this.applyEvent(state, event)
    }

    return state
  }

  applyEvent(state: any, event: OrderEvent) {
    switch (event.type) {
      case 'OrderCreated':
        return { ...state, ...event.data }
      case 'PaymentCompleted':
        return { ...state, status: 'paid' }
      case 'OrderShipped':
        return { ...state, status: 'shipped' }
      default:
        return state
    }
  }
}
```

---

## デプロイ戦略

### コンテナ化

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["node", "dist/index.js"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  user-service:
    build: ./user-service
    ports:
      - "3001:3000"
    environment:
      - DATABASE_URL=postgresql://...
      - JWT_SECRET=secret
    depends_on:
      - user-db

  product-service:
    build: ./product-service
    ports:
      - "3002:3000"
    depends_on:
      - product-db

  user-db:
    image: postgres:15
    environment:
      - POSTGRES_DB=users
      - POSTGRES_PASSWORD=password
```

### Kubernetes

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: user-service:1.0.0
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

---
apiVersion: v1
kind: Service
metadata:
  name: user-service
spec:
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 3000
```

---

## モニタリング

### 分散トレーシング

```typescript
// OpenTelemetry
import { trace } from '@opentelemetry/api'

const tracer = trace.getTracer('user-service')

async function getUser(userId: string) {
  const span = tracer.startSpan('getUser')

  try {
    span.setAttribute('userId', userId)

    const user = await db.users.findById(userId)

    span.setStatus({ code: SpanStatusCode.OK })
    return user
  } catch (error) {
    span.setStatus({ code: SpanStatusCode.ERROR, message: error.message })
    throw error
  } finally {
    span.end()
  }
}
```

### ログ集約

```typescript
// 構造化ログ
import pino from 'pino'

const logger = pino({
  level: 'info',
  base: {
    service: 'user-service',
    version: '1.0.0'
  }
})

logger.info({ userId, action: 'login' }, 'User logged in')
```

---

## 課題と対策

### ネットワーク障害

```typescript
// Circuit Breaker
import CircuitBreaker from 'opossum'

const options = {
  timeout: 3000,
  errorThresholdPercentage: 50,
  resetTimeout: 30000
}

const breaker = new CircuitBreaker(callExternalService, options)

breaker.fallback(() => ({ fallback: true }))

breaker.on('open', () => {
  logger.warn('Circuit breaker opened')
})
```

### データ整合性

```
- Eventual Consistency を受け入れる
- Saga パターンで補償トランザクション
- Event Sourcing でイベント記録
- Outbox パターンでメッセージング保証
```

---

## 参考リンク

- [Microservices.io](https://microservices.io/)
- [Building Microservices - Sam Newman](https://samnewman.io/books/building_microservices/)
