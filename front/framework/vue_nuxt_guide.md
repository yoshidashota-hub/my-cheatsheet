# Vue.js & Nuxt.js 完全ガイド

## 目次
- [Vue.js](#vuejs)
- [Composition API](#composition-api)
- [コンポーネント](#コンポーネント)
- [状態管理（Pinia）](#状態管理pinia)
- [Nuxt.js](#nuxtjs)
- [Nuxt 3](#nuxt-3)
- [ルーティング](#ルーティング)
- [データフェッチング](#データフェッチング)

---

## Vue.js

プログレッシブJavaScriptフレームワーク。

### セットアップ

```bash
# Vite + Vue
npm create vite@latest my-vue-app -- --template vue
npm create vite@latest my-vue-app -- --template vue-ts

cd my-vue-app
npm install
npm run dev
```

### 基本的なコンポーネント

```vue
<template>
  <div class="hello">
    <h1>{{ msg }}</h1>
    <button @click="count++">Count: {{ count }}</button>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const msg = ref('Hello Vue!')
const count = ref(0)
</script>

<style scoped>
.hello {
  color: #42b983;
}
</style>
```

---

## Composition API

Vue 3の新しいAPI。

### リアクティビティ

```typescript
import { ref, reactive, computed, watch } from 'vue'

// ref（プリミティブ値）
const count = ref(0)
count.value++ // .value でアクセス

// reactive（オブジェクト）
const state = reactive({
  name: 'John',
  age: 25
})
state.name = 'Jane' // 直接アクセス

// computed（算出プロパティ）
const doubled = computed(() => count.value * 2)

// watch（監視）
watch(count, (newVal, oldVal) => {
  console.log(`Count changed from ${oldVal} to ${newVal}`)
})

// watchEffect（自動依存関係）
watchEffect(() => {
  console.log(`Count is ${count.value}`)
})
```

### ライフサイクルフック

```typescript
import { onMounted, onUpdated, onUnmounted } from 'vue'

onMounted(() => {
  console.log('Component mounted')
})

onUpdated(() => {
  console.log('Component updated')
})

onUnmounted(() => {
  console.log('Component unmounted')
})
```

---

## コンポーネント

### Props

```vue
<!-- Parent.vue -->
<template>
  <Child :message="greeting" :count="10" />
</template>

<!-- Child.vue -->
<script setup lang="ts">
defineProps<{
  message: string
  count: number
}>()
</script>
```

### Emits

```vue
<!-- Child.vue -->
<script setup lang="ts">
const emit = defineEmits<{
  update: [value: string]
  delete: []
}>()

const handleClick = () => {
  emit('update', 'new value')
}
</script>

<!-- Parent.vue -->
<template>
  <Child @update="handleUpdate" />
</template>
```

### スロット

```vue
<!-- Layout.vue -->
<template>
  <div class="layout">
    <header>
      <slot name="header"></slot>
    </header>
    <main>
      <slot></slot>
    </main>
  </div>
</template>

<!-- Parent.vue -->
<template>
  <Layout>
    <template #header>
      <h1>Title</h1>
    </template>
    <p>Content</p>
  </Layout>
</template>
```

---

## 状態管理（Pinia）

Vue 3公式の状態管理ライブラリ。

### セットアップ

```bash
npm install pinia
```

```typescript
// main.ts
import { createPinia } from 'pinia'

app.use(createPinia())
```

### ストア定義

```typescript
// stores/counter.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useCounterStore = defineStore('counter', () => {
  // State
  const count = ref(0)

  // Getters
  const doubled = computed(() => count.value * 2)

  // Actions
  function increment() {
    count.value++
  }

  return { count, doubled, increment }
})
```

### ストア使用

```vue
<script setup lang="ts">
import { useCounterStore } from '@/stores/counter'

const counter = useCounterStore()
</script>

<template>
  <div>
    <p>Count: {{ counter.count }}</p>
    <p>Doubled: {{ counter.doubled }}</p>
    <button @click="counter.increment()">Increment</button>
  </div>
</template>
```

---

## Nuxt.js

Vue.jsのメタフレームワーク。

### Nuxt 3 セットアップ

```bash
npx nuxi@latest init my-nuxt-app
cd my-nuxt-app
npm install
npm run dev
```

### ディレクトリ構造

```
my-nuxt-app/
├── pages/           # ルーティング（ファイルベース）
├── components/      # コンポーネント（自動インポート）
├── composables/     # Composition関数
├── layouts/         # レイアウト
├── plugins/         # プラグイン
├── middleware/      # ミドルウェア
├── server/          # サーバーAPI
├── public/          # 静的ファイル
└── nuxt.config.ts   # 設定ファイル
```

---

## Nuxt 3

### Pages（ルーティング）

```vue
<!-- pages/index.vue -->
<template>
  <div>
    <h1>Home Page</h1>
  </div>
</template>

<!-- pages/about.vue -->
<template>
  <div>
    <h1>About Page</h1>
  </div>
</template>

<!-- pages/posts/[id].vue -->
<script setup lang="ts">
const route = useRoute()
const id = route.params.id
</script>
```

### Layouts

```vue
<!-- layouts/default.vue -->
<template>
  <div>
    <header>Header</header>
    <slot />
    <footer>Footer</footer>
  </div>
</template>

<!-- pages/index.vue -->
<script setup lang="ts">
definePageMeta({
  layout: 'default'
})
</script>
```

---

## ルーティング

### ナビゲーション

```vue
<template>
  <NuxtLink to="/">Home</NuxtLink>
  <NuxtLink to="/about">About</NuxtLink>
  <NuxtLink :to="`/posts/${id}`">Post</NuxtLink>
</template>

<script setup lang="ts">
const router = useRouter()

// プログラマティックナビゲーション
const goToAbout = () => {
  router.push('/about')
}
</script>
```

---

## データフェッチング

### useFetch

```vue
<script setup lang="ts">
const { data, pending, error } = await useFetch('/api/users')
</script>

<template>
  <div v-if="pending">Loading...</div>
  <div v-else-if="error">Error: {{ error }}</div>
  <div v-else>
    <div v-for="user in data" :key="user.id">
      {{ user.name }}
    </div>
  </div>
</template>
```

### useAsyncData

```vue
<script setup lang="ts">
const { data } = await useAsyncData('users', () => $fetch('/api/users'))
</script>
```

---

## 参考リンク

- [Vue.js 公式](https://vuejs.org/)
- [Nuxt 3 公式](https://nuxt.com/)
- [Pinia](https://pinia.vuejs.org/)
