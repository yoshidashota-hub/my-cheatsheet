# フロントエンドパフォーマンス最適化ガイド

## 目次
1. [パフォーマンス最適化とは](#パフォーマンス最適化とは)
2. [Core Web Vitals](#core-web-vitals)
3. [コード分割](#コード分割)
4. [画像最適化](#画像最適化)
5. [レンダリング最適化](#レンダリング最適化)
6. [バンドルサイズ削減](#バンドルサイズ削減)
7. [キャッシング戦略](#キャッシング戦略)
8. [ベストプラクティス](#ベストプラクティス)

---

## パフォーマンス最適化とは

Webアプリケーションの読み込み速度とユーザー体験を向上させる技術です。

### 主な指標

- **LCP**: Largest Contentful Paint（最大コンテンツの描画時間）
- **FID**: First Input Delay（初回入力遅延）
- **CLS**: Cumulative Layout Shift（累積レイアウトシフト）
- **TTFB**: Time to First Byte（最初のバイトまでの時間）

---

## Core Web Vitals

### LCP改善

```typescript
// Next.js Image最適化
import Image from 'next/image';

export function Hero() {
  return (
    <Image
      src="/hero.jpg"
      alt="Hero"
      width={1200}
      height={600}
      priority // LCP要素に使用
      placeholder="blur"
    />
  );
}

// プリロード
<link rel="preload" as="image" href="/hero.jpg" />
```

### CLS改善

```css
/* 画像サイズを事前指定 */
img {
  aspect-ratio: 16 / 9;
  width: 100%;
  height: auto;
}

/* フォント読み込み中のレイアウトシフト防止 */
@font-face {
  font-family: 'MyFont';
  src: url('/fonts/myfont.woff2') format('woff2');
  font-display: swap;
}
```

---

## コード分割

### React Lazy Loading

```typescript
import { lazy, Suspense } from 'react';

// コンポーネントの遅延読み込み
const HeavyComponent = lazy(() => import('./HeavyComponent'));

export function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <HeavyComponent />
    </Suspense>
  );
}
```

### Next.js Dynamic Import

```typescript
import dynamic from 'next/dynamic';

const DynamicComponent = dynamic(() => import('./HeavyComponent'), {
  loading: () => <p>Loading...</p>,
  ssr: false, // クライアントサイドのみ
});

export function Page() {
  return <DynamicComponent />;
}
```

### Route-based Code Splitting

```typescript
// React Router
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

const Home = lazy(() => import('./pages/Home'));
const About = lazy(() => import('./pages/About'));
const Contact = lazy(() => import('./pages/Contact'));

export function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
        <Route path="/contact" element={<Contact />} />
      </Routes>
    </Suspense>
  );
}
```

---

## 画像最適化

### Next.js Image

```typescript
import Image from 'next/image';

export function Gallery() {
  return (
    <div>
      <Image
        src="/photo.jpg"
        alt="Photo"
        width={800}
        height={600}
        quality={75} // 75%品質
        placeholder="blur"
        blurDataURL="data:image/jpeg;base64,..."
      />
    </div>
  );
}
```

### WebP/AVIF対応

```html
<picture>
  <source srcset="/image.avif" type="image/avif" />
  <source srcset="/image.webp" type="image/webp" />
  <img src="/image.jpg" alt="Fallback" />
</picture>
```

### Lazy Loading

```typescript
export function LazyImage({ src, alt }: { src: string; alt: string }) {
  return <img src={src} alt={alt} loading="lazy" />;
}
```

---

## レンダリング最適化

### React Memo

```typescript
import { memo } from 'react';

const ExpensiveComponent = memo(function ExpensiveComponent({ data }: { data: any }) {
  // 重い処理
  return <div>{data}</div>;
});
```

### useMemo / useCallback

```typescript
import { useMemo, useCallback } from 'react';

export function DataTable({ items }: { items: any[] }) {
  // 計算結果をメモ化
  const sortedItems = useMemo(() => {
    return items.sort((a, b) => a.name.localeCompare(b.name));
  }, [items]);

  // コールバックをメモ化
  const handleClick = useCallback((id: string) => {
    console.log('Clicked:', id);
  }, []);

  return (
    <div>
      {sortedItems.map((item) => (
        <div key={item.id} onClick={() => handleClick(item.id)}>
          {item.name}
        </div>
      ))}
    </div>
  );
}
```

### Virtualization

```typescript
import { FixedSizeList } from 'react-window';

export function VirtualList({ items }: { items: any[] }) {
  return (
    <FixedSizeList
      height={600}
      itemCount={items.length}
      itemSize={50}
      width="100%"
    >
      {({ index, style }) => (
        <div style={style}>{items[index].name}</div>
      )}
    </FixedSizeList>
  );
}
```

---

## バンドルサイズ削減

### Tree Shaking

```typescript
// 悪い例: 全体インポート
import _ from 'lodash';

// 良い例: 必要な関数のみ
import debounce from 'lodash/debounce';
```

### Bundle Analyzer

```bash
# Next.js
npm install @next/bundle-analyzer

# Vite
npm install rollup-plugin-visualizer
```

```typescript
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

module.exports = withBundleAnalyzer({
  // config
});
```

---

## キャッシング戦略

### Service Worker

```typescript
// service-worker.ts
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open('v1').then((cache) => {
      return cache.addAll([
        '/',
        '/styles.css',
        '/script.js',
      ]);
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request);
    })
  );
});
```

---

## ベストプラクティス

### 1. Prefetching

```typescript
// Next.js Link prefetch
import Link from 'next/link';

export function Navigation() {
  return (
    <Link href="/about" prefetch={true}>
      About
    </Link>
  );
}

// DNS Prefetch
<link rel="dns-prefetch" href="https://api.example.com" />
```

### 2. Critical CSS

```html
<!-- Critical CSS をインライン化 -->
<style>
  /* 初期表示に必要な最小限のCSS */
  .header { display: flex; }
</style>

<!-- 残りのCSSは遅延読み込み -->
<link rel="preload" href="/styles.css" as="style" onload="this.onload=null;this.rel='stylesheet'" />
```

### 3. Resource Hints

```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="dns-prefetch" href="https://cdn.example.com" />
<link rel="preload" href="/critical.css" as="style" />
<link rel="prefetch" href="/next-page.js" />
```

---

## 参考リンク

- [Web.dev Performance](https://web.dev/performance/)
- [Core Web Vitals](https://web.dev/vitals/)
- [Next.js Performance](https://nextjs.org/docs/advanced-features/measuring-performance)
