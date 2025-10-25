# AWS EventBridge 完全ガイド

## 目次
- [EventBridgeとは](#eventbridgeとは)
- [イベントパターン](#イベントパターン)
- [ルールとターゲット](#ルールとターゲット)
- [カスタムイベントバス](#カスタムイベントバス)
- [イベント送信](#イベント送信)
- [Schema Registry](#schema-registry)
- [Serverless Framework統合](#serverless-framework統合)
- [アーカイブとリプレイ](#アーカイブとリプレイ)
- [ベストプラクティス](#ベストプラクティス)

---

## EventBridgeとは

AWS のサーバーレスイベントバスサービス。アプリケーション間でイベントを配信するイベント駆動アーキテクチャの中核。

### 特徴

- 📨 イベントルーティング: イベントを適切なターゲットへ配信
- 🔄 疎結合: サービス間の疎結合を実現
- 🎯 フィルタリング: 柔軟なイベントパターンマッチング
- 🌍 マルチアカウント: アカウント・リージョン間でイベント配信
- 📊 Schema Registry: イベント構造の管理
- 💰 従量課金: 100万イベントあたり$1.00

### ユースケース

```
✓ マイクロサービス連携
✓ リアルタイムデータ処理
✓ SaaS 統合
✓ 監視・アラート
✓ イベントソーシング
✓ ワークフロー トリガー
```

---

## イベントパターン

### 基本構造

```json
{
  "source": "com.myapp.orders",
  "detail-type": "OrderPlaced",
  "detail": {
    "orderId": "123",
    "userId": "user-456",
    "amount": 1000
  }
}
```

### パターンマッチング

#### 完全一致

```json
{
  "source": ["com.myapp.orders"],
  "detail-type": ["OrderPlaced"]
}
```

#### プレフィックス一致

```json
{
  "source": [{ "prefix": "com.myapp" }]
}
```

#### Anything-but（除外）

```json
{
  "detail": {
    "status": [{ "anything-but": "cancelled" }]
  }
}
```

#### 数値範囲

```json
{
  "detail": {
    "amount": [{ "numeric": [">", 100] }]
  }
}
```

```json
{
  "detail": {
    "price": [{ "numeric": [">=", 100, "<=", 500] }]
  }
}
```

#### OR条件

```json
{
  "detail": {
    "status": ["pending", "approved", "shipped"]
  }
}
```

#### AND条件（ネスト）

```json
{
  "source": ["com.myapp.orders"],
  "detail-type": ["OrderPlaced"],
  "detail": {
    "amount": [{ "numeric": [">", 100] }],
    "status": ["pending"]
  }
}
```

#### 存在チェック

```json
{
  "detail": {
    "userId": [{ "exists": true }]
  }
}
```

---

## ルールとターゲット

### Lambda をターゲットにする

```typescript
// functions/processOrder.ts
import { EventBridgeHandler } from 'aws-lambda'

interface OrderEvent {
  orderId: string
  userId: string
  amount: number
}

export const handler: EventBridgeHandler<'OrderPlaced', OrderEvent, void> = async (event) => {
  console.log('Received event:', JSON.stringify(event, null, 2))

  const { orderId, userId, amount } = event.detail

  // 注文処理
  console.log(`Processing order ${orderId} for user ${userId}, amount: ${amount}`)

  // DynamoDB への保存等
  // ...
}
```

### Step Functions をターゲットにする

```json
{
  "Arn": "arn:aws:states:ap-northeast-1:123456789:stateMachine:OrderWorkflow",
  "RoleArn": "arn:aws:iam::123456789:role/EventBridgeStepFunctionsRole",
  "Input": "$.detail"
}
```

### SQS をターゲットにする

```json
{
  "Arn": "arn:aws:sqs:ap-northeast-1:123456789:OrderQueue",
  "MessageGroupId": "$.detail.userId"
}
```

### SNS をターゲットにする

```json
{
  "Arn": "arn:aws:sns:ap-northeast-1:123456789:OrderTopic",
  "Message": "$.detail"
}
```

### Input Transformer

```json
{
  "Arn": "arn:aws:lambda:...:function:ProcessOrder",
  "InputTransformer": {
    "InputPathsMap": {
      "orderId": "$.detail.orderId",
      "userId": "$.detail.userId"
    },
    "InputTemplate": "{\"order_id\": <orderId>, \"user_id\": <userId>, \"processed_at\": \"<aws.events.event.ingestion-time>\"}"
  }
}
```

---

## カスタムイベントバス

### イベントバス作成

```bash
# AWS CLI
aws events create-event-bus --name my-app-bus
```

```yaml
# serverless.yml
resources:
  Resources:
    MyAppEventBus:
      Type: AWS::Events::EventBus
      Properties:
        Name: my-app-bus-${self:provider.stage}
```

### クロスアカウント・クロスリージョン

```json
// イベントバスのリソースポリシー
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAccountToPutEvents",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:root"
      },
      "Action": "events:PutEvents",
      "Resource": "arn:aws:events:ap-northeast-1:111111111111:event-bus/my-app-bus"
    }
  ]
}
```

---

## イベント送信

### SDK を使用してイベント送信

```typescript
// utils/eventBridge.ts
import { EventBridgeClient, PutEventsCommand } from '@aws-sdk/client-eventbridge'

const eventBridge = new EventBridgeClient({})

export async function publishEvent(
  source: string,
  detailType: string,
  detail: any,
  eventBusName = 'default'
) {
  const command = new PutEventsCommand({
    Entries: [
      {
        Source: source,
        DetailType: detailType,
        Detail: JSON.stringify(detail),
        EventBusName: eventBusName
      }
    ]
  })

  const result = await eventBridge.send(command)

  if (result.FailedEntryCount && result.FailedEntryCount > 0) {
    console.error('Failed to publish event:', result.Entries)
    throw new Error('Failed to publish event')
  }

  return result
}
```

### 使用例

```typescript
// functions/createOrder.ts
import { publishEvent } from '../utils/eventBridge'

export const handler = async (event: any) => {
  // 注文作成処理
  const order = {
    orderId: crypto.randomUUID(),
    userId: event.userId,
    items: event.items,
    amount: 1000,
    createdAt: new Date().toISOString()
  }

  // DynamoDB に保存
  // ...

  // イベント発行
  await publishEvent(
    'com.myapp.orders',
    'OrderPlaced',
    order
  )

  return {
    statusCode: 200,
    body: JSON.stringify(order)
  }
}
```

### 複数イベント一括送信

```typescript
import { PutEventsCommand } from '@aws-sdk/client-eventbridge'

const entries = orders.map(order => ({
  Source: 'com.myapp.orders',
  DetailType: 'OrderPlaced',
  Detail: JSON.stringify(order),
  EventBusName: 'my-app-bus'
}))

const command = new PutEventsCommand({ Entries: entries })
await eventBridge.send(command)
```

---

## Schema Registry

### スキーマ定義

```json
{
  "openapi": "3.0.0",
  "info": {
    "version": "1.0.0",
    "title": "OrderPlaced"
  },
  "paths": {},
  "components": {
    "schemas": {
      "OrderPlaced": {
        "type": "object",
        "required": ["orderId", "userId", "amount"],
        "properties": {
          "orderId": {
            "type": "string"
          },
          "userId": {
            "type": "string"
          },
          "amount": {
            "type": "number"
          },
          "items": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "productId": { "type": "string" },
                "quantity": { "type": "number" }
              }
            }
          }
        }
      }
    }
  }
}
```

### スキーマレジストリ作成

```bash
# レジストリ作成
aws schemas create-registry --registry-name my-app-registry

# スキーマ作成
aws schemas create-schema \
  --registry-name my-app-registry \
  --schema-name com.myapp.orders.OrderPlaced \
  --type OpenApi3 \
  --content file://order-schema.json
```

### TypeScript 型生成

```bash
# AWS CLI でコード生成
aws schemas get-code-binding-source \
  --registry-name my-app-registry \
  --schema-name com.myapp.orders.OrderPlaced \
  --language TypeScript
```

---

## Serverless Framework統合

### serverless.yml

```yaml
# serverless.yml
service: event-driven-app

provider:
  name: aws
  runtime: nodejs18.x
  region: ap-northeast-1

  environment:
    EVENT_BUS_NAME: ${self:service}-${self:provider.stage}-bus

  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - events:PutEvents
          Resource: "*"

functions:
  # イベント発行者
  createOrder:
    handler: src/functions/createOrder.handler
    events:
      - httpApi:
          path: /orders
          method: post

  # イベント購読者
  processOrder:
    handler: src/functions/processOrder.handler
    events:
      - eventBridge:
          eventBus: ${self:custom.eventBusArn}
          pattern:
            source:
              - com.myapp.orders
            detail-type:
              - OrderPlaced

  sendOrderEmail:
    handler: src/functions/sendOrderEmail.handler
    events:
      - eventBridge:
          eventBus: ${self:custom.eventBusArn}
          pattern:
            source:
              - com.myapp.orders
            detail-type:
              - OrderPlaced
            detail:
              amount:
                - numeric:
                    - ">"
                    - 1000

  updateInventory:
    handler: src/functions/updateInventory.handler
    events:
      - eventBridge:
          eventBus: ${self:custom.eventBusArn}
          pattern:
            source:
              - com.myapp.orders
            detail-type:
              - OrderPlaced

custom:
  eventBusArn:
    Fn::GetAtt: [EventBus, Arn]

resources:
  Resources:
    EventBus:
      Type: AWS::Events::EventBus
      Properties:
        Name: ${self:provider.environment.EVENT_BUS_NAME}

  Outputs:
    EventBusName:
      Value:
        Ref: EventBus
      Export:
        Name: ${self:service}-${self:provider.stage}-event-bus-name

    EventBusArn:
      Value:
        Fn::GetAtt: [EventBus, Arn]
      Export:
        Name: ${self:service}-${self:provider.stage}-event-bus-arn
```

---

## アーカイブとリプレイ

### アーカイブ作成

```yaml
resources:
  Resources:
    EventArchive:
      Type: AWS::Events::Archive
      Properties:
        ArchiveName: my-app-archive-${self:provider.stage}
        SourceArn:
          Fn::GetAtt: [EventBus, Arn]
        RetentionDays: 7
        EventPattern:
          source:
            - com.myapp.orders
```

### リプレイ実行

```bash
# AWS CLI でリプレイ
aws events start-replay \
  --replay-name my-replay \
  --event-source-arn arn:aws:events:ap-northeast-1:123456789:archive/my-app-archive \
  --event-start-time 2024-01-01T00:00:00Z \
  --event-end-time 2024-01-02T00:00:00Z \
  --destination '{"Arn":"arn:aws:events:ap-northeast-1:123456789:event-bus/my-app-bus"}'
```

---

## 実践パターン

### Event-Driven マイクロサービス

```typescript
// Order Service: イベント発行
export const createOrder = async (event: any) => {
  const order = await saveOrder(event)

  await publishEvent('com.myapp.orders', 'OrderPlaced', order)

  return { statusCode: 201, body: JSON.stringify(order) }
}

// Inventory Service: イベント処理
export const updateInventory = async (event: EventBridgeEvent<'OrderPlaced', Order>) => {
  const { items } = event.detail

  for (const item of items) {
    await decrementStock(item.productId, item.quantity)
  }

  await publishEvent('com.myapp.inventory', 'InventoryUpdated', {
    orderId: event.detail.orderId,
    items
  })
}

// Notification Service: イベント処理
export const sendNotification = async (event: EventBridgeEvent<'OrderPlaced', Order>) => {
  const { userId, orderId } = event.detail

  await sendEmail(userId, `Order ${orderId} has been placed`)

  await publishEvent('com.myapp.notifications', 'NotificationSent', {
    userId,
    type: 'order_placed',
    orderId
  })
}
```

### Saga パターン

```typescript
// Step 1: Create Order
export const createOrder = async (event: any) => {
  const order = await saveOrder(event)
  await publishEvent('com.myapp.saga', 'OrderCreated', order)
  return order
}

// Step 2: Reserve Inventory
export const reserveInventory = async (event: EventBridgeEvent<'OrderCreated', Order>) => {
  try {
    await reserveStock(event.detail.items)
    await publishEvent('com.myapp.saga', 'InventoryReserved', event.detail)
  } catch (error) {
    await publishEvent('com.myapp.saga', 'InventoryReserveFailed', {
      ...event.detail,
      error: error.message
    })
  }
}

// Step 3: Process Payment
export const processPayment = async (event: EventBridgeEvent<'InventoryReserved', Order>) => {
  try {
    const payment = await chargePayment(event.detail)
    await publishEvent('com.myapp.saga', 'PaymentProcessed', {
      ...event.detail,
      payment
    })
  } catch (error) {
    await publishEvent('com.myapp.saga', 'PaymentFailed', {
      ...event.detail,
      error: error.message
    })
  }
}

// Compensating Transaction
export const compensateOrder = async (event: EventBridgeEvent<'PaymentFailed', Order>) => {
  await releaseInventory(event.detail.items)
  await cancelOrder(event.detail.orderId)
  await publishEvent('com.myapp.saga', 'OrderCancelled', event.detail)
}
```

### Fanout パターン

```typescript
// 1つのイベントを複数のサービスで処理
await publishEvent('com.myapp.orders', 'OrderPlaced', order)

// 複数のLambda関数が同時に処理
// - sendOrderEmail
// - updateInventory
// - updateAnalytics
// - notifySlack
```

---

## ベストプラクティス

### 1. イベント命名規則

```
Source: 逆ドメイン形式
- com.myapp.orders
- com.myapp.payments

Detail-Type: 過去形
- OrderPlaced
- PaymentProcessed
- UserRegistered
```

### 2. イベント構造の標準化

```typescript
interface BaseEvent {
  id: string
  timestamp: string
  version: string
}

interface OrderPlacedEvent extends BaseEvent {
  orderId: string
  userId: string
  amount: number
  items: Array<{
    productId: string
    quantity: number
  }>
}
```

### 3. エラーハンドリング

```typescript
export const handler = async (event: EventBridgeEvent<any, any>) => {
  try {
    await processEvent(event)
  } catch (error) {
    console.error('Error processing event:', error)

    // エラーイベント発行
    await publishEvent(
      'com.myapp.errors',
      'EventProcessingFailed',
      {
        originalEvent: event,
        error: error.message,
        timestamp: new Date().toISOString()
      }
    )

    throw error // DLQ へ送信
  }
}
```

### 4. Dead Letter Queue 設定

```yaml
functions:
  processOrder:
    handler: handler.processOrder
    events:
      - eventBridge:
          pattern:
            source:
              - com.myapp.orders
    destinations:
      onFailure:
        arn:
          Fn::GetAtt: [OrderDLQ, Arn]

resources:
  Resources:
    OrderDLQ:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: order-processing-dlq-${self:provider.stage}
        MessageRetentionPeriod: 1209600  # 14日間
```

### 5. イベントバージョニング

```typescript
interface OrderPlacedV1 {
  version: '1.0'
  orderId: string
  userId: string
}

interface OrderPlacedV2 {
  version: '2.0'
  orderId: string
  userId: string
  items: Item[]  // 新フィールド
}

export const handler = async (event: EventBridgeEvent<any, any>) => {
  const { version } = event.detail

  if (version === '1.0') {
    return processV1(event.detail as OrderPlacedV1)
  }
  if (version === '2.0') {
    return processV2(event.detail as OrderPlacedV2)
  }

  throw new Error(`Unsupported version: ${version}`)
}
```

### 6. べき等性の確保

```typescript
const processedEvents = new Set<string>()

export const handler = async (event: EventBridgeEvent<any, any>) => {
  const eventId = event.id

  // 重複チェック（DynamoDBやRedisで実装）
  if (await isProcessed(eventId)) {
    console.log('Event already processed:', eventId)
    return
  }

  // 処理
  await processEvent(event)

  // 処理済みマーク
  await markAsProcessed(eventId)
}
```

### 7. メトリクス・モニタリング

```typescript
import { CloudWatch } from '@aws-sdk/client-cloudwatch'

const cloudwatch = new CloudWatch({})

export const handler = async (event: EventBridgeEvent<any, any>) => {
  const startTime = Date.now()

  try {
    await processEvent(event)

    // 成功メトリクス
    await cloudwatch.putMetricData({
      Namespace: 'MyApp/Events',
      MetricData: [
        {
          MetricName: 'EventProcessed',
          Value: 1,
          Unit: 'Count',
          Dimensions: [
            { Name: 'EventType', Value: event['detail-type'] }
          ]
        },
        {
          MetricName: 'ProcessingTime',
          Value: Date.now() - startTime,
          Unit: 'Milliseconds'
        }
      ]
    })
  } catch (error) {
    // 失敗メトリクス
    await cloudwatch.putMetricData({
      Namespace: 'MyApp/Events',
      MetricData: [
        {
          MetricName: 'EventFailed',
          Value: 1,
          Unit: 'Count',
          Dimensions: [
            { Name: 'EventType', Value: event['detail-type'] }
          ]
        }
      ]
    })

    throw error
  }
}
```

---

## 参考リンク

- [AWS EventBridge Documentation](https://docs.aws.amazon.com/eventbridge/)
- [EventBridge Event Patterns](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html)
- [EventBridge Schema Registry](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-schema.html)
