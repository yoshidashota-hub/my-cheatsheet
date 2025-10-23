# Tailwind CSS ガイド

Tailwind CSSは、ユーティリティファーストのCSSフレームワークです。

## 特徴

- **ユーティリティファースト**: 小さなクラスを組み合わせてスタイリング
- **高いカスタマイズ性**: 設定ファイルで自由にカスタマイズ
- **レスポンシブ対応**: モバイルファーストなブレークポイント
- **ダークモード対応**: クラスベースまたはメディアクエリ
- **小さいバンドルサイズ**: 使用したクラスのみを出力

## インストール

### Next.js プロジェクト

```bash
npx create-next-app@latest my-app
# Tailwind CSS を選択
```

### 既存プロジェクトに追加

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

### 設定ファイル

```javascript
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

```css
/* globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

## 基本的な使い方

### レイアウト

```html
<!-- Flexbox -->
<div class="flex items-center justify-between">
  <div>Left</div>
  <div>Right</div>
</div>

<!-- Grid -->
<div class="grid grid-cols-3 gap-4">
  <div>1</div>
  <div>2</div>
  <div>3</div>
</div>

<!-- センター配置 -->
<div class="flex items-center justify-center h-screen">
  <div>Centered</div>
</div>
```

### スペーシング

```html
<!-- Margin -->
<div class="m-4">margin: 1rem</div>
<div class="mx-4">margin-left/right: 1rem</div>
<div class="my-4">margin-top/bottom: 1rem</div>
<div class="mt-4">margin-top: 1rem</div>
<div class="mr-4">margin-right: 1rem</div>
<div class="mb-4">margin-bottom: 1rem</div>
<div class="ml-4">margin-left: 1rem</div>

<!-- Padding -->
<div class="p-4">padding: 1rem</div>
<div class="px-4">padding-left/right: 1rem</div>
<div class="py-4">padding-top/bottom: 1rem</div>

<!-- Space between -->
<div class="flex space-x-4">
  <div>1</div>
  <div>2</div>
  <div>3</div>
</div>
```

スペーシングスケール:
- `0` = 0px
- `1` = 0.25rem (4px)
- `2` = 0.5rem (8px)
- `3` = 0.75rem (12px)
- `4` = 1rem (16px)
- `5` = 1.25rem (20px)
- `6` = 1.5rem (24px)
- `8` = 2rem (32px)
- `10` = 2.5rem (40px)
- `12` = 3rem (48px)
- `16` = 4rem (64px)

### サイズ

```html
<!-- Width -->
<div class="w-full">width: 100%</div>
<div class="w-1/2">width: 50%</div>
<div class="w-64">width: 16rem</div>
<div class="w-screen">width: 100vw</div>

<!-- Height -->
<div class="h-full">height: 100%</div>
<div class="h-screen">height: 100vh</div>
<div class="h-64">height: 16rem</div>

<!-- Min/Max -->
<div class="min-w-0">min-width: 0</div>
<div class="max-w-sm">max-width: 24rem</div>
<div class="max-w-lg">max-width: 32rem</div>
<div class="max-w-xl">max-width: 36rem</div>
<div class="max-w-2xl">max-width: 42rem</div>
```

### タイポグラフィ

```html
<!-- Font Size -->
<p class="text-xs">extra small</p>
<p class="text-sm">small</p>
<p class="text-base">base</p>
<p class="text-lg">large</p>
<p class="text-xl">extra large</p>
<p class="text-2xl">2xl</p>
<p class="text-3xl">3xl</p>

<!-- Font Weight -->
<p class="font-thin">Thin</p>
<p class="font-light">Light</p>
<p class="font-normal">Normal</p>
<p class="font-medium">Medium</p>
<p class="font-semibold">Semibold</p>
<p class="font-bold">Bold</p>
<p class="font-extrabold">Extra Bold</p>

<!-- Text Align -->
<p class="text-left">Left</p>
<p class="text-center">Center</p>
<p class="text-right">Right</p>
<p class="text-justify">Justify</p>

<!-- Text Color -->
<p class="text-gray-900">Dark Gray</p>
<p class="text-blue-500">Blue</p>
<p class="text-red-600">Red</p>

<!-- Line Height -->
<p class="leading-none">line-height: 1</p>
<p class="leading-tight">line-height: 1.25</p>
<p class="leading-normal">line-height: 1.5</p>
<p class="leading-relaxed">line-height: 1.625</p>
```

### カラー

```html
<!-- Background -->
<div class="bg-white">White</div>
<div class="bg-gray-100">Light Gray</div>
<div class="bg-blue-500">Blue</div>
<div class="bg-gradient-to-r from-blue-500 to-purple-500">Gradient</div>

<!-- Text -->
<p class="text-gray-900">Dark Text</p>
<p class="text-blue-600">Blue Text</p>

<!-- Border -->
<div class="border border-gray-300">Border</div>
<div class="border-2 border-blue-500">Thick Blue Border</div>
```

カラースケール: 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950

### ボーダーと角丸

```html
<!-- Border Radius -->
<div class="rounded">border-radius: 0.25rem</div>
<div class="rounded-md">border-radius: 0.375rem</div>
<div class="rounded-lg">border-radius: 0.5rem</div>
<div class="rounded-xl">border-radius: 0.75rem</div>
<div class="rounded-2xl">border-radius: 1rem</div>
<div class="rounded-full">border-radius: 9999px</div>

<!-- Border Width -->
<div class="border">1px</div>
<div class="border-2">2px</div>
<div class="border-4">4px</div>
<div class="border-t">top only</div>
<div class="border-r">right only</div>

<!-- Border Color -->
<div class="border border-gray-300">Gray Border</div>
<div class="border-2 border-blue-500">Blue Border</div>
```

### シャドウ

```html
<div class="shadow-sm">Small Shadow</div>
<div class="shadow">Default Shadow</div>
<div class="shadow-md">Medium Shadow</div>
<div class="shadow-lg">Large Shadow</div>
<div class="shadow-xl">Extra Large Shadow</div>
<div class="shadow-2xl">2XL Shadow</div>
<div class="shadow-none">No Shadow</div>
```

### 透明度

```html
<div class="opacity-0">opacity: 0</div>
<div class="opacity-25">opacity: 0.25</div>
<div class="opacity-50">opacity: 0.5</div>
<div class="opacity-75">opacity: 0.75</div>
<div class="opacity-100">opacity: 1</div>

<!-- Background Opacity -->
<div class="bg-blue-500 bg-opacity-50">Semi-transparent</div>
```

## レスポンシブデザイン

### ブレークポイント

- `sm`: 640px以上
- `md`: 768px以上
- `lg`: 1024px以上
- `xl`: 1280px以上
- `2xl`: 1536px以上

```html
<!-- モバイルファースト -->
<div class="text-sm md:text-base lg:text-lg">
  Responsive Text
</div>

<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
  <div>1</div>
  <div>2</div>
  <div>3</div>
</div>

<!-- 非表示/表示 -->
<div class="hidden md:block">Desktop Only</div>
<div class="block md:hidden">Mobile Only</div>
```

## ホバー・フォーカス・その他の状態

```html
<!-- Hover -->
<button class="bg-blue-500 hover:bg-blue-600">
  Hover Me
</button>

<!-- Focus -->
<input class="border focus:border-blue-500 focus:ring focus:ring-blue-200" />

<!-- Active -->
<button class="bg-blue-500 active:bg-blue-700">
  Click Me
</button>

<!-- Disabled -->
<button class="disabled:opacity-50 disabled:cursor-not-allowed" disabled>
  Disabled
</button>

<!-- Group Hover -->
<div class="group">
  <p class="group-hover:text-blue-500">Hover parent</p>
</div>

<!-- Peer -->
<input class="peer" type="checkbox" />
<label class="peer-checked:text-blue-500">Checkbox Label</label>
```

## ダークモード

### 設定

```javascript
// tailwind.config.js
module.exports = {
  darkMode: 'class', // または 'media'
  // ...
}
```

### 使用例

```html
<div class="bg-white dark:bg-gray-900">
  <p class="text-gray-900 dark:text-white">
    Light/Dark Text
  </p>
</div>
```

### Next.js でのダークモード実装

```bash
npm install next-themes
```

```typescript
// app/providers.tsx
'use client'

import { ThemeProvider } from 'next-themes'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
      {children}
    </ThemeProvider>
  )
}

// app/layout.tsx
import { Providers } from './providers'

export default function RootLayout({ children }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}

// components/ThemeToggle.tsx
'use client'

import { useTheme } from 'next-themes'

export function ThemeToggle() {
  const { theme, setTheme } = useTheme()

  return (
    <button
      onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
      className="px-4 py-2 rounded bg-gray-200 dark:bg-gray-800"
    >
      Toggle Theme
    </button>
  )
}
```

## カスタマイズ

### カラーの追加

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          500: '#0ea5e9',
          900: '#0c4a6e',
        },
        brand: '#FF6B6B',
      },
    },
  },
}
```

```html
<div class="bg-primary-500">Primary Color</div>
<div class="text-brand">Brand Color</div>
```

### スペーシングの追加

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      spacing: {
        128: '32rem',
        144: '36rem',
      },
    },
  },
}
```

```html
<div class="w-128">Custom Width</div>
```

### フォントの追加

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        mono: ['Fira Code', 'monospace'],
      },
    },
  },
}
```

```html
<p class="font-sans">Sans Serif</p>
<code class="font-mono">Monospace</code>
```

### カスタムブレークポイント

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    screens: {
      xs: '475px',
      sm: '640px',
      md: '768px',
      lg: '1024px',
      xl: '1280px',
      '2xl': '1536px',
      '3xl': '1920px',
    },
  },
}
```

## カスタムユーティリティ

### @layer を使用

```css
/* globals.css */
@layer utilities {
  .text-shadow {
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
  }

  .scrollbar-hide {
    -ms-overflow-style: none;
    scrollbar-width: none;
  }

  .scrollbar-hide::-webkit-scrollbar {
    display: none;
  }
}
```

```html
<p class="text-shadow">Text with shadow</p>
<div class="scrollbar-hide">Hidden scrollbar</div>
```

### カスタムコンポーネント

```css
@layer components {
  .btn {
    @apply px-4 py-2 rounded font-semibold transition-colors;
  }

  .btn-primary {
    @apply bg-blue-500 text-white hover:bg-blue-600;
  }

  .btn-secondary {
    @apply bg-gray-200 text-gray-900 hover:bg-gray-300;
  }
}
```

```html
<button class="btn btn-primary">Primary Button</button>
<button class="btn btn-secondary">Secondary Button</button>
```

## プラグイン

### 公式プラグイン

```bash
npm install -D @tailwindcss/forms
npm install -D @tailwindcss/typography
npm install -D @tailwindcss/aspect-ratio
npm install -D @tailwindcss/container-queries
```

```javascript
// tailwind.config.js
module.exports = {
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/container-queries'),
  ],
}
```

### @tailwindcss/forms

```html
<!-- スタイルが自動的に適用される -->
<input type="text" class="rounded-md" />
<select class="rounded-md">
  <option>Option 1</option>
</select>
<textarea class="rounded-md"></textarea>
```

### @tailwindcss/typography

```html
<article class="prose lg:prose-xl">
  <h1>Title</h1>
  <p>Content with automatic typography styles.</p>
</article>

<article class="prose dark:prose-invert">
  <h1>Dark Mode Typography</h1>
</article>
```

## 実践例

### カード

```html
<div class="max-w-sm rounded-lg overflow-hidden shadow-lg bg-white">
  <img class="w-full" src="image.jpg" alt="Image" />
  <div class="px-6 py-4">
    <div class="font-bold text-xl mb-2">Card Title</div>
    <p class="text-gray-700 text-base">
      Card description goes here.
    </p>
  </div>
  <div class="px-6 pt-4 pb-2">
    <span class="inline-block bg-gray-200 rounded-full px-3 py-1 text-sm font-semibold text-gray-700 mr-2 mb-2">
      #tag1
    </span>
    <span class="inline-block bg-gray-200 rounded-full px-3 py-1 text-sm font-semibold text-gray-700 mr-2 mb-2">
      #tag2
    </span>
  </div>
</div>
```

### ナビゲーションバー

```html
<nav class="bg-white shadow-lg">
  <div class="max-w-6xl mx-auto px-4">
    <div class="flex justify-between items-center h-16">
      <div class="flex items-center">
        <a href="/" class="font-bold text-xl text-gray-800">Logo</a>
      </div>
      <div class="hidden md:flex space-x-8">
        <a href="/" class="text-gray-800 hover:text-blue-500">Home</a>
        <a href="/about" class="text-gray-800 hover:text-blue-500">About</a>
        <a href="/contact" class="text-gray-800 hover:text-blue-500">Contact</a>
      </div>
      <div class="md:hidden">
        <button class="text-gray-800">Menu</button>
      </div>
    </div>
  </div>
</nav>
```

### フォーム

```html
<form class="max-w-md mx-auto bg-white p-8 rounded-lg shadow-md">
  <div class="mb-4">
    <label class="block text-gray-700 text-sm font-bold mb-2" for="email">
      Email
    </label>
    <input
      class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:ring-2 focus:ring-blue-500"
      id="email"
      type="email"
      placeholder="Email"
    />
  </div>
  <div class="mb-6">
    <label class="block text-gray-700 text-sm font-bold mb-2" for="password">
      Password
    </label>
    <input
      class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 mb-3 leading-tight focus:outline-none focus:ring-2 focus:ring-blue-500"
      id="password"
      type="password"
      placeholder="******************"
    />
  </div>
  <div class="flex items-center justify-between">
    <button
      class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline"
      type="button"
    >
      Sign In
    </button>
    <a
      class="inline-block align-baseline font-bold text-sm text-blue-500 hover:text-blue-800"
      href="#"
    >
      Forgot Password?
    </a>
  </div>
</form>
```

### グリッドレイアウト

```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 p-6">
  <div class="bg-white rounded-lg shadow-md p-6">
    <h3 class="text-xl font-bold mb-2">Item 1</h3>
    <p class="text-gray-600">Description</p>
  </div>
  <div class="bg-white rounded-lg shadow-md p-6">
    <h3 class="text-xl font-bold mb-2">Item 2</h3>
    <p class="text-gray-600">Description</p>
  </div>
  <div class="bg-white rounded-lg shadow-md p-6">
    <h3 class="text-xl font-bold mb-2">Item 3</h3>
    <p class="text-gray-600">Description</p>
  </div>
</div>
```

### モーダル

```html
<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
  <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
    <div class="p-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-2xl font-bold">Modal Title</h2>
        <button class="text-gray-500 hover:text-gray-700">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <p class="text-gray-600 mb-6">
        Modal content goes here.
      </p>
      <div class="flex justify-end space-x-4">
        <button class="px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300">
          Cancel
        </button>
        <button class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
          Confirm
        </button>
      </div>
    </div>
  </div>
</div>
```

## パフォーマンス最適化

### PurgeCSS（自動）

Tailwind v3以降は自動的に未使用のクラスを削除します。

```javascript
// tailwind.config.js
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  // ...
}
```

### JITモード（デフォルト）

Tailwind v3以降はJIT（Just-In-Time）モードがデフォルト。

- 任意の値を使用可能: `w-[137px]`
- ビルド時間が短縮
- 開発時のファイルサイズが小さい

```html
<!-- 任意の値 -->
<div class="w-[137px]">Custom Width</div>
<div class="top-[117px]">Custom Top</div>
<div class="bg-[#1da1f2]">Custom Color</div>
```

## ベストプラクティス

1. **コンポーネント化**: 繰り返し使うスタイルはコンポーネントに
2. **@apply は慎重に**: できるだけHTMLでクラスを使用
3. **カスタムクラス名は避ける**: Tailwindのユーティリティを優先
4. **レスポンシブデザイン**: モバイルファーストで設計
5. **ダークモード対応**: 最初から考慮に入れる
6. **一貫性**: デザインシステムを設定ファイルで定義

## VSCode拡張機能

- **Tailwind CSS IntelliSense**: クラス名の補完
- **Headwind**: クラス名の自動ソート
- **Tailwind Docs**: ドキュメントをすぐに参照

## 参考リンク

- [Tailwind CSS 公式ドキュメント](https://tailwindcss.com/docs)
- [Tailwind UI](https://tailwindui.com/) - 公式コンポーネント集
- [Heroicons](https://heroicons.com/) - Tailwind製作チームのアイコン
- [Tailwind Play](https://play.tailwindcss.com/) - オンラインプレイグラウンド
