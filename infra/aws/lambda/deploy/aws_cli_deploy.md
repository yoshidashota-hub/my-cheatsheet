# AWS CLI Lambda Deploy

## 概要

AWS CLIを使用してLambdaを直接デプロイする最もシンプルな方法。

## 前提条件

- AWS CLI インストール済み
- AWS認証情報設定済み

## 基本的なデプロイ

```bash
# zipファイルの作成
zip -r function.zip . -x "*.git*" "node_modules/aws-sdk/*"

# コードの更新
aws lambda update-function-code \
  --function-name my-function \
  --zip-file fileb://function.zip \
  --publish

# 設定の更新
aws lambda update-function-configuration \
  --function-name my-function \
  --memory-size 512 \
  --timeout 60 \
  --environment Variables="{NODE_ENV=production,LOG_LEVEL=info}"
```

## ログとメトリクス

```bash
# ログの確認
aws logs tail "/aws/lambda/my-function" --follow

# エラーログのフィルタ
aws logs filter-log-events \
  --log-group-name "/aws/lambda/my-function" \
  --filter-pattern "ERROR"
```

## ロールバック

```bash
# 前のバージョンへのロールバック
PREVIOUS_VERSION=$(aws lambda list-versions-by-function \
  --function-name my-function \
  --query 'Versions[-2].Version' --output text)

aws lambda update-alias \
  --function-name my-function \
  --name LIVE \
  --function-version $PREVIOUS_VERSION
```

## メリット・デメリット

**メリット**: シンプル、学習コスト低、スクリプト化可能
**デメリット**: 手動実行、状態管理なし、複雑な設定管理が困難
