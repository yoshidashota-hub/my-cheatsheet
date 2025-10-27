# Infrastructure ガイド一覧

インフラストラクチャ・デプロイに関する技術ガイド集です。

## 📑 カテゴリ

### AWS サービス

#### コンピューティング
- [Lambda ガイド](./aws/lambda/lambda_guide.md) - AWS Lambda サーバーレス関数
  - [AWS CLI デプロイ](./aws/lambda/deploy/aws_cli_deploy.md)
  - [AWS SAM デプロイ](./aws/lambda/deploy/aws_sam_deploy.md)
  - [AWS CDK デプロイ](./aws/lambda/deploy/aws_cdk_deploy.md)
  - [Serverless Framework デプロイ](./aws/lambda/deploy/serverless_framework_deploy.md)
  - [Terraform デプロイ](./aws/lambda/deploy/terraform_deploy.md)
- [ECS Fargate ガイド](./aws/ecs/ecs_fargate_guide.md) - コンテナオーケストレーション

#### API・ゲートウェイ
- [API Gateway ガイド](./aws/api-gateway/api_gateway_guide.md) - APIゲートウェイの構築

#### ストレージ・CDN
- [S3 ガイド](./aws/s3/s3_guide.md) - オブジェクトストレージ
- [CloudFront ガイド](./aws/cdn/cloudfront_guide.md) - CDNサービス

#### メッセージング・イベント
- [SQS ガイド](./aws/sqs/sqs_guide.md) - メッセージキューサービス
- [SNS ガイド](./aws/sns/sns_guide.md) - 通知サービス
- [EventBridge ガイド](./aws/eventbridge/eventbridge_guide.md) - イベント駆動アーキテクチャ

#### ワークフロー
- [Step Functions ガイド](./aws/step-functions/step_functions_guide.md) - ステートマシン・ワークフロー

#### 監視・ログ
- [CloudWatch ガイド](./aws/cloudwatch/cloudwatch_guide.md) - モニタリング・ログサービス

#### フルスタック開発
- [Amplify ガイド](./aws/amplify/amplify_guide.md) - フルスタック開発プラットフォーム

### コンテナ・オーケストレーション
- [Docker ガイド](./docker/docker_guide.md) - コンテナ化技術
- [Kubernetes ガイド](./kubernetes/kubernetes_guide.md) - コンテナオーケストレーション

### Infrastructure as Code (IaC)
- [Terraform ガイド](./iac/terraform_guide.md) - インフラコード管理

### サーバーレス
- [Serverless Framework ガイド](./serverless/serverless_framework_guide.md) - サーバーレスアプリケーション開発

### エッジコンピューティング
- [Cloudflare Workers ガイド](./edge/cloudflare_workers_guide.md) - エッジサーバーレス

### デプロイ・ホスティング
- [Vercel/Netlify ガイド](./deploy/vercel_netlify_guide.md) - フロントエンドホスティング

### CI/CD
- [GitHub Actions ガイド](./ci-cd/github_actions_guide.md) - CI/CDパイプライン
- [Lambda デプロイワークフロー](./github/workflows/lambda_deploy.md) - GitHub ActionsでのLambdaデプロイ

### オブザーバビリティ
- [OpenTelemetry ガイド](./observability/opentelemetry_guide.md) - 分散トレーシング・メトリクス
- [Prometheus/Grafana ガイド](./observability/prometheus_grafana_guide.md) - メトリクス監視・可視化
- [ロギングガイド](./observability/logging_guide.md) - ログ管理ベストプラクティス

## 関連カテゴリ
- [Backend](../backend/) - バックエンド関連ガイド
- [Database](../database/) - データベース関連ガイド
- [Tools](../tools/) - 監視・テストツール
