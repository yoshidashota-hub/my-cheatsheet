# TanStack Query

## 概要

サーバー状態管理とデータフェッチングのための強力なライブラリ。

## インストール

```bash
npm install @tanstack/react-query
```

## 基本セットアップ

```tsx
import {
  QueryClient,
  QueryClientProvider,
  useQuery,
  useMutation,
  useQueryClient,
} from "@tanstack/react-query";

// 1. QueryClientの作成
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5分
      retry: 3,
    },
  },
});

// 2. Providerでラップ
function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <UserList />
    </QueryClientProvider>
  );
}

// 3. データ取得
function UserList() {
  const { data, isLoading } = useQuery({
    queryKey: ["users"],
    queryFn: () => fetch("/api/users").then((r) => r.json()),
  });

  if (isLoading) return <div>Loading...</div>;
  return (
    <ul>
      {data?.map((user) => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}

// 4. データ更新
function CreateUser() {
  const queryClient = useQueryClient();
  const createUser = useMutation({
    mutationFn: (userData) =>
      fetch("/api/users", {
        method: "POST",
        body: JSON.stringify(userData),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });

  return (
    <button onClick={() => createUser.mutate({ name: "John" })}>作成</button>
  );
}
```

## 主要機能

- **自動キャッシュ**: レスポンスを自動的にキャッシュ
- **バックグラウンド更新**: データを最新に保つ
- **楽観的更新**: UI 即座更新
- **無限スクロール**: useInfiniteQuery 対応
- **重複削除**: 同じリクエストの重複を防ぐ

## 参考リンク

- 公式ドキュメント: https://tanstack.com/query/latest

## 関連ガイド

### フロントエンド
- [Next.js App Router ガイド](../../framework/nextjs/app_router_guide.md) - TanStack Query with Next.js
- [React Server Components ガイド](../../framework/react/server_components_guide.md) - RSCとの組み合わせ
- [Zustand ガイド](../../state/zustand_guide.md) - グローバル状態管理

### バックエンド統合
- [tRPC ガイド](../../../backend/api/trpc_guide.md) - 型安全なAPI呼び出し
- [REST API 設計ガイド](../../../backend/api/rest_api_design_guide.md) - REST APIの設計

### テスト
- [Vitest ガイド](../../../tools/testing/vitest_guide.md) - TanStack Queryのテスト
- [Testing Library ガイド](../../../tools/testing/testing_library_guide.md) - Reactコンポーネントのテスト
