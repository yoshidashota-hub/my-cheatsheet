# my-cheatsheet

This repository is a collection of personal cheatsheets for development and operations.
このリポジトリは、開発や運用でよく使うコマンドやコードスニペット、設定例をまとめたチートシート集です。

## 📑 目次

- [📚 ディレクトリ構造](#-ディレクトリ構造)
- [🗂️ カテゴリ一覧](#️-カテゴリ一覧)
- [🔗 よく使うガイドへのクイックリンク](#-よく使うガイドへのクイックリンク)
- [📖 使い方](#-使い方)
- [📝 運用方針](#-運用方針)

## 📚 ディレクトリ構造

```
my-cheatsheet/
├── ai/                  # AI・機械学習
├── architecture/        # アーキテクチャパターン
├── auth/                # 認証・認可
├── backend/             # バックエンド開発
├── database/            # データベース
├── front/               # フロントエンド開発
├── infra/               # インフラ・デプロイ
├── mobile/              # モバイル開発
├── operations/          # システム運用
├── performance/         # パフォーマンス最適化
├── security/            # セキュリティ
├── tools/               # 開発ツール
└── ui/                  # UIコンポーネント
```

## 🗂️ カテゴリ一覧

### [Backend](./backend/) - バックエンド開発

API 設計、フレームワーク、ORM、リアルタイム通信、メッセージキュー、検索、キャッシング、ファイル処理、スケジューリング等

**主要技術**: tRPC, GraphQL, REST API, Hono, Fastify, NestJS, Rails, Prisma, Drizzle, Zod, Supabase, WebRTC, QR コード, CSV 処理

### [Frontend](./front/) - フロントエンド開発

React、Vue、フレームワーク、状態管理、データフェッチング、ビルドツール、地図、国際化等

**主要技術**: Next.js, React Server Components, Svelte, Vue/Nuxt, TanStack Query/Router/Table, Zustand, Vite, Maps, i18n

### [Infrastructure](./infra/) - インフラ・デプロイ

AWS、コンテナ、IaC、サーバーレス、エッジ、CI/CD、オブザーバビリティ等

**主要技術**: AWS Lambda/ECS/S3/EventBridge/VPC/Route53/Secrets Manager, Docker, Kubernetes, Terraform, CloudFormation, Serverless Framework, GitHub Actions

### [Auth](./auth/) - 認証・認可

SSO、JWT、OAuth、認証サービス、モダン認証プラットフォーム等

**主要技術**: NextAuth.js, Passport.js, AWS Cognito, JWT, Clerk, Auth0, Supabase Auth, Firebase Auth

### [Database](./database/) - データベース

SQL、NoSQL、インメモリデータベース等

**主要技術**: PostgreSQL, MongoDB, DynamoDB, Firestore, Redis

### [UI](./ui/) - UI コンポーネント

CSS フレームワーク、UI ライブラリ、アニメーション等

**主要技術**: Tailwind CSS, shadcn/ui, Aceternity UI, MagicUI

### [Tools](./tools/) - 開発ツール

テスト、Lint、監視、ドキュメンテーション等

**主要技術**: Jest, Vitest, Testing Library, Playwright, ESLint/Prettier, Sentry

### [Security](./security/) - セキュリティ

Web セキュリティ、API セキュリティ等

**主要トピック**: XSS/CSRF 対策、API 保護、認証、レート制限

### [AI](./ai/) - AI・機械学習

LLM、RAG、ベクトル検索、ホットな AI サービス等

**主要技術**: OpenAI API, Claude, Gemini, LangChain, RAG, Vector Database (Pinecone, Qdrant), Vercel AI SDK, LlamaIndex

### [Architecture](./architecture/) - アーキテクチャパターン

設計パターン、アーキテクチャ手法等

**主要トピック**: クリーンアーキテクチャ, DDD, マイクロサービス, イベント駆動

### [Mobile](./mobile/) - モバイル開発

クロスプラットフォーム開発、モバイル特有機能等

**主要技術**: React Native, Expo, オフライン同期

### [Performance](./performance/) - パフォーマンス最適化

フロントエンド・バックエンドの最適化手法

**主要トピック**: React/Next.js 最適化, API パフォーマンス, データベースクエリ最適化

### [Operations](./operations/) - システム運用

デプロイ戦略、監視・アラート、インシデント対応、バックアップ・リカバリ等

**主要トピック**: デプロイメント戦略, 監視・アラート設定, インシデント対応, ポストモーテム, バックアップ/リカバリ, スケーリング, セキュリティ運用

## 🔗 よく使うガイドへのクイックリンク

### フロントエンド

- [Next.js App Router](./front/framework/nextjs/app_router_guide.md)
- [TanStack Query](./front/library/tanstack/tanstack_query.md)
- [shadcn/ui](./ui/components/shadcn_ui_guide.md)
- [Tailwind CSS](./ui/css/tailwind_guide.md)
- [Maps](./front/library/map_guide.md)
- [i18n](./front/library/i18n_guide.md)

### バックエンド

- [tRPC](./backend/api/trpc_guide.md)
- [Prisma](./backend/orm/prisma_guide.md)
- [Hono](./backend/framework/hono_guide.md)
- [Zod](./backend/validation/zod_guide.md)
- [WebRTC](./backend/realtime/webrtc_guide.md)
- [CSV 処理](./backend/file-processing/csv_guide.md)
- [QR コード](./backend/library/qrcode_guide.md)
- [スケジューリング](./backend/scheduling/scheduling_guide.md)

### インフラ

- [AWS Lambda](./infra/aws/lambda/lambda_guide.md)
- [AWS VPC](./infra/aws/vpc/vpc_guide.md)
- [AWS Route53](./infra/aws/route53/route53_guide.md)
- [AWS Secrets Manager](./infra/aws/secrets/secrets_management_guide.md)
- [Docker](./infra/docker/docker_guide.md)
- [Terraform](./infra/iac/terraform_guide.md)
- [CloudFormation](./infra/iac/cloudformation_guide.md)
- [GitHub Actions](./infra/ci-cd/github_actions_guide.md)

### 認証・AI

- [NextAuth.js](./auth/nextauth_guide.md)
- [Modern Auth Services](./auth/modern_auth_services_guide.md)
- [Hot AI Services](./ai/hot_ai_services_guide.md)

### データベース・テスト

- [PostgreSQL](./database/postgresql/postgresql_guide.md)
- [Redis](./database/redis/redis_guide.md)
- [Vitest](./tools/testing/vitest_guide.md)
- [Playwright](./tools/testing/playwright_guide.md)

### 運用

- [監視・アラート](./operations/monitoring/monitoring_guide.md)
- [デプロイ戦略](./operations/deployment/deployment_strategies.md)
- [インシデント対応](./operations/incident/incident_response.md)

## 📖 使い方

1. **カテゴリから探す**: 上記のカテゴリ一覧から該当する分野を選び、各カテゴリの README.md を参照
2. **技術名で探す**: リポジトリ内を検索、または各カテゴリの README.md から目的の技術を探す
3. **クイックリンク**: よく使う技術は上記のクイックリンクから直接アクセス

## 📝 運用方針

詳細な運用方針・ガイドライン追加方針は [CLAUDE.md](./CLAUDE.md) を参照してください。

### 新規ガイドの追加

新しいガイドを追加する際は [templates/](./templates/) のテンプレートを使用してください。

```bash
# 例: 新しいガイドを作成する
cp templates/guide_template.md backend/orm/new_guide.md
```

詳細な使い方は [templates/README.md](./templates/README.md) を参照してください。
