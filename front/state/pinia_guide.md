# Pinia 完全ガイド

## 目次
- [Piniaとは](#piniaとは)
- [セットアップ](#セットアップ)
- [Store定義](#store定義)
- [State](#state)
- [Getters](#getters)
- [Actions](#actions)
- [コンポーネントで使用](#コンポーネントで使用)
- [プラグイン](#プラグイン)

---

## Piniaとは

Vue 3公式の状態管理ライブラリ。Vuexの後継として設計され、よりシンプルで型安全。

### 特徴
- 🎯 シンプルなAPI
- 📘 TypeScript完全サポート
- ⚡ DevTools統合
- 🔌 プラグインシステム

### Vuexとの違い
- Mutationsが不要
- モジュールの自動分割
- 完全なTypeScript推論

---

## セットアップ

### インストール

```bash
npm install pinia
```

### Vue 3

```typescript
// main.ts
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.mount('#app')
```

### Nuxt 3

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@pinia/nuxt']
})
```

---

## Store定義

### Options API形式

```typescript
// stores/counter.ts
import { defineStore } from 'pinia'

export const useCounterStore = defineStore('counter', {
  state: () => ({
    count: 0,
    name: 'Counter'
  }),

  getters: {
    doubleCount: (state) => state.count * 2,

    // 他のgetterを使用
    quadrupleCount(): number {
      return this.doubleCount * 2
    }
  },

  actions: {
    increment() {
      this.count++
    },

    incrementBy(amount: number) {
      this.count += amount
    },

    async fetchCount() {
      const response = await fetch('/api/count')
      const data = await response.json()
      this.count = data.count
    }
  }
})
```

### Composition API形式

```typescript
// stores/counter.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useCounterStore = defineStore('counter', () => {
  // state
  const count = ref(0)
  const name = ref('Counter')

  // getters
  const doubleCount = computed(() => count.value * 2)

  // actions
  function increment() {
    count.value++
  }

  function incrementBy(amount: number) {
    count.value += amount
  }

  async function fetchCount() {
    const response = await fetch('/api/count')
    const data = await response.json()
    count.value = data.count
  }

  return {
    count,
    name,
    doubleCount,
    increment,
    incrementBy,
    fetchCount
  }
})
```

---

## State

### アクセス

```typescript
const store = useCounterStore()

// 直接アクセス
console.log(store.count)

// 変更
store.count++

// $patch で複数更新
store.$patch({
  count: store.count + 1,
  name: 'New Counter'
})

// $patch with function
store.$patch((state) => {
  state.count++
  state.name = 'Updated'
})

// $state で置き換え
store.$state = {
  count: 10,
  name: 'Reset'
}
```

### リセット

```typescript
// 初期状態に戻す
store.$reset()
```

### 購読

```typescript
// state変更を監視
store.$subscribe((mutation, state) => {
  console.log(mutation.type) // 'direct' | 'patch object' | 'patch function'
  console.log(state)

  // localStorage に保存
  localStorage.setItem('counter', JSON.stringify(state))
})
```

---

## Getters

### 基本的な使い方

```typescript
export const useStore = defineStore('main', {
  state: () => ({
    items: [
      { id: 1, name: 'Item 1', completed: false },
      { id: 2, name: 'Item 2', completed: true }
    ]
  }),

  getters: {
    // 基本
    completedItems: (state) => {
      return state.items.filter(item => item.completed)
    },

    // 他のgetterにアクセス
    completedCount(): number {
      return this.completedItems.length
    },

    // 引数を受け取る
    getItemById: (state) => {
      return (id: number) => state.items.find(item => item.id === id)
    },

    // 他のstoreにアクセス
    otherStoreValue(): number {
      const otherStore = useOtherStore()
      return otherStore.value
    }
  }
})
```

---

## Actions

### 非同期処理

```typescript
export const useUserStore = defineStore('user', {
  state: () => ({
    user: null as User | null,
    loading: false,
    error: null as string | null
  }),

  actions: {
    async fetchUser(id: string) {
      this.loading = true
      this.error = null

      try {
        const response = await fetch(`/api/users/${id}`)
        if (!response.ok) throw new Error('Failed to fetch')

        this.user = await response.json()
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Unknown error'
      } finally {
        this.loading = false
      }
    },

    async updateUser(data: Partial<User>) {
      if (!this.user) return

      const response = await fetch(`/api/users/${this.user.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      })

      this.user = await response.json()
    }
  }
})
```

### 他のStoreを使用

```typescript
export const useCartStore = defineStore('cart', {
  actions: {
    async checkout() {
      const authStore = useAuthStore()

      if (!authStore.isLoggedIn) {
        throw new Error('User not logged in')
      }

      // checkout処理
      await fetch('/api/checkout', {
        headers: {
          'Authorization': `Bearer ${authStore.token}`
        }
      })
    }
  }
})
```

---

## コンポーネントで使用

### Options API

```vue
<script lang="ts">
import { defineComponent } from 'vue'
import { useCounterStore } from '@/stores/counter'
import { mapState, mapActions } from 'pinia'

export default defineComponent({
  computed: {
    ...mapState(useCounterStore, ['count', 'doubleCount'])
  },

  methods: {
    ...mapActions(useCounterStore, ['increment', 'incrementBy'])
  }
})
</script>

<template>
  <div>
    <p>Count: {{ count }}</p>
    <p>Double: {{ doubleCount }}</p>
    <button @click="increment">+1</button>
    <button @click="incrementBy(5)">+5</button>
  </div>
</template>
```

### Composition API

```vue
<script setup lang="ts">
import { useCounterStore } from '@/stores/counter'
import { storeToRefs } from 'pinia'

const store = useCounterStore()

// リアクティブな参照を取得
const { count, doubleCount } = storeToRefs(store)

// actionsは直接取得可能
const { increment, incrementBy } = store
</script>

<template>
  <div>
    <p>Count: {{ count }}</p>
    <p>Double: {{ doubleCount }}</p>
    <button @click="increment">+1</button>
    <button @click="incrementBy(5)">+5</button>
  </div>
</template>
```

---

## プラグイン

### 永続化プラグイン

```bash
npm install pinia-plugin-persistedstate
```

```typescript
// main.ts
import { createPinia } from 'pinia'
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate'

const pinia = createPinia()
pinia.use(piniaPluginPersistedstate)
```

```typescript
// stores/user.ts
export const useUserStore = defineStore('user', {
  state: () => ({
    token: null,
    user: null
  }),

  persist: true // localStorage に自動保存
})

// カスタム設定
export const useUserStore = defineStore('user', {
  state: () => ({
    token: null,
    user: null
  }),

  persist: {
    storage: sessionStorage,
    paths: ['token'] // token のみ保存
  }
})
```

### カスタムプラグイン

```typescript
// plugins/logger.ts
import { PiniaPluginContext } from 'pinia'

export function loggerPlugin({ store }: PiniaPluginContext) {
  store.$subscribe((mutation) => {
    console.log(`[${store.$id}]:`, mutation.type)
  })

  // 全storeに共通のプロパティを追加
  return {
    createdAt: new Date()
  }
}

// main.ts
const pinia = createPinia()
pinia.use(loggerPlugin)
```

---

## TypeScript

### 型定義

```typescript
interface User {
  id: string
  name: string
  email: string
}

interface UserState {
  user: User | null
  users: User[]
  loading: boolean
}

export const useUserStore = defineStore('user', {
  state: (): UserState => ({
    user: null,
    users: [],
    loading: false
  }),

  getters: {
    currentUser: (state): User | null => state.user,
    userCount: (state): number => state.users.length
  },

  actions: {
    setUser(user: User) {
      this.user = user
    }
  }
})
```

### Store型の取得

```typescript
import { useUserStore } from '@/stores/user'

type UserStore = ReturnType<typeof useUserStore>
```

---

## テスト

```typescript
import { setActivePinia, createPinia } from 'pinia'
import { useCounterStore } from '@/stores/counter'

describe('Counter Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('increments count', () => {
    const store = useCounterStore()
    expect(store.count).toBe(0)

    store.increment()
    expect(store.count).toBe(1)
  })

  it('increments by amount', () => {
    const store = useCounterStore()
    store.incrementBy(5)
    expect(store.count).toBe(5)
  })

  it('computes double count', () => {
    const store = useCounterStore()
    store.count = 10
    expect(store.doubleCount).toBe(20)
  })
})
```

---

## 参考リンク

- [Pinia 公式](https://pinia.vuejs.org/)
- [pinia-plugin-persistedstate](https://prazdevs.github.io/pinia-plugin-persistedstate/)
