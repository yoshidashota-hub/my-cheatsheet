# メール送信サービス 完全ガイド

## 目次
1. [メール送信サービスとは](#メール送信サービスとは)
2. [AWS SES](#aws-ses)
3. [SendGrid](#sendgrid)
4. [Resend](#resend)
5. [Nodemailer](#nodemailer)
6. [テンプレートエンジン](#テンプレートエンジン)
7. [ベストプラクティス](#ベストプラクティス)

---

## メール送信サービスとは

メール送信サービスは、アプリケーションからメールを送信するためのインフラを提供します。

### 主要サービス比較

| サービス | 特徴 | 料金 |
|---------|------|------|
| AWS SES | 高信頼性、低コスト | $0.10/1000通 |
| SendGrid | 豊富な機能、Analytics | 無料枠あり |
| Resend | 開発者フレンドリー | 無料枠あり |
| Mailgun | 強力なAPI | 無料枠あり |

---

## AWS SES

### セットアップ

```typescript
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

const ses = new SESClient({ region: 'us-east-1' });

async function sendEmail(to: string, subject: string, body: string) {
  try {
    const command = new SendEmailCommand({
      Source: 'noreply@example.com',
      Destination: {
        ToAddresses: [to],
      },
      Message: {
        Subject: {
          Data: subject,
        },
        Body: {
          Html: {
            Data: body,
          },
        },
      },
    });

    const response = await ses.send(command);
    console.log('Email sent:', response.MessageId);
    return response.MessageId;
  } catch (error) {
    console.error('Failed to send email:', error);
    throw error;
  }
}
```

### テンプレートメール

```typescript
import { SendTemplatedEmailCommand } from '@aws-sdk/client-ses';

async function sendTemplatedEmail(to: string, templateData: any) {
  const command = new SendTemplatedEmailCommand({
    Source: 'noreply@example.com',
    Destination: {
      ToAddresses: [to],
    },
    Template: 'WelcomeTemplate',
    TemplateData: JSON.stringify(templateData),
  });

  await ses.send(command);
}

// 使用例
await sendTemplatedEmail('user@example.com', {
  name: 'John Doe',
  verificationUrl: 'https://example.com/verify?token=abc123',
});
```

---

## SendGrid

### セットアップ

```typescript
import sgMail from '@sendgrid/mail';

sgMail.setApiKey(process.env.SENDGRID_API_KEY!);

async function sendEmailWithSendGrid(to: string, subject: string, html: string) {
  try {
    await sgMail.send({
      to,
      from: 'noreply@example.com',
      subject,
      html,
    });

    console.log('Email sent successfully');
  } catch (error) {
    console.error('SendGrid error:', error);
    throw error;
  }
}
```

### ダイナミックテンプレート

```typescript
async function sendDynamicTemplate(to: string, templateId: string, data: any) {
  await sgMail.send({
    to,
    from: 'noreply@example.com',
    templateId,
    dynamicTemplateData: data,
  });
}

// 使用例
await sendDynamicTemplate('user@example.com', 'd-abc123', {
  name: 'John Doe',
  verificationUrl: 'https://example.com/verify?token=abc123',
});
```

---

## Resend

### セットアップ

```typescript
import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

async function sendEmailWithResend(to: string, subject: string, html: string) {
  try {
    const { data, error } = await resend.emails.send({
      from: 'noreply@example.com',
      to,
      subject,
      html,
    });

    if (error) {
      throw error;
    }

    console.log('Email sent:', data);
    return data;
  } catch (error) {
    console.error('Resend error:', error);
    throw error;
  }
}
```

### React Email との統合

```typescript
import { render } from '@react-email/render';
import { WelcomeEmail } from './emails/WelcomeEmail';

async function sendWelcomeEmail(to: string, name: string) {
  const emailHtml = render(WelcomeEmail({ name }));

  await resend.emails.send({
    from: 'noreply@example.com',
    to,
    subject: 'Welcome!',
    html: emailHtml,
  });
}
```

---

## Nodemailer

### SMTP設定

```typescript
import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransporter({
  host: 'smtp.gmail.com',
  port: 587,
  secure: false,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

async function sendEmailWithNodemailer(to: string, subject: string, html: string) {
  try {
    const info = await transporter.sendMail({
      from: '"My App" <noreply@example.com>',
      to,
      subject,
      html,
    });

    console.log('Email sent:', info.messageId);
    return info.messageId;
  } catch (error) {
    console.error('Nodemailer error:', error);
    throw error;
  }
}
```

---

## テンプレートエンジン

### Handlebars

```typescript
import Handlebars from 'handlebars';
import fs from 'fs';

const templateSource = fs.readFileSync('templates/welcome.hbs', 'utf-8');
const template = Handlebars.compile(templateSource);

const html = template({
  name: 'John Doe',
  verificationUrl: 'https://example.com/verify?token=abc123',
});

await sendEmail('user@example.com', 'Welcome!', html);
```

### React Email

```tsx
// emails/WelcomeEmail.tsx
import { Html, Head, Body, Container, Heading, Text, Button } from '@react-email/components';

export function WelcomeEmail({ name }: { name: string }) {
  return (
    <Html>
      <Head />
      <Body>
        <Container>
          <Heading>Welcome, {name}!</Heading>
          <Text>Thanks for joining us.</Text>
          <Button href="https://example.com">Get Started</Button>
        </Container>
      </Body>
    </Html>
  );
}
```

---

## ベストプラクティス

### 1. メールキュー

```typescript
import Bull from 'bull';

const emailQueue = new Bull('email', {
  redis: {
    host: 'localhost',
    port: 6379,
  },
});

emailQueue.process(async (job) => {
  const { to, subject, html } = job.data;
  await sendEmail(to, subject, html);
});

// メール送信をキューに追加
await emailQueue.add({
  to: 'user@example.com',
  subject: 'Hello',
  html: '<p>World</p>',
});
```

### 2. エラーハンドリング

```typescript
async function sendEmailSafely(to: string, subject: string, html: string) {
  const maxRetries = 3;
  let lastError: Error | null = null;

  for (let i = 0; i < maxRetries; i++) {
    try {
      await sendEmail(to, subject, html);
      return;
    } catch (error) {
      lastError = error as Error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }

  throw lastError;
}
```

### 3. レート制限

```typescript
import pLimit from 'p-limit';

const limit = pLimit(10); // 同時実行数を10に制限

const promises = users.map(user =>
  limit(() => sendEmail(user.email, 'Update', html))
);

await Promise.all(promises);
```

---

## 参考リンク

- [AWS SES Documentation](https://docs.aws.amazon.com/ses/)
- [SendGrid Documentation](https://docs.sendgrid.com/)
- [Resend Documentation](https://resend.com/docs)
- [Nodemailer](https://nodemailer.com/)
