# モダン認証サービスガイド

Next.js/Reactアプリケーション向けの最新認証サービスとその実装方法をまとめたガイドです。

## サービス比較

| サービス | 料金 | セットアップ | 機能 | カスタマイズ性 | おすすめ度 |
|---------|------|------------|------|--------------|-----------|
| **Clerk** | 無料〜 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Lucia** | 無料 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Better Auth** | 無料 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **NextAuth.js** | 無料 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

### 選択基準

- **Clerk**: 最速でプロダクション品質の認証を実装したい
- **Lucia**: 完全なカスタマイズと制御が必要
- **Better Auth**: モダンで型安全なAPIが欲しい
- **NextAuth.js**: 実績のある安定したソリューション

## Clerk

### 特徴

- **フルマネージド**: 完全ホスト型、インフラ不要
- **UIコンポーネント**: 美しい認証UIが提供済み
- **多要素認証**: SMS、TOTP、バックアップコード
- **組織管理**: マルチテナントに対応
- **セッション管理**: 自動更新、デバイス管理

### 料金

- **Free**: 月10,000 MAU（アクティブユーザー）
- **Pro**: $25/月 + 月10,000 MAU以降 $0.02/MAU
- **Enterprise**: カスタム価格

### インストール

```bash
npm install @clerk/nextjs
```

### 設定

```typescript
// app/layout.tsx
import { ClerkProvider } from '@clerk/nextjs'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <ClerkProvider>
      <html lang="ja">
        <body>{children}</body>
      </html>
    </ClerkProvider>
  )
}
```

```bash
# .env.local
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_xxxxx
CLERK_SECRET_KEY=sk_test_xxxxx
```

### ミドルウェア

```typescript
// middleware.ts
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

const isPublicRoute = createRouteMatcher(['/sign-in(.*)', '/sign-up(.*)', '/'])

export default clerkMiddleware((auth, request) => {
  if (!isPublicRoute(request)) {
    auth().protect()
  }
})

export const config = {
  matcher: ['/((?!.*\\..*|_next).*)', '/', '/(api|trpc)(.*)'],
}
```

### 認証UIコンポーネント

```typescript
// app/sign-in/[[...sign-in]]/page.tsx
import { SignIn } from '@clerk/nextjs'

export default function SignInPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <SignIn />
    </div>
  )
}

// app/sign-up/[[...sign-up]]/page.tsx
import { SignUp } from '@clerk/nextjs'

export default function SignUpPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <SignUp />
    </div>
  )
}
```

### ユーザー情報取得

```typescript
// Server Component
import { currentUser } from '@clerk/nextjs/server'

export default async function Dashboard() {
  const user = await currentUser()

  if (!user) {
    return <div>Please sign in</div>
  }

  return (
    <div>
      <h1>Welcome, {user.firstName}!</h1>
      <p>Email: {user.emailAddresses[0].emailAddress}</p>
    </div>
  )
}
```

```typescript
// Client Component
'use client'

import { useUser } from '@clerk/nextjs'

export default function UserProfile() {
  const { user, isLoaded } = useUser()

  if (!isLoaded) return <div>Loading...</div>
  if (!user) return <div>Not signed in</div>

  return (
    <div>
      <h2>{user.fullName}</h2>
      <p>{user.primaryEmailAddress?.emailAddress}</p>
    </div>
  )
}
```

### 組織管理

```typescript
'use client'

import { useOrganization, useOrganizationList } from '@clerk/nextjs'

export default function OrganizationSwitcher() {
  const { organization } = useOrganization()
  const { organizationList, setActive } = useOrganizationList()

  return (
    <div>
      <h3>Current Organization: {organization?.name}</h3>
      <select
        onChange={(e) => setActive({ organization: e.target.value })}
        value={organization?.id}
      >
        {organizationList?.map((org) => (
          <option key={org.organization.id} value={org.organization.id}>
            {org.organization.name}
          </option>
        ))}
      </select>
    </div>
  )
}
```

## Lucia

### 特徴

- **ライブラリ**: フレームワーク、データベース非依存
- **型安全**: 完全TypeScript対応
- **セッション管理**: 柔軟なセッション制御
- **カスタマイズ**: 完全な制御が可能
- **無料**: オープンソース

### インストール

```bash
npm install lucia
npm install @lucia-auth/adapter-prisma
```

### 設定（Prisma使用）

```prisma
// prisma/schema.prisma
model User {
  id       String    @id @default(cuid())
  email    String    @unique
  name     String?
  sessions Session[]
}

model Session {
  id        String   @id
  userId    String
  expiresAt DateTime
  user      User     @relation(references: [id], fields: [userId], onDelete: Cascade)
}
```

```typescript
// lib/auth.ts
import { Lucia } from 'lucia'
import { PrismaAdapter } from '@lucia-auth/adapter-prisma'
import { prisma } from './db'

const adapter = new PrismaAdapter(prisma.session, prisma.user)

export const lucia = new Lucia(adapter, {
  sessionCookie: {
    expires: false,
    attributes: {
      secure: process.env.NODE_ENV === 'production',
    },
  },
  getUserAttributes: (attributes) => {
    return {
      email: attributes.email,
      name: attributes.name,
    }
  },
})

declare module 'lucia' {
  interface Register {
    Lucia: typeof lucia
    DatabaseUserAttributes: {
      email: string
      name: string | null
    }
  }
}
```

### サインアップ

```typescript
// app/api/signup/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { lucia } from '@/lib/auth'
import { prisma } from '@/lib/db'
import { hash } from '@node-rs/argon2'
import { cookies } from 'next/headers'

export async function POST(request: NextRequest) {
  const { email, password, name } = await request.json()

  // パスワードハッシュ化
  const passwordHash = await hash(password, {
    memoryCost: 19456,
    timeCost: 2,
    outputLen: 32,
    parallelism: 1,
  })

  // ユーザー作成
  const user = await prisma.user.create({
    data: {
      email,
      name,
      passwordHash,
    },
  })

  // セッション作成
  const session = await lucia.createSession(user.id, {})
  const sessionCookie = lucia.createSessionCookie(session.id)

  cookies().set(sessionCookie.name, sessionCookie.value, sessionCookie.attributes)

  return NextResponse.json({ success: true })
}
```

### サインイン

```typescript
// app/api/signin/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { lucia } from '@/lib/auth'
import { prisma } from '@/lib/db'
import { verify } from '@node-rs/argon2'
import { cookies } from 'next/headers'

export async function POST(request: NextRequest) {
  const { email, password } = await request.json()

  // ユーザー検索
  const user = await prisma.user.findUnique({
    where: { email },
  })

  if (!user) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 400 })
  }

  // パスワード検証
  const validPassword = await verify(user.passwordHash, password)

  if (!validPassword) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 400 })
  }

  // セッション作成
  const session = await lucia.createSession(user.id, {})
  const sessionCookie = lucia.createSessionCookie(session.id)

  cookies().set(sessionCookie.name, sessionCookie.value, sessionCookie.attributes)

  return NextResponse.json({ success: true })
}
```

### セッション検証

```typescript
// lib/auth-utils.ts
import { lucia } from './auth'
import { cookies } from 'next/headers'
import { cache } from 'react'

export const getCurrentUser = cache(async () => {
  const sessionId = cookies().get(lucia.sessionCookieName)?.value ?? null

  if (!sessionId) {
    return { user: null, session: null }
  }

  const result = await lucia.validateSession(sessionId)

  try {
    if (result.session && result.session.fresh) {
      const sessionCookie = lucia.createSessionCookie(result.session.id)
      cookies().set(sessionCookie.name, sessionCookie.value, sessionCookie.attributes)
    }
    if (!result.session) {
      const sessionCookie = lucia.createBlankSessionCookie()
      cookies().set(sessionCookie.name, sessionCookie.value, sessionCookie.attributes)
    }
  } catch {}

  return result
})
```

## Better Auth

### 特徴

- **モダン**: Next.js App Router最適化
- **型安全**: 完全TypeScript
- **プラグイン**: 拡張可能なアーキテクチャ
- **多機能**: OAuth、メール認証等をサポート

### インストール

```bash
npm install better-auth
```

### 設定

```typescript
// lib/auth.ts
import { betterAuth } from 'better-auth'
import { prismaAdapter } from 'better-auth/adapters/prisma'
import { prisma } from './db'

export const auth = betterAuth({
  database: prismaAdapter(prisma, {
    provider: 'postgresql',
  }),
  emailAndPassword: {
    enabled: true,
  },
  socialProviders: {
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    },
    github: {
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    },
  },
})
```

### API Route

```typescript
// app/api/auth/[...all]/route.ts
import { auth } from '@/lib/auth'

export const { GET, POST } = auth.handler
```

### クライアント設定

```typescript
// lib/auth-client.ts
import { createAuthClient } from 'better-auth/client'

export const authClient = createAuthClient({
  baseURL: process.env.NEXT_PUBLIC_APP_URL,
})
```

### 使用例

```typescript
'use client'

import { authClient } from '@/lib/auth-client'
import { useState } from 'react'

export default function SignInForm() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    await authClient.signIn.email({
      email,
      password,
    })

    // リダイレクト
    window.location.href = '/dashboard'
  }

  const handleGoogleSignIn = async () => {
    await authClient.signIn.social({
      provider: 'google',
      callbackURL: '/dashboard',
    })
  }

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
      />
      <button type="submit">Sign In</button>
      <button type="button" onClick={handleGoogleSignIn}>
        Sign in with Google
      </button>
    </form>
  )
}
```

## NextAuth.js v5 (Auth.js)

### 特徴

- **実績**: 広く使われている
- **多様なプロバイダー**: OAuth、メール等
- **Next.js統合**: App Router対応
- **コミュニティ**: 豊富なリソース

### インストール

```bash
npm install next-auth@beta
```

### 設定

```typescript
// auth.ts
import NextAuth from 'next-auth'
import GitHub from 'next-auth/providers/github'
import Google from 'next-auth/providers/google'
import Credentials from 'next-auth/providers/credentials'

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    GitHub,
    Google,
    Credentials({
      credentials: {
        email: {},
        password: {},
      },
      authorize: async (credentials) => {
        // ユーザー検証ロジック
        const user = await verifyUser(credentials.email, credentials.password)
        if (user) {
          return user
        }
        return null
      },
    }),
  ],
  callbacks: {
    session({ session, token }) {
      session.user.id = token.sub!
      return session
    },
  },
})
```

```typescript
// app/api/auth/[...nextauth]/route.ts
import { handlers } from '@/auth'

export const { GET, POST } = handlers
```

### 使用例

```typescript
// Server Component
import { auth } from '@/auth'

export default async function Dashboard() {
  const session = await auth()

  if (!session) {
    return <div>Not authenticated</div>
  }

  return <div>Welcome, {session.user?.name}!</div>
}
```

```typescript
// Client Component
'use client'

import { useSession, signIn, signOut } from 'next-auth/react'

export default function UserMenu() {
  const { data: session, status } = useSession()

  if (status === 'loading') {
    return <div>Loading...</div>
  }

  if (!session) {
    return <button onClick={() => signIn()}>Sign In</button>
  }

  return (
    <div>
      <span>{session.user?.name}</span>
      <button onClick={() => signOut()}>Sign Out</button>
    </div>
  )
}
```

## 比較と選択ガイド

### 最速で実装したい → **Clerk**

- UIコンポーネント提供済み
- 設定が最小限
- マネージドサービス

### 完全な制御が必要 → **Lucia**

- データベース、セッション管理を完全制御
- カスタマイズ性が最も高い
- オープンソース、無料

### モダンで型安全 → **Better Auth**

- TypeScript完全対応
- 最新のNext.js機能を活用
- プラグインで拡張可能

### 実績と安定性 → **NextAuth.js**

- 最も広く使われている
- 豊富なプロバイダー
- コミュニティサポート

## ベストプラクティス

### 1. セキュアなパスワードハッシュ

```typescript
import { hash, verify } from '@node-rs/argon2'

// ハッシュ化
const passwordHash = await hash(password, {
  memoryCost: 19456,
  timeCost: 2,
  outputLen: 32,
  parallelism: 1,
})

// 検証
const valid = await verify(passwordHash, password)
```

### 2. CSRFトークン

```typescript
// すべての主要ライブラリがCSRF保護を提供
// 自動的に処理される
```

### 3. セッション管理

```typescript
// セッションの有効期限を適切に設定
sessionCookie: {
  maxAge: 30 * 24 * 60 * 60, // 30日
  expires: false, // ブラウザ閉じても保持
  attributes: {
    secure: process.env.NODE_ENV === 'production', // HTTPS only
    sameSite: 'lax', // CSRF保護
    httpOnly: true, // XSS保護
  },
}
```

### 4. リフレッシュトークン

```typescript
// 長期セッションにはリフレッシュトークンを実装
// Clerk、Better Authは自動対応
```

## 参考リンク

- [Clerk 公式ドキュメント](https://clerk.com/docs)
- [Lucia 公式ドキュメント](https://lucia-auth.com/)
- [Better Auth 公式ドキュメント](https://better-auth.com/)
- [NextAuth.js 公式ドキュメント](https://next-auth.js.org/)
