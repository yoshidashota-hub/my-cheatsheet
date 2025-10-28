# 国際化（i18n）ガイド

アプリケーションの多言語対応を実装するための主要ライブラリと実装方法をまとめたガイドです。

## ライブラリ比較

| ライブラリ | フレームワーク | サイズ | 型安全性 | 動的ロード | SSR対応 |
|-----------|--------------|--------|---------|-----------|---------|
| **next-intl** | Next.js専用 | 軽量 | ✓ | ✓ | ✓ |
| **i18next** | フレームワーク非依存 | 中量 | △ | ✓ | ✓ |
| **react-intl** | React | 中量 | ✓ | ✓ | ✓ |
| **LinguiJS** | React | 軽量 | ✓ | ✓ | ✓ |

### 選択基準

- **next-intl**: Next.js App Router使用時の最適解
- **i18next**: 多機能、フレームワーク非依存
- **react-intl**: Format.js統合、ICUメッセージフォーマット
- **LinguiJS**: 軽量、開発体験重視

## next-intl (Next.js)

### 特徴

- **Next.js専用**: App Routerに最適化
- **型安全**: TypeScriptサポート
- **Server Components**: サーバーサイドで翻訳
- **軽量**: 必要な翻訳のみロード

### インストール

```bash
npm install next-intl
```

### プロジェクト構造

```text
app/
├── [locale]/
│   ├── layout.tsx
│   ├── page.tsx
│   └── about/
│       └── page.tsx
├── api/
└── ...
messages/
├── en.json
├── ja.json
└── zh.json
i18n.ts
middleware.ts
```

### 設定

```typescript
// i18n.ts
import { getRequestConfig } from 'next-intl/server'

export default getRequestConfig(async ({ locale }) => ({
  messages: (await import(`./messages/${locale}.json`)).default,
}))
```

```typescript
// middleware.ts
import createMiddleware from 'next-intl/middleware'

export default createMiddleware({
  locales: ['en', 'ja', 'zh'],
  defaultLocale: 'ja',
})

export const config = {
  matcher: ['/((?!api|_next|.*\\..*).*)'],
}
```

### 翻訳ファイル

```json
// messages/ja.json
{
  "common": {
    "welcome": "ようこそ",
    "signIn": "ログイン",
    "signOut": "ログアウト"
  },
  "home": {
    "title": "ホーム",
    "description": "私たちのアプリケーションへようこそ"
  },
  "user": {
    "profile": "{name}さんのプロフィール",
    "greeting": "こんにちは、{name}さん！",
    "itemsCount": "{count, plural, =0 {アイテムがありません} =1 {1つのアイテム} other {#個のアイテム}}"
  }
}
```

```json
// messages/en.json
{
  "common": {
    "welcome": "Welcome",
    "signIn": "Sign In",
    "signOut": "Sign Out"
  },
  "home": {
    "title": "Home",
    "description": "Welcome to our application"
  },
  "user": {
    "profile": "{name}'s Profile",
    "greeting": "Hello, {name}!",
    "itemsCount": "{count, plural, =0 {No items} =1 {1 item} other {# items}}"
  }
}
```

### Layout設定

```typescript
// app/[locale]/layout.tsx
import { NextIntlClientProvider } from 'next-intl'
import { getMessages } from 'next-intl/server'

export default async function LocaleLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode
  params: { locale: string }
}) {
  const messages = await getMessages()

  return (
    <html lang={locale}>
      <body>
        <NextIntlClientProvider messages={messages}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  )
}
```

### Server Component

```typescript
// app/[locale]/page.tsx
import { useTranslations } from 'next-intl'

export default function HomePage() {
  const t = useTranslations('home')

  return (
    <div>
      <h1>{t('title')}</h1>
      <p>{t('description')}</p>
    </div>
  )
}
```

### Client Component

```typescript
'use client'

import { useTranslations } from 'next-intl'

export default function UserGreeting({ name }: { name: string }) {
  const t = useTranslations('user')

  return (
    <div>
      <h2>{t('greeting', { name })}</h2>
      <p>{t('profile', { name })}</p>
    </div>
  )
}
```

### 日付・数値フォーマット

```typescript
import { useFormatter } from 'next-intl'

export default function FormattingExample() {
  const format = useFormatter()

  const date = new Date('2024-12-25')
  const number = 1234567.89
  const currency = 9800

  return (
    <div>
      {/* 日付 */}
      <p>{format.dateTime(date, { dateStyle: 'full' })}</p>
      {/* => 2024年12月25日水曜日 (ja) */}
      {/* => Wednesday, December 25, 2024 (en) */}

      <p>{format.dateTime(date, { year: 'numeric', month: 'long', day: 'numeric' })}</p>
      {/* => 2024年12月25日 (ja) */}

      {/* 数値 */}
      <p>{format.number(number)}</p>
      {/* => 1,234,567.89 */}

      {/* 通貨 */}
      <p>{format.number(currency, { style: 'currency', currency: 'JPY' })}</p>
      {/* => ¥9,800 (ja) */}
      <p>{format.number(currency, { style: 'currency', currency: 'USD' })}</p>
      {/* => $9,800.00 (en) */}

      {/* 相対時間 */}
      <p>{format.relativeTime(date)}</p>
      {/* => 2ヶ月後 */}
    </div>
  )
}
```

### 複数形

```typescript
import { useTranslations } from 'next-intl'

export default function ItemsList({ count }: { count: number }) {
  const t = useTranslations('user')

  return <p>{t('itemsCount', { count })}</p>
}

// count = 0 => "アイテムがありません"
// count = 1 => "1つのアイテム"
// count = 5 => "5個のアイテム"
```

### 言語切り替え

```typescript
'use client'

import { useParams, usePathname, useRouter } from 'next/navigation'

export default function LanguageSwitcher() {
  const params = useParams()
  const pathname = usePathname()
  const router = useRouter()

  const currentLocale = params.locale as string
  const locales = ['ja', 'en', 'zh']

  const switchLocale = (locale: string) => {
    const newPath = pathname.replace(`/${currentLocale}`, `/${locale}`)
    router.push(newPath)
  }

  return (
    <select value={currentLocale} onChange={(e) => switchLocale(e.target.value)}>
      {locales.map((locale) => (
        <option key={locale} value={locale}>
          {locale === 'ja' ? '日本語' : locale === 'en' ? 'English' : '中文'}
        </option>
      ))}
    </select>
  )
}
```

## i18next + react-i18next

### 特徴

- **フレームワーク非依存**: React以外でも使用可能
- **プラグイン**: 豊富なプラグインエコシステム
- **動的ロード**: 翻訳ファイルの遅延ロード
- **バックエンド対応**: Node.jsでも使用可能

### インストール

```bash
npm install i18next react-i18next i18next-http-backend
```

### 設定

```typescript
// i18n/config.ts
import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import HttpBackend from 'i18next-http-backend'

i18n
  .use(HttpBackend)
  .use(initReactI18next)
  .init({
    fallbackLng: 'ja',
    supportedLngs: ['ja', 'en', 'zh'],
    debug: process.env.NODE_ENV === 'development',

    backend: {
      loadPath: '/locales/{{lng}}/{{ns}}.json',
    },

    ns: ['common', 'home', 'user'],
    defaultNS: 'common',

    interpolation: {
      escapeValue: false,
    },
  })

export default i18n
```

### アプリケーションに適用

```typescript
// app/layout.tsx
'use client'

import { I18nextProvider } from 'react-i18next'
import i18n from '@/i18n/config'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        <I18nextProvider i18n={i18n}>
          {children}
        </I18nextProvider>
      </body>
    </html>
  )
}
```

### 使用例

```typescript
'use client'

import { useTranslation } from 'react-i18next'

export default function HomePage() {
  const { t, i18n } = useTranslation(['common', 'home'])

  const changeLanguage = (lng: string) => {
    i18n.changeLanguage(lng)
  }

  return (
    <div>
      <h1>{t('home:title')}</h1>
      <p>{t('home:description')}</p>
      <button onClick={() => changeLanguage('en')}>English</button>
      <button onClick={() => changeLanguage('ja')}>日本語</button>
    </div>
  )
}
```

### フォーマット

```typescript
import { useTranslation } from 'react-i18next'

export default function FormattingExample() {
  const { t } = useTranslation()

  const date = new Date('2024-12-25')
  const number = 1234567.89

  return (
    <div>
      {/* 日付フォーマット（i18next-backend使用） */}
      <p>{t('date', { date, formatParams: { date: { year: 'numeric', month: 'long', day: 'numeric' } } })}</p>

      {/* 数値フォーマット */}
      <p>{t('number', { number, formatParams: { number: { minimumFractionDigits: 2 } } })}</p>
    </div>
  )
}
```

## react-intl (Format.js)

### 特徴

- **ICUメッセージフォーマット**: 強力なメッセージ構文
- **コンポーネントベース**: Reactコンポーネントで使用
- **Format.js**: Yahoo製の国際化ライブラリ
- **型安全**: TypeScript対応

### インストール

```bash
npm install react-intl
```

### 設定

```typescript
// app/layout.tsx
'use client'

import { IntlProvider } from 'react-intl'
import { useState } from 'react'

import jaMessages from '@/messages/ja.json'
import enMessages from '@/messages/en.json'

const messages = {
  ja: jaMessages,
  en: enMessages,
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const [locale, setLocale] = useState('ja')

  return (
    <html lang={locale}>
      <body>
        <IntlProvider messages={messages[locale]} locale={locale} defaultLocale="ja">
          {children}
        </IntlProvider>
      </body>
    </html>
  )
}
```

### 使用例

```typescript
'use client'

import { FormattedMessage, useIntl } from 'react-intl'

export default function HomePage() {
  const intl = useIntl()

  return (
    <div>
      {/* コンポーネントで使用 */}
      <h1>
        <FormattedMessage id="home.title" />
      </h1>

      {/* フック経由 */}
      <p>{intl.formatMessage({ id: 'home.description' })}</p>

      {/* パラメータ付き */}
      <p>
        <FormattedMessage id="user.greeting" values={{ name: '太郎' }} />
      </p>
    </div>
  )
}
```

### フォーマット

```typescript
import { FormattedDate, FormattedNumber, FormattedTime, FormattedRelativeTime } from 'react-intl'

export default function FormattingExample() {
  const date = new Date('2024-12-25')
  const number = 1234567.89

  return (
    <div>
      {/* 日付 */}
      <p>
        <FormattedDate value={date} year="numeric" month="long" day="numeric" />
      </p>
      {/* => 2024年12月25日 */}

      {/* 時刻 */}
      <p>
        <FormattedTime value={date} />
      </p>

      {/* 数値 */}
      <p>
        <FormattedNumber value={number} />
      </p>
      {/* => 1,234,567.89 */}

      {/* 通貨 */}
      <p>
        <FormattedNumber value={9800} style="currency" currency="JPY" />
      </p>
      {/* => ¥9,800 */}

      {/* 相対時間 */}
      <p>
        <FormattedRelativeTime value={-1} unit="day" />
      </p>
      {/* => 1日前 */}
    </div>
  )
}
```

## ベストプラクティス

### 1. 翻訳キーの命名規則

```json
{
  "namespace.component.element": "翻訳テキスト",
  "common.button.submit": "送信",
  "home.hero.title": "ようこそ",
  "user.profile.edit": "プロフィールを編集"
}
```

### 2. 翻訳の分割

```text
messages/
├── ja/
│   ├── common.json
│   ├── home.json
│   ├── user.json
│   └── errors.json
└── en/
    ├── common.json
    ├── home.json
    ├── user.json
    └── errors.json
```

### 3. 型安全な翻訳

```typescript
// types/i18n.ts
import jaMessages from '@/messages/ja.json'

type Messages = typeof jaMessages

declare global {
  interface IntlMessages extends Messages {}
}
```

### 4. デフォルト翻訳

```typescript
// 翻訳が見つからない場合のフォールバック
const t = useTranslations()

// デフォルト値を指定
t('key.that.might.not.exist', { defaultValue: 'Default text' })
```

### 5. SEO対策

```typescript
// app/[locale]/page.tsx
import { getTranslations } from 'next-intl/server'

export async function generateMetadata({ params: { locale } }) {
  const t = await getTranslations({ locale, namespace: 'home' })

  return {
    title: t('title'),
    description: t('description'),
  }
}
```

### 6. 日付・時刻のタイムゾーン

```typescript
import { useFormatter } from 'next-intl'

export default function TimeDisplay() {
  const format = useFormatter()
  const date = new Date()

  return (
    <p>
      {format.dateTime(date, {
        timeZone: 'Asia/Tokyo',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })}
    </p>
  )
}
```

## 翻訳管理

### Crowdin統合

```yaml
# crowdin.yml
project_id: 'your-project-id'
api_token_env: CROWDIN_API_TOKEN
preserve_hierarchy: true

files:
  - source: '/messages/en/**/*.json'
    translation: '/messages/%two_letters_code%/**/%original_file_name%'
```

### 翻訳の自動チェック

```typescript
// scripts/check-translations.ts
import fs from 'fs'
import path from 'path'

function checkTranslations() {
  const locales = ['ja', 'en', 'zh']
  const baseLocale = 'ja'

  const baseMessages = JSON.parse(
    fs.readFileSync(path.join('messages', `${baseLocale}.json`), 'utf-8')
  )

  locales.forEach((locale) => {
    if (locale === baseLocale) return

    const messages = JSON.parse(
      fs.readFileSync(path.join('messages', `${locale}.json`), 'utf-8')
    )

    // 不足しているキーをチェック
    checkMissingKeys(baseMessages, messages, locale)
  })
}

function checkMissingKeys(base: any, target: any, locale: string, prefix = '') {
  Object.keys(base).forEach((key) => {
    const fullKey = prefix ? `${prefix}.${key}` : key

    if (!(key in target)) {
      console.warn(`Missing translation for "${fullKey}" in ${locale}`)
    } else if (typeof base[key] === 'object') {
      checkMissingKeys(base[key], target[key], locale, fullKey)
    }
  })
}

checkTranslations()
```

## 参考リンク

- [next-intl 公式ドキュメント](https://next-intl-docs.vercel.app/)
- [i18next 公式ドキュメント](https://www.i18next.com/)
- [react-intl 公式ドキュメント](https://formatjs.io/docs/react-intl/)
- [Unicode CLDR](https://cldr.unicode.org/)
