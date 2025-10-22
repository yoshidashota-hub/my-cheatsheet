# TanStack Start

## 概要

フルスタック React フレームワーク。TanStack Router ベースで、SSR、SSG、API Routes 対応。

## インストール

```bash
npx create-start@latest my-app
cd my-app
npm install
```

## 基本構成

### 1. ルートレイアウト

```tsx
// app/routes/__root.tsx
import { createRootRoute, Outlet } from "@tanstack/react-router";
import { Meta, Scripts } from "@tanstack/start";

export const Route = createRootRoute({
  component: () => (
    <html>
      <head>
        <Meta />
      </head>
      <body>
        <Outlet />
        <Scripts />
      </body>
    </html>
  ),
});
```

### 2. SSR ページ

```tsx
// app/routes/index.tsx
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/start";

const getStats = createServerFn("GET", async () => {
  return await fetch("https://api.example.com/stats").then((r) => r.json());
});

export const Route = createFileRoute("/")({
  component: HomePage,
  loader: () => getStats(),
});

function HomePage() {
  const stats = Route.useLoaderData();
  return <div>総ユーザー数: {stats.totalUsers}</div>;
}
```

### 3. API Routes

```tsx
// app/routes/api/users.ts
import { createAPIFileRoute } from "@tanstack/start/api";

export const Route = createAPIFileRoute("/api/users")({
  GET: async ({ request }) => {
    const users = await db.users.findMany();
    return Response.json({ users });
  },

  POST: async ({ request }) => {
    const body = await request.json();
    const user = await db.users.create({ data: body });
    return Response.json(user, { status: 201 });
  },
});
```

### 4. フォーム処理

```tsx
import { useForm } from "@tanstack/react-form";
import { createServerFn } from "@tanstack/start";

const createUser = createServerFn("POST", async (formData) => {
  return await fetch("/api/users", {
    method: "POST",
    body: JSON.stringify(formData),
  });
});

function UserForm() {
  const form = useForm({
    defaultValues: { name: "", email: "" },
    onSubmit: async ({ value }) => {
      await createUser(value);
    },
  });

  return <form onSubmit={form.handleSubmit}>{/* フォーム要素 */}</form>;
}
```

## 主要機能

- **フルスタック**: フロントエンド + API Routes
- **SSR/SSG**: サーバーサイドレンダリング対応
- **型安全**: 完全な型推論
- **サーバー関数**: 型安全なサーバー処理
- **自動最適化**: コード分割、プリロード

## 参考リンク

- 公式ドキュメント: https://tanstack.com/start/latest
