# React Server Components ガイド

React Server Components (RSC)は、サーバー上でレンダリングされる新しいタイプのReactコンポーネントです。

## 特徴

- **ゼロバンドル**: サーバーコンポーネントのコードはクライアントに送信されない
- **直接データアクセス**: データベースやファイルシステムに直接アクセス可能
- **自動コード分割**: 必要なコードのみをクライアントに送信
- **ストリーミング**: コンテンツを段階的に送信
- **SEO対応**: サーバーでレンダリングされるため検索エンジンに最適

## Server Components vs Client Components

### Server Components（デフォルト）

```typescript
// app/components/UserList.tsx
// デフォルトでServer Component

async function getUsers() {
  const res = await fetch('https://api.example.com/users')
  return res.json()
}

export default async function UserList() {
  const users = await getUsers()

  return (
    <ul>
      {users.map((user) => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  )
}
```

**できること:**
- データベースに直接アクセス
- ファイルシステムの読み取り
- 秘密鍵の使用（環境変数）
- async/awaitでデータフェッチ
- 重い依存関係の使用（クライアントに送信されない）

**できないこと:**
- `useState`, `useEffect` などのフック
- ブラウザAPI（`window`, `localStorage` など）
- イベントハンドラ（`onClick`, `onChange` など）
- `createContext`, `useContext`

### Client Components

```typescript
// app/components/Counter.tsx
'use client' // この宣言が必須

import { useState } from 'react'

export default function Counter() {
  const [count, setCount] = useState(0)

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>Increment</button>
    </div>
  )
}
```

**使用するケース:**
- インタラクティブな機能
- Reactフックの使用
- ブラウザAPIの使用
- イベントハンドラ
- カスタムフック
- クラスコンポーネント

## 基本的な使い方

### データフェッチング

```typescript
// app/posts/page.tsx
async function getPosts() {
  const res = await fetch('https://api.example.com/posts', {
    cache: 'no-store', // SSR（毎回最新データ）
  })
  return res.json()
}

export default async function PostsPage() {
  const posts = await getPosts()

  return (
    <div>
      <h1>Posts</h1>
      {posts.map((post) => (
        <article key={post.id}>
          <h2>{post.title}</h2>
          <p>{post.body}</p>
        </article>
      ))}
    </div>
  )
}
```

### キャッシング戦略

```typescript
// デフォルト: force-cache（SSG）
const res = await fetch('https://api.example.com/data')

// キャッシュなし（SSR）
const res = await fetch('https://api.example.com/data', {
  cache: 'no-store'
})

// 60秒ごとに再検証（ISR）
const res = await fetch('https://api.example.com/data', {
  next: { revalidate: 60 }
})

// タグベースの再検証
const res = await fetch('https://api.example.com/data', {
  next: { tags: ['posts'] }
})
```

### データベースアクセス

```typescript
// app/users/page.tsx
import { prisma } from '@/lib/prisma'

export default async function UsersPage() {
  // Server Componentなのでデータベースに直接アクセス可能
  const users = await prisma.user.findMany({
    include: {
      posts: true,
    },
  })

  return (
    <div>
      {users.map((user) => (
        <div key={user.id}>
          <h2>{user.name}</h2>
          <p>Posts: {user.posts.length}</p>
        </div>
      ))}
    </div>
  )
}
```

## 並列データフェッチング

### 逐次フェッチ（遅い）

```typescript
// ❌ 悪い例
export default async function Page() {
  const user = await getUser() // 待機
  const posts = await getPosts(user.id) // userを待ってから実行

  return (
    <div>
      <h1>{user.name}</h1>
      <PostList posts={posts} />
    </div>
  )
}
```

### 並列フェッチ（速い）

```typescript
// ✅ 良い例
export default async function Page() {
  // 並列実行
  const [user, posts] = await Promise.all([
    getUser(),
    getPosts(),
  ])

  return (
    <div>
      <h1>{user.name}</h1>
      <PostList posts={posts} />
    </div>
  )
}
```

### データの先読み

```typescript
// データフェッチ関数を先に呼び出す
export default async function Page() {
  const userPromise = getUser()
  const postsPromise = getPosts()

  // 他の処理

  // 必要な時にawait
  const user = await userPromise
  const posts = await postsPromise

  return (
    <div>
      <h1>{user.name}</h1>
      <PostList posts={posts} />
    </div>
  )
}
```

## Server ComponentとClient Componentの組み合わせ

### パターン1: Server → Client（基本）

```typescript
// app/page.tsx (Server Component)
import ClientCounter from './ClientCounter'

async function getData() {
  const res = await fetch('https://api.example.com/data')
  return res.json()
}

export default async function Page() {
  const data = await getData()

  return (
    <div>
      <h1>Server Component</h1>
      {/* Server Component から Client Component を呼び出し */}
      <ClientCounter initialCount={data.count} />
    </div>
  )
}

// app/ClientCounter.tsx
'use client'

import { useState } from 'react'

export default function ClientCounter({ initialCount }: { initialCount: number }) {
  const [count, setCount] = useState(initialCount)

  return (
    <button onClick={() => setCount(count + 1)}>
      Count: {count}
    </button>
  )
}
```

### パターン2: Client → Server（childrenパターン）

```typescript
// app/ClientWrapper.tsx
'use client'

import { useState } from 'react'

export default function ClientWrapper({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <div>
      <button onClick={() => setIsOpen(!isOpen)}>Toggle</button>
      {isOpen && children}
    </div>
  )
}

// app/page.tsx (Server Component)
import ClientWrapper from './ClientWrapper'

async function getData() {
  const res = await fetch('https://api.example.com/data')
  return res.json()
}

export default async function Page() {
  const data = await getData()

  return (
    <ClientWrapper>
      {/* Server Componentをchildrenとして渡す */}
      <div>
        <h1>Server Data</h1>
        <p>{data.message}</p>
      </div>
    </ClientWrapper>
  )
}
```

### パターン3: Composition（コンポジション）

```typescript
// app/components/Layout.tsx
'use client'

export default function Layout({
  sidebar,
  content
}: {
  sidebar: React.ReactNode
  content: React.ReactNode
}) {
  return (
    <div className="flex">
      <aside className="w-64">{sidebar}</aside>
      <main className="flex-1">{content}</main>
    </div>
  )
}

// app/page.tsx
import Layout from './components/Layout'
import Sidebar from './components/Sidebar' // Server Component
import Content from './components/Content' // Server Component

export default function Page() {
  return (
    <Layout
      sidebar={<Sidebar />}
      content={<Content />}
    />
  )
}
```

## ストリーミングとSuspense

### 基本的なSuspense

```typescript
// app/page.tsx
import { Suspense } from 'react'
import SlowComponent from './SlowComponent'

export default function Page() {
  return (
    <div>
      <h1>Fast Content</h1>

      <Suspense fallback={<div>Loading...</div>}>
        <SlowComponent />
      </Suspense>
    </div>
  )
}

// app/SlowComponent.tsx
async function getSlowData() {
  await new Promise(resolve => setTimeout(resolve, 3000))
  return { message: 'Slow data loaded' }
}

export default async function SlowComponent() {
  const data = await getSlowData()

  return <div>{data.message}</div>
}
```

### 複数のSuspense境界

```typescript
export default function Page() {
  return (
    <div>
      <h1>Dashboard</h1>

      <Suspense fallback={<Skeleton />}>
        <UserInfo />
      </Suspense>

      <Suspense fallback={<Skeleton />}>
        <RecentPosts />
      </Suspense>

      <Suspense fallback={<Skeleton />}>
        <Analytics />
      </Suspense>
    </div>
  )
}
```

### loading.tsx（自動Suspense）

```typescript
// app/dashboard/loading.tsx
export default function Loading() {
  return <div>Loading dashboard...</div>
}

// app/dashboard/page.tsx
// 自動的にSuspenseでラップされる
export default async function DashboardPage() {
  const data = await getSlowData()
  return <div>{data}</div>
}
```

## エラーハンドリング

### error.tsx

```typescript
// app/error.tsx
'use client' // Error componentsは必ずClient Component

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>Something went wrong!</h2>
      <p>{error.message}</p>
      <button onClick={() => reset()}>Try again</button>
    </div>
  )
}
```

### エラー境界の配置

```typescript
// app/posts/error.tsx
'use client'

export default function PostsError({ error, reset }: any) {
  return (
    <div>
      <h2>Failed to load posts</h2>
      <button onClick={reset}>Retry</button>
    </div>
  )
}

// app/posts/page.tsx
// この下で発生したエラーはpostsのerror.tsxでキャッチ
export default async function PostsPage() {
  const posts = await getPosts() // エラーが発生する可能性
  return <PostList posts={posts} />
}
```

## データの再検証

### revalidatePath

```typescript
// app/actions.ts
'use server'

import { revalidatePath } from 'next/cache'

export async function createPost(formData: FormData) {
  const title = formData.get('title') as string
  const content = formData.get('content') as string

  await db.posts.create({ title, content })

  // /posts ページのキャッシュを無効化
  revalidatePath('/posts')
}
```

### revalidateTag

```typescript
// データフェッチ時にタグを付ける
async function getPosts() {
  const res = await fetch('https://api.example.com/posts', {
    next: { tags: ['posts'] }
  })
  return res.json()
}

// app/actions.ts
'use server'

import { revalidateTag } from 'next/cache'

export async function createPost(data: any) {
  await db.posts.create(data)

  // 'posts' タグが付いた全てのキャッシュを無効化
  revalidateTag('posts')
}
```

## プリレンダリング

### 静的レンダリング（デフォルト）

```typescript
// app/posts/page.tsx
// ビルド時に生成される
export default async function PostsPage() {
  const posts = await fetch('https://api.example.com/posts')
    .then(res => res.json())

  return <PostList posts={posts} />
}
```

### 動的レンダリング

```typescript
// 以下のいずれかで動的レンダリングになる

// 1. cookies() / headers() の使用
import { cookies } from 'next/headers'

export default async function Page() {
  const cookieStore = cookies()
  const theme = cookieStore.get('theme')
  return <div>{theme?.value}</div>
}

// 2. searchParams の使用
export default function Page({ searchParams }: { searchParams: { q: string } }) {
  return <div>Search: {searchParams.q}</div>
}

// 3. cache: 'no-store' の使用
const data = await fetch('https://api.example.com/data', {
  cache: 'no-store'
})

// 4. revalidate: 0 の使用
const data = await fetch('https://api.example.com/data', {
  next: { revalidate: 0 }
})
```

### 段階的静的再生成（ISR）

```typescript
// app/posts/[slug]/page.tsx

// 1. パスを事前生成
export async function generateStaticParams() {
  const posts = await fetch('https://api.example.com/posts')
    .then(res => res.json())

  return posts.map((post: any) => ({
    slug: post.slug,
  }))
}

// 2. ページを生成
export default async function PostPage({ params }: { params: { slug: string } }) {
  const post = await fetch(`https://api.example.com/posts/${params.slug}`, {
    next: { revalidate: 60 } // 60秒ごとに再生成
  }).then(res => res.json())

  return (
    <article>
      <h1>{post.title}</h1>
      <div>{post.content}</div>
    </article>
  )
}
```

## 実践例

### ブログ記事一覧と詳細

```typescript
// app/blog/page.tsx
import Link from 'next/link'

async function getPosts() {
  const res = await fetch('https://api.example.com/posts', {
    next: { tags: ['posts'] }
  })
  return res.json()
}

export default async function BlogPage() {
  const posts = await getPosts()

  return (
    <div>
      <h1>Blog</h1>
      <div className="grid gap-4">
        {posts.map((post) => (
          <article key={post.id}>
            <Link href={`/blog/${post.slug}`}>
              <h2>{post.title}</h2>
              <p>{post.excerpt}</p>
            </Link>
          </article>
        ))}
      </div>
    </div>
  )
}

// app/blog/[slug]/page.tsx
import { notFound } from 'next/navigation'

async function getPost(slug: string) {
  const res = await fetch(`https://api.example.com/posts/${slug}`, {
    next: { revalidate: 60 }
  })

  if (!res.ok) return null
  return res.json()
}

export async function generateStaticParams() {
  const posts = await fetch('https://api.example.com/posts')
    .then(res => res.json())

  return posts.map((post: any) => ({
    slug: post.slug,
  }))
}

export default async function PostPage({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug)

  if (!post) {
    notFound()
  }

  return (
    <article>
      <h1>{post.title}</h1>
      <time>{new Date(post.createdAt).toLocaleDateString()}</time>
      <div dangerouslySetInnerHTML={{ __html: post.content }} />
    </article>
  )
}
```

### ダッシュボード（複数データソース）

```typescript
// app/dashboard/page.tsx
import { Suspense } from 'react'
import UserInfo from './UserInfo'
import RecentOrders from './RecentOrders'
import Analytics from './Analytics'

export default function DashboardPage() {
  return (
    <div className="grid grid-cols-2 gap-4">
      <Suspense fallback={<UserInfoSkeleton />}>
        <UserInfo />
      </Suspense>

      <Suspense fallback={<AnalyticsSkeleton />}>
        <Analytics />
      </Suspense>

      <div className="col-span-2">
        <Suspense fallback={<OrdersSkeleton />}>
          <RecentOrders />
        </Suspense>
      </div>
    </div>
  )
}

// app/dashboard/UserInfo.tsx
async function getUserInfo() {
  const res = await fetch('https://api.example.com/user')
  return res.json()
}

export default async function UserInfo() {
  const user = await getUserInfo()

  return (
    <div className="card">
      <h2>{user.name}</h2>
      <p>{user.email}</p>
    </div>
  )
}

// app/dashboard/RecentOrders.tsx
async function getRecentOrders() {
  const res = await fetch('https://api.example.com/orders?limit=10')
  return res.json()
}

export default async function RecentOrders() {
  const orders = await getRecentOrders()

  return (
    <div className="card">
      <h2>Recent Orders</h2>
      <ul>
        {orders.map((order: any) => (
          <li key={order.id}>
            {order.product} - ${order.amount}
          </li>
        ))}
      </ul>
    </div>
  )
}
```

### フォームとServer Actions

```typescript
// app/posts/new/page.tsx
import { createPost } from './actions'

export default function NewPostPage() {
  return (
    <form action={createPost}>
      <input name="title" placeholder="Title" required />
      <textarea name="content" placeholder="Content" required />
      <button type="submit">Create Post</button>
    </form>
  )
}

// app/posts/new/actions.ts
'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'

export async function createPost(formData: FormData) {
  const title = formData.get('title') as string
  const content = formData.get('content') as string

  const post = await db.posts.create({
    data: { title, content }
  })

  revalidatePath('/posts')
  redirect(`/posts/${post.id}`)
}
```

## パフォーマンス最適化

### データフェッチの最適化

```typescript
// ❌ 悪い例: N+1問題
export default async function UsersPage() {
  const users = await getUsers()

  return (
    <div>
      {users.map(user => (
        <UserCard key={user.id} userId={user.id} />
      ))}
    </div>
  )
}

async function UserCard({ userId }: { userId: string }) {
  // 各ユーザーごとにクエリが発行される
  const user = await getUserById(userId)
  return <div>{user.name}</div>
}

// ✅ 良い例: 一括取得
export default async function UsersPage() {
  const users = await getUsers()

  return (
    <div>
      {users.map(user => (
        <UserCard key={user.id} user={user} />
      ))}
    </div>
  )
}

function UserCard({ user }: { user: User }) {
  return <div>{user.name}</div>
}
```

### 並列データフェッチ

```typescript
// ✅ 並列実行
export default async function Page() {
  const [user, posts, comments] = await Promise.all([
    getUser(),
    getPosts(),
    getComments(),
  ])

  return (
    <div>
      <UserInfo user={user} />
      <Posts posts={posts} />
      <Comments comments={comments} />
    </div>
  )
}
```

### 選択的ハイドレーション

```typescript
// 重いコンポーネントは遅延読み込み
import dynamic from 'next/dynamic'

const HeavyChart = dynamic(() => import('./HeavyChart'), {
  loading: () => <div>Loading chart...</div>,
  ssr: false, // クライアントのみでレンダリング
})

export default function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>
      <HeavyChart />
    </div>
  )
}
```

## ベストプラクティス

1. **デフォルトでServer Componentsを使用**: 特に理由がない限りServer Components
2. **必要な箇所のみClient Components**: インタラクティブな部分だけ
3. **データフェッチは並列化**: `Promise.all` を活用
4. **適切なSuspense境界**: 独立したデータソースごとに配置
5. **キャッシュ戦略を明示**: `cache`, `revalidate`, `tags` を適切に設定
6. **エラー境界を適切に配置**: ユーザー体験を考慮
7. **Server ActionsでUIを更新**: フォーム処理とキャッシュ無効化

## 制限事項と注意点

### Server Componentsの制限

- Context APIは使えない（代わりにpropsで渡す）
- ブラウザAPIは使えない
- イベントハンドラは使えない
- Reactフックは使えない

### Client Componentsの制限

- async/awaitは使えない（`use` hookは可能）
- Server-only APIは使えない

### 相互運用の注意点

- Server ComponentをClient Componentにimportできない
- Client ComponentにServer Componentをchildrenとして渡すのは可能

## 参考リンク

- [React Server Components RFC](https://github.com/reactjs/rfcs/blob/main/text/0188-server-components.md)
- [Next.js Server Components](https://nextjs.org/docs/app/building-your-application/rendering/server-components)
- [React 18 Working Group](https://github.com/reactwg/react-18/discussions)
- [Server Components Patterns](https://nextjs.org/docs/app/building-your-application/rendering/composition-patterns)

#20