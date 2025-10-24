# Drizzle ORM 完全ガイド

## 目次
- [Drizzle ORMとは](#drizzle-ormとは)
- [セットアップ](#セットアップ)
- [スキーマ定義](#スキーマ定義)
- [クエリ](#クエリ)
- [マイグレーション](#マイグレーション)
- [リレーション](#リレーション)
- [トランザクション](#トランザクション)
- [Prisma vs Drizzle](#prisma-vs-drizzle)

---

## Drizzle ORMとは

TypeScript/JavaScriptのための軽量で型安全なORM。

### 主な特徴
- ⚡ 軽量・高速
- 🔒 完全な型安全性
- 📝 SQL-likeなAPI
- 🎯 ゼロ依存関係
- 🔄 複数DBサポート（PostgreSQL、MySQL、SQLite）

---

## セットアップ

### インストール

```bash
# PostgreSQL
npm install drizzle-orm postgres
npm install -D drizzle-kit

# MySQL
npm install drizzle-orm mysql2
npm install -D drizzle-kit

# SQLite (better-sqlite3)
npm install drizzle-orm better-sqlite3
npm install -D drizzle-kit @types/better-sqlite3
```

### 設定ファイル

```typescript
// drizzle.config.ts
import type { Config } from 'drizzle-kit'

export default {
  schema: './src/db/schema.ts',
  out: './drizzle',
  driver: 'pg',
  dbCredentials: {
    connectionString: process.env.DATABASE_URL!
  }
} satisfies Config
```

---

## スキーマ定義

### PostgreSQL

```typescript
// src/db/schema.ts
import { pgTable, serial, text, integer, timestamp, boolean } from 'drizzle-orm/pg-core'

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  age: integer('age'),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow()
})

export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: text('title').notNull(),
  content: text('content'),
  userId: integer('user_id').references(() => users.id),
  publishedAt: timestamp('published_at')
})
```

### MySQL

```typescript
import { mysqlTable, serial, varchar, int, timestamp, boolean } from 'drizzle-orm/mysql-core'

export const users = mysqlTable('users', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 255 }).notNull(),
  email: varchar('email', { length: 255 }).notNull(),
  age: int('age'),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow()
})
```

---

## クエリ

### データベース接続

```typescript
// src/db/index.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from './schema'

const client = postgres(process.env.DATABASE_URL!)
export const db = drizzle(client, { schema })
```

### SELECT

```typescript
import { db } from './db'
import { users } from './db/schema'

// 全件取得
const allUsers = await db.select().from(users)

// 条件付き
import { eq, gt, and } from 'drizzle-orm'

const user = await db.select().from(users).where(eq(users.id, 1))

const activeUsers = await db.select()
  .from(users)
  .where(and(
    eq(users.isActive, true),
    gt(users.age, 18)
  ))

// 特定カラムのみ
const names = await db.select({ name: users.name }).from(users)

// LIMIT & OFFSET
const paginatedUsers = await db.select()
  .from(users)
  .limit(10)
  .offset(20)

// ORDER BY
const sortedUsers = await db.select()
  .from(users)
  .orderBy(users.createdAt)
```

### INSERT

```typescript
// 1件挿入
const newUser = await db.insert(users).values({
  name: 'John Doe',
  email: 'john@example.com',
  age: 25
}).returning()

// 複数挿入
await db.insert(users).values([
  { name: 'Alice', email: 'alice@example.com' },
  { name: 'Bob', email: 'bob@example.com' }
])
```

### UPDATE

```typescript
await db.update(users)
  .set({ age: 26 })
  .where(eq(users.id, 1))

// 複数カラム更新
await db.update(users)
  .set({
    name: 'Jane Doe',
    isActive: false
  })
  .where(eq(users.email, 'jane@example.com'))
```

### DELETE

```typescript
await db.delete(users).where(eq(users.id, 1))

// 条件付き削除
await db.delete(users).where(eq(users.isActive, false))
```

---

## マイグレーション

### マイグレーション生成

```bash
# マイグレーションファイル生成
npx drizzle-kit generate:pg

# MySQL
npx drizzle-kit generate:mysql

# SQLite
npx drizzle-kit generate:sqlite
```

### マイグレーション実行

```typescript
// migrate.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import { migrate } from 'drizzle-orm/postgres-js/migrator'
import postgres from 'postgres'

const connection = postgres(process.env.DATABASE_URL!, { max: 1 })
const db = drizzle(connection)

await migrate(db, { migrationsFolder: './drizzle' })
await connection.end()
```

```bash
# 実行
npx tsx migrate.ts
```

---

## リレーション

### リレーション定義

```typescript
import { relations } from 'drizzle-orm'

export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts)
}))

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, {
    fields: [posts.userId],
    references: [users.id]
  })
}))
```

### リレーションクエリ

```typescript
// ユーザーと投稿を一緒に取得
const usersWithPosts = await db.query.users.findMany({
  with: {
    posts: true
  }
})

// ネストしたリレーション
const postsWithAuthors = await db.query.posts.findMany({
  with: {
    author: {
      columns: {
        name: true,
        email: true
      }
    }
  }
})
```

---

## トランザクション

```typescript
await db.transaction(async (tx) => {
  const user = await tx.insert(users).values({
    name: 'John',
    email: 'john@example.com'
  }).returning()

  await tx.insert(posts).values({
    title: 'First Post',
    userId: user[0].id
  })
})
```

---

## Prisma vs Drizzle

| 特徴 | Prisma | Drizzle |
|------|--------|---------|
| 型安全性 | ○ | ○ |
| パフォーマンス | △ | ○ |
| バンドルサイズ | 大 | 小 |
| API | スキーマファースト | コードファースト |
| 学習曲線 | やや急 | 緩やか |

---

## 参考リンク

- [Drizzle ORM 公式ドキュメント](https://orm.drizzle.team/)
- [Drizzle Kit](https://orm.drizzle.team/kit-docs/overview)
