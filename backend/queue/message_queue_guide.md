# メッセージキュー完全ガイド (RabbitMQ / AWS SQS)

## 目次
- [概要](#概要)
- [RabbitMQ](#rabbitmq)
- [AWS SQS](#aws-sqs)
- [比較](#比較)
- [パターン](#パターン)
- [ベストプラクティス](#ベストプラクティス)

---

## 概要

非同期メッセージングシステム。マイクロサービス間の通信やバックグラウンド処理に使用。

### ユースケース
- 📧 メール送信
- 🖼️ 画像処理
- 📊 データ集計
- 🔄 システム間連携
- ⚖️ 負荷分散

### 主要サービス
- **RabbitMQ**: オープンソース、高機能、セルフホスト
- **AWS SQS**: マネージドサービス、スケーラブル、簡単

---

## RabbitMQ

AMQP (Advanced Message Queuing Protocol) 実装のメッセージブローカー。

### インストール

```bash
# Docker
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:management

# 管理画面: http://localhost:15672 (guest/guest)
```

### Node.js クライアント

```bash
npm install amqplib
```

### Producer（送信）

```typescript
import amqp from 'amqplib'

async function sendMessage() {
  // 接続
  const connection = await amqp.connect('amqp://localhost')
  const channel = await connection.createChannel()

  // キュー作成
  const queue = 'task_queue'
  await channel.assertQueue(queue, { durable: true })

  // メッセージ送信
  const message = JSON.stringify({
    userId: '123',
    action: 'send_email',
    data: { email: 'user@example.com' }
  })

  channel.sendToQueue(queue, Buffer.from(message), {
    persistent: true
  })

  console.log('Sent:', message)

  // クローズ
  setTimeout(() => {
    connection.close()
  }, 500)
}

sendMessage()
```

### Consumer（受信）

```typescript
import amqp from 'amqplib'

async function consumeMessages() {
  const connection = await amqp.connect('amqp://localhost')
  const channel = await connection.createChannel()

  const queue = 'task_queue'
  await channel.assertQueue(queue, { durable: true })

  // 同時処理数制限
  channel.prefetch(1)

  console.log('Waiting for messages...')

  channel.consume(queue, async (msg) => {
    if (msg) {
      const content = msg.content.toString()
      console.log('Received:', content)

      try {
        const data = JSON.parse(content)
        await processMessage(data)

        // 処理成功 - ACK
        channel.ack(msg)
      } catch (error) {
        console.error('Error:', error)

        // 処理失敗 - Reject（再キュー）
        channel.nack(msg, false, true)
      }
    }
  })
}

async function processMessage(data: any) {
  // 実際の処理
  await new Promise(resolve => setTimeout(resolve, 1000))
  console.log('Processed:', data)
}

consumeMessages()
```

### Exchange パターン

#### Direct Exchange

```typescript
// Publisher
const exchange = 'direct_logs'
const routingKey = 'error'

await channel.assertExchange(exchange, 'direct', { durable: false })
channel.publish(exchange, routingKey, Buffer.from(message))

// Consumer
await channel.assertExchange(exchange, 'direct', { durable: false })
const q = await channel.assertQueue('', { exclusive: true })
await channel.bindQueue(q.queue, exchange, 'error')

channel.consume(q.queue, (msg) => {
  console.log('Received error:', msg.content.toString())
})
```

#### Fanout Exchange（Pub/Sub）

```typescript
// Publisher
const exchange = 'notifications'

await channel.assertExchange(exchange, 'fanout', { durable: false })
channel.publish(exchange, '', Buffer.from(message))

// Consumer
await channel.assertExchange(exchange, 'fanout', { durable: false })
const q = await channel.assertQueue('', { exclusive: true })
await channel.bindQueue(q.queue, exchange, '')

channel.consume(q.queue, (msg) => {
  console.log('Received:', msg.content.toString())
})
```

#### Topic Exchange

```typescript
// Publisher
const exchange = 'topic_logs'
const routingKey = 'user.created'

await channel.assertExchange(exchange, 'topic', { durable: false })
channel.publish(exchange, routingKey, Buffer.from(message))

// Consumer
await channel.assertExchange(exchange, 'topic', { durable: false })
const q = await channel.assertQueue('', { exclusive: true })
await channel.bindQueue(q.queue, exchange, 'user.*')

channel.consume(q.queue, (msg) => {
  console.log('Received:', msg.content.toString())
})
```

### Dead Letter Queue

```typescript
// メインキュー設定
await channel.assertQueue('main_queue', {
  durable: true,
  arguments: {
    'x-dead-letter-exchange': 'dlx',
    'x-dead-letter-routing-key': 'dead_letter'
  }
})

// DLX設定
await channel.assertExchange('dlx', 'direct', { durable: true })
await channel.assertQueue('dead_letter_queue', { durable: true })
await channel.bindQueue('dead_letter_queue', 'dlx', 'dead_letter')

// 失敗したメッセージはDLQへ
channel.consume('main_queue', (msg) => {
  try {
    // 処理
    channel.ack(msg)
  } catch (error) {
    // 再試行せずDLQへ
    channel.nack(msg, false, false)
  }
})
```

---

## AWS SQS

AWSのマネージドメッセージキューサービス。

### 種類

- **Standard Queue**: 最高スループット、順序保証なし、重複あり
- **FIFO Queue**: 順序保証、重複排除、スループット制限

### セットアップ

```bash
npm install @aws-sdk/client-sqs
```

### メッセージ送信

```typescript
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs'

const client = new SQSClient({ region: 'ap-northeast-1' })

async function sendMessage() {
  const command = new SendMessageCommand({
    QueueUrl: 'https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue',
    MessageBody: JSON.stringify({
      userId: '123',
      action: 'send_email',
      data: { email: 'user@example.com' }
    }),
    MessageAttributes: {
      Type: {
        DataType: 'String',
        StringValue: 'email'
      }
    }
  })

  const response = await client.send(command)
  console.log('MessageId:', response.MessageId)
}

sendMessage()
```

### メッセージ受信

```typescript
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs'

const client = new SQSClient({ region: 'ap-northeast-1' })
const queueUrl = 'https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue'

async function pollMessages() {
  while (true) {
    const command = new ReceiveMessageCommand({
      QueueUrl: queueUrl,
      MaxNumberOfMessages: 10,
      WaitTimeSeconds: 20, // ロングポーリング
      VisibilityTimeout: 30
    })

    const response = await client.send(command)

    if (!response.Messages) {
      continue
    }

    for (const message of response.Messages) {
      try {
        const body = JSON.parse(message.Body!)
        console.log('Processing:', body)

        await processMessage(body)

        // 処理成功 - メッセージ削除
        await client.send(new DeleteMessageCommand({
          QueueUrl: queueUrl,
          ReceiptHandle: message.ReceiptHandle!
        }))

        console.log('Deleted:', message.MessageId)
      } catch (error) {
        console.error('Error:', error)
        // 処理失敗 - VisibilityTimeout後に再試行
      }
    }
  }
}

pollMessages()
```

### FIFO Queue

```typescript
import { SendMessageCommand } from '@aws-sdk/client-sqs'

async function sendFifoMessage() {
  const command = new SendMessageCommand({
    QueueUrl: 'https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue.fifo',
    MessageBody: JSON.stringify({ order: 'data' }),
    MessageGroupId: 'order-123', // 順序グループ
    MessageDeduplicationId: `${Date.now()}-${Math.random()}` // 重複排除ID
  })

  await client.send(command)
}
```

### バッチ送信

```typescript
import { SendMessageBatchCommand } from '@aws-sdk/client-sqs'

async function sendBatch() {
  const command = new SendMessageBatchCommand({
    QueueUrl: queueUrl,
    Entries: [
      {
        Id: '1',
        MessageBody: JSON.stringify({ data: 1 })
      },
      {
        Id: '2',
        MessageBody: JSON.stringify({ data: 2 })
      },
      {
        Id: '3',
        MessageBody: JSON.stringify({ data: 3 })
      }
    ]
  })

  const response = await client.send(command)
  console.log('Successful:', response.Successful?.length)
  console.log('Failed:', response.Failed?.length)
}
```

### Dead Letter Queue

```bash
# DLQ作成
aws sqs create-queue --queue-name my-dlq

# メインキューにDLQ設定
aws sqs set-queue-attributes \
  --queue-url https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue \
  --attributes '{
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:ap-northeast-1:123456789012:my-dlq\",\"maxReceiveCount\":\"3\"}"
  }'
```

---

## 比較

| 機能 | RabbitMQ | AWS SQS |
|------|----------|---------|
| 運用 | セルフホスト | マネージド |
| プロトコル | AMQP, MQTT等 | HTTP/HTTPS |
| 順序保証 | ○ | FIFO Queueのみ |
| メッセージサイズ | カスタマイズ可 | 最大256KB |
| スループット | 高い | Standard: 無制限<br>FIFO: 3000/秒 |
| 永続化 | ○ | ○ |
| メッセージ保持 | カスタマイズ可 | 最大14日 |
| 料金 | インフラコスト | 従量課金 |
| Exchange | ○ | × |
| ルーティング | 高度 | シンプル |

### どちらを選ぶ？

**RabbitMQ**を選ぶ場合:
- 複雑なルーティングが必要
- 高度な機能が必要（Exchange, Priority等）
- オンプレミス環境
- 既存のAMQPシステムと統合

**AWS SQS**を選ぶ場合:
- AWSエコシステム使用
- 運用コスト削減
- スケーラビリティ重視
- シンプルなキュー

---

## パターン

### ワークキュー

```
Producer → Queue → Worker1
                 → Worker2
                 → Worker3
```

複数のワーカーで負荷分散。

### Pub/Sub

```
Publisher → Exchange → Queue1 → Consumer1
                    → Queue2 → Consumer2
                    → Queue3 → Consumer3
```

1つのメッセージを複数のサブスクライバーに配信。

### Request/Reply

```
Client → Request Queue → Server
      ← Reply Queue    ←
```

同期的なRPC風の通信。

---

## ベストプラクティス

### ✓ 推奨

```typescript
// メッセージに十分な情報を含める
{
  id: 'msg-123',
  type: 'send_email',
  timestamp: '2024-01-15T10:00:00Z',
  data: {
    userId: '123',
    email: 'user@example.com'
  },
  retryCount: 0
}

// 冪等性を保つ
async function processMessage(msg) {
  const processed = await checkIfProcessed(msg.id)
  if (processed) return

  await performAction(msg)
  await markAsProcessed(msg.id)
}

// タイムアウト設定
const timeout = setTimeout(() => {
  throw new Error('Processing timeout')
}, 30000)

await processMessage(msg)
clearTimeout(timeout)

// エラーハンドリング
try {
  await processMessage(msg)
  channel.ack(msg)
} catch (error) {
  if (isRetryable(error)) {
    channel.nack(msg, false, true) // 再キュー
  } else {
    channel.nack(msg, false, false) // DLQへ
  }
}
```

### ✗ 避けるべき

```typescript
// 大きすぎるメッセージ
{
  data: largeImageBuffer // ✗ S3等を使用

  imageUrl: 's3://bucket/key' // ○
}

// 再試行なし
channel.consume(queue, (msg) => {
  processMessage(msg)
  channel.ack(msg) // ✗ 失敗しても削除
})

// 無限ループ
channel.consume(queue, (msg) => {
  try {
    processMessage(msg)
    channel.ack(msg)
  } catch (error) {
    channel.nack(msg, false, true) // ✗ 無限再試行
  }
})
```

---

## モニタリング

### RabbitMQ

```bash
# 管理API
curl -u guest:guest http://localhost:15672/api/queues

# メトリクス
- Queue length
- Message rate
- Consumer count
- Memory usage
```

### AWS SQS

```bash
# CloudWatchメトリクス
- ApproximateNumberOfMessagesVisible
- ApproximateAgeOfOldestMessage
- NumberOfMessagesSent
- NumberOfMessagesReceived
```

---

## 参考リンク

- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/)
- [AMQP Protocol](https://www.amqp.org/)
