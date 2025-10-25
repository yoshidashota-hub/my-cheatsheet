# APIセキュリティ 完全ガイド

## 目次
1. [APIセキュリティとは](#apiセキュリティとは)
2. [認証方式](#認証方式)
3. [APIキー管理](#apiキー管理)
4. [OAuth 2.0](#oauth-20)
5. [レート制限](#レート制限)
6. [APIゲートウェイ](#apiゲートウェイ)
7. [ベストプラクティス](#ベストプラクティス)

---

## APIセキュリティとは

APIを不正アクセスや攻撃から保護するための対策です。

### 主な脅威

- **認証・認可の不備**
- **APIキーの漏洩**
- **DDoS攻撃**
- **データ漏洩**
- **不正なリクエスト**

---

## 認証方式

### 1. Bearer Token (JWT)

```typescript
import jwt from 'jsonwebtoken';

// トークン生成
function generateToken(userId: string, role: string) {
  return jwt.sign(
    {
      userId,
      role,
    },
    process.env.JWT_SECRET!,
    { expiresIn: '1h' }
  );
}

// 検証ミドルウェア
function authenticateToken(req: any, res: any, next: any) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!);
    req.user = payload;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid token' });
  }
}
```

### 2. API Key

```typescript
function validateApiKey(req: any, res: any, next: any) {
  const apiKey = req.headers['x-api-key'];

  if (!apiKey) {
    return res.status(401).json({ error: 'API key required' });
  }

  // データベースでキー検証
  const isValid = await checkApiKey(apiKey);

  if (!isValid) {
    return res.status(403).json({ error: 'Invalid API key' });
  }

  next();
}

async function checkApiKey(key: string) {
  const apiKey = await db.apiKeys.findOne({
    where: { key, active: true },
  });

  return !!apiKey;
}
```

### 3. Basic Authentication

```typescript
import basicAuth from 'express-basic-auth';

app.use(
  basicAuth({
    users: {
      admin: 'supersecret',
    },
    challenge: true,
  })
);

// または
function basicAuthMiddleware(req: any, res: any, next: any) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Basic ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const credentials = Buffer.from(authHeader.split(' ')[1], 'base64').toString();
  const [username, password] = credentials.split(':');

  if (username === 'admin' && password === 'secret') {
    next();
  } else {
    res.status(403).json({ error: 'Invalid credentials' });
  }
}
```

---

## APIキー管理

### キー生成

```typescript
import crypto from 'crypto';

function generateApiKey() {
  return crypto.randomBytes(32).toString('hex');
}

// 使用例
app.post('/api/keys', authenticateToken, async (req, res) => {
  const apiKey = generateApiKey();

  await db.apiKeys.create({
    key: apiKey,
    userId: req.user.userId,
    createdAt: new Date(),
    active: true,
  });

  res.json({ apiKey });
});
```

### キーローテーション

```typescript
async function rotateApiKey(oldKey: string) {
  const newKey = generateApiKey();

  await db.apiKeys.update(
    { key: oldKey },
    {
      key: newKey,
      rotatedAt: new Date(),
    }
  );

  return newKey;
}
```

---

## OAuth 2.0

### Authorization Code Flow

```typescript
import { Issuer, generators } from 'openid-client';

// Google OAuth設定
const googleIssuer = await Issuer.discover('https://accounts.google.com');

const client = new googleIssuer.Client({
  client_id: process.env.GOOGLE_CLIENT_ID!,
  client_secret: process.env.GOOGLE_CLIENT_SECRET!,
  redirect_uris: ['http://localhost:3000/callback'],
  response_types: ['code'],
});

// 認証URLの生成
app.get('/auth/google', (req, res) => {
  const codeVerifier = generators.codeVerifier();
  const codeChallenge = generators.codeChallenge(codeVerifier);

  req.session.codeVerifier = codeVerifier;

  const authUrl = client.authorizationUrl({
    scope: 'openid email profile',
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  });

  res.redirect(authUrl);
});

// コールバック処理
app.get('/callback', async (req, res) => {
  const params = client.callbackParams(req);
  const codeVerifier = req.session.codeVerifier;

  const tokenSet = await client.callback(
    'http://localhost:3000/callback',
    params,
    { code_verifier: codeVerifier }
  );

  const userInfo = await client.userinfo(tokenSet.access_token!);

  req.session.user = userInfo;
  res.redirect('/dashboard');
});
```

---

## レート制限

### Express Rate Limit

```typescript
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import Redis from 'ioredis';

const redis = new Redis();

// グローバルレート制限
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 100,
  store: new RedisStore({
    client: redis,
    prefix: 'rl:',
  }),
});

app.use('/api/', globalLimiter);

// エンドポイント別レート制限
const strictLimiter = rateLimit({
  windowMs: 60 * 1000, // 1分
  max: 5,
  message: 'Too many requests',
});

app.post('/api/login', strictLimiter, async (req, res) => {
  // ログイン処理
});

// ユーザー別レート制限
const userLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  keyGenerator: (req) => req.user?.userId || req.ip,
});

app.use('/api/user/', authenticateToken, userLimiter);
```

---

## APIゲートウェイ

### カスタムゲートウェイミドルウェア

```typescript
function apiGateway() {
  return async (req: any, res: any, next: any) => {
    // 1. リクエストロギング
    console.log(`${req.method} ${req.path}`, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });

    // 2. 認証
    const apiKey = req.headers['x-api-key'];
    if (!apiKey) {
      return res.status(401).json({ error: 'API key required' });
    }

    // 3. レート制限チェック
    const rateLimitKey = `rate:${apiKey}`;
    const count = await redis.incr(rateLimitKey);

    if (count === 1) {
      await redis.expire(rateLimitKey, 60);
    }

    if (count > 100) {
      return res.status(429).json({ error: 'Rate limit exceeded' });
    }

    // 4. リクエストバリデーション
    if (req.body && Object.keys(req.body).length > 100) {
      return res.status(400).json({ error: 'Payload too large' });
    }

    // 5. レスポンス時間計測
    const start = Date.now();

    res.on('finish', () => {
      const duration = Date.now() - start;
      console.log(`Response time: ${duration}ms`);
    });

    next();
  };
}

app.use('/api/', apiGateway());
```

---

## ベストプラクティス

### 1. HTTPS強制

```typescript
function forceHTTPS(req: any, res: any, next: any) {
  if (req.secure || req.headers['x-forwarded-proto'] === 'https') {
    return next();
  }

  res.redirect(301, `https://${req.headers.host}${req.url}`);
}

app.use(forceHTTPS);
```

### 2. CORS設定

```typescript
import cors from 'cors';

app.use(
  cors({
    origin: ['https://example.com', 'https://app.example.com'],
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'],
    credentials: true,
    maxAge: 86400, // 1日
  })
);
```

### 3. 入力バリデーション

```typescript
import { z } from 'zod';

const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(100),
  name: z.string().min(2).max(50),
});

app.post('/api/users', async (req, res) => {
  try {
    const validated = createUserSchema.parse(req.body);

    // 処理...
    res.json({ message: 'User created' });
  } catch (error) {
    res.status(400).json({ error: 'Invalid input' });
  }
});
```

### 4. エラーハンドリング

```typescript
app.use((err: Error, req: any, res: any, next: any) => {
  // エラーログ
  console.error('API Error:', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  // 本番環境では詳細なエラーを返さない
  if (process.env.NODE_ENV === 'production') {
    res.status(500).json({
      error: 'Internal server error',
    });
  } else {
    res.status(500).json({
      error: err.message,
      stack: err.stack,
    });
  }
});
```

### 5. APIバージョニング

```typescript
// URLパスバージョニング
app.use('/api/v1', v1Routes);
app.use('/api/v2', v2Routes);

// ヘッダーバージョニング
function versionMiddleware(req: any, res: any, next: any) {
  const version = req.headers['api-version'] || '1';

  if (version === '2') {
    req.apiVersion = 2;
  } else {
    req.apiVersion = 1;
  }

  next();
}

app.use(versionMiddleware);
```

---

## 参考リンク

- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [OAuth 2.0](https://oauth.net/2/)
