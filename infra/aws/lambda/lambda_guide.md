# AWS Lambda 完全ガイド

## 目次
- [AWS Lambdaとは](#aws-lambdaとは)
- [基本概念](#基本概念)
- [Lambda関数の作成](#lambda関数の作成)
- [トリガー](#トリガー)
- [環境変数](#環境変数)
- [レイヤー](#レイヤー)
- [デプロイ](#デプロイ)
- [ログとモニタリング](#ログとモニタリング)
- [パフォーマンス最適化](#パフォーマンス最適化)

---

## AWS Lambdaとは

サーバーレスコンピューティングサービス。サーバー管理不要でコード実行。

### 特徴
- 🚀 サーバーレス
- 💰 実行時間課金
- 📈 自動スケーリング
- 🔌 イベントドリブン

### 対応言語
- Node.js, Python, Java, Go, Ruby, .NET, カスタムランタイム

---

## 基本概念

### 料金体系

```
無料枠（月次）:
- リクエスト: 100万回
- コンピューティング: 400,000 GB-秒

課金:
- リクエスト: $0.20 / 100万リクエスト
- コンピューティング: $0.0000166667 / GB-秒
```

### 制限

```
タイムアウト: 最大 15分
メモリ: 128MB 〜 10,240MB
一時ストレージ (/tmp): 最大 10GB
デプロイパッケージ: 50MB（zip圧縮時）/ 250MB（解凍後）
環境変数: 4KB
```

---

## Lambda関数の作成

### Node.js (JavaScript)

```javascript
// index.js
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2))

  const response = {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Hello from Lambda!',
      input: event
    })
  }

  return response
}
```

### Node.js (TypeScript)

```typescript
// index.ts
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda'

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  console.log('Event:', JSON.stringify(event, null, 2))

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      message: 'Hello from Lambda!',
      input: event
    })
  }
}
```

### Python

```python
# lambda_function.py
import json

def lambda_handler(event, context):
    print('Event:', json.dumps(event))

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from Lambda!',
            'input': event
        })
    }
```

### Go

```go
// main.go
package main

import (
    "context"
    "encoding/json"
    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-lambda-go/lambda"
)

type Response struct {
    Message string      `json:"message"`
    Input   interface{} `json:"input"`
}

func handler(ctx context.Context, event events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
    response := Response{
        Message: "Hello from Lambda!",
        Input:   event,
    }

    body, _ := json.Marshal(response)

    return events.APIGatewayProxyResponse{
        StatusCode: 200,
        Body:       string(body),
    }, nil
}

func main() {
    lambda.Start(handler)
}
```

---

## トリガー

### API Gateway

```javascript
exports.handler = async (event) => {
  const method = event.httpMethod
  const path = event.path
  const body = JSON.parse(event.body || '{}')

  console.log(`${method} ${path}`)

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify({ message: 'Success' })
  }
}
```

### S3

```javascript
exports.handler = async (event) => {
  const records = event.Records

  for (const record of records) {
    const bucket = record.s3.bucket.name
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '))

    console.log(`File uploaded: s3://${bucket}/${key}`)
  }

  return { statusCode: 200 }
}
```

### DynamoDB Streams

```javascript
exports.handler = async (event) => {
  for (const record of event.Records) {
    console.log('Event:', record.eventName)
    console.log('New:', JSON.stringify(record.dynamodb.NewImage))
    console.log('Old:', JSON.stringify(record.dynamodb.OldImage))
  }

  return { statusCode: 200 }
}
```

### EventBridge (CloudWatch Events)

```javascript
exports.handler = async (event) => {
  console.log('Scheduled event:', event.time)

  // 定期実行処理
  await performScheduledTask()

  return { statusCode: 200 }
}
```

### SQS

```javascript
exports.handler = async (event) => {
  for (const record of event.Records) {
    const body = JSON.parse(record.body)
    console.log('Message:', body)

    // メッセージ処理
    await processMessage(body)
  }

  return { statusCode: 200 }
}
```

---

## 環境変数

### コンソールから設定

```
AWS Console → Lambda → 設定 → 環境変数

DATABASE_URL=postgresql://...
API_KEY=xxxxx
STAGE=production
```

### コード内で使用

```javascript
exports.handler = async (event) => {
  const dbUrl = process.env.DATABASE_URL
  const apiKey = process.env.API_KEY
  const stage = process.env.STAGE

  console.log(`Running in ${stage} environment`)

  return { statusCode: 200 }
}
```

### AWS CLIで設定

```bash
aws lambda update-function-configuration \
  --function-name my-function \
  --environment Variables={DATABASE_URL=postgresql://...,API_KEY=xxxxx}
```

---

## レイヤー

共通ライブラリやランタイムを複数のLambda関数で共有。

### レイヤーの作成

```bash
# ディレクトリ構造
layer/
└── nodejs/
    └── node_modules/
        └── axios/

# レイヤー作成
cd layer
zip -r layer.zip .

aws lambda publish-layer-version \
  --layer-name my-dependencies \
  --zip-file fileb://layer.zip \
  --compatible-runtimes nodejs18.x
```

### 関数にレイヤーを追加

```bash
aws lambda update-function-configuration \
  --function-name my-function \
  --layers arn:aws:lambda:ap-northeast-1:123456789012:layer:my-dependencies:1
```

---

## デプロイ

### AWS CLI

```bash
# zipファイル作成
zip function.zip index.js

# 関数作成
aws lambda create-function \
  --function-name my-function \
  --runtime nodejs18.x \
  --role arn:aws:iam::123456789012:role/lambda-role \
  --handler index.handler \
  --zip-file fileb://function.zip

# 関数更新
aws lambda update-function-code \
  --function-name my-function \
  --zip-file fileb://function.zip
```

### AWS SAM

```yaml
# template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: my-function
      Runtime: nodejs18.x
      Handler: index.handler
      CodeUri: ./src
      MemorySize: 512
      Timeout: 30
      Environment:
        Variables:
          STAGE: production
      Events:
        Api:
          Type: Api
          Properties:
            Path: /hello
            Method: get
```

```bash
# ビルド
sam build

# デプロイ
sam deploy --guided
```

### Serverless Framework

```yaml
# serverless.yml
service: my-service

provider:
  name: aws
  runtime: nodejs18.x
  region: ap-northeast-1
  stage: ${opt:stage, 'dev'}
  environment:
    STAGE: ${self:provider.stage}

functions:
  hello:
    handler: src/handler.hello
    events:
      - httpApi:
          path: /hello
          method: get
    memorySize: 512
    timeout: 30
```

```bash
# デプロイ
serverless deploy --stage production
```

### CDK (TypeScript)

```typescript
import * as cdk from 'aws-cdk-lib'
import * as lambda from 'aws-cdk-lib/aws-lambda'
import * as apigateway from 'aws-cdk-lib/aws-apigateway'

export class LambdaStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string) {
    super(scope, id)

    const fn = new lambda.Function(this, 'MyFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
      memorySize: 512,
      timeout: cdk.Duration.seconds(30),
      environment: {
        STAGE: 'production'
      }
    })

    new apigateway.LambdaRestApi(this, 'Api', {
      handler: fn
    })
  }
}
```

---

## ログとモニタリング

### CloudWatch Logs

```javascript
exports.handler = async (event) => {
  console.log('Info:', 'Processing started')
  console.error('Error:', 'Something went wrong')
  console.warn('Warning:', 'This is a warning')

  return { statusCode: 200 }
}
```

### ログの確認

```bash
# 最新のログ
aws logs tail /aws/lambda/my-function --follow

# 特定期間のログ
aws logs filter-log-events \
  --log-group-name /aws/lambda/my-function \
  --start-time $(date -d '1 hour ago' +%s)000
```

### X-Ray（分散トレーシング）

```javascript
const AWSXRay = require('aws-xray-sdk-core')
const AWS = AWSXRay.captureAWS(require('aws-sdk'))

exports.handler = async (event) => {
  const segment = AWSXRay.getSegment()
  const subsegment = segment.addNewSubsegment('CustomOperation')

  try {
    // 処理
    await performOperation()
    subsegment.close()
  } catch (error) {
    subsegment.close(error)
    throw error
  }

  return { statusCode: 200 }
}
```

### メトリクス監視

```javascript
const { CloudWatch } = require('@aws-sdk/client-cloudwatch')
const cloudwatch = new CloudWatch()

exports.handler = async (event) => {
  await cloudwatch.putMetricData({
    Namespace: 'MyApp',
    MetricData: [{
      MetricName: 'ProcessedItems',
      Value: 10,
      Unit: 'Count'
    }]
  })

  return { statusCode: 200 }
}
```

---

## パフォーマンス最適化

### コールドスタート対策

```javascript
// グローバルスコープで初期化（再利用される）
const db = connectToDatabase()

exports.handler = async (event) => {
  // dbを使用
  const result = await db.query('SELECT * FROM users')

  return { statusCode: 200, body: JSON.stringify(result) }
}
```

### Provisioned Concurrency

```bash
# 事前に起動しておく
aws lambda put-provisioned-concurrency-config \
  --function-name my-function \
  --provisioned-concurrent-executions 5
```

### メモリ設定

```
メモリ ↑ → CPU ↑ → 実行速度 ↑
最適なメモリサイズを見つける = コスト最適化
```

### 接続プーリング

```javascript
let cachedDb = null

async function connectToDatabase() {
  if (cachedDb) {
    return cachedDb
  }

  cachedDb = await createConnection()
  return cachedDb
}

exports.handler = async (event) => {
  const db = await connectToDatabase()
  // 処理
}
```

---

## エラーハンドリング

```javascript
exports.handler = async (event) => {
  try {
    // メイン処理
    const result = await processEvent(event)

    return {
      statusCode: 200,
      body: JSON.stringify({ result })
    }
  } catch (error) {
    console.error('Error:', error)

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: error.message
      })
    }
  }
}
```

### リトライ設定

```bash
aws lambda put-function-event-invoke-config \
  --function-name my-function \
  --maximum-retry-attempts 2 \
  --maximum-event-age 3600
```

### Dead Letter Queue

```bash
aws lambda update-function-configuration \
  --function-name my-function \
  --dead-letter-config TargetArn=arn:aws:sqs:ap-northeast-1:123456789012:dlq
```

---

## 参考リンク

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS SAM](https://aws.amazon.com/serverless/sam/)
- [Serverless Framework](https://www.serverless.com/)

## 関連ガイド

### デプロイ方法
- [AWS SAM デプロイ](./deploy/aws_sam_deploy.md) - SAMでのデプロイ
- [AWS CDK デプロイ](./deploy/aws_cdk_deploy.md) - CDKでのデプロイ
- [Terraform デプロイ](./deploy/terraform_deploy.md) - Terraformでのデプロイ
- [Serverless Framework デプロイ](./deploy/serverless_framework_deploy.md) - Serverless Frameworkでのデプロイ
- [AWS CLI デプロイ](./deploy/aws_cli_deploy.md) - AWS CLIでのデプロイ

### AWS サービス統合
- [API Gateway ガイド](../api-gateway/api_gateway_guide.md) - LambdaとAPI Gatewayの統合
- [S3 ガイド](../s3/s3_guide.md) - S3イベントトリガー
- [SQS ガイド](../sqs/sqs_guide.md) - SQSトリガー
- [EventBridge ガイド](../eventbridge/eventbridge_guide.md) - イベント駆動アーキテクチャ
- [Step Functions ガイド](../step-functions/step_functions_guide.md) - ワークフロー統合
- [CloudWatch ガイド](../cloudwatch/cloudwatch_guide.md) - モニタリング・ログ

### コンテナ化
- [Docker ガイド](../../docker/docker_guide.md) - Lambdaコンテナイメージ

### IaC
- [Terraform ガイド](../../iac/terraform_guide.md) - インフラコード管理

### CI/CD
- [GitHub Actions ガイド](../../ci-cd/github_actions_guide.md) - デプロイ自動化
