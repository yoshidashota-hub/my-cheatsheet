# TanStack Virtual

## 概要

大量データの効率的レンダリングのための仮想化ライブラリ。リスト、グリッド、テーブルに対応。

## インストール

```bash
npm install @tanstack/react-virtual
```

## 基本的な仮想リスト

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";
import { useRef } from "react";

function VirtualList() {
  const parentRef = useRef<HTMLDivElement>(null);
  const items = Array.from({ length: 10000 }, (_, i) => `Item ${i}`);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 60,
  });

  return (
    <div ref={parentRef} style={{ height: "400px", overflow: "auto" }}>
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: "relative",
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            {items[virtualItem.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

## TanStack Table との統合

```tsx
import { useReactTable, getCoreRowModel } from "@tanstack/react-table";
import { useVirtualizer } from "@tanstack/react-virtual";

function VirtualizedTable({ data }) {
  const tableContainerRef = useRef<HTMLDivElement>(null);

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  const { rows } = table.getRowModel();

  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => tableContainerRef.current,
    estimateSize: () => 50,
  });

  return (
    <div ref={tableContainerRef} style={{ height: "400px", overflow: "auto" }}>
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: "relative",
        }}
      >
        {virtualizer.getVirtualItems().map((virtualRow) => {
          const row = rows[virtualRow.index];
          return (
            <div
              key={row.id}
              style={{
                position: "absolute",
                top: 0,
                width: "100%",
                height: `${virtualRow.size}px`,
                transform: `translateY(${virtualRow.start}px)`,
              }}
            >
              {row.getVisibleCells().map((cell) => (
                <span key={cell.id}>{cell.getValue()}</span>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

## 無限スクロール

```tsx
import { useInfiniteQuery } from "@tanstack/react-query";

function InfiniteList() {
  const { data, fetchNextPage, hasNextPage } = useInfiniteQuery({
    queryKey: ["posts"],
    queryFn: ({ pageParam = 0 }) => fetchPosts(pageParam),
    getNextPageParam: (lastPage) => lastPage.nextCursor,
  });

  const allItems = data?.pages.flatMap((page) => page.posts) ?? [];

  const virtualizer = useVirtualizer({
    count: hasNextPage ? allItems.length + 1 : allItems.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 80,
  });

  useEffect(() => {
    const items = virtualizer.getVirtualItems();
    const lastItem = items[items.length - 1];

    if (lastItem?.index >= allItems.length - 1 && hasNextPage) {
      fetchNextPage();
    }
  }, [virtualizer.getVirtualItems()]);

  // レンダリング...
}
```

## 主要機能

- **効率的レンダリング**: 可視範囲のみレンダリング
- **動的サイズ**: アイテムサイズの動的測定
- **水平・垂直**: 両方向対応
- **グリッド**: 2D 仮想化
- **無限スクロール**: TanStack Query 統合

## 参考リンク

- 公式ドキュメント: https://tanstack.com/virtual/latest
