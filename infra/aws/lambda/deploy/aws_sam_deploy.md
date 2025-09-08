# AWS SAM Lambda Deploy

## 概要

AWS が提供するサーバーレスアプリケーション開発フレームワーク

## 前提条件

- AWS CLI
- SAM CLI (`pip install aws-sam-cli`)
- Docker（ローカルテスト用）

## 実務レベルのセットアップ

### 1. プロジェクト構造

```project
my-lambda/
├── template.yaml
├── samconfig.toml
├── src/
│   ├── handlers/
│   │   ├── user.js
│   │   └── order.js
│   ├── layers/
│   │   └── utils/
│   └── tests/
├── events/
│   ├── api-gateway-event.json
│   └── s3-event.json
└── .github/workflows/
    └── deploy.yml
```

### 2. 本番レベル template.yaml

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Transform: AWS::Serverless-2016-10-31

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]

Mappings:
  EnvironmentMap:
    dev:
      MemorySize: 256
      Timeout: 30
      LogLevel: debug
    prod:
      MemorySize: 512
      Timeout: 60
      LogLevel: info

Globals:
  Function:
    Runtime: nodejs18.x
    Timeout: !FindInMap [EnvironmentMap, !Ref Environment, Timeout]
    MemorySize: !FindInMap [EnvironmentMap, !Ref Environment, MemorySize]
    Environment:
      Variables:
        LOG_LEVEL: !FindInMap [EnvironmentMap, !Ref Environment, LogLevel]
        ENVIRONMENT: !Ref Environment
    Tracing: Active
    Tags:
      Environment: !Ref Environment
      Project: MyApp

Resources:
  # Shared Lambda Layer
  UtilsLayer:
    Type: AWS::Serverless::LayerVersion
    Properties:
      LayerName: !Sub "${AWS::StackName}-utils"
      ContentUri: src/layers/utils/
      CompatibleRuntimes:
        - nodejs18.x
      RetentionPolicy: Delete

  # API Gateway
  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: !Ref Environment
      Cors:
        AllowMethods: "'*'"
        AllowHeaders: "'*'"
        AllowOrigin: "'*'"
      Auth:
        DefaultAuthorizer: CognitoAuthorizer
        Authorizers:
          CognitoAuthorizer:
            UserPoolArn: !GetAtt UserPool.Arn

  # User Management Function
  UserFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/handlers/
      Handler: user.handler
      Layers:
        - !Ref UtilsLayer
      Environment:
        Variables:
          USER_TABLE: !Ref UserTable
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref UserTable
        - CloudWatchLogsFullAccess
      Events:
        Api:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /users/{proxy+}
            Method: ANY

  # DynamoDB Table
  UserTable:
    Type: AWS::Serverless::SimpleTable
    Properties:
      TableName: !Sub "${AWS::StackName}-users"
      PrimaryKey:
        Name: userId
        Type: String
      BillingMode: PAY_PER_REQUEST
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true

  # Dead Letter Queue
  DeadLetterQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${AWS::StackName}-dlq"
      MessageRetentionPeriod: 1209600 # 14 days

  # CloudWatch Alarms
  ErrorAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${AWS::StackName}-errors"
      ComparisonOperator: GreaterThanThreshold
      EvaluationPeriods: 2
      MetricName: Errors
      Namespace: AWS/Lambda
      Period: 300
      Statistic: Sum
      Threshold: 5
      Dimensions:
        - Name: FunctionName
          Value: !Ref UserFunction

Outputs:
  ApiUrl:
    Description: API Gateway URL
    Value: !Sub "https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/${Environment}/"
  UserTableName:
    Description: DynamoDB table name
    Value: !Ref UserTable
```

### 3. 環境別設定（samconfig.toml）

```toml
version = 0.1

[default]
[default.global.parameters]
stack_name = "my-lambda-app"

[default.build.parameters]
cached = true
parallel = true

[default.deploy.parameters]
capabilities = "CAPABILITY_IAM"
confirm_changeset = true
resolve_s3 = true
s3_prefix = "my-lambda-app"
region = "us-east-1"
image_repositories = []

[dev]
[dev.deploy.parameters]
stack_name = "my-lambda-app-dev"
s3_bucket = "my-deployment-bucket-dev"
parameter_overrides = "Environment=dev"

[prod]
[prod.deploy.parameters]
stack_name = "my-lambda-app-prod"
s3_bucket = "my-deployment-bucket-prod"
parameter_overrides = "Environment=prod"
```

## デプロイ手順

### 1. 依存関係とビルド

```bash
# 依存関係のインストール
cd src && npm ci --production && cd ..

# ビルド（レイヤー含む）
sam build --use-container

# テスト実行
npm test
```

### 2. 環境別デプロイ

```bash
# 開発環境
sam deploy --config-env dev

# 本番環境（承認付き）
sam deploy --config-env prod --confirm-changeset
```

### 3. パイプラインデプロイ

```bash
# GitHub Actions用のパイプライン生成
sam pipeline init --bootstrap
sam pipeline bootstrap
```

## ローカル開発とテスト

### API Gateway のローカル実行

```bash
# APIを localhost:3000 で起動
sam local start-api --port 3000 --env-vars env.json

# 特定の関数をテスト
sam local invoke UserFunction -e events/api-gateway-event.json
```

### 環境変数ファイル（env.json）

```json
{
  "UserFunction": {
    "LOG_LEVEL": "debug",
    "USER_TABLE": "users-dev",
    "ENVIRONMENT": "local"
  }
}
```

## 監視とデバッグ

### X-Ray トレーシング

```bash
# トレースの確認
sam logs -n UserFunction --start-time '10min ago' --tail

# X-Ray サービスマップの確認（AWSコンソール）
```

### パフォーマンス監視

```bash
# CloudWatch Insights でのログ分析
aws logs start-query \
  --log-group-name "/aws/lambda/my-lambda-app-prod-UserFunction" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/'
```

## セキュリティとベストプラクティス

### 1. IAM 最小権限

```yaml
# template.yamlでの権限設定
Policies:
  - DynamoDBCrudPolicy:
      TableName: !Ref UserTable
  - VPCAccessPolicy: {}
  - CloudWatchLogsFullAccess
  - Version: "2012-10-17"
    Statement:
      - Effect: Allow
        Action:
          - secretsmanager:GetSecretValue
        Resource: !Sub "arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:myapp/*"
```

### 2. シークレット管理

```yaml
# Secrets Manager統合
Environment:
  Variables:
    DB_PASSWORD: !Sub "{{resolve:secretsmanager:${AWS::StackName}/database:SecretString:password}}"
```

## CI/CD 統合

### GitHub Actions 例

```yaml
# .github/workflows/deploy.yml
name: Deploy SAM App
on:
  push:
    branches: [main, develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: aws-actions/setup-sam@v2
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: us-east-1

      - name: SAM build
        run: sam build --use-container

      - name: Deploy to dev
        if: github.ref == 'refs/heads/develop'
        run: sam deploy --config-env dev --no-confirm-changeset

      - name: Deploy to prod
        if: github.ref == 'refs/heads/main'
        run: sam deploy --config-env prod --no-confirm-changeset
```

## メリット・デメリット

**メリット**: AWS ネイティブ、ローカルテスト可能、CloudFormation ベース、豊富なイベントソース  
**デメリット**: AWS 特化、YAML 設定が複雑、学習コストが中程度
