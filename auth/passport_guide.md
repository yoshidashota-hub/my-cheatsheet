# Passport.js 完全ガイド

## 目次
- [Passport.jsとは](#passportjsとは)
- [セットアップ](#セットアップ)
- [ローカル認証](#ローカル認証)
- [JWT認証](#jwt認証)
- [OAuth認証](#oauth認証)
- [セッション管理](#セッション管理)
- [ミドルウェア](#ミドルウェア)

---

## Passport.jsとは

Node.js向けの認証ミドルウェア。500以上のストラテジーで多様な認証方式に対応。

### 特徴
- 🔐 柔軟な認証方式
- 🔌 500+のストラテジー
- 🎯 シンプルなAPI
- 🌐 Express/Fastify対応

### 主要ストラテジー
- Local (ユーザー名・パスワード)
- JWT (JSON Web Token)
- OAuth (Google, GitHub, Facebook等)

---

## セットアップ

### インストール

```bash
npm install passport
npm install passport-local
npm install passport-jwt
npm install passport-google-oauth20
```

### Express統合

```typescript
import express from 'express'
import passport from 'passport'
import session from 'express-session'

const app = express()

// セッション設定
app.use(session({
  secret: 'your-secret-key',
  resave: false,
  saveUninitialized: false
}))

// Passport初期化
app.use(passport.initialize())
app.use(passport.session())
```

---

## ローカル認証

### ストラテジー設定

```typescript
import passport from 'passport'
import { Strategy as LocalStrategy } from 'passport-local'
import bcrypt from 'bcrypt'
import { findUserByEmail, findUserById } from './db'

// Local Strategy設定
passport.use(new LocalStrategy(
  {
    usernameField: 'email',
    passwordField: 'password'
  },
  async (email, password, done) => {
    try {
      // ユーザー検索
      const user = await findUserByEmail(email)
      if (!user) {
        return done(null, false, { message: 'Invalid email' })
      }

      // パスワード検証
      const isValid = await bcrypt.compare(password, user.password)
      if (!isValid) {
        return done(null, false, { message: 'Invalid password' })
      }

      return done(null, user)
    } catch (error) {
      return done(error)
    }
  }
))

// シリアライズ
passport.serializeUser((user: any, done) => {
  done(null, user.id)
})

// デシリアライズ
passport.deserializeUser(async (id: string, done) => {
  try {
    const user = await findUserById(id)
    done(null, user)
  } catch (error) {
    done(error)
  }
})
```

### ログインエンドポイント

```typescript
import { Router } from 'express'

const router = Router()

// ログイン
router.post('/login',
  passport.authenticate('local', {
    successRedirect: '/dashboard',
    failureRedirect: '/login',
    failureFlash: true
  })
)

// カスタムコールバック
router.post('/login', (req, res, next) => {
  passport.authenticate('local', (err, user, info) => {
    if (err) return next(err)
    if (!user) return res.status(401).json({ message: info.message })

    req.logIn(user, (err) => {
      if (err) return next(err)
      return res.json({ user })
    })
  })(req, res, next)
})

// ログアウト
router.post('/logout', (req, res) => {
  req.logout((err) => {
    if (err) return res.status(500).json({ error: err })
    res.json({ message: 'Logged out' })
  })
})
```

---

## JWT認証

### ストラテジー設定

```typescript
import { Strategy as JwtStrategy, ExtractJwt } from 'passport-jwt'

const options = {
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: process.env.JWT_SECRET || 'your-secret'
}

passport.use(new JwtStrategy(options, async (payload, done) => {
  try {
    const user = await findUserById(payload.sub)
    if (user) {
      return done(null, user)
    }
    return done(null, false)
  } catch (error) {
    return done(error, false)
  }
}))
```

### トークン生成

```typescript
import jwt from 'jsonwebtoken'

router.post('/login', async (req, res) => {
  const { email, password } = req.body

  const user = await findUserByEmail(email)
  if (!user) {
    return res.status(401).json({ message: 'Invalid credentials' })
  }

  const isValid = await bcrypt.compare(password, user.password)
  if (!isValid) {
    return res.status(401).json({ message: 'Invalid credentials' })
  }

  // JWT生成
  const token = jwt.sign(
    { sub: user.id, email: user.email },
    process.env.JWT_SECRET!,
    { expiresIn: '7d' }
  )

  res.json({ token, user })
})
```

### 保護されたルート

```typescript
router.get('/profile',
  passport.authenticate('jwt', { session: false }),
  (req, res) => {
    res.json({ user: req.user })
  }
)
```

---

## OAuth認証

### Google OAuth

```bash
npm install passport-google-oauth20
```

```typescript
import { Strategy as GoogleStrategy } from 'passport-google-oauth20'

passport.use(new GoogleStrategy(
  {
    clientID: process.env.GOOGLE_CLIENT_ID!,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    callbackURL: 'http://localhost:3000/auth/google/callback'
  },
  async (accessToken, refreshToken, profile, done) => {
    try {
      // ユーザー検索または作成
      let user = await findUserByGoogleId(profile.id)

      if (!user) {
        user = await createUser({
          googleId: profile.id,
          email: profile.emails?.[0].value,
          name: profile.displayName,
          avatar: profile.photos?.[0].value
        })
      }

      return done(null, user)
    } catch (error) {
      return done(error as Error)
    }
  }
))
```

### OAuth ルート

```typescript
// Google認証開始
router.get('/auth/google',
  passport.authenticate('google', {
    scope: ['profile', 'email']
  })
)

// コールバック
router.get('/auth/google/callback',
  passport.authenticate('google', { failureRedirect: '/login' }),
  (req, res) => {
    res.redirect('/dashboard')
  }
)
```

### GitHub OAuth

```bash
npm install passport-github2
```

```typescript
import { Strategy as GitHubStrategy } from 'passport-github2'

passport.use(new GitHubStrategy(
  {
    clientID: process.env.GITHUB_CLIENT_ID!,
    clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    callbackURL: 'http://localhost:3000/auth/github/callback'
  },
  async (accessToken, refreshToken, profile, done) => {
    try {
      let user = await findUserByGitHubId(profile.id)

      if (!user) {
        user = await createUser({
          githubId: profile.id,
          username: profile.username,
          email: profile.emails?.[0].value,
          avatar: profile.photos?.[0].value
        })
      }

      return done(null, user)
    } catch (error) {
      return done(error as Error)
    }
  }
))

router.get('/auth/github',
  passport.authenticate('github', { scope: ['user:email'] })
)

router.get('/auth/github/callback',
  passport.authenticate('github', { failureRedirect: '/login' }),
  (req, res) => {
    res.redirect('/dashboard')
  }
)
```

---

## セッション管理

### セッションストア

```bash
npm install express-session connect-redis redis
```

```typescript
import session from 'express-session'
import RedisStore from 'connect-redis'
import { createClient } from 'redis'

const redisClient = createClient({
  url: process.env.REDIS_URL
})
redisClient.connect()

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET!,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 1000 * 60 * 60 * 24 * 7 // 7 days
  }
}))
```

---

## ミドルウェア

### 認証チェック

```typescript
// 認証必須
export function isAuthenticated(req: Request, res: Response, next: NextFunction) {
  if (req.isAuthenticated()) {
    return next()
  }
  res.status(401).json({ message: 'Unauthorized' })
}

// 使用例
router.get('/dashboard', isAuthenticated, (req, res) => {
  res.json({ user: req.user })
})
```

### ロールベース認証

```typescript
export function hasRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.isAuthenticated()) {
      return res.status(401).json({ message: 'Unauthorized' })
    }

    const user = req.user as any
    if (!roles.includes(user.role)) {
      return res.status(403).json({ message: 'Forbidden' })
    }

    next()
  }
}

// 使用例
router.get('/admin', hasRole('admin'), (req, res) => {
  res.json({ message: 'Admin only' })
})
```

---

## TypeScript型定義

```typescript
// types/express.d.ts
import { User } from './models'

declare global {
  namespace Express {
    interface User {
      id: string
      email: string
      name: string
      role: string
    }
  }
}
```

---

## 複数ストラテジー

```typescript
// 複数のストラテジーを使用
router.post('/login',
  passport.authenticate(['local', 'jwt'], { session: false }),
  (req, res) => {
    res.json({ user: req.user })
  }
)

// カスタム認証ロジック
passport.use('custom', new CustomStrategy(
  async (req, done) => {
    try {
      const apiKey = req.headers['x-api-key']
      if (!apiKey) return done(null, false)

      const user = await findUserByApiKey(apiKey as string)
      if (!user) return done(null, false)

      return done(null, user)
    } catch (error) {
      return done(error)
    }
  }
))
```

---

## セキュリティ

### レート制限

```bash
npm install express-rate-limit
```

```typescript
import rateLimit from 'express-rate-limit'

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 5, // 5回まで
  message: 'Too many login attempts'
})

router.post('/login', loginLimiter, passport.authenticate('local'))
```

### CSRF対策

```bash
npm install csurf
```

```typescript
import csrf from 'csurf'

app.use(csrf({ cookie: true }))

router.get('/login', (req, res) => {
  res.render('login', { csrfToken: req.csrfToken() })
})
```

---

## 参考リンク

- [Passport.js 公式](http://www.passportjs.org/)
- [Strategies](http://www.passportjs.org/packages/)
