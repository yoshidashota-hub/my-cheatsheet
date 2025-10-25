# AWS Step Functions 完全ガイド

## 目次
- [Step Functionsとは](#step-functionsとは)
- [State Types](#state-types)
- [State Machine定義](#state-machine定義)
- [Lambda統合](#lambda統合)
- [エラーハンドリング](#エラーハンドリング)
- [Express vs Standard](#express-vs-standard)
- [Serverless Framework統合](#serverless-framework統合)
- [実践パターン](#実践パターン)
- [ベストプラクティス](#ベストプラクティス)

---

## Step Functionsとは

AWS のサーバーレスワークフローオーケストレーションサービス。複数の AWS サービスを組み合わせたビジネスロジックを視覚的に構築・実行できる。

### 特徴

- 🔄 ワークフロー: 複雑なビジネスロジックを管理
- 📊 可視化: 実行状態を視覚的に確認
- 🔀 並列処理: 複数タスクの並列実行
- ⚠️ エラー処理: 自動リトライ・エラーハンドリング
- 💰 従量課金: 状態遷移数に応じた課金

### ユースケース

```
✓ 分散トランザクション（Saga パターン）
✓ ETL パイプライン
✓ バッチ処理
✓ マイクロサービス オーケストレーション
✓ 承認ワークフロー
✓ データ処理パイプライン
```

---

## State Types

### Task（タスク実行）

Lambda 関数や他の AWS サービスを実行。

```json
{
  "ProcessOrder": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:ap-northeast-1:123456789:function:ProcessOrder",
    "Next": "NotifyUser"
  }
}
```

### Pass（データ加工）

データを加工して次のステートに渡す。

```json
{
  "AddTimestamp": {
    "Type": "Pass",
    "Result": {
      "timestamp": "2024-01-01T00:00:00Z"
    },
    "ResultPath": "$.metadata",
    "Next": "ProcessData"
  }
}
```

### Choice（条件分岐）

入力データに基づいて分岐。

```json
{
  "CheckStatus": {
    "Type": "Choice",
    "Choices": [
      {
        "Variable": "$.status",
        "StringEquals": "pending",
        "Next": "ProcessPending"
      },
      {
        "Variable": "$.status",
        "StringEquals": "approved",
        "Next": "ProcessApproved"
      }
    ],
    "Default": "HandleUnknown"
  }
}
```

### Wait（待機）

指定した時間または日時まで待機。

```json
{
  "Wait10Seconds": {
    "Type": "Wait",
    "Seconds": 10,
    "Next": "CheckStatus"
  },
  "WaitUntilDate": {
    "Type": "Wait",
    "Timestamp": "2024-12-31T23:59:59Z",
    "Next": "ProcessNewYear"
  },
  "WaitFromPath": {
    "Type": "Wait",
    "TimestampPath": "$.scheduledTime",
    "Next": "Execute"
  }
}
```

### Parallel（並列実行）

複数のブランチを並列実行。

```json
{
  "ProcessInParallel": {
    "Type": "Parallel",
    "Branches": [
      {
        "StartAt": "SendEmail",
        "States": {
          "SendEmail": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:...:function:SendEmail",
            "End": true
          }
        }
      },
      {
        "StartAt": "SendSMS",
        "States": {
          "SendSMS": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:...:function:SendSMS",
            "End": true
          }
        }
      }
    ],
    "Next": "CompleteNotification"
  }
}
```

### Map（ループ処理）

配列の各要素に対して処理を実行。

```json
{
  "ProcessItems": {
    "Type": "Map",
    "ItemsPath": "$.items",
    "Iterator": {
      "StartAt": "ProcessItem",
      "States": {
        "ProcessItem": {
          "Type": "Task",
          "Resource": "arn:aws:lambda:...:function:ProcessItem",
          "End": true
        }
      }
    },
    "MaxConcurrency": 10,
    "Next": "Complete"
  }
}
```

### Succeed / Fail（終了）

ワークフローの成功・失敗を明示的に終了。

```json
{
  "Success": {
    "Type": "Succeed"
  },
  "HandleError": {
    "Type": "Fail",
    "Error": "OrderProcessingError",
    "Cause": "Failed to process order"
  }
}
```

---

## State Machine定義

### 基本構造

```json
{
  "Comment": "Order processing workflow",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:ValidateOrder",
      "Next": "CheckInventory"
    },
    "CheckInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:CheckInventory",
      "Next": "IsAvailable"
    },
    "IsAvailable": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.available",
          "BooleanEquals": true,
          "Next": "ProcessPayment"
        }
      ],
      "Default": "NotifyOutOfStock"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:ProcessPayment",
      "Next": "SendConfirmation"
    },
    "SendConfirmation": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:SendConfirmation",
      "End": true
    },
    "NotifyOutOfStock": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:NotifyOutOfStock",
      "End": true
    }
  }
}
```

### InputPath / OutputPath / ResultPath

```json
{
  "ProcessData": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:ProcessData",
    "InputPath": "$.data",           // Lambda への入力を $.data に限定
    "ResultPath": "$.result",        // Lambda の結果を $.result に保存
    "OutputPath": "$.result",        // 次のステートへは $.result のみ渡す
    "Next": "NextState"
  }
}
```

例:

```json
// 入力
{
  "data": { "value": 10 },
  "metadata": { "timestamp": "2024-01-01" }
}

// InputPath: "$.data" → Lambda には { "value": 10 } が渡される
// Lambda の結果: { "processed": 20 }
// ResultPath: "$.result" → { "data": {...}, "metadata": {...}, "result": { "processed": 20 } }
// OutputPath: "$.result" → 次のステートには { "processed": 20 } が渡される
```

---

## Lambda統合

### Lambda 関数実装

```typescript
// functions/validateOrder.ts
import { Handler } from 'aws-lambda'

interface OrderInput {
  orderId: string
  items: Array<{ productId: string; quantity: number }>
  userId: string
}

interface OrderOutput extends OrderInput {
  valid: boolean
  totalAmount: number
}

export const handler: Handler<OrderInput, OrderOutput> = async (event) => {
  console.log('Validating order:', event)

  // バリデーション
  if (!event.orderId || !event.items || event.items.length === 0) {
    throw new Error('Invalid order')
  }

  // 金額計算（仮）
  const totalAmount = event.items.reduce((sum, item) => sum + (item.quantity * 100), 0)

  return {
    ...event,
    valid: true,
    totalAmount
  }
}
```

```typescript
// functions/checkInventory.ts
export const handler: Handler = async (event) => {
  console.log('Checking inventory:', event)

  // 在庫確認（仮）
  const available = Math.random() > 0.3 // 70%の確率で在庫あり

  return {
    ...event,
    available
  }
}
```

```typescript
// functions/processPayment.ts
export const handler: Handler = async (event) => {
  console.log('Processing payment:', event)

  try {
    // 決済処理（仮）
    const paymentId = `PAY-${Date.now()}`

    return {
      ...event,
      paymentId,
      paymentStatus: 'success'
    }
  } catch (error) {
    throw new Error('Payment failed')
  }
}
```

---

## エラーハンドリング

### Retry（リトライ）

```json
{
  "ProcessPayment": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:ProcessPayment",
    "Retry": [
      {
        "ErrorEquals": ["States.Timeout", "NetworkError"],
        "IntervalSeconds": 2,
        "MaxAttempts": 3,
        "BackoffRate": 2.0
      },
      {
        "ErrorEquals": ["States.ALL"],
        "IntervalSeconds": 1,
        "MaxAttempts": 2
      }
    ],
    "Next": "Success"
  }
}
```

### Catch（エラー処理）

```json
{
  "ProcessPayment": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:ProcessPayment",
    "Catch": [
      {
        "ErrorEquals": ["PaymentError"],
        "Next": "RefundUser",
        "ResultPath": "$.error"
      },
      {
        "ErrorEquals": ["States.ALL"],
        "Next": "HandleGenericError",
        "ResultPath": "$.error"
      }
    ],
    "Next": "Success"
  },
  "RefundUser": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:RefundUser",
    "End": true
  },
  "HandleGenericError": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:LogError",
    "Next": "NotifyAdmin"
  }
}
```

### タイムアウト

```json
{
  "LongRunningTask": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:Process",
    "TimeoutSeconds": 300,
    "HeartbeatSeconds": 60,
    "Next": "NextState"
  }
}
```

---

## Express vs Standard

### Standard Workflow

```
特徴:
- 最大実行時間: 1年
- 最大実行履歴: 25,000イベント
- 正確に1回実行（Exactly-once）
- 全実行履歴を保存

用途:
- 長時間実行ワークフロー
- 複雑なビジネスプロセス
- 監査が必要な処理
```

### Express Workflow

```
特徴:
- 最大実行時間: 5分
- 最大実行履歴: なし（CloudWatch Logsに出力）
- 最低1回実行（At-least-once）
- 高スループット（100,000 実行/秒）

用途:
- 高頻度・短時間の処理
- IoT データ処理
- リアルタイム処理
- マイクロサービス連携
```

### 比較表

| 項目 | Standard | Express |
|-----|---------|---------|
| 最大実行時間 | 1年 | 5分 |
| 料金 | 状態遷移数 | 実行数+期間 |
| 実行履歴 | 保存 | CloudWatch Logs |
| 実行保証 | Exactly-once | At-least-once |
| スループット | 4,000/秒 | 100,000/秒 |

---

## Serverless Framework統合

### serverless.yml 設定

```yaml
# serverless.yml
service: order-workflow

provider:
  name: aws
  runtime: nodejs18.x
  region: ap-northeast-1

  environment:
    TABLE_NAME: ${self:service}-${self:provider.stage}-orders

  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:*
          Resource: "*"
        - Effect: Allow
          Action:
            - states:StartExecution
          Resource: "*"

functions:
  validateOrder:
    handler: src/functions/validateOrder.handler

  checkInventory:
    handler: src/functions/checkInventory.handler

  processPayment:
    handler: src/functions/processPayment.handler

  sendConfirmation:
    handler: src/functions/sendConfirmation.handler

  notifyOutOfStock:
    handler: src/functions/notifyOutOfStock.handler

  # ワークフロー起動用 API
  startWorkflow:
    handler: src/functions/startWorkflow.handler
    events:
      - httpApi:
          path: /orders
          method: post
    environment:
      STATE_MACHINE_ARN: !Ref OrderStateMachine

stepFunctions:
  stateMachines:
    orderStateMachine:
      name: OrderStateMachine-${self:provider.stage}
      definition:
        Comment: Order processing workflow
        StartAt: ValidateOrder
        States:
          ValidateOrder:
            Type: Task
            Resource:
              Fn::GetAtt: [validateOrder, Arn]
            Retry:
              - ErrorEquals: ["States.ALL"]
                IntervalSeconds: 1
                MaxAttempts: 2
            Catch:
              - ErrorEquals: ["States.ALL"]
                Next: HandleError
                ResultPath: $.error
            Next: CheckInventory

          CheckInventory:
            Type: Task
            Resource:
              Fn::GetAtt: [checkInventory, Arn]
            Next: IsAvailable

          IsAvailable:
            Type: Choice
            Choices:
              - Variable: $.available
                BooleanEquals: true
                Next: ProcessPayment
            Default: NotifyOutOfStock

          ProcessPayment:
            Type: Task
            Resource:
              Fn::GetAtt: [processPayment, Arn]
            Retry:
              - ErrorEquals: ["PaymentError"]
                IntervalSeconds: 2
                MaxAttempts: 3
                BackoffRate: 2.0
            Catch:
              - ErrorEquals: ["States.ALL"]
                Next: HandleError
                ResultPath: $.error
            Next: SendConfirmation

          SendConfirmation:
            Type: Task
            Resource:
              Fn::GetAtt: [sendConfirmation, Arn]
            End: true

          NotifyOutOfStock:
            Type: Task
            Resource:
              Fn::GetAtt: [notifyOutOfStock, Arn]
            End: true

          HandleError:
            Type: Fail
            Error: OrderProcessingError
            Cause: Failed to process order

plugins:
  - serverless-step-functions
  - serverless-esbuild
```

### プラグインインストール

```bash
npm install -D serverless-step-functions
```

### ワークフロー起動

```typescript
// src/functions/startWorkflow.ts
import { APIGatewayProxyHandlerV2 } from 'aws-lambda'
import { SFNClient, StartExecutionCommand } from '@aws-sdk/client-sfn'

const sfn = new SFNClient({})
const STATE_MACHINE_ARN = process.env.STATE_MACHINE_ARN!

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const body = JSON.parse(event.body || '{}')

    const command = new StartExecutionCommand({
      stateMachineArn: STATE_MACHINE_ARN,
      input: JSON.stringify({
        orderId: crypto.randomUUID(),
        ...body
      })
    })

    const result = await sfn.send(command)

    return {
      statusCode: 200,
      body: JSON.stringify({
        executionArn: result.executionArn,
        startDate: result.startDate
      })
    }
  } catch (error) {
    console.error('Error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Failed to start workflow' })
    }
  }
}
```

---

## 実践パターン

### Saga パターン（分散トランザクション）

```json
{
  "Comment": "Saga pattern for distributed transaction",
  "StartAt": "CreateOrder",
  "States": {
    "CreateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:CreateOrder",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "CompensateCreateOrder",
        "ResultPath": "$.error"
      }],
      "Next": "ReserveInventory"
    },
    "ReserveInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:ReserveInventory",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "CompensateReserveInventory",
        "ResultPath": "$.error"
      }],
      "Next": "ProcessPayment"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:ProcessPayment",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "CompensateProcessPayment",
        "ResultPath": "$.error"
      }],
      "Next": "Success"
    },
    "Success": {
      "Type": "Succeed"
    },
    "CompensateProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:RefundPayment",
      "Next": "CompensateReserveInventory"
    },
    "CompensateReserveInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:ReleaseInventory",
      "Next": "CompensateCreateOrder"
    },
    "CompensateCreateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:CancelOrder",
      "Next": "Fail"
    },
    "Fail": {
      "Type": "Fail"
    }
  }
}
```

### ETL パイプライン

```json
{
  "Comment": "ETL Pipeline",
  "StartAt": "ExtractData",
  "States": {
    "ExtractData": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:ExtractData",
      "Next": "TransformInParallel"
    },
    "TransformInParallel": {
      "Type": "Map",
      "ItemsPath": "$.batches",
      "MaxConcurrency": 10,
      "Iterator": {
        "StartAt": "TransformBatch",
        "States": {
          "TransformBatch": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:...:function:TransformBatch",
            "End": true
          }
        }
      },
      "Next": "LoadData"
    },
    "LoadData": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:LoadData",
      "End": true
    }
  }
}
```

### 承認ワークフロー

```json
{
  "Comment": "Approval workflow with wait",
  "StartAt": "RequestApproval",
  "States": {
    "RequestApproval": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:SendApprovalEmail",
      "Next": "WaitForApproval"
    },
    "WaitForApproval": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
      "Parameters": {
        "FunctionName": "CheckApprovalStatus",
        "Payload": {
          "token.$": "$$.Task.Token"
        }
      },
      "Next": "IsApproved"
    },
    "IsApproved": {
      "Type": "Choice",
      "Choices": [{
        "Variable": "$.approved",
        "BooleanEquals": true,
        "Next": "ExecuteTask"
      }],
      "Default": "Rejected"
    },
    "ExecuteTask": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:ExecuteTask",
      "End": true
    },
    "Rejected": {
      "Type": "Fail",
      "Error": "ApprovalRejected"
    }
  }
}
```

---

## ベストプラクティス

### 1. エラーハンドリング必須

```json
{
  "ProcessData": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:ProcessData",
    "Retry": [
      {
        "ErrorEquals": ["States.TaskFailed"],
        "IntervalSeconds": 2,
        "MaxAttempts": 3,
        "BackoffRate": 2.0
      }
    ],
    "Catch": [
      {
        "ErrorEquals": ["States.ALL"],
        "Next": "HandleError",
        "ResultPath": "$.error"
      }
    ],
    "Next": "Success"
  }
}
```

### 2. タイムアウト設定

```json
{
  "LongTask": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:LongTask",
    "TimeoutSeconds": 300,
    "Next": "NextState"
  }
}
```

### 3. 適切な粒度でステート分割

```
✓ 各ステートは単一責任
✓ 再利用可能な単位で分割
✓ エラーハンドリングしやすい粒度
```

### 4. 入出力の設計

```json
{
  "ProcessOrder": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:...:function:ProcessOrder",
    "InputPath": "$.order",
    "ResultPath": "$.processedOrder",
    "Next": "NextState"
  }
}
```

### 5. コスト最適化

```
✓ Express Workflow を優先検討（短時間・高頻度）
✓ 不要なステート遷移を削減
✓ Parallel で並列化
✓ Map の MaxConcurrency を適切に設定
```

---

## 参考リンク

- [AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Step Functions Workflow Studio](https://docs.aws.amazon.com/step-functions/latest/dg/workflow-studio.html)
- [Serverless Step Functions Plugin](https://www.serverless.com/plugins/serverless-step-functions)
