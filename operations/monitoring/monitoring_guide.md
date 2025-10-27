# モニタリングガイド

> 最終更新: 2025-10-27
> 難易度: 中級

## 概要

システム監視は、問題の早期発見と迅速な対応を可能にする重要な運用活動です。適切なモニタリングにより、ユーザーが問題に気づく前に対処できます。

## Four Golden Signals（4つの黄金シグナル）

Google SREが推奨する、システムの健全性を測る4つの重要な指標：

### 1. Latency（レイテンシ）

**定義**: リクエストの処理にかかる時間

**測定項目**:
- P50（中央値）: 50%のリクエストがこの時間以内に処理
- P95: 95%のリクエストがこの時間以内に処理
- P99: 99%のリクエストがこの時間以内に処理
- P99.9: 99.9%のリクエストがこの時間以内に処理

**実装例（Prometheus + Node.js）**:

```typescript
import promClient from 'prom-client'

// ヒストグラムメトリクス作成
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_ms',
  help: 'Duration of HTTP requests in ms',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [10, 50, 100, 200, 500, 1000, 2000, 5000], // ms
})

// ミドルウェア
app.use((req, res, next) => {
  const start = Date.now()

  res.on('finish', () => {
    const duration = Date.now() - start
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode.toString())
      .observe(duration)
  })

  next()
})
```

### 2. Traffic（トラフィック）

**定義**: システムへのリクエスト量

**測定項目**:
- Requests per second (RPS)
- Transactions per second (TPS)
- データ転送量（GB/s）

**実装例**:

```typescript
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
})

app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode.toString())
      .inc()
  })
  next()
})
```

### 3. Errors（エラー）

**定義**: 失敗したリクエストの割合

**測定項目**:
- エラー率（%）
- HTTP 5xx エラー数
- HTTP 4xx エラー数
- アプリケーションエラー数

**実装例**:

```typescript
const httpErrorsTotal = new promClient.Counter({
  name: 'http_errors_total',
  help: 'Total number of HTTP errors',
  labelNames: ['method', 'route', 'status_code', 'error_type'],
})

app.use((err, req, res, next) => {
  httpErrorsTotal
    .labels(
      req.method,
      req.route?.path || req.path,
      res.statusCode.toString(),
      err.name
    )
    .inc()

  next(err)
})
```

### 4. Saturation（飽和度）

**定義**: システムリソースの使用率

**測定項目**:
- CPU使用率（%）
- メモリ使用率（%）
- ディスクI/O
- ネットワーク帯域幅
- データベース接続プール使用率

**実装例**:

```typescript
import os from 'os'

// システムリソースメトリクス
setInterval(() => {
  const cpuUsage = process.cpuUsage()
  const memUsage = process.memoryUsage()

  cpuGauge.set(cpuUsage.user + cpuUsage.system)
  memoryGauge.set(memUsage.heapUsed)
}, 10000) // 10秒ごと
```

---

## USE Method（リソース監視）

**Utilization（使用率）**, **Saturation（飽和）**, **Errors（エラー）** の3つの観点でリソースを監視

### システムリソースの監視例

```yaml
# Prometheus設定例
scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'app'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/metrics'
```

### 主要メトリクス

**CPU**:
```promql
# CPU使用率
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# CPU飽和（ロードアベレージ）
node_load1 / count(node_cpu_seconds_total{mode="idle"}) by (instance)
```

**メモリ**:
```promql
# メモリ使用率
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# スワップ使用量
node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes
```

**ディスク**:
```promql
# ディスク使用率
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100

# ディスクI/O待ち時間
rate(node_disk_io_time_seconds_total[5m])
```

---

## ログ監視

### 構造化ログ

```typescript
import winston from 'winston'

const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
  ],
})

// 使用例
logger.info('User logged in', {
  userId: '123',
  ip: req.ip,
  userAgent: req.get('user-agent'),
})

logger.error('Payment failed', {
  userId: '123',
  orderId: 'ORD-456',
  amount: 1000,
  error: err.message,
  stack: err.stack,
})
```

### ログレベルの使い分け

| レベル | 用途 | 例 |
|--------|------|-----|
| FATAL | システムクラッシュ | データベース接続完全喪失 |
| ERROR | エラーだが継続可能 | 決済API呼び出し失敗 |
| WARN | 潜在的な問題 | API レート制限に接近 |
| INFO | 重要なイベント | ユーザーログイン、注文完了 |
| DEBUG | 開発時のデバッグ情報 | SQL クエリ、変数の値 |
| TRACE | 非常に詳細な情報 | 関数呼び出しトレース |

---

## APM（Application Performance Monitoring）

### 分散トレーシング（OpenTelemetry）

```typescript
import { trace, SpanStatusCode } from '@opentelemetry/api'
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node'

const provider = new NodeTracerProvider()
provider.register()

const tracer = trace.getTracer('my-app')

async function processOrder(orderId: string) {
  // スパン作成
  const span = tracer.startSpan('processOrder')
  span.setAttribute('order.id', orderId)

  try {
    // データベース操作
    const order = await db.getOrder(orderId)
    span.addEvent('order_fetched')

    // 決済処理
    const payment = await processPayment(order)
    span.addEvent('payment_processed')

    span.setStatus({ code: SpanStatusCode.OK })
  } catch (error) {
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    })
    throw error
  } finally {
    span.end()
  }
}
```

---

## ダッシュボード設計

### Grafana ダッシュボード例

```json
{
  "dashboard": {
    "title": "Application Overview",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m])) by (status_code)"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status_code=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100"
          }
        ]
      },
      {
        "title": "Response Time (P95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_ms_bucket[5m])) by (le))"
          }
        ]
      }
    ]
  }
}
```

---

## モニタリングのベストプラクティス

### 1. メトリクスの命名規則

```
# フォーマット: {namespace}_{subsystem}_{name}_{unit}
http_request_duration_seconds
database_query_count_total
cache_hit_rate_ratio
```

### 2. ラベルの使用

```typescript
// Good: 適切なカーディナリティ
httpRequests.labels('GET', '/api/users', '200').inc()

// Bad: 高カーディナリティ（ユーザーIDなど）
httpRequests.labels('GET', '/api/users', '200', 'user-12345').inc()
```

### 3. アラート閾値の設定

```yaml
# Prometheus アラートルール
groups:
  - name: application
    rules:
      # エラー率が5%を超えた場合
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status_code=~"5.."}[5m]))
          / sum(rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"

      # レスポンスタイムP95が2秒を超えた場合
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          ) > 2
        for: 10m
        labels:
          severity: warning
```

### 4. SLI/SLO/SLA

**SLI（Service Level Indicator）**: 測定可能な指標
```
可用性 = (成功リクエスト数 / 全リクエスト数) × 100%
```

**SLO（Service Level Objective）**: 目標値
```
可用性 99.9%（月間ダウンタイム43分以内）
レスポンスタイムP95 < 500ms
エラー率 < 0.1%
```

**SLA（Service Level Agreement）**: 契約上の保証
```
可用性 99.5%を下回った場合、利用料金の25%を返金
```

---

## モニタリングツール比較

| ツール | 用途 | メリット | デメリット |
|--------|------|----------|-----------|
| Prometheus + Grafana | メトリクス | オープンソース、柔軟 | 設定が複雑 |
| Datadog | 統合監視 | All-in-one、UI優秀 | 高コスト |
| New Relic | APM | 詳細なトレース | 高コスト |
| CloudWatch | AWS監視 | AWS統合 | AWS専用 |
| Sentry | エラー追跡 | エラー詳細 | エラー特化 |

---

## 関連ガイド

### 可観測性
- [Prometheus/Grafana ガイド](../../infra/observability/prometheus_grafana_guide.md) - メトリクス監視の実装
- [OpenTelemetry ガイド](../../infra/observability/opentelemetry_guide.md) - 分散トレーシング
- [ロギングガイド](../../infra/observability/logging_guide.md) - ログ管理

### アラート
- [アラート設計ガイド](./alerting_guide.md) - 効果的なアラート設計

### AWS
- [CloudWatch ガイド](../../infra/aws/cloudwatch/cloudwatch_guide.md) - AWS のモニタリング
