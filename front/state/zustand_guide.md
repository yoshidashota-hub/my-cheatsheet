# Zustand 状態管理ガイド

Zustandは、シンプルで高速な状態管理ライブラリです。

## 特徴

- **シンプル**: Boilerplateが少ない
- **高速**: 不要なレンダリングが発生しない
- **型安全**: TypeScriptで完全な型サポート
- **軽量**: 1KB以下のバンドルサイズ
- **柔軟**: Reactに依存しない設計

## インストール

```bash
npm install zustand
# or
yarn add zustand
# or
pnpm add zustand
```

## 基本的な使い方

### ストアの作成

```typescript
// store/useStore.ts
import { create } from 'zustand'

interface BearState {
  bears: number
  increasePopulation: () => void
  removeAllBears: () => void
  updateBears: (newBears: number) => void
}

export const useBearStore = create<BearState>((set) => ({
  bears: 0,
  increasePopulation: () => set((state) => ({ bears: state.bears + 1 })),
  removeAllBears: () => set({ bears: 0 }),
  updateBears: (newBears) => set({ bears: newBears }),
}))
```

### コンポーネントで使用

```typescript
// components/BearCounter.tsx
import { useBearStore } from '@/store/useStore'

export default function BearCounter() {
  const bears = useBearStore((state) => state.bears)
  const increasePopulation = useBearStore((state) => state.increasePopulation)

  return (
    <div>
      <h1>{bears} bears around here...</h1>
      <button onClick={increasePopulation}>Add bear</button>
    </div>
  )
}
```

### 複数の状態を取得

```typescript
// 複数の値を取得
const { bears, increasePopulation } = useBearStore((state) => ({
  bears: state.bears,
  increasePopulation: state.increasePopulation,
}))

// 全ての状態を取得（非推奨 - 不要なレンダリングが発生）
const state = useBearStore()
```

## ストアの更新

### set関数

```typescript
import { create } from 'zustand'

interface CounterState {
  count: number
  increment: () => void
  decrement: () => void
  reset: () => void
  setCount: (count: number) => void
}

export const useCounterStore = create<CounterState>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
  reset: () => set({ count: 0 }),
  setCount: (count) => set({ count }),
}))
```

### 部分的な更新

```typescript
// 複数のフィールドを同時に更新
set((state) => ({
  count: state.count + 1,
  lastUpdated: new Date(),
}))

// オブジェクトのマージ
set({ count: 0 }) // 他のフィールドは保持される
```

### replaceオプション

```typescript
// 状態を完全に置き換える
set({ count: 0 }, true) // 他のフィールドは削除される
```

## get関数

```typescript
import { create } from 'zustand'

interface TodoState {
  todos: string[]
  addTodo: (todo: string) => void
  removeTodo: (index: number) => void
  getTodoCount: () => number
}

export const useTodoStore = create<TodoState>((set, get) => ({
  todos: [],
  addTodo: (todo) => set((state) => ({ todos: [...state.todos, todo] })),
  removeTodo: (index) =>
    set((state) => ({
      todos: state.todos.filter((_, i) => i !== index),
    })),
  getTodoCount: () => get().todos.length,
}))
```

## 非同期アクション

```typescript
import { create } from 'zustand'

interface UserState {
  user: User | null
  loading: boolean
  error: string | null
  fetchUser: (id: string) => Promise<void>
}

export const useUserStore = create<UserState>((set) => ({
  user: null,
  loading: false,
  error: null,
  fetchUser: async (id) => {
    set({ loading: true, error: null })
    try {
      const response = await fetch(`/api/users/${id}`)
      const user = await response.json()
      set({ user, loading: false })
    } catch (error) {
      set({ error: error.message, loading: false })
    }
  },
}))
```

## セレクターの最適化

### 浅い比較（Shallow）

```typescript
import { create } from 'zustand'
import { shallow } from 'zustand/shallow'

const useStore = create((set) => ({
  count: 0,
  text: '',
  increment: () => set((state) => ({ count: state.count + 1 })),
  setText: (text) => set({ text }),
}))

// shallow を使用して不要なレンダリングを防ぐ
function Component() {
  const { count, text } = useStore(
    (state) => ({ count: state.count, text: state.text }),
    shallow
  )
  return (
    <div>
      <p>{count}</p>
      <p>{text}</p>
    </div>
  )
}
```

### セレクターの分離

```typescript
// ❌ 悪い例（textが変更されてもレンダリングされる）
function Component() {
  const { count, text } = useStore()
  return <div>{count}</div>
}

// ✅ 良い例（countが変更された時のみレンダリング）
function Component() {
  const count = useStore((state) => state.count)
  return <div>{count}</div>
}
```

## ミドルウェア

### persist（永続化）

```typescript
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

interface AuthState {
  user: User | null
  token: string | null
  login: (user: User, token: string) => void
  logout: () => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      login: (user, token) => set({ user, token }),
      logout: () => set({ user: null, token: null }),
    }),
    {
      name: 'auth-storage', // localStorageのキー名
      storage: createJSONStorage(() => localStorage), // デフォルト
    }
  )
)

// sessionStorageを使用
export const useSessionStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      login: (user, token) => set({ user, token }),
      logout: () => set({ user: null, token: null }),
    }),
    {
      name: 'session-storage',
      storage: createJSONStorage(() => sessionStorage),
    }
  )
)
```

### immer（イミュータブル）

```typescript
import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

interface TodoState {
  todos: Todo[]
  addTodo: (todo: Todo) => void
  toggleTodo: (id: string) => void
  updateTodo: (id: string, text: string) => void
}

export const useTodoStore = create<TodoState>()(
  immer((set) => ({
    todos: [],
    addTodo: (todo) =>
      set((state) => {
        state.todos.push(todo)
      }),
    toggleTodo: (id) =>
      set((state) => {
        const todo = state.todos.find((t) => t.id === id)
        if (todo) {
          todo.completed = !todo.completed
        }
      }),
    updateTodo: (id, text) =>
      set((state) => {
        const todo = state.todos.find((t) => t.id === id)
        if (todo) {
          todo.text = text
        }
      }),
  }))
)
```

### devtools（開発ツール）

```typescript
import { create } from 'zustand'
import { devtools } from 'zustand/middleware'

interface CounterState {
  count: number
  increment: () => void
  decrement: () => void
}

export const useCounterStore = create<CounterState>()(
  devtools(
    (set) => ({
      count: 0,
      increment: () => set((state) => ({ count: state.count + 1 }), false, 'increment'),
      decrement: () => set((state) => ({ count: state.count - 1 }), false, 'decrement'),
    }),
    {
      name: 'CounterStore',
    }
  )
)
```

### ミドルウェアの組み合わせ

```typescript
import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'
import { immer } from 'zustand/middleware/immer'

interface State {
  count: number
  increment: () => void
}

export const useStore = create<State>()(
  devtools(
    persist(
      immer((set) => ({
        count: 0,
        increment: () =>
          set((state) => {
            state.count += 1
          }),
      })),
      { name: 'my-store' }
    ),
    { name: 'MyStore' }
  )
)
```

## スライスパターン

### ストアの分割

```typescript
// store/slices/userSlice.ts
import { StateCreator } from 'zustand'

export interface UserSlice {
  user: User | null
  setUser: (user: User) => void
  clearUser: () => void
}

export const createUserSlice: StateCreator<UserSlice> = (set) => ({
  user: null,
  setUser: (user) => set({ user }),
  clearUser: () => set({ user: null }),
})

// store/slices/todoSlice.ts
import { StateCreator } from 'zustand'

export interface TodoSlice {
  todos: Todo[]
  addTodo: (todo: Todo) => void
  removeTodo: (id: string) => void
}

export const createTodoSlice: StateCreator<TodoSlice> = (set) => ({
  todos: [],
  addTodo: (todo) => set((state) => ({ todos: [...state.todos, todo] })),
  removeTodo: (id) => set((state) => ({ todos: state.todos.filter((t) => t.id !== id) })),
})

// store/index.ts
import { create } from 'zustand'
import { createUserSlice, UserSlice } from './slices/userSlice'
import { createTodoSlice, TodoSlice } from './slices/todoSlice'

type StoreState = UserSlice & TodoSlice

export const useStore = create<StoreState>()((...a) => ({
  ...createUserSlice(...a),
  ...createTodoSlice(...a),
}))
```

## React外での使用

### ストアの直接アクセス

```typescript
import { useBearStore } from '@/store/useStore'

// コンポーネント外で状態を取得
const currentBears = useBearStore.getState().bears

// コンポーネント外で状態を更新
useBearStore.getState().increasePopulation()

// 状態変更を購読
const unsubscribe = useBearStore.subscribe((state, prevState) => {
  console.log('Bears changed from', prevState.bears, 'to', state.bears)
})

// 購読解除
unsubscribe()
```

### Vanilla Store

```typescript
import { createStore } from 'zustand/vanilla'

interface CounterState {
  count: number
  increment: () => void
  decrement: () => void
}

export const counterStore = createStore<CounterState>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
}))

// 使用
counterStore.getState().increment()
console.log(counterStore.getState().count)
```

## 実践例

### 認証ストア

```typescript
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface User {
  id: string
  email: string
  name: string
}

interface AuthState {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  refreshToken: () => Promise<void>
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      login: async (email, password) => {
        try {
          const response = await fetch('/api/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password }),
          })
          const { user, token } = await response.json()
          set({ user, token, isAuthenticated: true })
        } catch (error) {
          console.error('Login failed:', error)
          throw error
        }
      },
      logout: () => {
        set({ user: null, token: null, isAuthenticated: false })
      },
      refreshToken: async () => {
        const currentToken = get().token
        if (!currentToken) return

        try {
          const response = await fetch('/api/refresh-token', {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${currentToken}`,
            },
          })
          const { token } = await response.json()
          set({ token })
        } catch (error) {
          console.error('Token refresh failed:', error)
          get().logout()
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
)
```

### ショッピングカート

```typescript
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface CartItem {
  id: string
  name: string
  price: number
  quantity: number
}

interface CartState {
  items: CartItem[]
  addItem: (item: Omit<CartItem, 'quantity'>) => void
  removeItem: (id: string) => void
  updateQuantity: (id: string, quantity: number) => void
  clearCart: () => void
  getTotalPrice: () => number
  getTotalItems: () => number
}

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],
      addItem: (item) => {
        const items = get().items
        const existingItem = items.find((i) => i.id === item.id)

        if (existingItem) {
          set({
            items: items.map((i) =>
              i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
            ),
          })
        } else {
          set({ items: [...items, { ...item, quantity: 1 }] })
        }
      },
      removeItem: (id) => {
        set({ items: get().items.filter((item) => item.id !== id) })
      },
      updateQuantity: (id, quantity) => {
        if (quantity <= 0) {
          get().removeItem(id)
          return
        }
        set({
          items: get().items.map((item) =>
            item.id === id ? { ...item, quantity } : item
          ),
        })
      },
      clearCart: () => set({ items: [] }),
      getTotalPrice: () =>
        get().items.reduce((total, item) => total + item.price * item.quantity, 0),
      getTotalItems: () =>
        get().items.reduce((total, item) => total + item.quantity, 0),
    }),
    {
      name: 'cart-storage',
    }
  )
)
```

### モーダル管理

```typescript
import { create } from 'zustand'

interface ModalState {
  modals: Record<string, boolean>
  openModal: (modalId: string) => void
  closeModal: (modalId: string) => void
  toggleModal: (modalId: string) => void
  isModalOpen: (modalId: string) => boolean
}

export const useModalStore = create<ModalState>((set, get) => ({
  modals: {},
  openModal: (modalId) =>
    set((state) => ({
      modals: { ...state.modals, [modalId]: true },
    })),
  closeModal: (modalId) =>
    set((state) => ({
      modals: { ...state.modals, [modalId]: false },
    })),
  toggleModal: (modalId) =>
    set((state) => ({
      modals: { ...state.modals, [modalId]: !state.modals[modalId] },
    })),
  isModalOpen: (modalId) => get().modals[modalId] || false,
}))

// 使用例
function MyComponent() {
  const { openModal, closeModal, isModalOpen } = useModalStore()

  return (
    <div>
      <button onClick={() => openModal('login')}>Open Login</button>
      {isModalOpen('login') && (
        <Modal onClose={() => closeModal('login')}>
          <LoginForm />
        </Modal>
      )}
    </div>
  )
}
```

### フォーム状態管理

```typescript
import { create } from 'zustand'

interface FormState {
  values: Record<string, any>
  errors: Record<string, string>
  touched: Record<string, boolean>
  isSubmitting: boolean
  setValue: (field: string, value: any) => void
  setError: (field: string, error: string) => void
  setTouched: (field: string, touched: boolean) => void
  reset: () => void
  submit: (onSubmit: (values: Record<string, any>) => Promise<void>) => Promise<void>
}

export const useFormStore = create<FormState>((set, get) => ({
  values: {},
  errors: {},
  touched: {},
  isSubmitting: false,
  setValue: (field, value) =>
    set((state) => ({
      values: { ...state.values, [field]: value },
      errors: { ...state.errors, [field]: '' },
    })),
  setError: (field, error) =>
    set((state) => ({
      errors: { ...state.errors, [field]: error },
    })),
  setTouched: (field, touched) =>
    set((state) => ({
      touched: { ...state.touched, [field]: touched },
    })),
  reset: () =>
    set({
      values: {},
      errors: {},
      touched: {},
      isSubmitting: false,
    }),
  submit: async (onSubmit) => {
    set({ isSubmitting: true })
    try {
      await onSubmit(get().values)
      get().reset()
    } catch (error) {
      console.error('Form submission failed:', error)
    } finally {
      set({ isSubmitting: false })
    }
  },
}))
```

## テスト

```typescript
import { renderHook, act } from '@testing-library/react'
import { useBearStore } from './store'

describe('useBearStore', () => {
  beforeEach(() => {
    // ストアをリセット
    useBearStore.setState({ bears: 0 })
  })

  it('should increase bear population', () => {
    const { result } = renderHook(() => useBearStore())

    act(() => {
      result.current.increasePopulation()
    })

    expect(result.current.bears).toBe(1)
  })

  it('should remove all bears', () => {
    const { result } = renderHook(() => useBearStore())

    act(() => {
      result.current.updateBears(5)
      result.current.removeAllBears()
    })

    expect(result.current.bears).toBe(0)
  })
})
```

## Redux DevToolsとの連携

```typescript
import { create } from 'zustand'
import { devtools } from 'zustand/middleware'

export const useStore = create<State>()(
  devtools(
    (set) => ({
      count: 0,
      increment: () => set((state) => ({ count: state.count + 1 }), false, 'increment'),
    }),
    {
      name: 'MyStore',
      enabled: process.env.NODE_ENV === 'development',
    }
  )
)
```

ブラウザのRedux DevTools拡張機能で状態の変更を確認可能。

## ベストプラクティス

1. **セレクターを使用**: 必要な状態のみを取得して不要なレンダリングを防ぐ
2. **アクションを分離**: 状態更新ロジックをストアに集約
3. **型定義**: TypeScriptで型安全性を確保
4. **ミドルウェア活用**: persist, devtools, immerを適切に使用
5. **スライスパターン**: 大規模アプリでは状態を分割
6. **テスト**: ストアのロジックをテスト

## ReduxやRecoilとの比較

| 機能 | Zustand | Redux | Recoil |
|------|---------|-------|--------|
| Boilerplate | 少ない | 多い | 中程度 |
| バンドルサイズ | 1KB | 3KB+ | 14KB+ |
| 学習コスト | 低い | 高い | 中程度 |
| TypeScript | 完全サポート | 完全サポート | 部分サポート |
| DevTools | あり | あり | あり |
| ミドルウェア | あり | あり | 限定的 |

## 参考リンク

- [Zustand 公式ドキュメント](https://docs.pmnd.rs/zustand/getting-started/introduction)
- [Zustand GitHub](https://github.com/pmndrs/zustand)
- [Zustand Examples](https://github.com/pmndrs/zustand/tree/main/examples)
