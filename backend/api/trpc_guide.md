# tRPC ガイド

tRPCは、TypeScript向けのEnd-to-End型安全なAPIフレームワークです。

## 特徴

- **完全な型安全性**: クライアント・サーバー間で型が共有される
- **GraphQLなしでGraphQLのような体験**: スキーマ定義不要
- **React Query統合**: データフェッチングとキャッシング
- **バリデーション**: Zodとの統合
- **軽量**: 追加のビルドステップ不要
- **開発体験**: 自動補完とエラーチェック

## インストール

```bash
npm install @trpc/server @trpc/client @trpc/react-query @trpc/next @tanstack/react-query zod
```

## 基本セットアップ

### サーバー側（tRPCルーター）

```typescript
// server/trpc.ts
import { initTRPC } from '@trpc/server'

const t = initTRPC.create()

export const router = t.router
export const publicProcedure = t.procedure
```

```typescript
// server/routers/_app.ts
import { router, publicProcedure } from '../trpc'
import { z } from 'zod'

export const appRouter = router({
  hello: publicProcedure
    .input(z.object({ name: z.string() }))
    .query(({ input }) => {
      return { greeting: `Hello, ${input.name}!` }
    }),

  createUser: publicProcedure
    .input(z.object({
      name: z.string(),
      email: z.string().email(),
    }))
    .mutation(({ input }) => {
      // データベースに保存
      return { id: '1', ...input }
    }),
})

export type AppRouter = typeof appRouter
```

### Next.js App Router統合

```typescript
// app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from '@trpc/server/adapters/fetch'
import { appRouter } from '@/server/routers/_app'

const handler = (req: Request) =>
  fetchRequestHandler({
    endpoint: '/api/trpc',
    req,
    router: appRouter,
    createContext: () => ({}),
  })

export { handler as GET, handler as POST }
```

### クライアント側セットアップ

```typescript
// utils/trpc.ts
import { createTRPCReact } from '@trpc/react-query'
import type { AppRouter } from '@/server/routers/_app'

export const trpc = createTRPCReact<AppRouter>()
```

```typescript
// app/providers.tsx
'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { httpBatchLink } from '@trpc/client'
import { useState } from 'react'
import { trpc } from '@/utils/trpc'

export function TRPCProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())
  const [trpcClient] = useState(() =>
    trpc.createClient({
      links: [
        httpBatchLink({
          url: 'http://localhost:3000/api/trpc',
        }),
      ],
    })
  )

  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </trpc.Provider>
  )
}
```

```typescript
// app/layout.tsx
import { TRPCProvider } from './providers'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <TRPCProvider>{children}</TRPCProvider>
      </body>
    </html>
  )
}
```

## クエリとミューテーション

### クエリ（データ取得）

```typescript
// コンポーネント
'use client'

import { trpc } from '@/utils/trpc'

export function Hello() {
  const { data, isLoading, error } = trpc.hello.useQuery({ name: 'World' })

  if (isLoading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>

  return <div>{data?.greeting}</div>
}
```

### ミューテーション（データ変更）

```typescript
'use client'

import { trpc } from '@/utils/trpc'

export function CreateUserForm() {
  const utils = trpc.useUtils()
  const createUser = trpc.createUser.useMutation({
    onSuccess: () => {
      // キャッシュを無効化
      utils.users.invalidate()
    },
  })

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const formData = new FormData(e.currentTarget)

    createUser.mutate({
      name: formData.get('name') as string,
      email: formData.get('email') as string,
    })
  }

  return (
    <form onSubmit={handleSubmit}>
      <input name="name" placeholder="Name" required />
      <input name="email" type="email" placeholder="Email" required />
      <button type="submit" disabled={createUser.isLoading}>
        {createUser.isLoading ? 'Creating...' : 'Create User'}
      </button>
      {createUser.error && <p>Error: {createUser.error.message}</p>}
    </form>
  )
}
```

## コンテキスト

### コンテキストの作成

```typescript
// server/trpc.ts
import { initTRPC, TRPCError } from '@trpc/server'
import type { FetchCreateContextFnOptions } from '@trpc/server/adapters/fetch'

export async function createContext(opts: FetchCreateContextFnOptions) {
  // 認証トークンからユーザーを取得
  const token = opts.req.headers.get('authorization')
  const user = await getUserFromToken(token)

  return {
    user,
  }
}

export type Context = Awaited<ReturnType<typeof createContext>>

const t = initTRPC.context<Context>().create()

export const router = t.router
export const publicProcedure = t.procedure

// 認証が必要なプロシージャ
export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' })
  }
  return next({
    ctx: {
      user: ctx.user,
    },
  })
})
```

```typescript
// app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from '@trpc/server/adapters/fetch'
import { appRouter } from '@/server/routers/_app'
import { createContext } from '@/server/trpc'

const handler = (req: Request) =>
  fetchRequestHandler({
    endpoint: '/api/trpc',
    req,
    router: appRouter,
    createContext,
  })

export { handler as GET, handler as POST }
```

### 認証済みプロシージャの使用

```typescript
// server/routers/_app.ts
import { router, publicProcedure, protectedProcedure } from '../trpc'
import { z } from 'zod'

export const appRouter = router({
  // パブリック
  hello: publicProcedure
    .input(z.object({ name: z.string() }))
    .query(({ input }) => {
      return { greeting: `Hello, ${input.name}!` }
    }),

  // 認証必要
  me: protectedProcedure.query(({ ctx }) => {
    return ctx.user
  }),

  updateProfile: protectedProcedure
    .input(z.object({
      name: z.string(),
    }))
    .mutation(async ({ ctx, input }) => {
      // ctx.user は必ず存在する
      return await db.user.update({
        where: { id: ctx.user.id },
        data: { name: input.name },
      })
    }),
})
```

## ルーターの分割

### サブルーター

```typescript
// server/routers/user.ts
import { router, protectedProcedure, publicProcedure } from '../trpc'
import { z } from 'zod'

export const userRouter = router({
  list: publicProcedure.query(async () => {
    return await db.user.findMany()
  }),

  byId: publicProcedure
    .input(z.string())
    .query(async ({ input }) => {
      return await db.user.findUnique({ where: { id: input } })
    }),

  create: protectedProcedure
    .input(z.object({
      name: z.string(),
      email: z.string().email(),
    }))
    .mutation(async ({ input }) => {
      return await db.user.create({ data: input })
    }),

  update: protectedProcedure
    .input(z.object({
      id: z.string(),
      name: z.string().optional(),
      email: z.string().email().optional(),
    }))
    .mutation(async ({ input }) => {
      const { id, ...data } = input
      return await db.user.update({
        where: { id },
        data,
      })
    }),

  delete: protectedProcedure
    .input(z.string())
    .mutation(async ({ input }) => {
      return await db.user.delete({ where: { id: input } })
    }),
})
```

```typescript
// server/routers/post.ts
import { router, protectedProcedure, publicProcedure } from '../trpc'
import { z } from 'zod'

export const postRouter = router({
  list: publicProcedure.query(async () => {
    return await db.post.findMany({
      include: { author: true },
    })
  }),

  byId: publicProcedure
    .input(z.string())
    .query(async ({ input }) => {
      return await db.post.findUnique({
        where: { id: input },
        include: { author: true },
      })
    }),

  create: protectedProcedure
    .input(z.object({
      title: z.string(),
      content: z.string(),
    }))
    .mutation(async ({ ctx, input }) => {
      return await db.post.create({
        data: {
          ...input,
          authorId: ctx.user.id,
        },
      })
    }),
})
```

```typescript
// server/routers/_app.ts
import { router } from '../trpc'
import { userRouter } from './user'
import { postRouter } from './post'

export const appRouter = router({
  user: userRouter,
  post: postRouter,
})

export type AppRouter = typeof appRouter
```

### クライアントでの使用

```typescript
'use client'

import { trpc } from '@/utils/trpc'

export function UserList() {
  // user.list を呼び出し
  const { data: users } = trpc.user.list.useQuery()

  return (
    <ul>
      {users?.map((user) => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  )
}

export function PostList() {
  // post.list を呼び出し
  const { data: posts } = trpc.post.list.useQuery()

  return (
    <ul>
      {posts?.map((post) => (
        <li key={post.id}>
          {post.title} by {post.author.name}
        </li>
      ))}
    </ul>
  )
}
```

## バリデーション（Zod）

```typescript
import { z } from 'zod'

// 基本的なバリデーション
const createUserInput = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  age: z.number().int().positive().optional(),
})

export const userRouter = router({
  create: publicProcedure
    .input(createUserInput)
    .mutation(({ input }) => {
      // input は自動的に型推論される
      // { name: string, email: string, age?: number }
      return db.user.create({ data: input })
    }),
})

// 複雑なバリデーション
const updatePostInput = z.object({
  id: z.string().uuid(),
  title: z.string().min(1).max(200).optional(),
  content: z.string().optional(),
  published: z.boolean().optional(),
}).refine(
  (data) => data.title || data.content || data.published !== undefined,
  { message: 'At least one field must be provided' }
)
```

## ページネーション

### カーソルベース

```typescript
import { z } from 'zod'

export const postRouter = router({
  list: publicProcedure
    .input(z.object({
      limit: z.number().min(1).max(100).default(10),
      cursor: z.string().optional(),
    }))
    .query(async ({ input }) => {
      const { limit, cursor } = input

      const posts = await db.post.findMany({
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: { createdAt: 'desc' },
      })

      let nextCursor: string | undefined = undefined
      if (posts.length > limit) {
        const nextItem = posts.pop()
        nextCursor = nextItem!.id
      }

      return {
        items: posts,
        nextCursor,
      }
    }),
})
```

```typescript
// クライアント
'use client'

import { trpc } from '@/utils/trpc'

export function InfinitePosts() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = trpc.post.list.useInfiniteQuery(
    { limit: 10 },
    {
      getNextPageParam: (lastPage) => lastPage.nextCursor,
    }
  )

  return (
    <div>
      {data?.pages.map((page) =>
        page.items.map((post) => (
          <div key={post.id}>{post.title}</div>
        ))
      )}
      <button
        onClick={() => fetchNextPage()}
        disabled={!hasNextPage || isFetchingNextPage}
      >
        {isFetchingNextPage
          ? 'Loading more...'
          : hasNextPage
          ? 'Load More'
          : 'Nothing more to load'}
      </button>
    </div>
  )
}
```

## サブスクリプション（リアルタイム）

```bash
npm install ws @trpc/server
```

```typescript
// server/trpc.ts
import { initTRPC } from '@trpc/server'
import { observable } from '@trpc/server/observable'
import { EventEmitter } from 'events'

const ee = new EventEmitter()

const t = initTRPC.create()

export const router = t.router
export const publicProcedure = t.procedure

// サブスクリプション
export const appRouter = router({
  onPostCreate: publicProcedure.subscription(() => {
    return observable<Post>((emit) => {
      const onCreate = (data: Post) => {
        emit.next(data)
      }

      ee.on('post:create', onCreate)

      return () => {
        ee.off('post:create', onCreate)
      }
    })
  }),

  createPost: publicProcedure
    .input(z.object({
      title: z.string(),
      content: z.string(),
    }))
    .mutation(async ({ input }) => {
      const post = await db.post.create({ data: input })

      // イベント発火
      ee.emit('post:create', post)

      return post
    }),
})
```

```typescript
// クライアント
'use client'

import { trpc } from '@/utils/trpc'
import { useEffect, useState } from 'react'

export function RealtimePosts() {
  const [posts, setPosts] = useState<Post[]>([])

  trpc.onPostCreate.useSubscription(undefined, {
    onData: (post) => {
      setPosts((prev) => [post, ...prev])
    },
  })

  return (
    <div>
      {posts.map((post) => (
        <div key={post.id}>{post.title}</div>
      ))}
    </div>
  )
}
```

## ミドルウェア

```typescript
// server/trpc.ts
import { initTRPC, TRPCError } from '@trpc/server'

const t = initTRPC.context<Context>().create()

// ロギングミドルウェア
const loggerMiddleware = t.middleware(async ({ path, type, next }) => {
  const start = Date.now()
  const result = await next()
  const duration = Date.now() - start

  console.log(`${type} ${path} took ${duration}ms`)

  return result
})

// 認証ミドルウェア
const authMiddleware = t.middleware(({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' })
  }
  return next({ ctx: { user: ctx.user } })
})

// ロール確認ミドルウェア
const adminMiddleware = t.middleware(({ ctx, next }) => {
  if (!ctx.user || ctx.user.role !== 'ADMIN') {
    throw new TRPCError({ code: 'FORBIDDEN' })
  }
  return next({ ctx: { user: ctx.user } })
})

export const publicProcedure = t.procedure.use(loggerMiddleware)
export const protectedProcedure = publicProcedure.use(authMiddleware)
export const adminProcedure = protectedProcedure.use(adminMiddleware)
```

## エラーハンドリング

```typescript
import { TRPCError } from '@trpc/server'

export const userRouter = router({
  byId: publicProcedure
    .input(z.string())
    .query(async ({ input }) => {
      const user = await db.user.findUnique({ where: { id: input } })

      if (!user) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: 'User not found',
        })
      }

      return user
    }),

  create: publicProcedure
    .input(z.object({
      email: z.string().email(),
      name: z.string(),
    }))
    .mutation(async ({ input }) => {
      try {
        return await db.user.create({ data: input })
      } catch (error) {
        if (error.code === 'P2002') {
          throw new TRPCError({
            code: 'CONFLICT',
            message: 'Email already exists',
          })
        }
        throw new TRPCError({
          code: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to create user',
        })
      }
    }),
})
```

```typescript
// クライアント
'use client'

import { trpc } from '@/utils/trpc'

export function UserProfile({ userId }: { userId: string }) {
  const { data, error } = trpc.user.byId.useQuery(userId)

  if (error) {
    if (error.data?.code === 'NOT_FOUND') {
      return <div>User not found</div>
    }
    return <div>Error: {error.message}</div>
  }

  return <div>{data?.name}</div>
}
```

## 楽観的更新

```typescript
'use client'

import { trpc } from '@/utils/trpc'

export function TodoList() {
  const utils = trpc.useUtils()
  const { data: todos } = trpc.todo.list.useQuery()

  const toggleTodo = trpc.todo.toggle.useMutation({
    onMutate: async ({ id }) => {
      // キャンセル
      await utils.todo.list.cancel()

      // 現在のデータを保存
      const previousTodos = utils.todo.list.getData()

      // 楽観的更新
      utils.todo.list.setData(undefined, (old) =>
        old?.map((todo) =>
          todo.id === id ? { ...todo, done: !todo.done } : todo
        )
      )

      return { previousTodos }
    },
    onError: (err, variables, context) => {
      // エラー時にロールバック
      if (context?.previousTodos) {
        utils.todo.list.setData(undefined, context.previousTodos)
      }
    },
    onSettled: () => {
      // 再取得
      utils.todo.list.invalidate()
    },
  })

  return (
    <ul>
      {todos?.map((todo) => (
        <li key={todo.id}>
          <input
            type="checkbox"
            checked={todo.done}
            onChange={() => toggleTodo.mutate({ id: todo.id })}
          />
          {todo.title}
        </li>
      ))}
    </ul>
  )
}
```

## Server-Side Rendering

```typescript
// app/users/page.tsx
import { createServerSideHelpers } from '@trpc/react-query/server'
import { appRouter } from '@/server/routers/_app'
import superjson from 'superjson'

export default async function UsersPage() {
  const helpers = createServerSideHelpers({
    router: appRouter,
    ctx: {},
    transformer: superjson,
  })

  // サーバーでデータをプリフェッチ
  await helpers.user.list.prefetch()

  return (
    <div>
      {/* クライアントコンポーネントで使用 */}
      <UserList />
    </div>
  )
}
```

## ベストプラクティス

1. **型安全性を活用**: tRPCの最大の利点を活かす
2. **Zodでバリデーション**: 入力値を必ず検証
3. **ルーターを分割**: 機能ごとにルーターを作成
4. **コンテキストで認証**: ユーザー情報をコンテキストで管理
5. **エラーハンドリング**: 適切なエラーコードとメッセージ
6. **楽観的更新**: UX向上のため活用
7. **キャッシュ戦略**: React Queryの機能を活用

## よくある実装パターン

### CRUD操作

```typescript
export const createCrudRouter = <T extends { id: string }>(
  model: string,
  schema: z.ZodType<Omit<T, 'id'>>
) => {
  return router({
    list: publicProcedure.query(() => {
      return db[model].findMany()
    }),

    byId: publicProcedure
      .input(z.string())
      .query(({ input }) => {
        return db[model].findUnique({ where: { id: input } })
      }),

    create: protectedProcedure
      .input(schema)
      .mutation(({ input }) => {
        return db[model].create({ data: input })
      }),

    update: protectedProcedure
      .input(z.object({
        id: z.string(),
        data: schema.partial(),
      }))
      .mutation(({ input }) => {
        return db[model].update({
          where: { id: input.id },
          data: input.data,
        })
      }),

    delete: protectedProcedure
      .input(z.string())
      .mutation(({ input }) => {
        return db[model].delete({ where: { id: input } })
      }),
  })
}
```

## 参考リンク

- [tRPC 公式ドキュメント](https://trpc.io/)
- [tRPC Examples](https://github.com/trpc/trpc/tree/main/examples)
- [Next.js with tRPC](https://trpc.io/docs/nextjs)
- [React Query Documentation](https://tanstack.com/query/latest)

## 関連ガイド

### フロントエンド
- [Next.js App Router ガイド](../../front/framework/nextjs/app_router_guide.md) - Next.jsでのtRPC統合
- [TanStack Query ガイド](../../front/library/tanstack/tanstack_query.md) - データフェッチング・キャッシング
- [React Server Components ガイド](../../front/framework/react/server_components_guide.md) - RSCとの組み合わせ

### バリデーション・ORM
- [Zod ガイド](../validation/zod_guide.md) - スキーマバリデーション
- [Prisma ガイド](../orm/prisma_guide.md) - データベースORM

### 認証
- [NextAuth.js ガイド](../../auth/nextauth_guide.md) - Next.js向け認証

### テスト
- [Vitest ガイド](../../tools/testing/vitest_guide.md) - tRPCエンドポイントのテスト
