# 概要

**AWS Lambda Deploy GitHub Action**は、GitHub Actions ワークフローの一部として AWS Lambda ファンクションのデプロイを自動化するツールです。zip ファイルアーカイブと Amazon ECR に保存されたコンテナイメージの両方に対応しています。

## 基本的な使用方法

### 標準的なデプロイ設定

```yaml
name: Deploy to AWS Lambda

on:
  push:
    branches: ["main"]

permissions:
  id-token: write # OIDC認証に必要
  contents: read # リポジトリのチェックアウトに必要

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
          aws-region: ${{ env.AWS_REGION }}

      - name: Lambdaファンクションのデプロイ
        uses: aws-actions/aws-lambda-deploy@v1.1.0
        with:
          function-name: my-function-name
          code-artifacts-dir: my-code-artifacts-dir
          handler: index.handler
          runtime: nodejs22.x
```

## デプロイメント方法

### 1. Zip ファイルデプロイ（デフォルト）

必須パラメータ：

- `function-name`: Lambda ファンクション名
- `code-artifacts-dir`: コード成果物ディレクトリのパス
- `handler`: ファンクションハンドラーメソッド
- `runtime`: ファンクションランタイム識別子

### 2. コンテナイメージデプロイ

必須パラメータ：

- `function-name`: Lambda ファンクション名
- `package-type`: `Image`に設定
- `image-uri`: Amazon ECR のコンテナイメージ URI

## 特殊な機能

### S3 デプロイメント方法

zip ファイルデプロイ用の代替方法として、コード成果物を S3 に保存できます：

```yaml
- name: S3経由でLambdaファンクションをデプロイ
  uses: aws-actions/aws-lambda-deploy@v1.1.0
  with:
    function-name: my-function-name
    code-artifacts-dir: my-code-artifacts-dir
    s3-bucket: my-s3-bucket
```

### ドライランモード

実際の変更を行わずにパラメータと権限を検証：

```yaml
- name: ドライランモードでデプロイ
  uses: aws-actions/aws-lambda-deploy@v1.1.0
  with:
    function-name: my-function-name
    code-artifacts-dir: my-code-artifacts-dir
    dry-run: true
```

## 認証とセキュリティ

### OIDC 認証（推奨）

長期間有効な GitHub シークレットとして AWS 認証情報を保存する代わりに、OpenID Connect（OIDC）を使用することを強く推奨しています。

### 必要な権限

最小限必要な IAM 権限：

- `lambda:GetFunctionConfiguration`
- `lambda:CreateFunction`
- `lambda:UpdateFunctionCode`
- `lambda:UpdateFunctionConfiguration`
- `lambda:PublishVersion`
- `iam:PassRole`

コンテナイメージデプロイの場合は、追加で ECR 権限も必要です。

## 主要な利点

1. **自動化**: GitHub Actions ワークフローに統合して Lambda デプロイを自動化
2. **柔軟性**: zip ファイルとコンテナイメージの両方に対応
3. **設定管理**: ファンクションの設定も自動で更新
4. **安全性**: ドライランモードでテスト可能
5. **セキュリティ**: OIDC 認証対応で安全な認証

このアクションを使用することで、Lambda ファンクションのデプロイプロセスを大幅に簡素化し、CI/CD パイプラインに組み込むことができます。
