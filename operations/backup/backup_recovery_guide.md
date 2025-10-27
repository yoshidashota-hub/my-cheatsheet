# バックアップ・リカバリガイド

> 最終更新: 2025-10-27
> 難易度: 中級

## 概要

バックアップは災害やデータ損失からシステムを守る最後の砦です。適切なバックアップ戦略により、障害発生時に迅速にサービスを復旧できます。

**重要な原則**: バックアップを取得しているだけでは不十分です。定期的にリストア手順をテストし、実際に復旧できることを確認する必要があります。

---

## バックアップの重要指標

### RTO (Recovery Time Objective)

**定義**: 障害発生から復旧までに許容される最大時間

**例**:
- **クリティカルシステム**: RTO = 1時間
  → 1時間以内にサービスを復旧する必要がある

- **非クリティカルシステム**: RTO = 24時間
  → 翌営業日までの復旧で問題ない

### RPO (Recovery Point Objective)

**定義**: 許容できるデータ損失の最大時間

**例**:
- **金融システム**: RPO = 0分
  → データ損失は一切許容されない（リアルタイムレプリケーション必須）

- **分析システム**: RPO = 24時間
  → 1日分のデータ損失は許容可能

### RTO/RPO とバックアップ戦略の関係

| 要件 | RPO | RTO | バックアップ戦略 | コスト |
|------|-----|-----|----------------|--------|
| クリティカル | < 1時間 | < 1時間 | リアルタイムレプリケーション + 自動フェイルオーバー | 高 |
| 重要 | < 4時間 | < 4時間 | 1時間ごとのスナップショット + 自動リストア | 中 |
| 標準 | < 24時間 | < 24時間 | 日次フルバックアップ | 低 |
| 低優先度 | < 7日 | < 7日 | 週次フルバックアップ | 最低 |

---

## バックアップ方式

### 1. フルバックアップ

**定義**: すべてのデータを毎回バックアップ

**メリット**:
- リストアが最も簡単（1つのバックアップから完全復元）
- データの完全性が高い

**デメリット**:
- バックアップ時間が長い
- ストレージ容量を大量に消費
- ネットワーク帯域を占有

**実装例（PostgreSQL）**:

```bash
#!/bin/bash
# フルバックアップスクリプト

BACKUP_DIR="/backups/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="production"

# pg_dump でフルバックアップ
pg_dump -h localhost -U postgres -d $DB_NAME \
  | gzip > "$BACKUP_DIR/${DB_NAME}_full_${TIMESTAMP}.sql.gz"

# S3 にアップロード
aws s3 cp "$BACKUP_DIR/${DB_NAME}_full_${TIMESTAMP}.sql.gz" \
  "s3://my-backups/postgresql/full/"

# 古いバックアップを削除（30日以上前）
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +30 -delete
```

### 2. 増分バックアップ（Incremental）

**定義**: 前回のバックアップ以降に変更されたデータのみをバックアップ

**メリット**:
- バックアップ時間が短い
- ストレージ容量を節約

**デメリット**:
- リストアが複雑（フル + すべての増分が必要）
- 増分チェーンが長くなると復旧が遅い

**実装例（rsync）**:

```bash
#!/bin/bash
# 増分バックアップスクリプト

SOURCE_DIR="/var/www/app"
BACKUP_DIR="/backups/app"
CURRENT=$(date +%Y%m%d)
LATEST_LINK="$BACKUP_DIR/latest"

# 最新のバックアップからハードリンクで増分バックアップ
rsync -av --delete \
  --link-dest="$LATEST_LINK" \
  "$SOURCE_DIR/" \
  "$BACKUP_DIR/$CURRENT"

# latest シンボリックリンクを更新
rm -f "$LATEST_LINK"
ln -s "$BACKUP_DIR/$CURRENT" "$LATEST_LINK"
```

### 3. 差分バックアップ（Differential）

**定義**: 最後のフルバックアップ以降に変更されたデータをバックアップ

**メリット**:
- リストアが比較的簡単（フル + 最新の差分のみ）
- 増分よりもリストアが速い

**デメリット**:
- 時間経過とともにバックアップサイズが増加

**戦略例**:

```
日曜日: フルバックアップ
月曜日: 差分バックアップ（日曜からの変更）
火曜日: 差分バックアップ（日曜からの変更）
水曜日: 差分バックアップ（日曜からの変更）
木曜日: 差分バックアップ（日曜からの変更）
金曜日: 差分バックアップ（日曜からの変更）
土曜日: 差分バックアップ（日曜からの変更）
日曜日: フルバックアップ（新しいサイクル開始）
```

### 4. スナップショット

**定義**: ある時点のストレージの状態を記録

**メリット**:
- ほぼ瞬時に作成可能
- ストレージ効率が良い（差分のみを保存）
- ポイントインタイムリカバリが容易

**デメリット**:
- スナップショット元のストレージに依存
- 元のストレージ障害時は復旧不可

**実装例（AWS EBS）**:

```bash
#!/bin/bash
# EBS スナップショット作成

VOLUME_ID="vol-1234567890abcdef0"
DESCRIPTION="Daily backup $(date +%Y-%m-%d)"

# スナップショット作成
SNAPSHOT_ID=$(aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "$DESCRIPTION" \
  --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=DailyBackup}]" \
  --query 'SnapshotId' \
  --output text)

echo "Created snapshot: $SNAPSHOT_ID"

# 古いスナップショットを削除（30日以上前）
aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=volume-id,Values=$VOLUME_ID" \
  --query "Snapshots[?StartTime<='$(date -d '30 days ago' --iso-8601)'].SnapshotId" \
  --output text | xargs -n 1 aws ec2 delete-snapshot --snapshot-id
```

---

## バックアップスケジュール設計

### 3-2-1 ルール

バックアップのベストプラクティス:

- **3**: データのコピーを3つ保持
- **2**: 2種類の異なるメディアに保存
- **1**: 1つはオフサイト（別の場所）に保存

**実装例**:
```
コピー1: 本番データベース（プライマリ）
コピー2: 同一リージョンのS3（1つ目のメディア）
コピー3: 異なるリージョンのS3（2つ目のメディア、オフサイト）
```

### バックアップスケジュール例

**データベース（クリティカル）**:
```yaml
# 毎時: トランザクションログのバックアップ
0 * * * * /scripts/backup-wal.sh

# 毎日 2:00: 差分バックアップ
0 2 * * * /scripts/backup-differential.sh

# 毎週日曜 1:00: フルバックアップ
0 1 * * 0 /scripts/backup-full.sh
```

**ファイルシステム（標準）**:
```yaml
# 毎日 3:00: 増分バックアップ
0 3 * * * /scripts/backup-files-incremental.sh

# 毎月1日 4:00: フルバックアップ
0 4 1 * * /scripts/backup-files-full.sh
```

---

## データベースバックアップ

### PostgreSQL

**論理バックアップ（pg_dump）**:

```bash
#!/bin/bash
# 論理バックアップ（全体）

pg_dump -h localhost -U postgres -d mydb \
  -F c \ # カスタムフォーマット
  -b \   # ラージオブジェクトも含める
  -v \   # 詳細出力
  -f /backups/mydb_$(date +%Y%m%d).dump

# 特定のテーブルのみ
pg_dump -h localhost -U postgres -d mydb \
  -t users -t orders \
  -f /backups/mydb_users_orders.dump
```

**物理バックアップ（pg_basebackup）**:

```bash
#!/bin/bash
# 物理バックアップ（ベースバックアップ）

pg_basebackup -h localhost -U replication \
  -D /backups/base_$(date +%Y%m%d) \
  -F tar \  # tar形式
  -z \      # gzip圧縮
  -P \      # 進捗表示
  -X stream # WALも含める
```

**ポイントインタイムリカバリ（PITR）**:

```bash
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /wal_archive/%f && cp %p /wal_archive/%f'

# 継続的なWALアーカイブ
# recovery.conf（リストア時）
restore_command = 'cp /wal_archive/%f %p'
recovery_target_time = '2025-10-27 14:30:00'
```

### MySQL

**mysqldump**:

```bash
#!/bin/bash
# 論理バックアップ

mysqldump -u root -p \
  --single-transaction \  # トランザクション一貫性
  --routines \            # ストアドプロシージャも含める
  --triggers \            # トリガーも含める
  --all-databases | gzip > /backups/mysql_all_$(date +%Y%m%d).sql.gz

# 特定のデータベースのみ
mysqldump -u root -p \
  --single-transaction \
  mydb | gzip > /backups/mydb_$(date +%Y%m%d).sql.gz
```

**Percona XtraBackup（物理バックアップ）**:

```bash
#!/bin/bash
# ホットバックアップ（サービス停止不要）

xtrabackup --backup \
  --target-dir=/backups/xtra_$(date +%Y%m%d) \
  --user=root \
  --password=$MYSQL_PASSWORD

# 増分バックアップ
xtrabackup --backup \
  --target-dir=/backups/xtra_incremental_$(date +%Y%m%d) \
  --incremental-basedir=/backups/xtra_20251027 \
  --user=root \
  --password=$MYSQL_PASSWORD
```

---

## AWS バックアップサービス

### AWS Backup

**バックアッププラン作成**:

```json
{
  "BackupPlan": {
    "BackupPlanName": "DailyBackupPlan",
    "Rules": [
      {
        "RuleName": "DailyBackup",
        "TargetBackupVault": "Default",
        "ScheduleExpression": "cron(0 2 * * ? *)",
        "StartWindowMinutes": 60,
        "CompletionWindowMinutes": 120,
        "Lifecycle": {
          "DeleteAfterDays": 30,
          "MoveToColdStorageAfterDays": 7
        }
      },
      {
        "RuleName": "WeeklyBackup",
        "TargetBackupVault": "LongTerm",
        "ScheduleExpression": "cron(0 1 ? * SUN *)",
        "Lifecycle": {
          "DeleteAfterDays": 365
        }
      }
    ]
  }
}
```

**Terraform 例**:

```hcl
resource "aws_backup_plan" "example" {
  name = "daily-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.example.name
    schedule          = "cron(0 2 * * ? *)"

    lifecycle {
      delete_after = 30
      cold_storage_after = 7
    }
  }
}

resource "aws_backup_selection" "example" {
  name         = "backup_selection"
  plan_id      = aws_backup_plan.example.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [
    aws_db_instance.example.arn,
    aws_ebs_volume.example.arn
  ]
}
```

### RDS 自動バックアップ

```hcl
resource "aws_db_instance" "example" {
  identifier = "mydb"
  engine     = "postgres"

  # 自動バックアップ
  backup_retention_period = 7  # 7日間保持
  backup_window          = "03:00-04:00"  # UTC
  maintenance_window     = "mon:04:00-mon:05:00"

  # スナップショット
  final_snapshot_identifier = "mydb-final-snapshot"
  skip_final_snapshot      = false

  # PITR有効化
  enabled_cloudwatch_logs_exports = ["postgresql"]
}
```

---

## リカバリ手順

### データベースリストア

**PostgreSQL (pg_dump からのリストア)**:

```bash
#!/bin/bash
# リストア手順

# 1. データベース作成
createdb -U postgres restored_db

# 2. リストア実行
pg_restore -h localhost -U postgres \
  -d restored_db \
  -v \  # 詳細出力
  -j 4 \ # 並列度4
  /backups/mydb_20251027.dump

# 3. 検証
psql -U postgres -d restored_db -c "SELECT COUNT(*) FROM users;"
```

**PostgreSQL (PITR)**:

```bash
# 1. ベースバックアップをリストア
tar -xzf /backups/base_20251027.tar.gz -C /var/lib/postgresql/14/main

# 2. recovery.conf 作成
cat > /var/lib/postgresql/14/main/recovery.conf <<EOF
restore_command = 'cp /wal_archive/%f %p'
recovery_target_time = '2025-10-27 14:30:00 JST'
recovery_target_action = 'promote'
EOF

# 3. PostgreSQL 起動
systemctl start postgresql

# 4. 復旧確認
psql -c "SELECT pg_is_in_recovery();"  # false なら復旧完了
```

**MySQL (mysqldump からのリストア)**:

```bash
#!/bin/bash
# リストア手順

# 1. データベース作成
mysql -u root -p -e "CREATE DATABASE restored_db;"

# 2. リストア実行
gunzip < /backups/mydb_20251027.sql.gz | mysql -u root -p restored_db

# 3. 検証
mysql -u root -p restored_db -e "SELECT COUNT(*) FROM users;"
```

### EC2 インスタンスリストア

**AMI からのリストア**:

```bash
# 1. AMI から新しいインスタンスを起動
aws ec2 run-instances \
  --image-id ami-1234567890abcdef0 \
  --instance-type t3.medium \
  --key-name my-key \
  --security-group-ids sg-12345678 \
  --subnet-id subnet-12345678

# 2. Elastic IP を付け替え（必要に応じて）
aws ec2 associate-address \
  --instance-id i-new-instance \
  --allocation-id eipalloc-12345678
```

**EBS スナップショットからのリストア**:

```bash
# 1. スナップショットからボリューム作成
VOLUME_ID=$(aws ec2 create-volume \
  --snapshot-id snap-1234567890abcdef0 \
  --availability-zone ap-northeast-1a \
  --query 'VolumeId' \
  --output text)

# 2. インスタンスにアタッチ
aws ec2 attach-volume \
  --volume-id $VOLUME_ID \
  --instance-id i-1234567890abcdef0 \
  --device /dev/sdf

# 3. マウント
sudo mkfs -t ext4 /dev/sdf  # 新規の場合のみ
sudo mount /dev/sdf /mnt/restored
```

---

## ディザスタリカバリ（DR）

### DR 戦略

#### 1. バックアップ & リストア

**RTO**: 数時間〜数日
**RPO**: 数時間〜1日
**コスト**: 低

```
本番環境（東京リージョン）
    ↓ 定期バックアップ
S3（大阪リージョン）
    ↓ 災害時
手動でリストア
```

#### 2. パイロットライト

**RTO**: 数時間
**RPO**: 分〜数時間
**コスト**: 中

```
本番環境（東京リージョン）
    ↓ 継続的レプリケーション
DR環境（最小構成、大阪リージョン）
    ↓ 災害時
DR環境をスケールアップ
```

#### 3. ウォームスタンバイ

**RTO**: 分〜数時間
**RPO**: 秒〜分
**コスト**: 高

```
本番環境（東京リージョン）
    ↓ リアルタイムレプリケーション
DR環境（縮小版、大阪リージョン）
    ↓ 災害時
DR環境をフルスケールに
```

#### 4. マルチサイト（アクティブ-アクティブ）

**RTO**: 0（自動フェイルオーバー）
**RPO**: 0
**コスト**: 最高

```
本番環境A（東京リージョン）
         ↓↑ 双方向レプリケーション
本番環境B（大阪リージョン）

Route 53 で負荷分散
```

### DR 訓練（Fire Drill）

**目的**: DR 手順が実際に機能することを検証

**訓練シナリオ例**:

```markdown
## DR訓練シナリオ: データベース障害

### 前提条件
- 東京リージョンのRDSが完全に停止
- 大阪リージョンのリードレプリカは正常稼働

### 訓練手順
1. リードレプリカを昇格（Read Replica → Primary）
2. アプリケーションの接続先を変更
3. Route 53 DNSレコードを更新
4. サービス稼働確認
5. 所要時間を記録

### 成功基準
- RTO目標（1時間）以内に復旧
- データ損失なし（RPO = 0）
- すべての主要機能が正常動作

### 実施頻度
- 四半期ごと（3ヶ月に1回）
```

---

## バックアップ監視

### バックアップ成功/失敗の監視

**CloudWatch Alarms**:

```hcl
resource "aws_cloudwatch_metric_alarm" "backup_failed" {
  alarm_name          = "backup-job-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = "3600"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when backup job fails"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### バックアップ完全性チェック

**自動リストアテスト**:

```bash
#!/bin/bash
# バックアップの完全性を検証

BACKUP_FILE="/backups/mydb_20251027.dump"
TEST_DB="test_restore_$(date +%s)"

# 1. テストDBにリストア
createdb $TEST_DB
pg_restore -d $TEST_DB $BACKUP_FILE

# 2. データ検証
EXPECTED_COUNT=10000
ACTUAL_COUNT=$(psql -t -d $TEST_DB -c "SELECT COUNT(*) FROM users;")

if [ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]; then
  echo "✅ Backup verification successful"
  exit 0
else
  echo "❌ Backup verification failed. Expected: $EXPECTED_COUNT, Actual: $ACTUAL_COUNT"
  # Slack通知
  curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"Backup verification failed for $BACKUP_FILE\"}" \
    $SLACK_WEBHOOK_URL
  exit 1
fi

# 3. テストDBを削除
dropdb $TEST_DB
```

---

## ベストプラクティス

### 1. 暗号化

```bash
# バックアップ時に暗号化
pg_dump mydb | gpg --encrypt --recipient backup@example.com > mydb.dump.gpg

# リストア時に復号化
gpg --decrypt mydb.dump.gpg | psql restored_db
```

### 2. 保存期間ポリシー

| バックアップ種別 | 保存期間 | 理由 |
|---------------|---------|------|
| 日次バックアップ | 30日 | 月次の誤操作に対応 |
| 週次バックアップ | 3ヶ月 | 四半期レポート用 |
| 月次バックアップ | 7年 | 法的要件（会計法など） |

### 3. バックアップのテスト

```markdown
## 月次バックアップテストチェックリスト

- [ ] ランダムにバックアップを選択
- [ ] テスト環境にリストア
- [ ] データ完全性を検証
  - [ ] レコード数の確認
  - [ ] 主要テーブルのサンプルデータ確認
  - [ ] 外部キー制約の確認
- [ ] アプリケーションから接続テスト
- [ ] リストア所要時間を記録
- [ ] 結果をドキュメント化
```

---

## トラブルシューティング

### バックアップが失敗する

```bash
# 1. ディスク容量を確認
df -h /backups

# 2. 権限を確認
ls -la /backups

# 3. ログを確認
tail -f /var/log/backup.log

# 4. 手動でバックアップを試行
pg_dump -v -h localhost -d mydb -f /tmp/test.dump
```

### リストアが遅い

```bash
# 並列リストア（PostgreSQL）
pg_restore -j 8 -d mydb backup.dump  # 8並列

# インデックス作成を後回し
pg_restore -d mydb --section=pre-data backup.dump  # スキーマのみ
pg_restore -d mydb --section=data backup.dump       # データのみ
pg_restore -d mydb --section=post-data backup.dump  # インデックス・制約
```

---

## 関連ガイド

### インフラストラクチャ
- [AWS RDS ガイド](../../infra/aws/rds/rds_guide.md) - RDSのバックアップ設定
- [AWS S3 ガイド](../../infra/aws/s3/s3_guide.md) - バックアップストレージ
- [Terraform ガイド](../../infra/iac/terraform_guide.md) - バックアップのコード化

### データベース
- [PostgreSQL ガイド](../../database/postgresql/postgresql_guide.md) - PostgreSQLバックアップ詳細

### インシデント対応
- [インシデント対応ガイド](../incident/incident_response.md) - データ損失時の対応
- [ポストモーテムテンプレート](../incident/postmortem_template.md) - 障害分析

### モニタリング
- [モニタリングガイド](../monitoring/monitoring_guide.md) - バックアップ監視
- [アラート設計ガイド](../monitoring/alerting_guide.md) - バックアップ失敗アラート
