# TanStack Router

## 概要

型安全で高性能な React 向けルーティングライブラリ。完全な型推論とコード分割対応

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
import react from "@vitejs/plugin-react";
import { TanStackRouterVite } from "@tanstack/router-vite-plugin";

export default defineConfig({
  plugins: [react(), TanStackRouterVite()],
});
```

### 2. ルート定義

```tsx
// routes/__root.tsx
import { createRootRoute, Outlet } from "@tanstack/react-router";
import { TanStackRouterDevtools } from "@tanstack/router-devtools";

export const Route = createRootRoute({
  component: () => (
    <>
      <div className="p-2 flex gap-2">
        <Link to="/" className="[&.active]:font-bold">
          Home
        </Link>
        <Link to="/users" className="[&.active]:font-bold">
          Users
        </Link>
      </div>
      <hr />
      <Outlet />
      <TanStackRouterDevtools />
    </>
  ),
});
```

### 3. ページルート

```tsx
// routes/index.tsx
import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  component: () => <div>Hello Home!</div>,
});

// routes/users/index.tsx
import { createFileRoute } from "@tanstack/react-router";
import { useUsers } from "../../hooks/useUsers";

export const Route = createFileRoute("/users/")({
  component: UserList,
  loader: ({ context }) => {
    // プリロード
    return context.queryClient.ensureQueryData(usersQueryOptions());
  },
});

function UserList() {
  const { data: users } = useUsers();
  return (
    <div>
      {users?.map((user) => (
        <Link key={user.id} to="/users/$userId" params={{ userId: user.id }}>
          {user.name}
        </Link>
      ))}
    </div>
  );
}
```

## 実務レベルの機能

### 4. パラメータ付きルート

```tsx
// routes/users/$userId.tsx
import { createFileRoute } from "@tanstack/react-router";
import { userQueryOptions } from "../../hooks/useUser";

export const Route = createFileRoute("/users/$userId")({
  component: UserDetail,
  loader: ({ params, context }) => {
    return context.queryClient.ensureQueryData(userQueryOptions(params.userId));
  },
  errorComponent: ({ error }) => (
    <div>ユーザーが見つかりません: {error.message}</div>
  ),
});

function UserDetail() {
  const { userId } = Route.useParams();
  const { data: user } = useUser(userId);

  return (
    <div>
      <h1>{user?.name}</h1>
      <p>{user?.email}</p>
    </div>
  );
}
```

### 5. 検索パラメータ

```tsx
// routes/users/index.tsx
import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

const userSearchSchema = z.object({
  page: z.number().optional().default(1),
  search: z.string().optional().default(""),
  role: z.enum(["admin", "user", "guest"]).optional(),
});

export const Route = createFileRoute("/users/")({
  component: UserList,
  validateSearch: userSearchSchema,
  loaderDeps: ({ search }) => ({ search }),
  loader: ({ deps: { search }, context }) => {
    return context.queryClient.ensureQueryData(usersQueryOptions(search));
  },
});

function UserList() {
  const navigate = Route.useNavigate();
  const { page, search, role } = Route.useSearch();

  const updateSearch = (updates: Partial<typeof search>) => {
    navigate({
      search: (prev) => ({ ...prev, ...updates }),
    });
  };

  return (
    <div>
      <input
        value={search}
        onChange={(e) => updateSearch({ search: e.target.value, page: 1 })}
        placeholder="検索..."
      />
      <select
        value={role || ""}
        onChange={(e) =>
          updateSearch({
            role: e.target.value as any,
            page: 1,
          })
        }
      >
        <option value="">全ての役割</option>
        <option value="admin">管理者</option>
        <option value="user">ユーザー</option>
      </select>
    </div>
  );
}
```

### 6. レイアウトとネストルート

```tsx
// routes/_authenticated.tsx
import { createFileRoute, redirect } from "@tanstack/react-router";
import { useAuth } from "../hooks/useAuth";

export const Route = createFileRoute("/_authenticated")({
  beforeLoad: ({ context }) => {
    if (!context.auth.isAuthenticated) {
      throw redirect({
        to: "/login",
        search: {
          redirect: location.href,
        },
      });
    }
  },
  component: AuthenticatedLayout,
});

function AuthenticatedLayout() {
  const { user } = useAuth();

  return (
    <div className="flex">
      <nav className="w-64 bg-gray-100 p-4">
        <div className="mb-4">
          <img src={user.avatar} className="w-8 h-8 rounded-full" />
          <span>{user.name}</span>
        </div>
        <Link to="/dashboard">ダッシュボード</Link>
        <Link to="/users">ユーザー管理</Link>
      </nav>
      <main className="flex-1 p-4">
        <Outlet />
      </main>
    </div>
  );
}

// routes/_authenticated/dashboard.tsx
export const Route = createFileRoute("/_authenticated/dashboard")({
  component: () => <div>ダッシュボード</div>,
});
```

### 7. コード分割とローディング

```tsx
// routes/admin.lazy.tsx
import { createLazyFileRoute } from "@tanstack/react-router";

export const Route = createLazyFileRoute("/admin")({
  component: AdminPage,
});

function AdminPage() {
  return <div>管理画面</div>;
}

// ローディング状態
// routes/__root.tsx
export const Route = createRootRoute({
  component: RootComponent,
  pendingComponent: () => <div>ページを読み込み中...</div>,
  errorComponent: ({ error }) => (
    <div>エラーが発生しました: {error.message}</div>
  ),
});
```

### 8. ルーターコンテキスト

```tsx
// main.tsx
import { createRouter, RouterProvider } from "@tanstack/react-router";
import { QueryClient } from "@tanstack/react-query";
import { routeTree } from "./routeTree.gen";

const queryClient = new QueryClient();

const router = createRouter({
  routeTree,
  context: {
    queryClient,
    auth: undefined!, // 後で設定
  },
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

function App() {
  const auth = useAuth();

  return (
    <RouterProvider
      router={router}
      context={{
        queryClient,
        auth,
      }}
    />
  );
}
```

### 9. フォームとナビゲーション

```tsx
// components/UserForm.tsx
function UserForm({ user }: { user?: User }) {
  const navigate = useNavigate();
  const createUser = useCreateUser();

  const handleSubmit = async (data: UserFormData) => {
    try {
      const newUser = await createUser.mutateAsync(data);
      navigate({
        to: "/users/$userId",
        params: { userId: newUser.id },
        search: { tab: "profile" },
      });
    } catch (error) {
      // エラーハンドリング
    }
  };

  return <form onSubmit={handleSubmit}>{/* フォーム要素 */}</form>;
}
```

### 10. 高度な機能

```tsx
// カスタムフック
export function useUserNavigation() {
  const navigate = useNavigate();

  const goToUser = (userId: string, tab?: string) => {
    navigate({
      to: "/users/$userId",
      params: { userId },
      search: { tab },
    });
  };

  const goToUsers = (filters?: UserFilters) => {
    navigate({
      to: "/users",
      search: filters,
    });
  };

  return { goToUser, goToUsers };
}

// ルートマスク（URL変更なしのナビゲーション）
function Modal() {
  const navigate = useNavigate();

  return (
    <div className="modal">
      <button
        onClick={() =>
          navigate({
            to: "/users/$userId/edit",
            params: { userId: "123" },
            mask: { to: "/users/$userId", params: { userId: "123" } },
          })
        }
      >
        編集（URLを変更せず）
      </button>
    </div>
  );
}

// ルートガード
const adminRoutes = createFileRoute("/_authenticated/admin")({
  beforeLoad: ({ context }) => {
    if (!context.auth.user?.isAdmin) {
      throw redirect({ to: "/unauthorized" });
    }
  },
});
```

### 11. メタデータと SEO

```tsx
// routes/users/$userId.tsx
export const Route = createFileRoute("/users/$userId")({
  component: UserDetail,
  loader: async ({ params, context }) => {
    const user = await context.queryClient.ensureQueryData(
      userQueryOptions(params.userId)
    );
    return { user };
  },
  meta: ({ loaderData }) => [
    { title: `${loaderData.user.name} - ユーザー詳細` },
    { name: "description", content: `${loaderData.user.name}のプロフィール` },
  ],
});
```

## 主要機能

- **完全な型安全性**: パラメータ、検索、ローダーまで全て型推論
- **コード分割**: 自動的な遅延ローディング
- **ローダー**: データプリロードとキャッシュ統合
- **ネストルート**: 複雑なレイアウト対応
- **検索パラメータ**: バリデーション付き URL 状態管理
- **エラーバウンダリ**: ルートレベルのエラーハンドリング

## メリット・デメリット

**メリット**: 完全な型安全、高性能、TanStack Query 統合、優れた DX  
**デメリット**: 学習コスト、新しいライブラリ、エコシステムが発展途上
