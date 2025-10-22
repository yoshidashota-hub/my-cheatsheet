# AWS SAM Lambda Deploy

## 概要

AWSが提供するサーバーレスアプリケーション開発フレームワーク。

## 前提条件

- AWS CLI
- SAM CLI (`pip install aws-sam-cli`)
- Docker (ローカルテスト用)

## 基本セットアップ

### template.yaml

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]

Globals:
  Function:
    Runtime: nodejs18.x
    Timeout: 30
    MemorySize: 256
    Environment:
      Variables:
        ENVIRONMENT: !Ref Environment

Resources:
  UserFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/handlers/
      Handler: user.handler
      Events:
        Api:
          Type: Api
          Properties:
            Path: /users/{proxy+}
            Method: ANY
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref UserTable

  UserTable:
    Type: AWS::Serverless::SimpleTable
    Properties:
      PrimaryKey:
        Name: userId
        Type: String
```

### samconfig.toml

```toml
version = 0.1

[dev.deploy.parameters]
stack_name = "my-lambda-app-dev"
s3_bucket = "my-deployment-bucket-dev"
parameter_overrides = "Environment=dev"

[prod.deploy.parameters]
stack_name = "my-lambda-app-prod"
s3_bucket = "my-deployment-bucket-prod"
parameter_overrides = "Environment=prod"
```

## デプロイ

```bash
# ビルド
sam build --use-container

# 開発環境デプロイ
sam deploy --config-env dev

# 本番環境デプロイ
sam deploy --config-env prod --confirm-changeset
```

## ローカル開発

```bash
# APIをローカルで起動
sam local start-api --port 3000

# 特定の関数をテスト
sam local invoke UserFunction -e events/api-event.json

# ログの確認
sam logs -n UserFunction --tail
```

## メリット・デメリット

**メリット**: AWSネイティブ、ローカルテスト可能、CloudFormationベース
**デメリット**: AWS特化、YAML設定が複雑
