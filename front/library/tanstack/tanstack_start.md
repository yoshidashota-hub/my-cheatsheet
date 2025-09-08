# TanStack Start

## 概要

フルスタック React フレームワーク。TanStack Router ベースで、SSR、SSG、API Routes 対応

## インストール

```bash
npx create-start@latest my-app
cd my-app
npm install
```

## 基本セットアップ

### 1. プロジェクト構造

```project
my-app/
├── app/
│   ├── routes/
│   │   ├── __root.tsx
│   │   ├── index.tsx
│   │   └── api/
│   │       └── users.ts
│   ├── client.tsx
│   ├── server.tsx
│   └── ssr.tsx
├── public/
├── vite.config.ts
└── package.json
```

### 2. ルートレイアウト

```tsx
// app/routes/__root.tsx
import {
  createRootRoute,
  Outlet,
  ScrollRestoration,
} from "@tanstack/react-router";
import { Meta, Scripts } from "@tanstack/start";

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: "My App" },
    ],
  }),
  component: RootComponent,
});

function RootComponent() {
  return (
    <html lang="ja">
      <head>
        <Meta />
      </head>
      <body>
        <div className="min-h-screen bg-gray-50">
          <nav className="bg-white shadow-sm border-b">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
              <div className="flex justify-between h-16 items-center">
                <h1 className="text-xl font-semibold">My App</h1>
                <div className="space-x-4">
                  <Link to="/" className="text-gray-700 hover:text-gray-900">
                    Home
                  </Link>
                  <Link
                    to="/users"
                    className="text-gray-700 hover:text-gray-900"
                  >
                    Users
                  </Link>
                </div>
              </div>
            </div>
          </nav>
          <main>
            <Outlet />
          </main>
        </div>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}
```

## 実務レベルの機能

### 3. SSR ページ

```tsx
// app/routes/index.tsx
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/start";

// サーバー関数
const getStats = createServerFn("GET", async () => {
  // サーバーサイドでのデータ取得
  const stats = await fetch("https://api.example.com/stats").then((r) =>
    r.json()
  );
  return stats;
});

export const Route = createFileRoute("/")({
  component: HomePage,
  loader: () => getStats(),
});

function HomePage() {
  const stats = Route.useLoaderData();

  return (
    <div className="max-w-7xl mx-auto py-8 px-4">
      <h1 className="text-3xl font-bold text-gray-900 mb-8">
        Welcome to My App
      </h1>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-semibold text-gray-900">総ユーザー数</h3>
          <p className="text-3xl font-bold text-blue-600">{stats.totalUsers}</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-semibold text-gray-900">
            アクティブユーザー
          </h3>
          <p className="text-3xl font-bold text-green-600">
            {stats.activeUsers}
          </p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-semibold text-gray-900">今月の投稿</h3>
          <p className="text-3xl font-bold text-purple-600">
            {stats.monthlyPosts}
          </p>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-xl font-semibold mb-4">最新の機能</h2>
        <ul className="space-y-2">
          <li>• TanStack Routerによる型安全なルーティング</li>
          <li>• サーバーサイドレンダリング対応</li>
          <li>• API Routesでバックエンド構築</li>
          <li>• 自動コード分割</li>
        </ul>
      </div>
    </div>
  );
}
```

### 4. API Routes

```tsx
// app/routes/api/users.ts
import { createAPIFileRoute } from "@tanstack/start/api";
import { z } from "zod";

const userSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(["admin", "user"]),
});

// データベース（実際の実装ではPrisma等を使用）
let users = [
  { id: "1", name: "John Doe", email: "john@example.com", role: "admin" },
  { id: "2", name: "Jane Smith", email: "jane@example.com", role: "user" },
];

export const Route = createAPIFileRoute("/api/users")({
  GET: async ({ request }) => {
    // クエリパラメータの処理
    const url = new URL(request.url);
    const search = url.searchParams.get("search");
    const role = url.searchParams.get("role");

    let filteredUsers = users;

    if (search) {
      filteredUsers = filteredUsers.filter(
        (user) =>
          user.name.toLowerCase().includes(search.toLowerCase()) ||
          user.email.toLowerCase().includes(search.toLowerCase())
      );
    }

    if (role) {
      filteredUsers = filteredUsers.filter((user) => user.role === role);
    }

    return Response.json({
      users: filteredUsers,
      total: filteredUsers.length,
    });
  },

  POST: async ({ request }) => {
    try {
      const body = await request.json();
      const validatedData = userSchema.parse(body);

      const newUser = {
        id: String(Date.now()),
        ...validatedData,
      };

      users.push(newUser);

      return Response.json(newUser, { status: 201 });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return Response.json(
          { error: "Validation failed", details: error.errors },
          { status: 400 }
        );
      }

      return Response.json({ error: "Internal server error" }, { status: 500 });
    }
  },
});

// app/routes/api/users/$userId.ts
export const Route = createAPIFileRoute("/api/users/$userId")({
  GET: async ({ params }) => {
    const user = users.find((u) => u.id === params.userId);

    if (!user) {
      return Response.json({ error: "User not found" }, { status: 404 });
    }

    return Response.json(user);
  },

  PUT: async ({ params, request }) => {
    const userIndex = users.findIndex((u) => u.id === params.userId);

    if (userIndex === -1) {
      return Response.json({ error: "User not found" }, { status: 404 });
    }

    try {
      const body = await request.json();
      const validatedData = userSchema.partial().parse(body);

      users[userIndex] = { ...users[userIndex], ...validatedData };

      return Response.json(users[userIndex]);
    } catch (error) {
      return Response.json({ error: "Validation failed" }, { status: 400 });
    }
  },

  DELETE: async ({ params }) => {
    const userIndex = users.findIndex((u) => u.id === params.userId);

    if (userIndex === -1) {
      return Response.json({ error: "User not found" }, { status: 404 });
    }

    users.splice(userIndex, 1);
    return Response.json({ success: true });
  },
});
```

### 5. データフェッチングとキャッシュ

```tsx
// app/routes/users/index.tsx
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/start";
import { z } from "zod";

const searchSchema = z.object({
  search: z.string().optional(),
  role: z.enum(["admin", "user"]).optional(),
  page: z.number().min(1).optional().default(1),
});

// サーバー関数でデータ取得
const getUsers = createServerFn("GET", async (searchParams: any) => {
  const { search, role, page } = searchParams;

  const url = new URL("/api/users", "http://localhost:3000");
  if (search) url.searchParams.set("search", search);
  if (role) url.searchParams.set("role", role);
  url.searchParams.set("page", page.toString());

  const response = await fetch(url.toString());
  return response.json();
});

export const Route = createFileRoute("/users/")({
  component: UsersPage,
  validateSearch: searchSchema,
  loaderDeps: ({ search }) => ({ search }),
  loader: ({ deps: { search } }) => getUsers(search),
});

function UsersPage() {
  const { users, total } = Route.useLoaderData();
  const { search, role, page } = Route.useSearch();
  const navigate = Route.useNavigate();

  const updateSearch = (updates: any) => {
    navigate({
      search: (prev) => ({ ...prev, ...updates, page: 1 }),
    });
  };

  return (
    <div className="max-w-7xl mx-auto py-8 px-4">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-900">
          ユーザー管理 ({total}人)
        </h1>
        <button className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700">
          新規ユーザー
        </button>
      </div>

      {/* 検索・フィルター */}
      <div className="bg-white p-4 rounded-lg shadow mb-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <input
            type="text"
            placeholder="名前またはメールで検索..."
            value={search || ""}
            onChange={(e) => updateSearch({ search: e.target.value })}
            className="border border-gray-300 rounded-md px-3 py-2"
          />
          <select
            value={role || ""}
            onChange={(e) =>
              updateSearch({ role: e.target.value || undefined })
            }
            className="border border-gray-300 rounded-md px-3 py-2"
          >
            <option value="">全ての役割</option>
            <option value="admin">管理者</option>
            <option value="user">ユーザー</option>
          </select>
        </div>
      </div>

      {/* ユーザーリスト */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                ユーザー
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                役割
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                アクション
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {users.map((user: any) => (
              <tr key={user.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div>
                    <div className="text-sm font-medium text-gray-900">
                      {user.name}
                    </div>
                    <div className="text-sm text-gray-500">{user.email}</div>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span
                    className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                      user.role === "admin"
                        ? "bg-purple-100 text-purple-800"
                        : "bg-green-100 text-green-800"
                    }`}
                  >
                    {user.role === "admin" ? "管理者" : "ユーザー"}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <Link
                    to="/users/$userId"
                    params={{ userId: user.id }}
                    className="text-blue-600 hover:text-blue-900 mr-4"
                  >
                    詳細
                  </Link>
                  <button className="text-red-600 hover:text-red-900">
                    削除
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
```

### 6. 認証とミドルウェア

```tsx
// app/utils/auth.ts
import { createServerFn } from "@tanstack/start";

export const getCurrentUser = createServerFn("GET", async () => {
  // セッション/JWT確認ロジック
  const user = await validateSession();
  return user;
});

export const requireAuth = createServerFn("GET", async () => {
  const user = await getCurrentUser();
  if (!user) {
    throw redirect({ to: "/login" });
  }
  return user;
});

// app/routes/_authenticated.tsx
import { createFileRoute, redirect } from "@tanstack/react-router";
import { requireAuth } from "../utils/auth";

export const Route = createFileRoute("/_authenticated")({
  beforeLoad: async () => {
    // 認証チェック
    return await requireAuth();
  },
  component: AuthenticatedLayout,
});

function AuthenticatedLayout() {
  const user = Route.useLoaderData();

  return (
    <div className="flex">
      <aside className="w-64 bg-gray-800 text-white p-4">
        <div className="mb-6">
          <h2 className="text-lg font-semibold">{user.name}</h2>
          <p className="text-gray-400">{user.email}</p>
        </div>
        <nav>
          <Link
            to="/dashboard"
            className="block py-2 px-4 rounded hover:bg-gray-700"
          >
            ダッシュボード
          </Link>
          <Link
            to="/users"
            className="block py-2 px-4 rounded hover:bg-gray-700"
          >
            ユーザー管理
          </Link>
        </nav>
      </aside>
      <main className="flex-1">
        <Outlet />
      </main>
    </div>
  );
}
```

### 7. フォーム処理

```tsx
// app/routes/users/new.tsx
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/start";
import { useForm } from "@tanstack/react-form";
import { zodValidator } from "@tanstack/zod-form-adapter";
import { z } from "zod";

const userSchema = z.object({
  name: z.string().min(1, "名前は必須です"),
  email: z.string().email("有効なメールアドレスを入力してください"),
  role: z.enum(["admin", "user"]),
});

const createUser = createServerFn("POST", async (formData: any) => {
  const response = await fetch("/api/users", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(formData),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message);
  }

  return response.json();
});

export const Route = createFileRoute("/_authenticated/users/new")({
  component: NewUserPage,
});

function NewUserPage() {
  const navigate = Route.useNavigate();

  const form = useForm({
    defaultValues: {
      name: "",
      email: "",
      role: "user" as const,
    },
    validatorAdapter: zodValidator,
    validators: {
      onChange: userSchema,
    },
    onSubmit: async ({ value }) => {
      try {
        await createUser(value);
        navigate({ to: "/users" });
      } catch (error) {
        form.setErrorMap({
          onSubmit:
            error instanceof Error ? error.message : "エラーが発生しました",
        });
      }
    },
  });

  return (
    <div className="max-w-2xl mx-auto py-8 px-4">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">
        新規ユーザー作成
      </h1>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          form.handleSubmit();
        }}
        className="space-y-6"
      >
        <form.Field
          name="name"
          children={(field) => (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                名前
              </label>
              <input
                value={field.state.value}
                onChange={(e) => field.handleChange(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
              {field.state.meta.errors.length > 0 && (
                <p className="mt-1 text-sm text-red-600">
                  {field.state.meta.errors[0]}
                </p>
              )}
            </div>
          )}
        />

        <form.Subscribe
          selector={(state) => [
            state.canSubmit,
            state.isSubmitting,
            state.errorMap,
          ]}
          children={([canSubmit, isSubmitting, errorMap]) => (
            <div>
              {errorMap.onSubmit && (
                <div className="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded">
                  {errorMap.onSubmit}
                </div>
              )}
              <button
                type="submit"
                disabled={!canSubmit}
                className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 disabled:opacity-50"
              >
                {isSubmitting ? "作成中..." : "ユーザー作成"}
              </button>
            </div>
          )}
        />
      </form>
    </div>
  );
}
```

### 8. 本番環境設定

```ts
// vite.config.ts
import { defineConfig } from 'vite'
import { tanstackStartVitePlugin } from '@tanstack/start/vite'

export default defineConfig({
  plugins: [
    tanstackStartVitePlugin({
      // SSRオプション
      ssr: {
        enabled: true,
        // プリレンダリング設定
        prerender: ['/'],
      },
      // API Routes設定
      api: {
        prefix: '/api',
      },
    }),
  ],
  // 本番環境最適化
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['@tanstack/react-router'],
        },
      },
    },
  },
})

// package.json スクリプト
{
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "start": "vite preview",
    "deploy": "npm run build && npm run start"
  }
}
```

## 主要機能

- **フルスタック**: フロントエンド + API Routes
- **SSR/SSG**: サーバーサイドレンダリング対応
- **型安全**: TanStack Router ベースの完全な型推論
- **サーバー関数**: 型安全なサーバーサイド処理
- **自動最適化**: コード分割、プリロード
- **ゼロ設定**: 設定不要で開始可能

## メリット・デメリット

**メリット**: TanStack エコシステム統合、型安全、フルスタック、高性能  
**デメリット**: 新しいフレームワーク、エコシステムが発展途上、学習コスト
