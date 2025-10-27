# インシデント対応ガイド

> 最終更新: 2025-10-27
> 難易度: 中級

## 概要

インシデントは予期せず発生します。効果的なインシデント対応により、サービスへの影響を最小化し、迅速に復旧できます。本ガイドでは、インシデント発生から解決、事後分析までのプロセスを解説します。

## インシデントとは

**定義**: サービスの正常な運用を妨げる、計画外の事象

**インシデントの例**:
- サービスダウン（完全停止）
- パフォーマンス低下（レスポンスタイムの大幅な増加）
- セキュリティ侵害
- データ損失
- 主要機能の障害

**インシデントではない**:
- 計画的なメンテナンス
- 機能リクエスト
- 軽微なバグ（サービス影響なし）

---

## 重要度レベル

### SEV-1（最高重要度）

**定義**: サービス全体または主要機能が完全に停止

**影響**:
- 全ユーザーが影響を受ける
- ビジネスクリティカルな機能が使用不可
- セキュリティ侵害
- データ損失

**対応**:
- 即座に対応（24/7）
- インシデントコマンダー招集
- 経営陣への報告
- 30分ごとのステータス更新

**例**:
```
- ウェブサイトが全く表示されない
- 決済システムが完全に停止
- データベースの完全障害
- 大規模なセキュリティ侵害
```

### SEV-2（高重要度）

**定義**: 主要機能の部分的な障害、または重大なパフォーマンス低下

**影響**:
- 多数のユーザーが影響を受ける
- 重要な機能が使用不可または著しく遅い
- ワークアラウンドは存在する

**対応**:
- 1時間以内に対応開始
- オンコールチームが対応
- 1時間ごとのステータス更新

**例**:
```
- ログイン機能が断続的に失敗
- API レスポンスが通常の10倍遅い
- 一部リージョンでサービス停止
- データベースのリードレプリカ障害
```

### SEV-3（中重要度）

**定義**: 軽微な機能障害、影響範囲が限定的

**影響**:
- 一部のユーザーが影響を受ける
- 副次的な機能が使用不可
- 回避策が容易に利用可能

**対応**:
- 営業時間内に対応
- 通常の開発プロセスで修正

**例**:
```
- 通知メールが遅延
- ダッシュボードの一部グラフが表示されない
- 非重要なエンドポイントでエラー
```

---

## インシデント対応フロー

### フェーズ1: 検知（Detection）

**アラート受信**:
```
1. PagerDuty / Slack でアラート受信
2. アラートの内容を確認
3. 重要度を判断（SEV-1/2/3）
4. ACK（確認応答）を送信
```

**初期評価**:
```bash
# クイックヘルスチェック
curl -i https://api.example.com/health

# エラーログ確認
kubectl logs -l app=api --tail=50 | grep ERROR

# メトリクス確認（Grafana ダッシュボード）
# - エラー率
# - レスポンスタイム
# - リクエスト数
```

### フェーズ2: 対応開始（Response）

**SEV-1/2 の場合: インシデント宣言**

1. **Slack インシデントチャンネル作成**
```
チャンネル名: #incident-2025-10-27-api-down
目的: インシデント対応の情報集約
```

2. **役割割り当て**

| 役割 | 責任 | 担当者 |
|------|------|--------|
| **Incident Commander (IC)** | 全体指揮、意思決定 | @john |
| **Communications Lead** | 内外へのステータス更新 | @sarah |
| **Technical Lead** | 技術的調査・修正 | @mike |

3. **ステータスページ更新**
```markdown
Status: Investigating
Message: "We are investigating reports of API errors. Updates to follow."
Updated: 2025-10-27 14:30 JST
```

### フェーズ3: 診断（Diagnosis）

**診断チェックリスト**:

```markdown
## インフラストラクチャ
- [ ] サーバー/コンテナは起動しているか？
- [ ] CPU/メモリ/ディスク使用率は正常か？
- [ ] ネットワーク接続は正常か？

## アプリケーション
- [ ] アプリケーションログにエラーはあるか？
- [ ] 最近のデプロイはあったか？
- [ ] 設定変更はあったか？

## データベース
- [ ] データベース接続は可能か？
- [ ] スロークエリはないか？
- [ ] レプリケーション遅延はないか？

## 外部依存
- [ ] 外部APIは正常か？
- [ ] CDNは正常か？
- [ ] DNSは正常か？
```

**診断コマンド例**:

```bash
# Kubernetes Pod 状態確認
kubectl get pods -n production
kubectl describe pod <pod-name>
kubectl logs <pod-name> --tail=100

# データベース接続確認
psql -h db.example.com -U appuser -c "SELECT 1"

# 外部API確認
curl -i https://api.external-service.com/status

# ネットワーク診断
nslookup api.example.com
traceroute api.example.com
```

### フェーズ4: 緩和・修正（Mitigation）

**優先順位**: サービス復旧 > 根本原因の特定

**緊急対処例**:

```bash
# 1. 即座のロールバック
kubectl rollout undo deployment/api

# 2. スケールアップ
kubectl scale deployment/api --replicas=10

# 3. トラフィック制御
# 問題のあるエンドポイントを一時的に無効化
kubectl apply -f disable-endpoint.yaml

# 4. フェイルオーバー
# プライマリからセカンダリDBへ切り替え
aws rds failover-db-cluster --db-cluster-identifier prod-cluster
```

**修正確認**:
```bash
# エラー率の推移を確認
# Prometheus クエリ
rate(http_requests_total{status=~"5.."}[5m])

# ヘルスチェック
for i in {1..10}; do curl -s https://api.example.com/health | jq .status; sleep 2; done
```

### フェーズ5: 復旧確認（Recovery）

**確認項目**:
- [ ] エラー率が正常範囲内（< 0.1%）
- [ ] レスポンスタイムが正常範囲内（P95 < 500ms）
- [ ] すべての主要機能が動作
- [ ] ユーザーからの報告が減少
- [ ] 監視アラートが解消

**ステータスページ更新**:
```markdown
Status: Resolved
Message: "The issue has been resolved. All systems are operational."
Updated: 2025-10-27 15:45 JST
```

### フェーズ6: 事後対応（Post-Incident）

**即座の対応**:
- [ ] インシデントチャンネルをアーカイブ
- [ ] タイムラインを記録
- [ ] ポストモーテム会議をスケジュール（24時間以内）

**ポストモーテム作成**（後述）

---

## コミュニケーションプロトコル

### 内部コミュニケーション

**Slack メッセージテンプレート**:

```markdown
🚨 **INCIDENT DECLARED** 🚨

**Severity**: SEV-1
**Title**: API Returning 500 Errors
**Impact**: All users unable to access the service
**Started**: 2025-10-27 14:23 JST

**Roles**:
- IC: @john
- Comms: @sarah
- Tech Lead: @mike

**Status**: Investigating

Updates will be posted in #incident-2025-10-27-api-down
```

**定期更新（SEV-1: 30分ごと、SEV-2: 1時間ごと）**:

```markdown
**UPDATE 15:00**

**Status**: Identified root cause - database connection pool exhausted
**Action**: Restarting application servers with increased pool size
**ETA**: 15分で復旧見込み
**Next update**: 15:30
```

### 外部コミュニケーション

**ステータスページ投稿例**:

```markdown
[Investigating] API Errors
Posted: Oct 27, 14:30 JST

We are currently investigating reports of users receiving error
messages when accessing our service. Our team is actively working
to identify and resolve the issue.

We will provide updates every 30 minutes until the issue is resolved.
```

**ユーザーへのメール通知**（解決後）:

```markdown
Subject: Service Disruption - Resolved

Dear Users,

On October 27, 2025, from 14:23 to 15:45 JST (1 hour 22 minutes),
some users experienced errors when accessing our service.

What happened:
A database connection pool exhaustion caused API requests to fail.

Impact:
Approximately 15% of API requests failed during this period.

Resolution:
We increased the database connection pool size and restarted the
affected servers.

Next steps:
We are conducting a thorough review to prevent similar issues in
the future.

We sincerely apologize for the inconvenience.
```

---

## オンコール運用

### オンコールローテーション

```
週次ローテーション（例）:

Week 1: Alice (Primary), Bob (Secondary)
Week 2: Bob (Primary), Charlie (Secondary)
Week 3: Charlie (Primary), Alice (Secondary)
```

**PagerDuty 設定例**:

```json
{
  "escalation_policy": {
    "name": "Production Support",
    "escalation_rules": [
      {
        "escalation_delay_in_minutes": 5,
        "targets": [
          { "type": "user", "id": "primary_oncall" }
        ]
      },
      {
        "escalation_delay_in_minutes": 15,
        "targets": [
          { "type": "user", "id": "secondary_oncall" }
        ]
      },
      {
        "escalation_delay_in_minutes": 30,
        "targets": [
          { "type": "user", "id": "engineering_manager" }
        ]
      }
    ]
  }
}
```

### オンコール心得

**やるべきこと**:
- ✅ アラートに15分以内に応答
- ✅ 対応開始前に ACK を送信
- ✅ 必要に応じてエスカレート
- ✅ 対応後にインシデントログを記録

**やってはいけないこと**:
- ❌ アラートを無視
- ❌ 一人で抱え込む
- ❌ 本番環境で未検証の修正を適用
- ❌ ドキュメント化せずに終了

### オンコール時の準備

```markdown
## オンコール開始前チェックリスト

- [ ] ノートPCが充電済み
- [ ] VPN 接続が可能
- [ ] 本番環境へのアクセス権限を確認
- [ ] PagerDuty アプリが正常に動作
- [ ] Slack 通知がON
- [ ] ランブックの場所を確認
- [ ] 前回のインシデントログをレビュー
```

---

## エスカレーション

### エスカレーション基準

| 条件 | エスカレーション先 | タイミング |
|------|------------------|-----------|
| 30分以内に診断できない | Secondary oncall | 即座 |
| 1時間以内に復旧できない | Engineering Manager | 即座 |
| SEV-1 が2時間継続 | CTO | 即座 |
| データ損失の可能性 | CTO + Legal | 即座 |
| セキュリティ侵害 | CISO + Security Team | 即座 |

### エスカレーション方法

```bash
# PagerDuty でエスカレート
pagerduty incident escalate <incident-id>

# Slack でメンション
@engineering-manager - Need help with SEV-1 incident.
Unable to identify root cause after 45 minutes of investigation.
```

---

## インシデントツール

### 必須ツール

1. **監視・アラート**
   - Prometheus / Grafana
   - PagerDuty / Opsgenie
   - Sentry

2. **コミュニケーション**
   - Slack
   - Zoom / Google Meet
   - ステータスページ（StatusPage.io, Atlassian Statuspage）

3. **インフラ管理**
   - kubectl (Kubernetes)
   - AWS CLI
   - Terraform

4. **ログ・トレーシング**
   - CloudWatch / Datadog
   - Jaeger / Zipkin

### Slack Bot 自動化例

```javascript
// インシデント開始時に自動でチャンネル作成
slack.on('incident_declared', async (incident) => {
  const channelName = `incident-${incident.date}-${incident.slug}`

  // チャンネル作成
  const channel = await slack.channels.create({
    name: channelName,
    is_private: false
  })

  // トピック設定
  await slack.channels.setTopic({
    channel: channel.id,
    topic: `SEV-${incident.severity}: ${incident.title} | IC: ${incident.commander}`
  })

  // ピン留めメッセージ
  await slack.chat.postMessage({
    channel: channel.id,
    text: generateIncidentTemplate(incident)
  })

  // 関連メンバーを招待
  await slack.channels.invite({
    channel: channel.id,
    users: incident.team_members
  })
})
```

---

## ベストプラクティス

### 1. ブレームレス文化（Blame-free Culture）

**原則**: 人を責めるのではなく、システムとプロセスを改善する

```
❌ 悪い例: 「誰がこのバグを本番にデプロイしたんだ？」
✅ 良い例: 「なぜこのバグがテストで検出されなかったのか？」
```

### 2. ドキュメント化

**記録すべき情報**:
- タイムライン（発生時刻、検知時刻、復旧時刻）
- 実行したコマンド
- 観察した現象
- 試した対処法（失敗したものも含む）

### 3. 定期的な訓練

```bash
# Chaos Engineering - 定期的な障害訓練
# 例: ランダムに Pod を削除
kubectl delete pod -l app=api --random

# Game Day - インシデント対応の模擬訓練
# シナリオ: データベース障害時の対応を訓練
```

### 4. ポストモーテムの徹底

すべての SEV-1/2 インシデントは必ずポストモーテムを実施

---

## インシデント対応チェックリスト

### 初動（最初の5分）

- [ ] アラートを確認・ACK
- [ ] 重要度を判断（SEV-1/2/3）
- [ ] 影響範囲を確認（何人のユーザーに影響？）
- [ ] 必要に応じてインシデント宣言

### 対応中

- [ ] 診断を開始（ログ、メトリクス確認）
- [ ] 定期的にステータス更新
- [ ] 試したことを記録
- [ ] 必要に応じてエスカレート

### 解決後

- [ ] 復旧を確認
- [ ] ステータスページを更新
- [ ] インシデントチャンネルをアーカイブ
- [ ] ポストモーテム会議をスケジュール（24時間以内）
- [ ] ポストモーテムドキュメントを作成（1週間以内）

---

## 関連ガイド

### モニタリング・アラート
- [モニタリングガイド](../monitoring/monitoring_guide.md) - システム監視の基礎
- [アラート設計ガイド](../monitoring/alerting_guide.md) - 効果的なアラート設計

### 事後分析
- [ポストモーテムテンプレート](./postmortem_template.md) - 事後分析のテンプレート

### 対応手順
- [ランブックテンプレート](../runbook/runbook_template.md) - 標準的な対応手順

### デプロイ
- [デプロイ戦略ガイド](../deployment/deployment_strategies.md) - ロールバック手順

### インフラ
- [Kubernetes ガイド](../../infra/kubernetes/kubernetes_guide.md) - コンテナオーケストレーション
- [AWS Lambda ガイド](../../infra/aws/lambda/lambda_guide.md) - サーバーレス環境の運用
