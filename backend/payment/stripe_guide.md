# Stripe決済統合 完全ガイド

## 目次
1. [Stripeとは](#stripeとは)
2. [セットアップ](#セットアップ)
3. [支払い処理](#支払い処理)
4. [サブスクリプション](#サブスクリプション)
5. [Webhook処理](#webhook処理)
6. [顧客管理](#顧客管理)
7. [セキュリティ](#セキュリティ)
8. [ベストプラクティス](#ベストプラクティス)

---

## Stripeとは

Stripeはオンライン決済を簡単に実装できる決済プラットフォームです。

### 主な機能

- **カード決済**: クレジットカード・デビットカード
- **サブスクリプション**: 定期課金
- **請求書**: インボイス発行
- **決済方法**: Apple Pay、Google Pay、銀行振込など

---

## セットアップ

### インストール

```bash
npm install stripe
npm install @stripe/stripe-js # フロントエンド用
```

### 初期化

```typescript
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2024-11-20.acacia',
});
```

### 環境変数

```bash
# .env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

---

## 支払い処理

### Payment Intent（推奨）

```typescript
// バックエンド: Payment Intent作成
app.post('/api/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency = 'jpy' } = req.body;

    const paymentIntent = await stripe.paymentIntents.create({
      amount, // 金額（最小単位：円の場合は1円）
      currency,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        orderId: 'order_123',
        userId: 'user_456',
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    res.status(500).json({ error: 'Payment intent creation failed' });
  }
});
```

### フロントエンド実装

```typescript
import { loadStripe } from '@stripe/stripe-js';
import {
  Elements,
  PaymentElement,
  useStripe,
  useElements,
} from '@stripe/react-stripe-js';

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!);

function CheckoutForm() {
  const stripe = useStripe();
  const elements = useElements();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!stripe || !elements) {
      return;
    }

    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/payment/success`,
      },
    });

    if (error) {
      console.error('Payment failed:', error);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      <button type="submit" disabled={!stripe}>
        支払う
      </button>
    </form>
  );
}

export function CheckoutPage({ clientSecret }: { clientSecret: string }) {
  return (
    <Elements stripe={stripePromise} options={{ clientSecret }}>
      <CheckoutForm />
    </Elements>
  );
}
```

### Checkout Session（簡単実装）

```typescript
// バックエンド
app.post('/api/create-checkout-session', async (req, res) => {
  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'jpy',
            product_data: {
              name: '商品名',
              description: '商品説明',
            },
            unit_amount: 10000, // 10,000円
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: `${req.headers.origin}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${req.headers.origin}/cancel`,
      metadata: {
        orderId: 'order_123',
      },
    });

    res.json({ url: session.url });
  } catch (error) {
    res.status(500).json({ error: 'Checkout session creation failed' });
  }
});

// フロントエンド
async function redirectToCheckout() {
  const response = await fetch('/api/create-checkout-session', {
    method: 'POST',
  });

  const { url } = await response.json();
  window.location.href = url;
}
```

---

## サブスクリプション

### プラン作成

```typescript
// 商品作成
const product = await stripe.products.create({
  name: 'プレミアムプラン',
  description: '月額プレミアム会員',
});

// 価格設定作成
const price = await stripe.prices.create({
  product: product.id,
  unit_amount: 1000, // 1,000円
  currency: 'jpy',
  recurring: {
    interval: 'month', // month, year, week, day
  },
});
```

### サブスクリプション開始

```typescript
app.post('/api/create-subscription', async (req, res) => {
  try {
    const { customerId, priceId } = req.body;

    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: priceId }],
      payment_behavior: 'default_incomplete',
      payment_settings: {
        save_default_payment_method: 'on_subscription',
      },
      expand: ['latest_invoice.payment_intent'],
    });

    res.json({
      subscriptionId: subscription.id,
      clientSecret: (subscription.latest_invoice as any).payment_intent.client_secret,
    });
  } catch (error) {
    res.status(500).json({ error: 'Subscription creation failed' });
  }
});
```

### サブスクリプション管理

```typescript
// サブスクリプション情報取得
const subscription = await stripe.subscriptions.retrieve('sub_xxx');

// サブスクリプション更新
await stripe.subscriptions.update('sub_xxx', {
  items: [
    {
      id: subscription.items.data[0].id,
      price: 'price_new', // 新しいプランに変更
    },
  ],
});

// サブスクリプション一時停止
await stripe.subscriptions.update('sub_xxx', {
  pause_collection: {
    behavior: 'mark_uncollectible',
  },
});

// サブスクリプションキャンセル
await stripe.subscriptions.cancel('sub_xxx');

// 即時キャンセル
await stripe.subscriptions.cancel('sub_xxx', {
  prorate: true,
});
```

### トライアル期間

```typescript
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [{ price: priceId }],
  trial_period_days: 14, // 14日間の無料トライアル
});
```

---

## Webhook処理

### Webhook設定

```typescript
import { buffer } from 'micro';

export const config = {
  api: {
    bodyParser: false, // Rawボディが必要
  },
};

app.post('/api/webhooks/stripe', async (req, res) => {
  const sig = req.headers['stripe-signature'] as string;
  const buf = await buffer(req);

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      buf,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (error) {
    console.error('Webhook signature verification failed:', error);
    return res.status(400).send('Webhook Error');
  }

  // イベント処理
  switch (event.type) {
    case 'payment_intent.succeeded':
      await handlePaymentSuccess(event.data.object as Stripe.PaymentIntent);
      break;

    case 'payment_intent.payment_failed':
      await handlePaymentFailed(event.data.object as Stripe.PaymentIntent);
      break;

    case 'customer.subscription.created':
      await handleSubscriptionCreated(event.data.object as Stripe.Subscription);
      break;

    case 'customer.subscription.updated':
      await handleSubscriptionUpdated(event.data.object as Stripe.Subscription);
      break;

    case 'customer.subscription.deleted':
      await handleSubscriptionCancelled(event.data.object as Stripe.Subscription);
      break;

    case 'invoice.paid':
      await handleInvoicePaid(event.data.object as Stripe.Invoice);
      break;

    case 'invoice.payment_failed':
      await handleInvoicePaymentFailed(event.data.object as Stripe.Invoice);
      break;

    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  res.json({ received: true });
});
```

### イベントハンドラー

```typescript
async function handlePaymentSuccess(paymentIntent: Stripe.PaymentIntent) {
  const { metadata } = paymentIntent;

  // データベース更新
  await db.orders.update({
    where: { id: metadata.orderId },
    data: {
      status: 'paid',
      stripePaymentIntentId: paymentIntent.id,
    },
  });

  // メール送信
  await sendPaymentConfirmationEmail(metadata.userId);
}

async function handleSubscriptionCreated(subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string;

  await db.subscriptions.create({
    data: {
      userId: customerId,
      stripeSubscriptionId: subscription.id,
      status: subscription.status,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
    },
  });
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  await db.subscriptions.update({
    where: { stripeSubscriptionId: subscription.id },
    data: {
      status: subscription.status,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
    },
  });
}

async function handleInvoicePaymentFailed(invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string;

  // ユーザーに支払い失敗を通知
  await sendPaymentFailureEmail(customerId);

  // 一定期間後にサブスクリプションを停止
  if (invoice.attempt_count >= 3) {
    const subscription = invoice.subscription as string;
    await stripe.subscriptions.cancel(subscription);
  }
}
```

---

## 顧客管理

### 顧客作成

```typescript
const customer = await stripe.customers.create({
  email: 'customer@example.com',
  name: 'John Doe',
  metadata: {
    userId: 'user_123',
  },
});
```

### 支払い方法の保存

```typescript
// バックエンド: Setup Intent作成
app.post('/api/create-setup-intent', async (req, res) => {
  const { customerId } = req.body;

  const setupIntent = await stripe.setupIntents.create({
    customer: customerId,
    payment_method_types: ['card'],
  });

  res.json({ clientSecret: setupIntent.client_secret });
});

// フロントエンド: 支払い方法を保存
const { error } = await stripe.confirmSetup({
  elements,
  confirmParams: {
    return_url: `${window.location.origin}/payment-methods`,
  },
});
```

### 保存済み支払い方法で決済

```typescript
const paymentIntent = await stripe.paymentIntents.create({
  amount: 10000,
  currency: 'jpy',
  customer: customerId,
  payment_method: paymentMethodId,
  off_session: true, // ユーザー不在時の決済
  confirm: true,
});
```

### 顧客ポータル

```typescript
// セルフサービスポータルへのリダイレクト
app.post('/api/create-portal-session', async (req, res) => {
  const { customerId } = req.body;

  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: `${req.headers.origin}/account`,
  });

  res.json({ url: session.url });
});
```

---

## セキュリティ

### PCI DSS準拠

```typescript
// ❌ 悪い例: カード情報をサーバーで扱う
app.post('/api/process-payment', (req, res) => {
  const { cardNumber, cvc, expMonth, expYear } = req.body;
  // PCI DSS違反！
});

// ✅ 良い例: Stripe Elementsを使用
// フロントエンドで直接Stripeに送信
<Elements stripe={stripePromise}>
  <PaymentElement />
</Elements>
```

### Webhook署名検証

```typescript
// 必ず署名を検証
try {
  event = stripe.webhooks.constructEvent(
    payload,
    signature,
    webhookSecret
  );
} catch (error) {
  return res.status(400).send('Invalid signature');
}
```

### Idempotency Key

```typescript
// 重複リクエスト防止
const paymentIntent = await stripe.paymentIntents.create(
  {
    amount: 10000,
    currency: 'jpy',
  },
  {
    idempotencyKey: `payment_${orderId}`,
  }
);
```

---

## ベストプラクティス

### 1. エラーハンドリング

```typescript
async function createPayment(amount: number) {
  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: 'jpy',
    });

    return { success: true, paymentIntent };
  } catch (error) {
    if (error instanceof Stripe.errors.StripeCardError) {
      // カードエラー
      return { success: false, error: 'カードが拒否されました' };
    } else if (error instanceof Stripe.errors.StripeRateLimitError) {
      // レート制限
      return { success: false, error: 'リクエストが多すぎます' };
    } else if (error instanceof Stripe.errors.StripeInvalidRequestError) {
      // 無効なパラメータ
      return { success: false, error: 'リクエストが無効です' };
    } else {
      // その他のエラー
      return { success: false, error: '決済に失敗しました' };
    }
  }
}
```

### 2. 金額の扱い

```typescript
// 通貨の最小単位で扱う
function convertToStripeAmount(amount: number, currency: string): number {
  // 日本円: 1円 = 1
  // USD: $1.00 = 100
  if (currency === 'jpy') {
    return Math.round(amount);
  }
  return Math.round(amount * 100);
}

// 使用例
const amount = 1000; // 1,000円
const stripeAmount = convertToStripeAmount(amount, 'jpy'); // 1000
```

### 3. メタデータ活用

```typescript
const paymentIntent = await stripe.paymentIntents.create({
  amount: 10000,
  currency: 'jpy',
  metadata: {
    orderId: 'order_123',
    userId: 'user_456',
    productId: 'prod_789',
    source: 'web',
  },
});

// メタデータは後から検索可能
const payments = await stripe.paymentIntents.list({
  limit: 10,
});
```

### 4. テストモード

```typescript
// テストカード番号
const testCards = {
  success: '4242424242424242',
  decline: '4000000000000002',
  insufficientFunds: '4000000000009995',
  requiresAuthentication: '4000002500003155',
};

// 環境判定
const isProduction = process.env.NODE_ENV === 'production';
const stripeKey = isProduction
  ? process.env.STRIPE_SECRET_KEY_LIVE
  : process.env.STRIPE_SECRET_KEY_TEST;
```

### 5. ロギング & モニタリング

```typescript
async function logStripeEvent(event: Stripe.Event) {
  await db.stripeEvents.create({
    data: {
      eventId: event.id,
      type: event.type,
      createdAt: new Date(event.created * 1000),
      data: event.data.object,
    },
  });
}

// Webhook処理でログ記録
app.post('/api/webhooks/stripe', async (req, res) => {
  const event = stripe.webhooks.constructEvent(/* ... */);

  await logStripeEvent(event);

  // イベント処理...
});
```

### 6. リトライロジック

```typescript
async function retryableStripeRequest<T>(
  operation: () => Promise<T>,
  maxRetries = 3
): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (error) {
      if (error instanceof Stripe.errors.StripeRateLimitError && i < maxRetries - 1) {
        // 指数バックオフ
        await new Promise((resolve) => setTimeout(resolve, Math.pow(2, i) * 1000));
        continue;
      }
      throw error;
    }
  }

  throw new Error('Max retries exceeded');
}

// 使用例
const customer = await retryableStripeRequest(() =>
  stripe.customers.create({ email: 'test@example.com' })
);
```

---

## 参考リンク

- [Stripe Documentation](https://stripe.com/docs)
- [Stripe API Reference](https://stripe.com/docs/api)
- [Testing Stripe](https://stripe.com/docs/testing)
