# Amazon SNS 完全ガイド

## 目次
1. [SNSとは](#snsとは)
2. [基本概念](#基本概念)
3. [セットアップ](#セットアップ)
4. [メッセージの配信](#メッセージの配信)
5. [サブスクリプション](#サブスクリプション)
6. [メッセージフィルタリング](#メッセージフィルタリング)
7. [SNS + SQS統合](#sns--sqs統合)
8. [実装例](#実装例)
9. [ベストプラクティス](#ベストプラクティス)
10. [トラブルシューティング](#トラブルシューティング)

---

## SNSとは

Amazon Simple Notification Service (SNS)は、Pub/Sub型のメッセージング・通知サービスです。

### 主な機能

- **Pub/Sub メッセージング**: 1対多の配信
- **マルチプロトコル**: SMS、Email、HTTP/S、Lambda、SQSなど
- **メッセージフィルタリング**: サブスクリプションごとのフィルター
- **メッセージの永続化**: 失敗時の自動リトライ
- **セキュリティ**: 暗号化とアクセス制御

### ユースケース

- アプリケーション間の疎結合化
- ファンアウトパターン（1つのイベントを複数のサブスクライバーへ）
- システム通知・アラート
- モバイルプッシュ通知
- SMS/Email通知

---

## 基本概念

### SNSの仕組み

```
                    ┌──────────────┐
                    │  Publisher   │
                    └──────┬───────┘
                           │ Publish
                           ▼
                    ┌──────────────┐
                    │  SNS Topic   │
                    └──────┬───────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │  Lambda  │    │   SQS    │    │  Email   │
    └──────────┘    └──────────┘    └──────────┘
    Subscriber 1    Subscriber 2    Subscriber 3
```

### 主要な用語

- **Topic**: メッセージの配信先
- **Publisher**: メッセージを送信する側
- **Subscriber**: メッセージを受信する側
- **Subscription**: TopicとSubscriberの紐付け
- **Message Attributes**: メッセージのメタデータ
- **Filter Policy**: サブスクリプションごとのフィルター

---

## セットアップ

### AWS CDKでのトピック作成

```typescript
import * as sns from 'aws-cdk-lib/aws-sns';
import * as subscriptions from 'aws-cdk-lib/aws-sns-subscriptions';
import * as cdk from 'aws-cdk-lib';

export class SnsStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 標準トピック
    const topic = new sns.Topic(this, 'Topic', {
      topicName: 'my-topic',
      displayName: 'My Topic',
      fifo: false,
    });

    // FIFOトピック
    const fifoTopic = new sns.Topic(this, 'FifoTopic', {
      topicName: 'my-topic.fifo', // .fifo サフィックス必須
      displayName: 'My FIFO Topic',
      fifo: true,
      contentBasedDeduplication: true,
    });

    // サブスクリプションの追加

    // Email
    topic.addSubscription(
      new subscriptions.EmailSubscription('user@example.com')
    );

    // SMS
    topic.addSubscription(
      new subscriptions.SmsSubscription('+1234567890')
    );

    // Lambda
    const lambdaFunction = new lambda.Function(this, 'Handler', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
    });
    topic.addSubscription(
      new subscriptions.LambdaSubscription(lambdaFunction)
    );

    // SQS
    const queue = new sqs.Queue(this, 'Queue');
    topic.addSubscription(
      new subscriptions.SqsSubscription(queue)
    );

    // HTTP/S Endpoint
    topic.addSubscription(
      new subscriptions.UrlSubscription('https://example.com/webhook')
    );

    // 出力
    new cdk.CfnOutput(this, 'TopicArn', {
      value: topic.topicArn,
    });
  }
}
```

---

## メッセージの配信

### メッセージの送信

```typescript
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

const client = new SNSClient({ region: 'us-east-1' });

// 基本的なメッセージ送信
async function publishMessage(topicArn: string, message: any) {
  try {
    const response = await client.send(
      new PublishCommand({
        TopicArn: topicArn,
        Message: JSON.stringify(message),
        Subject: 'New Notification',
        MessageAttributes: {
          Type: {
            DataType: 'String',
            StringValue: message.type,
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
      })
    );

    console.log('Message published:', response.MessageId);
    return response.MessageId;
  } catch (error) {
    console.error('Failed to publish message:', error);
    throw error;
  }
}

// プロトコル別メッセージ（Message Structure）
async function publishProtocolSpecificMessage(topicArn: string) {
  try {
    const response = await client.send(
      new PublishCommand({
        TopicArn: topicArn,
        MessageStructure: 'json',
        Message: JSON.stringify({
          default: 'Default message for all protocols',
          email: 'Email version of the message',
          sms: 'SMS version',
          sqs: JSON.stringify({
            orderId: '12345',
            status: 'completed',
          }),
          lambda: JSON.stringify({
            eventType: 'ORDER_COMPLETED',
            data: {
              orderId: '12345',
            },
          }),
        }),
      })
    );

    console.log('Protocol-specific message published');
    return response.MessageId;
  } catch (error) {
    console.error('Failed to publish:', error);
    throw error;
  }
}

// FIFOトピックへの送信
async function publishFifoMessage(
  topicArn: string,
  message: any,
  messageGroupId: string
) {
  try {
    const response = await client.send(
      new PublishCommand({
        TopicArn: topicArn,
        Message: JSON.stringify(message),
        MessageGroupId: messageGroupId, // FIFO必須
        MessageDeduplicationId: `${Date.now()}-${Math.random()}`, // 重複排除ID
      })
    );

    console.log('FIFO message published');
    return response.MessageId;
  } catch (error) {
    console.error('Failed to publish FIFO message:', error);
    throw error;
  }
}

// 電話番号への直接送信（SMS）
async function sendSMS(phoneNumber: string, message: string) {
  try {
    const response = await client.send(
      new PublishCommand({
        PhoneNumber: phoneNumber, // +1234567890
        Message: message,
        MessageAttributes: {
          'AWS.SNS.SMS.SenderID': {
            DataType: 'String',
            StringValue: 'MyApp',
          },
          'AWS.SNS.SMS.SMSType': {
            DataType: 'String',
            StringValue: 'Transactional', // または Promotional
          },
        },
      })
    );

    console.log('SMS sent:', response.MessageId);
    return response.MessageId;
  } catch (error) {
    console.error('Failed to send SMS:', error);
    throw error;
  }
}
```

---

## サブスクリプション

### プログラムでのサブスクリプション作成

```typescript
import { SNSClient, SubscribeCommand, ConfirmSubscriptionCommand } from '@aws-sdk/client-sns';

// サブスクリプションの作成
async function subscribe(topicArn: string, protocol: string, endpoint: string) {
  try {
    const response = await client.send(
      new SubscribeCommand({
        TopicArn: topicArn,
        Protocol: protocol, // email, sms, lambda, sqs, http, https
        Endpoint: endpoint, // user@example.com, +1234567890, arn:...
        ReturnSubscriptionArn: true,
      })
    );

    console.log('Subscription created:', response.SubscriptionArn);
    return response.SubscriptionArn;
  } catch (error) {
    console.error('Failed to subscribe:', error);
    throw error;
  }
}

// サブスクリプションの確認（Email, HTTP/S）
async function confirmSubscription(topicArn: string, token: string) {
  try {
    const response = await client.send(
      new ConfirmSubscriptionCommand({
        TopicArn: topicArn,
        Token: token, // 確認メール/HTTPリクエストに含まれるトークン
      })
    );

    console.log('Subscription confirmed:', response.SubscriptionArn);
    return response.SubscriptionArn;
  } catch (error) {
    console.error('Failed to confirm subscription:', error);
    throw error;
  }
}

// サブスクリプションの削除
import { UnsubscribeCommand } from '@aws-sdk/client-sns';

async function unsubscribe(subscriptionArn: string) {
  try {
    await client.send(
      new UnsubscribeCommand({
        SubscriptionArn: subscriptionArn,
      })
    );

    console.log('Unsubscribed successfully');
  } catch (error) {
    console.error('Failed to unsubscribe:', error);
    throw error;
  }
}
```

---

## メッセージフィルタリング

### フィルターポリシー

```typescript
import * as sns from 'aws-cdk-lib/aws-sns';
import * as subscriptions from 'aws-cdk-lib/aws-sns-subscriptions';

// フィルターポリシー付きサブスクリプション
const queue1 = new sqs.Queue(this, 'OrderQueue');
topic.addSubscription(
  new subscriptions.SqsSubscription(queue1, {
    filterPolicy: {
      eventType: sns.SubscriptionFilter.stringFilter({
        allowlist: ['ORDER_PLACED', 'ORDER_COMPLETED'],
      }),
      priority: sns.SubscriptionFilter.numericFilter({
        greaterThan: 5,
      }),
    },
  })
);

const queue2 = new sqs.Queue(this, 'NotificationQueue');
topic.addSubscription(
  new subscriptions.SqsSubscription(queue2, {
    filterPolicy: {
      eventType: sns.SubscriptionFilter.stringFilter({
        allowlist: ['USER_REGISTERED', 'USER_UPDATED'],
      }),
      region: sns.SubscriptionFilter.stringFilter({
        allowlist: ['us-east-1', 'us-west-2'],
      }),
    },
  })
);

// 複雑なフィルター
topic.addSubscription(
  new subscriptions.SqsSubscription(queue, {
    filterPolicyWithMessageBody: {
      // Message Bodyベースのフィルタリング（JSON）
      price: sns.FilterOrPolicy.filter(
        sns.SubscriptionFilter.numericFilter({
          between: { start: 100, stop: 1000 },
        })
      ),
      category: sns.FilterOrPolicy.filter(
        sns.SubscriptionFilter.stringFilter({
          allowlist: ['electronics', 'books'],
        })
      ),
    },
  })
);
```

### フィルターポリシーの例

```json
{
  "eventType": ["ORDER_PLACED", "ORDER_COMPLETED"],
  "priority": [{"numeric": [">", 5]}],
  "region": ["us-east-1", "us-west-2"],
  "store": [{"exists": true}]
}
```

```json
{
  "price": [{"numeric": [">=", 100, "<=", 1000]}],
  "category": ["electronics", "books"],
  "inStock": [true]
}
```

---

## SNS + SQS統合

### ファンアウトパターン

```typescript
import * as sns from 'aws-cdk-lib/aws-sns';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as subscriptions from 'aws-cdk-lib/aws-sns-subscriptions';

// SNSトピック
const topic = new sns.Topic(this, 'OrderTopic', {
  topicName: 'order-events',
});

// 複数のSQSキュー
const inventoryQueue = new sqs.Queue(this, 'InventoryQueue', {
  queueName: 'inventory-queue',
});

const shippingQueue = new sqs.Queue(this, 'ShippingQueue', {
  queueName: 'shipping-queue',
});

const analyticsQueue = new sqs.Queue(this, 'AnalyticsQueue', {
  queueName: 'analytics-queue',
});

// サブスクリプション
topic.addSubscription(new subscriptions.SqsSubscription(inventoryQueue));
topic.addSubscription(new subscriptions.SqsSubscription(shippingQueue));
topic.addSubscription(new subscriptions.SqsSubscription(analyticsQueue));

// SQSキューポリシーは自動的に設定される
```

### DLQ（Dead Letter Queue）の設定

```typescript
// DLQの作成
const dlq = new sqs.Queue(this, 'DLQ', {
  queueName: 'sns-dlq',
});

// サブスクリプションにDLQを設定
topic.addSubscription(
  new subscriptions.SqsSubscription(queue, {
    deadLetterQueue: dlq,
  })
);

// SNSレベルのDLQ設定
import * as iam from 'aws-cdk-lib/aws-iam';

const snsDlq = new sqs.Queue(this, 'SnsDLQ');

// Lambda サブスクリプションのDLQ
topic.addSubscription(
  new subscriptions.LambdaSubscription(lambdaFunction, {
    deadLetterQueue: snsDlq,
  })
);
```

---

## 実装例

### イベント駆動アーキテクチャ

```typescript
// イベント発行
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

class EventPublisher {
  private sns: SNSClient;
  private topicArn: string;

  constructor(topicArn: string, region: string = 'us-east-1') {
    this.sns = new SNSClient({ region });
    this.topicArn = topicArn;
  }

  async publishOrderPlaced(order: any) {
    await this.publish({
      eventType: 'ORDER_PLACED',
      data: order,
    });
  }

  async publishOrderCompleted(orderId: string) {
    await this.publish({
      eventType: 'ORDER_COMPLETED',
      data: { orderId },
    });
  }

  async publishUserRegistered(user: any) {
    await this.publish({
      eventType: 'USER_REGISTERED',
      data: user,
    });
  }

  private async publish(event: any) {
    try {
      const response = await this.sns.send(
        new PublishCommand({
          TopicArn: this.topicArn,
          Message: JSON.stringify(event.data),
          MessageAttributes: {
            eventType: {
              DataType: 'String',
              StringValue: event.eventType,
            },
            timestamp: {
              DataType: 'String',
              StringValue: new Date().toISOString(),
            },
          },
        })
      );

      console.log(`Event published: ${event.eventType}`, response.MessageId);
    } catch (error) {
      console.error('Failed to publish event:', error);
      throw error;
    }
  }
}

// 使用例
const publisher = new EventPublisher(process.env.TOPIC_ARN!);

await publisher.publishOrderPlaced({
  orderId: '12345',
  userId: 'user-123',
  items: [{ productId: 'prod-1', quantity: 2 }],
  total: 99.99,
});
```

### Lambda + SNS イベントハンドラー

```typescript
import { SNSEvent, SNSEventRecord } from 'aws-lambda';

export const handler = async (event: SNSEvent) => {
  console.log(`Processing ${event.Records.length} SNS messages`);

  for (const record of event.Records) {
    await processRecord(record);
  }
};

async function processRecord(record: SNSEventRecord) {
  const message = JSON.parse(record.Sns.Message);
  const eventType = record.Sns.MessageAttributes?.eventType?.Value;

  console.log('Event type:', eventType);
  console.log('Message:', message);

  switch (eventType) {
    case 'ORDER_PLACED':
      await handleOrderPlaced(message);
      break;
    case 'ORDER_COMPLETED':
      await handleOrderCompleted(message);
      break;
    case 'USER_REGISTERED':
      await handleUserRegistered(message);
      break;
    default:
      console.log('Unknown event type:', eventType);
  }
}

async function handleOrderPlaced(order: any) {
  console.log('Processing order:', order.orderId);
  // 在庫確認・予約処理
}

async function handleOrderCompleted(data: any) {
  console.log('Order completed:', data.orderId);
  // 配送手配
}

async function handleUserRegistered(user: any) {
  console.log('User registered:', user.userId);
  // ウェルカムメール送信
}
```

### Express.js + SNS 通知

```typescript
import express from 'express';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

const app = express();
const sns = new SNSClient({ region: 'us-east-1' });

app.use(express.json());

// アラート送信エンドポイント
app.post('/api/alerts', async (req, res) => {
  try {
    const { level, message, details } = req.body;

    const topicArn = getTopicArnByLevel(level);

    await sns.send(
      new PublishCommand({
        TopicArn: topicArn,
        Subject: `Alert: ${level.toUpperCase()}`,
        Message: JSON.stringify({ message, details }),
        MessageAttributes: {
          level: {
            DataType: 'String',
            StringValue: level,
          },
          source: {
            DataType: 'String',
            StringValue: 'api-server',
          },
        },
      })
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Failed to send alert:', error);
    res.status(500).json({ error: 'Failed to send alert' });
  }
});

function getTopicArnByLevel(level: string): string {
  const topics = {
    critical: process.env.CRITICAL_TOPIC_ARN!,
    warning: process.env.WARNING_TOPIC_ARN!,
    info: process.env.INFO_TOPIC_ARN!,
  };

  return topics[level as keyof typeof topics] || topics.info;
}

app.listen(3000);
```

---

## ベストプラクティス

### 1. メッセージ属性の活用

```typescript
// 良い例: メッセージ属性でフィルタリング
await sns.send(
  new PublishCommand({
    TopicArn: topicArn,
    Message: JSON.stringify(order),
    MessageAttributes: {
      eventType: {
        DataType: 'String',
        StringValue: 'ORDER_PLACED',
      },
      priority: {
        DataType: 'Number',
        StringValue: '10',
      },
      region: {
        DataType: 'String',
        StringValue: 'us-east-1',
      },
    },
  })
);
```

### 2. 冪等性の確保

```typescript
// メッセージ処理を冪等にする
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';

const dynamodb = new DynamoDBClient({ region: 'us-east-1' });

async function processMessageIdempotent(messageId: string, message: any) {
  try {
    // 処理済みチェック
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

    // メッセージ処理
    await handleMessage(message);
  } catch (error: any) {
    if (error.name === 'ConditionalCheckFailedException') {
      console.log('Message already processed');
      return;
    }
    throw error;
  }
}
```

### 3. エラーハンドリング

```typescript
// Lambda関数でのエラーハンドリング
export const handler = async (event: SNSEvent) => {
  const errors: Error[] = [];

  for (const record of event.Records) {
    try {
      await processRecord(record);
    } catch (error) {
      console.error('Failed to process record:', error);
      errors.push(error as Error);
    }
  }

  // 一部失敗でも続行（DLQへは自動的に送られる）
  if (errors.length > 0) {
    console.error(`${errors.length} records failed to process`);
  }

  // 全て失敗した場合のみエラーをthrow
  if (errors.length === event.Records.length) {
    throw new Error('All records failed to process');
  }
};
```

### 4. モニタリング

```typescript
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as actions from 'aws-cdk-lib/aws-cloudwatch-actions';

// SNSメトリクスのアラーム
const failedDeliveryAlarm = new cloudwatch.Alarm(this, 'FailedDeliveryAlarm', {
  metric: topic.metricNumberOfNotificationsFailed({
    statistic: 'Sum',
    period: cdk.Duration.minutes(5),
  }),
  threshold: 10,
  evaluationPeriods: 2,
  alarmDescription: 'Alert when SNS delivery failures exceed threshold',
});

failedDeliveryAlarm.addAlarmAction(
  new actions.SnsAction(alertTopic)
);

// サブスクリプションフィルターのマッチ率
const filterMatchMetric = new cloudwatch.Metric({
  namespace: 'AWS/SNS',
  metricName: 'NumberOfMessagesPublished',
  dimensionsMap: {
    TopicName: topic.topicName,
  },
  statistic: 'Sum',
});
```

---

## トラブルシューティング

### よくある問題

#### 1. メッセージが届かない

```typescript
// 原因: サブスクリプションが確認されていない
// 解決: Email/HTTPサブスクリプションを確認

// 確認ステータスの確認
import { ListSubscriptionsByTopicCommand } from '@aws-sdk/client-sns';

const response = await sns.send(
  new ListSubscriptionsByTopicCommand({
    TopicArn: topicArn,
  })
);

response.Subscriptions?.forEach((sub) => {
  console.log(
    `${sub.Protocol}: ${sub.Endpoint} - ${sub.SubscriptionArn}`
  );
  // SubscriptionArn が "PendingConfirmation" の場合は未確認
});
```

#### 2. フィルターポリシーが機能しない

```typescript
// 原因: メッセージ属性が設定されていない
// 解決: MessageAttributesを設定

// 悪い例
await sns.send(
  new PublishCommand({
    TopicArn: topicArn,
    Message: JSON.stringify({ eventType: 'ORDER_PLACED' }),
    // MessageAttributesなし
  })
);

// 良い例
await sns.send(
  new PublishCommand({
    TopicArn: topicArn,
    Message: JSON.stringify({ orderId: '123' }),
    MessageAttributes: {
      eventType: {
        DataType: 'String',
        StringValue: 'ORDER_PLACED', // フィルター対象
      },
    },
  })
);
```

#### 3. Lambda関数が呼び出されない

```typescript
// 原因: 権限不足
// 解決: Lambda実行権限の確認

// CDKで自動的に設定されるが、手動の場合:
import { CfnPermission } from 'aws-cdk-lib/aws-lambda';

new CfnPermission(this, 'SnsInvokePermission', {
  action: 'lambda:InvokeFunction',
  functionName: lambdaFunction.functionName,
  principal: 'sns.amazonaws.com',
  sourceArn: topic.topicArn,
});
```

---

## 参考リンク

- [Amazon SNS 公式ドキュメント](https://docs.aws.amazon.com/sns/)
- [SNS Developer Guide](https://docs.aws.amazon.com/sns/latest/dg/)
- [SNS Message Filtering](https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering.html)
- [SNS Pricing](https://aws.amazon.com/sns/pricing/)
