# セキュリティ運用ガイド

> 最終更新: 2025-10-27
> 難易度: 中級〜上級

## 概要

セキュリティ運用（SecOps）は、システムとデータを継続的に保護するための活動です。攻撃者は常に進化しているため、セキュリティ対策も継続的に改善する必要があります。

**重要な原則**: セキュリティは一度設定して終わりではなく、継続的な監視・改善が必要です。

---

## セキュリティ運用の基本活動

### 1. 脆弱性管理（Vulnerability Management）

**目的**: システムの脆弱性を特定し、修正する

**プロセス**:
```
スキャン → 評価 → 優先順位付け → 修正 → 検証
```

#### 脆弱性スキャン

**自動スキャンツール**:

```yaml
# Trivy（コンテナイメージスキャン）
name: Security Scan
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Trivy scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
```

**依存関係スキャン**:

```bash
# npm audit（Node.js）
npm audit
npm audit fix  # 自動修正

# Snyk
snyk test
snyk monitor  # 継続的監視

# GitHub Dependabot
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

#### 脆弱性評価（CVSS スコア）

| スコア | 重要度 | 対応期限 | 例 |
|-------|-------|---------|-----|
| 9.0-10.0 | Critical | 24時間以内 | リモートコード実行 |
| 7.0-8.9 | High | 7日以内 | 認証バイパス |
| 4.0-6.9 | Medium | 30日以内 | XSS脆弱性 |
| 0.1-3.9 | Low | 90日以内 | 情報漏洩（軽微） |

---

### 2. パッチ管理（Patch Management）

**目的**: セキュリティパッチを迅速かつ安全に適用

#### パッチ適用プロセス

```markdown
## パッチ適用チェックリスト

### 計画フェーズ
- [ ] パッチ情報の収集（CVE, セキュリティアドバイザリ）
- [ ] 影響範囲の評価
- [ ] パッチ適用スケジュールの決定
- [ ] ロールバックプランの準備

### テストフェーズ
- [ ] ステージング環境でパッチ適用
- [ ] 機能テストの実施
- [ ] パフォーマンステストの実施
- [ ] 互換性確認

### 本番適用フェーズ
- [ ] メンテナンス通知（ユーザーへ）
- [ ] バックアップ取得
- [ ] パッチ適用
- [ ] 動作確認
- [ ] 監視強化（24時間）

### 事後フェーズ
- [ ] 適用結果の記録
- [ ] インベントリ更新
```

**自動パッチ適用（AWS Systems Manager）**:

```hcl
resource "aws_ssm_patch_baseline" "production" {
  name             = "production-patch-baseline"
  operating_system = "AMAZON_LINUX_2"

  approval_rule {
    approve_after_days = 7
    compliance_level   = "CRITICAL"

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Critical"]
    }

    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }
}

resource "aws_ssm_maintenance_window" "production" {
  name     = "production-maintenance-window"
  schedule = "cron(0 2 ? * SUN *)"  # 毎週日曜 2:00
  duration = 3
  cutoff   = 1
}
```

---

### 3. アクセス制御（Access Control）

#### 最小権限の原則（Principle of Least Privilege）

**IAM ポリシー例（AWS）**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket/uploads/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "203.0.113.0/24"
        }
      }
    }
  ]
}
```

#### アクセスレビュー

**四半期ごとのアクセス権レビュー**:

```bash
# AWS IAM ユーザーの最終アクセス時刻を確認
aws iam generate-credential-report
aws iam get-credential-report --output text | base64 -d > credential-report.csv

# 90日間アクセスのないユーザーを抽出
awk -F',' '$5 == "false" || ($5 != "N/A" && (systime() - mktime(substr($5,1,10)," 00:00:00")) > 90*86400)' \
  credential-report.csv
```

#### 多要素認証（MFA）の強制

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllExceptListedIfNoMFA",
      "Effect": "Deny",
      "NotAction": [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:ListMFADevices",
        "iam:ListUsers",
        "iam:GetUser"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

---

### 4. シークレット管理（Secrets Management）

#### シークレットのローテーション

**AWS Secrets Manager**:

```hcl
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "production/db/password"
  recovery_window_in_days = 7

  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret_rotation" "db_password" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

**アプリケーションでの使用**:

```typescript
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager"

async function getSecret(secretName: string): Promise<string> {
  const client = new SecretsManagerClient({ region: "ap-northeast-1" })

  try {
    const response = await client.send(
      new GetSecretValueCommand({ SecretId: secretName })
    )
    return response.SecretString!
  } catch (error) {
    console.error(`Failed to retrieve secret: ${secretName}`, error)
    throw error
  }
}

// 使用例
const dbPassword = await getSecret("production/db/password")
```

#### Git リポジトリのシークレットスキャン

```bash
# git-secrets（AWS）
git secrets --install
git secrets --register-aws

# gitleaks
gitleaks detect --source . --verbose

# GitHub Actions
name: Gitleaks
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
```

---

### 5. セキュリティ監視（Security Monitoring）

#### セキュリティログの収集

**重要なログソース**:

```markdown
## 監視すべきログ

### アプリケーション
- [ ] 認証試行（成功・失敗）
- [ ] 認可エラー
- [ ] 異常なAPI呼び出し
- [ ] エラー・例外

### インフラストラクチャ
- [ ] AWS CloudTrail（API操作）
- [ ] VPC Flow Logs（ネットワークトラフィック）
- [ ] AWS GuardDuty（脅威検知）
- [ ] OS ログ（/var/log/auth.log, /var/log/secure）

### データベース
- [ ] 認証失敗
- [ ] DDL操作（CREATE, ALTER, DROP）
- [ ] 大量データ抽出
- [ ] 管理者権限での操作
```

**CloudWatch Logs Insights クエリ例**:

```sql
-- 失敗した認証試行を検索
fields @timestamp, username, ip_address
| filter event_type = "login_failed"
| stats count() by username, ip_address
| sort count desc

-- 異常なAPI呼び出しパターン
fields @timestamp, user_id, endpoint, status_code
| filter status_code >= 400
| stats count() by user_id, endpoint
| filter count > 100
```

#### SIEM（Security Information and Event Management）

**Elastic Stack（ELK）設定例**:

```yaml
# filebeat.yml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/auth.log
      - /var/log/nginx/access.log
    fields:
      log_type: security

output.elasticsearch:
  hosts: ["localhost:9200"]

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
```

**セキュリティアラートルール例**:

```json
{
  "trigger": {
    "schedule": {
      "interval": "5m"
    }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["logs-*"],
        "body": {
          "query": {
            "bool": {
              "must": [
                { "match": { "event_type": "login_failed" } },
                { "range": { "@timestamp": { "gte": "now-5m" } } }
              ]
            }
          }
        }
      }
    }
  },
  "condition": {
    "compare": {
      "ctx.payload.hits.total": {
        "gte": 10
      }
    }
  },
  "actions": {
    "notify_slack": {
      "slack": {
        "message": {
          "text": "🚨 10+ failed login attempts detected in the last 5 minutes"
        }
      }
    }
  }
}
```

---

### 6. インシデント対応（Security Incident Response）

#### セキュリティインシデントの分類

| レベル | 定義 | 例 | 対応時間 |
|-------|------|-----|---------|
| P0 | データ侵害・システム侵害 | ランサムウェア、データ流出 | 即座（15分以内） |
| P1 | 重大な脆弱性の悪用 | 未パッチの脆弱性への攻撃 | 1時間以内 |
| P2 | 疑わしい活動 | 異常なログイン試行 | 4時間以内 |
| P3 | ポリシー違反 | 不適切なアクセス権設定 | 営業時間内 |

#### インシデント対応プレイブック

**疑わしい API アクセスの検知**:

```markdown
## プレイブック: 異常なAPIアクセス

### トリガー
- 短時間（5分）に100回以上のAPI呼び出し
- 通常と異なる地域からのアクセス
- 認証失敗後の成功

### 初期対応（15分以内）
1. [ ] アクセスログを確認
2. [ ] ユーザーアカウントの状態を確認
3. [ ] IP アドレスのレピュテーションをチェック（AbuseIPDB等）
4. [ ] 影響範囲の特定（どのデータにアクセスされたか）

### 封じ込め（30分以内）
1. [ ] 疑わしいユーザーセッションを無効化
2. [ ] 必要に応じてIPアドレスをブロック
3. [ ] アクセストークンを失効
4. [ ] データベースへのアクセスを一時的に制限

### 根絶（2時間以内）
1. [ ] 侵害されたアカウントのパスワードリセット
2. [ ] MFA を強制有効化
3. [ ] すべてのアクティブセッションを終了
4. [ ] API キーをローテーション

### 復旧（4時間以内）
1. [ ] 正常なアクセスパターンを確認
2. [ ] ユーザーに通知・パスワード変更を依頼
3. [ ] 監視を強化（24-48時間）

### 事後対応
1. [ ] インシデントレポート作成
2. [ ] 根本原因分析
3. [ ] 再発防止策の実施
```

#### 侵害されたアカウントの無効化

```bash
#!/bin/bash
# 緊急時のユーザーアカウント無効化スクリプト

USER_ID=$1
REASON=$2

# AWS IAM ユーザーを無効化
aws iam attach-user-policy \
  --user-name $USER_ID \
  --policy-arn arn:aws:iam::aws:policy/AWSDenyAll

# すべてのアクセスキーを無効化
aws iam list-access-keys --user-name $USER_ID \
  --query 'AccessKeyMetadata[].AccessKeyId' --output text | \
  xargs -I {} aws iam update-access-key \
    --user-name $USER_ID \
    --access-key-id {} \
    --status Inactive

# ログ記録
echo "$(date): User $USER_ID disabled. Reason: $REASON" >> /var/log/security-actions.log

# Slack 通知
curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"🚨 User account $USER_ID has been disabled. Reason: $REASON\"}" \
  $SLACK_WEBHOOK_URL
```

---

### 7. コンプライアンス（Compliance）

#### 主要なコンプライアンス基準

**PCI DSS（Payment Card Industry Data Security Standard）**:
- クレジットカード情報を扱う場合に必須
- 要件: 暗号化、アクセス制御、監視、定期テスト

**GDPR（General Data Protection Regulation）**:
- EU居住者の個人データを扱う場合に適用
- 要件: 同意取得、データ保護、削除権、72時間以内の侵害通知

**HIPAA（Health Insurance Portability and Accountability Act）**:
- 医療情報を扱う場合に適用
- 要件: 暗号化、アクセス制御、監査ログ

#### コンプライアンスチェック自動化

**AWS Config ルール例**:

```hcl
resource "aws_config_config_rule" "s3_bucket_encryption" {
  name = "s3-bucket-server-side-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "mfa_enabled" {
  name = "iam-user-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }
}

resource "aws_config_config_rule" "rds_encryption" {
  name = "rds-storage-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
}
```

---

### 8. セキュリティ監査（Security Audit）

#### 定期監査チェックリスト

**月次**:
- [ ] アクセス権レビュー（新規・変更・削除）
- [ ] 未使用のアカウント確認
- [ ] MFA 有効化状況確認
- [ ] パッチ適用状況確認
- [ ] セキュリティアラートのレビュー

**四半期**:
- [ ] 脆弱性スキャン実施
- [ ] ペネトレーションテスト実施
- [ ] セキュリティポリシーのレビュー
- [ ] インシデント対応訓練
- [ ] バックアップリストアテスト

**年次**:
- [ ] 外部セキュリティ監査
- [ ] ディザスタリカバリ訓練
- [ ] セキュリティ意識向上トレーニング
- [ ] セキュリティアーキテクチャレビュー

#### 監査ログの保存

```hcl
# CloudTrail で全 API 操作を記録
resource "aws_cloudtrail" "main" {
  name                          = "main-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/"]
    }
  }
}

# ログの改ざん防止（S3 Object Lock）
resource "aws_s3_bucket_object_lock_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 2555  # 7年間保持
    }
  }
}
```

---

## ベストプラクティス

### 1. Defense in Depth（多層防御）

```
┌─────────────────────────────────────┐
│ Layer 7: ユーザー教育               │
├─────────────────────────────────────┤
│ Layer 6: アプリケーションセキュリティ │
│         (WAF, 入力検証)              │
├─────────────────────────────────────┤
│ Layer 5: ネットワークセキュリティ     │
│         (Firewall, IDS/IPS)          │
├─────────────────────────────────────┤
│ Layer 4: ホストセキュリティ           │
│         (アンチウイルス, HIDS)        │
├─────────────────────────────────────┤
│ Layer 3: データ暗号化                │
│         (TLS, 暗号化ストレージ)       │
├─────────────────────────────────────┤
│ Layer 2: 認証・認可                  │
│         (MFA, RBAC)                  │
├─────────────────────────────────────┤
│ Layer 1: 物理セキュリティ             │
│         (データセンター)              │
└─────────────────────────────────────┘
```

### 2. ゼロトラスト原則

**基本方針**: 「決して信頼せず、常に検証する」

```typescript
// すべてのリクエストを検証
app.use(async (req, res, next) => {
  // 1. 認証チェック
  const token = req.headers.authorization?.split(' ')[1]
  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' })
  }

  // 2. トークン検証
  const user = await verifyToken(token)
  if (!user) {
    return res.status(401).json({ error: 'Invalid token' })
  }

  // 3. 認可チェック
  const hasPermission = await checkPermission(user, req.method, req.path)
  if (!hasPermission) {
    return res.status(403).json({ error: 'Forbidden' })
  }

  // 4. レート制限チェック
  const isRateLimited = await checkRateLimit(user.id, req.path)
  if (isRateLimited) {
    return res.status(429).json({ error: 'Too many requests' })
  }

  req.user = user
  next()
})
```

### 3. セキュリティ自動化

```yaml
# GitHub Actions - セキュリティチェック
name: Security Checks
on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      # 依存関係の脆弱性スキャン
      - name: npm audit
        run: npm audit --audit-level=high

      # コンテナイメージスキャン
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          severity: 'CRITICAL,HIGH'

      # シークレットスキャン
      - name: Gitleaks scan
        uses: gitleaks/gitleaks-action@v2

      # SAST（静的解析）
      - name: Semgrep scan
        uses: returntocorp/semgrep-action@v1
```

---

## トラブルシューティング

### 侵害の兆候を検知した場合

```bash
# 1. 緊急対応チームを招集
# 2. 影響範囲を特定

# 現在のアクティブセッションを確認
who
w
last

# 不審なプロセスを確認
ps aux | grep -v "^root"
netstat -tuln | grep ESTABLISHED

# 最近変更されたファイルを確認
find / -type f -mtime -1 -ls 2>/dev/null

# 3. ネットワーク隔離
# iptables で全トラフィックをブロック
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# SSH は管理者IPのみ許可
iptables -A INPUT -p tcp --dport 22 -s <管理者IP> -j ACCEPT

# 4. フォレンジック証拠の保全
# メモリダンプ取得
dd if=/dev/mem of=/mnt/external/memory.dump bs=1M

# ディスクイメージ取得
dd if=/dev/sda of=/mnt/external/disk.img bs=1M
```

---

## 関連ガイド

### セキュリティ対策
- [Web セキュリティガイド](../../security/web/web_security_guide.md) - Webアプリケーションのセキュリティ
- [API セキュリティガイド](../../security/api/api_security_guide.md) - API のセキュリティ対策

### 認証・認可
- [JWT ガイド](../../auth/jwt/jwt_guide.md) - JWTによる認証
- [NextAuth ガイド](../../auth/nextauth_guide.md) - Next.jsの認証

### インシデント対応
- [インシデント対応ガイド](../incident/incident_response.md) - インシデント対応プロセス
- [ポストモーテムテンプレート](../incident/postmortem_template.md) - 事後分析

### モニタリング
- [モニタリングガイド](../monitoring/monitoring_guide.md) - システム監視
- [アラート設計ガイド](../monitoring/alerting_guide.md) - セキュリティアラート

### インフラ
- [AWS IAM ガイド](../../infra/aws/iam/iam_guide.md) - アクセス制御
- [AWS Secrets Manager](../../infra/aws/secrets-manager/secrets_manager_guide.md) - シークレット管理
