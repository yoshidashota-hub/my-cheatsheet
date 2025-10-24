# NextAuth.js (Auth.js) 完全ガイド

## 目次
- [NextAuth.jsとは](#nextauthjsとは)
- [セットアップ](#セットアップ)
- [プロバイダー](#プロバイダー)
- [セッション管理](#セッション管理)
- [データベース連携](#データベース連携)
- [認証コールバック](#認証コールバック)
- [ミドルウェア](#ミドルウェア)
- [カスタマイズ](#カスタマイズ)

---

## NextAuth.jsとは

Next.js向けの認証ライブラリ。OAuth、メール、認証情報など複数の認証方法をサポート。

### 主な特徴
- 🔐 多様な認証プロバイダー
- 🔄 セッション管理
- 🗄️ データベース対応
- 🎨 カスタマイズ可能
- ⚡ サーバーレス対応

---

## セットアップ

### インストール (Next.js 14+)

```bash
npm install next-auth
```

### 基本設定

```typescript
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth'
import GoogleProvider from 'next-auth/providers/google'
import GithubProvider from 'next-auth/providers/github'

const handler = NextAuth({
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!
    }),
    GithubProvider({
      clientId: process.env.GITHUB_ID!,
      clientSecret: process.env.GITHUB_SECRET!
    })
  ],
  secret: process.env.NEXTAUTH_SECRET
})

export { handler as GET, handler as POST }
```

### 環境変数

```bash
# .env.local
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-secret-here

GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret

GITHUB_ID=your-github-id
GITHUB_SECRET=your-github-secret
```

---

## プロバイダー

### OAuth プロバイダー

```typescript
import GoogleProvider from 'next-auth/providers/google'
import GithubProvider from 'next-auth/providers/github'
import FacebookProvider from 'next-auth/providers/facebook'
import TwitterProvider from 'next-auth/providers/twitter'
import DiscordProvider from 'next-auth/providers/discord'

providers: [
  GoogleProvider({
    clientId: process.env.GOOGLE_CLIENT_ID!,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET!
  }),
  GithubProvider({
    clientId: process.env.GITHUB_ID!,
    clientSecret: process.env.GITHUB_SECRET!
  })
]
```

### Credentials プロバイダー

```typescript
import CredentialsProvider from 'next-auth/providers/credentials'

providers: [
  CredentialsProvider({
    name: 'Credentials',
    credentials: {
      email: { label: "Email", type: "email" },
      password: { label: "Password", type: "password" }
    },
    async authorize(credentials) {
      const user = await verifyUser(credentials)

      if (user) {
        return user
      }
      return null
    }
  })
]
```

### Email プロバイダー

```typescript
import EmailProvider from 'next-auth/providers/email'

providers: [
  EmailProvider({
    server: process.env.EMAIL_SERVER,
    from: process.env.EMAIL_FROM
  })
]
```

---

## セッション管理

### クライアントコンポーネント

```typescript
'use client'

import { useSession, signIn, signOut } from 'next-auth/react'

export default function Component() {
  const { data: session, status } = useSession()

  if (status === 'loading') {
    return <p>Loading...</p>
  }

  if (status === 'unauthenticated') {
    return (
      <button onClick={() => signIn()}>Sign in</button>
    )
  }

  return (
    <div>
      <p>Signed in as {session?.user?.email}</p>
      <button onClick={() => signOut()}>Sign out</button>
    </div>
  )
}
```

### サーバーコンポーネント

```typescript
import { getServerSession } from 'next-auth/next'
import { authOptions } from './api/auth/[...nextauth]/route'

export default async function ServerComponent() {
  const session = await getServerSession(authOptions)

  if (!session) {
    return <p>Not authenticated</p>
  }

  return <p>Welcome {session.user?.name}</p>
}
```

---

## データベース連携

### Prisma Adapter

```bash
npm install @prisma/client @next-auth/prisma-adapter
npm install -D prisma
```

```typescript
import { PrismaAdapter } from '@next-auth/prisma-adapter'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export const authOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    // ...
  ]
}
```

```prisma
// schema.prisma
model Account {
  id                String  @id @default(cuid())
  userId            String
  type              String
  provider          String
  providerAccountId String
  refresh_token     String? @db.Text
  access_token      String? @db.Text
  expires_at        Int?
  token_type        String?
  scope             String?
  id_token          String? @db.Text
  session_state     String?

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([provider, providerAccountId])
}

model Session {
  id           String   @id @default(cuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime
  user         User     @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String?   @unique
  emailVerified DateTime?
  image         String?
  accounts      Account[]
  sessions      Session[]
}
```

---

## 認証コールバック

### JWT コールバック

```typescript
callbacks: {
  async jwt({ token, user, account }) {
    if (user) {
      token.id = user.id
      token.role = user.role
    }
    return token
  }
}
```

### Session コールバック

```typescript
callbacks: {
  async session({ session, token }) {
    if (session.user) {
      session.user.id = token.id
      session.user.role = token.role
    }
    return session
  }
}
```

### 型定義の拡張

```typescript
// types/next-auth.d.ts
import 'next-auth'

declare module 'next-auth' {
  interface Session {
    user: {
      id: string
      role: string
    } & DefaultSession['user']
  }

  interface User {
    role: string
  }
}
```

---

## ミドルウェア

### 認証保護

```typescript
// middleware.ts
export { default } from 'next-auth/middleware'

export const config = {
  matcher: ['/dashboard/:path*', '/admin/:path*']
}
```

### カスタムミドルウェア

```typescript
import { withAuth } from 'next-auth/middleware'

export default withAuth(
  function middleware(req) {
    console.log(req.nextauth.token)
  },
  {
    callbacks: {
      authorized({ req, token }) {
        if (req.nextUrl.pathname.startsWith('/admin')) {
          return token?.role === 'admin'
        }
        return !!token
      }
    }
  }
)
```

---

## カスタマイズ

### カスタムサインインページ

```typescript
pages: {
  signIn: '/auth/signin',
  signOut: '/auth/signout',
  error: '/auth/error'
}
```

### カスタムサインインUI

```typescript
// app/auth/signin/page.tsx
import { getProviders, signIn } from 'next-auth/react'

export default async function SignInPage() {
  const providers = await getProviders()

  return (
    <div>
      {Object.values(providers).map((provider) => (
        <button
          key={provider.name}
          onClick={() => signIn(provider.id)}
        >
          Sign in with {provider.name}
        </button>
      ))}
    </div>
  )
}
```

---

## 参考リンク

- [NextAuth.js 公式ドキュメント](https://next-auth.js.org/)
- [Auth.js (v5)](https://authjs.dev/)
