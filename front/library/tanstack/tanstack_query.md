# TanStack Query (React Query)

## 概要

サーバー状態管理とデータフェッチングのための強力なライブラリ

## インストール

```bash
npm install @tanstack/react-query
```

## 基本セットアップ

### 1. QueryClient 設定

```tsx
// main.tsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 3,
      staleTime: 5 * 60 * 1000, // 5分
      gcTime: 10 * 60 * 1000, // 10分
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <MyApp />
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

### 2. カスタムフック（API 層）

```tsx
// hooks/useUsers.ts
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "../lib/api";

interface User {
  id: string;
  name: string;
  email: string;
}

// 一覧取得
export const useUsers = () => {
  return useQuery({
    queryKey: ["users"],
    queryFn: () => api.get<User[]>("/users"),
  });
};

// 詳細取得
export const useUser = (id: string) => {
  return useQuery({
    queryKey: ["users", id],
    queryFn: () => api.get<User>(`/users/${id}`),
    enabled: !!id, // idが存在する時のみ実行
  });
};

// 作成
export const useCreateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (userData: Omit<User, "id">) =>
      api.post<User>("/users", userData),
    onSuccess: () => {
      // キャッシュを無効化して再取得
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
};

// 更新
export const useUpdateUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, ...userData }: User) =>
      api.put<User>(`/users/${id}`, userData),
    onSuccess: (data, variables) => {
      // 楽観的更新
      queryClient.setQueryData(["users", variables.id], data);
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
};
```

## 実務レベルの使用例

### 3. エラーハンドリング

```tsx
// components/UserList.tsx
import { useUsers } from "../hooks/useUsers";

export const UserList = () => {
  const { data: users, isLoading, error, refetch } = useUsers();

  if (isLoading) return <div>Loading...</div>;

  if (error) {
    return (
      <div>
        <p>エラーが発生しました: {error.message}</p>
        <button onClick={() => refetch()}>再試行</button>
      </div>
    );
  }

  return (
    <ul>
      {users?.map((user) => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
};
```

### 4. 楽観的更新

```tsx
// components/UserForm.tsx
export const UserForm = ({ userId }: { userId?: string }) => {
  const queryClient = useQueryClient();
  const updateUser = useUpdateUser();

  const handleSubmit = async (formData: User) => {
    // 楽観的更新
    const previousData = queryClient.getQueryData(["users", userId]);
    queryClient.setQueryData(["users", userId], formData);

    try {
      await updateUser.mutateAsync(formData);
    } catch (error) {
      // エラー時にロールバック
      queryClient.setQueryData(["users", userId], previousData);
      throw error;
    }
  };

  return <form onSubmit={handleSubmit}>{/* フォーム要素 */}</form>;
};
```

### 5. 無限スクロール

```tsx
// hooks/useInfiniteUsers.ts
export const useInfiniteUsers = () => {
  return useInfiniteQuery({
    queryKey: ["users", "infinite"],
    queryFn: ({ pageParam = 0 }) =>
      api.get(`/users?page=${pageParam}&limit=20`),
    getNextPageParam: (lastPage, pages) =>
      lastPage.hasMore ? pages.length : undefined,
    initialPageParam: 0,
  });
};

// components/InfiniteUserList.tsx
export const InfiniteUserList = () => {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } =
    useInfiniteUsers();

  return (
    <div>
      {data?.pages.map((page, i) => (
        <div key={i}>
          {page.users.map((user) => (
            <div key={user.id}>{user.name}</div>
          ))}
        </div>
      ))}

      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          {isFetchingNextPage ? "Loading..." : "Load More"}
        </button>
      )}
    </div>
  );
};
```

### 6. バックグラウンド同期

```tsx
// hooks/useRealtimeUsers.ts
export const useRealtimeUsers = () => {
  const queryClient = useQueryClient();

  useEffect(() => {
    const ws = new WebSocket("ws://localhost:8080/users");

    ws.onmessage = (event) => {
      const update = JSON.parse(event.data);

      // リアルタイム更新
      queryClient.invalidateQueries({ queryKey: ["users"] });
    };

    return () => ws.close();
  }, [queryClient]);

  return useUsers();
};
```

## パフォーマンス最適化

### 7. キャッシュ戦略

```tsx
// 設定例
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5分間はフレッシュ
      gcTime: 30 * 60 * 1000, // 30分間キャッシュ保持
      retry: (failureCount, error) => {
        if (error.status === 404) return false;
        return failureCount < 3;
      },
    },
  },
});

// 重要でないデータは長めのstaleTime
export const useUserStats = () => {
  return useQuery({
    queryKey: ["user-stats"],
    queryFn: () => api.get("/users/stats"),
    staleTime: 60 * 60 * 1000, // 1時間
  });
};
```

### 8. プリフェッチ

```tsx
// components/UserListItem.tsx
export const UserListItem = ({ user }: { user: User }) => {
  const queryClient = useQueryClient();

  const handleMouseEnter = () => {
    // ユーザー詳細をプリフェッチ
    queryClient.prefetchQuery({
      queryKey: ["users", user.id],
      queryFn: () => api.get(`/users/${user.id}`),
      staleTime: 5 * 60 * 1000,
    });
  };

  return (
    <div onMouseEnter={handleMouseEnter}>
      <Link to={`/users/${user.id}`}>{user.name}</Link>
    </div>
  );
};
```

## 主要機能

- **自動キャッシュ**: レスポンスを自動的にキャッシュ
- **バックグラウンド更新**: 自動でデータを最新に保つ
- **楽観的更新**: UI の即座な更新
- **重複削除**: 同じリクエストの重複を防ぐ
- **無限クエリ**: 無限スクロール対応
- **オフライン対応**: ネットワーク復旧時の自動同期

## メリット・デメリット

**メリット**: 強力なキャッシュ、楽観的更新、優れた DX、TypeScript 対応  
**デメリット**: 学習コスト、バンドルサイズ、複雑なキャッシュ戦略
