# Jest 完全ガイド

## 目次
- [Jestとは](#jestとは)
- [セットアップ](#セットアップ)
- [基本的なテスト](#基本的なテスト)
- [マッチャー](#マッチャー)
- [非同期テスト](#非同期テスト)
- [モック](#モック)
- [スナップショットテスト](#スナップショットテスト)
- [カバレッジ](#カバレッジ)

---

## Jestとは

Facebook製のJavaScriptテストフレームワーク。設定不要で使いやすく、高速。

### 特徴
- ⚡ 高速並列実行
- 🔧 ゼロコンフィグ
- 📸 スナップショットテスト
- 🎭 強力なモック機能

---

## セットアップ

### インストール

```bash
npm install --save-dev jest

# TypeScript対応
npm install --save-dev @types/jest ts-jest
```

### package.json

```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  }
}
```

### TypeScript設定

```javascript
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts'
  ]
}
```

---

## 基本的なテスト

### テストの書き方

```typescript
// sum.ts
export function sum(a: number, b: number): number {
  return a + b
}

// sum.test.ts
import { sum } from './sum'

describe('sum', () => {
  test('adds 1 + 2 to equal 3', () => {
    expect(sum(1, 2)).toBe(3)
  })

  it('adds 5 + 5 to equal 10', () => {
    expect(sum(5, 5)).toBe(10)
  })
})
```

### テストの構造

```typescript
describe('Calculator', () => {
  // 各テスト前に実行
  beforeEach(() => {
    console.log('Before each test')
  })

  // 各テスト後に実行
  afterEach(() => {
    console.log('After each test')
  })

  // 全テスト前に1回実行
  beforeAll(() => {
    console.log('Before all tests')
  })

  // 全テスト後に1回実行
  afterAll(() => {
    console.log('After all tests')
  })

  test('addition', () => {
    expect(2 + 2).toBe(4)
  })

  test('subtraction', () => {
    expect(5 - 2).toBe(3)
  })
})
```

---

## マッチャー

### 基本マッチャー

```typescript
// 厳密な等価性
expect(2 + 2).toBe(4)
expect({ name: 'John' }).toEqual({ name: 'John' })

// 真偽値
expect(true).toBeTruthy()
expect(false).toBeFalsy()
expect(null).toBeNull()
expect(undefined).toBeUndefined()
expect(value).toBeDefined()

// 数値
expect(10).toBeGreaterThan(5)
expect(5).toBeLessThan(10)
expect(5).toBeGreaterThanOrEqual(5)
expect(5).toBeLessThanOrEqual(5)
expect(0.1 + 0.2).toBeCloseTo(0.3)

// 文字列
expect('Hello World').toMatch(/World/)
expect('test@example.com').toMatch(/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/)

// 配列・反復可能
expect(['A', 'B', 'C']).toContain('B')
expect([1, 2, 3]).toHaveLength(3)

// オブジェクト
expect({ name: 'John', age: 30 }).toHaveProperty('name')
expect({ name: 'John', age: 30 }).toHaveProperty('name', 'John')

// 例外
expect(() => {
  throw new Error('Error')
}).toThrow()
expect(() => {
  throw new Error('Not found')
}).toThrow('Not found')

// 否定
expect(2 + 2).not.toBe(5)
```

---

## 非同期テスト

### Promise

```typescript
// return を忘れずに
test('async test with promise', () => {
  return fetchData().then(data => {
    expect(data).toBe('success')
  })
})

// rejects/resolves
test('async test with resolves', () => {
  return expect(fetchData()).resolves.toBe('success')
})

test('async test with rejects', () => {
  return expect(fetchError()).rejects.toThrow('error')
})
```

### async/await

```typescript
test('async test with async/await', async () => {
  const data = await fetchData()
  expect(data).toBe('success')
})

test('async error with async/await', async () => {
  expect.assertions(1)
  try {
    await fetchError()
  } catch (error) {
    expect(error).toMatch('error')
  }
})

// より簡潔に
test('async test', async () => {
  await expect(fetchData()).resolves.toBe('success')
})
```

### タイムアウト

```typescript
test('slow test', async () => {
  const data = await slowFunction()
  expect(data).toBeDefined()
}, 10000) // 10秒タイムアウト
```

---

## モック

### 関数のモック

```typescript
// モック関数作成
const mockFn = jest.fn()

mockFn('arg1', 'arg2')

// 呼び出し確認
expect(mockFn).toHaveBeenCalled()
expect(mockFn).toHaveBeenCalledTimes(1)
expect(mockFn).toHaveBeenCalledWith('arg1', 'arg2')

// 戻り値設定
mockFn.mockReturnValue('mocked value')
mockFn.mockReturnValueOnce('first call')
  .mockReturnValueOnce('second call')
  .mockReturnValue('default')

// 実装設定
mockFn.mockImplementation((x, y) => x + y)
```

### モジュールのモック

```typescript
// api.ts
export async function fetchUser(id: string) {
  const response = await fetch(`/api/users/${id}`)
  return response.json()
}

// user.test.ts
import { fetchUser } from './api'

jest.mock('./api')

test('fetch user', async () => {
  (fetchUser as jest.Mock).mockResolvedValue({
    id: '1',
    name: 'John'
  })

  const user = await fetchUser('1')
  expect(user.name).toBe('John')
})
```

### 部分的モック

```typescript
import * as api from './api'

jest.mock('./api', () => ({
  ...jest.requireActual('./api'),
  fetchUser: jest.fn()
}))

test('partial mock', async () => {
  (api.fetchUser as jest.Mock).mockResolvedValue({ name: 'John' })
  // 他の関数は実際の実装を使用
})
```

### タイマーのモック

```typescript
jest.useFakeTimers()

test('timer test', () => {
  const callback = jest.fn()

  setTimeout(callback, 1000)

  // 時間を進める
  jest.advanceTimersByTime(1000)

  expect(callback).toHaveBeenCalled()
})

afterEach(() => {
  jest.useRealTimers()
})
```

---

## スナップショットテスト

### 基本的な使い方

```typescript
import React from 'react'
import renderer from 'react-test-renderer'
import Button from './Button'

test('Button snapshot', () => {
  const tree = renderer.create(<Button>Click me</Button>).toJSON()
  expect(tree).toMatchSnapshot()
})
```

### インラインスナップショット

```typescript
test('inline snapshot', () => {
  expect({ name: 'John', age: 30 }).toMatchInlineSnapshot(`
    {
      "age": 30,
      "name": "John",
    }
  `)
})
```

### スナップショット更新

```bash
# スナップショット更新
jest --updateSnapshot
jest -u
```

---

## カバレッジ

### カバレッジ取得

```bash
jest --coverage
```

### 設定

```javascript
// jest.config.js
module.exports = {
  collectCoverageFrom: [
    'src/**/*.{js,ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.tsx',
    '!src/index.ts'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
}
```

---

## 便利な機能

### .only と .skip

```typescript
// このテストのみ実行
test.only('only this test', () => {
  expect(true).toBe(true)
})

// このテストをスキップ
test.skip('skip this test', () => {
  expect(true).toBe(false)
})

describe.only('only this suite', () => {
  // ...
})
```

### test.each

```typescript
test.each([
  [1, 1, 2],
  [1, 2, 3],
  [2, 1, 3],
])('adds %i + %i to equal %i', (a, b, expected) => {
  expect(a + b).toBe(expected)
})

// テーブル形式
test.each`
  a    | b    | expected
  ${1} | ${1} | ${2}
  ${1} | ${2} | ${3}
  ${2} | ${1} | ${3}
`('$a + $b = $expected', ({ a, b, expected }) => {
  expect(a + b).toBe(expected)
})
```

---

## React Testing

### 環境設定

```bash
npm install --save-dev @testing-library/react @testing-library/jest-dom
```

```javascript
// jest.config.js
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js']
}

// jest.setup.js
import '@testing-library/jest-dom'
```

### コンポーネントテスト

```typescript
import { render, screen, fireEvent } from '@testing-library/react'
import Button from './Button'

test('button click', () => {
  const handleClick = jest.fn()
  render(<Button onClick={handleClick}>Click</Button>)

  const button = screen.getByRole('button', { name: 'Click' })
  fireEvent.click(button)

  expect(handleClick).toHaveBeenCalledTimes(1)
})
```

---

## 参考リンク

- [Jest 公式](https://jestjs.io/)
- [Testing Library](https://testing-library.com/)
