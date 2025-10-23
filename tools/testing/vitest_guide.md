# Vitest テストガイド

Vitestは、Viteベースの高速なテストフレームワークです。

## 特徴

- **超高速**: Viteのトランスフォーム機能を活用
- **Jest互換**: Jestのほとんどの機能をサポート
- **ESMネイティブ**: ES Modulesをそのまま使用可能
- **TypeScript完全対応**: 型定義が充実
- **UI搭載**: ブラウザでテスト結果を確認可能
- **HMR対応**: テストファイルの変更を即座に反映

## インストール

```bash
npm install -D vitest
# or
yarn add -D vitest
# or
pnpm add -D vitest
```

## セットアップ

### 基本設定

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
    },
  },
})
```

### React プロジェクトの設定

```bash
npm install -D @testing-library/react @testing-library/jest-dom jsdom
```

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
  },
})
```

```typescript
// src/test/setup.ts
import { expect, afterEach } from 'vitest'
import { cleanup } from '@testing-library/react'
import * as matchers from '@testing-library/jest-dom/matchers'

expect.extend(matchers)

afterEach(() => {
  cleanup()
})
```

### package.json

```json
{
  "scripts": {
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage"
  }
}
```

## 基本的なテストの書き方

### 基本構文

```typescript
// sum.test.ts
import { describe, it, expect } from 'vitest'

function sum(a: number, b: number): number {
  return a + b
}

describe('sum', () => {
  it('should add two numbers', () => {
    expect(sum(1, 2)).toBe(3)
  })

  it('should handle negative numbers', () => {
    expect(sum(-1, -2)).toBe(-3)
  })

  it('should handle zero', () => {
    expect(sum(0, 0)).toBe(0)
  })
})
```

### test と it

```typescript
import { test, expect } from 'vitest'

// test と it は同じ
test('adds 1 + 2 to equal 3', () => {
  expect(1 + 2).toBe(3)
})

// it の方が読みやすい場合もある
it('should return true when input is valid', () => {
  expect(isValid('test')).toBe(true)
})
```

### テストのスキップと限定

```typescript
import { describe, it, test } from 'vitest'

describe('math operations', () => {
  it('adds', () => {
    expect(1 + 1).toBe(2)
  })

  // このテストをスキップ
  it.skip('subtracts', () => {
    expect(2 - 1).toBe(1)
  })

  // このテストのみ実行
  it.only('multiplies', () => {
    expect(2 * 2).toBe(4)
  })

  // TODO: 後で実装
  it.todo('divides')
})
```

## マッチャー

### 等価性

```typescript
// 厳密等価
expect(1 + 2).toBe(3)
expect(true).toBe(true)

// オブジェクトの等価
expect({ name: 'John' }).toEqual({ name: 'John' })

// 厳密な等価（型も含む）
expect({ name: 'John' }).toStrictEqual({ name: 'John' })
```

### 真偽値

```typescript
expect(null).toBeNull()
expect(undefined).toBeUndefined()
expect(value).toBeDefined()
expect(true).toBeTruthy()
expect(false).toBeFalsy()
```

### 数値

```typescript
expect(2 + 2).toBeGreaterThan(3)
expect(2 + 2).toBeGreaterThanOrEqual(4)
expect(2 + 2).toBeLessThan(5)
expect(2 + 2).toBeLessThanOrEqual(4)

// 浮動小数点数
expect(0.1 + 0.2).toBeCloseTo(0.3)
```

### 文字列

```typescript
expect('Hello World').toMatch(/World/)
expect('Hello World').toMatch('World')
expect('Hello World').toContain('World')
```

### 配列とオブジェクト

```typescript
const list = ['apple', 'banana', 'orange']

expect(list).toContain('apple')
expect(list).toHaveLength(3)

const obj = { name: 'John', age: 30 }

expect(obj).toHaveProperty('name')
expect(obj).toHaveProperty('name', 'John')
expect(obj).toMatchObject({ name: 'John' })
```

### 例外

```typescript
function throwError() {
  throw new Error('Something went wrong')
}

expect(() => throwError()).toThrow()
expect(() => throwError()).toThrow(Error)
expect(() => throwError()).toThrow('Something went wrong')
expect(() => throwError()).toThrow(/wrong/)
```

### Promise

```typescript
// async/await
test('resolves to value', async () => {
  await expect(Promise.resolve('success')).resolves.toBe('success')
})

test('rejects with error', async () => {
  await expect(Promise.reject(new Error('failed'))).rejects.toThrow('failed')
})

// または
test('async function', async () => {
  const result = await fetchData()
  expect(result).toBe('data')
})
```

## セットアップとティアダウン

### beforeEach / afterEach

```typescript
import { describe, it, expect, beforeEach, afterEach } from 'vitest'

describe('database tests', () => {
  let db: Database

  beforeEach(() => {
    // 各テストの前に実行
    db = new Database()
    db.connect()
  })

  afterEach(() => {
    // 各テストの後に実行
    db.disconnect()
  })

  it('should insert data', () => {
    db.insert({ name: 'John' })
    expect(db.count()).toBe(1)
  })

  it('should delete data', () => {
    db.insert({ name: 'John' })
    db.delete(1)
    expect(db.count()).toBe(0)
  })
})
```

### beforeAll / afterAll

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest'

describe('suite', () => {
  beforeAll(() => {
    // 全てのテストの前に1回だけ実行
    console.log('Setup')
  })

  afterAll(() => {
    // 全てのテストの後に1回だけ実行
    console.log('Teardown')
  })

  it('test 1', () => {
    expect(true).toBe(true)
  })

  it('test 2', () => {
    expect(true).toBe(true)
  })
})
```

## モック

### 関数のモック

```typescript
import { vi, expect, test } from 'vitest'

// モック関数の作成
const mockFn = vi.fn()

test('mock function', () => {
  mockFn('hello')
  mockFn('world')

  expect(mockFn).toHaveBeenCalledTimes(2)
  expect(mockFn).toHaveBeenCalledWith('hello')
  expect(mockFn).toHaveBeenLastCalledWith('world')
})

// 戻り値を設定
const mockFn2 = vi.fn().mockReturnValue(42)
expect(mockFn2()).toBe(42)

// 非同期の戻り値
const mockFn3 = vi.fn().mockResolvedValue('success')
await expect(mockFn3()).resolves.toBe('success')

// 実装を設定
const mockFn4 = vi.fn((x: number) => x * 2)
expect(mockFn4(5)).toBe(10)
```

### モジュールのモック

```typescript
// api.ts
export async function fetchUser(id: string) {
  const response = await fetch(`/api/users/${id}`)
  return response.json()
}

// user.test.ts
import { vi, expect, test } from 'vitest'
import { fetchUser } from './api'

// モジュール全体をモック
vi.mock('./api', () => ({
  fetchUser: vi.fn(),
}))

test('fetchUser', async () => {
  const mockFetchUser = fetchUser as vi.MockedFunction<typeof fetchUser>
  mockFetchUser.mockResolvedValue({ id: '1', name: 'John' })

  const user = await fetchUser('1')
  expect(user).toEqual({ id: '1', name: 'John' })
  expect(mockFetchUser).toHaveBeenCalledWith('1')
})
```

### スパイ

```typescript
import { vi, expect, test } from 'vitest'

const user = {
  getName: () => 'John',
  getAge: () => 30,
}

test('spy on method', () => {
  const spy = vi.spyOn(user, 'getName')

  user.getName()

  expect(spy).toHaveBeenCalled()
  expect(spy).toHaveReturnedWith('John')

  spy.mockRestore() // 元の実装に戻す
})

// 戻り値を変更
test('spy with mock return value', () => {
  const spy = vi.spyOn(user, 'getName').mockReturnValue('Jane')

  expect(user.getName()).toBe('Jane')

  spy.mockRestore()
})
```

### タイマーのモック

```typescript
import { vi, expect, test, beforeEach, afterEach } from 'vitest'

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.restoreAllMocks()
})

test('setTimeout', () => {
  const callback = vi.fn()

  setTimeout(callback, 1000)

  // 時間を進める
  vi.advanceTimersByTime(1000)

  expect(callback).toHaveBeenCalled()
})

test('setInterval', () => {
  const callback = vi.fn()

  setInterval(callback, 1000)

  // 3秒進める
  vi.advanceTimersByTime(3000)

  expect(callback).toHaveBeenCalledTimes(3)
})
```

### fetch のモック

```typescript
import { vi, expect, test } from 'vitest'

test('fetch mock', async () => {
  global.fetch = vi.fn().mockResolvedValue({
    json: async () => ({ id: 1, name: 'John' }),
  })

  const response = await fetch('/api/users/1')
  const data = await response.json()

  expect(data).toEqual({ id: 1, name: 'John' })
})
```

## Reactコンポーネントのテスト

### 基本的なレンダリング

```typescript
// Button.tsx
interface ButtonProps {
  onClick: () => void
  children: React.ReactNode
}

export function Button({ onClick, children }: ButtonProps) {
  return <button onClick={onClick}>{children}</button>
}

// Button.test.tsx
import { render, screen } from '@testing-library/react'
import { expect, test, vi } from 'vitest'
import { Button } from './Button'

test('renders button with text', () => {
  render(<Button onClick={() => {}}>Click me</Button>)

  expect(screen.getByText('Click me')).toBeInTheDocument()
})

test('calls onClick when clicked', async () => {
  const handleClick = vi.fn()
  const { user } = render(<Button onClick={handleClick}>Click me</Button>)

  const button = screen.getByText('Click me')
  await user.click(button)

  expect(handleClick).toHaveBeenCalledTimes(1)
})
```

### フォームのテスト

```typescript
// LoginForm.tsx
export function LoginForm({ onSubmit }: { onSubmit: (data: any) => void }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSubmit({ email, password })
  }

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        placeholder="Email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
      />
      <input
        type="password"
        placeholder="Password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      <button type="submit">Login</button>
    </form>
  )
}

// LoginForm.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'
import { LoginForm } from './LoginForm'

test('submits form with email and password', async () => {
  const handleSubmit = vi.fn()
  const user = userEvent.setup()

  render(<LoginForm onSubmit={handleSubmit} />)

  await user.type(screen.getByPlaceholderText('Email'), 'test@example.com')
  await user.type(screen.getByPlaceholderText('Password'), 'password123')
  await user.click(screen.getByText('Login'))

  expect(handleSubmit).toHaveBeenCalledWith({
    email: 'test@example.com',
    password: 'password123',
  })
})
```

### 非同期コンポーネント

```typescript
// UserProfile.tsx
export function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchUser(userId).then((data) => {
      setUser(data)
      setLoading(false)
    })
  }, [userId])

  if (loading) return <div>Loading...</div>
  if (!user) return <div>User not found</div>

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  )
}

// UserProfile.test.tsx
import { render, screen, waitFor } from '@testing-library/react'
import { expect, test, vi } from 'vitest'
import { UserProfile } from './UserProfile'
import * as api from './api'

vi.mock('./api')

test('displays user profile', async () => {
  const mockUser = { id: '1', name: 'John', email: 'john@example.com' }
  vi.mocked(api.fetchUser).mockResolvedValue(mockUser)

  render(<UserProfile userId="1" />)

  expect(screen.getByText('Loading...')).toBeInTheDocument()

  await waitFor(() => {
    expect(screen.getByText('John')).toBeInTheDocument()
    expect(screen.getByText('john@example.com')).toBeInTheDocument()
  })
})
```

### カスタムフックのテスト

```typescript
// useCounter.ts
export function useCounter(initialValue = 0) {
  const [count, setCount] = useState(initialValue)

  const increment = () => setCount((c) => c + 1)
  const decrement = () => setCount((c) => c - 1)
  const reset = () => setCount(initialValue)

  return { count, increment, decrement, reset }
}

// useCounter.test.ts
import { renderHook, act } from '@testing-library/react'
import { expect, test } from 'vitest'
import { useCounter } from './useCounter'

test('useCounter', () => {
  const { result } = renderHook(() => useCounter(0))

  expect(result.current.count).toBe(0)

  act(() => {
    result.current.increment()
  })

  expect(result.current.count).toBe(1)

  act(() => {
    result.current.decrement()
  })

  expect(result.current.count).toBe(0)

  act(() => {
    result.current.reset()
  })

  expect(result.current.count).toBe(0)
})
```

## スナップショットテスト

```typescript
import { render } from '@testing-library/react'
import { expect, test } from 'vitest'
import { Button } from './Button'

test('matches snapshot', () => {
  const { container } = render(<Button onClick={() => {}}>Click me</Button>)
  expect(container.firstChild).toMatchSnapshot()
})

// インラインスナップショット
test('matches inline snapshot', () => {
  const { container } = render(<Button onClick={() => {}}>Click me</Button>)
  expect(container.firstChild).toMatchInlineSnapshot()
})
```

## カバレッジ

### 設定

```bash
npm install -D @vitest/coverage-v8
```

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'src/test/',
        '**/*.test.ts',
        '**/*.spec.ts',
      ],
      all: true,
      lines: 80,
      functions: 80,
      branches: 80,
      statements: 80,
    },
  },
})
```

### 実行

```bash
# カバレッジ付きでテスト実行
npm run test:coverage

# カバレッジレポートはcoverageディレクトリに出力
```

## UI モード

```bash
# UIモードで起動
npm run test:ui
```

ブラウザで `http://localhost:51204/__vitest__/` が開き、テスト結果をGUIで確認可能。

## ベストプラクティス

1. **テストは独立させる**: 各テストは他のテストに依存しない
2. **AAA パターン**: Arrange（準備）、Act（実行）、Assert（検証）
3. **わかりやすい名前**: テストケース名は明確に
4. **モックは最小限**: 必要な部分だけモック
5. **スナップショットは慎重に**: 変更が多い箇所には使わない
6. **カバレッジ目標**: 80%以上を目指す

### テストの構造

```typescript
describe('UserService', () => {
  describe('createUser', () => {
    it('should create a user with valid data', () => {
      // Arrange（準備）
      const userData = { name: 'John', email: 'john@example.com' }

      // Act（実行）
      const user = userService.createUser(userData)

      // Assert（検証）
      expect(user).toMatchObject(userData)
      expect(user.id).toBeDefined()
    })

    it('should throw error with invalid email', () => {
      const userData = { name: 'John', email: 'invalid' }

      expect(() => userService.createUser(userData)).toThrow('Invalid email')
    })
  })
})
```

## JestからVitestへの移行

### 主な違い

```typescript
// Jest
import { jest } from '@jest/globals'

// Vitest
import { vi } from 'vitest'

// Jest
jest.fn()
jest.mock()
jest.spyOn()

// Vitest
vi.fn()
vi.mock()
vi.spyOn()
```

### globals設定

```typescript
// vitest.config.ts で globals: true にすると
// import なしで使用可能
describe('test', () => {
  it('works', () => {
    expect(true).toBe(true)
  })
})
```

## 参考リンク

- [Vitest 公式ドキュメント](https://vitest.dev/)
- [Testing Library](https://testing-library.com/)
- [Vitest Examples](https://github.com/vitest-dev/vitest/tree/main/examples)
- [Vitest vs Jest](https://vitest.dev/guide/comparisons.html)
