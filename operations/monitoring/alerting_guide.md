# アラート設計ガイド

> 最終更新: 2025-10-27
> 難易度: 中級

## 概要

効果的なアラートは、重大な問題を迅速に検出し、適切な担当者に通知します。一方、不適切なアラート設計は「アラート疲れ」を引き起こし、本当に重要な問題を見逃す原因となります。

## アラート設計の基本原則

### 1. アクション可能であること

**良い例**:
```
アラート: API エラー率が5%を超えています
→ アクション: ログを確認し、エラー原因を特定して修正
```

**悪い例**:
```
アラート: ディスク使用率が70%です
→ アクション: まだ余裕があるので何もしない（不要なアラート）
```

### 2. 緊急性を反映する

**原則**: アラートを受け取った人が即座に対応する必要があるものだけをアラートにする

```yaml
# 良い例: 即座の対応が必要
- alert: ServiceDown
  expr: up{job="api"} == 0
  for: 1m
  labels:
    severity: critical

# 悪い例: 予防的な情報（チケットやレポートで十分）
- alert: DiskUsage70Percent
  expr: disk_usage > 70
  labels:
    severity: warning  # これは週次レポートで十分
```

### 3. 症状ベースでアラート

**症状ベース（推奨）**: ユーザーが体験する問題に基づく
```yaml
- alert: HighLatency
  expr: http_request_duration_seconds{quantile="0.95"} > 2
  for: 5m
```

**原因ベース（補足的）**: システムの内部状態に基づく
```yaml
- alert: HighCPU
  expr: cpu_usage > 90
  for: 10m
```

**ベストプラクティス**: 症状ベースを優先し、原因ベースは補助的に使用

---

## 重要度レベル

### Critical（緊急）

**定義**: 即座の対応が必要。サービスが停止しているか、データ損失の危険がある

**対応**: 24/7 オンコール対応、即座にページャー通知

**例**:
```yaml
groups:
  - name: critical-alerts
    rules:
      # サービス停止
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.instance }} has been down for more than 1 minute"
          runbook_url: "https://runbook.example.com/ServiceDown"

      # データベース接続不可
      - alert: DatabaseConnectionFailed
        expr: database_up == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Cannot connect to database"

      # エラー率が異常に高い
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          / sum(rate(http_requests_total[5m])) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Error rate exceeds 10%"
```

### Warning（警告）

**定義**: 注意が必要だが、即座の対応は不要。放置すると Critical になる可能性

**対応**: 営業時間内に確認、Slack/Email通知

**例**:
```yaml
  - name: warning-alerts
    rules:
      # レイテンシ上昇
      - alert: IncreasedLatency
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          ) > 1
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "P95 latency is above 1 second"

      # ディスク容量逼迫
      - alert: DiskSpaceRunningOut
        expr: |
          (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.15
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Disk space below 15%"
          description: "Filesystem {{ $labels.mountpoint }} has only {{ $value | humanizePercentage }} available"

      # メモリ使用率高
      - alert: HighMemoryUsage
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.85
        for: 10m
        labels:
          severity: warning
```

### Info（情報）

**定義**: 情報提供のみ。アクションは不要

**対応**: ダッシュボード表示、週次レポート

---

## アラート疲れ（Alert Fatigue）を防ぐ

### 問題: 頻繁すぎるアラート

**解決策1: `for` 句で短期的なスパイクを無視**
```yaml
# 悪い例: 一瞬のスパイクでアラート
- alert: HighCPU
  expr: cpu_usage > 80

# 良い例: 10分間継続した場合のみアラート
- alert: HighCPU
  expr: cpu_usage > 80
  for: 10m
```

**解決策2: 適切な閾値設定**
```yaml
# 悪い例: 閾値が低すぎて頻繁にアラート
- alert: SlowResponse
  expr: response_time > 0.5  # 500ms

# 良い例: SLO に基づく閾値
- alert: SlowResponse
  expr: response_time > 2  # 2秒（SLOの2倍）
  for: 15m
```

**解決策3: 集約とレート計算**
```yaml
# 悪い例: 個別のエラーごとにアラート
- alert: ErrorOccurred
  expr: error_count > 0

# 良い例: エラー率で判断
- alert: HighErrorRate
  expr: rate(error_count[5m]) > 0.05
  for: 10m
```

### 問題: 誤検知

**解決策: ホワイトリストとフィルタリング**
```yaml
# メンテナンス中はアラートを抑制
- alert: ServiceDown
  expr: up{job="api"} == 0 and on() maintenance_mode == 0
  for: 2m
```

**Alertmanager の抑制ルール**:
```yaml
# alertmanager.yml
inhibit_rules:
  # サービスダウン時は、他の全アラートを抑制
  - source_match:
      severity: 'critical'
      alertname: 'ServiceDown'
    target_match_re:
      severity: 'warning|info'
    equal: ['job']
```

---

## 通知チャネル設計

### Alertmanager 設定例

```yaml
# alertmanager.yml
route:
  receiver: 'default'
  group_by: ['alertname', 'cluster']
  group_wait: 10s        # 初回アラートを待つ時間
  group_interval: 10s    # グループ化された追加アラートの送信間隔
  repeat_interval: 12h   # 同じアラートの再送間隔

  routes:
    # Critical: PagerDuty + Slack
    - match:
        severity: critical
      receiver: pagerduty
      continue: true

    - match:
        severity: critical
      receiver: slack-critical

    # Warning: Slack のみ
    - match:
        severity: warning
      receiver: slack-warning

receivers:
  - name: 'default'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX'
        channel: '#alerts'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'

  - name: 'slack-critical'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX'
        channel: '#incidents'
        title: '🚨 CRITICAL ALERT'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Runbook:* {{ .Annotations.runbook_url }}
          {{ end }}

  - name: 'slack-warning'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX'
        channel: '#monitoring'
        title: '⚠️ Warning'
```

### 通知チャネルの使い分け

| 重要度 | チャネル | 対応時間 | グループ化 |
|--------|---------|---------|-----------|
| Critical | PagerDuty, Phone, Slack | 即座（24/7） | しない |
| Warning | Slack, Email | 営業時間内 | 10分単位 |
| Info | Dashboard, Report | なし | 日次/週次 |

---

## ランブック（Runbook）統合

### アラートにランブックURLを含める

```yaml
- alert: HighErrorRate
  expr: error_rate > 0.05
  annotations:
    summary: "Error rate is {{ $value | humanizePercentage }}"
    description: "Check application logs and recent deployments"
    runbook_url: "https://runbook.example.com/HighErrorRate"
    dashboard_url: "https://grafana.example.com/d/errors"
```

### ランブック構成例

```markdown
# High Error Rate - Runbook

## 症状
API のエラー率が5%を超えている

## 影響
ユーザーがサービスを正常に利用できない可能性

## 診断手順
1. Grafana ダッシュボードでエラーの内訳を確認
2. アプリケーションログで具体的なエラーメッセージを確認
3. 最近のデプロイを確認（直近30分以内）
4. データベース接続状態を確認

## 対処手順
### ケース1: 最近デプロイした場合
→ ロールバックを実施

### ケース2: データベース接続エラー
→ データベースの状態を確認、必要に応じて再起動

### ケース3: 外部API障害
→ フォールバック処理が動作しているか確認

## エスカレーション
15分以内に解決しない場合:
- Slack: @backend-team
- オンコール: [PagerDuty rotation]
```

---

## SLO ベースのアラート

### エラーバジェット方式

```yaml
# 月次エラーバジェット: 99.9% = 43.2分のダウンタイム許容
- alert: ErrorBudgetExhausted
  expr: |
    (
      1 - (
        sum(rate(http_requests_total{status!~"5.."}[30d]))
        / sum(rate(http_requests_total[30d]))
      )
    ) > 0.001
  labels:
    severity: critical
  annotations:
    summary: "Monthly error budget (99.9%) is exhausted"
    description: "Cannot deploy new features until next month"
```

### マルチウィンドウ方式

```yaml
# 短期（1時間）と長期（1日）の両方でエラー率をチェック
- alert: BurnRateHigh
  expr: |
    (
      sum(rate(http_requests_total{status=~"5.."}[1h]))
      / sum(rate(http_requests_total[1h]))
      > 0.01
    )
    and
    (
      sum(rate(http_requests_total{status=~"5.."}[1d]))
      / sum(rate(http_requests_total[1d]))
      > 0.005
    )
  labels:
    severity: warning
  annotations:
    summary: "Error budget burn rate is high"
```

---

## アラートレビュープロセス

### 定期レビュー（月次）

**レビュー項目**:
- [ ] 過去30日間に発火したアラート一覧
- [ ] 誤検知アラートの特定と修正
- [ ] 未対応アラートの分析
- [ ] 平均対応時間（MTTA: Mean Time To Acknowledge）
- [ ] 平均解決時間（MTTR: Mean Time To Resolve）

### アラートメトリクス

```promql
# アラート発火頻度
count(ALERTS{alertstate="firing"}) by (alertname)

# アラート継続時間
time() - ALERTS_FOR_STATE{alertstate="firing"}
```

---

## アラート設計チェックリスト

### 新規アラート作成時

- [ ] このアラートは即座のアクションを必要とするか？
- [ ] アラートのタイトルは症状を明確に示しているか？
- [ ] 適切な `for` 句で短期的なスパイクを除外しているか？
- [ ] 閾値は SLO に基づいているか？
- [ ] Runbook URL が含まれているか？
- [ ] 適切な重要度レベルが設定されているか？
- [ ] 通知チャネルは適切か？
- [ ] テスト環境で動作確認したか？

### アラート削除基準

- [ ] 過去3ヶ月間、一度も発火していない
- [ ] 発火しても誰もアクションを取らない
- [ ] 常に誤検知である
- [ ] 同じ問題を検出する別のアラートがある

---

## トラブルシューティング

### アラートが発火しない

```bash
# 1. Prometheus でルールが読み込まれているか確認
curl http://localhost:9090/api/v1/rules | jq

# 2. クエリが実際にデータを返すか確認
curl -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=up{job="api"} == 0'

# 3. Prometheus のログを確認
kubectl logs prometheus-0 | grep -i alert
```

### アラートが届かない

```bash
# 1. Alertmanager が稼働しているか確認
curl http://localhost:9093/api/v2/status

# 2. アラートが Alertmanager に届いているか確認
curl http://localhost:9093/api/v2/alerts

# 3. 抑制ルールで除外されていないか確認
curl http://localhost:9093/api/v2/silences
```

---

## ベストプラクティス

### 1. ノイズリダクション

```yaml
# 複数の条件を組み合わせて誤検知を減らす
- alert: PodCrashLooping
  expr: |
    rate(kube_pod_container_status_restarts_total[15m]) > 0
    and
    kube_pod_container_status_restarts_total > 3
  for: 5m
```

### 2. コンテキスト情報を含める

```yaml
annotations:
  summary: "Pod {{ $labels.pod }} is crash looping"
  description: |
    Pod {{ $labels.pod }} in namespace {{ $labels.namespace }}
    has restarted {{ $value }} times in the last 15 minutes.

    Current status: {{ $labels.phase }}
    Node: {{ $labels.node }}

    Check logs: kubectl logs -n {{ $labels.namespace }} {{ $labels.pod }}
```

### 3. アラートのバージョン管理

```bash
# Git でアラートルールを管理
git add prometheus/alerts/
git commit -m "feat: add high error rate alert"
git push

# CI/CD でテスト
promtool check rules prometheus/alerts/*.yml
```

---

## 関連ガイド

### モニタリング
- [モニタリングガイド](./monitoring_guide.md) - システム監視の基礎
- [Prometheus/Grafana ガイド](../../infra/observability/prometheus_grafana_guide.md) - メトリクス収集と可視化

### インシデント対応
- [インシデント対応ガイド](../incident/incident_response.md) - アラート受信後の対応手順
- [ランブックテンプレート](../runbook/runbook_template.md) - 対応手順の標準化

### デプロイ
- [デプロイ戦略ガイド](../deployment/deployment_strategies.md) - デプロイ時のアラート設計
