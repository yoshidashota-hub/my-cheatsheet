# GitHub Actions Lambda Deploy

## 概要

GitHub Actionsを使用してAWS Lambdaのデプロイを自動化するツール。zipファイルとコンテナイメージの両方に対応。

## 基本的な使用方法

```yaml
name: Deploy to AWS Lambda

on:
  push:
    branches: ["main"]

permissions:
  id-token: write # OIDC認証に必要
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: AWS認証情報の設定
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: us-east-1

      - name: Lambdaファンクションのデプロイ
        uses: aws-actions/aws-lambda-deploy@v1.1.0
        with:
          function-name: my-function-name
          code-artifacts-dir: my-code-artifacts-dir
          handler: index.handler
          runtime: nodejs22.x
```

## Zipデプロイ

必須パラメータ:

- `function-name`: Lambda関数名
- `code-artifacts-dir`: コード成果物ディレクトリのパス
- `handler`: 関数ハンドラーメソッド
- `runtime`: 関数ランタイム識別子

## コンテナイメージデプロイ

```yaml
- name: コンテナイメージでデプロイ
  uses: aws-actions/aws-lambda-deploy@v1.1.0
  with:
    function-name: my-function-name
    package-type: Image
    image-uri: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest
```

## S3経由のデプロイ

```yaml
- name: S3経由でデプロイ
  uses: aws-actions/aws-lambda-deploy@v1.1.0
  with:
    function-name: my-function-name
    code-artifacts-dir: my-code-artifacts-dir
    s3-bucket: my-s3-bucket
```

## ドライランモード

```yaml
- name: ドライランモードでデプロイ
  uses: aws-actions/aws-lambda-deploy@v1.1.0
  with:
    function-name: my-function-name
    code-artifacts-dir: my-code-artifacts-dir
    dry-run: true
```

## 必要な権限

最小限必要なIAM権限:

- `lambda:GetFunctionConfiguration`
- `lambda:CreateFunction`
- `lambda:UpdateFunctionCode`
- `lambda:UpdateFunctionConfiguration`
- `lambda:PublishVersion`
- `iam:PassRole`

コンテナイメージの場合は追加でECR権限も必要。

## 主要な利点

- **自動化**: GitHub Actionsワークフローに統合
- **柔軟性**: zipとコンテナイメージ両対応
- **セキュリティ**: OIDC認証対応
- **ドライラン**: 本番実行前にテスト可能

## 参考リンク

- GitHub Action: https://github.com/aws-actions/aws-lambda-deploy
