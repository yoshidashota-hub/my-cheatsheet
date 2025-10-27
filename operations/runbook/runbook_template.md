# ランブック: [操作名]

> 最終更新: YYYY-MM-DD
> 作成者: @username
> レビュー者: @username1, @username2
> カテゴリ: [デプロイ / 障害対応 / メンテナンス / セキュリティ]

---

## 概要

<!-- この操作の目的と概要を1-2段落で説明 -->

**目的**: [この操作を実行する理由]

**影響範囲**: [この操作が影響するシステム・ユーザー]

**所要時間**: 約XX分

**実行頻度**: [定期 / 必要時 / 緊急時]

---

## 前提条件

### 必要な権限

- [ ] AWS Console へのアクセス（AdministratorAccess）
- [ ] Kubernetes クラスタへのアクセス（kubectl）
- [ ] データベースへの接続権限（DBA）
- [ ] VPN 接続

### 必要なツール

```bash
# ツールのバージョン確認
aws --version        # AWS CLI 2.x 以上
kubectl version      # kubectl 1.25 以上
psql --version       # PostgreSQL 14 以上
```

### 事前確認事項

- [ ] メンテナンスウィンドウ内である（営業時間外）
- [ ] 関係者への通知完了
- [ ] バックアップ取得済み
- [ ] ロールバックプラン準備済み

---

## 影響評価

| 項目 | 内容 |
|------|------|
| **サービス影響** | あり / なし / 部分的 |
| **ダウンタイム** | XX分（予想） |
| **影響ユーザー数** | XX,XXX ユーザー |
| **データ損失リスク** | 低 / 中 / 高 |
| **リスクレベル** | 低 / 中 / 高 / クリティカル |

---

## 手順

### フェーズ1: 準備

#### 1-1. バックアップ取得

```bash
# データベースバックアップ
pg_dump -h production-db.example.com -U admin -d myapp \
  -F c -f backup_$(date +%Y%m%d_%H%M%S).dump

# S3にアップロード
aws s3 cp backup_*.dump s3://my-backups/manual/
```

**期待される結果**:
```
backup_20251027_140000.dump
upload: ./backup_20251027_140000.dump to s3://my-backups/manual/backup_20251027_140000.dump
```

**確認**:
- [ ] バックアップファイルが作成された
- [ ] S3へのアップロードが成功した

#### 1-2. メンテナンスモードに移行

```bash
# ステータスページを更新
curl -X POST https://api.statuspage.io/v1/pages/xxx/incidents \
  -H "Authorization: OAuth YOUR_API_KEY" \
  -d '{
    "incident": {
      "name": "Scheduled Maintenance",
      "status": "investigating",
      "impact_override": "maintenance"
    }
  }'

# アプリケーションをメンテナンスモードに
kubectl set env deployment/api MAINTENANCE_MODE=true
```

**確認**:
- [ ] ステータスページが更新された
- [ ] アプリケーションがメンテナンスモードになった

---

### フェーズ2: 実行

#### 2-1. [具体的な操作手順]

```bash
# ここに実際のコマンドを記載

# 例: データベーススキーマ変更
psql -h production-db.example.com -U admin -d myapp <<EOF
BEGIN;

-- マイグレーション実行
ALTER TABLE users ADD COLUMN phone_number VARCHAR(20);
CREATE INDEX idx_users_phone ON users(phone_number);

-- 確認
\d users

COMMIT;
EOF
```

**期待される結果**:
```
ALTER TABLE
CREATE INDEX
                              Table "public.users"
    Column     |          Type          | Nullable | Default
---------------+------------------------+----------+---------
 id            | uuid                   | not null |
 email         | character varying(255) | not null |
 phone_number  | character varying(20)  |          |
```

**確認**:
- [ ] コマンドがエラーなく完了した
- [ ] 期待される結果が得られた

#### 2-2. [次の操作手順]

```bash
# 次のステップのコマンド
```

**確認**:
- [ ] [確認項目1]
- [ ] [確認項目2]

---

### フェーズ3: 検証

#### 3-1. 動作確認

```bash
# ヘルスチェック
curl https://api.example.com/health

# データ整合性確認
psql -h production-db.example.com -U admin -d myapp \
  -c "SELECT COUNT(*) FROM users WHERE phone_number IS NOT NULL;"
```

**期待される結果**:
```json
{
  "status": "ok",
  "database": "ok",
  "version": "2.0.0"
}
```

**確認**:
- [ ] ヘルスチェックが正常
- [ ] データ整合性に問題なし
- [ ] エラーログに異常なし

#### 3-2. パフォーマンス確認

```bash
# レスポンスタイム確認
for i in {1..10}; do
  curl -w "Time: %{time_total}s\n" -o /dev/null -s https://api.example.com/users
  sleep 1
done

# データベース負荷確認
psql -h production-db.example.com -U admin -d myapp \
  -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

**期待される結果**:
- レスポンスタイム: < 500ms
- アクティブクエリ: < 10

**確認**:
- [ ] レスポンスタイムが正常範囲内
- [ ] データベース負荷が正常範囲内

---

### フェーズ4: 終了処理

#### 4-1. メンテナンスモード解除

```bash
# アプリケーションを通常モードに戻す
kubectl set env deployment/api MAINTENANCE_MODE-

# Podが正常に起動するまで待機
kubectl rollout status deployment/api

# ステータスページを更新
curl -X PATCH https://api.statuspage.io/v1/pages/xxx/incidents/yyy \
  -H "Authorization: OAuth YOUR_API_KEY" \
  -d '{
    "incident": {
      "status": "resolved",
      "body": "Maintenance completed successfully."
    }
  }'
```

**確認**:
- [ ] すべてのPodが Running 状態
- [ ] ステータスページが正常に更新された

#### 4-2. 監視強化

```bash
# Grafana ダッシュボードを確認
open https://grafana.example.com/d/production-overview

# エラーログを監視（15分間）
kubectl logs -f -l app=api --tail=100 | grep -i error
```

**確認**:
- [ ] エラー率が正常範囲内（< 0.1%）
- [ ] レイテンシが正常範囲内（P95 < 500ms）
- [ ] エラーログに異常なし

#### 4-3. ドキュメント更新

```bash
# 作業ログを記録
cat >> /var/log/operations.log <<EOF
Date: $(date)
Operation: Database schema update
Performed by: $USER
Status: Success
Notes: Added phone_number column to users table
EOF
```

**確認**:
- [ ] 作業ログが記録された
- [ ] 変更管理システムに記録（Jira/GitHub Issue等）

---

## ロールバック手順

### いつロールバックするか

以下の場合は即座にロールバックを検討:
- エラー率が1%を超えた
- レスポンスタイムが通常の2倍を超えた
- データ整合性に問題が発見された
- ユーザーから大量の問い合わせ

### ロールバック手順

#### ステップ1: メンテナンスモードに戻す

```bash
kubectl set env deployment/api MAINTENANCE_MODE=true
```

#### ステップ2: 変更を元に戻す

```bash
# データベース変更のロールバック
psql -h production-db.example.com -U admin -d myapp <<EOF
BEGIN;

-- インデックス削除
DROP INDEX IF EXISTS idx_users_phone;

-- カラム削除
ALTER TABLE users DROP COLUMN IF EXISTS phone_number;

COMMIT;
EOF
```

#### ステップ3: 検証

```bash
# テーブル構造確認
psql -h production-db.example.com -U admin -d myapp -c "\d users"

# ヘルスチェック
curl https://api.example.com/health
```

#### ステップ4: 通常モードに戻す

```bash
kubectl set env deployment/api MAINTENANCE_MODE-
kubectl rollout status deployment/api
```

**ロールバック所要時間**: 約10分

---

## トラブルシューティング

### 問題1: データベース接続エラー

**症状**:
```
psql: error: connection to server at "production-db.example.com" failed: timeout
```

**原因**:
- ネットワーク問題
- データベースサーバーの高負荷
- セキュリティグループ設定

**対処法**:

```bash
# 1. ネットワーク疎通確認
ping production-db.example.com
telnet production-db.example.com 5432

# 2. セキュリティグループ確認
aws ec2 describe-security-groups --group-ids sg-12345678

# 3. RDS インスタンス状態確認
aws rds describe-db-instances --db-instance-identifier production-db
```

---

### 問題2: マイグレーション失敗

**症状**:
```
ERROR:  duplicate key value violates unique constraint "users_pkey"
```

**原因**:
- データ重複
- トランザクションの途中失敗

**対処法**:

```bash
# 1. トランザクション状態確認
psql -c "SELECT * FROM pg_stat_activity WHERE state = 'idle in transaction';"

# 2. 該当トランザクションをロールバック
psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction';"

# 3. データ整合性確認
psql -c "SELECT id, COUNT(*) FROM users GROUP BY id HAVING COUNT(*) > 1;"
```

---

### 問題3: Kubernetes Pod起動失敗

**症状**:
```
kubectl get pods
NAME              READY   STATUS             RESTARTS   AGE
api-xxx-yyy       0/1     CrashLoopBackOff   3          2m
```

**対処法**:

```bash
# 1. ログ確認
kubectl logs api-xxx-yyy
kubectl describe pod api-xxx-yyy

# 2. イベント確認
kubectl get events --sort-by='.lastTimestamp'

# 3. リソース確認
kubectl top pods

# 4. 必要に応じて再デプロイ
kubectl rollout restart deployment/api
```

---

## チェックリスト

### 実行前チェックリスト

- [ ] 前提条件をすべて満たしている
- [ ] バックアップを取得した
- [ ] 関係者に通知した
- [ ] ロールバックプランを準備した
- [ ] メンテナンスウィンドウ内である

### 実行中チェックリスト

- [ ] 各ステップの確認項目をクリアした
- [ ] エラーが発生していない
- [ ] 期待される結果が得られている

### 実行後チェックリスト

- [ ] 動作確認が完了した
- [ ] パフォーマンスが正常範囲内
- [ ] メンテナンスモードを解除した
- [ ] ステータスページを更新した
- [ ] 監視を強化した（最低30分）
- [ ] ドキュメントを更新した
- [ ] 作業ログを記録した

---

## 関連ドキュメント

### ダッシュボード・モニタリング
- [Grafana ダッシュボード](https://grafana.example.com/d/production)
- [CloudWatch ログ](https://console.aws.amazon.com/cloudwatch/logs)
- [Sentry エラートラッキング](https://sentry.io/myorg/myapp)

### 設定ファイル
- [Kubernetes Deployment](https://github.com/myorg/myapp/blob/main/k8s/deployment.yaml)
- [Database Schema](https://github.com/myorg/myapp/blob/main/prisma/schema.prisma)

### 関連ランブック
- [データベースマイグレーション](./database-migration.md)
- [ロールバック手順](./rollback-deployment.md)
- [緊急時対応](./emergency-response.md)

### 連絡先
- **オンコール**: PagerDuty rotation
- **エンジニアリングマネージャー**: @manager (Slack)
- **SREチーム**: #sre-team (Slack)
- **カスタマーサポート**: support@example.com

---

## 変更履歴

| 日付 | 変更者 | 変更内容 |
|------|--------|---------|
| 2025-10-27 | @alice | 初版作成 |
| 2025-10-28 | @bob | トラブルシューティングセクション追加 |
| 2025-10-29 | @charlie | ロールバック手順を詳細化 |

---

## 承認

- [ ] エンジニアリングマネージャー
- [ ] SRE Lead
- [ ] セキュリティチーム（セキュリティに影響する場合）

---

## テンプレート使用ガイド

### ランブック作成の基本原則

1. **明確性**: 誰が読んでも理解できる明確な手順
2. **再現性**: 誰が実行しても同じ結果が得られる
3. **完全性**: 前提条件から完了確認まですべてを含む
4. **保守性**: 定期的に見直し、常に最新の状態を保つ

### いつランブックを作成するか

- 定期的に実行する操作（月次メンテナンス等）
- 複雑な手順を伴う操作（データベースマイグレーション等）
- 緊急時の対応（障害復旧、ロールバック等）
- 引き継ぎが必要な操作

### ランブックの保管場所

- Git リポジトリで管理（バージョン管理）
- Wiki または Confluence で公開（検索性）
- オンコール担当者が容易にアクセス可能な場所

### 定期レビュー

- **四半期ごと**: すべてのランブックをレビュー
- **変更時**: システム変更後は即座に更新
- **インシデント後**: インシデント対応で使用したランブックを改善

---

## 関連ガイド

### 運用管理
- [インシデント対応ガイド](../incident/incident_response.md) - インシデント対応プロセス
- [デプロイ戦略ガイド](../deployment/deployment_strategies.md) - デプロイ手順
- [バックアップ・リカバリガイド](../backup/backup_recovery_guide.md) - バックアップ手順

### モニタリング
- [モニタリングガイド](../monitoring/monitoring_guide.md) - システム監視
- [アラート設計ガイド](../monitoring/alerting_guide.md) - アラート設定

### データベース
- [PostgreSQL ガイド](../../database/postgresql/postgresql_guide.md) - データベース操作
