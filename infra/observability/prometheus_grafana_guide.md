# Prometheus & Grafana 完全ガイド

## 目次
1. [Prometheusとは](#prometheusとは)
2. [セットアップ](#セットアップ)
3. [メトリクス収集](#メトリクス収集)
4. [PromQL](#promql)
5. [アラート設定](#アラート設定)
6. [Grafanaダッシュボード](#grafanaダッシュボード)
7. [Node.js統合](#nodejs統合)
8. [ベストプラクティス](#ベストプラクティス)

---

## Prometheusとは

Prometheusは、時系列データベースを備えたオープンソースの監視システムです。

### 主な特徴

- **Pull型**: アプリケーションからメトリクスを取得
- **時系列データベース**: 高効率なデータ保存
- **PromQL**: 強力なクエリ言語
- **アラート**: Alertmanagerによるアラート管理

---

## セットアップ

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - '9090:9090'
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - '3001:3000'
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - prometheus

  alertmanager:
    image: prom/alertmanager:latest
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
    ports:
      - '9093:9093'

volumes:
  prometheus_data:
  grafana_data:
```

### Prometheus設定

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-app'
    static_configs:
      - targets: ['app:3000']
    metrics_path: '/metrics'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - 'alerts.yml'
```

---

## メトリクス収集

### prom-client

```bash
npm install prom-client
```

```typescript
import express from 'express';
import { register, collectDefaultMetrics, Counter, Histogram, Gauge } from 'prom-client';

const app = express();

// デフォルトメトリクスを収集
collectDefaultMetrics({ prefix: 'node_' });

// カスタムメトリクス
const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.5, 1, 2, 5],
});

const activeConnections = new Gauge({
  name: 'http_active_connections',
  help: 'Number of active HTTP connections',
});

// メトリクス収集ミドルウェア
app.use((req, res, next) => {
  const start = Date.now();
  activeConnections.inc();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;

    httpRequestsTotal.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode,
    });

    httpRequestDuration.observe(
      {
        method: req.method,
        route: req.route?.path || req.path,
        status: res.statusCode,
      },
      duration
    );

    activeConnections.dec();
  });

  next();
});

// メトリクスエンドポイント
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

### ビジネスメトリクス

```typescript
import { Counter, Histogram, Gauge } from 'prom-client';

// 注文メトリクス
const ordersTotal = new Counter({
  name: 'orders_total',
  help: 'Total number of orders',
  labelNames: ['status', 'country'],
});

const orderValue = new Histogram({
  name: 'order_value_dollars',
  help: 'Order value in dollars',
  labelNames: ['country'],
  buckets: [10, 50, 100, 500, 1000, 5000],
});

// ユーザーメトリクス
const activeUsers = new Gauge({
  name: 'active_users',
  help: 'Number of currently active users',
});

const userRegistrations = new Counter({
  name: 'user_registrations_total',
  help: 'Total number of user registrations',
  labelNames: ['source'],
});

// 使用例
async function createOrder(orderData: any) {
  const order = await db.orders.create({ data: orderData });

  ordersTotal.inc({
    status: 'created',
    country: orderData.country,
  });

  orderValue.observe(
    { country: orderData.country },
    orderData.amount
  );

  return order;
}

// 定期的にアクティブユーザー数を更新
setInterval(async () => {
  const count = await getActiveUserCount();
  activeUsers.set(count);
}, 60000);
```

---

## PromQL

### 基本的なクエリ

```promql
# リクエスト数
http_requests_total

# 特定のメソッドのリクエスト数
http_requests_total{method="GET"}

# 複数条件
http_requests_total{method="GET", status="200"}

# 正規表現
http_requests_total{route=~"/api/.*"}
```

### レート計算

```promql
# 1分間のリクエスト数
rate(http_requests_total[1m])

# 5分間の平均リクエスト数
rate(http_requests_total[5m])

# エラーレート
rate(http_requests_total{status=~"5.."}[5m])
  / rate(http_requests_total[5m])
```

### 集計関数

```promql
# 合計
sum(http_requests_total)

# ラベル別集計
sum by (method) (http_requests_total)

# 平均
avg(http_request_duration_seconds)

# パーセンタイル
histogram_quantile(0.95, http_request_duration_seconds_bucket)

# 最大値
max(http_active_connections)
```

### 便利なクエリ

```promql
# レスポンスタイム95パーセンタイル
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)

# エラー率
sum(rate(http_requests_total{status=~"5.."}[5m]))
  / sum(rate(http_requests_total[5m]))
  * 100

# リクエスト/秒
sum(rate(http_requests_total[1m]))

# メモリ使用率
process_resident_memory_bytes / 1024 / 1024
```

---

## アラート設定

### アラートルール

```yaml
# alerts.yml
groups:
  - name: api_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          / sum(rate(http_requests_total[5m]))
          > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: 'High error rate detected'
          description: 'Error rate is {{ $value | humanizePercentage }}'

      - alert: HighResponseTime
        expr: |
          histogram_quantile(0.95,
            rate(http_request_duration_seconds_bucket[5m])
          ) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: 'High response time'
          description: '95th percentile response time is {{ $value }}s'

      - alert: HighMemoryUsage
        expr: process_resident_memory_bytes / 1024 / 1024 > 512
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: 'High memory usage'
          description: 'Memory usage is {{ $value }}MB'

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: 'Service is down'
          description: 'Service {{ $labels.job }} is down'
```

### Alertmanager設定

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
      continue: true
    - match:
        severity: warning
      receiver: 'slack'

receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'

  - name: 'email'
    email_configs:
      - to: 'team@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alerts@example.com'
        auth_password: 'password'
```

---

## Grafanaダッシュボード

### データソース設定

```json
{
  "name": "Prometheus",
  "type": "prometheus",
  "access": "proxy",
  "url": "http://prometheus:9090",
  "isDefault": true
}
```

### ダッシュボード例（JSON）

```json
{
  "dashboard": {
    "title": "API Monitoring",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m]))"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Response Time (95th percentile)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Active Connections",
        "targets": [
          {
            "expr": "http_active_connections"
          }
        ],
        "type": "stat"
      }
    ]
  }
}
```

### よく使うパネル

```typescript
// リクエスト/秒
sum(rate(http_requests_total[1m]))

// エラー率（%）
sum(rate(http_requests_total{status=~"5.."}[5m]))
  / sum(rate(http_requests_total[5m]))
  * 100

// レスポンスタイム（パーセンタイル）
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m])) # P50
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) # P95
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) # P99

// メモリ使用量（MB）
process_resident_memory_bytes / 1024 / 1024

// CPU使用率
rate(process_cpu_seconds_total[5m]) * 100

// アクティブコネクション
http_active_connections
```

---

## Node.js統合

### Express統合

```typescript
import express from 'express';
import { register, collectDefaultMetrics, Counter, Histogram } from 'prom-client';

const app = express();

collectDefaultMetrics();

const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.5, 1, 2, 5],
});

app.use((req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path;

    httpRequestsTotal.inc({
      method: req.method,
      route,
      status: res.statusCode,
    });

    httpRequestDuration.observe(
      { method: req.method, route, status: res.statusCode },
      duration
    );
  });

  next();
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(3000);
```

### Prisma統合

```typescript
import { Counter, Histogram } from 'prom-client';
import { PrismaClient } from '@prisma/client';

const queryCounter = new Counter({
  name: 'db_queries_total',
  help: 'Total database queries',
  labelNames: ['model', 'action'],
});

const queryDuration = new Histogram({
  name: 'db_query_duration_seconds',
  help: 'Database query duration',
  labelNames: ['model', 'action'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1],
});

const prisma = new PrismaClient();

prisma.$use(async (params, next) => {
  const start = Date.now();

  const result = await next(params);

  const duration = (Date.now() - start) / 1000;

  queryCounter.inc({
    model: params.model || 'unknown',
    action: params.action,
  });

  queryDuration.observe(
    {
      model: params.model || 'unknown',
      action: params.action,
    },
    duration
  );

  return result;
});
```

---

## ベストプラクティス

### 1. メトリクス命名規則

```typescript
// 良い例
const http_requests_total = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
});

const http_request_duration_seconds = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
});

// 悪い例
const requests = new Counter({ name: 'requests' });
const time = new Histogram({ name: 'time' });
```

### 2. ラベルの使い方

```typescript
// 良い例: カーディナリティが低い
const requests = new Counter({
  name: 'http_requests_total',
  labelNames: ['method', 'status', 'route'],
});

// 悪い例: カーディナリティが高い（ユーザーIDなど）
const badRequests = new Counter({
  name: 'http_requests_total',
  labelNames: ['user_id'], // ❌ ユーザーIDは避ける
});
```

### 3. ヘルスチェック

```typescript
import { Counter } from 'prom-client';

const healthCheckCounter = new Counter({
  name: 'health_checks_total',
  help: 'Total health checks',
  labelNames: ['status'],
});

app.get('/health', async (req, res) => {
  try {
    // データベース接続チェック
    await prisma.$queryRaw`SELECT 1`;

    healthCheckCounter.inc({ status: 'success' });
    res.json({ status: 'ok' });
  } catch (error) {
    healthCheckCounter.inc({ status: 'failure' });
    res.status(500).json({ status: 'error' });
  }
});
```

### 4. レート制限メトリクス

```typescript
const rateLimitHits = new Counter({
  name: 'rate_limit_hits_total',
  help: 'Total rate limit hits',
  labelNames: ['endpoint'],
});

function rateLimitMiddleware(req: any, res: any, next: any) {
  const key = `${req.ip}:${req.path}`;
  const limit = 100;

  if (isRateLimited(key, limit)) {
    rateLimitHits.inc({ endpoint: req.path });
    return res.status(429).json({ error: 'Too many requests' });
  }

  next();
}
```

### 5. SLI/SLO監視

```typescript
// SLI: Service Level Indicator
const sliRequestsTotal = new Counter({
  name: 'sli_requests_total',
  help: 'Total SLI requests',
  labelNames: ['success'],
});

app.use((req, res, next) => {
  res.on('finish', () => {
    const success = res.statusCode < 500 && res.statusCode >= 200;
    sliRequestsTotal.inc({ success: success.toString() });
  });

  next();
});

// SLO: Service Level Objective
// PromQLクエリ:
// sum(rate(sli_requests_total{success="true"}[5m]))
//   / sum(rate(sli_requests_total[5m]))
//   > 0.99  # 99% の成功率
```

### 6. カスタムレジストリ

```typescript
import { Registry, Counter } from 'prom-client';

// カスタムレジストリを作成
const customRegistry = new Registry();

const customCounter = new Counter({
  name: 'custom_metric',
  help: 'Custom metric',
  registers: [customRegistry],
});

app.get('/custom-metrics', async (req, res) => {
  res.set('Content-Type', customRegistry.contentType);
  res.end(await customRegistry.metrics());
});
```

---

## 参考リンク

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [prom-client](https://github.com/siimon/prom-client)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
