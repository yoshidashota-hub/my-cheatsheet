# スケジューリング・ジョブキューガイド

バックエンドアプリケーションで定期実行タスクやバックグラウンドジョブを実装するためのガイドです。

## ライブラリ比較

| ライブラリ | 用途 | 永続化 | UI | 分散対応 | 複雑さ |
|-----------|------|--------|----|---------|---------|
| **node-cron** | 定期実行 | ✗ | ✗ | ✗ | ⭐ |
| **BullMQ** | ジョブキュー | ✓ (Redis) | ✓ | ✓ | ⭐⭐⭐ |
| **Agenda** | ジョブスケジューリング | ✓ (MongoDB) | ✗ | ✓ | ⭐⭐ |
| **node-schedule** | 定期実行 | ✗ | ✗ | ✗ | ⭐ |

### 選択基準

- **node-cron**: シンプルな定期実行タスク
- **BullMQ**: 本格的なジョブキュー、スケーリング必要
- **Agenda**: MongoDB使用、中規模アプリ
- **node-schedule**: より高度な日時指定

## node-cron

### 特徴

- **シンプル**: 最小限のセットアップ
- **軽量**: 依存関係が少ない
- **Cron構文**: Unixのcronと同じ
- **インメモリ**: 永続化なし

### インストール

```bash
npm install node-cron
```

### 基本的な使い方

```typescript
import cron from 'node-cron'

// 毎分実行
cron.schedule('* * * * *', () => {
  console.log('Running every minute')
})

// 毎日午前3時に実行
cron.schedule('0 3 * * *', () => {
  console.log('Running at 3:00 AM every day')
})

// 月曜日から金曜日の午前9時に実行
cron.schedule('0 9 * * 1-5', () => {
  console.log('Running at 9:00 AM on weekdays')
})
```

### Cron構文

```text
 ┌────────────── 秒 (0-59) - オプション
 │ ┌──────────── 分 (0-59)
 │ │ ┌────────── 時 (0-23)
 │ │ │ ┌──────── 日 (1-31)
 │ │ │ │ ┌────── 月 (1-12)
 │ │ │ │ │ ┌──── 曜日 (0-7) (0と7は日曜日)
 │ │ │ │ │ │
 * * * * * *
```

### よく使うパターン

```typescript
import cron from 'node-cron'

// 毎分
cron.schedule('* * * * *', task)

// 毎時0分
cron.schedule('0 * * * *', task)

// 毎日深夜0時
cron.schedule('0 0 * * *', task)

// 毎週月曜日午前9時
cron.schedule('0 9 * * 1', task)

// 毎月1日午前0時
cron.schedule('0 0 1 * *', task)

// 平日の午前9時から午後5時まで1時間ごと
cron.schedule('0 9-17 * * 1-5', task)

// 15分ごと
cron.schedule('*/15 * * * *', task)

// 30秒ごと（秒指定）
cron.schedule('*/30 * * * * *', task)
```

### タスクの制御

```typescript
import cron from 'node-cron'

// タスク作成
const task = cron.schedule('*/5 * * * *', () => {
  console.log('Running every 5 minutes')
}, {
  scheduled: false, // 初期状態は停止
})

// タスク開始
task.start()

// タスク停止
task.stop()

// タスク削除
task.destroy()
```

### 実践例

```typescript
import cron from 'node-cron'
import { prisma } from './db'
import { sendEmail } from './email'

// 日次レポート生成（毎日午前3時）
cron.schedule('0 3 * * *', async () => {
  console.log('Generating daily report...')

  try {
    const report = await generateDailyReport()
    await saveReport(report)
    console.log('Daily report generated successfully')
  } catch (error) {
    console.error('Failed to generate report:', error)
  }
})

// 期限切れデータのクリーンアップ（毎日午前2時）
cron.schedule('0 2 * * *', async () => {
  console.log('Cleaning up expired data...')

  try {
    const result = await prisma.session.deleteMany({
      where: {
        expiresAt: {
          lt: new Date(),
        },
      },
    })

    console.log(`Deleted ${result.count} expired sessions`)
  } catch (error) {
    console.error('Cleanup failed:', error)
  }
})

// リマインダーメール送信（毎日午前10時）
cron.schedule('0 10 * * *', async () => {
  console.log('Sending reminder emails...')

  try {
    const reminders = await prisma.reminder.findMany({
      where: {
        scheduledFor: {
          gte: new Date(),
          lt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        },
        sent: false,
      },
      include: {
        user: true,
      },
    })

    for (const reminder of reminders) {
      await sendEmail({
        to: reminder.user.email,
        subject: 'Reminder',
        body: reminder.message,
      })

      await prisma.reminder.update({
        where: { id: reminder.id },
        data: { sent: true },
      })
    }

    console.log(`Sent ${reminders.length} reminder emails`)
  } catch (error) {
    console.error('Failed to send reminders:', error)
  }
})
```

### Next.js での使用

```typescript
// lib/cron.ts
import cron from 'node-cron'

export function initializeCronJobs() {
  // 開発環境では実行しない
  if (process.env.NODE_ENV !== 'production') {
    return
  }

  // Cronジョブの初期化
  cron.schedule('0 3 * * *', async () => {
    // タスク実行
  })

  console.log('Cron jobs initialized')
}
```

```typescript
// app/api/cron/init/route.ts
import { NextResponse } from 'next/server'
import { initializeCronJobs } from '@/lib/cron'

let initialized = false

export async function GET() {
  if (!initialized) {
    initializeCronJobs()
    initialized = true
  }

  return NextResponse.json({ status: 'Cron jobs running' })
}
```

## BullMQ

### 特徴

- **Redis**: Redisベースの永続化
- **分散処理**: 複数ワーカーで並列処理
- **リトライ**: 自動リトライ機能
- **優先度**: ジョブの優先度設定
- **UI**: Bull Boardで監視可能

### インストール

```bash
npm install bullmq
npm install ioredis
```

### 基本設定

```typescript
// lib/queue.ts
import { Queue, Worker } from 'bullmq'
import IORedis from 'ioredis'

const connection = new IORedis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  maxRetriesPerRequest: null,
})

// キュー作成
export const emailQueue = new Queue('email', { connection })

// ワーカー作成
export const emailWorker = new Worker(
  'email',
  async (job) => {
    const { to, subject, body } = job.data

    console.log(`Sending email to ${to}...`)

    // メール送信処理
    await sendEmail({ to, subject, body })

    console.log(`Email sent to ${to}`)

    return { success: true }
  },
  { connection }
)

// イベントリスナー
emailWorker.on('completed', (job) => {
  console.log(`Job ${job.id} completed`)
})

emailWorker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed:`, err)
})
```

### ジョブの追加

```typescript
import { emailQueue } from '@/lib/queue'

// ジョブ追加
await emailQueue.add('send-email', {
  to: 'user@example.com',
  subject: 'Welcome!',
  body: 'Thank you for signing up',
})

// 遅延実行（5分後）
await emailQueue.add(
  'send-email',
  {
    to: 'user@example.com',
    subject: 'Reminder',
    body: 'Don\'t forget!',
  },
  {
    delay: 5 * 60 * 1000, // 5分
  }
)

// 優先度設定
await emailQueue.add(
  'send-email',
  { to: 'vip@example.com', subject: 'VIP', body: 'High priority' },
  {
    priority: 1, // 高優先度
  }
)

// リトライ設定
await emailQueue.add(
  'send-email',
  { to: 'user@example.com', subject: 'Important', body: 'Message' },
  {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 1000,
    },
  }
)
```

### スケジュール実行

```typescript
import { Queue, QueueScheduler } from 'bullmq'

const connection = {
  host: 'localhost',
  port: 6379,
}

// スケジューラー作成
const scheduler = new QueueScheduler('reports', { connection })

// キュー作成
const reportQueue = new Queue('reports', { connection })

// 定期実行ジョブ追加
await reportQueue.add(
  'daily-report',
  { type: 'daily' },
  {
    repeat: {
      pattern: '0 3 * * *', // 毎日午前3時
    },
  }
)

// 週次レポート
await reportQueue.add(
  'weekly-report',
  { type: 'weekly' },
  {
    repeat: {
      pattern: '0 9 * * 1', // 毎週月曜日午前9時
    },
  }
)
```

### 実践例

```typescript
// lib/queues/email-queue.ts
import { Queue, Worker } from 'bullmq'
import { sendEmail } from '../email'

const connection = {
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT || '6379'),
}

export const emailQueue = new Queue('email', { connection })

export const emailWorker = new Worker(
  'email',
  async (job) => {
    const { type, ...data } = job.data

    switch (type) {
      case 'welcome':
        await sendEmail({
          to: data.email,
          subject: 'Welcome to our service!',
          template: 'welcome',
          data,
        })
        break

      case 'password-reset':
        await sendEmail({
          to: data.email,
          subject: 'Password Reset Request',
          template: 'password-reset',
          data,
        })
        break

      case 'notification':
        await sendEmail({
          to: data.email,
          subject: data.subject,
          body: data.body,
        })
        break

      default:
        throw new Error(`Unknown email type: ${type}`)
    }

    return { success: true }
  },
  {
    connection,
    concurrency: 5, // 同時に5つのジョブを処理
  }
)

emailWorker.on('failed', (job, err) => {
  console.error(`Email job ${job?.id} failed:`, err)
  // エラー通知、ログ保存等
})
```

```typescript
// lib/queues/image-queue.ts
import { Queue, Worker } from 'bullmq'
import sharp from 'sharp'

export const imageQueue = new Queue('image-processing', { connection })

export const imageWorker = new Worker(
  'image-processing',
  async (job) => {
    const { inputPath, outputPath, width, height } = job.data

    await sharp(inputPath)
      .resize(width, height, { fit: 'cover' })
      .jpeg({ quality: 80 })
      .toFile(outputPath)

    return { success: true, outputPath }
  },
  {
    connection,
    concurrency: 3,
  }
)
```

### Bull Board（UI）

```typescript
// app/api/admin/queues/route.ts
import { createBullBoard } from '@bull-board/api'
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter'
import { ExpressAdapter } from '@bull-board/express'
import { emailQueue, imageQueue } from '@/lib/queues'

const serverAdapter = new ExpressAdapter()

createBullBoard({
  queues: [
    new BullMQAdapter(emailQueue),
    new BullMQAdapter(imageQueue),
  ],
  serverAdapter,
})

serverAdapter.setBasePath('/api/admin/queues')

// Express middleware として使用
```

### Next.js API Route

```typescript
// app/api/users/register/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { emailQueue } from '@/lib/queues/email-queue'
import { prisma } from '@/lib/db'

export async function POST(request: NextRequest) {
  const { email, name, password } = await request.json()

  // ユーザー作成
  const user = await prisma.user.create({
    data: { email, name, passwordHash: await hash(password) },
  })

  // ウェルカムメールをキューに追加
  await emailQueue.add('welcome', {
    type: 'welcome',
    email: user.email,
    name: user.name,
  })

  return NextResponse.json({ success: true, user })
}
```

## Vercel Cron Jobs

### 特徴

- **Vercel統合**: 設定ファイルで管理
- **サーバーレス**: 関数として実行
- **無料枠**: Hobby プランでも使用可能

### 設定

```json
// vercel.json
{
  "crons": [
    {
      "path": "/api/cron/daily-report",
      "schedule": "0 3 * * *"
    },
    {
      "path": "/api/cron/cleanup",
      "schedule": "0 2 * * *"
    }
  ]
}
```

### API Route

```typescript
// app/api/cron/daily-report/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  // 認証チェック（Vercelからのリクエストか確認）
  const authHeader = request.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    // レポート生成処理
    const report = await generateDailyReport()

    return NextResponse.json({ success: true, report })
  } catch (error) {
    console.error('Cron job failed:', error)
    return NextResponse.json({ error: 'Failed' }, { status: 500 })
  }
}
```

## ベストプラクティス

### 1. エラーハンドリング

```typescript
cron.schedule('0 3 * * *', async () => {
  try {
    await performTask()
  } catch (error) {
    console.error('Task failed:', error)
    // エラー通知（Slack、メール等）
    await notifyError(error)
  }
})
```

### 2. 冪等性

```typescript
// 同じジョブが複数回実行されても安全に
async function processOrder(orderId: string) {
  const order = await prisma.order.findUnique({
    where: { id: orderId },
  })

  // 既に処理済みかチェック
  if (order.status === 'processed') {
    console.log('Order already processed')
    return
  }

  // 処理実行
  await processOrderLogic(order)

  // ステータス更新
  await prisma.order.update({
    where: { id: orderId },
    data: { status: 'processed' },
  })
}
```

### 3. ロギング

```typescript
import cron from 'node-cron'

cron.schedule('0 3 * * *', async () => {
  const startTime = Date.now()
  console.log(`[${new Date().toISOString()}] Starting daily report...`)

  try {
    const result = await generateDailyReport()
    const duration = Date.now() - startTime

    console.log(
      `[${new Date().toISOString()}] Daily report completed in ${duration}ms`,
      result
    )
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Daily report failed:`, error)
  }
})
```

### 4. タイムゾーン設定

```typescript
import cron from 'node-cron'

// タイムゾーン指定
cron.schedule(
  '0 9 * * *',
  () => {
    console.log('Running at 9:00 AM JST')
  },
  {
    timezone: 'Asia/Tokyo',
  }
)
```

### 5. ジョブの分離

```typescript
// 各ジョブを個別のファイルに分離
// jobs/daily-report.ts
export async function dailyReportJob() {
  // レポート生成処理
}

// jobs/cleanup.ts
export async function cleanupJob() {
  // クリーンアップ処理
}

// lib/scheduler.ts
import cron from 'node-cron'
import { dailyReportJob } from '@/jobs/daily-report'
import { cleanupJob } from '@/jobs/cleanup'

export function initializeScheduler() {
  cron.schedule('0 3 * * *', dailyReportJob)
  cron.schedule('0 2 * * *', cleanupJob)
}
```

## 参考リンク

- [node-cron 公式ドキュメント](https://github.com/node-cron/node-cron)
- [BullMQ 公式ドキュメント](https://docs.bullmq.io/)
- [Vercel Cron Jobs](https://vercel.com/docs/cron-jobs)
- [Crontab Guru](https://crontab.guru/) - Cron構文チェッカー
