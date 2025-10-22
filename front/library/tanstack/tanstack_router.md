# TanStack Router

## 概要

型安全で高性能な React 向けルーティングライブラリ。完全な型推論とコード分割対応。

## インストール

```bash
npm install @tanstack/react-router
npm install -D @tanstack/router-vite-plugin
```

## 基本セットアップ

### 1. Vite 設定

```ts
// vite.config.ts
import { defineConfig } from "vite";
import { TanStackRouterVite } from "@tanstack/router-vite-plugin";

export default defineConfig({
  plugins: [TanStackRouterVite()],
});
```

### 2. ルート定義

```tsx
// routes/__root.tsx
import { createRootRoute, Outlet, Link } from "@tanstack/react-router";

export const Route = createRootRoute({
  component: () => (
    <>
      <nav>
        <Link to="/">Home</Link>
        <Link to="/users">Users</Link>
      </nav>
      <Outlet />
    </>
  ),
});

// routes/index.tsx
import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  component: () => <div>Home Page</div>,
});

// routes/users/$userId.tsx
export const Route = createFileRoute("/users/$userId")({
  component: UserDetail,
  loader: ({ params }) => fetchUser(params.userId),
});

function UserDetail() {
  const { userId } = Route.useParams();
  const user = Route.useLoaderData();
  return <div>{user.name}</div>;
}
```

### 3. 検索パラメータ

```tsx
import { z } from "zod";

const searchSchema = z.object({
  page: z.number().default(1),
  search: z.string().default(""),
});

export const Route = createFileRoute("/users/")({
  validateSearch: searchSchema,
  component: UserList,
});

function UserList() {
  const { page, search } = Route.useSearch();
  const navigate = Route.useNavigate();

  return (
    <input
      value={search}
      onChange={(e) =>
        navigate({ search: { search: e.target.value, page: 1 } })
      }
    />
  );
}
```

## 主要機能

- **完全な型安全性**: パラメータ・検索まで全て型推論
- **コード分割**: 自動遅延ローディング
- **ローダー**: データプリロード
- **ネストルート**: 複雑なレイアウト対応
- **検索パラメータ**: バリデーション付き URL 状態管理

## 参考リンク

- 公式ドキュメント: https://tanstack.com/router/latest
