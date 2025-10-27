# Next.js App Router ガイド

Next.js 13以降で導入されたApp Routerの完全ガイドです。

## セットアップ

```bash
npx create-next-app@latest my-app
cd my-app
npm run dev
```

インストール時の選択:
- TypeScript: Yes
- ESLint: Yes
- Tailwind CSS: Yes（推奨）
- `src/` directory: Yes（推奨）
- App Router: Yes
- import alias: Yes (@/*)

## ディレクトリ構造

```
app/
├── layout.tsx          # ルートレイアウト（必須）
├── page.tsx            # トップページ (/)
├── loading.tsx         # ローディングUI
├── error.tsx           # エラーUI
├── not-found.tsx       # 404ページ
├── about/
│   └── page.tsx        # /about
├── blog/
│   ├── page.tsx        # /blog
│   ├── layout.tsx      # /blog のレイアウト
│   └── [slug]/
│       └── page.tsx    # /blog/hello-world
└── dashboard/
    ├── layout.tsx
    ├── page.tsx        # /dashboard
    └── settings/
        └── page.tsx    # /dashboard/settings
```

## 基本的なページ作成

### page.tsx（ページコンポーネント）

```typescript
// app/page.tsx
export default function Home() {
  return (
    <main>
      <h1>ホームページ</h1>
      <p>Next.js App Router へようこそ</p>
    </main>
  );
}

// app/about/page.tsx
export default function About() {
  return <h1>About ページ</h1>;
}
```

### layout.tsx（レイアウト）

```typescript
// app/layout.tsx（ルートレイアウト - 必須）
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'My App',
  description: 'My Next.js App',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ja">
      <body>
        <header>ヘッダー</header>
        {children}
        <footer>フッター</footer>
      </body>
    </html>
  );
}

// app/dashboard/layout.tsx（ネストレイアウト）
export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div>
      <nav>ダッシュボードナビゲーション</nav>
      <main>{children}</main>
    </div>
  );
}
```

## ルーティング

### 動的ルート

```typescript
// app/blog/[slug]/page.tsx
interface PageProps {
  params: { slug: string };
  searchParams: { [key: string]: string | string[] | undefined };
}

export default function BlogPost({ params, searchParams }: PageProps) {
  return <h1>記事: {params.slug}</h1>;
}

// 複数の動的セグメント
// app/shop/[category]/[productId]/page.tsx
export default function Product({
  params,
}: {
  params: { category: string; productId: string };
}) {
  return (
    <div>
      <p>カテゴリ: {params.category}</p>
      <p>商品ID: {params.productId}</p>
    </div>
  );
}
```

### キャッチオールルート

```typescript
// app/docs/[...slug]/page.tsx
// /docs/a, /docs/a/b, /docs/a/b/c にマッチ
export default function Docs({ params }: { params: { slug: string[] } }) {
  return <h1>ドキュメント: {params.slug.join('/')}</h1>;
}

// app/docs/[[...slug]]/page.tsx（オプショナル）
// /docs, /docs/a, /docs/a/b にマッチ
```

### Route Groups（グループ化）

```typescript
// app/(marketing)/about/page.tsx
// app/(marketing)/contact/page.tsx
// app/(shop)/products/page.tsx
// app/(shop)/cart/page.tsx

// URL には影響せず、レイアウトの共有などに使用
// app/(marketing)/layout.tsx
```

### Parallel Routes（並行ルート）

```typescript
// app/layout.tsx
export default function Layout({
  children,
  analytics,
  team,
}: {
  children: React.ReactNode;
  analytics: React.ReactNode;
  team: React.ReactNode;
}) {
  return (
    <>
      {children}
      {analytics}
      {team}
    </>
  );
}

// app/@analytics/page.tsx
// app/@team/page.tsx
```

### Intercepting Routes（インターセプトルート）

```typescript
// app/feed/page.tsx
// app/feed/(..)photo/[id]/page.tsx
// モーダルで写真を表示しつつ、URLは変更

// (.) - 同じレベル
// (..) - 1つ上のレベル
// (..)(..) - 2つ上のレベル
// (...) - ルートからのレベル
```

## Server Components と Client Components

### Server Components（デフォルト）

```typescript
// app/posts/page.tsx
// デフォルトでServer Component
async function getPosts() {
  const res = await fetch('https://api.example.com/posts', {
    cache: 'no-store', // SSR
    // next: { revalidate: 60 }, // ISR (60秒ごとに再生成)
  });
  return res.json();
}

export default async function Posts() {
  const posts = await getPosts();

  return (
    <ul>
      {posts.map((post: any) => (
        <li key={post.id}>{post.title}</li>
      ))}
    </ul>
  );
}
```

Server Componentsの特徴:
- サーバーでのみ実行される
- データベースアクセス、ファイルシステムアクセスが可能
- バンドルサイズが小さい
- `useState`, `useEffect` などのフックは使用不可

### Client Components

```typescript
'use client'; // この宣言が必要

import { useState } from 'react';

export default function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <p>カウント: {count}</p>
      <button onClick={() => setCount(count + 1)}>+1</button>
    </div>
  );
}
```

Client Componentsが必要な場合:
- `useState`, `useEffect` などのフックを使用
- ブラウザAPIを使用（`window`, `localStorage` など）
- イベントハンドラ（`onClick`, `onChange` など）
- カスタムフックの使用

### 組み合わせパターン

```typescript
// app/dashboard/page.tsx (Server Component)
import ClientButton from './ClientButton';

async function getData() {
  const res = await fetch('https://api.example.com/data');
  return res.json();
}

export default async function Dashboard() {
  const data = await getData();

  return (
    <div>
      <h1>{data.title}</h1>
      {/* Server Component から Client Component へpropsを渡す */}
      <ClientButton initialCount={data.count} />
    </div>
  );
}

// app/dashboard/ClientButton.tsx
'use client';

import { useState } from 'react';

export default function ClientButton({ initialCount }: { initialCount: number }) {
  const [count, setCount] = useState(initialCount);

  return <button onClick={() => setCount(count + 1)}>Count: {count}</button>;
}
```

## データフェッチング

### fetch API（拡張版）

```typescript
// SSG（Static Site Generation）- デフォルト
const res = await fetch('https://api.example.com/posts');

// SSR（Server-Side Rendering）
const res = await fetch('https://api.example.com/posts', {
  cache: 'no-store',
});

// ISR（Incremental Static Regeneration）
const res = await fetch('https://api.example.com/posts', {
  next: { revalidate: 60 }, // 60秒ごとに再生成
});

// タグベースの再検証
const res = await fetch('https://api.example.com/posts', {
  next: { tags: ['posts'] },
});
```

### 並列データフェッチング

```typescript
// ❌ 直列（遅い）
export default async function Page() {
  const user = await getUser();
  const posts = await getPosts(user.id);

  return <div>...</div>;
}

// ✅ 並列（速い）
export default async function Page() {
  const [user, posts] = await Promise.all([
    getUser(),
    getPosts(),
  ]);

  return <div>...</div>;
}
```

### ストリーミングとSuspense

```typescript
// app/dashboard/page.tsx
import { Suspense } from 'react';

async function SlowComponent() {
  await new Promise((resolve) => setTimeout(resolve, 3000));
  return <div>遅いコンポーネント</div>;
}

export default function Dashboard() {
  return (
    <div>
      <h1>ダッシュボード</h1>
      <Suspense fallback={<div>読み込み中...</div>}>
        <SlowComponent />
      </Suspense>
    </div>
  );
}
```

### loading.tsx（自動Suspense）

```typescript
// app/dashboard/loading.tsx
export default function Loading() {
  return <div>ダッシュボード読み込み中...</div>;
}

// app/dashboard/page.tsx は自動的に Suspense でラップされる
```

## Server Actions

```typescript
// app/actions.ts
'use server';

import { revalidatePath } from 'next/cache';

export async function createPost(formData: FormData) {
  const title = formData.get('title') as string;
  const content = formData.get('content') as string;

  // データベースに保存
  await db.posts.create({ title, content });

  // キャッシュの再検証
  revalidatePath('/posts');
}

// app/posts/new/page.tsx
import { createPost } from '@/app/actions';

export default function NewPost() {
  return (
    <form action={createPost}>
      <input name="title" placeholder="タイトル" />
      <textarea name="content" placeholder="内容" />
      <button type="submit">投稿</button>
    </form>
  );
}
```

### Server Actions with useFormState

```typescript
// app/actions.ts
'use server';

export async function createUser(prevState: any, formData: FormData) {
  const name = formData.get('name') as string;

  if (!name) {
    return { error: '名前は必須です' };
  }

  await db.users.create({ name });
  return { success: true };
}

// app/users/new/page.tsx
'use client';

import { useFormState } from 'react-dom';
import { createUser } from '@/app/actions';

export default function NewUser() {
  const [state, formAction] = useFormState(createUser, null);

  return (
    <form action={formAction}>
      <input name="name" />
      {state?.error && <p style={{ color: 'red' }}>{state.error}</p>}
      <button type="submit">作成</button>
    </form>
  );
}
```

## メタデータ

### 静的メタデータ

```typescript
// app/about/page.tsx
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About',
  description: 'About page',
  openGraph: {
    title: 'About',
    description: 'About page',
    images: ['/og-image.jpg'],
  },
};

export default function About() {
  return <h1>About</h1>;
}
```

### 動的メタデータ

```typescript
// app/blog/[slug]/page.tsx
import type { Metadata } from 'next';

interface PageProps {
  params: { slug: string };
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const post = await getPost(params.slug);

  return {
    title: post.title,
    description: post.excerpt,
    openGraph: {
      title: post.title,
      description: post.excerpt,
      images: [post.image],
    },
  };
}

export default function BlogPost({ params }: PageProps) {
  return <div>...</div>;
}
```

### generateStaticParams（SSG）

```typescript
// app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  const posts = await getPosts();

  return posts.map((post) => ({
    slug: post.slug,
  }));
}

// ビルド時に /blog/post-1, /blog/post-2... が生成される
```

## エラーハンドリング

### error.tsx

```typescript
// app/error.tsx
'use client'; // Error componentsは必ずClient Component

import { useEffect } from 'react';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div>
      <h2>エラーが発生しました</h2>
      <button onClick={() => reset()}>再試行</button>
    </div>
  );
}
```

### not-found.tsx

```typescript
// app/not-found.tsx
export default function NotFound() {
  return <h1>404 - ページが見つかりません</h1>;
}

// app/blog/[slug]/page.tsx
import { notFound } from 'next/navigation';

export default async function BlogPost({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);

  if (!post) {
    notFound(); // not-found.tsx を表示
  }

  return <div>{post.title}</div>;
}
```

## ナビゲーション

### Link コンポーネント

```typescript
import Link from 'next/link';

export default function Nav() {
  return (
    <nav>
      <Link href="/">Home</Link>
      <Link href="/about">About</Link>
      <Link href="/blog/hello-world">Blog Post</Link>

      {/* prefetch を無効化 */}
      <Link href="/heavy-page" prefetch={false}>
        Heavy Page
      </Link>
    </nav>
  );
}
```

### useRouter（Client Component）

```typescript
'use client';

import { useRouter } from 'next/navigation';

export default function MyComponent() {
  const router = useRouter();

  return (
    <button onClick={() => router.push('/dashboard')}>
      ダッシュボードへ
    </button>
  );
}

// その他のメソッド
router.push('/path');      // 遷移
router.replace('/path');   // 履歴を残さず遷移
router.back();             // 戻る
router.forward();          // 進む
router.refresh();          // ページをリフレッシュ
router.prefetch('/path');  // プリフェッチ
```

### redirect（Server Component）

```typescript
import { redirect } from 'next/navigation';

export default async function Profile() {
  const session = await getSession();

  if (!session) {
    redirect('/login');
  }

  return <div>プロフィール</div>;
}
```

## ミドルウェア

```typescript
// middleware.ts（ルートに配置）
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  // 認証チェック
  const token = request.cookies.get('token');

  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // ヘッダーの追加
  const response = NextResponse.next();
  response.headers.set('x-custom-header', 'value');

  return response;
}

// マッチャー設定
export const config = {
  matcher: ['/dashboard/:path*', '/api/:path*'],
};
```

## Route Handlers（API Routes）

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';

// GET /api/users
export async function GET(request: NextRequest) {
  const users = await db.users.findMany();
  return NextResponse.json(users);
}

// POST /api/users
export async function POST(request: NextRequest) {
  const body = await request.json();
  const user = await db.users.create({ data: body });
  return NextResponse.json(user, { status: 201 });
}

// app/api/users/[id]/route.ts
// GET /api/users/123
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const user = await db.users.findUnique({ where: { id: params.id } });

  if (!user) {
    return NextResponse.json({ error: 'User not found' }, { status: 404 });
  }

  return NextResponse.json(user);
}

// DELETE /api/users/123
export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  await db.users.delete({ where: { id: params.id } });
  return NextResponse.json({ success: true });
}
```

## キャッシュと再検証

### revalidatePath

```typescript
// app/actions.ts
'use server';

import { revalidatePath } from 'next/cache';

export async function updatePost(id: string, data: any) {
  await db.posts.update({ where: { id }, data });

  // 特定のパスを再検証
  revalidatePath('/posts');
  revalidatePath(`/posts/${id}`);
}
```

### revalidateTag

```typescript
// データフェッチ時にタグを付ける
const res = await fetch('https://api.example.com/posts', {
  next: { tags: ['posts'] },
});

// app/actions.ts
'use server';

import { revalidateTag } from 'next/cache';

export async function createPost(data: any) {
  await db.posts.create({ data });

  // タグで再検証
  revalidateTag('posts');
}
```

## 環境変数

```typescript
// .env.local
NEXT_PUBLIC_API_URL=https://api.example.com
DATABASE_URL=postgresql://...
SECRET_KEY=secret123

// Client Component で使用（NEXT_PUBLIC_ プレフィックスが必要）
const apiUrl = process.env.NEXT_PUBLIC_API_URL;

// Server Component / API Routes で使用
const dbUrl = process.env.DATABASE_URL;
const secretKey = process.env.SECRET_KEY;
```

## ベストプラクティス

1. **デフォルトでServer Componentsを使用**: Client Componentsは必要な場合のみ
2. **データフェッチングを並列化**: `Promise.all` を活用
3. **Suspenseでストリーミング**: 遅いコンポーネントを待たない
4. **適切なキャッシュ戦略**: SSG/ISR/SSRを使い分ける
5. **Server Actionsでフォーム処理**: type-safeなフォーム送信
6. **メタデータを適切に設定**: SEO対策
7. **エラーハンドリング**: error.tsx と not-found.tsx を活用

## Pages Router からの移行

| Pages Router | App Router |
|-------------|-----------|
| `pages/index.tsx` | `app/page.tsx` |
| `pages/about.tsx` | `app/about/page.tsx` |
| `pages/blog/[slug].tsx` | `app/blog/[slug]/page.tsx` |
| `pages/_app.tsx` | `app/layout.tsx` |
| `pages/_document.tsx` | `app/layout.tsx` |
| `pages/api/users.ts` | `app/api/users/route.ts` |
| `getStaticProps` | `fetch` with cache |
| `getServerSideProps` | `fetch` with no-store |
| `getStaticPaths` | `generateStaticParams` |

## 参考リンク

- [Next.js App Router 公式ドキュメント](https://nextjs.org/docs/app)
- [React Server Components](https://react.dev/blog/2023/03/22/react-labs-what-we-have-been-working-on-march-2023#react-server-components)
- [Next.js Examples](https://github.com/vercel/next.js/tree/canary/examples)

## 関連ガイド

### フロントエンド
- [React Server Components ガイド](../react/server_components_guide.md) - RSCの詳細な実装方法
- [TanStack Query ガイド](../../library/tanstack/tanstack_query.md) - データフェッチング・キャッシング
- [Vite ガイド](../../build/vite_guide.md) - ビルドツール

### UI・スタイリング
- [Tailwind CSS ガイド](../../../ui/css/tailwind_guide.md) - Next.jsでのTailwind設定
- [shadcn/ui ガイド](../../../ui/components/shadcn_ui_guide.md) - Next.js向けUIコンポーネント

### バックエンド統合
- [tRPC ガイド](../../../backend/api/trpc_guide.md) - Next.jsとの型安全な統合
- [Prisma ガイド](../../../backend/orm/prisma_guide.md) - データベースORM
- [Zod ガイド](../../../backend/validation/zod_guide.md) - バリデーション

### 認証
- [NextAuth.js ガイド](../../../auth/nextauth_guide.md) - Next.js向け認証

### デプロイ・インフラ
- [Vercel/Netlify ガイド](../../../infra/deploy/vercel_netlify_guide.md) - Next.jsのデプロイ
- [Docker ガイド](../../../infra/docker/docker_guide.md) - コンテナ化

### テスト
- [Vitest ガイド](../../../tools/testing/vitest_guide.md) - ユニットテスト
- [Playwright ガイド](../../../tools/testing/playwright_guide.md) - E2Eテスト
