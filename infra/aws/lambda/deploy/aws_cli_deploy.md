# AWS CLI Lambda Deploy

## 概要

コマンドラインから直接 AWS Lambda をデプロイする最もシンプルな方法

## 前提条件

- AWS CLI がインストール済み
- AWS 認証情報が設定済み
- 適切な IAM 権限

## 実務レベルのセットアップ

### 1. 環境設定スクリプト

```bash
#!/bin/bash
# deploy.sh

# 環境変数の設定
export AWS_REGION=${AWS_REGION:-us-east-1}
export FUNCTION_NAME=${FUNCTION_NAME:-my-function}
export ENVIRONMENT=${ENVIRONMENT:-dev}

# 依存関係のインストール（Node.js例）
npm ci --production

# zipファイルの作成（除外ファイル指定）
zip -r function.zip . -x "*.git*" "node_modules/aws-sdk/*" "tests/*" "*.md"

# バージョンタグの追加
VERSION=$(git rev-parse --short HEAD)
```

### 2. 環境別デプロイ

```bash
# 開発環境
aws lambda update-function-code \
  --function-name "${FUNCTION_NAME}-dev" \
  --zip-file fileb://function.zip \
  --publish

# 本番環境（承認後）
aws lambda update-function-code \
  --function-name "${FUNCTION_NAME}-prod" \
  --zip-file fileb://function.zip \
  --publish

# エイリアスの更新
aws lambda update-alias \
  --function-name "${FUNCTION_NAME}-prod" \
  --name LIVE \
  --function-version $LATEST_VERSION
```

### 3. 本番レベルの設定更新

```bash
# VPC設定付きの設定更新
aws lambda update-function-configuration \
  --function-name $FUNCTION_NAME \
  --memory-size 512 \
  --timeout 300 \
  --environment Variables="{
    NODE_ENV=production,
    LOG_LEVEL=info,
    DB_HOST=$DB_HOST,
    REDIS_URL=$REDIS_URL
  }" \
  --vpc-config SubnetIds=$SUBNET_IDS,SecurityGroupIds=$SECURITY_GROUP_IDS \
  --dead-letter-config TargetArn=$DLQ_ARN \
  --tracing-config Mode=Active
```

### 4. ロールバック機能

```bash
# 前のバージョンへのロールバック
PREVIOUS_VERSION=$(aws lambda list-versions-by-function \
  --function-name $FUNCTION_NAME \
  --query 'Versions[-2].Version' --output text)

aws lambda update-alias \
  --function-name $FUNCTION_NAME \
  --name LIVE \
  --function-version $PREVIOUS_VERSION
```

## 監視とログ

### ログの確認

```bash
# リアルタイムログ
aws logs tail "/aws/lambda/$FUNCTION_NAME" --follow

# エラーログのフィルタリング
aws logs filter-log-events \
  --log-group-name "/aws/lambda/$FUNCTION_NAME" \
  --filter-pattern "ERROR"
```

### メトリクスの確認

```bash
# 関数のメトリクス取得
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=$FUNCTION_NAME \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

## CI/CD での使用例

### GitHub Actions 統合

```bash
# .github/scripts/deploy.sh
if [[ "$GITHUB_REF" == "refs/heads/main" ]]; then
  ENVIRONMENT="prod"
elif [[ "$GITHUB_REF" == "refs/heads/develop" ]]; then
  ENVIRONMENT="dev"
fi

aws lambda update-function-code \
  --function-name "${FUNCTION_NAME}-${ENVIRONMENT}" \
  --zip-file fileb://function.zip
```

## セキュリティベストプラクティス

### 1. 最小権限の原則

```bash
# 必要最小限の権限でロールを作成
aws iam create-role --role-name lambda-execution-role \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name lambda-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```

### 2. シークレット管理

```bash
# Secrets Managerから環境変数を取得
SECRET_VALUE=$(aws secretsmanager get-secret-value \
  --secret-id prod/myapp/database \
  --query SecretString --output text)

aws lambda update-function-configuration \
  --function-name $FUNCTION_NAME \
  --environment Variables="{DB_PASSWORD=$SECRET_VALUE}"
```

## メリット・デメリット

**メリット**: シンプル、学習コストが低い、スクリプト化可能  
**デメリット**: 手動実行、複雑な設定管理、状態管理なし、チーム協業が困難
