# イベント駆動アーキテクチャ完全ガイド

## 目次
- [イベント駆動アーキテクチャとは](#イベント駆動アーキテクチャとは)
- [イベントソーシング](#イベントソーシング)
- [CQRS](#cqrs)
- [Sagaパターン](#sagaパターン)
- [実装例](#実装例)
- [メリット・デメリット](#メリットデメリット)

---

## イベント駆動アーキテクチャとは

イベントの発生と処理を中心に設計されたアーキテクチャパターン。

### 基本概念

```
Event (イベント): システム内で発生した出来事
Producer (生産者): イベントを発行
Consumer (消費者): イベントを受信・処理
Event Bus: イベントの配信システム
```

### アーキテクチャ図

```
┌──────────┐       ┌──────────────┐       ┌──────────┐
│ Producer │──────▶│  Event Bus   │──────▶│ Consumer │
│ (発行者)  │       │ (メッセージ)  │       │ (購読者)  │
└──────────┘       └──────────────┘       └──────────┘
                           │
                           ├──────▶ Consumer 2
                           │
                           └──────▶ Consumer 3

非同期・疎結合
```

### 特徴

```
✓ 非同期処理
✓ 疎結合
✓ スケーラブル
✓ イベント履歴の保持
✓ 複数サービスの連携
```

---

## イベントソーシング

状態ではなく、状態変更のイベントを記録するパターン。

### 従来の方式 vs イベントソーシング

```
従来:
┌────────────┐
│  Users     │
├────────────┤
│ id: 1      │
│ name: John │ ← 現在の状態のみ保存
│ email: ... │
└────────────┘

イベントソーシング:
┌────────────────────────────────┐
│  Events                        │
├────────────────────────────────┤
│ 1. UserCreated { name: John }  │
│ 2. EmailUpdated { email: ... } │
│ 3. NameUpdated { name: Jane }  │ ← 全変更履歴を保存
└────────────────────────────────┘

現在の状態 = イベントの再生結果
```

### イベント定義

```typescript
// domain/events/UserEvents.ts
export interface DomainEvent {
  eventId: string
  aggregateId: string
  eventType: string
  timestamp: Date
  version: number
  data: any
}

export class UserCreatedEvent implements DomainEvent {
  constructor(
    public eventId: string,
    public aggregateId: string,
    public eventType: 'UserCreated',
    public timestamp: Date,
    public version: number,
    public data: {
      email: string
      name: string
    }
  ) {}
}

export class EmailUpdatedEvent implements DomainEvent {
  constructor(
    public eventId: string,
    public aggregateId: string,
    public eventType: 'EmailUpdated',
    public timestamp: Date,
    public version: number,
    public data: {
      oldEmail: string
      newEmail: string
    }
  ) {}
}
```

### Event Store

```typescript
// infrastructure/EventStore.ts
export class EventStore {
  constructor(private db: Database) {}

  async appendEvent(event: DomainEvent): Promise<void> {
    await this.db.events.insert({
      event_id: event.eventId,
      aggregate_id: event.aggregateId,
      event_type: event.eventType,
      timestamp: event.timestamp,
      version: event.version,
      data: JSON.stringify(event.data)
    })

    // イベントをパブリッシュ
    await this.publishEvent(event)
  }

  async getEvents(aggregateId: string): Promise<DomainEvent[]> {
    const rows = await this.db.events
      .where({ aggregate_id: aggregateId })
      .orderBy('version', 'asc')

    return rows.map(row => this.deserializeEvent(row))
  }

  async getEventsSince(version: number): Promise<DomainEvent[]> {
    const rows = await this.db.events
      .where('version', '>', version)
      .orderBy('version', 'asc')

    return rows.map(row => this.deserializeEvent(row))
  }

  private deserializeEvent(row: any): DomainEvent {
    return {
      eventId: row.event_id,
      aggregateId: row.aggregate_id,
      eventType: row.event_type,
      timestamp: row.timestamp,
      version: row.version,
      data: JSON.parse(row.data)
    }
  }
}
```

### 状態再構築

```typescript
// domain/aggregates/UserAggregate.ts
export class UserAggregate {
  private id: string
  private email: string
  private name: string
  private version: number = 0

  // イベントから状態を再構築
  static fromEvents(events: DomainEvent[]): UserAggregate {
    const user = new UserAggregate()

    for (const event of events) {
      user.applyEvent(event)
    }

    return user
  }

  private applyEvent(event: DomainEvent): void {
    switch (event.eventType) {
      case 'UserCreated':
        this.id = event.aggregateId
        this.email = event.data.email
        this.name = event.data.name
        break

      case 'EmailUpdated':
        this.email = event.data.newEmail
        break

      case 'NameUpdated':
        this.name = event.data.newName
        break
    }

    this.version = event.version
  }

  // コマンド実行 → イベント生成
  updateEmail(newEmail: string): EmailUpdatedEvent {
    if (!this.isValidEmail(newEmail)) {
      throw new Error('Invalid email')
    }

    return new EmailUpdatedEvent(
      generateId(),
      this.id,
      'EmailUpdated',
      new Date(),
      this.version + 1,
      { oldEmail: this.email, newEmail }
    )
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }
}
```

### スナップショット

```typescript
// パフォーマンス最適化：定期的にスナップショット作成
export class SnapshotStore {
  async saveSnapshot(aggregateId: string, state: any, version: number) {
    await this.db.snapshots.upsert({
      aggregate_id: aggregateId,
      version,
      state: JSON.stringify(state),
      created_at: new Date()
    })
  }

  async getSnapshot(aggregateId: string): Promise<{ state: any, version: number } | null> {
    const snapshot = await this.db.snapshots.findOne({ aggregate_id: aggregateId })
    if (!snapshot) return null

    return {
      state: JSON.parse(snapshot.state),
      version: snapshot.version
    }
  }
}

// 使用例
async function loadAggregate(aggregateId: string): Promise<UserAggregate> {
  // スナップショットから復元
  const snapshot = await snapshotStore.getSnapshot(aggregateId)

  if (snapshot) {
    const user = UserAggregate.fromSnapshot(snapshot.state)

    // スナップショット以降のイベントのみ適用
    const events = await eventStore.getEventsSince(aggregateId, snapshot.version)
    events.forEach(event => user.applyEvent(event))

    return user
  }

  // スナップショットがない場合は全イベントから復元
  const events = await eventStore.getEvents(aggregateId)
  return UserAggregate.fromEvents(events)
}
```

---

## CQRS

Command Query Responsibility Segregation（コマンドクエリ責務分離）

### 概念

```
Command (書き込み) と Query (読み取り) を分離

┌──────────────┐         ┌──────────────┐
│  Command     │         │    Query     │
│   Model      │         │    Model     │
├──────────────┤         ├──────────────┤
│ Write DB     │   sync  │  Read DB     │
│ (正規化)      │───────▶│ (非正規化)    │
└──────────────┘         └──────────────┘

メリット:
- 読み書きを独立してスケール
- 最適化されたデータモデル
- 複雑なクエリが簡単
```

### Command側

```typescript
// commands/CreateUserCommand.ts
export interface CreateUserCommand {
  userId: string
  email: string
  name: string
}

// command handlers
export class CreateUserCommandHandler {
  constructor(
    private eventStore: EventStore,
    private userRepository: UserRepository
  ) {}

  async handle(command: CreateUserCommand): Promise<void> {
    // バリデーション
    if (!command.email || !command.name) {
      throw new Error('Email and name are required')
    }

    // イベント作成
    const event = new UserCreatedEvent(
      generateId(),
      command.userId,
      'UserCreated',
      new Date(),
      1,
      { email: command.email, name: command.name }
    )

    // イベント保存
    await this.eventStore.appendEvent(event)
  }
}
```

### Query側

```typescript
// queries/GetUserQuery.ts
export interface GetUserQuery {
  userId: string
}

export interface UserReadModel {
  id: string
  email: string
  name: string
  createdAt: Date
  updatedAt: Date
}

// query handlers
export class GetUserQueryHandler {
  constructor(private readDb: Database) {}

  async handle(query: GetUserQuery): Promise<UserReadModel | null> {
    // Read DBから取得（非正規化済み）
    return await this.readDb.users.findOne({ id: query.userId })
  }
}

// リスト取得（複雑な集計も簡単）
export class GetUserListQueryHandler {
  async handle(): Promise<UserReadModel[]> {
    return await this.readDb.query(`
      SELECT
        u.id,
        u.email,
        u.name,
        u.created_at,
        COUNT(o.id) as order_count,
        SUM(o.total) as total_spent
      FROM users u
      LEFT JOIN orders o ON u.id = o.user_id
      GROUP BY u.id
    `)
  }
}
```

### Projection（読み取りモデル更新）

```typescript
// projections/UserProjection.ts
export class UserProjection {
  constructor(private readDb: Database) {}

  // イベントを購読して Read Model を更新
  async handleUserCreatedEvent(event: UserCreatedEvent): Promise<void> {
    await this.readDb.users.insert({
      id: event.aggregateId,
      email: event.data.email,
      name: event.data.name,
      created_at: event.timestamp,
      updated_at: event.timestamp
    })
  }

  async handleEmailUpdatedEvent(event: EmailUpdatedEvent): Promise<void> {
    await this.readDb.users.update(
      { id: event.aggregateId },
      { email: event.data.newEmail, updated_at: event.timestamp }
    )
  }
}
```

---

## Sagaパターン

分散トランザクションの管理パターン。

### Choreography-based Saga

各サービスがイベントを発行・購読して連携。

```
Order Service  → order.created
                      ↓
Payment Service → payment.completed
                      ↓
Shipping Service → shipping.arranged
                      ↓
Notification Service → notification.sent
```

```typescript
// Order Service
async function createOrder(data: OrderData) {
  const order = await db.orders.create(data)

  await publishEvent('order.created', {
    orderId: order.id,
    userId: data.userId,
    total: data.total
  })

  return order
}

// Payment Service
subscribeToEvent('order.created', async (event) => {
  try {
    await processPayment(event.data.orderId, event.data.total)

    await publishEvent('payment.completed', {
      orderId: event.data.orderId
    })
  } catch (error) {
    await publishEvent('payment.failed', {
      orderId: event.data.orderId,
      reason: error.message
    })
  }
})

// Shipping Service
subscribeToEvent('payment.completed', async (event) => {
  await arrangeShipping(event.data.orderId)

  await publishEvent('shipping.arranged', {
    orderId: event.data.orderId
  })
})
```

### Orchestration-based Saga

中央のオーケストレーターが制御。

```
        ┌─────────────────┐
        │ Saga Orchestrator│
        └────────┬─────────┘
                 │
    ┌────────────┼────────────┬──────────┐
    │            │            │          │
    ▼            ▼            ▼          ▼
Order      Payment      Shipping   Notification
Service    Service      Service    Service
```

```typescript
// saga/OrderSaga.ts
export class OrderSagaOrchestrator {
  async execute(orderData: OrderData) {
    const sagaId = generateId()
    const compensation: Function[] = []

    try {
      // Step 1: 注文作成
      const order = await orderService.createOrder(sagaId, orderData)
      compensation.push(() => orderService.cancelOrder(order.id))

      // Step 2: 在庫確保
      await inventoryService.reserve(sagaId, order.items)
      compensation.push(() => inventoryService.release(sagaId))

      // Step 3: 決済
      await paymentService.charge(sagaId, order.total)
      compensation.push(() => paymentService.refund(sagaId))

      // Step 4: 配送手配
      await shippingService.arrange(sagaId, order.id)

      // 成功
      await orderService.confirmOrder(order.id)

      return order
    } catch (error) {
      // 補償トランザクション実行（逆順）
      for (const compensate of compensation.reverse()) {
        try {
          await compensate()
        } catch (compensationError) {
          // ログ記録
          console.error('Compensation failed:', compensationError)
        }
      }

      throw error
    }
  }
}
```

---

## 実装例

### イベントバス

```typescript
// EventBus.ts
import { EventEmitter } from 'events'

export class EventBus {
  private emitter = new EventEmitter()

  publish(eventType: string, data: any): void {
    this.emitter.emit(eventType, data)
  }

  subscribe(eventType: string, handler: (data: any) => Promise<void>): void {
    this.emitter.on(eventType, async (data) => {
      try {
        await handler(data)
      } catch (error) {
        console.error(`Error handling ${eventType}:`, error)
      }
    })
  }
}

// 使用例
const eventBus = new EventBus()

// 購読
eventBus.subscribe('user.created', async (data) => {
  console.log('User created:', data)
  await sendWelcomeEmail(data.email)
})

// 発行
eventBus.publish('user.created', {
  userId: '123',
  email: 'user@example.com'
})
```

### RabbitMQ使用

```typescript
// EventBusRabbitMQ.ts
import amqp from 'amqplib'

export class EventBusRabbitMQ {
  private connection: amqp.Connection
  private channel: amqp.Channel

  async connect() {
    this.connection = await amqp.connect('amqp://localhost')
    this.channel = await this.connection.createChannel()
    await this.channel.assertExchange('events', 'topic', { durable: true })
  }

  async publish(eventType: string, data: any) {
    this.channel.publish(
      'events',
      eventType,
      Buffer.from(JSON.stringify(data)),
      { persistent: true }
    )
  }

  async subscribe(eventType: string, handler: (data: any) => Promise<void>) {
    const queue = await this.channel.assertQueue('', { exclusive: true })
    await this.channel.bindQueue(queue.queue, 'events', eventType)

    this.channel.consume(queue.queue, async (msg) => {
      if (msg) {
        const data = JSON.parse(msg.content.toString())
        await handler(data)
        this.channel.ack(msg)
      }
    })
  }
}
```

---

## メリット・デメリット

### メリット

```
✓ スケーラビリティ
  - 非同期処理で高スループット
  - サービスを独立してスケール

✓ 疎結合
  - サービス間の依存が少ない
  - 新サービスの追加が容易

✓ 監査ログ
  - 全イベント履歴が残る
  - デバッグ・監査が容易

✓ 時間遡行
  - 過去の状態を再現可能
  - バグ調査が容易

✓ 柔軟性
  - 複数のConsumerで処理可能
  - 後からConsumer追加可能
```

### デメリット

```
✗ 複雑性
  - 設計・実装が複雑
  - デバッグが困難

✗ Eventual Consistency
  - 即座に一貫性が保証されない
  - UXへの配慮が必要

✗ イベントバージョニング
  - イベントスキーマの変更が困難
  - 互換性維持が必要

✗ 学習コスト
  - チーム全体の理解が必要
  - 新メンバーの学習に時間
```

---

## 参考リンク

- [Event Sourcing - Martin Fowler](https://martinfowler.com/eaaDev/EventSourcing.html)
- [CQRS Pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [Saga Pattern](https://microservices.io/patterns/data/saga.html)
