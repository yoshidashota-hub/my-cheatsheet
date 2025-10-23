# Prisma ORM ガイド

PrismaはTypeScriptとNode.js向けの次世代ORMです。

## 特徴

- **型安全**: TypeScriptで完全な型サポート
- **自動生成**: スキーマからクライアントを自動生成
- **マイグレーション**: データベーススキーマの管理が容易
- **直感的なAPI**: わかりやすいクエリAPI
- **複数DB対応**: PostgreSQL, MySQL, SQLite, MongoDB, SQL Server

## セットアップ

### インストール

```bash
npm install prisma --save-dev
npm install @prisma/client
```

### 初期化

```bash
npx prisma init
```

これにより以下が作成されます:

- `prisma/schema.prisma` - スキーマファイル
- `.env` - 環境変数ファイル

### データベース接続設定

```env
# .env
DATABASE_URL="postgresql://user:password@localhost:5432/mydb"
# DATABASE_URL="mysql://user:password@localhost:3306/mydb"
# DATABASE_URL="file:./dev.db" # SQLite
```

## スキーマ定義

### 基本構文

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

### データ型

```prisma
model Example {
  // 文字列
  text      String
  varchar   String   @db.VarChar(255)

  // 数値
  integer   Int
  bigInt    BigInt
  float     Float
  decimal   Decimal

  // 真偽値
  boolean   Boolean

  // 日時
  datetime  DateTime
  date      DateTime @db.Date
  time      DateTime @db.Time

  // JSON
  json      Json

  // バイト
  bytes     Bytes

  // 列挙型
  role      Role     @default(USER)
}

enum Role {
  USER
  ADMIN
  MODERATOR
}
```

### リレーション

```prisma
// 1対1
model User {
  id      Int      @id @default(autoincrement())
  email   String   @unique
  profile Profile?
}

model Profile {
  id     Int    @id @default(autoincrement())
  bio    String
  userId Int    @unique
  user   User   @relation(fields: [userId], references: [id])
}

// 1対多
model User {
  id    Int    @id @default(autoincrement())
  posts Post[]
}

model Post {
  id       Int    @id @default(autoincrement())
  title    String
  authorId Int
  author   User   @relation(fields: [authorId], references: [id])
}

// 多対多
model Post {
  id         Int        @id @default(autoincrement())
  title      String
  categories Category[]
}

model Category {
  id    Int    @id @default(autoincrement())
  name  String
  posts Post[]
}

// 多対多（明示的な中間テーブル）
model Post {
  id              Int              @id @default(autoincrement())
  title           String
  postCategories  PostCategory[]
}

model Category {
  id              Int              @id @default(autoincrement())
  name            String
  postCategories  PostCategory[]
}

model PostCategory {
  postId     Int
  categoryId Int
  assignedAt DateTime @default(now())
  post       Post     @relation(fields: [postId], references: [id])
  category   Category @relation(fields: [categoryId], references: [id])

  @@id([postId, categoryId])
}
```

### インデックス

```prisma
model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  firstName String
  lastName  String
  age       Int
  posts     Post[]

  // 単一フィールドのインデックス
  @@index([email])

  // 複合インデックス
  @@index([firstName, lastName])

  // ユニーク制約
  @@unique([email, firstName])
}
```

### デフォルト値と制約

```prisma
model User {
  id        Int      @id @default(autoincrement())
  uuid      String   @default(uuid())
  email     String   @unique
  name      String   @default("Anonymous")
  age       Int      @default(0)
  isActive  Boolean  @default(true)
  role      Role     @default(USER)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

### カスケード削除

```prisma
model User {
  id    Int    @id @default(autoincrement())
  posts Post[]
}

model Post {
  id       Int    @id @default(autoincrement())
  title    String
  authorId Int
  author   User   @relation(fields: [authorId], references: [id], onDelete: Cascade)
}

// onDelete オプション:
// - Cascade: 親削除時に子も削除
// - SetNull: 親削除時に外部キーをnullに設定
// - Restrict: 子が存在する場合、親の削除を防ぐ
// - NoAction: データベースのデフォルト動作
```

## マイグレーション

### マイグレーションの作成

```bash
# マイグレーションを作成して実行
npx prisma migrate dev --name init
npx prisma migrate dev --name add_user_profile
npx prisma migrate dev --name add_post_categories

# マイグレーションのみ作成（実行しない）
npx prisma migrate dev --create-only
```

### マイグレーションの実行

```bash
# 本番環境でマイグレーション実行
npx prisma migrate deploy

# マイグレーションの状態確認
npx prisma migrate status

# マイグレーションのリセット（開発時のみ）
npx prisma migrate reset
```

### プロトタイピング（db push）

```bash
# スキーマを直接DBに反映（マイグレーションファイルを作成しない）
npx prisma db push
```

## Prisma Client

### クライアントの生成

```bash
npx prisma generate
```

### クライアントのインスタンス化

```typescript
// lib/prisma.ts
import { PrismaClient } from '@prisma/client'

const globalForPrisma = global as unknown as { prisma: PrismaClient }

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    log: ['query', 'error', 'warn'],
  })

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

## CRUD操作

### Create（作成）

```typescript
import { prisma } from '@/lib/prisma'

// 単一レコード作成
const user = await prisma.user.create({
  data: {
    email: 'user@example.com',
    name: 'John Doe',
  },
})

// リレーションを含む作成
const user = await prisma.user.create({
  data: {
    email: 'user@example.com',
    name: 'John Doe',
    posts: {
      create: [
        { title: 'First Post', content: 'Hello World' },
        { title: 'Second Post', content: 'Prisma is awesome' },
      ],
    },
  },
  include: {
    posts: true,
  },
})

// 複数レコード作成
const users = await prisma.user.createMany({
  data: [
    { email: 'user1@example.com', name: 'User 1' },
    { email: 'user2@example.com', name: 'User 2' },
  ],
  skipDuplicates: true, // ユニーク制約違反をスキップ
})
```

### Read（読み取り）

```typescript
// 全件取得
const users = await prisma.user.findMany()

// 条件付き取得
const users = await prisma.user.findMany({
  where: {
    email: {
      contains: '@example.com',
    },
    age: {
      gte: 18,
    },
  },
  orderBy: {
    createdAt: 'desc',
  },
  take: 10, // LIMIT
  skip: 20, // OFFSET
})

// 単一レコード取得
const user = await prisma.user.findUnique({
  where: {
    email: 'user@example.com',
  },
})

const user = await prisma.user.findFirst({
  where: {
    email: {
      contains: '@example.com',
    },
  },
})

// リレーションを含む取得
const user = await prisma.user.findUnique({
  where: { id: 1 },
  include: {
    posts: true,
    profile: true,
  },
})

// 特定のフィールドのみ取得
const users = await prisma.user.findMany({
  select: {
    id: true,
    email: true,
    name: true,
  },
})

// カウント
const count = await prisma.user.count()
const count = await prisma.user.count({
  where: {
    age: { gte: 18 },
  },
})
```

### Update（更新）

```typescript
// 単一レコード更新
const user = await prisma.user.update({
  where: { id: 1 },
  data: {
    name: 'Jane Doe',
    age: 25,
  },
})

// 複数レコード更新
const result = await prisma.user.updateMany({
  where: {
    age: { lt: 18 },
  },
  data: {
    isActive: false,
  },
})

// Upsert（存在すれば更新、なければ作成）
const user = await prisma.user.upsert({
  where: { email: 'user@example.com' },
  update: {
    name: 'Updated Name',
  },
  create: {
    email: 'user@example.com',
    name: 'New User',
  },
})

// リレーションの更新
const user = await prisma.user.update({
  where: { id: 1 },
  data: {
    posts: {
      create: { title: 'New Post' },
      delete: { id: 5 },
      update: {
        where: { id: 3 },
        data: { title: 'Updated Title' },
      },
    },
  },
})
```

### Delete（削除）

```typescript
// 単一レコード削除
const user = await prisma.user.delete({
  where: { id: 1 },
})

// 複数レコード削除
const result = await prisma.user.deleteMany({
  where: {
    age: { lt: 18 },
  },
})

// 全件削除
const result = await prisma.user.deleteMany()
```

## 高度なクエリ

### フィルタリング

```typescript
// AND条件
const users = await prisma.user.findMany({
  where: {
    AND: [
      { age: { gte: 18 } },
      { isActive: true },
    ],
  },
})

// OR条件
const users = await prisma.user.findMany({
  where: {
    OR: [
      { email: { contains: '@gmail.com' } },
      { email: { contains: '@yahoo.com' } },
    ],
  },
})

// NOT条件
const users = await prisma.user.findMany({
  where: {
    NOT: {
      email: { contains: '@spam.com' },
    },
  },
})

// 複合条件
const users = await prisma.user.findMany({
  where: {
    OR: [
      {
        AND: [
          { age: { gte: 18 } },
          { isActive: true },
        ],
      },
      { role: 'ADMIN' },
    ],
  },
})
```

### リレーションフィルタ

```typescript
// postsが存在するユーザー
const users = await prisma.user.findMany({
  where: {
    posts: {
      some: {},
    },
  },
})

// 特定の条件を満たすpostsを持つユーザー
const users = await prisma.user.findMany({
  where: {
    posts: {
      some: {
        published: true,
        title: { contains: 'Prisma' },
      },
    },
  },
})

// postsが存在しないユーザー
const users = await prisma.user.findMany({
  where: {
    posts: {
      none: {},
    },
  },
})

// 全てのpostsが条件を満たすユーザー
const users = await prisma.user.findMany({
  where: {
    posts: {
      every: {
        published: true,
      },
    },
  },
})
```

### 集計

```typescript
// 平均、合計、最小、最大
const result = await prisma.user.aggregate({
  _avg: {
    age: true,
  },
  _sum: {
    age: true,
  },
  _min: {
    age: true,
  },
  _max: {
    age: true,
  },
  _count: {
    id: true,
  },
})

// グループ化
const result = await prisma.user.groupBy({
  by: ['role'],
  _count: {
    id: true,
  },
  _avg: {
    age: true,
  },
  having: {
    age: {
      _avg: { gt: 25 },
    },
  },
})
```

### ページネーション

```typescript
// カーソルベース
const users = await prisma.user.findMany({
  take: 10,
  cursor: {
    id: lastUserId,
  },
  skip: 1, // カーソル自体をスキップ
  orderBy: {
    id: 'asc',
  },
})

// オフセットベース
const users = await prisma.user.findMany({
  take: 10,
  skip: (page - 1) * 10,
})
```

## トランザクション

### インタラクティブトランザクション

```typescript
import { prisma } from '@/lib/prisma'

const result = await prisma.$transaction(async (tx) => {
  // ユーザーを作成
  const user = await tx.user.create({
    data: {
      email: 'user@example.com',
      name: 'John Doe',
    },
  })

  // プロフィールを作成
  const profile = await tx.profile.create({
    data: {
      bio: 'Hello World',
      userId: user.id,
    },
  })

  return { user, profile }
})
```

### シーケンシャルトランザクション

```typescript
const [user, posts] = await prisma.$transaction([
  prisma.user.create({
    data: {
      email: 'user@example.com',
      name: 'John Doe',
    },
  }),
  prisma.post.findMany(),
])
```

### 楽観的ロック

```typescript
const post = await prisma.post.findUnique({
  where: { id: 1 },
})

// バージョンチェックして更新
const updated = await prisma.post.update({
  where: {
    id: 1,
    version: post.version, // 現在のバージョンと一致する場合のみ更新
  },
  data: {
    title: 'New Title',
    version: {
      increment: 1,
    },
  },
})
```

## 生SQLクエリ

```typescript
// Raw query
const users = await prisma.$queryRaw`SELECT * FROM User WHERE age > ${18}`

// タイプセーフなRawクエリ
import { Prisma } from '@prisma/client'

const users = await prisma.$queryRaw<User[]>`
  SELECT * FROM User WHERE age > ${18}
`

// Execute（UPDATE/DELETE/INSERT）
const result = await prisma.$executeRaw`
  UPDATE User SET isActive = true WHERE age > ${18}
`
```

## シーディング

```typescript
// prisma/seed.ts
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  // 既存データをクリア
  await prisma.post.deleteMany()
  await prisma.user.deleteMany()

  // ユーザーを作成
  const user1 = await prisma.user.create({
    data: {
      email: 'user1@example.com',
      name: 'User 1',
      posts: {
        create: [
          {
            title: 'Post 1',
            content: 'Content 1',
            published: true,
          },
          {
            title: 'Post 2',
            content: 'Content 2',
            published: false,
          },
        ],
      },
    },
  })

  const user2 = await prisma.user.create({
    data: {
      email: 'user2@example.com',
      name: 'User 2',
    },
  })

  console.log({ user1, user2 })
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
```

```json
// package.json
{
  "prisma": {
    "seed": "ts-node --compiler-options {\"module\":\"CommonJS\"} prisma/seed.ts"
  }
}
```

```bash
# シーディングの実行
npx prisma db seed
```

## Next.js統合

### API Route

```typescript
// app/api/users/route.ts
import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const users = await prisma.user.findMany()
  return NextResponse.json(users)
}

export async function POST(request: Request) {
  const body = await request.json()
  const user = await prisma.user.create({
    data: body,
  })
  return NextResponse.json(user, { status: 201 })
}
```

### Server Component

```typescript
// app/users/page.tsx
import { prisma } from '@/lib/prisma'

async function getUsers() {
  return await prisma.user.findMany({
    include: {
      posts: true,
    },
  })
}

export default async function UsersPage() {
  const users = await getUsers()

  return (
    <div>
      {users.map((user) => (
        <div key={user.id}>
          <h2>{user.name}</h2>
          <p>{user.email}</p>
          <p>Posts: {user.posts.length}</p>
        </div>
      ))}
    </div>
  )
}
```

### Server Actions

```typescript
// app/actions.ts
'use server'

import { prisma } from '@/lib/prisma'
import { revalidatePath } from 'next/cache'

export async function createUser(formData: FormData) {
  const email = formData.get('email') as string
  const name = formData.get('name') as string

  const user = await prisma.user.create({
    data: { email, name },
  })

  revalidatePath('/users')
  return user
}

export async function deleteUser(id: number) {
  await prisma.user.delete({
    where: { id },
  })

  revalidatePath('/users')
}
```

## Prisma Studio

```bash
# データベースGUIを起動
npx prisma studio
```

ブラウザで `http://localhost:5555` が開き、データの閲覧・編集が可能。

## ベストプラクティス

### 1. シングルトンパターン

```typescript
// lib/prisma.ts
import { PrismaClient } from '@prisma/client'

const prismaClientSingleton = () => {
  return new PrismaClient()
}

declare global {
  var prisma: undefined | ReturnType<typeof prismaClientSingleton>
}

const prisma = globalThis.prisma ?? prismaClientSingleton()

export default prisma

if (process.env.NODE_ENV !== 'production') globalThis.prisma = prisma
```

### 2. エラーハンドリング

```typescript
import { Prisma } from '@prisma/client'

try {
  await prisma.user.create({
    data: {
      email: 'duplicate@example.com',
    },
  })
} catch (error) {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    // ユニーク制約違反
    if (error.code === 'P2002') {
      console.log('Email already exists')
    }
  }
  throw error
}
```

### 3. 型の再利用

```typescript
import { Prisma } from '@prisma/client'

// モデルの型
type User = Prisma.UserGetPayload<{}>

// リレーションを含む型
type UserWithPosts = Prisma.UserGetPayload<{
  include: { posts: true }
}>

// 特定のフィールドのみの型
type UserBasic = Prisma.UserGetPayload<{
  select: { id: true; email: true; name: true }
}>
```

### 4. ソフトデリート

```prisma
model User {
  id        Int       @id @default(autoincrement())
  email     String    @unique
  name      String
  deletedAt DateTime?
}
```

```typescript
// ミドルウェアでソフトデリートを実装
prisma.$use(async (params, next) => {
  if (params.model === 'User') {
    if (params.action === 'delete') {
      // deleteをupdateに変換
      params.action = 'update'
      params.args['data'] = { deletedAt: new Date() }
    }
    if (params.action === 'findMany' || params.action === 'findFirst') {
      // 削除されていないレコードのみ取得
      params.args.where = {
        ...params.args.where,
        deletedAt: null,
      }
    }
  }
  return next(params)
})
```

## トラブルシューティング

### スキーマとDBの同期

```bash
# スキーマをDBに反映
npx prisma db push

# DBからスキーマを生成（イントロスペクション）
npx prisma db pull
```

### クライアントの再生成

```bash
npx prisma generate
```

### マイグレーションのリセット

```bash
# 開発環境のみ
npx prisma migrate reset
```

## 参考リンク

- [Prisma 公式ドキュメント](https://www.prisma.io/docs)
- [Prisma Examples](https://github.com/prisma/prisma-examples)
- [Prisma Schema Reference](https://www.prisma.io/docs/reference/api-reference/prisma-schema-reference)
- [Prisma Client API Reference](https://www.prisma.io/docs/reference/api-reference/prisma-client-reference)
