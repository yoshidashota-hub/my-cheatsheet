# Serverless Framework Lambda Deploy

## 概要

最も人気の高いサードパーティサーバーレスフレームワーク

## 前提条件

- Node.js
- npm/yarn
- AWS CLI（認証用）

## 実務レベルのセットアップ

### 1. プロジェクト構造

```project
my-service/
├── serverless.yml
├── serverless/
│   ├── resources/
│   │   ├── dynamodb.yml
│   │   ├── s3.yml
│   │   └── iam.yml
│   └── functions/
│       ├── users.yml
│       └── orders.yml
├── src/
│   ├── handlers/
│   │   ├── users/
│   │   └── orders/
│   ├── libs/
│   ├── middlewares/
│   └── utils/
├── tests/
├── .env.example
├── package.json
└── webpack.config.js
```

### 2. 本番レベル serverless.yml

```yaml
service: my-ecommerce-api
frameworkVersion: "3"

plugins:
  - serverless-webpack
  - serverless-offline
  - serverless-dotenv-plugin
  - serverless-iam-roles-per-function
  - serverless-plugin-warmup
  - serverless-plugin-lambda-dead-letter

custom:
  webpack:
    webpackConfig: webpack.config.js
    includeModules: true

  warmup:
    enabled: true
    prewarm: true

  # 環境別設定
  stages:
    dev:
      memorySize: 256
      timeout: 30
      logLevel: debug
    prod:
      memorySize: 512
      timeout: 60
      logLevel: info

  # VPC設定
  vpc:
    securityGroupIds:
      - ${env:SECURITY_GROUP_ID}
    subnetIds:
      - ${env:SUBNET_ID_1}
      - ${env:SUBNET_ID_2}

provider:
  name: aws
  runtime: nodejs18.x
  region: ${env:AWS_REGION, 'us-east-1'}
  stage: ${opt:stage, 'dev'}
  memorySize: ${self:custom.stages.${self:provider.stage}.memorySize}
  timeout: ${self:custom.stages.${self:provider.stage}.timeout}

  # 環境変数
  environment:
    STAGE: ${self:provider.stage}
    LOG_LEVEL: ${self:custom.stages.${self:provider.stage}.logLevel}
    USERS_TABLE: ${self:service}-${self:provider.stage}-users
    ORDERS_TABLE: ${self:service}-${self:provider.stage}-orders

  # X-Ray トレーシング
  tracing:
    lambda: true
    apiGateway: true

  # API Gateway設定
  apiGateway:
    restApiId: ${env:API_GATEWAY_ID, ''}
    restApiRootResourceId: ${env:API_GATEWAY_ROOT_RESOURCE_ID, ''}
    minimumCompressionSize: 1024

  # ログ設定
  logs:
    restApi:
      level: INFO
      dataTrace: true

  # デッドレターキュー
  deadLetter:
    targetArn: ${env:DLQ_ARN}

functions:
  # ユーザー管理
  createUser:
    handler: src/handlers/users/create.handler
    events:
      - http:
          path: /users
          method: post
          cors: true
          authorizer:
            name: cognitoAuthorizer
            type: COGNITO_USER_POOLS
            arn: ${env:COGNITO_USER_POOL_ARN}
    iamRoleStatements:
      - Effect: Allow
        Action:
          - dynamodb:PutItem
        Resource:
          - Fn::GetAtt: [UsersTable, Arn]
    deadLetter:
      sqs: ${env:DLQ_ARN}

  getUser:
    handler: src/handlers/users/get.handler
    events:
      - http:
          path: /users/{id}
          method: get
          cors: true
          request:
            parameters:
              paths:
                id: true
    iamRoleStatements:
      - Effect: Allow
        Action:
          - dynamodb:GetItem
        Resource:
          - Fn::GetAtt: [UsersTable, Arn]

  # バッチ処理
  processOrders:
    handler: src/handlers/orders/process.handler
    events:
      - schedule: rate(5 minutes)
    reservedConcurrency: 5
    vpc: ${self:custom.vpc}
    iamRoleStatements:
      - Effect: Allow
        Action:
          - dynamodb:Scan
          - dynamodb:UpdateItem
        Resource:
          - Fn::GetAtt: [OrdersTable, Arn]

# 外部リソース設定の読み込み
resources:
  - ${file(serverless/resources/dynamodb.yml)}
  - ${file(serverless/resources/s3.yml)}
  - ${file(serverless/resources/iam.yml)}

# Outputs
outputs:
  RestApiId:
    Value:
      Ref: ApiGatewayRestApi
  RestApiRootResourceId:
    Value:
      Fn::GetAtt:
        - ApiGatewayRestApi
        - RootResourceId
```

### 3. プラグイン設定（package.json）

```json
{
  "name": "my-ecommerce-api",
  "scripts": {
    "dev": "serverless offline start",
    "deploy:dev": "serverless deploy --stage dev",
    "deploy:prod": "serverless deploy --stage prod",
    "test": "jest",
    "lint": "eslint src/",
    "logs": "serverless logs -f createUser -t"
  },
  "devDependencies": {
    "serverless": "^3.0.0",
    "serverless-webpack": "^5.11.0",
    "serverless-offline": "^12.0.0",
    "serverless-dotenv-plugin": "^6.0.0",
    "serverless-iam-roles-per-function": "^3.2.0",
    "serverless-plugin-warmup": "^8.0.0",
    "serverless-plugin-lambda-dead-letter": "^2.0.0",
    "webpack": "^5.0.0",
    "jest": "^29.0.0"
  }
}
```

### 4. Webpack 設定（webpack.config.js）

```javascript
const path = require("path");

module.exports = {
  entry: "./src/handlers",
  target: "node",
  mode: "production",
  externals: ["aws-sdk"],
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
          options: {
            presets: ["@babel/preset-env"],
          },
        },
      },
    ],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
};
```

## 環境別設定

### 1. 環境変数ファイル

```bash
# .env.dev
AWS_REGION=us-east-1
COGNITO_USER_POOL_ARN=arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_ABC123
DLQ_ARN=arn:aws:sqs:us-east-1:123456789012:my-service-dev-dlq
SECURITY_GROUP_ID=sg-12345678
SUBNET_ID_1=subnet-12345678
SUBNET_ID_2=subnet-87654321

# .env.prod
AWS_REGION=us-east-1
COGNITO_USER_POOL_ARN=arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_DEF456
DLQ_ARN=arn:aws:sqs:us-east-1:123456789012:my-service-prod-dlq
```

## デプロイ手順

### 1. 開発環境デプロイ

```bash
# 依存関係のインストール
npm install

# 開発環境デプロイ
npm run deploy:dev

# 特定の関数のみデプロイ
serverless deploy function -f createUser --stage dev
```

### 2. 本番環境デプロイ

```bash
# 本番環境デプロイ（承認付き）
npm run deploy:prod

# パッケージの確認
serverless package --stage prod
```

## ローカル開発

### オフライン実行

```bash
# API Gateway をローカルで起動
npm run dev

# 特定のポートで起動
serverless offline start --port 4000

# DynamoDB Local との連携
serverless dynamodb install
serverless dynamodb start
```

### テスト実行

```bash
# ユニットテスト
npm test

# 統合テスト
serverless invoke local -f createUser -p tests/events/create-user.json

# ログの確認
npm run logs
```

## 監視とデバッグ

### 1. X-Ray トレーシング

```javascript
// src/libs/tracer.js
const AWSXRay = require("aws-xray-sdk-core");
const AWS = AWSXRay.captureAWS(require("aws-sdk"));

module.exports = { AWS, AWSXRay };
```

### 2. 構造化ログ

```javascript
// src/libs/logger.js
const winston = require("winston");

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()],
});

module.exports = logger;
```

## CI/CD 統合

### GitHub Actions

````yaml
# .github/workflows/deploy.yml
name: Deploy Serverless App

on:
  push:
    branches: [main, develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        stage: [dev, prod]
        include:
          - stage: dev
            branch: develop
          - stage: prod
            branch: main

    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: us-east-1

      - name:# Serverless Framework Lambda Deploy

## 概要
最も人気の高いサードパーティサーバーレスフレームワーク

## 前提条件
- Node.js
- npm/yarn

## セットアップ

### 1. インストール
```bash
npm install -g serverless
````

### 2. プロジェクト作成

```bash
serverless create --template aws-nodejs --path my-service
cd my-service
```

### 3. プロジェクト構造

```project
my-service/
├── serverless.yml
├── handler.js
└── package.json
```

### 4. serverless.yml

```yaml
service: my-service

provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1
  memorySize: 256
  timeout: 30

functions:
  hello:
    handler: handler.hello
    events:
      - http:
          path: hello
          method: get

  process:
    handler: handler.process
    events:
      - s3:
          bucket: my-bucket
          event: s3:ObjectCreated:*
```

### 5. handler.js

```javascript
module.exports.hello = async (event) => {
  return {
    statusCode: 200,
    body: JSON.stringify({ message: "Hello World!" }),
  };
};
```

## デプロイ手順

### 1. 依存関係のインストール

```bash
npm install
```

### 2. デプロイ

```bash
serverless deploy
```

### 3. 単一関数のデプロイ

```bash
serverless deploy function -f hello
```

## 便利なコマンド

### 関数の呼び出し

```bash
serverless invoke -f hello
```

### ログの確認

```bash
serverless logs -f hello -t
```

### 削除

```bash
serverless remove
```

### プラグインの追加

```bash
serverless plugin install -n serverless-offline
```

## メリット・デメリット

**メリット**: 多クラウド対応、豊富なプラグイン、強力なコミュニティ  
**デメリット**: サードパーティ依存、設定が複雑になりがち
