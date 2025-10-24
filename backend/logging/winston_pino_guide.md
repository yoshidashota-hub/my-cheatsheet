# ログ管理完全ガイド (Winston / Pino)

## 目次
- [概要](#概要)
- [Winston](#winston)
- [Pino](#pino)
- [比較](#比較)
- [本番環境設定](#本番環境設定)
- [ログ集約](#ログ集約)

---

## 概要

Node.jsのログ管理ライブラリ。本番環境でのデバッグやモニタリングに必須。

### 主要ライブラリ
- **Winston**: 多機能、柔軟なトランスポート、豊富なエコシステム
- **Pino**: 高速、軽量、JSON形式、パフォーマンス重視

---

## Winston

最も人気のあるNode.jsロギングライブラリ。

### インストール

```bash
npm install winston
```

### 基本的な使い方

```typescript
import winston from 'winston'

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
})

// ログ出力
logger.info('Server started', { port: 3000 })
logger.warn('Warning message')
logger.error('Error occurred', { error: 'details' })
```

### ログレベル

```typescript
const levels = {
  error: 0,   // エラー
  warn: 1,    // 警告
  info: 2,    // 情報
  http: 3,    // HTTPリクエスト
  verbose: 4, // 詳細
  debug: 5,   // デバッグ
  silly: 6    // 全て
}

// 使用例
logger.error('Critical error')
logger.warn('This is a warning')
logger.info('Informational message')
logger.http('GET /api/users')
logger.debug('Debugging info', { data: {...} })
```

### フォーマット

```typescript
import winston from 'winston'

const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
})
```

### カスタムフォーマット

```typescript
const customFormat = winston.format.printf(({ level, message, timestamp, ...metadata }) => {
  let msg = `${timestamp} [${level}]: ${message}`

  if (Object.keys(metadata).length > 0) {
    msg += ` ${JSON.stringify(metadata)}`
  }

  return msg
})

const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    customFormat
  ),
  transports: [new winston.transports.Console()]
})
```

### 環境別設定

```typescript
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.json(),
  defaultMeta: { service: 'user-service' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
})

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }))
}
```

### Express統合

```typescript
import express from 'express'
import winston from 'winston'
import expressWinston from 'express-winston'

const app = express()

// リクエストログ
app.use(expressWinston.logger({
  transports: [
    new winston.transports.Console()
  ],
  format: winston.format.combine(
    winston.format.colorize(),
    winston.format.json()
  ),
  meta: true,
  msg: 'HTTP {{req.method}} {{req.url}}',
  expressFormat: true,
  colorize: false
}))

// アプリケーションロジック
app.get('/', (req, res) => {
  logger.info('Home page accessed')
  res.send('Hello')
})

// エラーログ
app.use(expressWinston.errorLogger({
  transports: [
    new winston.transports.Console()
  ],
  format: winston.format.combine(
    winston.format.colorize(),
    winston.format.json()
  )
}))
```

### 外部サービス連携

```typescript
// CloudWatch
import WinstonCloudWatch from 'winston-cloudwatch'

logger.add(new WinstonCloudWatch({
  logGroupName: '/aws/lambda/my-function',
  logStreamName: 'production',
  awsRegion: 'ap-northeast-1'
}))

// Datadog
import { WinstonTransport as DatadogWinston } from '@datadog/datadog-winston'

logger.add(new DatadogWinston({
  apiKey: process.env.DATADOG_API_KEY,
  hostname: 'my-host',
  service: 'my-service'
}))
```

---

## Pino

高速でJSONベースのロギングライブラリ。

### インストール

```bash
npm install pino
npm install pino-pretty  # 開発用
```

### 基本的な使い方

```typescript
import pino from 'pino'

const logger = pino({
  level: process.env.LOG_LEVEL || 'info'
})

// ログ出力
logger.info('Server started')
logger.info({ port: 3000 }, 'Server started on port')
logger.warn('Warning message')
logger.error({ err: new Error('Failed') }, 'Error occurred')
```

### Pretty Print（開発環境）

```typescript
const logger = pino({
  transport: {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'yyyy-mm-dd HH:MM:ss',
      ignore: 'pid,hostname'
    }
  }
})
```

### 子ロガー

```typescript
const baseLogger = pino()

// 子ロガー作成
const childLogger = baseLogger.child({ module: 'auth' })

childLogger.info('User logged in', { userId: '123' })
// Output: {"level":30,"time":...,"module":"auth","userId":"123","msg":"User logged in"}
```

### 環境別設定

```typescript
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  ...(process.env.NODE_ENV !== 'production' && {
    transport: {
      target: 'pino-pretty',
      options: {
        colorize: true
      }
    }
  })
})
```

### Express統合

```typescript
import express from 'express'
import pino from 'pino'
import pinoHttp from 'pino-http'

const logger = pino()
const app = express()

// HTTPログミドルウェア
app.use(pinoHttp({ logger }))

app.get('/', (req, res) => {
  req.log.info('Home page accessed')
  res.send('Hello')
})
```

### カスタムシリアライザー

```typescript
const logger = pino({
  serializers: {
    req: (req) => ({
      method: req.method,
      url: req.url,
      headers: req.headers
    }),
    res: (res) => ({
      statusCode: res.statusCode
    }),
    err: pino.stdSerializers.err
  }
})
```

### 非同期ロギング

```typescript
import pino from 'pino'

const logger = pino(
  pino.destination({
    dest: './app.log',
    sync: false  // 非同期書き込み
  })
)

// プロセス終了時にフラッシュ
process.on('SIGINT', () => {
  logger.flush()
  process.exit(0)
})
```

### 外部サービス連携

```typescript
// CloudWatch
import pinoCloudWatch from 'pino-cloudwatch'

const logger = pino({
  level: 'info'
}, pinoCloudWatch({
  group: '/aws/lambda/my-function',
  stream: 'production',
  aws_region: 'ap-northeast-1'
}))

// Datadog
import { datadog } from 'pino-datadog'

const logger = pino({}, datadog({
  apiKey: process.env.DATADOG_API_KEY,
  service: 'my-service'
}))
```

---

## 比較

| 機能 | Winston | Pino |
|------|---------|------|
| パフォーマンス | 普通 | ◎ 高速 |
| 出力形式 | 柔軟 | JSON固定 |
| トランスポート | 豊富 | シンプル |
| カスタマイズ | ◎ 高い | ○ 普通 |
| ファイルサイズ | 大きい | 小さい |
| エコシステム | 豊富 | 限定的 |
| 学習コスト | 低 | 低 |

### どちらを選ぶ？

**Winston**を選ぶ場合:
- 柔軟なフォーマットが必要
- 多様なトランスポートを使いたい
- 既存のWinstonエコシステムを活用
- ログの見た目をカスタマイズしたい

**Pino**を選ぶ場合:
- 高パフォーマンスが必須
- JSONログが要件
- シンプルな設定で済ませたい
- マイクロサービスアーキテクチャ

---

## 本番環境設定

### 環境変数

```bash
# .env
LOG_LEVEL=info
NODE_ENV=production
```

### ログローテーション

```typescript
// Winston
import winston from 'winston'
import DailyRotateFile from 'winston-daily-rotate-file'

const logger = winston.createLogger({
  transports: [
    new DailyRotateFile({
      filename: 'application-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '14d'
    })
  ]
})
```

```typescript
// Pino
import pino from 'pino'
import rotating from 'rotating-file-stream'

const stream = rotating.createStream('app.log', {
  interval: '1d',
  maxFiles: 14,
  compress: 'gzip'
})

const logger = pino(stream)
```

### エラー処理

```typescript
// Winston
logger.error('Error occurred', {
  error: err.message,
  stack: err.stack,
  userId: req.user?.id
})

// Pino
logger.error({ err, userId: req.user?.id }, 'Error occurred')
```

### 機密情報のマスク

```typescript
// Winston
const maskFormat = winston.format((info) => {
  if (info.password) {
    info.password = '***'
  }
  return info
})

// Pino
const logger = pino({
  serializers: {
    password: () => '***',
    token: () => '***'
  }
})
```

---

## ログ集約

### ELKスタック（Elasticsearch + Logstash + Kibana）

```typescript
// Winston
import { ElasticsearchTransport } from 'winston-elasticsearch'

logger.add(new ElasticsearchTransport({
  level: 'info',
  clientOpts: { node: 'http://localhost:9200' },
  index: 'logs'
}))
```

### Datadog

```typescript
// ログをJSON形式で出力し、Datadog Agentが収集
logger.info({
  message: 'User login',
  userId: '123',
  dd: {
    service: 'my-service',
    env: 'production'
  }
})
```

### CloudWatch Logs

```typescript
// AWS Lambda環境では自動的にCloudWatch Logsに送信
console.log(JSON.stringify({
  level: 'info',
  message: 'Processing started',
  requestId: context.requestId
}))
```

---

## ベストプラクティス

### ✓ 推奨

```typescript
// 構造化ログ
logger.info({ userId, action: 'login' }, 'User logged in')

// コンテキスト情報を含める
logger.error({ err, userId, requestId }, 'Payment failed')

// 適切なログレベル
logger.error('Critical error')  // エラー
logger.warn('Retry attempt')    // 警告
logger.info('User action')      // 情報
logger.debug('Variable value')  // デバッグ
```

### ✗ 避けるべき

```typescript
// 平文のみ
logger.info('User logged in')

// 機密情報をログに出力
logger.info('Password:', password)

// 過度なログ
logger.debug('Line 1')
logger.debug('Line 2')
logger.debug('Line 3')
```

---

## 参考リンク

- [Winston Documentation](https://github.com/winstonjs/winston)
- [Pino Documentation](https://getpino.io/)
- [12 Factor App - Logs](https://12factor.net/logs)
