# 日付ライブラリ完全ガイド (date-fns / Day.js)

## 目次
- [概要](#概要)
- [date-fns](#date-fns)
- [Day.js](#dayjs)
- [比較](#比較)
- [タイムゾーン](#タイムゾーン)
- [フォーマット](#フォーマット)

---

## 概要

JavaScriptの日付操作を簡単にするライブラリ。

### 主要ライブラリ
- **date-fns**: 関数型、Tree-shaking対応、軽量
- **Day.js**: Moment.js互換API、2KB
- ~~Moment.js~~: レガシー（非推奨）

---

## date-fns

モダンで関数型の日付ライブラリ。必要な関数のみインポート可能。

### インストール

```bash
npm install date-fns
```

### 基本的な使い方

```typescript
import { format, parseISO, addDays, subDays, differenceInDays } from 'date-fns'
import { ja } from 'date-fns/locale'

// 現在日時
const now = new Date()

// フォーマット
format(now, 'yyyy-MM-dd') // "2024-01-15"
format(now, 'yyyy年MM月dd日', { locale: ja }) // "2024年01月15日"
format(now, 'HH:mm:ss') // "14:30:45"

// パース
const date = parseISO('2024-01-15')
const date2 = new Date('2024-01-15')

// 日付操作
const tomorrow = addDays(now, 1)
const yesterday = subDays(now, 1)
const nextWeek = addDays(now, 7)

// 差分計算
const diff = differenceInDays(new Date('2024-12-31'), now)
```

### 日付操作

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
  startOfDay,
  endOfDay,
  startOfMonth,
  endOfMonth,
  startOfYear
} from 'date-fns'

const date = new Date('2024-01-15 14:30:00')

// 加算・減算
addYears(date, 1)    // 1年後
addMonths(date, 2)   // 2ヶ月後
addWeeks(date, 1)    // 1週間後
addDays(date, 7)     // 7日後
subMonths(date, 1)   // 1ヶ月前

// 開始・終了
startOfDay(date)     // 2024-01-15 00:00:00
endOfDay(date)       // 2024-01-15 23:59:59
startOfMonth(date)   // 2024-01-01 00:00:00
endOfMonth(date)     // 2024-01-31 23:59:59
startOfYear(date)    // 2024-01-01 00:00:00
```

### 比較

```typescript
import {
  isAfter,
  isBefore,
  isEqual,
  isFuture,
  isPast,
  isToday,
  isYesterday,
  isTomorrow,
  isWeekend,
  isWithinInterval
} from 'date-fns'

const date1 = new Date('2024-01-15')
const date2 = new Date('2024-01-20')

isAfter(date2, date1)  // true
isBefore(date1, date2) // true
isEqual(date1, date1)  // true

isFuture(date2)        // date2が未来か
isPast(date1)          // date1が過去か
isToday(new Date())    // 今日か
isYesterday(subDays(new Date(), 1)) // 昨日か
isTomorrow(addDays(new Date(), 1))  // 明日か
isWeekend(date1)       // 週末か

// 期間内チェック
isWithinInterval(new Date(), {
  start: date1,
  end: date2
})
```

### 差分計算

```typescript
import {
  differenceInYears,
  differenceInMonths,
  differenceInDays,
  differenceInHours,
  differenceInMinutes,
  differenceInSeconds
} from 'date-fns'

const start = new Date('2024-01-01')
const end = new Date('2024-12-31')

differenceInYears(end, start)    // 0
differenceInMonths(end, start)   // 11
differenceInDays(end, start)     // 365
differenceInHours(end, start)    // 8760
```

### フォーマット

```typescript
import { format } from 'date-fns'
import { ja } from 'date-fns/locale'

const date = new Date('2024-01-15 14:30:45')

// 日付
format(date, 'yyyy-MM-dd')           // "2024-01-15"
format(date, 'yyyy/MM/dd')           // "2024/01/15"
format(date, 'MM/dd/yyyy')           // "01/15/2024"

// 時刻
format(date, 'HH:mm:ss')             // "14:30:45"
format(date, 'hh:mm a')              // "02:30 PM"

// 複合
format(date, 'yyyy-MM-dd HH:mm:ss')  // "2024-01-15 14:30:45"
format(date, 'PPpp', { locale: ja }) // "2024年1月15日 14:30"

// 相対時間
import { formatDistance, formatRelative } from 'date-fns'

formatDistance(subDays(new Date(), 3), new Date(), { locale: ja })
// "3日前"

formatRelative(subDays(new Date(), 3), new Date(), { locale: ja })
// "先週の金曜日"
```

---

## Day.js

Moment.js互換の軽量ライブラリ（2KB）。

### インストール

```bash
npm install dayjs
```

### 基本的な使い方

```typescript
import dayjs from 'dayjs'
import 'dayjs/locale/ja'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'
import relativeTime from 'dayjs/plugin/relativeTime'

// プラグイン有効化
dayjs.locale('ja')
dayjs.extend(utc)
dayjs.extend(timezone)
dayjs.extend(relativeTime)

// 現在日時
const now = dayjs()

// フォーマット
now.format('YYYY-MM-DD')           // "2024-01-15"
now.format('YYYY年MM月DD日')        // "2024年01月15日"
now.format('HH:mm:ss')             // "14:30:45"

// パース
const date = dayjs('2024-01-15')
const date2 = dayjs('2024-01-15 14:30:00')
```

### 日付操作

```typescript
const date = dayjs('2024-01-15')

// 加算・減算
date.add(1, 'year')    // 1年後
date.add(2, 'month')   // 2ヶ月後
date.add(7, 'day')     // 7日後
date.subtract(1, 'month') // 1ヶ月前

// 開始・終了
date.startOf('day')    // 2024-01-15 00:00:00
date.endOf('day')      // 2024-01-15 23:59:59
date.startOf('month')  // 2024-01-01 00:00:00
date.endOf('month')    // 2024-01-31 23:59:59

// 設定
date.set('year', 2025)
date.set('month', 11)  // 12月（0始まり）
date.set('date', 25)
```

### 比較

```typescript
const date1 = dayjs('2024-01-15')
const date2 = dayjs('2024-01-20')

date2.isAfter(date1)   // true
date1.isBefore(date2)  // true
date1.isSame(date1)    // true

// 単位指定
date2.isAfter(date1, 'day')
date2.isBefore(date1, 'month')
date1.isSame(date2, 'year')

// その他
date1.isBetween(date1, date2)
```

### 差分計算

```typescript
const start = dayjs('2024-01-01')
const end = dayjs('2024-12-31')

end.diff(start, 'year')    // 0
end.diff(start, 'month')   // 11
end.diff(start, 'day')     // 365
end.diff(start, 'hour')    // 8760

// 小数点付き
end.diff(start, 'month', true) // 11.xx
```

### フォーマット

```typescript
const date = dayjs('2024-01-15 14:30:45')

// 日付
date.format('YYYY-MM-DD')           // "2024-01-15"
date.format('YYYY/MM/DD')           // "2024/01/15"
date.format('MM/DD/YYYY')           // "01/15/2024"

// 時刻
date.format('HH:mm:ss')             // "14:30:45"
date.format('hh:mm A')              // "02:30 PM"

// 複合
date.format('YYYY-MM-DD HH:mm:ss')  // "2024-01-15 14:30:45"

// 相対時間（relativeTimeプラグイン必要）
date.fromNow()                      // "3日前"
date.from(dayjs('2024-01-10'))      // "5日後"
date.toNow()                        // "3日後"
```

### プラグイン

```typescript
// カスタムパース
import customParseFormat from 'dayjs/plugin/customParseFormat'
dayjs.extend(customParseFormat)
dayjs('12-25-2024', 'MM-DD-YYYY')

// 週番号
import weekOfYear from 'dayjs/plugin/weekOfYear'
dayjs.extend(weekOfYear)
dayjs().week() // 週番号

// 営業日計算
import isSameOrAfter from 'dayjs/plugin/isSameOrAfter'
import isSameOrBefore from 'dayjs/plugin/isSameOrBefore'
dayjs.extend(isSameOrAfter)
dayjs.extend(isSameOrBefore)
```

---

## 比較

| 機能 | date-fns | Day.js |
|------|----------|--------|
| サイズ | ~13KB (Tree-shaking) | ~2KB |
| API | 関数型 | メソッドチェーン |
| Tree-shaking | ○ | △ |
| Immutable | ○ | ○ |
| タイムゾーン | date-fns-tz | プラグイン |
| 国際化 | ○ | ○ |
| TypeScript | ○ | ○ |

### どちらを選ぶ？

**date-fns**を選ぶ場合:
- Tree-shakingでバンドルサイズを最小化したい
- 関数型プログラミングが好き
- 多機能で拡張性が必要

**Day.js**を選ぶ場合:
- Moment.jsから移行したい
- メソッドチェーンが好き
- 最小限のサイズが重要

---

## タイムゾーン

### date-fns-tz

```bash
npm install date-fns-tz
```

```typescript
import { formatInTimeZone, utcToZonedTime, zonedTimeToUtc } from 'date-fns-tz'

const date = new Date('2024-01-15 14:30:00')

// タイムゾーン付きフォーマット
formatInTimeZone(date, 'Asia/Tokyo', 'yyyy-MM-dd HH:mm:ss zzz')
// "2024-01-15 14:30:00 JST"

// UTCからタイムゾーン変換
const tokyoTime = utcToZonedTime(date, 'Asia/Tokyo')

// タイムゾーンからUTC変換
const utcTime = zonedTimeToUtc(tokyoTime, 'Asia/Tokyo')
```

### Day.js timezone

```typescript
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'

dayjs.extend(utc)
dayjs.extend(timezone)

// タイムゾーン指定
dayjs.tz('2024-01-15 14:30:00', 'Asia/Tokyo')

// 変換
dayjs().tz('America/New_York')

// デフォルトタイムゾーン設定
dayjs.tz.setDefault('Asia/Tokyo')
```

---

## フォーマット一覧

### date-fns

| トークン | 例 | 説明 |
|---------|-----|------|
| yyyy | 2024 | 年（4桁） |
| yy | 24 | 年（2桁） |
| MM | 01 | 月（2桁） |
| M | 1 | 月 |
| dd | 15 | 日（2桁） |
| d | 15 | 日 |
| HH | 14 | 時（24時間、2桁） |
| hh | 02 | 時（12時間、2桁） |
| mm | 30 | 分（2桁） |
| ss | 45 | 秒（2桁） |
| a | PM | AM/PM |

### Day.js

| トークン | 例 | 説明 |
|---------|-----|------|
| YYYY | 2024 | 年（4桁） |
| YY | 24 | 年（2桁） |
| MM | 01 | 月（2桁） |
| M | 1 | 月 |
| DD | 15 | 日（2桁） |
| D | 15 | 日 |
| HH | 14 | 時（24時間、2桁） |
| hh | 02 | 時（12時間、2桁） |
| mm | 30 | 分（2桁） |
| ss | 45 | 秒（2桁） |
| A | PM | AM/PM |

---

## 参考リンク

- [date-fns 公式](https://date-fns.org/)
- [Day.js 公式](https://day.js.org/)
- [date-fns-tz](https://github.com/marnusw/date-fns-tz)
