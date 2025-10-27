# my-cheatsheet

This repository is a collection of personal cheatsheets for development and operations.
このリポジトリは、開発や運用でよく使うコマンドやコードスニペット、設定例をまとめたチートシート集です。

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
├── performance/         # パフォーマンス最適化
├── security/            # セキュリティ
├── tools/               # 開発ツール
└── ui/                  # UIコンポーネント
```

## 🗂️ カテゴリ一覧

### [Backend](./backend/) - バックエンド開発
API設計、フレームワーク、ORM、リアルタイム通信、メッセージキュー、検索、キャッシング等

**主要技術**: tRPC, GraphQL, REST API, Hono, Fastify, NestJS, Rails, Prisma, Drizzle, Zod, Supabase

### [Frontend](./front/) - フロントエンド開発
React、Vue、フレームワーク、状態管理、データフェッチング、ビルドツール等

**主要技術**: Next.js, React Server Components, Svelte, Vue/Nuxt, TanStack Query/Router/Table, Zustand, Vite

### [Infrastructure](./infra/) - インフラ・デプロイ
AWS、コンテナ、IaC、サーバーレス、エッジ、CI/CD、オブザーバビリティ等

**主要技術**: AWS Lambda/ECS/S3/EventBridge, Docker, Kubernetes, Terraform, Serverless Framework, GitHub Actions

### [Auth](./auth/) - 認証・認可
SSO、JWT、OAuth、認証サービス等

**主要技術**: NextAuth.js, Passport.js, AWS Cognito, JWT

### [Database](./database/) - データベース
SQL、NoSQL、インメモリデータベース等

**主要技術**: PostgreSQL, MongoDB, DynamoDB, Firestore, Redis

### [UI](./ui/) - UIコンポーネント
CSSフレームワーク、UIライブラリ、アニメーション等

**主要技術**: Tailwind CSS, shadcn/ui, Aceternity UI, MagicUI

### [Tools](./tools/) - 開発ツール
テスト、Lint、監視、ドキュメンテーション等

**主要技術**: Jest, Vitest, Testing Library, Playwright, ESLint/Prettier, Sentry

### [Security](./security/) - セキュリティ
Webセキュリティ、APIセキュリティ等

**主要トピック**: XSS/CSRF対策、API保護、認証、レート制限

### [AI](./ai/) - AI・機械学習
LLM、RAG、ベクトル検索等

**主要技術**: OpenAI API, LangChain, RAG, Vector Database (Pinecone, Qdrant)

### [Architecture](./architecture/) - アーキテクチャパターン
設計パターン、アーキテクチャ手法等

**主要トピック**: クリーンアーキテクチャ, DDD, マイクロサービス, イベント駆動

### [Mobile](./mobile/) - モバイル開発
クロスプラットフォーム開発、モバイル特有機能等

**主要技術**: React Native, Expo, オフライン同期

### [Performance](./performance/) - パフォーマンス最適化
フロントエンド・バックエンドの最適化手法

**主要トピック**: React/Next.js最適化, APIパフォーマンス, データベースクエリ最適化

## 🔗 よく使うガイドへのクイックリンク

### フロントエンド
- [Next.js App Router](./front/framework/nextjs/app_router_guide.md)
- [TanStack Query](./front/library/tanstack/tanstack_query.md)
- [shadcn/ui](./ui/components/shadcn_ui_guide.md)
- [Tailwind CSS](./ui/css/tailwind_guide.md)

### バックエンド
- [tRPC](./backend/api/trpc_guide.md)
- [Prisma](./backend/orm/prisma_guide.md)
- [Hono](./backend/framework/hono_guide.md)
- [Zod](./backend/validation/zod_guide.md)

### インフラ
- [AWS Lambda](./infra/aws/lambda/lambda_guide.md)
- [Docker](./infra/docker/docker_guide.md)
- [Terraform](./infra/iac/terraform_guide.md)
- [GitHub Actions](./infra/ci-cd/github_actions_guide.md)

### データベース・認証
- [PostgreSQL](./database/postgresql/postgresql_guide.md)
- [Redis](./database/redis/redis_guide.md)
- [NextAuth.js](./auth/nextauth_guide.md)

### テスト・ツール
- [Vitest](./tools/testing/vitest_guide.md)
- [Playwright](./tools/testing/playwright_guide.md)

## 📖 使い方

1. **カテゴリから探す**: 上記のカテゴリ一覧から該当する分野を選び、各カテゴリのREADME.mdを参照
2. **技術名で探す**: リポジトリ内を検索、または各カテゴリのREADME.mdから目的の技術を探す
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
