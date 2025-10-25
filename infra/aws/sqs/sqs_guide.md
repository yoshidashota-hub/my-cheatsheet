# Amazon SQS 完全ガイド

## 目次
1. [SQSとは](#sqsとは)
2. [基本概念](#基本概念)
3. [キューの種類](#キューの種類)
4. [セットアップ](#セットアップ)
5. [メッセージの送受信](#メッセージの送受信)
6. [Dead Letter Queue（DLQ）](#dead-letter-queuedlq)
7. [Lambda統合](#lambda統合)
8. [実装例](#実装例)
9. [ベストプラクティス](#ベストプラクティス)
10. [トラブルシューティング](#トラブルシューティング)

---

## SQSとは

Amazon Simple Queue Service (SQS)は、フルマネージドなメッセージキューイングサービスです。

### 主な機能

- **非同期処理**: アプリケーション間の疎結合化
- **スケーラビリティ**: 無制限のスループット
- **信頼性**: メッセージの永続化と冗長化
- **セキュリティ**: 暗号化とアクセス制御
- **コスト効率**: 使用量ベースの料金体系

### ユースケース

- バックグラウンドジョブの処理
- マイクロサービス間の通信
- イベント駆動アーキテクチャ
- リクエストのバッファリング
- 分散システムの疎結合化

---

## 基本概念

### SQSの仕組み

```
┌──────────┐          ┌──────────┐          ┌──────────┐
│ Producer │ ────────>│   SQS    │<──────── │ Consumer │
│          │  SendMsg │  Queue   │ RecvMsg  │          │
└──────────┘          └──────────┘          └──────────┘
                           │
                      ┌────┴────┐
                      │ Message │
                      │ Message │
                      │ Message │
                      └─────────┘
```

### 主要な用語

- **Message**: キューに送信されるデータ
- **Producer**: メッセージを送信する側
- **Consumer**: メッセージを受信・処理する側
- **Visibility Timeout**: メッセージが他のコンシューマーから見えなくなる時間
- **Retention Period**: メッセージの保持期間（最大14日間）
- **Receive Count**: メッセージが受信された回数

---

## キューの種類

### Standard Queue（標準キュー）

- **順序保証**: なし
- **重複配信**: 可能性あり
- **スループット**: 無制限
- **ユースケース**: 高スループットが必要な場合

### FIFO Queue（先入れ先出しキュー）

- **順序保証**: あり（メッセージグループ内）
- **重複配信**: なし（メッセージ重複排除）
- **スループット**: 最大3,000メッセージ/秒
- **ユースケース**: 順序が重要な場合

```
┌─────────────────────────────────────────────┐
│         Standard Queue                      │
├─────────────────────────────────────────────┤
│  Message 3  →  Consumer A                  │
│  Message 1  →  Consumer B                  │
│  Message 2  →  Consumer C                  │
│  (順序は保証されない)                        │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         FIFO Queue                          │
├─────────────────────────────────────────────┤
│  Message 1  →  Consumer A                  │
│  Message 2  →  Consumer B                  │
│  Message 3  →  Consumer C                  │
│  (順序が保証される)                          │
└─────────────────────────────────────────────┘
```

---

## セットアップ

### AWS CDKでのキュー作成

```typescript
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as cdk from 'aws-cdk-lib';

export class SqsStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Standard Queue
    const standardQueue = new sqs.Queue(this, 'StandardQueue', {
      queueName: 'my-standard-queue',
      visibilityTimeout: cdk.Duration.seconds(300), // 5分
      receiveMessageWaitTime: cdk.Duration.seconds(20), // Long Polling
      retentionPeriod: cdk.Duration.days(4), // 4日間保持
      encryption: sqs.QueueEncryption.KMS_MANAGED, // KMS暗号化
    });

    // FIFO Queue
    const fifoQueue = new sqs.Queue(this, 'FifoQueue', {
      queueName: 'my-fifo-queue.fifo', // .fifo サフィックス必須
      fifo: true,
      contentBasedDeduplication: true, // コンテンツベースの重複排除
      visibilityTimeout: cdk.Duration.seconds(300),
      receiveMessageWaitTime: cdk.Duration.seconds(20),
      deduplicationScope: sqs.DeduplicationScope.MESSAGE_GROUP,
      fifoThroughputLimit: sqs.FifoThroughputLimit.PER_MESSAGE_GROUP_ID,
    });

    // Dead Letter Queue（DLQ）
    const dlq = new sqs.Queue(this, 'DLQ', {
      queueName: 'my-queue-dlq',
      retentionPeriod: cdk.Duration.days(14), // 14日間保持
    });

    // メインキュー（DLQ付き）
    const mainQueue = new sqs.Queue(this, 'MainQueue', {
      queueName: 'my-main-queue',
      visibilityTimeout: cdk.Duration.seconds(300),
      deadLetterQueue: {
        queue: dlq,
        maxReceiveCount: 3, // 3回失敗したらDLQへ
      },
    });

    // 出力
    new cdk.CfnOutput(this, 'QueueUrl', {
      value: mainQueue.queueUrl,
    });

    new cdk.CfnOutput(this, 'QueueArn', {
      value: mainQueue.queueArn,
    });
  }
}
```

---

## メッセージの送受信

### メッセージの送信

```typescript
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

const client = new SQSClient({ region: 'us-east-1' });

// 標準キューへの送信
async function sendMessage(queueUrl: string, message: any) {
  try {
    const response = await client.send(
      new SendMessageCommand({
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify(message),
        MessageAttributes: {
          UserId: {
            DataType: 'String',
            StringValue: message.userId,
          },
          Priority: {
            DataType: 'Number',
            StringValue: message.priority.toString(),
          },
          Timestamp: {
            DataType: 'String',
            StringValue: new Date().toISOString(),
          },
        },
        DelaySeconds: 0, // 遅延配信（0-900秒）
      })
    );

    console.log('Message sent:', response.MessageId);
    return response.MessageId;
  } catch (error) {
    console.error('Failed to send message:', error);
    throw error;
  }
}

// FIFO キューへの送信
async function sendFifoMessage(queueUrl: string, message: any, groupId: string) {
  try {
    const response = await client.send(
      new SendMessageCommand({
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify(message),
        MessageGroupId: groupId, // FIFO必須
        MessageDeduplicationId: `${Date.now()}-${Math.random()}`, // 重複排除ID
        // または contentBasedDeduplication: true の場合は不要
      })
    );

    console.log('FIFO message sent:', response.MessageId);
    return response.MessageId;
  } catch (error) {
    console.error('Failed to send FIFO message:', error);
    throw error;
  }
}

// バッチ送信（最大10件）
import { SendMessageBatchCommand } from '@aws-sdk/client-sqs';

async function sendMessageBatch(queueUrl: string, messages: any[]) {
  try {
    const response = await client.send(
      new SendMessageBatchCommand({
        QueueUrl: queueUrl,
        Entries: messages.map((message, index) => ({
          Id: `msg-${index}`,
          MessageBody: JSON.stringify(message),
          MessageAttributes: {
            Type: {
              DataType: 'String',
              StringValue: message.type,
            },
          },
        })),
      })
    );

    console.log('Batch sent successfully:', response.Successful?.length);
    if (response.Failed && response.Failed.length > 0) {
      console.error('Some messages failed:', response.Failed);
    }

    return response;
  } catch (error) {
    console.error('Failed to send batch:', error);
    throw error;
  }
}
```

### メッセージの受信

```typescript
import {
  ReceiveMessageCommand,
  DeleteMessageCommand,
  ChangeMessageVisibilityCommand,
} from '@aws-sdk/client-sqs';

// メッセージの受信
async function receiveMessages(queueUrl: string, maxMessages: number = 1) {
  try {
    const response = await client.send(
      new ReceiveMessageCommand({
        QueueUrl: queueUrl,
        MaxNumberOfMessages: maxMessages, // 1-10
        WaitTimeSeconds: 20, // Long Polling（1-20秒）
        MessageAttributeNames: ['All'],
        AttributeNames: ['All'],
        VisibilityTimeout: 300, // 5分
      })
    );

    if (!response.Messages || response.Messages.length === 0) {
      console.log('No messages available');
      return [];
    }

    console.log(`Received ${response.Messages.length} messages`);
    return response.Messages;
  } catch (error) {
    console.error('Failed to receive messages:', error);
    throw error;
  }
}

// メッセージの処理と削除
async function processMessage(queueUrl: string) {
  const messages = await receiveMessages(queueUrl, 1);

  for (const message of messages) {
    try {
      const body = JSON.parse(message.Body || '{}');
      console.log('Processing message:', body);

      // メッセージ処理
      await handleMessage(body);

      // 処理成功 → メッセージを削除
      await client.send(
        new DeleteMessageCommand({
          QueueUrl: queueUrl,
          ReceiptHandle: message.ReceiptHandle!,
        })
      );

      console.log('Message deleted successfully');
    } catch (error) {
      console.error('Failed to process message:', error);

      // 処理失敗 → Visibility Timeoutを変更（即座に再試行）
      await client.send(
        new ChangeMessageVisibilityCommand({
          QueueUrl: queueUrl,
          ReceiptHandle: message.ReceiptHandle!,
          VisibilityTimeout: 0,
        })
      );
    }
  }
}

async function handleMessage(message: any) {
  // ビジネスロジック
  console.log('Handling message:', message);
}

// ポーリングループ
async function pollQueue(queueUrl: string) {
  console.log('Starting queue polling...');

  while (true) {
    try {
      await processMessage(queueUrl);
    } catch (error) {
      console.error('Polling error:', error);
      await new Promise((resolve) => setTimeout(resolve, 5000)); // 5秒待機
    }
  }
}
```

---

## Dead Letter Queue（DLQ）

### DLQの設定

```typescript
// DLQの作成
const dlq = new sqs.Queue(this, 'DLQ', {
  queueName: 'my-dlq',
  retentionPeriod: cdk.Duration.days(14),
});

// メインキューにDLQを設定
const mainQueue = new sqs.Queue(this, 'MainQueue', {
  queueName: 'my-queue',
  deadLetterQueue: {
    queue: dlq,
    maxReceiveCount: 3, // 3回受信後にDLQへ移動
  },
});

// DLQモニタリング用アラーム
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as actions from 'aws-cdk-lib/aws-cloudwatch-actions';
import * as sns from 'aws-cdk-lib/aws-sns';

const topic = new sns.Topic(this, 'AlarmTopic');

new cloudwatch.Alarm(this, 'DLQAlarm', {
  metric: dlq.metricApproximateNumberOfMessagesVisible(),
  threshold: 1,
  evaluationPeriods: 1,
  alarmDescription: 'Alert when messages appear in DLQ',
}).addAlarmAction(new actions.SnsAction(topic));
```

### DLQからのメッセージ再処理

```typescript
async function redriveMessagesFromDLQ(dlqUrl: string, targetQueueUrl: string) {
  while (true) {
    const messages = await receiveMessages(dlqUrl, 10);

    if (messages.length === 0) {
      console.log('No more messages in DLQ');
      break;
    }

    for (const message of messages) {
      try {
        // メッセージをターゲットキューに送信
        await client.send(
          new SendMessageCommand({
            QueueUrl: targetQueueUrl,
            MessageBody: message.Body!,
            MessageAttributes: message.MessageAttributes,
          })
        );

        // DLQから削除
        await client.send(
          new DeleteMessageCommand({
            QueueUrl: dlqUrl,
            ReceiptHandle: message.ReceiptHandle!,
          })
        );

        console.log('Message moved from DLQ to main queue');
      } catch (error) {
        console.error('Failed to move message:', error);
      }
    }
  }
}
```

---

## Lambda統合

### SQSトリガーLambda

```typescript
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { SqsEventSource } from 'aws-cdk-lib/aws-lambda-event-sources';

// Lambda関数
const processor = new lambda.Function(this, 'QueueProcessor', {
  runtime: lambda.Runtime.NODEJS_18_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset('lambda/queue-processor'),
  timeout: cdk.Duration.minutes(5),
  reservedConcurrentExecutions: 10, // 同時実行数制限
});

// SQSイベントソース
processor.addEventSource(
  new SqsEventSource(mainQueue, {
    batchSize: 10, // 1-10
    maxBatchingWindow: cdk.Duration.seconds(10), // バッチウィンドウ
    reportBatchItemFailures: true, // 部分的失敗レポート
  })
);

// キューへのアクセス権限は自動的に付与される
```

### Lambda関数実装

```typescript
import { SQSEvent, SQSRecord, SQSBatchResponse } from 'aws-lambda';

export const handler = async (event: SQSEvent): Promise<SQSBatchResponse> => {
  console.log(`Processing ${event.Records.length} messages`);

  const batchItemFailures: SQSBatchResponse['batchItemFailures'] = [];

  for (const record of event.Records) {
    try {
      await processRecord(record);
      console.log('Message processed successfully:', record.messageId);
    } catch (error: any) {
      console.error('Failed to process message:', error);
      // 失敗したメッセージをレポート
      batchItemFailures.push({
        itemIdentifier: record.messageId,
      });
    }
  }

  return { batchItemFailures };
};

async function processRecord(record: SQSRecord) {
  const body = JSON.parse(record.body);
  console.log('Processing:', body);

  // メッセージ属性の取得
  const userId = record.messageAttributes?.UserId?.stringValue;
  const priority = record.messageAttributes?.Priority?.stringValue;

  console.log('User:', userId, 'Priority:', priority);

  // ビジネスロジック
  if (body.type === 'order') {
    await processOrder(body);
  } else if (body.type === 'notification') {
    await sendNotification(body);
  }
}

async function processOrder(order: any) {
  // 注文処理
  console.log('Processing order:', order);
}

async function sendNotification(notification: any) {
  // 通知送信
  console.log('Sending notification:', notification);
}
```

---

## 実装例

### ワーカーパターン

```typescript
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';

class SQSWorker {
  private client: SQSClient;
  private queueUrl: string;
  private isRunning: boolean = false;

  constructor(queueUrl: string, region: string = 'us-east-1') {
    this.client = new SQSClient({ region });
    this.queueUrl = queueUrl;
  }

  async start() {
    this.isRunning = true;
    console.log('Worker started');

    while (this.isRunning) {
      try {
        await this.poll();
      } catch (error) {
        console.error('Polling error:', error);
        await this.sleep(5000);
      }
    }
  }

  async stop() {
    this.isRunning = false;
    console.log('Worker stopped');
  }

  private async poll() {
    const response = await this.client.send(
      new ReceiveMessageCommand({
        QueueUrl: this.queueUrl,
        MaxNumberOfMessages: 10,
        WaitTimeSeconds: 20,
        MessageAttributeNames: ['All'],
      })
    );

    if (!response.Messages || response.Messages.length === 0) {
      return;
    }

    console.log(`Received ${response.Messages.length} messages`);

    await Promise.all(
      response.Messages.map((message) => this.processMessage(message))
    );
  }

  private async processMessage(message: any) {
    try {
      const body = JSON.parse(message.Body);
      console.log('Processing message:', body);

      // メッセージ処理
      await this.handleMessage(body);

      // 削除
      await this.client.send(
        new DeleteMessageCommand({
          QueueUrl: this.queueUrl,
          ReceiptHandle: message.ReceiptHandle,
        })
      );

      console.log('Message processed successfully');
    } catch (error) {
      console.error('Failed to process message:', error);
      // エラー時はメッセージを残す（再試行される）
    }
  }

  private async handleMessage(message: any) {
    // ビジネスロジック
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

// 使用例
const worker = new SQSWorker('https://sqs.us-east-1.amazonaws.com/123456789012/my-queue');
worker.start();

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Received SIGTERM, stopping worker...');
  await worker.stop();
  process.exit(0);
});
```

### Express.js + SQS

```typescript
import express from 'express';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

const app = express();
const sqs = new SQSClient({ region: 'us-east-1' });
const queueUrl = process.env.QUEUE_URL!;

app.use(express.json());

// 非同期ジョブの投入
app.post('/api/jobs', async (req, res) => {
  try {
    const job = req.body;

    // バリデーション
    if (!job.type || !job.data) {
      return res.status(400).json({ error: 'Invalid job format' });
    }

    // SQSに送信
    const response = await sqs.send(
      new SendMessageCommand({
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify(job),
        MessageAttributes: {
          JobType: {
            DataType: 'String',
            StringValue: job.type,
          },
          Priority: {
            DataType: 'Number',
            StringValue: (job.priority || 0).toString(),
          },
        },
      })
    );

    res.json({
      message: 'Job queued successfully',
      jobId: response.MessageId,
    });
  } catch (error) {
    console.error('Failed to queue job:', error);
    res.status(500).json({ error: 'Failed to queue job' });
  }
});

app.listen(3000, () => {
  console.log('Server started on port 3000');
});
```

---

## ベストプラクティス

### 1. Visibility Timeoutの適切な設定

```typescript
// 処理時間に応じて設定
const queue = new sqs.Queue(this, 'Queue', {
  // 処理に最大5分かかる場合
  visibilityTimeout: cdk.Duration.seconds(300),
});

// 処理中にタイムアウトを延長
import { ChangeMessageVisibilityCommand } from '@aws-sdk/client-sqs';

async function extendVisibilityTimeout(queueUrl: string, receiptHandle: string) {
  await client.send(
    new ChangeMessageVisibilityCommand({
      QueueUrl: queueUrl,
      ReceiptHandle: receiptHandle,
      VisibilityTimeout: 600, // さらに10分延長
    })
  );
}
```

### 2. Long Pollingの使用

```typescript
// キュー作成時に設定
const queue = new sqs.Queue(this, 'Queue', {
  receiveMessageWaitTime: cdk.Duration.seconds(20), // Long Polling
});

// または受信時に指定
const response = await client.send(
  new ReceiveMessageCommand({
    QueueUrl: queueUrl,
    WaitTimeSeconds: 20, // Long Polling
  })
);
```

### 3. バッチ処理の活用

```typescript
// バッチ送信でコスト削減
const messages = [/* ... */];
const batches = chunk(messages, 10); // 10件ずつに分割

for (const batch of batches) {
  await sendMessageBatch(queueUrl, batch);
}

function chunk<T>(array: T[], size: number): T[][] {
  return Array.from({ length: Math.ceil(array.length / size) }, (_, i) =>
    array.slice(i * size, i * size + size)
  );
}
```

### 4. メッセージの冪等性確保

```typescript
// メッセージ処理を冪等にする
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';

const dynamodb = new DynamoDBClient({ region: 'us-east-1' });

async function processMessageIdempotent(messageId: string, message: any) {
  // 処理済みチェック
  const isProcessed = await checkProcessed(messageId);
  if (isProcessed) {
    console.log('Message already processed, skipping');
    return;
  }

  // メッセージ処理
  await handleMessage(message);

  // 処理済みマーク
  await markAsProcessed(messageId);
}

async function checkProcessed(messageId: string): Promise<boolean> {
  // DynamoDBで確認
  try {
    await dynamodb.send(
      new PutItemCommand({
        TableName: 'ProcessedMessages',
        Item: {
          MessageId: { S: messageId },
          ProcessedAt: { S: new Date().toISOString() },
        },
        ConditionExpression: 'attribute_not_exists(MessageId)',
      })
    );
    return false; // 未処理
  } catch (error: any) {
    if (error.name === 'ConditionalCheckFailedException') {
      return true; // 処理済み
    }
    throw error;
  }
}

async function markAsProcessed(messageId: string) {
  // すでにcheckProcessedで記録済み
}
```

---

## トラブルシューティング

### よくある問題

#### 1. メッセージが重複して処理される

```typescript
// 原因: Visibility Timeoutが短すぎる
// 解決: Visibility Timeoutを延長

const queue = new sqs.Queue(this, 'Queue', {
  visibilityTimeout: cdk.Duration.seconds(600), // 10分
});
```

#### 2. メッセージがDLQに送られる

```typescript
// 原因: maxReceiveCountが低すぎる、または処理が失敗している
// 解決: maxReceiveCountを増やす、エラーハンドリングを改善

const queue = new sqs.Queue(this, 'Queue', {
  deadLetterQueue: {
    queue: dlq,
    maxReceiveCount: 5, // 5回まで再試行
  },
});

// エラーハンドリングを改善
try {
  await processMessage(message);
} catch (error) {
  console.error('Error details:', error);
  // リトライ可能なエラーか判定
  if (isRetryableError(error)) {
    // 再試行のため削除しない
    throw error;
  } else {
    // 再試行不可能なエラーは削除
    await deleteMessage(queueUrl, receiptHandle);
  }
}
```

#### 3. キューに大量のメッセージが溜まる

```typescript
// 原因: Consumer の処理能力不足
// 解決: Consumer をスケールアウト

// Lambdaの同時実行数を増やす
const processor = new lambda.Function(this, 'Processor', {
  reservedConcurrentExecutions: 100, // 100まで同時実行
});

// EC2/ECS ワーカーをスケールアウト
import * as autoscaling from 'aws-cdk-lib/aws-autoscaling';

const asg = new autoscaling.AutoScalingGroup(this, 'ASG', {
  // ...
});

// キューの深さに応じてスケーリング
asg.scaleOnMetric('ScaleOnQueue', {
  metric: queue.metricApproximateNumberOfMessagesVisible(),
  scalingSteps: [
    { upper: 0, change: -1 },
    { lower: 100, change: +1 },
    { lower: 500, change: +2 },
  ],
});
```

---

## 参考リンク

- [Amazon SQS 公式ドキュメント](https://docs.aws.amazon.com/sqs/)
- [SQS Developer Guide](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/)
- [SQS Pricing](https://aws.amazon.com/sqs/pricing/)
- [SQS Best Practices](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-best-practices.html)
