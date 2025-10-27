# サブスクリプション管理 完全ガイド

## 目次
1. [サブスクリプション管理とは](#サブスクリプション管理とは)
2. [データモデル設計](#データモデル設計)
3. [プラン管理](#プラン管理)
4. [課金処理](#課金処理)
5. [アップグレード・ダウングレード](#アップグレードダウングレード)
6. [請求書生成](#請求書生成)
7. [解約・返金](#解約返金)
8. [ベストプラクティス](#ベストプラクティス)

---

## サブスクリプション管理とは

定期課金サービスの会員管理、課金処理、プラン変更などを効率的に行うシステムです。

### 主な機能

- **プラン管理**: 複数のプラン・価格設定
- **課金処理**: 定期的な自動課金
- **使用量課金**: 使用量に応じた従量課金
- **トライアル**: 無料お試し期間
- **プロレーション**: プラン変更時の日割り計算

---

## データモデル設計

### Prismaスキーマ

```prisma
// schema.prisma

model User {
  id            String         @id @default(cuid())
  email         String         @unique
  name          String?
  stripeCustomerId String?     @unique
  subscriptions Subscription[]
  createdAt     DateTime       @default(now())
  updatedAt     DateTime       @updatedAt
}

model Plan {
  id            String         @id @default(cuid())
  name          String
  description   String?
  stripePriceId String         @unique
  amount        Int            // 価格（最小単位）
  currency      String         @default("jpy")
  interval      BillingInterval
  features      Json           // プラン機能
  active        Boolean        @default(true)
  subscriptions Subscription[]
  createdAt     DateTime       @default(now())
  updatedAt     DateTime       @updatedAt
}

enum BillingInterval {
  MONTHLY
  YEARLY
  WEEKLY
}

model Subscription {
  id                   String             @id @default(cuid())
  userId               String
  user                 User               @relation(fields: [userId], references: [id])
  planId               String
  plan                 Plan               @relation(fields: [planId], references: [id])
  stripeSubscriptionId String             @unique
  status               SubscriptionStatus
  currentPeriodStart   DateTime
  currentPeriodEnd     DateTime
  cancelAtPeriodEnd    Boolean            @default(false)
  canceledAt           DateTime?
  trialStart           DateTime?
  trialEnd             DateTime?
  invoices             Invoice[]
  createdAt            DateTime           @default(now())
  updatedAt            DateTime           @updatedAt

  @@index([userId])
  @@index([status])
}

enum SubscriptionStatus {
  TRIALING
  ACTIVE
  PAST_DUE
  CANCELED
  UNPAID
}

model Invoice {
  id                   String   @id @default(cuid())
  subscriptionId       String
  subscription         Subscription @relation(fields: [subscriptionId], references: [id])
  stripeInvoiceId      String   @unique
  amount               Int
  currency             String
  status               InvoiceStatus
  paidAt               DateTime?
  dueDate              DateTime
  invoiceUrl           String?
  createdAt            DateTime @default(now())

  @@index([subscriptionId])
  @@index([status])
}

enum InvoiceStatus {
  DRAFT
  OPEN
  PAID
  VOID
  UNCOLLECTIBLE
}
```

---

## プラン管理

### プラン作成

```typescript
import { PrismaClient } from '@prisma/client';
import Stripe from 'stripe';

const prisma = new PrismaClient();
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

async function createPlan(data: {
  name: string;
  description: string;
  amount: number;
  interval: 'month' | 'year';
  features: string[];
}) {
  // Stripeで商品・価格を作成
  const product = await stripe.products.create({
    name: data.name,
    description: data.description,
  });

  const price = await stripe.prices.create({
    product: product.id,
    unit_amount: data.amount,
    currency: 'jpy',
    recurring: {
      interval: data.interval,
    },
  });

  // データベースに保存
  const plan = await prisma.plan.create({
    data: {
      name: data.name,
      description: data.description,
      stripePriceId: price.id,
      amount: data.amount,
      interval: data.interval === 'month' ? 'MONTHLY' : 'YEARLY',
      features: data.features,
    },
  });

  return plan;
}

// 使用例
await createPlan({
  name: 'プレミアムプラン',
  description: '全機能が使える月額プラン',
  amount: 1000,
  interval: 'month',
  features: [
    '無制限のプロジェクト',
    '優先サポート',
    'カスタムドメイン',
  ],
});
```

### プラン一覧取得

```typescript
app.get('/api/plans', async (req, res) => {
  const plans = await prisma.plan.findMany({
    where: { active: true },
    orderBy: { amount: 'asc' },
  });

  res.json(plans);
});
```

---

## 課金処理

### サブスクリプション開始

```typescript
app.post('/api/subscriptions', async (req, res) => {
  try {
    const { userId, planId, paymentMethodId } = req.body;

    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    const plan = await prisma.plan.findUnique({
      where: { id: planId },
    });

    if (!user || !plan) {
      return res.status(404).json({ error: 'User or plan not found' });
    }

    // Stripe顧客がいない場合は作成
    let stripeCustomerId = user.stripeCustomerId;
    if (!stripeCustomerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        payment_method: paymentMethodId,
        invoice_settings: {
          default_payment_method: paymentMethodId,
        },
      });

      stripeCustomerId = customer.id;

      await prisma.user.update({
        where: { id: userId },
        data: { stripeCustomerId },
      });
    }

    // サブスクリプション作成
    const stripeSubscription = await stripe.subscriptions.create({
      customer: stripeCustomerId,
      items: [{ price: plan.stripePriceId }],
      payment_settings: {
        save_default_payment_method: 'on_subscription',
      },
      expand: ['latest_invoice.payment_intent'],
    });

    // データベースに保存
    const subscription = await prisma.subscription.create({
      data: {
        userId,
        planId,
        stripeSubscriptionId: stripeSubscription.id,
        status: mapStripeStatus(stripeSubscription.status),
        currentPeriodStart: new Date(stripeSubscription.current_period_start * 1000),
        currentPeriodEnd: new Date(stripeSubscription.current_period_end * 1000),
      },
    });

    res.json(subscription);
  } catch (error) {
    console.error('Subscription creation failed:', error);
    res.status(500).json({ error: 'Subscription creation failed' });
  }
});

function mapStripeStatus(status: string): SubscriptionStatus {
  const statusMap: Record<string, SubscriptionStatus> = {
    trialing: 'TRIALING',
    active: 'ACTIVE',
    past_due: 'PAST_DUE',
    canceled: 'CANCELED',
    unpaid: 'UNPAID',
  };

  return statusMap[status] || 'ACTIVE';
}
```

### トライアル期間付き

```typescript
const stripeSubscription = await stripe.subscriptions.create({
  customer: stripeCustomerId,
  items: [{ price: plan.stripePriceId }],
  trial_period_days: 14,
});

await prisma.subscription.create({
  data: {
    // ...
    trialStart: new Date(stripeSubscription.trial_start! * 1000),
    trialEnd: new Date(stripeSubscription.trial_end! * 1000),
  },
});
```

---

## アップグレード・ダウングレード

### プラン変更

```typescript
app.post('/api/subscriptions/:id/change-plan', async (req, res) => {
  try {
    const { id } = req.params;
    const { newPlanId } = req.body;

    const subscription = await prisma.subscription.findUnique({
      where: { id },
      include: { plan: true },
    });

    const newPlan = await prisma.plan.findUnique({
      where: { id: newPlanId },
    });

    if (!subscription || !newPlan) {
      return res.status(404).json({ error: 'Not found' });
    }

    // Stripeサブスクリプション更新
    const stripeSubscription = await stripe.subscriptions.retrieve(
      subscription.stripeSubscriptionId
    );

    await stripe.subscriptions.update(subscription.stripeSubscriptionId, {
      items: [
        {
          id: stripeSubscription.items.data[0].id,
          price: newPlan.stripePriceId,
        },
      ],
      proration_behavior: 'always_invoice', // 日割り計算
    });

    // データベース更新
    const updated = await prisma.subscription.update({
      where: { id },
      data: { planId: newPlanId },
    });

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: 'Plan change failed' });
  }
});
```

### プロレーション計算

```typescript
// プラン変更時の差額計算
async function calculateProration(subscriptionId: string, newPriceId: string) {
  const upcomingInvoice = await stripe.invoices.retrieveUpcoming({
    subscription: subscriptionId,
    subscription_items: [
      {
        id: 'si_xxx',
        price: newPriceId,
      },
    ],
  });

  return {
    proratedAmount: upcomingInvoice.total,
    lines: upcomingInvoice.lines.data,
  };
}
```

---

## 請求書生成

### Webhook処理

```typescript
app.post('/api/webhooks/stripe', async (req, res) => {
  const event = stripe.webhooks.constructEvent(/* ... */);

  switch (event.type) {
    case 'invoice.created':
      await handleInvoiceCreated(event.data.object as Stripe.Invoice);
      break;

    case 'invoice.paid':
      await handleInvoicePaid(event.data.object as Stripe.Invoice);
      break;

    case 'invoice.payment_failed':
      await handleInvoicePaymentFailed(event.data.object as Stripe.Invoice);
      break;
  }

  res.json({ received: true });
});

async function handleInvoiceCreated(invoice: Stripe.Invoice) {
  const subscription = await prisma.subscription.findUnique({
    where: { stripeSubscriptionId: invoice.subscription as string },
  });

  if (subscription) {
    await prisma.invoice.create({
      data: {
        subscriptionId: subscription.id,
        stripeInvoiceId: invoice.id,
        amount: invoice.total,
        currency: invoice.currency,
        status: 'OPEN',
        dueDate: new Date(invoice.due_date! * 1000),
        invoiceUrl: invoice.hosted_invoice_url,
      },
    });
  }
}

async function handleInvoicePaid(invoice: Stripe.Invoice) {
  await prisma.invoice.update({
    where: { stripeInvoiceId: invoice.id },
    data: {
      status: 'PAID',
      paidAt: new Date(),
    },
  });

  // サブスクリプションステータス更新
  await prisma.subscription.update({
    where: { stripeSubscriptionId: invoice.subscription as string },
    data: { status: 'ACTIVE' },
  });
}

async function handleInvoicePaymentFailed(invoice: Stripe.Invoice) {
  await prisma.invoice.update({
    where: { stripeInvoiceId: invoice.id },
    data: { status: 'UNCOLLECTIBLE' },
  });

  // サブスクリプションを支払い遅延状態に
  await prisma.subscription.update({
    where: { stripeSubscriptionId: invoice.subscription as string },
    data: { status: 'PAST_DUE' },
  });

  // ユーザーに通知
  const subscription = await prisma.subscription.findUnique({
    where: { stripeSubscriptionId: invoice.subscription as string },
    include: { user: true },
  });

  await sendPaymentFailureEmail(subscription!.user.email);
}
```

### 請求書一覧

```typescript
app.get('/api/invoices', async (req, res) => {
  const { userId } = req.query;

  const invoices = await prisma.invoice.findMany({
    where: {
      subscription: {
        userId: userId as string,
      },
    },
    include: {
      subscription: {
        include: {
          plan: true,
        },
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  res.json(invoices);
});
```

---

## 解約・返金

### サブスクリプション解約

```typescript
app.post('/api/subscriptions/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;
    const { immediate = false } = req.body;

    const subscription = await prisma.subscription.findUnique({
      where: { id },
    });

    if (!subscription) {
      return res.status(404).json({ error: 'Subscription not found' });
    }

    if (immediate) {
      // 即座にキャンセル
      await stripe.subscriptions.cancel(subscription.stripeSubscriptionId);

      await prisma.subscription.update({
        where: { id },
        data: {
          status: 'CANCELED',
          canceledAt: new Date(),
        },
      });
    } else {
      // 期間終了時にキャンセル
      await stripe.subscriptions.update(subscription.stripeSubscriptionId, {
        cancel_at_period_end: true,
      });

      await prisma.subscription.update({
        where: { id },
        data: {
          cancelAtPeriodEnd: true,
        },
      });
    }

    res.json({ message: 'Subscription canceled' });
  } catch (error) {
    res.status(500).json({ error: 'Cancellation failed' });
  }
});
```

### 解約取り消し

```typescript
app.post('/api/subscriptions/:id/reactivate', async (req, res) => {
  const { id } = req.params;

  const subscription = await prisma.subscription.findUnique({
    where: { id },
  });

  if (!subscription || !subscription.cancelAtPeriodEnd) {
    return res.status(400).json({ error: 'Cannot reactivate' });
  }

  await stripe.subscriptions.update(subscription.stripeSubscriptionId, {
    cancel_at_period_end: false,
  });

  await prisma.subscription.update({
    where: { id },
    data: { cancelAtPeriodEnd: false },
  });

  res.json({ message: 'Subscription reactivated' });
});
```

### 返金処理

```typescript
async function refundSubscription(subscriptionId: string, reason?: string) {
  const subscription = await prisma.subscription.findUnique({
    where: { id: subscriptionId },
    include: { invoices: true },
  });

  if (!subscription) {
    throw new Error('Subscription not found');
  }

  // 最後の請求書を取得
  const lastInvoice = subscription.invoices
    .filter((inv) => inv.status === 'PAID')
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0];

  if (lastInvoice) {
    // Stripe返金作成
    const refund = await stripe.refunds.create({
      charge: lastInvoice.stripeInvoiceId,
      reason: reason as any,
    });

    // ログ記録
    await prisma.refund.create({
      data: {
        invoiceId: lastInvoice.id,
        stripeRefundId: refund.id,
        amount: refund.amount,
        reason,
      },
    });
  }

  // サブスクリプションキャンセル
  await stripe.subscriptions.cancel(subscription.stripeSubscriptionId);

  await prisma.subscription.update({
    where: { id: subscriptionId },
    data: {
      status: 'CANCELED',
      canceledAt: new Date(),
    },
  });
}
```

---

## ベストプラクティス

### 1. 使用制限チェック

```typescript
async function checkSubscriptionFeature(
  userId: string,
  feature: string
): Promise<boolean> {
  const subscription = await prisma.subscription.findFirst({
    where: {
      userId,
      status: { in: ['ACTIVE', 'TRIALING'] },
    },
    include: { plan: true },
  });

  if (!subscription) {
    return false;
  }

  const features = subscription.plan.features as string[];
  return features.includes(feature);
}

// ミドルウェア
function requireFeature(feature: string) {
  return async (req: any, res: any, next: any) => {
    const hasFeature = await checkSubscriptionFeature(req.user.id, feature);

    if (!hasFeature) {
      return res.status(403).json({
        error: 'この機能を使用するにはプランのアップグレードが必要です',
      });
    }

    next();
  };
}

// 使用例
app.post('/api/projects', requireFeature('unlimited_projects'), async (req, res) => {
  // プロジェクト作成処理
});
```

### 2. 使用量追跡

```typescript
model Usage {
  id             String   @id @default(cuid())
  subscriptionId String
  subscription   Subscription @relation(fields: [subscriptionId], references: [id])
  metric         String   // "api_calls", "storage_gb" など
  quantity       Int
  timestamp      DateTime @default(now())

  @@index([subscriptionId, metric])
}

// 使用量記録
async function trackUsage(subscriptionId: string, metric: string, quantity: number) {
  await prisma.usage.create({
    data: {
      subscriptionId,
      metric,
      quantity,
    },
  });

  // Stripeに使用量を報告（従量課金の場合）
  const subscription = await prisma.subscription.findUnique({
    where: { id: subscriptionId },
  });

  const stripeSubscription = await stripe.subscriptions.retrieve(
    subscription!.stripeSubscriptionId
  );

  const usageBasedItem = stripeSubscription.items.data.find(
    (item) => item.price.recurring?.usage_type === 'metered'
  );

  if (usageBasedItem) {
    await stripe.subscriptionItems.createUsageRecord(usageBasedItem.id, {
      quantity,
      timestamp: Math.floor(Date.now() / 1000),
    });
  }
}
```

### 3. ダンジョングレード防止

```typescript
async function preventDowngradeDataLoss(
  subscriptionId: string,
  newPlanId: string
): Promise<{ allowed: boolean; reason?: string }> {
  const subscription = await prisma.subscription.findUnique({
    where: { id: subscriptionId },
    include: { plan: true, user: true },
  });

  const newPlan = await prisma.plan.findUnique({
    where: { id: newPlanId },
  });

  if (!subscription || !newPlan) {
    return { allowed: false, reason: 'プランが見つかりません' };
  }

  // 現在のプランより低い場合のチェック
  if (newPlan.amount < subscription.plan.amount) {
    // プロジェクト数チェック
    const projectCount = await prisma.project.count({
      where: { userId: subscription.userId },
    });

    const newPlanFeatures = newPlan.features as any;
    if (projectCount > newPlanFeatures.maxProjects) {
      return {
        allowed: false,
        reason: `プロジェクト数が上限（${newPlanFeatures.maxProjects}）を超えています`,
      };
    }
  }

  return { allowed: true };
}
```

### 4. サブスクリプション期限通知

```typescript
import cron from 'node-cron';

// 毎日実行
cron.schedule('0 9 * * *', async () => {
  const threeDaysFromNow = new Date();
  threeDaysFromNow.setDate(threeDaysFromNow.getDate() + 3);

  // 3日後に期限が切れるサブスクリプション
  const expiring = await prisma.subscription.findMany({
    where: {
      status: 'ACTIVE',
      currentPeriodEnd: {
        gte: new Date(),
        lte: threeDaysFromNow,
      },
    },
    include: { user: true, plan: true },
  });

  for (const sub of expiring) {
    await sendExpirationReminderEmail(sub.user.email, sub);
  }
});
```

### 5. MRR（月次経常収益）計算

```typescript
async function calculateMRR() {
  const activeSubscriptions = await prisma.subscription.findMany({
    where: {
      status: { in: ['ACTIVE', 'TRIALING'] },
    },
    include: { plan: true },
  });

  const mrr = activeSubscriptions.reduce((total, sub) => {
    let monthlyAmount = sub.plan.amount;

    // 年間プランを月額に換算
    if (sub.plan.interval === 'YEARLY') {
      monthlyAmount = monthlyAmount / 12;
    }

    return total + monthlyAmount;
  }, 0);

  return mrr;
}

// ダッシュボード
app.get('/api/admin/metrics', async (req, res) => {
  const mrr = await calculateMRR();

  const churnRate = await calculateChurnRate();
  const newSubscriptions = await getNewSubscriptionsThisMonth();

  res.json({
    mrr,
    churnRate,
    newSubscriptions,
  });
});
```

---

## 参考リンク

- [Stripe Billing](https://stripe.com/docs/billing)
- [Stripe Subscriptions](https://stripe.com/docs/billing/subscriptions/overview)
- [SaaS Metrics](https://stripe.com/guides/saas-metrics)
