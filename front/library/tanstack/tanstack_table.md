# TanStack Table

## 概要

ヘッドレスで高性能なテーブルライブラリ。フレームワーク非依存で柔軟なカスタマイズが可能。

## インストール

```bash
npm install @tanstack/react-table
```

## 基本的な使用例

```tsx
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
}

const columnHelper = createColumnHelper<User>();

const columns = [
  columnHelper.accessor("name", {
    header: "名前",
    cell: (info) => info.getValue(),
  }),
  columnHelper.accessor("email", {
    header: "メール",
  }),
  columnHelper.accessor("role", {
    header: "役割",
  }),
];

function UserTable({ data }: { data: User[] }) {
  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  return (
    <table>
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
}
```

## ソート・フィルタ・ページネーション

```tsx
import { getSortedRowModel, getFilteredRowModel, getPaginationRowModel } from '@tanstack/react-table'

const [sorting, setSorting] = useState([])
const [globalFilter, setGlobalFilter] = useState('')

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  getPaginationRowModel: getPaginationRowModel(),
  state: { sorting, globalFilter },
  onSortingChange: setSorting,
  onGlobalFilterChange: setGlobalFilter,
})

// ソート
<th onClick={header.column.getToggleSortingHandler()}>
  {header.column.columnDef.header}
  {header.column.getIsSorted() === 'asc' ? ' 🔼' : header.column.getIsSorted() === 'desc' ? ' 🔽' : ''}
</th>

// 検索
<input value={globalFilter} onChange={e => setGlobalFilter(e.target.value)} />

// ページネーション
<button onClick={() => table.previousPage()} disabled={!table.getCanPreviousPage()}>前へ</button>
<button onClick={() => table.nextPage()} disabled={!table.getCanNextPage()}>次へ</button>
```

## 主要機能

- **ヘッドレス設計**: UI 完全カスタマイズ可能
- **ソート・フィルタ**: 高性能処理
- **ページネーション**: 大量データ対応
- **行選択**: 単一・複数選択
- **カラム制御**: 表示/非表示、リサイズ

## 参考リンク

- 公式ドキュメント: https://tanstack.com/table/latest
