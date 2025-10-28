# 日付・時刻処理ライブラリガイド

JavaScriptの日付処理は標準の`Date`オブジェクトでは不十分なため、専用ライブラリの使用が推奨されます。

## ライブラリ比較

| ライブラリ | サイズ | 不変性 | タイムゾーン | Tree-shaking | 人気度 |
|-----------|--------|--------|------------|--------------|--------|
| **Day.js** | 2KB | ✓ | プラグイン | ✓ | ⭐⭐⭐⭐⭐ |
| **date-fns** | 13KB | ✓ | ✓ (v2.28+) | ✓ | ⭐⭐⭐⭐⭐ |
| **Luxon** | 15KB | ✓ | ✓ | ✗ | ⭐⭐⭐⭐ |
| **Moment.js** | 67KB | ✗ | ✓ | ✗ | 🚫 非推奨 |

### 選択基準

- **Day.js**: 軽量最優先、Moment.js互換API
- **date-fns**: 関数型、Tree-shaking重視
- **Luxon**: 高機能、国際化重視

## Day.js

### 特徴

- **超軽量**: 2KB（gzip圧縮後）
- **Moment.js互換**: APIが似ている
- **プラグイン**: 必要な機能だけ追加
- **不変性**: 元のオブジェクトを変更しない

### インストール

```bash
npm install dayjs
```

### 基本的な使い方

```typescript
import dayjs from 'dayjs'

// 現在日時
const now = dayjs()
console.log(now.format('YYYY-MM-DD HH:mm:ss'))
// => 2024-10-28 14:30:00

// 文字列から作成
const date = dayjs('2024-12-25')
console.log(date.format('YYYY年MM月DD日'))
// => 2024年12月25日

// Dateオブジェクトから作成
const fromDate = dayjs(new Date())

// Unix タイムスタンプから作成
const fromUnix = dayjs.unix(1672531200)

// ISO 8601形式
const iso = dayjs('2024-12-25T10:30:00+09:00')
```

### フォーマット

```typescript
import dayjs from 'dayjs'

const date = dayjs('2024-12-25 14:30:00')

// 基本フォーマット
date.format('YYYY-MM-DD') // => 2024-12-25
date.format('YYYY/MM/DD') // => 2024/12/25
date.format('YYYY年MM月DD日') // => 2024年12月25日
date.format('HH:mm:ss') // => 14:30:00
date.format('hh:mm A') // => 02:30 PM

// ISO 8601
date.toISOString() // => 2024-12-25T14:30:00.000Z

// Unix タイムスタンプ
date.unix() // => 1735106400
date.valueOf() // => 1735106400000 (ミリ秒)
```

### 操作（加算・減算）

```typescript
import dayjs from 'dayjs'

const date = dayjs('2024-12-25')

// 加算
date.add(1, 'day') // => 2024-12-26
date.add(1, 'week') // => 2025-01-01
date.add(1, 'month') // => 2025-01-25
date.add(1, 'year') // => 2025-12-25
date.add(2, 'hour') // => 2024-12-25 02:00:00

// 減算
date.subtract(1, 'day') // => 2024-12-24
date.subtract(1, 'week') // => 2024-12-18

// チェーン
date.add(1, 'month').subtract(1, 'day') // => 2025-01-24

// 設定
date.set('year', 2025) // => 2025-12-25
date.set('month', 0) // => 2024-01-25 (0 = January)
date.set('date', 1) // => 2024-12-01
date.set('hour', 12) // => 2024-12-25 12:00:00
```

### 比較

```typescript
import dayjs from 'dayjs'

const date1 = dayjs('2024-12-25')
const date2 = dayjs('2024-12-26')

// 比較
date1.isBefore(date2) // => true
date1.isAfter(date2) // => false
date1.isSame(date2) // => false
date1.isSame(date2, 'month') // => true (同じ月)
date1.isSame(date2, 'year') // => true (同じ年)

// 範囲チェック
date1.isBetween('2024-12-01', '2024-12-31') // => true

// 差分
date2.diff(date1, 'day') // => 1
date2.diff(date1, 'hour') // => 24
```

### 取得

```typescript
import dayjs from 'dayjs'

const date = dayjs('2024-12-25 14:30:00')

// 個別の値を取得
date.year() // => 2024
date.month() // => 11 (0-11, 0 = January)
date.date() // => 25
date.day() // => 3 (0-6, 0 = Sunday)
date.hour() // => 14
date.minute() // => 30
date.second() // => 0

// 月初・月末
date.startOf('month') // => 2024-12-01 00:00:00
date.endOf('month') // => 2024-12-31 23:59:59

// 週初・週末
date.startOf('week') // => 2024-12-22 00:00:00 (日曜日)
date.endOf('week') // => 2024-12-28 23:59:59 (土曜日)

// 日初・日終
date.startOf('day') // => 2024-12-25 00:00:00
date.endOf('day') // => 2024-12-25 23:59:59
```

### プラグイン

```typescript
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'
import relativeTime from 'dayjs/plugin/relativeTime'
import isSameOrBefore from 'dayjs/plugin/isSameOrBefore'
import isSameOrAfter from 'dayjs/plugin/isSameOrAfter'
import 'dayjs/locale/ja'

// プラグイン有効化
dayjs.extend(utc)
dayjs.extend(timezone)
dayjs.extend(relativeTime)
dayjs.extend(isSameOrBefore)
dayjs.extend(isSameOrAfter)
dayjs.locale('ja')

// UTC
const utcDate = dayjs.utc('2024-12-25')
console.log(utcDate.format()) // => 2024-12-25T00:00:00Z

// タイムゾーン
const tokyo = dayjs.tz('2024-12-25 10:00:00', 'Asia/Tokyo')
console.log(tokyo.format()) // => 2024-12-25T10:00:00+09:00

const newYork = tokyo.tz('America/New_York')
console.log(newYork.format()) // => 2024-12-24T20:00:00-05:00

// 相対時間
dayjs().from(dayjs('2024-12-25')) // => 2ヶ月前
dayjs('2024-12-25').fromNow() // => 2ヶ月後

// 比較拡張
date.isSameOrBefore(date2) // => true
date.isSameOrAfter(date2) // => false
```

### 実践例

```typescript
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'

dayjs.extend(utc)
dayjs.extend(timezone)

// 営業日計算（土日を除く）
function addBusinessDays(date: string, days: number): string {
  let result = dayjs(date)
  let count = 0

  while (count < days) {
    result = result.add(1, 'day')
    // 土曜日(6)と日曜日(0)を除外
    if (result.day() !== 0 && result.day() !== 6) {
      count++
    }
  }

  return result.format('YYYY-MM-DD')
}

console.log(addBusinessDays('2024-12-25', 5))
// => 2025-01-02 (土日を除いて5営業日後)

// 期間の日数計算
function daysBetween(start: string, end: string): number {
  return dayjs(end).diff(dayjs(start), 'day')
}

// 年齢計算
function calculateAge(birthDate: string): number {
  const today = dayjs()
  const birth = dayjs(birthDate)
  return today.diff(birth, 'year')
}

// タイムゾーン変換
function convertTimezone(
  dateTime: string,
  fromTz: string,
  toTz: string
): string {
  return dayjs.tz(dateTime, fromTz).tz(toTz).format('YYYY-MM-DD HH:mm:ss')
}

console.log(
  convertTimezone('2024-12-25 10:00:00', 'Asia/Tokyo', 'America/New_York')
)
// => 2024-12-24 20:00:00
```

## date-fns

### 特徴

- **関数型**: 純粋関数のコレクション
- **Tree-shaking**: 使った関数だけバンドル
- **TypeScript**: 完全な型サポート
- **不変性**: 元のDateを変更しない

### インストール

```bash
npm install date-fns
```

### 基本的な使い方

```typescript
import {
  format,
  parseISO,
  parse,
  addDays,
  subDays,
  differenceInDays,
  isAfter,
  isBefore,
  startOfMonth,
  endOfMonth,
} from 'date-fns'

// フォーマット
const date = new Date('2024-12-25')
format(date, 'yyyy-MM-dd') // => 2024-12-25
format(date, 'yyyy年MM月dd日') // => 2024年12月25日
format(date, 'HH:mm:ss') // => 00:00:00

// パース
const parsed = parseISO('2024-12-25T10:30:00')
const customParsed = parse('25/12/2024', 'dd/MM/yyyy', new Date())

// 加算・減算
addDays(date, 5) // => 2024-12-30
subDays(date, 5) // => 2024-12-20

// 差分
differenceInDays(new Date('2024-12-26'), date) // => 1

// 比較
isAfter(new Date('2024-12-26'), date) // => true
isBefore(new Date('2024-12-24'), date) // => true

// 月初・月末
startOfMonth(date) // => 2024-12-01 00:00:00
endOfMonth(date) // => 2024-12-31 23:59:59
```

### 多様なフォーマット

```typescript
import { format } from 'date-fns'
import { ja } from 'date-fns/locale'

const date = new Date('2024-12-25 14:30:00')

// 基本
format(date, 'yyyy-MM-dd') // => 2024-12-25
format(date, 'yyyy/MM/dd') // => 2024/12/25
format(date, 'MM/dd/yyyy') // => 12/25/2024

// 時刻
format(date, 'HH:mm:ss') // => 14:30:00
format(date, 'hh:mm a') // => 02:30 pm

// 日本語
format(date, 'yyyy年MM月dd日', { locale: ja }) // => 2024年12月25日
format(date, 'M月d日(E)', { locale: ja }) // => 12月25日(水)

// カスタム
format(date, "yyyy年MM月dd日 HH時mm分ss秒") // => 2024年12月25日 14時30分00秒
```

### 操作

```typescript
import {
  addYears,
  addMonths,
  addWeeks,
  addDays,
  addHours,
  addMinutes,
  subYears,
  subMonths,
  set,
} from 'date-fns'

const date = new Date('2024-12-25')

// 加算
addYears(date, 1) // => 2025-12-25
addMonths(date, 1) // => 2025-01-25
addWeeks(date, 1) // => 2025-01-01
addDays(date, 1) // => 2024-12-26
addHours(date, 2) // => 2024-12-25 02:00:00

// 減算
subYears(date, 1) // => 2023-12-25
subMonths(date, 1) // => 2024-11-25

// 設定
set(date, { year: 2025 }) // => 2025-12-25
set(date, { month: 0, date: 1 }) // => 2024-01-01
set(date, { hours: 12, minutes: 30 }) // => 2024-12-25 12:30:00
```

### 比較と検証

```typescript
import {
  isAfter,
  isBefore,
  isEqual,
  isSameDay,
  isSameMonth,
  isWithinInterval,
  isWeekend,
  isPast,
  isFuture,
  isValid,
} from 'date-fns'

const date1 = new Date('2024-12-25')
const date2 = new Date('2024-12-26')

// 比較
isAfter(date2, date1) // => true
isBefore(date1, date2) // => true
isEqual(date1, date1) // => true
isSameDay(date1, date2) // => false
isSameMonth(date1, date2) // => true

// 範囲チェック
isWithinInterval(date1, {
  start: new Date('2024-12-01'),
  end: new Date('2024-12-31'),
}) // => true

// その他
isWeekend(date1) // => false (水曜日)
isPast(date1) // => false (未来)
isFuture(date1) // => true
isValid(new Date('invalid')) // => false
```

### タイムゾーン処理

```typescript
import { format, toZonedTime, fromZonedTime } from 'date-fns-tz'

// タイムゾーン変換
const date = new Date('2024-12-25T10:00:00')
const tokyo = toZonedTime(date, 'Asia/Tokyo')
const newYork = toZonedTime(date, 'America/New_York')

console.log(format(tokyo, 'yyyy-MM-dd HH:mm:ssXXX', { timeZone: 'Asia/Tokyo' }))
// => 2024-12-25 10:00:00+09:00

console.log(format(newYork, 'yyyy-MM-dd HH:mm:ssXXX', { timeZone: 'America/New_York' }))
// => 2024-12-24 20:00:00-05:00

// タイムゾーンから戻す
const backToUTC = fromZonedTime(tokyo, 'Asia/Tokyo')
```

### 実践例

```typescript
import {
  format,
  addDays,
  differenceInDays,
  differenceInYears,
  startOfMonth,
  endOfMonth,
  eachDayOfInterval,
  isWeekend,
} from 'date-fns'
import { ja } from 'date-fns/locale'

// 営業日計算
function addBusinessDays(date: Date, days: number): Date {
  let result = date
  let count = 0

  while (count < days) {
    result = addDays(result, 1)
    if (!isWeekend(result)) {
      count++
    }
  }

  return result
}

// 年齢計算
function calculateAge(birthDate: Date): number {
  return differenceInYears(new Date(), birthDate)
}

// 期間内の全日付を取得
function getDatesInRange(start: Date, end: Date): Date[] {
  return eachDayOfInterval({ start, end })
}

// カレンダー生成
function generateMonthCalendar(year: number, month: number) {
  const start = startOfMonth(new Date(year, month, 1))
  const end = endOfMonth(start)
  const days = eachDayOfInterval({ start, end })

  return days.map((day) => ({
    date: format(day, 'yyyy-MM-dd'),
    dayOfWeek: format(day, 'E', { locale: ja }),
    isWeekend: isWeekend(day),
  }))
}

console.log(generateMonthCalendar(2024, 11)) // 2024年12月
```

## Luxon

### 特徴

- **高機能**: 最も豊富な機能
- **国際化**: 優れた多言語サポート
- **タイムゾーン**: ネイティブサポート
- **不変性**: Immutableオブジェクト

### インストール

```bash
npm install luxon
```

### 基本的な使い方

```typescript
import { DateTime } from 'luxon'

// 現在日時
const now = DateTime.now()
console.log(now.toISO()) // => 2024-10-28T14:30:00.000+09:00

// 文字列から作成
const date = DateTime.fromISO('2024-12-25')
console.log(date.toFormat('yyyy-MM-dd')) // => 2024-12-25

// オブジェクトから作成
const fromObject = DateTime.fromObject({
  year: 2024,
  month: 12,
  day: 25,
  hour: 14,
  minute: 30,
})

// SQL形式
const fromSQL = DateTime.fromSQL('2024-12-25 14:30:00')

// Unix タイムスタンプ
const fromUnix = DateTime.fromSeconds(1672531200)
```

### フォーマット

```typescript
import { DateTime } from 'luxon'

const date = DateTime.fromISO('2024-12-25T14:30:00')

// カスタムフォーマット
date.toFormat('yyyy-MM-dd') // => 2024-12-25
date.toFormat('yyyy年MM月dd日') // => 2024年12月25日
date.toFormat('HH:mm:ss') // => 14:30:00

// ISO 8601
date.toISO() // => 2024-12-25T14:30:00.000+09:00

// SQL形式
date.toSQL() // => 2024-12-25 14:30:00.000

// Unix タイムスタンプ
date.toSeconds() // => 1735106400
date.toMillis() // => 1735106400000

// ロケール対応
date.setLocale('ja').toLocaleString(DateTime.DATE_FULL)
// => 2024年12月25日水曜日
```

### 操作

```typescript
import { DateTime } from 'luxon'

const date = DateTime.fromISO('2024-12-25')

// 加算
date.plus({ days: 1 }) // => 2024-12-26
date.plus({ weeks: 1 }) // => 2025-01-01
date.plus({ months: 1 }) // => 2025-01-25
date.plus({ years: 1 }) // => 2025-12-25
date.plus({ hours: 2 }) // => 2024-12-25 02:00:00

// 減算
date.minus({ days: 1 }) // => 2024-12-24
date.minus({ weeks: 1 }) // => 2024-12-18

// 設定
date.set({ year: 2025 }) // => 2025-12-25
date.set({ month: 1, day: 1 }) // => 2024-01-01
date.set({ hour: 12, minute: 30 }) // => 2024-12-25 12:30:00

// 月初・月末
date.startOf('month') // => 2024-12-01 00:00:00
date.endOf('month') // => 2024-12-31 23:59:59
```

### タイムゾーン

```typescript
import { DateTime } from 'luxon'

// タイムゾーン指定
const tokyo = DateTime.fromISO('2024-12-25T10:00:00', {
  zone: 'Asia/Tokyo',
})
console.log(tokyo.toISO()) // => 2024-12-25T10:00:00.000+09:00

// タイムゾーン変換
const newYork = tokyo.setZone('America/New_York')
console.log(newYork.toISO()) // => 2024-12-24T20:00:00.000-05:00

// UTC
const utc = tokyo.toUTC()
console.log(utc.toISO()) // => 2024-12-25T01:00:00.000Z

// ローカルタイムゾーン
const local = tokyo.toLocal()
```

### 国際化

```typescript
import { DateTime } from 'luxon'

const date = DateTime.fromISO('2024-12-25T14:30:00')

// 日本語
date.setLocale('ja').toLocaleString(DateTime.DATE_FULL)
// => 2024年12月25日水曜日

date.setLocale('ja').toLocaleString(DateTime.DATETIME_FULL)
// => 2024年12月25日水曜日 14:30:00 JST

// 英語
date.setLocale('en').toLocaleString(DateTime.DATE_FULL)
// => Wednesday, December 25, 2024

// 相対時間
date.setLocale('ja').toRelative()
// => 2ヶ月後

date.setLocale('ja').toRelativeCalendar()
// => 来月
```

## Next.js での実装例

### API Route

```typescript
// app/api/schedule/route.ts
import { NextRequest, NextResponse } from 'next/server'
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'

dayjs.extend(utc)
dayjs.extend(timezone)

export async function POST(request: NextRequest) {
  const { datetime, timezone: tz } = await request.json()

  // タイムゾーン変換
  const converted = dayjs.tz(datetime, tz).tz('UTC')

  return NextResponse.json({
    original: datetime,
    timezone: tz,
    utc: converted.toISOString(),
    formatted: converted.format('YYYY-MM-DD HH:mm:ss'),
  })
}
```

### Server Component

```typescript
// app/schedule/page.tsx
import dayjs from 'dayjs'
import 'dayjs/locale/ja'

dayjs.locale('ja')

export default async function SchedulePage() {
  const today = dayjs()
  const events = await getEvents() // データ取得

  return (
    <div>
      <h1>スケジュール - {today.format('YYYY年MM月DD日(dd)')}</h1>
      <ul>
        {events.map((event) => (
          <li key={event.id}>
            <span>{dayjs(event.datetime).format('HH:mm')}</span>
            <span>{event.title}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

### Client Component

```typescript
'use client'

import { useState } from 'react'
import dayjs from 'dayjs'

export default function DatePicker() {
  const [selectedDate, setSelectedDate] = useState(dayjs())

  const handlePrevMonth = () => {
    setSelectedDate(selectedDate.subtract(1, 'month'))
  }

  const handleNextMonth = () => {
    setSelectedDate(selectedDate.add(1, 'month'))
  }

  return (
    <div>
      <div>
        <button onClick={handlePrevMonth}>前月</button>
        <span>{selectedDate.format('YYYY年MM月')}</span>
        <button onClick={handleNextMonth}>次月</button>
      </div>
      {/* カレンダー表示 */}
    </div>
  )
}
```

## ベストプラクティス

### 1. 不変性を保つ

```typescript
// 悪い例: Dateオブジェクトを直接変更
const date = new Date()
date.setDate(date.getDate() + 1) // 元のオブジェクトが変更される

// 良い例: Day.js/date-fns/Luxonを使用
const date = dayjs()
const tomorrow = date.add(1, 'day') // 新しいオブジェクトを返す
```

### 2. タイムゾーンを明示

```typescript
import dayjs from 'dayjs'
import timezone from 'dayjs/plugin/timezone'

dayjs.extend(timezone)

// 明示的にタイムゾーンを指定
const tokyo = dayjs.tz('2024-12-25 10:00:00', 'Asia/Tokyo')
```

### 3. ISO 8601形式を使用

```typescript
// データベースやAPIでは ISO 8601 形式を使用
const isoString = dayjs().toISOString()
// => 2024-10-28T14:30:00.000Z

// パース時も ISO 形式を推奨
const parsed = dayjs('2024-12-25T10:00:00+09:00')
```

### 4. ユーザーのタイムゾーンを考慮

```typescript
// ユーザーのタイムゾーンを取得
const userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone

// タイムゾーンを考慮した表示
const displayDate = dayjs.utc(serverDate).tz(userTimezone).format('YYYY-MM-DD HH:mm')
```

### 5. 日付の検証

```typescript
import { isValid, parseISO } from 'date-fns'

function validateDate(dateString: string): boolean {
  try {
    const date = parseISO(dateString)
    return isValid(date)
  } catch {
    return false
  }
}
```

## 参考リンク

- [Day.js 公式ドキュメント](https://day.js.org/)
- [date-fns 公式ドキュメント](https://date-fns.org/)
- [Luxon 公式ドキュメント](https://moment.github.io/luxon/)
- [You Don't Need Moment.js](https://github.com/you-dont-need/You-Dont-Need-Momentjs)
