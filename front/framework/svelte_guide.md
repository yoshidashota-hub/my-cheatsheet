# Svelte & SvelteKit 完全ガイド

## 目次
- [Svelteとは](#svelteとは)
- [基本構文](#基本構文)
- [リアクティビティ](#リアクティビティ)
- [コンポーネント](#コンポーネント)
- [SvelteKit](#sveltekit)
- [ルーティング](#ルーティング)
- [データロード](#データロード)

---

## Svelteとは

コンパイラベースのフロントエンドフレームワーク。仮想DOMを使わず、ビルド時に最適化。

### 特徴
- ⚡ 超高速
- 📦 小さいバンドルサイズ
- 🎯 シンプルな構文
- 🔧 ビルド時最適化

### セットアップ

```bash
npm create svelte@latest my-app
cd my-app
npm install
npm run dev
```

---

## 基本構文

### Hello World

```svelte
<script>
  let name = 'world';
</script>

<h1>Hello {name}!</h1>
```

### リアクティブステートメント

```svelte
<script>
  let count = 0;

  // リアクティブ
  $: doubled = count * 2;

  function increment() {
    count += 1;
  }
</script>

<button on:click={increment}>
  Count: {count}
</button>
<p>Doubled: {doubled}</p>
```

---

## リアクティビティ

### リアクティブ宣言

```svelte
<script>
  let count = 0;

  $: doubled = count * 2;

  $: {
    console.log(`Count is ${count}`);
    console.log(`Doubled is ${doubled}`);
  }

  $: if (count > 10) {
    alert('Count is high!');
  }
</script>
```

### Store（状態管理）

```typescript
// stores.ts
import { writable } from 'svelte/store';

export const count = writable(0);
```

```svelte
<script>
  import { count } from './stores';

  function increment() {
    count.update(n => n + 1);
  }
</script>

<button on:click={increment}>
  Count: {$count}
</button>
```

---

## コンポーネント

### Props

```svelte
<!-- Child.svelte -->
<script>
  export let name;
  export let age = 0; // デフォルト値
</script>

<p>{name} is {age} years old</p>

<!-- Parent.svelte -->
<script>
  import Child from './Child.svelte';
</script>

<Child name="John" age={25} />
```

### イベント

```svelte
<!-- Child.svelte -->
<script>
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  function handleClick() {
    dispatch('message', { text: 'Hello' });
  }
</script>

<button on:click={handleClick}>Send</button>

<!-- Parent.svelte -->
<Child on:message={e => console.log(e.detail.text)} />
```

---

## SvelteKit

Svelteのメタフレームワーク。

### プロジェクト構造

```
my-app/
├── src/
│   ├── routes/          # ページ
│   ├── lib/             # ライブラリ
│   └── app.html         # HTMLテンプレート
├── static/              # 静的ファイル
└── svelte.config.js     # 設定
```

---

## ルーティング

### ページ

```svelte
<!-- src/routes/+page.svelte -->
<h1>Home</h1>

<!-- src/routes/about/+page.svelte -->
<h1>About</h1>

<!-- src/routes/blog/[slug]/+page.svelte -->
<script>
  export let data;
</script>

<h1>{data.post.title}</h1>
```

---

## データロード

### load関数

```typescript
// +page.ts
export async function load({ params }) {
  const post = await fetchPost(params.slug);
  return { post };
}
```

---

## 参考リンク

- [Svelte 公式](https://svelte.dev/)
- [SvelteKit 公式](https://kit.svelte.dev/)
