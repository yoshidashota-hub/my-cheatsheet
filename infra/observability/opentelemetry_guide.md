# OpenTelemetry 完全ガイド

## 目次
1. [OpenTelemetryとは](#opentelemetryとは)
2. [セットアップ](#セットアップ)
3. [トレーシング](#トレーシング)
4. [メトリクス](#メトリクス)
5. [ログ](#ログ)
6. [コンテキスト伝播](#コンテキスト伝播)
7. [エクスポーター](#エクスポーター)
8. [ベストプラクティス](#ベストプラクティス)

---

## OpenTelemetryとは

OpenTelemetryは、分散システムの可観測性を実現するためのオープンソースの標準規格です。

### 3つの柱

- **トレース**: リクエストの流れを追跡
- **メトリクス**: システムの状態を数値化
- **ログ**: イベントの詳細記録

### 主な特徴

- **ベンダーニュートラル**: 特定のベンダーに依存しない
- **自動計装**: フレームワークの自動計装
- **コンテキスト伝播**: サービス間でコンテキストを伝播

---

## セットアップ

### インストール

```bash
npm install @opentelemetry/api
npm install @opentelemetry/sdk-node
npm install @opentelemetry/auto-instrumentations-node
npm install @opentelemetry/exporter-trace-otlp-http
npm install @opentelemetry/exporter-metrics-otlp-http
```

### 基本設定

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'my-service',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces',
  }),
  metricReader: new OTLPMetricExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/metrics',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown().finally(() => process.exit(0));
});
```

---

## トレーシング

### 手動スパン作成

```typescript
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service');

async function processOrder(orderId: string) {
  const span = tracer.startSpan('processOrder', {
    attributes: {
      'order.id': orderId,
    },
  });

  try {
    // ビジネスロジック
    await validateOrder(orderId);
    await chargePayment(orderId);
    await fulfillOrder(orderId);

    span.setStatus({ code: 1 }); // OK
    return { success: true };
  } catch (error) {
    span.recordException(error as Error);
    span.setStatus({
      code: 2, // ERROR
      message: (error as Error).message,
    });
    throw error;
  } finally {
    span.end();
  }
}

async function validateOrder(orderId: string) {
  return tracer.startActiveSpan('validateOrder', async (span) => {
    try {
      // バリデーションロジック
      const order = await db.orders.findUnique({
        where: { id: orderId },
      });

      span.setAttribute('order.valid', !!order);
      return order;
    } finally {
      span.end();
    }
  });
}
```

### Express統合

```typescript
import express from 'express';
import { trace, context } from '@opentelemetry/api';

const app = express();
const tracer = trace.getTracer('express-app');

app.get('/api/users/:id', async (req, res) => {
  const span = tracer.startSpan('GET /api/users/:id', {
    attributes: {
      'http.method': req.method,
      'http.url': req.url,
      'http.route': '/api/users/:id',
      'user.id': req.params.id,
    },
  });

  try {
    const user = await getUserById(req.params.id);

    span.setAttribute('http.status_code', 200);
    res.json(user);
  } catch (error) {
    span.recordException(error as Error);
    span.setAttribute('http.status_code', 500);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    span.end();
  }
});
```

### 子スパンの作成

```typescript
async function getUserWithDetails(userId: string) {
  return tracer.startActiveSpan('getUserWithDetails', async (parentSpan) => {
    parentSpan.setAttribute('user.id', userId);

    // 子スパン1: ユーザー情報取得
    const user = await tracer.startActiveSpan('getUser', async (span) => {
      const result = await db.users.findUnique({ where: { id: userId } });
      span.setAttribute('user.found', !!result);
      span.end();
      return result;
    });

    // 子スパン2: 注文履歴取得
    const orders = await tracer.startActiveSpan('getOrders', async (span) => {
      const result = await db.orders.findMany({ where: { userId } });
      span.setAttribute('orders.count', result.length);
      span.end();
      return result;
    });

    parentSpan.end();
    return { user, orders };
  });
}
```

---

## メトリクス

### カウンター

```typescript
import { metrics } from '@opentelemetry/api';

const meter = metrics.getMeter('my-service');

// リクエストカウンター
const requestCounter = meter.createCounter('http.requests', {
  description: 'Total HTTP requests',
});

app.use((req, res, next) => {
  requestCounter.add(1, {
    method: req.method,
    route: req.route?.path || req.path,
    status: res.statusCode,
  });
  next();
});
```

### ヒストグラム

```typescript
// レスポンスタイムヒストグラム
const responseTimeHistogram = meter.createHistogram('http.response_time', {
  description: 'HTTP response time in ms',
  unit: 'ms',
});

app.use((req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    responseTimeHistogram.record(duration, {
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode,
    });
  });

  next();
});
```

### ゲージ

```typescript
// アクティブ接続数
const activeConnections = meter.createObservableGauge('http.active_connections', {
  description: 'Number of active HTTP connections',
});

let connectionCount = 0;

activeConnections.addCallback((result) => {
  result.observe(connectionCount);
});

app.use((req, res, next) => {
  connectionCount++;
  res.on('finish', () => {
    connectionCount--;
  });
  next();
});
```

### カスタムメトリクス

```typescript
// ビジネスメトリクス
const ordersCounter = meter.createCounter('orders.created', {
  description: 'Total orders created',
});

const orderValueHistogram = meter.createHistogram('orders.value', {
  description: 'Order value distribution',
  unit: 'USD',
});

async function createOrder(orderData: any) {
  const order = await db.orders.create({ data: orderData });

  ordersCounter.add(1, {
    country: orderData.country,
    payment_method: orderData.paymentMethod,
  });

  orderValueHistogram.record(orderData.amount, {
    currency: orderData.currency,
  });

  return order;
}
```

---

## ログ

### ログとトレースの統合

```typescript
import winston from 'winston';
import { trace, context } from '@opentelemetry/api';

const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()],
});

// トレースIDをログに追加
function log(level: string, message: string, meta?: any) {
  const span = trace.getActiveSpan();
  const spanContext = span?.spanContext();

  logger.log(level, message, {
    ...meta,
    traceId: spanContext?.traceId,
    spanId: spanContext?.spanId,
  });
}

// 使用例
app.get('/api/users/:id', async (req, res) => {
  return tracer.startActiveSpan('GET /api/users/:id', async (span) => {
    log('info', 'Fetching user', { userId: req.params.id });

    try {
      const user = await getUserById(req.params.id);
      log('info', 'User fetched successfully', { userId: user.id });
      res.json(user);
    } catch (error) {
      log('error', 'Failed to fetch user', { error: (error as Error).message });
      res.status(500).json({ error: 'Internal server error' });
    } finally {
      span.end();
    }
  });
});
```

---

## コンテキスト伝播

### HTTP ヘッダーでの伝播

```typescript
import { propagation, trace, context as otelContext } from '@opentelemetry/api';

// クライアント側: ヘッダーに注入
async function callExternalAPI(url: string) {
  const headers: Record<string, string> = {};

  // 現在のコンテキストをヘッダーに注入
  propagation.inject(otelContext.active(), headers);

  const response = await fetch(url, { headers });
  return response.json();
}

// サーバー側: ヘッダーから抽出
app.use((req, res, next) => {
  // ヘッダーからコンテキストを抽出
  const extractedContext = propagation.extract(otelContext.active(), req.headers);

  // 抽出したコンテキストをアクティブに設定
  otelContext.with(extractedContext, () => {
    next();
  });
});
```

### マイクロサービス間の伝播

```typescript
// Service A
async function callServiceB() {
  return tracer.startActiveSpan('call-service-b', async (span) => {
    const headers: Record<string, string> = {};
    propagation.inject(otelContext.active(), headers);

    const response = await fetch('http://service-b/api/data', {
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    });

    span.setAttribute('service.response_status', response.status);
    span.end();

    return response.json();
  });
}

// Service B
app.use((req, res, next) => {
  const extractedContext = propagation.extract(otelContext.active(), req.headers);

  otelContext.with(extractedContext, () => {
    tracer.startActiveSpan('service-b-handler', (span) => {
      span.setAttribute('service.name', 'service-b');
      res.on('finish', () => span.end());
      next();
    });
  });
});
```

---

## エクスポーター

### Jaeger

```bash
npm install @opentelemetry/exporter-jaeger
```

```typescript
import { JaegerExporter } from '@opentelemetry/exporter-jaeger';

const traceExporter = new JaegerExporter({
  endpoint: 'http://localhost:14268/api/traces',
});

const sdk = new NodeSDK({
  traceExporter,
  // ...
});
```

### Zipkin

```bash
npm install @opentelemetry/exporter-zipkin
```

```typescript
import { ZipkinExporter } from '@opentelemetry/exporter-zipkin';

const traceExporter = new ZipkinExporter({
  url: 'http://localhost:9411/api/v2/spans',
});
```

### コンソール（デバッグ用）

```typescript
import { ConsoleSpanExporter } from '@opentelemetry/sdk-trace-base';

const traceExporter = new ConsoleSpanExporter();
```

---

## ベストプラクティス

### 1. 自動計装の活用

```typescript
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingPaths: ['/health', '/metrics'],
      },
      '@opentelemetry/instrumentation-express': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-pg': {
        enabled: true,
      },
    }),
  ],
});
```

### 2. サンプリング

```typescript
import { TraceIdRatioBasedSampler } from '@opentelemetry/sdk-trace-base';

const sdk = new NodeSDK({
  sampler: new TraceIdRatioBasedSampler(0.1), // 10%のトレースをサンプリング
  // ...
});
```

### 3. リソース属性

```typescript
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: 'my-service',
  [SemanticResourceAttributes.SERVICE_VERSION]: process.env.APP_VERSION || '1.0.0',
  [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
  [SemanticResourceAttributes.HOST_NAME]: process.env.HOSTNAME,
});
```

### 4. エラーハンドリング

```typescript
tracer.startActiveSpan('operation', async (span) => {
  try {
    await riskyOperation();
    span.setStatus({ code: 1 }); // OK
  } catch (error) {
    span.recordException(error as Error);
    span.setStatus({
      code: 2, // ERROR
      message: (error as Error).message,
    });
    throw error;
  } finally {
    span.end();
  }
});
```

### 5. パフォーマンス最適化

```typescript
// 高頻度の操作にはサンプリングを適用
const highFrequencyOperationCounter = meter.createCounter('high_frequency_operation');

function highFrequencyOperation() {
  // サンプリング（10回に1回だけ記録）
  if (Math.random() < 0.1) {
    highFrequencyOperationCounter.add(10); // 10回分まとめて記録
  }
}
```

### 6. Docker Compose設定

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
    depends_on:
      - otel-collector

  otel-collector:
    image: otel/opentelemetry-collector:latest
    command: ['--config=/etc/otel-collector-config.yaml']
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - '4318:4318' # OTLP HTTP
      - '4317:4317' # OTLP gRPC

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - '16686:16686' # Jaeger UI
      - '14268:14268' # Jaeger collector

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - '9090:9090'
```

### 7. カスタム計装

```typescript
// カスタムミドルウェア
function tracingMiddleware(req: any, res: any, next: any) {
  tracer.startActiveSpan(`${req.method} ${req.path}`, (span) => {
    span.setAttribute('http.method', req.method);
    span.setAttribute('http.url', req.url);
    span.setAttribute('http.user_agent', req.get('user-agent'));

    if (req.user) {
      span.setAttribute('user.id', req.user.id);
    }

    res.on('finish', () => {
      span.setAttribute('http.status_code', res.statusCode);
      span.end();
    });

    next();
  });
}

app.use(tracingMiddleware);
```

---

## 参考リンク

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [OpenTelemetry JS](https://github.com/open-telemetry/opentelemetry-js)
- [OpenTelemetry Specification](https://github.com/open-telemetry/opentelemetry-specification)
