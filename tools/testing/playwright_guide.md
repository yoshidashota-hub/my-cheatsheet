# Playwright 完全ガイド

## 目次
- [Playwrightとは](#playwrightとは)
- [セットアップ](#セットアップ)
- [基本的なテスト](#基本的なテスト)
- [ロケーター](#ロケーター)
- [アクション](#アクション)
- [アサーション](#アサーション)
- [テストの構造化](#テストの構造化)
- [高度な機能](#高度な機能)

---

## Playwrightとは

Microsoft製のE2E（End-to-End）テストフレームワーク。複数ブラウザでの自動テストをサポート。

### 主な特徴
- 🌐 複数ブラウザ対応（Chromium、Firefox、WebKit）
- ⚡ 高速な実行
- 📱 モバイルエミュレーション
- 🎬 自動待機
- 🔒 信頼性の高いテスト

---

## セットアップ

### インストール

```bash
npm init playwright@latest
```

対話形式で選択：
- TypeScript or JavaScript
- テストディレクトリ名
- GitHub Actions の設定

### 手動インストール

```bash
npm install -D @playwright/test
npx playwright install
```

---

## 基本的なテスト

### シンプルなテスト

```typescript
import { test, expect } from '@playwright/test'

test('basic test', async ({ page }) => {
  await page.goto('https://playwright.dev/')

  const title = await page.title()
  expect(title).toBe('Fast and reliable end-to-end testing for modern web apps | Playwright')

  await expect(page).toHaveTitle(/Playwright/)
})
```

### テスト実行

```bash
# 全テスト実行
npx playwright test

# 特定ファイル
npx playwright test example.spec.ts

# ヘッドモード（ブラウザ表示）
npx playwright test --headed

# デバッグモード
npx playwright test --debug

# UIモード
npx playwright test --ui
```

---

## ロケーター

### 推奨されるロケーター

```typescript
// Role（最優先）
await page.getByRole('button', { name: 'Sign in' })
await page.getByRole('link', { name: 'About' })
await page.getByRole('heading', { level: 1 })

// Label（フォーム）
await page.getByLabel('Email')
await page.getByLabel('Password')

// Placeholder
await page.getByPlaceholder('name@example.com')

// Text
await page.getByText('Welcome')
await page.getByText(/hello/i) // 正規表現

// Test ID
await page.getByTestId('submit-button')
```

### セレクター

```typescript
// CSS セレクター
await page.locator('.submit-button')
await page.locator('#login-form')

// XPath
await page.locator('xpath=//button[@type="submit"]')

// チェーン
await page.locator('article').locator('button')

// フィルター
await page.getByRole('listitem').filter({ hasText: 'Product 2' })

// nth要素
await page.getByRole('listitem').nth(0)
await page.getByRole('listitem').first()
await page.getByRole('listitem').last()
```

---

## アクション

### クリック

```typescript
// 通常のクリック
await page.getByRole('button').click()

// ダブルクリック
await page.getByRole('button').dblclick()

// 右クリック
await page.getByRole('button').click({ button: 'right' })

// Shiftキー押しながら
await page.getByRole('button').click({ modifiers: ['Shift'] })
```

### 入力

```typescript
// テキスト入力
await page.getByLabel('Email').fill('user@example.com')

// キーボード入力（文字ごと）
await page.getByLabel('Email').type('user@example.com')

// キーボード操作
await page.keyboard.press('Enter')
await page.keyboard.press('Control+A')

// クリア
await page.getByLabel('Email').clear()
```

### セレクト

```typescript
// セレクトボックス
await page.selectOption('select#colors', 'blue')
await page.selectOption('select#colors', { label: 'Blue' })
await page.selectOption('select#colors', { index: 2 })

// チェックボックス
await page.getByLabel('I agree').check()
await page.getByLabel('Subscribe').uncheck()

// ラジオボタン
await page.getByLabel('Male').check()
```

### ファイルアップロード

```typescript
await page.getByLabel('Upload file').setInputFiles('path/to/file.pdf')

// 複数ファイル
await page.getByLabel('Upload files').setInputFiles([
  'file1.pdf',
  'file2.pdf'
])

// バッファから
await page.getByLabel('Upload').setInputFiles({
  name: 'file.txt',
  mimeType: 'text/plain',
  buffer: Buffer.from('file content')
})
```

---

## アサーション

### ページアサーション

```typescript
// URL
await expect(page).toHaveURL('https://example.com/login')
await expect(page).toHaveURL(/login/)

// タイトル
await expect(page).toHaveTitle('Login Page')
await expect(page).toHaveTitle(/Login/)
```

### 要素アサーション

```typescript
// 存在確認
await expect(page.getByText('Success')).toBeVisible()
await expect(page.getByText('Hidden')).toBeHidden()
await expect(page.getByRole('button')).toBeEnabled()
await expect(page.getByRole('button')).toBeDisabled()

// テキスト
await expect(page.getByRole('heading')).toHaveText('Welcome')
await expect(page.getByRole('heading')).toContainText('Welcome')

// 属性
await expect(page.getByRole('link')).toHaveAttribute('href', '/about')
await expect(page.getByRole('textbox')).toHaveValue('John')

// CSS
await expect(page.getByRole('button')).toHaveCSS('color', 'rgb(255, 0, 0)')

// カウント
await expect(page.getByRole('listitem')).toHaveCount(3)
```

---

## テストの構造化

### テストグループ

```typescript
import { test, expect } from '@playwright/test'

test.describe('Login', () => {
  test('successful login', async ({ page }) => {
    // ...
  })

  test('failed login', async ({ page }) => {
    // ...
  })
})
```

### beforeEach / afterEach

```typescript
test.describe('Blog', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('https://example.com/blog')
  })

  test.afterEach(async ({ page }) => {
    await page.close()
  })

  test('first post', async ({ page }) => {
    // ...
  })
})
```

### フィクスチャー

```typescript
import { test as base } from '@playwright/test'

type MyFixtures = {
  todoPage: TodoPage
}

const test = base.extend<MyFixtures>({
  todoPage: async ({ page }, use) => {
    const todoPage = new TodoPage(page)
    await todoPage.goto()
    await use(todoPage)
  }
})

test('add todo', async ({ todoPage }) => {
  await todoPage.addTodo('Buy milk')
  await expect(todoPage.todos).toHaveCount(1)
})
```

---

## 高度な機能

### Page Object Model

```typescript
// pages/LoginPage.ts
export class LoginPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto('/login')
  }

  async login(email: string, password: string) {
    await this.page.getByLabel('Email').fill(email)
    await this.page.getByLabel('Password').fill(password)
    await this.page.getByRole('button', { name: 'Sign in' }).click()
  }

  async getErrorMessage() {
    return await this.page.getByRole('alert').textContent()
  }
}

// tests/login.spec.ts
test('login with invalid credentials', async ({ page }) => {
  const loginPage = new LoginPage(page)
  await loginPage.goto()
  await loginPage.login('invalid@example.com', 'wrongpassword')

  const error = await loginPage.getErrorMessage()
  expect(error).toContain('Invalid credentials')
})
```

### スクリーンショット

```typescript
// ページ全体
await page.screenshot({ path: 'screenshot.png' })

// 特定要素
await page.getByRole('button').screenshot({ path: 'button.png' })

// フルページ
await page.screenshot({ path: 'full.png', fullPage: true })
```

### ビデオ録画

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    video: 'on-first-retry'
  }
})
```

### ネットワークモック

```typescript
await page.route('**/api/users', async route => {
  await route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify([
      { id: 1, name: 'John' },
      { id: 2, name: 'Jane' }
    ])
  })
})

await page.goto('/users')
```

---

## 設定

### playwright.config.ts

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure'
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] }
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] }
    }
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI
  }
})
```

---

## 参考リンク

- [Playwright 公式ドキュメント](https://playwright.dev/)
- [Best Practices](https://playwright.dev/docs/best-practices)
