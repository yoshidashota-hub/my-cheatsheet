# Testing Library 完全ガイド

## 目次
- [Testing Libraryとは](#testing-libraryとは)
- [React Testing Library](#react-testing-library)
- [クエリの使い方](#クエリの使い方)
- [ユーザーイベント](#ユーザーイベント)
- [非同期テスト](#非同期テスト)
- [モックとスタブ](#モックとスタブ)
- [ベストプラクティス](#ベストプラクティス)
- [その他のライブラリ](#その他のライブラリ)

---

## Testing Libraryとは

ユーザーの視点でUIコンポーネントをテストするためのライブラリ群。実装の詳細ではなく、ユーザーが実際に体験する動作をテスト。

### 主な特徴
- 🎯 ユーザー中心のテスト
- 🔍 アクセシビリティを重視
- 🚫 実装の詳細に依存しない
- 📦 複数フレームワークに対応

### 哲学
> The more your tests resemble the way your software is used, the more confidence they can give you.

---

## React Testing Library

### セットアップ

```bash
# npm
npm install --save-dev @testing-library/react @testing-library/jest-dom

# yarn
yarn add -D @testing-library/react @testing-library/jest-dom

# With Vite + Vitest
npm install --save-dev @testing-library/react @testing-library/jest-dom vitest jsdom
```

### Vitest 設定

```javascript
// vitest.config.js
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
import '@testing-library/jest-dom'
```

### 基本的なテスト

```tsx
// Button.tsx
interface ButtonProps {
  onClick: () => void
  children: React.ReactNode
}

export function Button({ onClick, children }: ButtonProps) {
  return <button onClick={onClick}>{children}</button>
}
```

```tsx
// Button.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Button } from './Button'

describe('Button', () => {
  it('renders button text', () => {
    render(<Button onClick={() => {}}>Click me</Button>)

    expect(screen.getByText('Click me')).toBeInTheDocument()
  })

  it('calls onClick when clicked', async () => {
    const handleClick = vi.fn()
    const user = userEvent.setup()

    render(<Button onClick={handleClick}>Click me</Button>)

    await user.click(screen.getByText('Click me'))

    expect(handleClick).toHaveBeenCalledTimes(1)
  })
})
```

---

## クエリの使い方

### クエリの優先順位

Testing Libraryは以下の優先順位でクエリを使用することを推奨:

#### 1. 誰でもアクセス可能なクエリ
```tsx
// getByRole（最優先）
screen.getByRole('button', { name: /submit/i })
screen.getByRole('heading', { name: /welcome/i })

// getByLabelText（フォーム要素）
screen.getByLabelText('Email')
screen.getByLabelText(/password/i)

// getByPlaceholderText
screen.getByPlaceholderText('Enter email')

// getByText
screen.getByText('Hello World')
screen.getByText(/hello/i) // 正規表現

// getByDisplayValue（フォームの現在値）
screen.getByDisplayValue('John Doe')
```

#### 2. セマンティッククエリ
```tsx
// getByAltText（画像）
screen.getByAltText('Profile picture')

// getByTitle
screen.getByTitle('Close')
```

#### 3. Test ID（最終手段）
```tsx
// getByTestId
screen.getByTestId('custom-element')

// JSX
<div data-testid="custom-element">Content</div>
```

### クエリのバリアント

```tsx
// getBy*: 要素が見つからない場合エラー
screen.getByText('Hello')

// queryBy*: 要素が見つからない場合 null
const element = screen.queryByText('Hello')
expect(element).not.toBeInTheDocument()

// findBy*: 非同期（デフォルト1秒待機）
const element = await screen.findByText('Hello')

// getAllBy*: 複数要素
const buttons = screen.getAllByRole('button')
expect(buttons).toHaveLength(3)

// queryAllBy*: 複数要素（見つからない場合 []）
const items = screen.queryAllByRole('listitem')

// findAllBy*: 複数要素（非同期）
const items = await screen.findAllByRole('listitem')
```

### ロールの一覧

```tsx
// よく使うロール
screen.getByRole('button')
screen.getByRole('link')
screen.getByRole('heading')
screen.getByRole('textbox')
screen.getByRole('checkbox')
screen.getByRole('radio')
screen.getByRole('combobox') // select
screen.getByRole('listitem')
screen.getByRole('list')
screen.getByRole('navigation')
screen.getByRole('main')
screen.getByRole('img')
screen.getByRole('alert')
screen.getByRole('dialog')
```

### オプション指定

```tsx
// name（アクセシブルな名前）
screen.getByRole('button', { name: 'Submit' })
screen.getByRole('button', { name: /submit/i })

// level（見出しレベル）
screen.getByRole('heading', { level: 1 })

// checked（チェック状態）
screen.getByRole('checkbox', { checked: true })

// pressed（押下状態）
screen.getByRole('button', { pressed: true })

// hidden（非表示要素も含める）
screen.getByRole('button', { hidden: true })
```

---

## ユーザーイベント

### @testing-library/user-event

```bash
npm install --save-dev @testing-library/user-event
```

```tsx
import userEvent from '@testing-library/user-event'

test('user interactions', async () => {
  const user = userEvent.setup()
  render(<MyComponent />)

  // クリック
  await user.click(screen.getByRole('button'))

  // ダブルクリック
  await user.dblClick(screen.getByRole('button'))

  // 右クリック
  await user.pointer({ keys: '[MouseRight]', target: element })

  // ホバー
  await user.hover(screen.getByRole('button'))
  await user.unhover(screen.getByRole('button'))

  // キーボード入力
  await user.type(screen.getByRole('textbox'), 'Hello World')

  // クリア
  await user.clear(screen.getByRole('textbox'))

  // キーボード操作
  await user.keyboard('{Enter}')
  await user.keyboard('{Escape}')
  await user.keyboard('{Tab}')

  // セレクトボックス
  await user.selectOptions(screen.getByRole('combobox'), 'option1')

  // チェックボックス
  await user.click(screen.getByRole('checkbox'))

  // ファイルアップロード
  const file = new File(['hello'], 'hello.png', { type: 'image/png' })
  const input = screen.getByLabelText(/upload/i)
  await user.upload(input, file)

  // コピー&ペースト
  await user.copy()
  await user.paste()
})
```

### fireEvent vs userEvent

```tsx
// ✗ fireEvent（非推奨）
import { fireEvent } from '@testing-library/react'
fireEvent.click(button)
fireEvent.change(input, { target: { value: 'text' } })

// ○ userEvent（推奨）
import userEvent from '@testing-library/user-event'
await user.click(button)
await user.type(input, 'text')
```

---

## 非同期テスト

### findBy クエリ

```tsx
test('async rendering', async () => {
  render(<AsyncComponent />)

  // 要素が表示されるまで待機（デフォルト1秒）
  const element = await screen.findByText('Loaded!')
  expect(element).toBeInTheDocument()
})
```

### waitFor

```tsx
import { waitFor } from '@testing-library/react'

test('wait for condition', async () => {
  render(<Component />)

  await waitFor(() => {
    expect(screen.getByText('Success')).toBeInTheDocument()
  })

  // タイムアウト指定
  await waitFor(
    () => {
      expect(screen.getByText('Success')).toBeInTheDocument()
    },
    { timeout: 3000 }
  )
})
```

### waitForElementToBeRemoved

```tsx
test('element is removed', async () => {
  render(<Component />)

  const loader = screen.getByText('Loading...')

  await waitForElementToBeRemoved(loader)

  expect(screen.getByText('Loaded!')).toBeInTheDocument()
})
```

---

## モックとスタブ

### API モック

```tsx
// MSW (Mock Service Worker) 推奨
import { rest } from 'msw'
import { setupServer } from 'msw/node'

const server = setupServer(
  rest.get('/api/users', (req, res, ctx) => {
    return res(
      ctx.json([
        { id: 1, name: 'John' },
        { id: 2, name: 'Jane' }
      ])
    )
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

test('fetches and displays users', async () => {
  render(<UserList />)

  expect(await screen.findByText('John')).toBeInTheDocument()
  expect(await screen.findByText('Jane')).toBeInTheDocument()
})
```

### 関数モック（Vitest）

```tsx
import { vi } from 'vitest'

test('mocked function', async () => {
  const handleClick = vi.fn()

  render(<Button onClick={handleClick}>Click</Button>)

  await user.click(screen.getByRole('button'))

  expect(handleClick).toHaveBeenCalled()
  expect(handleClick).toHaveBeenCalledTimes(1)
  expect(handleClick).toHaveBeenCalledWith(expect.any(Object))
})
```

### モジュールモック

```tsx
// モックしたいモジュール
vi.mock('./api', () => ({
  fetchUsers: vi.fn(() => Promise.resolve([
    { id: 1, name: 'John' }
  ]))
}))

test('uses mocked module', async () => {
  render(<UserList />)

  expect(await screen.findByText('John')).toBeInTheDocument()
})
```

---

## カスタムマッチャー

### @testing-library/jest-dom

```tsx
import '@testing-library/jest-dom'

// DOM状態
expect(element).toBeInTheDocument()
expect(element).toBeVisible()
expect(element).toBeEmpty()
expect(element).toBeEmptyDOMElement()

// 属性
expect(element).toHaveAttribute('type', 'submit')
expect(element).toHaveClass('active')
expect(element).toHaveStyle({ color: 'red' })

// フォーム
expect(input).toHaveValue('text')
expect(input).toHaveDisplayValue('text')
expect(checkbox).toBeChecked()
expect(checkbox).not.toBeChecked()
expect(input).toBeDisabled()
expect(input).toBeEnabled()
expect(input).toBeRequired()
expect(input).toBeInvalid()
expect(input).toBeValid()

// テキスト
expect(element).toHaveTextContent('Hello')
expect(element).toHaveTextContent(/hello/i)

// アクセシビリティ
expect(element).toHaveAccessibleName('Submit button')
expect(element).toHaveAccessibleDescription('Click to submit')

// フォーカス
expect(element).toHaveFocus()
```

---

## フォームテスト

### 基本的なフォーム

```tsx
// LoginForm.tsx
export function LoginForm({ onSubmit }: { onSubmit: (data: any) => void }) {
  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const formData = new FormData(e.currentTarget)
    onSubmit({
      email: formData.get('email'),
      password: formData.get('password')
    })
  }

  return (
    <form onSubmit={handleSubmit}>
      <label htmlFor="email">Email</label>
      <input id="email" name="email" type="email" required />

      <label htmlFor="password">Password</label>
      <input id="password" name="password" type="password" required />

      <button type="submit">Login</button>
    </form>
  )
}
```

```tsx
// LoginForm.test.tsx
test('submits form with email and password', async () => {
  const handleSubmit = vi.fn()
  const user = userEvent.setup()

  render(<LoginForm onSubmit={handleSubmit} />)

  await user.type(screen.getByLabelText('Email'), 'test@example.com')
  await user.type(screen.getByLabelText('Password'), 'password123')

  await user.click(screen.getByRole('button', { name: 'Login' }))

  expect(handleSubmit).toHaveBeenCalledWith({
    email: 'test@example.com',
    password: 'password123'
  })
})
```

---

## コンポーネントテストのパターン

### 条件付きレンダリング

```tsx
test('shows loading state', () => {
  render(<Component isLoading={true} />)
  expect(screen.getByText('Loading...')).toBeInTheDocument()
})

test('shows content when loaded', () => {
  render(<Component isLoading={false} />)
  expect(screen.queryByText('Loading...')).not.toBeInTheDocument()
  expect(screen.getByText('Content')).toBeInTheDocument()
})
```

### リスト表示

```tsx
test('renders list of items', () => {
  const items = [
    { id: 1, name: 'Item 1' },
    { id: 2, name: 'Item 2' }
  ]

  render(<ItemList items={items} />)

  const listItems = screen.getAllByRole('listitem')
  expect(listItems).toHaveLength(2)

  expect(screen.getByText('Item 1')).toBeInTheDocument()
  expect(screen.getByText('Item 2')).toBeInTheDocument()
})
```

### エラー表示

```tsx
test('displays error message', () => {
  render(<Component error="Something went wrong" />)

  expect(screen.getByRole('alert')).toHaveTextContent('Something went wrong')
})
```

---

## カスタムレンダー

### テーマやプロバイダーを含める

```tsx
// test-utils.tsx
import { render } from '@testing-library/react'
import { ThemeProvider } from 'styled-components'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const AllTheProviders = ({ children }: { children: React.ReactNode }) => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false }
    }
  })

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={theme}>
        {children}
      </ThemeProvider>
    </QueryClientProvider>
  )
}

const customRender = (ui: React.ReactElement, options = {}) =>
  render(ui, { wrapper: AllTheProviders, ...options })

export * from '@testing-library/react'
export { customRender as render }
```

```tsx
// Component.test.tsx
import { render, screen } from './test-utils'

test('uses custom render', () => {
  render(<MyComponent />)
  // ThemeProvider と QueryClientProvider が自動適用される
})
```

---

## ベストプラクティス

### 1. ユーザーの視点でテスト

```tsx
// ✗ 実装の詳細に依存
expect(wrapper.find('.button').prop('onClick')).toBeDefined()

// ○ ユーザーの視点
await user.click(screen.getByRole('button', { name: 'Submit' }))
```

### 2. アクセシブルなクエリを優先

```tsx
// ✗ testid に依存
screen.getByTestId('submit-button')

// ○ role を使用
screen.getByRole('button', { name: 'Submit' })
```

### 3. 非同期処理を適切に待機

```tsx
// ✗ 固定時間待機
await new Promise(resolve => setTimeout(resolve, 1000))

// ○ findBy または waitFor を使用
await screen.findByText('Loaded!')
```

### 4. ユーザーイベントを使用

```tsx
// ✗ fireEvent
fireEvent.click(button)

// ○ userEvent
await user.click(button)
```

---

## その他のライブラリ

### Vue Testing Library

```bash
npm install --save-dev @testing-library/vue
```

```javascript
import { render, screen } from '@testing-library/vue'
import userEvent from '@testing-library/user-event'

test('renders component', async () => {
  const user = userEvent.setup()

  render(MyComponent, {
    props: { message: 'Hello' }
  })

  expect(screen.getByText('Hello')).toBeInTheDocument()
})
```

### Svelte Testing Library

```bash
npm install --save-dev @testing-library/svelte
```

### Angular Testing Library

```bash
npm install --save-dev @testing-library/angular
```

---

## デバッグ

### screen.debug()

```tsx
test('debug test', () => {
  render(<Component />)

  // DOM全体を出力
  screen.debug()

  // 特定要素を出力
  const button = screen.getByRole('button')
  screen.debug(button)
})
```

### screen.logTestingPlaygroundURL()

```tsx
test('get testing playground URL', () => {
  render(<Component />)

  // Testing Playground の URL を出力
  screen.logTestingPlaygroundURL()
})
```

---

## 参考リンク

- [Testing Library 公式](https://testing-library.com/)
- [React Testing Library](https://testing-library.com/docs/react-testing-library/intro/)
- [Common mistakes with React Testing Library](https://kentcdodds.com/blog/common-mistakes-with-react-testing-library)
- [Testing Playground](https://testing-playground.com/)
