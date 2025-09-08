# TanStack Virtual

## 概要

大量データの効率的レンダリングのための仮想化ライブラリ。リスト、グリッド、テーブルに対応

## インストール

```bash
npm install @tanstack/react-virtual
```

## 基本セットアップ

### 1. 仮想リスト

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";
import { useRef } from "react";

const items = Array.from({ length: 10000 }, (_, i) => `Item ${i}`);

export function VirtualList() {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 60, // 各アイテムの推定高さ
  });

  return (
    <div
      ref={parentRef}
      className="h-96 w-80 overflow-auto border border-gray-300"
    >
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          width: "100%",
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
            className="flex items-center px-4 border-b"
          >
            {items[virtualItem.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

## 実務レベルの機能

### 2. 動的サイズの仮想リスト

```tsx
interface Message {
  id: string;
  content: string;
  timestamp: Date;
  user: string;
}

export function ChatMessages({ messages }: { messages: Message[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: messages.length,
    getScrollElement: () => parentRef.current,
    estimateSize: (index) => {
      // メッセージの長さに基づく動的サイズ推定
      const message = messages[index];
      const baseHeight = 60;
      const extraHeight = Math.floor(message.content.length / 50) * 20;
      return baseHeight + extraHeight;
    },
    // スムーズスクロールのための設定
    overscan: 5,
  });

  return (
    <div ref={parentRef} className="h-96 overflow-auto bg-gray-50 p-2">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: "relative",
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => {
          const message = messages[virtualItem.index];
          return (
            <div
              key={virtualItem.key}
              data-index={virtualItem.index}
              ref={virtualizer.measureElement} // 動的サイズ測定
              style={{
                position: "absolute",
                top: 0,
                left: 0,
                width: "100%",
                transform: `translateY(${virtualItem.start}px)`,
              }}
            >
              <MessageItem message={message} />
            </div>
          );
        })}
      </div>
    </div>
  );
}

function MessageItem({ message }: { message: Message }) {
  return (
    <div className="bg-white rounded-lg p-3 mb-2 shadow-sm">
      <div className="flex justify-between items-center mb-1">
        <span className="font-semibold text-blue-600">{message.user}</span>
        <span className="text-xs text-gray-500">
          {message.timestamp.toLocaleTimeString()}
        </span>
      </div>
      <p className="text-gray-800">{message.content}</p>
    </div>
  );
}
```

### 3. TanStack Table との統合

```tsx
import {
  useReactTable,
  getCoreRowModel,
  flexRender,
} from "@tanstack/react-table";
import { useVirtualizer } from "@tanstack/react-virtual";

interface User {
  id: string;
  name: string;
  email: string;
  role: string;
}

export function VirtualizedTable({ data }: { data: User[] }) {
  const columns = [
    { accessorKey: "name", header: "名前" },
    { accessorKey: "email", header: "メール" },
    { accessorKey: "role", header: "役割" },
  ];

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  const tableContainerRef = useRef<HTMLDivElement>(null);

  const { rows } = table.getRowModel();

  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => tableContainerRef.current,
    estimateSize: () => 50,
    overscan: 10,
  });

  return (
    <div className="w-full">
      {/* ヘッダー */}
      <div className="bg-gray-100 border-b">
        {table.getHeaderGroups().map((headerGroup) => (
          <div key={headerGroup.id} className="flex">
            {headerGroup.headers.map((header) => (
              <div
                key={header.id}
                className="flex-1 p-3 font-semibold text-left"
              >
                {flexRender(
                  header.column.columnDef.header,
                  header.getContext()
                )}
              </div>
            ))}
          </div>
        ))}
      </div>

      {/* 仮想化されたボディ */}
      <div ref={tableContainerRef} className="h-96 overflow-auto">
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
                  left: 0,
                  width: "100%",
                  height: `${virtualRow.size}px`,
                  transform: `translateY(${virtualRow.start}px)`,
                }}
                className="flex border-b hover:bg-gray-50"
              >
                {row.getVisibleCells().map((cell) => (
                  <div key={cell.id} className="flex-1 p-3 truncate">
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </div>
                ))}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
```

### 4. 水平仮想化

```tsx
export function HorizontalVirtualList() {
  const parentRef = useRef<HTMLDivElement>(null);
  const items = Array.from({ length: 1000 }, (_, i) => `Column ${i}`);

  const virtualizer = useVirtualizer({
    horizontal: true, // 水平仮想化
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 200,
  });

  return (
    <div ref={parentRef} className="h-20 w-full overflow-auto border">
      <div
        style={{
          width: `${virtualizer.getTotalSize()}px`,
          height: "100%",
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
              height: "100%",
              width: `${virtualItem.size}px`,
              transform: `translateX(${virtualItem.start}px)`,
            }}
            className="flex items-center justify-center bg-blue-100 border-r"
          >
            {items[virtualItem.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

### 5. グリッド仮想化

```tsx
export function VirtualGrid() {
  const parentRef = useRef<HTMLDivElement>(null);

  const totalItems = 10000;
  const columns = 10;
  const rows = Math.ceil(totalItems / columns);

  const rowVirtualizer = useVirtualizer({
    count: rows,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 100,
  });

  const columnVirtualizer = useVirtualizer({
    horizontal: true,
    count: columns,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 100,
  });

  return (
    <div ref={parentRef} className="h-96 w-full overflow-auto border">
      <div
        style={{
          height: `${rowVirtualizer.getTotalSize()}px`,
          width: `${columnVirtualizer.getTotalSize()}px`,
          position: "relative",
        }}
      >
        {rowVirtualizer.getVirtualItems().map((virtualRow) => (
          <div key={virtualRow.key}>
            {columnVirtualizer.getVirtualItems().map((virtualColumn) => {
              const itemIndex =
                virtualRow.index * columns + virtualColumn.index;

              if (itemIndex >= totalItems) return null;

              return (
                <div
                  key={`${virtualRow.key}-${virtualColumn.key}`}
                  style={{
                    position: "absolute",
                    top: 0,
                    left: 0,
                    width: `${virtualColumn.size}px`,
                    height: `${virtualRow.size}px`,
                    transform: `translateX(${virtualColumn.start}px) translateY(${virtualRow.start}px)`,
                  }}
                  className="border border-gray-200 flex items-center justify-center bg-white hover:bg-gray-50"
                >
                  Item {itemIndex}
                </div>
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
}
```

### 6. 無限スクロールとの統合

```tsx
import { useInfiniteQuery } from "@tanstack/react-query";

export function InfiniteVirtualList() {
  const parentRef = useRef<HTMLDivElement>(null);

  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } =
    useInfiniteQuery({
      queryKey: ["posts"],
      queryFn: ({ pageParam = 0 }) => fetchPosts(pageParam),
      getNextPageParam: (lastPage, pages) =>
        lastPage.hasMore ? pages.length : undefined,
      initialPageParam: 0,
    });

  const allItems = data?.pages.flatMap((page) => page.posts) ?? [];

  const virtualizer = useVirtualizer({
    count: hasNextPage ? allItems.length + 1 : allItems.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 80,
  });

  const items = virtualizer.getVirtualItems();

  useEffect(() => {
    const [lastItem] = [...items].reverse();

    if (!lastItem) return;

    if (
      lastItem.index >= allItems.length - 1 &&
      hasNextPage &&
      !isFetchingNextPage
    ) {
      fetchNextPage();
    }
  }, [hasNextPage, fetchNextPage, allItems.length, isFetchingNextPage, items]);

  return (
    <div ref={parentRef} className="h-96 overflow-auto border">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: "relative",
        }}
      >
        {items.map((virtualItem) => {
          const isLoaderRow = virtualItem.index > allItems.length - 1;
          const post = allItems[virtualItem.index];

          return (
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
              {isLoaderRow ? (
                hasNextPage ? (
                  <div className="flex items-center justify-center h-full">
                    Loading more...
                  </div>
                ) : (
                  <div className="flex items-center justify-center h-full">
                    Nothing more to load
                  </div>
                )
              ) : (
                <PostItem post={post} />
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

### 7. パフォーマンス最適化

```tsx
// メモ化された仮想リスト
export const OptimizedVirtualList = memo(function OptimizedVirtualList({
  items,
  itemHeight = 50,
}: {
  items: any[];
  itemHeight?: number;
}) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: useCallback(() => itemHeight, [itemHeight]),
    // パフォーマンス設定
    overscan: 5, // 可視範囲外にレンダリングするアイテム数
    scrollMargin: parentRef.current?.offsetTop ?? 0,
  });

  return (
    <div ref={parentRef} className="h-96 overflow-auto">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: "relative",
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <VirtualItem
            key={virtualItem.key}
            virtualItem={virtualItem}
            item={items[virtualItem.index]}
          />
        ))}
      </div>
    </div>
  );
});

// メモ化されたアイテムコンポーネント
const VirtualItem = memo(function VirtualItem({
  virtualItem,
  item,
}: {
  virtualItem: any;
  item: any;
}) {
  return (
    <div
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        width: "100%",
        height: `${virtualItem.size}px`,
        transform: `translateY(${virtualItem.start}px)`,
      }}
      className="flex items-center px-4 border-b"
    >
      {item.name}
    </div>
  );
});
```

### 8. スティッキーヘッダー付きリスト

```tsx
export function StickyHeaderVirtualList({ groups }: { groups: any[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  // グループとアイテムを平坦化
  const items = useMemo(() => {
    const result: any[] = [];
    groups.forEach((group) => {
      result.push({ type: "header", data: group });
      result.push(
        ...group.items.map((item: any) => ({ type: "item", data: item }))
      );
    });
    return result;
  }, [groups]);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: (index) => {
      return items[index].type === "header" ? 40 : 60;
    },
  });

  return (
    <div ref={parentRef} className="h-96 overflow-auto border">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          position: "relative",
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => {
          const item = items[virtualItem.index];

          return (
            <div
              key={virtualItem.key}
              style={{
                position: "absolute",
                top: 0,
                left: 0,
                width: "100%",
                height: `${virtualItem.size}px`,
                transform: `translateY(${virtualItem.start}px)`,
                zIndex: item.type === "header" ? 1 : 0,
              }}
              className={
                item.type === "header"
                  ? "bg-gray-200 font-bold px-4 flex items-center sticky top-0"
                  : "bg-white px-4 flex items-center border-b"
              }
            >
              {item.type === "header" ? item.data.name : item.data.title}
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

## 主要機能

- **効率的レンダリング**: 可視範囲のみレンダリング
- **動的サイズ**: アイテムサイズの動的測定
- **水平・垂直対応**: 両方向の仮想化
- **グリッド仮想化**: 2D 仮想化対応
- **無限スクロール**: TanStack Query との統合
- **スムーズスクロール**: 最適化されたスクロール体験

## メリット・デメリット

**メリット**: 高性能、大量データ対応、メモリ効率、柔軟性  
**デメリット**: 複雑性、動的コンテンツの制約、SEO の考慮が必要
