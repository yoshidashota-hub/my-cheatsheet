# TanStack Table

## 概要

ヘッドレスで高性能なテーブルライブラリ。フレームワーク非依存で柔軟なカスタマイズが可能

## インストール

```bash
npm install @tanstack/react-table
```

## 基本セットアップ

### 1. 基本テーブル

```tsx
// components/UserTable.tsx
import {
  useReactTable,
  getCoreRowModel,
  flexRender,
  createColumnHelper,
} from "@tanstack/react-table";

interface User {
  id: string;
  name: string;
  email: string;
  role: string;
  createdAt: string;
}

const columnHelper = createColumnHelper<User>();

const columns = [
  columnHelper.accessor("name", {
    header: "名前",
    cell: (info) => info.getValue(),
  }),
  columnHelper.accessor("email", {
    header: "メール",
    cell: (info) => <a href={`mailto:${info.getValue()}`}>{info.getValue()}</a>,
  }),
  columnHelper.accessor("role", {
    header: "役割",
    cell: (info) => (
      <span className={`badge ${info.getValue()}`}>{info.getValue()}</span>
    ),
  }),
  columnHelper.accessor("createdAt", {
    header: "作成日",
    cell: (info) => new Date(info.getValue()).toLocaleDateString("ja-JP"),
  }),
];

export const UserTable = ({ data }: { data: User[] }) => {
  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  return (
    <table className="table">
      <thead>
        {table.getHeaderGroups().map((headerGroup) => (
          <tr key={headerGroup.id}>
            {headerGroup.headers.map((header) => (
              <th key={header.id}>
                {flexRender(
                  header.column.columnDef.header,
                  header.getContext()
                )}
              </th>
            ))}
          </tr>
        ))}
      </thead>
      <tbody>
        {table.getRowModel().rows.map((row) => (
          <tr key={row.id}>
            {row.getVisibleCells().map((cell) => (
              <td key={cell.id}>
                {flexRender(cell.column.columnDef.cell, cell.getContext())}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
};
```

## 実務レベルの機能

### 2. ソート機能

```tsx
import { getSortedRowModel } from '@tanstack/react-table'

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
  state: {
    sorting,
  },
  onSortingChange: setSorting,
})

// ヘッダーでソート
<th key={header.id}>
  <div
    className={header.column.getCanSort() ? 'cursor-pointer' : ''}
    onClick={header.column.getToggleSortingHandler()}
  >
    {flexRender(header.column.columnDef.header, header.getContext())}
    {{
      asc: ' 🔼',
      desc: ' 🔽',
    }[header.column.getIsSorted() as string] ?? null}
  </div>
</th>
```

### 3. フィルタリング

```tsx
import { getFilteredRowModel } from '@tanstack/react-table'

const [globalFilter, setGlobalFilter] = useState('')

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  state: {
    globalFilter,
  },
  onGlobalFilterChange: setGlobalFilter,
})

// グローバル検索
<input
  value={globalFilter ?? ''}
  onChange={e => setGlobalFilter(e.target.value)}
  placeholder="検索..."
  className="search-input"
/>

// カラムフィルター
const columns = [
  columnHelper.accessor('role', {
    header: '役割',
    filterFn: 'includesString',
    cell: info => info.getValue(),
  }),
]
```

### 4. ページネーション

```tsx
import { getPaginationRowModel } from '@tanstack/react-table'

const [pagination, setPagination] = useState({
  pageIndex: 0,
  pageSize: 10,
})

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getPaginationRowModel: getPaginationRowModel(),
  state: {
    pagination,
  },
  onPaginationChange: setPagination,
})

// ページネーションUI
<div className="pagination">
  <button
    onClick={() => table.setPageIndex(0)}
    disabled={!table.getCanPreviousPage()}
  >
    最初
  </button>
  <button
    onClick={() => table.previousPage()}
    disabled={!table.getCanPreviousPage()}
  >
    前へ
  </button>
  <span>
    ページ {table.getState().pagination.pageIndex + 1} / {table.getPageCount()}
  </span>
  <button
    onClick={() => table.nextPage()}
    disabled={!table.getCanNextPage()}
  >
    次へ
  </button>
  <button
    onClick={() => table.setPageIndex(table.getPageCount() - 1)}
    disabled={!table.getCanNextPage()}
  >
    最後
  </button>
</div>
```

### 5. 行選択

```tsx
import { useState } from "react";

const [rowSelection, setRowSelection] = useState({});

const columns = [
  // 選択チェックボックス
  columnHelper.display({
    id: "select",
    header: ({ table }) => (
      <input
        type="checkbox"
        checked={table.getIsAllRowsSelected()}
        onChange={table.getToggleAllRowsSelectedHandler()}
      />
    ),
    cell: ({ row }) => (
      <input
        type="checkbox"
        checked={row.getIsSelected()}
        onChange={row.getToggleSelectedHandler()}
      />
    ),
  }),
  // その他のカラム
];

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  enableRowSelection: true,
  state: {
    rowSelection,
  },
  onRowSelectionChange: setRowSelection,
});

// 選択された行の取得
const selectedRows = table.getFilteredSelectedRowModel().rows;
```

### 6. アクションカラム

```tsx
const columns = [
  // その他のカラム...
  columnHelper.display({
    id: "actions",
    header: "アクション",
    cell: ({ row }) => (
      <div className="action-buttons">
        <button onClick={() => handleEdit(row.original)} className="btn-edit">
          編集
        </button>
        <button
          onClick={() => handleDelete(row.original.id)}
          className="btn-delete"
        >
          削除
        </button>
      </div>
    ),
  }),
];
```

### 7. カラム表示制御

```tsx
import { useState } from 'react'

const [columnVisibility, setColumnVisibility] = useState({})

const table = useReactTable({
  data,
  columns,
  state: {
    columnVisibility,
  },
  onColumnVisibilityChange: setColumnVisibility,
})

// カラム表示切り替えUI
<div className="column-toggle">
  {table.getAllLeafColumns().map(column => (
    <label key={column.id}>
      <input
        type="checkbox"
        checked={column.getIsVisible()}
        onChange={column.getToggleVisibilityHandler()}
      />
      {column.columnDef.header}
    </label>
  ))}
</div>
```

### 8. TanStack Query との統合

```tsx
import { useUsers } from "../hooks/useUsers";

export const UserTableContainer = () => {
  const [sorting, setSorting] = useState([]);
  const [pagination, setPagination] = useState({
    pageIndex: 0,
    pageSize: 10,
  });
  const [globalFilter, setGlobalFilter] = useState("");

  // サーバーサイドの処理
  const { data, isLoading, error } = useUsers({
    page: pagination.pageIndex,
    size: pagination.pageSize,
    sort: sorting,
    search: globalFilter,
  });

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <UserTable
      data={data?.users || []}
      totalCount={data?.totalCount || 0}
      pagination={pagination}
      onPaginationChange={setPagination}
      sorting={sorting}
      onSortingChange={setSorting}
      globalFilter={globalFilter}
      onGlobalFilterChange={setGlobalFilter}
    />
  );
};
```

### 9. カスタムスタイリング

```tsx
// TailwindCSS での例
<table className="min-w-full bg-white border border-gray-200">
  <thead className="bg-gray-50">
    {table.getHeaderGroups().map((headerGroup) => (
      <tr key={headerGroup.id}>
        {headerGroup.headers.map((header) => (
          <th
            key={header.id}
            className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
          >
            {flexRender(header.column.columnDef.header, header.getContext())}
          </th>
        ))}
      </tr>
    ))}
  </thead>
  <tbody className="bg-white divide-y divide-gray-200">
    {table.getRowModel().rows.map((row) => (
      <tr key={row.id} className="hover:bg-gray-50">
        {row.getVisibleCells().map((cell) => (
          <td
            key={cell.id}
            className="px-6 py-4 whitespace-nowrap text-sm text-gray-900"
          >
            {flexRender(cell.column.columnDef.cell, cell.getContext())}
          </td>
        ))}
      </tr>
    ))}
  </tbody>
</table>
```

### 10. 仮想化（大量データ対応）

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";

export const VirtualizedTable = ({ data }: { data: User[] }) => {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: table.getRowModel().rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
  });

  return (
    <div ref={parentRef} className="h-96 overflow-auto">
      <div style={{ height: `${virtualizer.getTotalSize()}px` }}>
        {virtualizer.getVirtualItems().map((virtualRow) => {
          const row = table.getRowModel().rows[virtualRow.index];
          return (
            <div
              key={row.id}
              style={{
                position: "absolute",
                top: 0,
                left: 0,
                width: "100%",
                height: `${virtualRow.size}px`,
                transform: `translateY(${virtualRow.start}px)`,
              }}
            >
              {row.getVisibleCells().map((cell) => (
                <span key={cell.id}>
                  {flexRender(cell.column.columnDef.cell, cell.getContext())}
                </span>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
};
```

## 主要機能

- **ヘッドレス設計**: UI は完全に自由にカスタマイズ可能
- **ソート・フィルタ**: 高性能なクライアント/サーバー側処理
- **ページネーション**: 効率的な大量データ処理
- **行選択**: 単一・複数選択対応
- **カラム制御**: 表示/非表示、リサイズ、並び替え
- **仮想化**: 大量データの高速レンダリング

## メリット・デメリット

**メリット**: 高性能、柔軟性、TypeScript 対応、フレームワーク非依存  
**デメリット**: 学習コスト、セットアップの複雑さ、UI は自作が必要
