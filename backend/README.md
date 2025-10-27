# Backend ガイド一覧

バックエンド開発に関する技術ガイド集です。

## 📑 カテゴリ

### API 設計・実装
- [tRPC ガイド](./api/trpc_guide.md) - TypeScript向け型安全なRPCフレームワーク
- [GraphQL ガイド](./api/graphql_guide.md) - GraphQL APIの設計と実装
- [REST API 設計ガイド](./api/rest_api_design_guide.md) - RESTful API設計のベストプラクティス

### バックエンドフレームワーク
- [Hono ガイド](./framework/hono_guide.md) - 軽量高速なWebフレームワーク
- [Fastify ガイド](./framework/fastify_guide.md) - Node.js向け高速Webフレームワーク
- [NestJS ガイド](./framework/nestjs_guide.md) - TypeScript向けエンタープライズフレームワーク

#### Ruby on Rails
- [Rails セットアップ](./framework/ruby/rails_setup.md)
- [Rails ルーティング](./framework/ruby/rails_routing.md)
- [Rails コントローラー](./framework/ruby/rails_controller.md)
- [Rails モデル](./framework/ruby/rails_model.md)
- [Rails ビュー](./framework/ruby/rails_view.md)
- [Rails マイグレーション](./framework/ruby/rails_migration.md)
- [Rails アソシエーション](./framework/ruby/rails_association.md)
- [Rails クエリ](./framework/ruby/rails_query.md)
- [Rails バリデーション](./framework/ruby/rails_validation.md)
- [Rails 認証](./framework/ruby/rails_auth.md)
- [Rails API](./framework/ruby/rails_api.md)
- [Rails テスト](./framework/ruby/rails_testing.md)

### ORM・データベース操作
- [Prisma ガイド](./orm/prisma_guide.md) - 次世代TypeScript ORM
- [Drizzle ガイド](./orm/drizzle_guide.md) - TypeScript向け軽量ORM

### バリデーション
- [Zod ガイド](./validation/zod_guide.md) - TypeScript向けスキーマバリデーション

### BaaS (Backend as a Service)
- [Supabase ガイド](./baas/supabase_guide.md) - オープンソースFirebase代替

### リアルタイム通信
- [WebSocket ガイド](./realtime/websocket_guide.md) - WebSocketを使ったリアルタイム通信
- [SSE ガイド](./realtime/sse_guide.md) - Server-Sent Eventsの実装
- [プッシュ通知ガイド](./realtime/push_notification_guide.md) - プッシュ通知の実装方法

### メッセージキュー
- [メッセージキューガイド](./queue/message_queue_guide.md) - BullMQ、SQS等のメッセージキュー実装

### 検索機能
- [Elasticsearch ガイド](./search/elasticsearch_guide.md) - Elasticsearchの使い方
- [全文検索ガイド](./search/fulltext_search_guide.md) - 全文検索の実装方法

### キャッシング
- [キャッシング戦略ガイド](./caching/caching_strategies_guide.md) - Redis等を使ったキャッシング戦略

### ロギング
- [Winston/Pino ガイド](./logging/winston_pino_guide.md) - Node.jsロギングライブラリ

### セキュリティ
- [CORS ガイド](./security/cors_guide.md) - Cross-Origin Resource Sharingの設定

### ファイル処理
- [ファイルアップロードガイド](./file-upload/file_upload_guide.md) - ファイルアップロード実装

### メール送信
- [メールサービスガイド](./email/email_service_guide.md) - SendGrid、SES等のメール送信サービス

### 決済・サブスクリプション
- [Stripe ガイド](./payment/stripe_guide.md) - Stripe決済の実装
- [サブスクリプション管理ガイド](./subscription/subscription_management_guide.md) - サブスクリプション機能の実装

## 関連カテゴリ
- [Database](../database/) - データベース関連ガイド
- [Auth](../auth/) - 認証・認可ガイド
- [Infrastructure](../infra/) - インフラ・デプロイガイド
