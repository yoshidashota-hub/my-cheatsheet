# Amazon CloudWatch 完全ガイド

## 目次
1. [CloudWatchとは](#cloudwatchとは)
2. [基本概念](#基本概念)
3. [CloudWatch Logs](#cloudwatch-logs)
4. [CloudWatch Metrics](#cloudwatch-metrics)
5. [CloudWatch Alarms](#cloudwatch-alarms)
6. [CloudWatch Dashboards](#cloudwatch-dashboards)
7. [CloudWatch Insights](#cloudwatch-insights)
8. [CloudWatch Events / EventBridge](#cloudwatch-events--eventbridge)
9. [実装例](#実装例)
10. [ベストプラクティス](#ベストプラクティス)

---

## CloudWatchとは

Amazon CloudWatchは、AWSリソースとアプリケーションのモニタリングサービスです。

### 主な機能

- **Logs**: ログの収集・保存・分析
- **Metrics**: メトリクスの収集・可視化
- **Alarms**: メトリクスベースのアラート
- **Dashboards**: カスタムダッシュボード
- **Insights**: ログ分析・クエリ
- **Events**: イベント駆動の自動化

### ユースケース

- アプリケーションログの集約
- システムメトリクスの監視
- 異常検知とアラート通知
- トラブルシューティング
- パフォーマンス最適化

---

## 基本概念

### CloudWatchの構成要素

```
┌─────────────────────────────────────────┐
│         Amazon CloudWatch               │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────┐  ┌──────────┐           │
│  │   Logs   │  │ Metrics  │           │
│  └────┬─────┘  └────┬─────┘           │
│       │             │                  │
│  ┌────▼──────────────▼─────┐          │
│  │      Alarms              │          │
│  └────┬─────────────────────┘          │
│       │                                │
│  ┌────▼─────┐  ┌──────────┐          │
│  │Dashboard │  │ Insights  │          │
│  └──────────┘  └──────────┘          │
│                                         │
└─────────────────────────────────────────┘
```

---

## CloudWatch Logs

### ロググループとログストリーム

```
Log Group: /aws/lambda/my-function
├── Log Stream: 2024/01/15/[$LATEST]abc123
├── Log Stream: 2024/01/15/[$LATEST]def456
└── Log Stream: 2024/01/15/[$LATEST]ghi789
```

### AWS CDKでのセットアップ

```typescript
import * as logs from 'aws-cdk-lib/aws-logs';
import * as cdk from 'aws-cdk-lib';

export class CloudWatchLogsStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ロググループの作成
    const logGroup = new logs.LogGroup(this, 'MyLogGroup', {
      logGroupName: '/my-app/application',
      retention: logs.RetentionDays.ONE_WEEK, // 7日間保持
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // 長期保存用（1年間）
    const archiveLogGroup = new logs.LogGroup(this, 'ArchiveLogGroup', {
      logGroupName: '/my-app/archive',
      retention: logs.RetentionDays.ONE_YEAR,
    });

    // 出力
    new cdk.CfnOutput(this, 'LogGroupName', {
      value: logGroup.logGroupName,
    });
  }
}
```

### ログの送信

#### AWS SDK（Node.js）

```typescript
import {
  CloudWatchLogsClient,
  CreateLogGroupCommand,
  CreateLogStreamCommand,
  PutLogEventsCommand,
} from '@aws-sdk/client-cloudwatch-logs';

const client = new CloudWatchLogsClient({ region: 'us-east-1' });

// ロググループの作成
async function createLogGroup(logGroupName: string) {
  try {
    await client.send(
      new CreateLogGroupCommand({
        logGroupName,
      })
    );
    console.log('Log group created');
  } catch (error: any) {
    if (error.name === 'ResourceAlreadyExistsException') {
      console.log('Log group already exists');
    } else {
      throw error;
    }
  }
}

// ログストリームの作成
async function createLogStream(logGroupName: string, logStreamName: string) {
  try {
    await client.send(
      new CreateLogStreamCommand({
        logGroupName,
        logStreamName,
      })
    );
    console.log('Log stream created');
  } catch (error: any) {
    if (error.name === 'ResourceAlreadyExistsException') {
      console.log('Log stream already exists');
    } else {
      throw error;
    }
  }
}

// ログイベントの送信
async function putLogEvents(
  logGroupName: string,
  logStreamName: string,
  messages: string[]
) {
  try {
    const response = await client.send(
      new PutLogEventsCommand({
        logGroupName,
        logStreamName,
        logEvents: messages.map((message) => ({
          message,
          timestamp: Date.now(),
        })),
      })
    );

    console.log('Logs sent successfully');
    return response.nextSequenceToken;
  } catch (error) {
    console.error('Failed to send logs:', error);
    throw error;
  }
}

// 使用例
async function main() {
  const logGroupName = '/my-app/application';
  const logStreamName = `stream-${Date.now()}`;

  await createLogGroup(logGroupName);
  await createLogStream(logGroupName, logStreamName);
  await putLogEvents(logGroupName, logStreamName, [
    'Application started',
    'User logged in',
    'Request processed',
  ]);
}
```

#### Winston統合

```typescript
import winston from 'winston';
import WinstonCloudWatch from 'winston-cloudwatch';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console({
      format: winston.format.simple(),
    }),
    new WinstonCloudWatch({
      logGroupName: '/my-app/application',
      logStreamName: `${process.env.NODE_ENV}-${new Date().toISOString().split('T')[0]}`,
      awsRegion: 'us-east-1',
      jsonMessage: true,
    }),
  ],
});

// 使用例
logger.info('User logged in', { userId: '12345', email: 'user@example.com' });
logger.error('Failed to process request', { error: 'Invalid input' });
```

### サブスクリプションフィルター

```typescript
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as destinations from 'aws-cdk-lib/aws-logs-destinations';

// Lambda関数へログを送信
const logProcessorFunction = new lambda.Function(this, 'LogProcessor', {
  runtime: lambda.Runtime.NODEJS_18_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset('lambda/log-processor'),
});

logGroup.addSubscriptionFilter('Subscription', {
  destination: new destinations.LambdaDestination(logProcessorFunction),
  filterPattern: logs.FilterPattern.allTerms('ERROR', 'WARN'),
});

// Kinesis Data Firehoseへ送信
import * as firehose from 'aws-cdk-lib/aws-kinesisfirehose';

const deliveryStream = new firehose.CfnDeliveryStream(this, 'DeliveryStream', {
  // 設定...
});

logGroup.addSubscriptionFilter('FirehoseSubscription', {
  destination: new destinations.KinesisDestination(deliveryStream),
  filterPattern: logs.FilterPattern.allEvents(),
});
```

---

## CloudWatch Metrics

### カスタムメトリクスの送信

```typescript
import {
  CloudWatchClient,
  PutMetricDataCommand,
  StandardUnit,
} from '@aws-sdk/client-cloudwatch';

const client = new CloudWatchClient({ region: 'us-east-1' });

async function putMetric(
  namespace: string,
  metricName: string,
  value: number,
  unit: StandardUnit = StandardUnit.Count,
  dimensions?: Record<string, string>
) {
  try {
    await client.send(
      new PutMetricDataCommand({
        Namespace: namespace,
        MetricData: [
          {
            MetricName: metricName,
            Value: value,
            Unit: unit,
            Timestamp: new Date(),
            Dimensions: dimensions
              ? Object.entries(dimensions).map(([Name, Value]) => ({
                  Name,
                  Value,
                }))
              : undefined,
          },
        ],
      })
    );

    console.log('Metric sent successfully');
  } catch (error) {
    console.error('Failed to send metric:', error);
    throw error;
  }
}

// 使用例
await putMetric('MyApp', 'PageViews', 1, StandardUnit.Count, {
  Page: '/home',
  Environment: 'production',
});

await putMetric('MyApp', 'ResponseTime', 125, StandardUnit.Milliseconds, {
  Endpoint: '/api/users',
});

await putMetric('MyApp', 'MemoryUsage', 512, StandardUnit.Megabytes);
```

### 埋め込みメトリクス形式（EMF）

```typescript
// Lambda関数内でEMFを使用
export const handler = async (event: any) => {
  // EMF形式でメトリクスを出力
  console.log(
    JSON.stringify({
      _aws: {
        Timestamp: Date.now(),
        CloudWatchMetrics: [
          {
            Namespace: 'MyApp',
            Dimensions: [['Service', 'Operation']],
            Metrics: [
              {
                Name: 'ProcessingTime',
                Unit: 'Milliseconds',
              },
              {
                Name: 'ItemsProcessed',
                Unit: 'Count',
              },
            ],
          },
        ],
      },
      Service: 'OrderService',
      Operation: 'ProcessOrder',
      ProcessingTime: 234,
      ItemsProcessed: 5,
      orderId: event.orderId,
      userId: event.userId,
    })
  );

  return { statusCode: 200 };
};
```

### CDKでのメトリクス取得

```typescript
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';

// Lambda関数のメトリクス
const functionErrorsMetric = myFunction.metricErrors({
  statistic: 'Sum',
  period: cdk.Duration.minutes(5),
});

const functionDurationMetric = myFunction.metricDuration({
  statistic: 'Average',
  period: cdk.Duration.minutes(5),
});

// DynamoDBテーブルのメトリクス
const tableReadThrottleMetric = table.metricUserErrors({
  statistic: 'Sum',
  period: cdk.Duration.minutes(1),
});

// カスタムメトリクス
const customMetric = new cloudwatch.Metric({
  namespace: 'MyApp',
  metricName: 'PageViews',
  dimensionsMap: {
    Page: '/home',
  },
  statistic: 'Sum',
  period: cdk.Duration.minutes(5),
});
```

---

## CloudWatch Alarms

### アラームの作成

```typescript
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as actions from 'aws-cdk-lib/aws-cloudwatch-actions';
import * as sns from 'aws-cdk-lib/aws-sns';

// SNSトピック（通知先）
const topic = new sns.Topic(this, 'AlarmTopic', {
  displayName: 'CloudWatch Alarms',
});

// Lambda関数のエラー率アラーム
const errorAlarm = new cloudwatch.Alarm(this, 'FunctionErrorAlarm', {
  metric: myFunction.metricErrors({
    statistic: 'Sum',
    period: cdk.Duration.minutes(5),
  }),
  threshold: 10,
  evaluationPeriods: 2,
  datapointsToAlarm: 2,
  comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
  alarmDescription: 'Alert when function errors exceed 10 in 5 minutes',
  alarmName: 'my-function-errors',
  treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
});

// アラームアクションの追加
errorAlarm.addAlarmAction(new actions.SnsAction(topic));
errorAlarm.addOkAction(new actions.SnsAction(topic));

// DynamoDB書き込みスロットリングアラーム
const writeThrottleAlarm = new cloudwatch.Alarm(this, 'WriteThrottleAlarm', {
  metric: table.metricSystemErrorsForOperations({
    operations: [dynamodb.Operation.PUT_ITEM],
    statistic: 'Sum',
    period: cdk.Duration.minutes(1),
  }),
  threshold: 5,
  evaluationPeriods: 3,
  alarmDescription: 'Alert when write throttling occurs',
});

// 複合アラーム
const compositeAlarm = new cloudwatch.CompositeAlarm(this, 'CompositeAlarm', {
  compositeAlarmName: 'critical-system-alarm',
  alarmDescription: 'Alert when multiple issues occur',
  alarmRule: cloudwatch.AlarmRule.anyOf(
    cloudwatch.AlarmRule.fromAlarm(errorAlarm, cloudwatch.AlarmState.ALARM),
    cloudwatch.AlarmRule.fromAlarm(
      writeThrottleAlarm,
      cloudwatch.AlarmState.ALARM
    )
  ),
});
```

### 異常検知アラーム

```typescript
// 異常検知を使用したアラーム
const anomalyDetector = new cloudwatch.CfnAnomalyDetector(
  this,
  'AnomalyDetector',
  {
    namespace: 'AWS/Lambda',
    metricName: 'Duration',
    dimensions: [
      {
        name: 'FunctionName',
        value: myFunction.functionName,
      },
    ],
    stat: 'Average',
  }
);

const anomalyAlarm = new cloudwatch.Alarm(this, 'AnomalyAlarm', {
  metric: myFunction.metricDuration({
    statistic: 'Average',
    period: cdk.Duration.minutes(5),
  }),
  threshold: 2, // 標準偏差の倍数
  evaluationPeriods: 2,
  comparisonOperator:
    cloudwatch.ComparisonOperator.LESS_THAN_LOWER_OR_GREATER_THAN_UPPER_THRESHOLD,
  alarmDescription: 'Alert on anomalous function duration',
});
```

---

## CloudWatch Dashboards

### ダッシュボードの作成

```typescript
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';

const dashboard = new cloudwatch.Dashboard(this, 'MyDashboard', {
  dashboardName: 'my-app-dashboard',
});

// メトリクスウィジェット
dashboard.addWidgets(
  new cloudwatch.GraphWidget({
    title: 'Lambda Function Metrics',
    left: [
      myFunction.metricInvocations({
        statistic: 'Sum',
        period: cdk.Duration.minutes(5),
        label: 'Invocations',
      }),
      myFunction.metricErrors({
        statistic: 'Sum',
        period: cdk.Duration.minutes(5),
        label: 'Errors',
      }),
    ],
    right: [
      myFunction.metricDuration({
        statistic: 'Average',
        period: cdk.Duration.minutes(5),
        label: 'Duration (avg)',
      }),
    ],
    width: 12,
    height: 6,
  })
);

// 単一値ウィジェット
dashboard.addWidgets(
  new cloudwatch.SingleValueWidget({
    title: 'Current Error Rate',
    metrics: [
      myFunction.metricErrors({
        statistic: 'Sum',
        period: cdk.Duration.minutes(1),
      }),
    ],
    width: 6,
    height: 3,
  }),
  new cloudwatch.SingleValueWidget({
    title: 'Avg Response Time',
    metrics: [
      customMetric.with({
        statistic: 'Average',
        period: cdk.Duration.minutes(5),
      }),
    ],
    width: 6,
    height: 3,
  })
);

// ログウィジェット
dashboard.addWidgets(
  new cloudwatch.LogQueryWidget({
    title: 'Recent Errors',
    logGroupNames: [logGroup.logGroupName],
    queryLines: [
      'fields @timestamp, @message',
      'filter @message like /ERROR/',
      'sort @timestamp desc',
      'limit 20',
    ],
    width: 24,
    height: 6,
  })
);

// テキストウィジェット（Markdown）
dashboard.addWidgets(
  new cloudwatch.TextWidget({
    markdown: `
# My Application Dashboard

This dashboard monitors:
- Lambda function performance
- DynamoDB operations
- API Gateway requests
- Error rates and logs

Last updated: ${new Date().toISOString()}
    `,
    width: 24,
    height: 4,
  })
);
```

---

## CloudWatch Insights

### Logs Insights クエリ

```typescript
// AWS SDK
import { CloudWatchLogsClient, StartQueryCommand } from '@aws-sdk/client-cloudwatch-logs';

async function queryLogs() {
  const client = new CloudWatchLogsClient({ region: 'us-east-1' });

  const response = await client.send(
    new StartQueryCommand({
      logGroupName: '/aws/lambda/my-function',
      startTime: Math.floor((Date.now() - 3600000) / 1000), // 1時間前
      endTime: Math.floor(Date.now() / 1000),
      queryString: `
        fields @timestamp, @message
        | filter @message like /ERROR/
        | stats count() by bin(5m)
      `,
    })
  );

  console.log('Query ID:', response.queryId);
  return response.queryId;
}
```

### 便利なクエリ例

#### エラーログの抽出

```
fields @timestamp, @message, @logStream
| filter @message like /ERROR/ or @message like /Exception/
| sort @timestamp desc
| limit 100
```

#### レスポンスタイムの統計

```
fields @timestamp, duration
| stats avg(duration), max(duration), min(duration), pct(duration, 95) by bin(5m)
```

#### ユーザー別リクエスト数

```
fields @timestamp, userId
| stats count() as requestCount by userId
| sort requestCount desc
| limit 10
```

#### エラー率の計算

```
stats count(@message) as total,
      count_if(@message like /ERROR/) as errors
| extend errorRate = 100.0 * errors / total
```

#### Lambda Cold Start の検出

```
filter @type = "REPORT"
| fields @timestamp, @duration, @billedDuration, @memorySize, @maxMemoryUsed
| filter @message like /Init Duration/
| sort @timestamp desc
```

---

## CloudWatch Events / EventBridge

CloudWatch Events は EventBridge に統合されました。

```typescript
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';

// スケジュールイベント（Cron）
new events.Rule(this, 'ScheduleRule', {
  schedule: events.Schedule.cron({
    minute: '0',
    hour: '9',
    weekDay: 'MON-FRI',
  }),
  targets: [new targets.LambdaFunction(myFunction)],
});

// カスタムイベント
const bus = new events.EventBus(this, 'MyEventBus', {
  eventBusName: 'my-event-bus',
});

new events.Rule(this, 'CustomEventRule', {
  eventBus: bus,
  eventPattern: {
    source: ['my.application'],
    detailType: ['Order Placed'],
  },
  targets: [new targets.LambdaFunction(orderProcessorFunction)],
});
```

---

## 実装例

### Express.js アプリケーション監視

```typescript
import express from 'express';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import winston from 'winston';
import WinstonCloudWatch from 'winston-cloudwatch';

const app = express();
const cloudwatch = new CloudWatchClient({ region: 'us-east-1' });

// ロガー設定
const logger = winston.createLogger({
  transports: [
    new WinstonCloudWatch({
      logGroupName: '/my-app/express',
      logStreamName: `${process.env.NODE_ENV}`,
      awsRegion: 'us-east-1',
      jsonMessage: true,
    }),
  ],
});

// メトリクス送信ヘルパー
async function sendMetric(
  metricName: string,
  value: number,
  dimensions?: Record<string, string>
) {
  await cloudwatch.send(
    new PutMetricDataCommand({
      Namespace: 'MyApp/Express',
      MetricData: [
        {
          MetricName: metricName,
          Value: value,
          Unit: 'Count',
          Timestamp: new Date(),
          Dimensions: dimensions
            ? Object.entries(dimensions).map(([Name, Value]) => ({ Name, Value }))
            : undefined,
        },
      ],
    })
  );
}

// ミドルウェア: リクエスト計測
app.use((req, res, next) => {
  const startTime = Date.now();

  res.on('finish', async () => {
    const duration = Date.now() - startTime;

    // ログ記録
    logger.info('Request processed', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration,
      userAgent: req.get('user-agent'),
    });

    // メトリクス送信
    await sendMetric('RequestCount', 1, {
      Method: req.method,
      Path: req.path,
      StatusCode: res.statusCode.toString(),
    });

    await sendMetric('ResponseTime', duration, {
      Path: req.path,
    });

    if (res.statusCode >= 500) {
      await sendMetric('ServerErrors', 1, {
        Path: req.path,
      });
    }
  });

  next();
});

// エラーハンドリング
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  sendMetric('UnhandledErrors', 1, {
    Path: req.path,
  });

  res.status(500).json({ error: 'Internal server error' });
});

app.listen(3000, () => {
  logger.info('Server started', { port: 3000 });
});
```

### Lambda関数の包括的モニタリング

```typescript
import { Context } from 'aws-lambda';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';

const cloudwatch = new CloudWatchClient({ region: 'us-east-1' });

// カスタムメトリクス送信
async function publishMetrics(metricName: string, value: number) {
  console.log(
    JSON.stringify({
      _aws: {
        Timestamp: Date.now(),
        CloudWatchMetrics: [
          {
            Namespace: 'MyApp/Lambda',
            Dimensions: [['FunctionName']],
            Metrics: [{ Name: metricName, Unit: 'Count' }],
          },
        ],
      },
      FunctionName: process.env.AWS_LAMBDA_FUNCTION_NAME,
      [metricName]: value,
    })
  );
}

export const handler = async (event: any, context: Context) => {
  const startTime = Date.now();
  let success = false;

  try {
    console.log('Processing event', { event, requestId: context.requestId });

    // ビジネスロジック
    const result = await processEvent(event);

    success = true;
    await publishMetrics('SuccessCount', 1);

    console.log('Event processed successfully', {
      result,
      requestId: context.requestId,
    });

    return { statusCode: 200, body: JSON.stringify(result) };
  } catch (error: any) {
    console.error('Error processing event', {
      error: error.message,
      stack: error.stack,
      event,
      requestId: context.requestId,
    });

    await publishMetrics('ErrorCount', 1);

    throw error;
  } finally {
    const duration = Date.now() - startTime;
    await publishMetrics('ProcessingTime', duration);

    console.log('Request completed', {
      duration,
      success,
      requestId: context.requestId,
    });
  }
};

async function processEvent(event: any) {
  // 処理...
  return { processed: true };
}
```

---

## ベストプラクティス

### 1. ログの構造化

```typescript
// 良い例: 構造化ログ
logger.info('User login', {
  userId: '12345',
  email: 'user@example.com',
  ipAddress: '192.168.1.1',
  timestamp: new Date().toISOString(),
  loginMethod: 'password',
});

// 悪い例: 非構造化ログ
logger.info('User 12345 (user@example.com) logged in from 192.168.1.1');
```

### 2. メトリクスのディメンション設計

```typescript
// 適切なディメンション
await putMetric('ApiRequests', 1, {
  Endpoint: '/api/users',
  Method: 'GET',
  StatusCode: '200',
  Environment: 'production',
});

// ディメンションが多すぎる（コスト増）
await putMetric('ApiRequests', 1, {
  Endpoint: '/api/users',
  Method: 'GET',
  StatusCode: '200',
  UserId: '12345', // ユーザーIDは不要
  Timestamp: new Date().toISOString(), // タイムスタンプは不要
  RequestId: 'abc-123', // リクエストIDは不要
});
```

### 3. コスト最適化

```typescript
// ログ保持期間の設定
const logGroup = new logs.LogGroup(this, 'LogGroup', {
  logGroupName: '/my-app/logs',
  // 短期ログ: 1週間
  retention: logs.RetentionDays.ONE_WEEK,
});

// S3へのエクスポート（長期保存）
import * as s3 from 'aws-cdk-lib/aws-s3';

const archiveBucket = new s3.Bucket(this, 'ArchiveBucket', {
  lifecycleRules: [
    {
      transitions: [
        {
          storageClass: s3.StorageClass.GLACIER,
          transitionAfter: cdk.Duration.days(90),
        },
      ],
    },
  ],
});

// Lambda関数でログをS3にエクスポート
const exportFunction = new lambda.Function(this, 'ExportLogs', {
  runtime: lambda.Runtime.NODEJS_18_X,
  handler: 'index.handler',
  code: lambda.Code.fromInline(`
    const { CloudWatchLogsClient, CreateExportTaskCommand } = require('@aws-sdk/client-cloudwatch-logs');
    const client = new CloudWatchLogsClient();

    exports.handler = async () => {
      const oneDayAgo = Date.now() - 86400000;
      await client.send(new CreateExportTaskCommand({
        logGroupName: '/my-app/logs',
        from: oneDayAgo,
        to: Date.now(),
        destination: '${archiveBucket.bucketName}',
      }));
    };
  `),
  timeout: cdk.Duration.minutes(1),
});

archiveBucket.grantWrite(exportFunction);

// 毎日実行
new events.Rule(this, 'ExportRule', {
  schedule: events.Schedule.rate(cdk.Duration.days(1)),
  targets: [new targets.LambdaFunction(exportFunction)],
});
```

### 4. アラームの設定

```typescript
// アラーム疲れを避ける
const alarm = new cloudwatch.Alarm(this, 'HighErrorRate', {
  metric: errorMetric,
  threshold: 10,
  evaluationPeriods: 3, // 3回連続で閾値超過
  datapointsToAlarm: 2, // そのうち2回がアラーム条件
  treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
});

// 複数の通知チャネル
import * as subscriptions from 'aws-cdk-lib/aws-sns-subscriptions';

const criticalTopic = new sns.Topic(this, 'CriticalAlerts');
criticalTopic.addSubscription(
  new subscriptions.EmailSubscription('oncall@example.com')
);
criticalTopic.addSubscription(
  new subscriptions.SmsSubscription('+1234567890')
);

alarm.addAlarmAction(new actions.SnsAction(criticalTopic));
```

---

## 参考リンク

- [Amazon CloudWatch 公式ドキュメント](https://docs.aws.amazon.com/cloudwatch/)
- [CloudWatch Logs Insights クエリ構文](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [CloudWatch Embedded Metric Format](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format.html)
- [CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/)
