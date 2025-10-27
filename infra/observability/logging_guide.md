# ログ集約・管理 完全ガイド

## 目次
1. [ロギングとは](#ロギングとは)
2. [Winston](#winston)
3. [Pino](#pino)
4. [構造化ログ](#構造化ログ)
5. [ログレベル](#ログレベル)
6. [ELK Stack](#elk-stack)
7. [ログローテーション](#ログローテーション)
8. [ベストプラクティス](#ベストプラクティス)

---

## ロギングとは

ロギングは、アプリケーションの動作を記録し、問題の診断やパフォーマンス分析を可能にする技術です。

### ログの目的

- **デバッグ**: 問題の原因特定
- **監視**: システムの健全性確認
- **監査**: セキュリティ・コンプライアンス
- **分析**: ユーザー行動分析

### ログレベル

- **ERROR**: エラー発生時
- **WARN**: 警告（エラーではない）
- **INFO**: 一般的な情報
- **DEBUG**: デバッグ情報
- **TRACE**: 詳細なトレース情報

---

## Winston

### セットアップ

```bash
npm install winston
npm install winston-daily-rotate-file
```

### 基本設定

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'my-service',
    environment: process.env.NODE_ENV,
  },
  transports: [
    // コンソール出力
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),

    // ファイル出力（エラーログ）
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
    }),

    // ファイル出力（全ログ）
    new winston.transports.File({
      filename: 'logs/combined.log',
    }),
  ],
});

export default logger;
```

### 使用例

```typescript
import logger from './logger';

// 基本的なログ
logger.info('User logged in', { userId: '123', email: 'user@example.com' });
logger.warn('High memory usage', { usage: '85%' });
logger.error('Database connection failed', { error: 'Connection timeout' });

// エラーオブジェクト
try {
  throw new Error('Something went wrong');
} catch (error) {
  logger.error('Failed to process request', { error });
}

// フォーマット付き
logger.info('User %s logged in from %s', userId, ipAddress);
```

### カスタムフォーマット

```typescript
const customFormat = winston.format.printf(({ level, message, timestamp, ...meta }) => {
  return `${timestamp} [${level}]: ${message} ${JSON.stringify(meta)}`;
});

const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    customFormat
  ),
  transports: [new winston.transports.Console()],
});
```

### Express統合

```typescript
import express from 'express';
import logger from './logger';

const app = express();

// リクエストロギングミドルウェア
app.use((req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;

    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration,
      userAgent: req.get('user-agent'),
      ip: req.ip,
    });
  });

  next();
});

// エラーハンドリング
app.use((err: Error, req: any, res: any, next: any) => {
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    method: req.method,
    url: req.url,
  });

  res.status(500).json({ error: 'Internal server error' });
});
```

---

## Pino

### セットアップ

```bash
npm install pino
npm install pino-pretty
```

### 基本設定

```typescript
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport:
    process.env.NODE_ENV === 'development'
      ? {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'SYS:standard',
            ignore: 'pid,hostname',
          },
        }
      : undefined,
});

export default logger;
```

### 使用例

```typescript
import logger from './logger';

// 基本的なログ
logger.info('Application started');
logger.info({ userId: '123' }, 'User logged in');
logger.error({ err: error }, 'Failed to process request');

// 子ロガー
const childLogger = logger.child({ module: 'auth' });
childLogger.info('User authenticated');
```

### Express統合（pino-http）

```bash
npm install pino-http
```

```typescript
import express from 'express';
import pinoHttp from 'pino-http';
import logger from './logger';

const app = express();

app.use(
  pinoHttp({
    logger,
    customLogLevel: (req, res, err) => {
      if (res.statusCode >= 500 || err) return 'error';
      if (res.statusCode >= 400) return 'warn';
      return 'info';
    },
    customSuccessMessage: (req, res) => {
      return `${req.method} ${req.url} - ${res.statusCode}`;
    },
    customErrorMessage: (req, res, err) => {
      return `${req.method} ${req.url} - ${res.statusCode} - ${err.message}`;
    },
  })
);

app.get('/api/users', (req, res) => {
  req.log.info('Fetching users');
  res.json({ users: [] });
});
```

---

## 構造化ログ

### JSON形式

```typescript
logger.info({
  event: 'user.login',
  userId: '123',
  email: 'user@example.com',
  timestamp: new Date().toISOString(),
  metadata: {
    ipAddress: '192.168.1.1',
    userAgent: 'Mozilla/5.0...',
  },
});
```

### ログコンテキスト

```typescript
import { AsyncLocalStorage } from 'async_hooks';
import logger from './logger';

const asyncLocalStorage = new AsyncLocalStorage<{ requestId: string }>();

// ミドルウェア
app.use((req, res, next) => {
  const requestId = generateRequestId();

  asyncLocalStorage.run({ requestId }, () => {
    req.requestId = requestId;
    next();
  });
});

// ロガーラッパー
function log(level: string, message: string, meta?: any) {
  const context = asyncLocalStorage.getStore();

  logger[level](message, {
    ...meta,
    requestId: context?.requestId,
  });
}

// 使用例
app.get('/api/users', async (req, res) => {
  log('info', 'Fetching users');
  const users = await getUsers();
  res.json(users);
});
```

### トレースID統合

```typescript
import { trace } from '@opentelemetry/api';

function logWithTrace(level: string, message: string, meta?: any) {
  const span = trace.getActiveSpan();
  const spanContext = span?.spanContext();

  logger[level](message, {
    ...meta,
    traceId: spanContext?.traceId,
    spanId: spanContext?.spanId,
  });
}
```

---

## ログレベル

### 環境別ログレベル

```typescript
const logLevel = {
  development: 'debug',
  staging: 'info',
  production: 'warn',
}[process.env.NODE_ENV || 'development'];

const logger = winston.createLogger({
  level: logLevel,
  // ...
});
```

### 動的ログレベル変更

```typescript
import logger from './logger';

// ログレベル変更エンドポイント
app.post('/admin/log-level', (req, res) => {
  const { level } = req.body;

  if (!['error', 'warn', 'info', 'debug'].includes(level)) {
    return res.status(400).json({ error: 'Invalid log level' });
  }

  logger.level = level;
  res.json({ message: `Log level set to ${level}` });
});
```

---

## ELK Stack

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - '9200:9200'
    volumes:
      - es_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    ports:
      - '5044:5044'
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - '5601:5601'
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  es_data:
```

### Logstash設定

```conf
# logstash.conf
input {
  tcp {
    port => 5044
    codec => json
  }
}

filter {
  # タイムスタンプ変換
  date {
    match => ["timestamp", "ISO8601"]
    target => "@timestamp"
  }

  # フィールド追加
  mutate {
    add_field => { "environment" => "%{[meta][environment]}" }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
  }

  stdout {
    codec => rubydebug
  }
}
```

### Winston → Logstash

```bash
npm install winston-logstash
```

```typescript
import winston from 'winston';
import LogstashTransport from 'winston-logstash/lib/winston-logstash-latest';

const logger = winston.createLogger({
  transports: [
    new LogstashTransport({
      host: 'localhost',
      port: 5044,
    }),
  ],
});
```

---

## ログローテーション

### winston-daily-rotate-file

```typescript
import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';

const logger = winston.createLogger({
  transports: [
    new DailyRotateFile({
      filename: 'logs/application-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '14d',
      zippedArchive: true,
    }),

    new DailyRotateFile({
      filename: 'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      level: 'error',
      maxSize: '20m',
      maxFiles: '30d',
      zippedArchive: true,
    }),
  ],
});
```

### logrotate（Linux）

```bash
# /etc/logrotate.d/myapp
/var/log/myapp/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload myapp
    endscript
}
```

---

## ベストプラクティス

### 1. センシティブ情報のマスキング

```typescript
import winston from 'winston';

const sensitiveFields = ['password', 'token', 'apiKey', 'ssn', 'creditCard'];

const maskSensitiveData = winston.format((info) => {
  const mask = (obj: any): any => {
    if (typeof obj !== 'object' || obj === null) return obj;

    const masked = Array.isArray(obj) ? [] : {};

    for (const [key, value] of Object.entries(obj)) {
      if (sensitiveFields.some((field) => key.toLowerCase().includes(field.toLowerCase()))) {
        masked[key] = '***MASKED***';
      } else if (typeof value === 'object') {
        masked[key] = mask(value);
      } else {
        masked[key] = value;
      }
    }

    return masked;
  };

  return mask(info);
});

const logger = winston.createLogger({
  format: winston.format.combine(
    maskSensitiveData(),
    winston.format.json()
  ),
});
```

### 2. パフォーマンスロギング

```typescript
function logPerformance(operation: string) {
  return (target: any, propertyKey: string, descriptor: PropertyDescriptor) => {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const start = Date.now();

      try {
        const result = await originalMethod.apply(this, args);
        const duration = Date.now() - start;

        logger.info('Performance', {
          operation,
          method: propertyKey,
          duration,
          success: true,
        });

        return result;
      } catch (error) {
        const duration = Date.now() - start;

        logger.error('Performance', {
          operation,
          method: propertyKey,
          duration,
          success: false,
          error: (error as Error).message,
        });

        throw error;
      }
    };

    return descriptor;
  };
}

// 使用例
class UserService {
  @logPerformance('database')
  async getUser(id: string) {
    return await db.users.findUnique({ where: { id } });
  }
}
```

### 3. エラートラッキング（Sentry統合）

```bash
npm install @sentry/node
```

```typescript
import * as Sentry from '@sentry/node';
import logger from './logger';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
});

// エラーロギング
function logError(error: Error, context?: any) {
  logger.error(error.message, {
    error: error.stack,
    ...context,
  });

  Sentry.captureException(error, {
    extra: context,
  });
}

// 使用例
try {
  await processPayment(orderId);
} catch (error) {
  logError(error as Error, { orderId });
  throw error;
}
```

### 4. ログ集約（Datadog）

```bash
npm install dd-trace
```

```typescript
import tracer from 'dd-trace';
import logger from './logger';

tracer.init({
  service: 'my-service',
  env: process.env.NODE_ENV,
  logInjection: true,
});

// ログにトレースIDを追加
logger.info('User action', {
  userId: '123',
  dd: {
    trace_id: tracer.scope().active()?.context().toTraceId(),
    span_id: tracer.scope().active()?.context().toSpanId(),
  },
});
```

### 5. ログ監視アラート

```typescript
import logger from './logger';
import { sendSlackAlert } from './slack';

const criticalLogger = logger.child({
  alert: true,
});

// 重大なエラーをSlackに通知
criticalLogger.error = function (message: string, meta?: any) {
  logger.error(message, meta);

  sendSlackAlert({
    channel: '#alerts',
    text: `🚨 Critical Error: ${message}`,
    fields: meta,
  });
};

// 使用例
try {
  await processPayment();
} catch (error) {
  criticalLogger.error('Payment processing failed', {
    error: (error as Error).message,
    orderId,
  });
}
```

### 6. ログクエリ例（Kibana）

```json
// エラーログ検索
{
  "query": {
    "bool": {
      "must": [
        { "match": { "level": "error" } },
        { "range": { "@timestamp": { "gte": "now-1h" } } }
      ]
    }
  }
}

// 特定ユーザーのログ
{
  "query": {
    "match": { "userId": "123" }
  }
}

// レスポンスタイムが遅いリクエスト
{
  "query": {
    "range": { "duration": { "gte": 1000 } }
  }
}
```

### 7. ログ保持ポリシー

```typescript
// ログレベル別の保持期間
const retentionPolicy = {
  error: 90, // 90日
  warn: 30, // 30日
  info: 14, // 14日
  debug: 7, // 7日
};

// Elasticsearchのインデックスライフサイクル管理
// PUT _ilm/policy/logs-policy
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_age": "1d",
            "max_size": "50gb"
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

---

## 参考リンク

- [Winston Documentation](https://github.com/winstonjs/winston)
- [Pino Documentation](https://getpino.io/)
- [ELK Stack](https://www.elastic.co/elastic-stack)
- [Structured Logging](https://www.structlog.org/)
