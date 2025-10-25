# Webセキュリティ 完全ガイド

## 目次
1. [Webセキュリティとは](#webセキュリティとは)
2. [OWASP Top 10](#owasp-top-10)
3. [認証・認可](#認証認可)
4. [XSS対策](#xss対策)
5. [CSRF対策](#csrf対策)
6. [SQL Injection対策](#sql-injection対策)
7. [セキュリティヘッダー](#セキュリティヘッダー)
8. [ベストプラクティス](#ベストプラクティス)

---

## Webセキュリティとは

Webアプリケーションを脅威から保護するための対策と実践です。

### 主な脅威

- **XSS**: クロスサイトスクリプティング
- **CSRF**: クロスサイトリクエストフォージェリ
- **SQL Injection**: SQLインジェクション
- **認証・認可の不備**
- **データ漏洩**

---

## OWASP Top 10

### 1. Broken Access Control

```typescript
// 悪い例: ユーザーIDをURLから取得
app.get('/api/users/:userId', async (req, res) => {
  const user = await db.users.findById(req.params.userId);
  res.json(user); // 他人の情報も見える
});

// 良い例: 認証済みユーザーのみアクセス可
app.get('/api/users/:userId', authenticateToken, async (req, res) => {
  const { userId } = req.params;

  // 本人または管理者のみ
  if (req.user.id !== userId && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const user = await db.users.findById(userId);
  res.json(user);
});
```

### 2. Cryptographic Failures

```typescript
import bcrypt from 'bcrypt';

// パスワードのハッシュ化
async function hashPassword(password: string) {
  const saltRounds = 10;
  return await bcrypt.hash(password, saltRounds);
}

// パスワード検証
async function verifyPassword(password: string, hash: string) {
  return await bcrypt.compare(password, hash);
}

// 使用例
const hashedPassword = await hashPassword('mypassword');
const isValid = await verifyPassword('mypassword', hashedPassword);
```

### 3. Injection

```typescript
// SQL Injection対策 - パラメータ化クエリ
import { Pool } from 'pg';

const pool = new Pool();

// 悪い例
async function badQuery(username: string) {
  const query = `SELECT * FROM users WHERE username = '${username}'`;
  return await pool.query(query); // SQL Injection可能
}

// 良い例
async function goodQuery(username: string) {
  const query = 'SELECT * FROM users WHERE username = $1';
  return await pool.query(query, [username]); // 安全
}
```

---

## 認証・認可

### JWT認証

```typescript
import jwt from 'jsonwebtoken';

const SECRET_KEY = process.env.JWT_SECRET!;

// トークン生成
function generateToken(userId: string) {
  return jwt.sign({ userId }, SECRET_KEY, {
    expiresIn: '24h',
  });
}

// トークン検証
function verifyToken(token: string) {
  try {
    return jwt.verify(token, SECRET_KEY);
  } catch (error) {
    return null;
  }
}

// Express ミドルウェア
function authenticateToken(req: any, res: any, next: any) {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const payload = verifyToken(token);
  if (!payload) {
    return res.status(403).json({ error: 'Invalid token' });
  }

  req.user = payload;
  next();
}
```

---

## XSS対策

### サニタイゼーション

```typescript
import DOMPurify from 'isomorphic-dompurify';

// HTML サニタイゼーション
function sanitizeHTML(dirty: string) {
  return DOMPurify.sanitize(dirty);
}

// 使用例
app.post('/api/posts', async (req, res) => {
  const { title, content } = req.body;

  const sanitizedContent = sanitizeHTML(content);

  await db.posts.create({
    title,
    content: sanitizedContent,
  });

  res.json({ message: 'Post created' });
});
```

### Content Security Policy

```typescript
import helmet from 'helmet';

app.use(
  helmet.contentSecurityPolicy({
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", 'cdn.example.com'],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", 'api.example.com'],
      fontSrc: ["'self'", 'fonts.gstatic.com'],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  })
);
```

---

## CSRF対策

### CSRFトークン

```typescript
import csrf from 'csurf';

const csrfProtection = csrf({ cookie: true });

// トークン生成
app.get('/api/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

// トークン検証
app.post('/api/transfer', csrfProtection, async (req, res) => {
  // CSRFトークンが有効な場合のみ処理
  await processTransfer(req.body);
  res.json({ message: 'Success' });
});
```

### SameSite Cookie

```typescript
app.use(
  session({
    secret: 'your-secret',
    cookie: {
      httpOnly: true,
      secure: true, // HTTPS のみ
      sameSite: 'strict', // CSRF対策
      maxAge: 24 * 60 * 60 * 1000, // 24時間
    },
  })
);
```

---

## SQL Injection対策

### ORM使用

```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// 安全なクエリ
async function getUser(email: string) {
  return await prisma.user.findUnique({
    where: { email }, // パラメータ化される
  });
}

// 複雑なクエリも安全
async function searchUsers(keyword: string) {
  return await prisma.user.findMany({
    where: {
      OR: [
        { name: { contains: keyword } },
        { email: { contains: keyword } },
      ],
    },
  });
}
```

---

## セキュリティヘッダー

### Helmet.js

```typescript
import helmet from 'helmet';

app.use(helmet());

// カスタム設定
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
      },
    },
    hsts: {
      maxAge: 31536000, // 1年
      includeSubDomains: true,
      preload: true,
    },
    frameguard: {
      action: 'deny',
    },
    noSniff: true,
    xssFilter: true,
  })
);
```

### 重要なヘッダー

```typescript
app.use((req, res, next) => {
  // HSTS
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');

  // XSS Protection
  res.setHeader('X-XSS-Protection', '1; mode=block');

  // MIME Sniffing防止
  res.setHeader('X-Content-Type-Options', 'nosniff');

  // Clickjacking防止
  res.setHeader('X-Frame-Options', 'DENY');

  // Referrer Policy
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

  next();
});
```

---

## ベストプラクティス

### 1. 入力バリデーション

```typescript
import { z } from 'zod';

const userSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(100),
  name: z.string().min(2).max(50),
});

app.post('/api/register', async (req, res) => {
  try {
    const validated = userSchema.parse(req.body);

    // 処理...
    res.json({ message: 'User created' });
  } catch (error) {
    res.status(400).json({ error: 'Invalid input' });
  }
});
```

### 2. レート制限

```typescript
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 100, // 最大100リクエスト
  message: 'Too many requests',
});

app.use('/api/', limiter);

// ログインエンドポイント用の厳しい制限
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: 'Too many login attempts',
});

app.post('/api/login', loginLimiter, async (req, res) => {
  // ログイン処理
});
```

### 3. セキュアなセッション管理

```typescript
import session from 'express-session';
import RedisStore from 'connect-redis';
import Redis from 'ioredis';

const redis = new Redis();

app.use(
  session({
    store: new RedisStore({ client: redis }),
    secret: process.env.SESSION_SECRET!,
    resave: false,
    saveUninitialized: false,
    cookie: {
      secure: true, // HTTPS のみ
      httpOnly: true,
      sameSite: 'strict',
      maxAge: 24 * 60 * 60 * 1000,
    },
  })
);
```

---

## 参考リンク

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Helmet.js](https://helmetjs.github.io/)
- [CSRF Protection](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
