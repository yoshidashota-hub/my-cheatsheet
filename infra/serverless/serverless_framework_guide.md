# Serverless Framework 完全ガイド

## 目次
- [Serverless Frameworkとは](#serverless-frameworkとは)
- [セットアップ](#セットアップ)
- [プロジェクト構造](#プロジェクト構造)
- [serverless.yml設定](#serverlessyml設定)
- [関数定義](#関数定義)
- [イベント設定](#イベント設定)
- [リソース管理](#リソース管理)
- [プラグイン](#プラグイン)
- [デプロイ](#デプロイ)
- [環境変数とシークレット](#環境変数とシークレット)
- [モニタリング](#モニタリング)
- [ベストプラクティス](#ベストプラクティス)

---

## Serverless Frameworkとは

サーバーレスアプリケーションを簡単に構築・デプロイできるオープンソースフレームワーク。

### 特徴

- 🚀 簡単デプロイ: 1コマンドでデプロイ
- ☁️ マルチクラウド: AWS, Azure, GCP対応
- 📦 インフラコード化: YAML でインフラ定義
- 🔌 プラグインシステム: 拡張性が高い
- 🌍 多言語対応: Node.js, Python, Go, Java等

### ユースケース

```
✓ REST API / GraphQL API
✓ バッチ処理
✓ イベント駆動処理
✓ Webhook
✓ データパイプライン
✓ マイクロサービス
```

---

## セットアップ

### インストール

```bash
# Serverless Framework CLI インストール
npm install -g serverless

# バージョン確認
serverless --version

# エイリアス
sls --version
```

### AWS認証情報設定

```bash
# AWS CLIで設定
aws configure

# または環境変数
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
```

### プロジェクト作成

```bash
# テンプレートから作成
serverless create --template aws-nodejs-typescript --path my-service

# 利用可能なテンプレート一覧
serverless create --help

# 主なテンプレート
- aws-nodejs          # Node.js
- aws-nodejs-typescript  # TypeScript
- aws-python3         # Python
- aws-go              # Go
```

---

## プロジェクト構造

### 基本構造

```
my-service/
├── serverless.yml      # サービス設定
├── package.json
├── tsconfig.json
├── src/
│   ├── functions/
│   │   ├── hello.ts
│   │   ├── getUser.ts
│   │   └── createOrder.ts
│   ├── types/
│   │   └── api.ts
│   └── utils/
│       ├── db.ts
│       └── response.ts
└── .env                # 環境変数（gitignore推奨）
```

### 大規模プロジェクト構造

```
my-app/
├── services/
│   ├── users/
│   │   ├── serverless.yml
│   │   ├── handler.ts
│   │   └── package.json
│   ├── products/
│   │   ├── serverless.yml
│   │   └── handler.ts
│   └── orders/
│       ├── serverless.yml
│       └── handler.ts
├── shared/
│   ├── utils/
│   └── types/
└── package.json
```

---

## serverless.yml設定

### 基本設定

```yaml
# serverless.yml
service: my-api

frameworkVersion: '3'

provider:
  name: aws
  runtime: nodejs18.x
  stage: ${opt:stage, 'dev'}
  region: ap-northeast-1

  # IAMロール
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:Query
            - dynamodb:GetItem
            - dynamodb:PutItem
          Resource: "arn:aws:dynamodb:${self:provider.region}:*:table/${self:custom.tableName}"

  # 環境変数
  environment:
    TABLE_NAME: ${self:custom.tableName}
    API_KEY: ${env:API_KEY}

# カスタム変数
custom:
  tableName: ${self:service}-${self:provider.stage}-table

# 関数定義
functions:
  hello:
    handler: src/functions/hello.handler
    events:
      - httpApi:
          path: /hello
          method: get

# リソース
resources:
  Resources:
    UsersTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:custom.tableName}
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: PK
            AttributeType: S
          - AttributeName: SK
            AttributeType: S
        KeySchema:
          - AttributeName: PK
            KeyType: HASH
          - AttributeName: SK
            KeyType: RANGE

# プラグイン
plugins:
  - serverless-offline
  - serverless-esbuild
```

### 複数環境対応

```yaml
# serverless.yml
provider:
  name: aws
  runtime: nodejs18.x
  stage: ${opt:stage, 'dev'}
  region: ${opt:region, 'ap-northeast-1'}

  environment:
    STAGE: ${self:provider.stage}
    DB_NAME: myapp-${self:provider.stage}
    LOG_LEVEL: ${self:custom.logLevels.${self:provider.stage}}

custom:
  logLevels:
    dev: debug
    staging: info
    prod: warn

  # ステージ別設定
  stages:
    dev:
      memorySize: 256
      timeout: 30
    prod:
      memorySize: 1024
      timeout: 10

functions:
  api:
    handler: handler.main
    memorySize: ${self:custom.stages.${self:provider.stage}.memorySize}
    timeout: ${self:custom.stages.${self:provider.stage}.timeout}
```

---

## 関数定義

### 基本的な関数

```typescript
// src/functions/hello.ts
import { APIGatewayProxyHandler } from 'aws-lambda'

export const handler: APIGatewayProxyHandler = async (event, context) => {
  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Hello from Serverless!',
      input: event
    })
  }
}
```

```yaml
# serverless.yml
functions:
  hello:
    handler: src/functions/hello.handler
    description: Hello function
    memorySize: 256
    timeout: 10
    events:
      - httpApi:
          path: /hello
          method: get
```

### TypeScript + 型安全

```typescript
// src/types/api.ts
export interface UserCreateRequest {
  email: string
  name: string
}

export interface UserResponse {
  id: string
  email: string
  name: string
  createdAt: string
}

// src/functions/createUser.ts
import { APIGatewayProxyHandler } from 'aws-lambda'
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb'
import { UserCreateRequest, UserResponse } from '../types/api'

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}))
const TABLE_NAME = process.env.TABLE_NAME!

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const request: UserCreateRequest = JSON.parse(event.body || '{}')

    if (!request.email || !request.name) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Email and name are required' })
      }
    }

    const user: UserResponse = {
      id: crypto.randomUUID(),
      email: request.email,
      name: request.name,
      createdAt: new Date().toISOString()
    }

    await client.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        PK: `USER#${user.id}`,
        SK: 'PROFILE',
        ...user
      }
    }))

    return {
      statusCode: 201,
      body: JSON.stringify(user)
    }
  } catch (error) {
    console.error('Error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' })
    }
  }
}
```

### 関数の分割

```yaml
# serverless.yml
functions:
  # ユーザー管理
  getUser:
    handler: src/functions/users/get.handler
    events:
      - httpApi:
          path: /users/{id}
          method: get

  createUser:
    handler: src/functions/users/create.handler
    events:
      - httpApi:
          path: /users
          method: post

  # 注文管理
  getOrders:
    handler: src/functions/orders/list.handler
    events:
      - httpApi:
          path: /orders
          method: get

  createOrder:
    handler: src/functions/orders/create.handler
    events:
      - httpApi:
          path: /orders
          method: post
```

---

## イベント設定

### HTTP API (API Gateway v2)

```yaml
functions:
  api:
    handler: handler.main
    events:
      # 基本
      - httpApi:
          path: /users
          method: get

      # パスパラメータ
      - httpApi:
          path: /users/{id}
          method: get

      # 認可
      - httpApi:
          path: /admin
          method: post
          authorizer:
            name: customAuthorizer

      # CORS
      - httpApi:
          path: /api
          method: any
          cors:
            origin: '*'
            headers:
              - Content-Type
              - Authorization
```

### REST API (API Gateway v1)

```yaml
functions:
  api:
    handler: handler.main
    events:
      - http:
          path: users
          method: get
          cors: true

      - http:
          path: users/{id}
          method: get
          request:
            parameters:
              paths:
                id: true

      # リクエストバリデーション
      - http:
          path: users
          method: post
          request:
            schemas:
              application/json: ${file(schemas/user-create.json)}
```

### DynamoDB Streams

```yaml
functions:
  processStream:
    handler: src/functions/processStream.handler
    events:
      - stream:
          type: dynamodb
          arn:
            Fn::GetAtt:
              - UsersTable
              - StreamArn
          batchSize: 10
          startingPosition: LATEST
          maximumRetryAttempts: 2
```

```typescript
// src/functions/processStream.ts
import { DynamoDBStreamHandler } from 'aws-lambda'

export const handler: DynamoDBStreamHandler = async (event) => {
  for (const record of event.Records) {
    console.log('Event:', record.eventName)

    if (record.eventName === 'INSERT') {
      const newItem = record.dynamodb?.NewImage
      console.log('New item:', newItem)
      // 処理...
    }
  }
}
```

### S3イベント

```yaml
functions:
  processUpload:
    handler: src/functions/processUpload.handler
    events:
      - s3:
          bucket: my-bucket
          event: s3:ObjectCreated:*
          rules:
            - prefix: uploads/
            - suffix: .jpg
          existing: true
```

### SQS

```yaml
functions:
  processQueue:
    handler: src/functions/processQueue.handler
    events:
      - sqs:
          arn:
            Fn::GetAtt:
              - MyQueue
              - Arn
          batchSize: 10
          maximumBatchingWindowInSeconds: 5
```

### EventBridge (CloudWatch Events)

```yaml
functions:
  scheduled:
    handler: src/functions/scheduled.handler
    events:
      # Cron
      - schedule:
          rate: cron(0 12 * * ? *)
          description: 'Run at noon every day'

      # Rate
      - schedule:
          rate: rate(5 minutes)

      # EventBridge
      - eventBridge:
          pattern:
            source:
              - aws.ec2
            detail-type:
              - EC2 Instance State-change Notification
```

### SNS

```yaml
functions:
  processNotification:
    handler: src/functions/processNotification.handler
    events:
      - sns:
          arn: arn:aws:sns:ap-northeast-1:123456789:my-topic
          topicName: MyTopic
```

---

## リソース管理

### DynamoDB テーブル

```yaml
resources:
  Resources:
    UsersTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:service}-${self:provider.stage}-users
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: PK
            AttributeType: S
          - AttributeName: SK
            AttributeType: S
          - AttributeName: email
            AttributeType: S
        KeySchema:
          - AttributeName: PK
            KeyType: HASH
          - AttributeName: SK
            KeyType: RANGE
        GlobalSecondaryIndexes:
          - IndexName: EmailIndex
            KeySchema:
              - AttributeName: email
                KeyType: HASH
            Projection:
              ProjectionType: ALL
        StreamSpecification:
          StreamViewType: NEW_AND_OLD_IMAGES
```

### S3 バケット

```yaml
resources:
  Resources:
    UploadsBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: ${self:service}-${self:provider.stage}-uploads
        CorsConfiguration:
          CorsRules:
            - AllowedOrigins:
                - '*'
              AllowedMethods:
                - GET
                - PUT
                - POST
              AllowedHeaders:
                - '*'
        PublicAccessBlockConfiguration:
          BlockPublicAcls: true
          BlockPublicPolicy: true
          IgnorePublicAcls: true
          RestrictPublicBuckets: true
```

### SQS キュー

```yaml
resources:
  Resources:
    ProcessQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: ${self:service}-${self:provider.stage}-queue
        VisibilityTimeout: 300
        MessageRetentionPeriod: 1209600
        RedrivePolicy:
          deadLetterTargetArn:
            Fn::GetAtt:
              - ProcessDLQ
              - Arn
          maxReceiveCount: 3

    ProcessDLQ:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: ${self:service}-${self:provider.stage}-dlq
        MessageRetentionPeriod: 1209600
```

### CloudWatch Logs

```yaml
resources:
  Resources:
    ApiLogGroup:
      Type: AWS::Logs::LogGroup
      Properties:
        LogGroupName: /aws/lambda/${self:service}-${self:provider.stage}-api
        RetentionInDays: 7
```

### 出力（Outputs）

```yaml
resources:
  Outputs:
    ApiUrl:
      Description: API Gateway URL
      Value:
        Fn::Sub: https://${HttpApi}.execute-api.${AWS::Region}.amazonaws.com
      Export:
        Name: ${self:service}-${self:provider.stage}-api-url

    TableName:
      Description: DynamoDB Table Name
      Value:
        Ref: UsersTable
      Export:
        Name: ${self:service}-${self:provider.stage}-table-name
```

---

## プラグイン

### 必須プラグイン

```bash
# TypeScript サポート
npm install -D serverless-esbuild

# ローカル開発
npm install -D serverless-offline

# 環境変数管理
npm install -D serverless-dotenv-plugin
```

```yaml
# serverless.yml
plugins:
  - serverless-esbuild
  - serverless-offline
  - serverless-dotenv-plugin

custom:
  esbuild:
    bundle: true
    minify: true
    sourcemap: true
    target: node18
    exclude:
      - aws-sdk
      - '@aws-sdk/*'

  serverless-offline:
    httpPort: 3000
    lambdaPort: 3002
```

### 便利なプラグイン

#### serverless-prune-plugin（古いバージョン削除）

```bash
npm install -D serverless-prune-plugin
```

```yaml
plugins:
  - serverless-prune-plugin

custom:
  prune:
    automatic: true
    number: 3  # 最新3バージョンのみ保持
```

#### serverless-domain-manager（カスタムドメイン）

```bash
npm install -D serverless-domain-manager
```

```yaml
plugins:
  - serverless-domain-manager

custom:
  customDomain:
    domainName: api.example.com
    certificateName: '*.example.com'
    basePath: ''
    stage: ${self:provider.stage}
    createRoute53Record: true
```

#### serverless-webpack（Webpack）

```bash
npm install -D serverless-webpack webpack
```

```yaml
plugins:
  - serverless-webpack

custom:
  webpack:
    webpackConfig: webpack.config.js
    includeModules: true
    packager: npm
```

---

## デプロイ

### 基本デプロイ

```bash
# デプロイ
serverless deploy

# ステージ指定
serverless deploy --stage prod

# リージョン指定
serverless deploy --region us-east-1

# 詳細ログ
serverless deploy --verbose
```

### 関数のみデプロイ

```bash
# 特定の関数のみデプロイ（高速）
serverless deploy function --function hello

# ステージ指定
serverless deploy function --function hello --stage prod
```

### 削除

```bash
# スタック全体削除
serverless remove

# ステージ指定
serverless remove --stage dev
```

### デプロイ情報確認

```bash
# デプロイ情報表示
serverless info

# エンドポイント確認
serverless info --verbose
```

### ログ確認

```bash
# ログをストリーミング
serverless logs --function hello --tail

# 過去のログ確認
serverless logs --function hello --startTime 1h
```

### ローカル実行

```bash
# 関数をローカルで実行
serverless invoke local --function hello

# データ付き実行
serverless invoke local --function hello --data '{"name": "John"}'

# ファイルから読み込み
serverless invoke local --function hello --path data.json
```

### オフライン開発

```bash
# serverless-offline 使用
npm install -D serverless-offline

# ローカルサーバー起動
serverless offline

# ポート指定
serverless offline --httpPort 3000
```

---

## 環境変数とシークレット

### 環境変数

```yaml
# serverless.yml
provider:
  environment:
    # 固定値
    STAGE: ${self:provider.stage}
    REGION: ${self:provider.region}

    # .env ファイルから
    API_KEY: ${env:API_KEY}

    # カスタム変数から
    TABLE_NAME: ${self:custom.tableName}

    # AWS リソース参照
    BUCKET_NAME:
      Ref: UploadsBucket

# 関数レベル環境変数
functions:
  api:
    handler: handler.main
    environment:
      FUNCTION_SPECIFIC: value
```

### .env ファイル

```bash
# .env.dev
API_KEY=dev-key-123
DATABASE_URL=dev-db-url

# .env.prod
API_KEY=prod-key-456
DATABASE_URL=prod-db-url
```

```yaml
# serverless.yml
plugins:
  - serverless-dotenv-plugin

custom:
  dotenv:
    path: .env.${self:provider.stage}
```

### AWS Systems Manager Parameter Store

```yaml
provider:
  environment:
    DB_PASSWORD: ${ssm:/myapp/${self:provider.stage}/db-password~true}
    # ~true で SecureString として取得
```

### AWS Secrets Manager

```yaml
provider:
  environment:
    API_SECRET: ${ssm:/aws/reference/secretsmanager/myapp/${self:provider.stage}/api-secret}
```

---

## モニタリング

### CloudWatch Logs

```yaml
# ログ保持期間設定
provider:
  logRetentionInDays: 7

functions:
  api:
    handler: handler.main
    # 関数ごとのログ設定
    logRetentionInDays: 14
```

```typescript
// 構造化ログ
export const handler = async (event: any) => {
  console.log(JSON.stringify({
    level: 'info',
    message: 'Processing request',
    requestId: event.requestContext.requestId,
    userId: event.userId
  }))
}
```

### X-Ray トレーシング

```yaml
provider:
  tracing:
    lambda: true
    apiGateway: true

functions:
  api:
    handler: handler.main
    tracing: Active
```

### CloudWatch メトリクス

```yaml
functions:
  api:
    handler: handler.main
    alarms:
      - functionErrors
      - functionThrottles
      - functionInvocations
      - functionDuration
```

### カスタムメトリクス

```typescript
import { CloudWatch } from '@aws-sdk/client-cloudwatch'

const cloudwatch = new CloudWatch({})

export const handler = async () => {
  await cloudwatch.putMetricData({
    Namespace: 'MyApp',
    MetricData: [
      {
        MetricName: 'OrdersProcessed',
        Value: 1,
        Unit: 'Count',
        Timestamp: new Date()
      }
    ]
  })
}
```

---

## ベストプラクティス

### 1. プロジェクト構成

```
✓ 関数を責務ごとに分割
✓ 共通ロジックを utils/ に集約
✓ 型定義を types/ に集約
✓ 環境ごとの設定ファイル分離
```

### 2. IAM 権限は最小限に

```yaml
# ✗ 悪い例
provider:
  iam:
    role:
      statements:
        - Effect: Allow
          Action: '*'
          Resource: '*'

# ○ 良い例
provider:
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:GetItem
            - dynamodb:PutItem
          Resource:
            - Fn::GetAtt: [UsersTable, Arn]
```

### 3. 環境変数管理

```yaml
# ○ ステージごとに分離
custom:
  config:
    dev:
      memorySize: 256
      timeout: 30
    prod:
      memorySize: 1024
      timeout: 10

functions:
  api:
    handler: handler.main
    memorySize: ${self:custom.config.${self:provider.stage}.memorySize}
    timeout: ${self:custom.config.${self:provider.stage}.timeout}
```

### 4. コールドスタート対策

```yaml
# Lambda ウォームアップ
plugins:
  - serverless-plugin-warmup

custom:
  warmup:
    default:
      enabled: true
      events:
        - schedule: rate(5 minutes)
      concurrency: 1
```

```typescript
// コールドスタート最適化
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'

// グローバルスコープで初期化
const client = new DynamoDBClient({})

export const handler = async (event: any) => {
  // 再利用される
  // ...
}
```

### 5. エラーハンドリング

```typescript
// src/utils/response.ts
export const success = (data: any) => ({
  statusCode: 200,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
  },
  body: JSON.stringify(data)
})

export const error = (statusCode: number, message: string) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
  },
  body: JSON.stringify({ error: message })
})

// 使用例
export const handler = async (event: any) => {
  try {
    const result = await processRequest(event)
    return success(result)
  } catch (err) {
    console.error('Error:', err)
    return error(500, 'Internal server error')
  }
}
```

### 6. バンドルサイズ最適化

```yaml
# serverless.yml
custom:
  esbuild:
    bundle: true
    minify: true
    sourcemap: false
    target: node18
    exclude:
      - aws-sdk
      - '@aws-sdk/*'

    # Tree shaking
    treeShaking: true
```

### 7. レイヤーの活用

```yaml
# 共通ライブラリをレイヤー化
layers:
  dependencies:
    path: layers/dependencies
    name: ${self:service}-${self:provider.stage}-dependencies
    description: Common dependencies
    compatibleRuntimes:
      - nodejs18.x

functions:
  api:
    handler: handler.main
    layers:
      - Ref: DependenciesLambdaLayer
```

### 8. タイムアウトとメモリ

```yaml
functions:
  # 軽い処理
  hello:
    handler: handler.hello
    memorySize: 128
    timeout: 3

  # 重い処理
  processData:
    handler: handler.processData
    memorySize: 1024
    timeout: 60

  # 長時間処理（最大15分）
  batchJob:
    handler: handler.batchJob
    memorySize: 3008
    timeout: 900
```

### 9. VPC 設定（必要な場合のみ）

```yaml
provider:
  vpc:
    securityGroupIds:
      - sg-xxxxxxxxx
    subnetIds:
      - subnet-xxxxxxxxx
      - subnet-yyyyyyyyy

# ⚠️ 注意: VPC内に配置するとコールドスタートが遅くなる
# RDSやElastiCache接続時のみ使用
```

### 10. デプロイ前のバリデーション

```bash
# package.json
{
  "scripts": {
    "validate": "serverless package",
    "deploy:dev": "npm run validate && serverless deploy --stage dev",
    "deploy:prod": "npm run validate && serverless deploy --stage prod"
  }
}
```

---

## CI/CD

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches:
      - main
      - develop

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: 18

      - name: Install dependencies
        run: npm ci

      - name: Deploy to dev
        if: github.ref == 'refs/heads/develop'
        run: npm run deploy:dev
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      - name: Deploy to prod
        if: github.ref == 'refs/heads/main'
        run: npm run deploy:prod
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

## トラブルシューティング

### デプロイエラー

```bash
# スタック状態確認
aws cloudformation describe-stacks --stack-name my-service-dev

# スタックイベント確認
aws cloudformation describe-stack-events --stack-name my-service-dev

# 失敗したスタック削除
serverless remove --stage dev
```

### ログ確認

```bash
# リアルタイムログ
serverless logs --function api --tail --stage dev

# 過去1時間のログ
serverless logs --function api --startTime 1h --stage dev

# エラーログのみ
serverless logs --function api --filter "ERROR" --stage dev
```

### パフォーマンス問題

```bash
# X-Ray でトレース確認
aws xray get-trace-summaries --start-time $(date -u -d '1 hour ago' +%s) --end-time $(date -u +%s)

# メモリ使用量確認
serverless metrics --function api --stage dev
```

---

## 参考リンク

- [Serverless Framework Documentation](https://www.serverless.com/framework/docs)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Serverless Examples](https://github.com/serverless/examples)
