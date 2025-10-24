# Vite ビルドツール完全ガイド

## 目次
- [Viteとは](#viteとは)
- [セットアップ](#セットアップ)
- [設定](#設定)
- [プラグイン](#プラグイン)
- [ビルド最適化](#ビルド最適化)
- [環境変数](#環境変数)
- [開発サーバー](#開発サーバー)
- [本番ビルド](#本番ビルド)

---

## Viteとは

次世代フロントエンドビルドツール。開発時は高速なHMR、本番時は最適化されたビルドを提供。

### 主な特徴
- ⚡ 超高速な開発サーバー起動
- 🔥 高速なHMR（Hot Module Replacement）
- 📦 最適化された本番ビルド（Rollup使用）
- 🔌 豊富なプラグインエコシステム
- 📁 TypeScript、JSX、CSS などを標準サポート

### WebpackとViteの違い

| 特徴 | Webpack | Vite |
|------|---------|------|
| 開発サーバー起動 | 遅い（全バンドル） | 超高速（ESM利用） |
| HMR | 遅くなりがち | 常に高速 |
| 設定 | 複雑 | シンプル |
| ビルド | Webpack | Rollup |

---

## セットアップ

### 新規プロジェクト作成

```bash
# npm
npm create vite@latest

# yarn
yarn create vite

# pnpm
pnpm create vite

# プロジェクト名とテンプレートを指定
npm create vite@latest my-app -- --template react
npm create vite@latest my-app -- --template react-ts
npm create vite@latest my-app -- --template vue
npm create vite@latest my-app -- --template vue-ts
npm create vite@latest my-app -- --template svelte
npm create vite@latest my-app -- --template svelte-ts
npm create vite@latest my-app -- --template vanilla
npm create vite@latest my-app -- --template vanilla-ts
```

### 利用可能なテンプレート
- `vanilla` / `vanilla-ts` - Vanilla JavaScript
- `react` / `react-ts` - React
- `react-swc` / `react-swc-ts` - React + SWC
- `vue` / `vue-ts` - Vue 3
- `preact` / `preact-ts` - Preact
- `lit` / `lit-ts` - Lit
- `svelte` / `svelte-ts` - Svelte
- `solid` / `solid-ts` - Solid

### 既存プロジェクトに追加

```bash
npm install -D vite
```

```json
// package.json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  }
}
```

---

## 設定

### vite.config.js の基本

```javascript
// vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    open: true
  },
  build: {
    outDir: 'dist',
    sourcemap: true
  }
})
```

### TypeScript設定

```typescript
// vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@components': path.resolve(__dirname, './src/components'),
      '@utils': path.resolve(__dirname, './src/utils')
    }
  }
})
```

### 環境別設定

```javascript
// vite.config.js
import { defineConfig } from 'vite'

export default defineConfig(({ command, mode }) => {
  if (command === 'serve') {
    // 開発サーバー設定
    return {
      server: {
        port: 3000
      }
    }
  } else {
    // ビルド設定
    return {
      build: {
        minify: 'terser'
      }
    }
  }
})
```

---

## プラグイン

### React

```bash
npm install -D @vitejs/plugin-react
```

```javascript
// vite.config.js
import react from '@vitejs/plugin-react'

export default {
  plugins: [react()]
}
```

#### React with SWC（高速）

```bash
npm install -D @vitejs/plugin-react-swc
```

```javascript
import react from '@vitejs/plugin-react-swc'

export default {
  plugins: [react()]
}
```

### Vue

```bash
npm install -D @vitejs/plugin-vue
```

```javascript
import vue from '@vitejs/plugin-vue'

export default {
  plugins: [vue()]
}
```

### Svelte

```bash
npm install -D @sveltejs/vite-plugin-svelte
```

```javascript
import { svelte } from '@sveltejs/vite-plugin-svelte'

export default {
  plugins: [svelte()]
}
```

### よく使うプラグイン

#### 1. vite-plugin-checker（型チェック）

```bash
npm install -D vite-plugin-checker
```

```javascript
import checker from 'vite-plugin-checker'

export default {
  plugins: [
    checker({
      typescript: true,
      eslint: {
        lintCommand: 'eslint "./src/**/*.{ts,tsx}"'
      }
    })
  ]
}
```

#### 2. vite-plugin-pwa（PWA対応）

```bash
npm install -D vite-plugin-pwa
```

```javascript
import { VitePWA } from 'vite-plugin-pwa'

export default {
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      manifest: {
        name: 'My App',
        short_name: 'App',
        theme_color: '#ffffff'
      }
    })
  ]
}
```

#### 3. vite-plugin-svg-icons（SVGスプライト）

```bash
npm install -D vite-plugin-svg-icons
```

```javascript
import { createSvgIconsPlugin } from 'vite-plugin-svg-icons'
import path from 'path'

export default {
  plugins: [
    createSvgIconsPlugin({
      iconDirs: [path.resolve(process.cwd(), 'src/icons')],
      symbolId: 'icon-[dir]-[name]'
    })
  ]
}
```

#### 4. vite-plugin-compression（Gzip圧縮）

```bash
npm install -D vite-plugin-compression
```

```javascript
import viteCompression from 'vite-plugin-compression'

export default {
  plugins: [
    viteCompression({
      algorithm: 'gzip',
      ext: '.gz'
    })
  ]
}
```

---

## ビルド最適化

### コード分割

```javascript
export default {
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // ライブラリを分離
          'react-vendor': ['react', 'react-dom'],
          'ui-vendor': ['@mui/material', '@emotion/react']
        }
      }
    }
  }
}
```

### チャンク分割（自動）

```javascript
export default {
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) {
            return 'vendor'
          }
        }
      }
    }
  }
}
```

### ファイルサイズ制限

```javascript
export default {
  build: {
    chunkSizeWarningLimit: 1000, // KB
    rollupOptions: {
      output: {
        chunkFileNames: 'js/[name]-[hash].js',
        entryFileNames: 'js/[name]-[hash].js',
        assetFileNames: '[ext]/[name]-[hash].[ext]'
      }
    }
  }
}
```

### Tree Shaking

```javascript
// 自動的に有効（設定不要）
// 未使用のコードは自動削除される

// package.json で sideEffects を指定
{
  "sideEffects": false
}

// または特定ファイルのみ
{
  "sideEffects": ["*.css", "*.scss"]
}
```

### Minify設定

```javascript
export default {
  build: {
    minify: 'terser', // 'terser' | 'esbuild'
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    }
  }
}
```

---

## 環境変数

### .env ファイル

```bash
# .env（全環境）
VITE_API_URL=https://api.example.com

# .env.local（ローカル環境、Git除外）
VITE_API_KEY=secret

# .env.development（開発環境）
VITE_API_URL=http://localhost:3000

# .env.production（本番環境）
VITE_API_URL=https://api.production.com
```

### 使用方法

```typescript
// import.meta.env で参照
const apiUrl = import.meta.env.VITE_API_URL
const mode = import.meta.env.MODE // 'development' | 'production'
const isDev = import.meta.env.DEV // boolean
const isProd = import.meta.env.PROD // boolean

// 型定義
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string
  readonly VITE_API_KEY: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
```

### 重要な注意点

```javascript
// ✗ VITE_ プレフィックスなしは使えない
const secret = import.meta.env.API_KEY // undefined

// ○ VITE_ プレフィックス付き
const apiKey = import.meta.env.VITE_API_KEY // OK

// クライアントに公開されるため、機密情報は含めない
```

---

## 開発サーバー

### 基本設定

```javascript
export default {
  server: {
    port: 3000,
    host: true, // 0.0.0.0でリッスン
    open: true, // ブラウザ自動起動
    cors: true,

    // プロキシ設定
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
  }
}
```

### HTTPS設定

```javascript
import fs from 'fs'

export default {
  server: {
    https: {
      key: fs.readFileSync('path/to/key.pem'),
      cert: fs.readFileSync('path/to/cert.pem')
    }
  }
}
```

### HMR設定

```javascript
export default {
  server: {
    hmr: {
      overlay: true, // エラーオーバーレイ表示
      port: 24678
    }
  }
}
```

---

## 本番ビルド

### 基本ビルド

```bash
# ビルド実行
npm run build

# プレビュー（ビルド結果を確認）
npm run preview
```

### ビルド設定

```javascript
export default {
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: true,

    // インライン化の閾値（4KB未満はBase64化）
    assetsInlineLimit: 4096,

    // CSS コード分割
    cssCodeSplit: true,

    // 静的アセットのコピー
    copyPublicDir: true
  }
}
```

### Base URL設定

```javascript
export default {
  base: '/my-app/', // サブディレクトリにデプロイする場合
}
```

### ビルドターゲット

```javascript
export default {
  build: {
    target: 'es2015', // または 'esnext', 'modules'

    // 複数ターゲット
    target: ['es2020', 'edge88', 'firefox78', 'chrome87', 'safari14']
  }
}
```

---

## CSS処理

### CSS Modules

```css
/* Button.module.css */
.button {
  background: blue;
  color: white;
}
```

```jsx
import styles from './Button.module.css'

function Button() {
  return <button className={styles.button}>Click</button>
}
```

### PostCSS

```bash
npm install -D postcss autoprefixer
```

```javascript
// postcss.config.js
export default {
  plugins: {
    autoprefixer: {}
  }
}
```

### Sass/SCSS

```bash
npm install -D sass
```

```javascript
// 自動的にサポート（設定不要）
import './styles.scss'
```

### Tailwind CSS

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

```javascript
// tailwind.config.js
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {}
  },
  plugins: []
}
```

```css
/* index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

---

## 静的アセット処理

### public ディレクトリ

```
public/
├── favicon.ico
├── robots.txt
└── images/
    └── logo.png
```

```html
<!-- そのまま参照 -->
<img src="/images/logo.png" alt="Logo" />
```

### src 内のアセット

```javascript
// import して使用
import logo from './assets/logo.png'

function App() {
  return <img src={logo} alt="Logo" />
}

// または URL として
import logoUrl from './assets/logo.png?url'
```

### アセットのインライン化

```javascript
// ?inline で強制的にインライン化
import logo from './assets/logo.png?inline'
```

---

## TypeScript サポート

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

### tsconfig.node.json

```json
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
```

---

## パフォーマンス最適化

### 依存関係の事前バンドル

```javascript
export default {
  optimizeDeps: {
    include: ['react', 'react-dom'],
    exclude: ['your-local-package']
  }
}
```

### Dynamic Import

```javascript
// コード分割
const Component = lazy(() => import('./Component'))

// ルートベースの分割
const routes = [
  {
    path: '/about',
    component: lazy(() => import('./pages/About'))
  }
]
```

### プリロード

```html
<!-- index.html -->
<link rel="modulepreload" href="/src/main.tsx" />
```

---

## デバッグ

### ソースマップ

```javascript
export default {
  build: {
    sourcemap: true, // 'inline' | 'hidden' | true
  }
}
```

### ログレベル

```bash
# コマンドラインで指定
vite --debug
vite --debug hmr

# 設定ファイルで指定
export default {
  logLevel: 'info' // 'info' | 'warn' | 'error' | 'silent'
}
```

---

## ベストプラクティス

### 1. 適切なコード分割

```javascript
// ルートベースの分割
const routes = [
  {
    path: '/',
    component: () => import('./pages/Home')
  },
  {
    path: '/about',
    component: () => import('./pages/About')
  }
]

// ライブラリの分離
export default {
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          ui: ['@mui/material']
        }
      }
    }
  }
}
```

### 2. 環境変数の管理

```bash
# 機密情報は .env.local に（Git除外）
VITE_API_KEY=secret

# 共通設定は .env に
VITE_APP_NAME=My App
```

### 3. プラグインの最小化

```javascript
// 必要なプラグインのみ使用
export default {
  plugins: [
    react(),
    // checker({ typescript: true }) // 開発時のみ
  ]
}
```

---

## トラブルシューティング

### ポートが使用中

```bash
# ポート変更
vite --port 3001

# または設定ファイルで
server: {
  port: 3001
}
```

### キャッシュクリア

```bash
# node_modules/.vite を削除
rm -rf node_modules/.vite
```

### HMRが動作しない

```javascript
// vite.config.js
export default {
  server: {
    watch: {
      usePolling: true
    }
  }
}
```

---

## 参考リンク

- [Vite 公式ドキュメント](https://vitejs.dev/)
- [Awesome Vite](https://github.com/vitejs/awesome-vite)
- [Vite Plugins](https://vitejs.dev/plugins/)
