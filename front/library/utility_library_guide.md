# ユーティリティライブラリ完全ガイド (Lodash / Ramda)

## 目次
- [概要](#概要)
- [Lodash](#lodash)
- [Ramda](#ramda)
- [比較](#比較)
- [パフォーマンス](#パフォーマンス)

---

## 概要

JavaScriptのユーティリティライブラリ。配列・オブジェクト操作を簡単に。

### 主要ライブラリ
- **Lodash**: 汎用的、豊富な関数、パフォーマンス重視
- **Ramda**: 関数型プログラミング、カリー化、イミュータブル

---

## Lodash

最も人気のあるJavaScriptユーティリティライブラリ。

### インストール

```bash
npm install lodash
npm install --save-dev @types/lodash

# Tree-shaking対応
npm install lodash-es
```

### インポート

```typescript
// 全体インポート（非推奨）
import _ from 'lodash'

// 個別インポート（推奨）
import { map, filter, reduce } from 'lodash'

// lodash-es (Tree-shaking)
import { map, filter } from 'lodash-es'

// 関数単位でインポート
import map from 'lodash/map'
```

### 配列操作

```typescript
import { chunk, compact, uniq, flatten, difference, intersection } from 'lodash'

// chunk - 配列を分割
chunk([1, 2, 3, 4, 5], 2)
// [[1, 2], [3, 4], [5]]

// compact - falsyな値を除外
compact([0, 1, false, 2, '', 3, null, undefined])
// [1, 2, 3]

// uniq - 重複削除
uniq([1, 2, 1, 3, 2])
// [1, 2, 3]

// flatten - 配列を平坦化
flatten([1, [2, [3, [4]], 5]])
// [1, 2, [3, [4]], 5]

// flattenDeep - 完全に平坦化
import { flattenDeep } from 'lodash'
flattenDeep([1, [2, [3, [4]], 5]])
// [1, 2, 3, 4, 5]

// difference - 差分
difference([2, 1], [2, 3])
// [1]

// intersection - 共通要素
intersection([2, 1], [2, 3])
// [2]

// union - 和集合
import { union } from 'lodash'
union([2], [1, 2])
// [2, 1]
```

### オブジェクト操作

```typescript
import { pick, omit, merge, cloneDeep, get, set } from 'lodash'

const obj = { a: 1, b: 2, c: 3 }

// pick - 指定キーのみ抽出
pick(obj, ['a', 'c'])
// { a: 1, c: 3 }

// omit - 指定キーを除外
omit(obj, ['b'])
// { a: 1, c: 3 }

// merge - マージ
merge({ a: 1 }, { b: 2 }, { c: 3 })
// { a: 1, b: 2, c: 3 }

// cloneDeep - ディープコピー
const original = { a: { b: 1 } }
const copied = cloneDeep(original)

// get - 安全なアクセス
const data = { user: { name: 'John', address: { city: 'Tokyo' } } }
get(data, 'user.address.city') // "Tokyo"
get(data, 'user.phone', 'N/A') // "N/A" (デフォルト値)

// set - 値設定
set(data, 'user.age', 30)
```

### コレクション操作

```typescript
import { map, filter, reduce, groupBy, sortBy, find } from 'lodash'

const users = [
  { name: 'John', age: 30, role: 'admin' },
  { name: 'Jane', age: 25, role: 'user' },
  { name: 'Bob', age: 35, role: 'user' }
]

// map
map(users, 'name')
// ['John', 'Jane', 'Bob']

// filter
filter(users, { role: 'user' })
// [{ name: 'Jane', ... }, { name: 'Bob', ... }]

// find
find(users, { name: 'John' })
// { name: 'John', age: 30, role: 'admin' }

// groupBy
groupBy(users, 'role')
// { admin: [...], user: [...] }

// sortBy
sortBy(users, 'age')
// 年齢順にソート

// orderBy - 複数キーでソート
import { orderBy } from 'lodash'
orderBy(users, ['role', 'age'], ['asc', 'desc'])
```

### 関数操作

```typescript
import { debounce, throttle, once, memoize } from 'lodash'

// debounce - 連続呼び出しを制限
const search = debounce((query: string) => {
  console.log('Searching:', query)
}, 300)

search('a')
search('ab')
search('abc') // 300ms後に1回だけ実行

// throttle - 一定時間に1回のみ実行
const onScroll = throttle(() => {
  console.log('Scrolled')
}, 1000)

window.addEventListener('scroll', onScroll)

// once - 1回のみ実行
const initialize = once(() => {
  console.log('Initialized')
})
initialize() // "Initialized"
initialize() // 実行されない

// memoize - 結果をキャッシュ
const fibonacci = memoize((n: number): number => {
  if (n <= 1) return n
  return fibonacci(n - 1) + fibonacci(n - 2)
})
```

### 文字列操作

```typescript
import {
  camelCase,
  kebabCase,
  snakeCase,
  startCase,
  upperFirst,
  capitalize,
  truncate
} from 'lodash'

// camelCase
camelCase('hello world') // "helloWorld"

// kebabCase
kebabCase('hello world') // "hello-world"

// snakeCase
snakeCase('hello world') // "hello_world"

// startCase
startCase('hello world') // "Hello World"

// upperFirst
upperFirst('hello') // "Hello"

// capitalize
capitalize('HELLO') // "Hello"

// truncate - 切り詰め
truncate('This is a long text', { length: 10 })
// "This is..."
```

### その他便利関数

```typescript
import { random, times, range, isEqual, isEmpty } from 'lodash'

// random - ランダム数
random(1, 10) // 1〜10のランダム数
random(1.5, 5.5, true) // 小数点含む

// times - N回実行
times(3, (i) => console.log(i))
// 0, 1, 2

// range - 範囲配列生成
range(5)        // [0, 1, 2, 3, 4]
range(1, 5)     // [1, 2, 3, 4]
range(0, 10, 2) // [0, 2, 4, 6, 8]

// isEqual - ディープ比較
isEqual({ a: 1 }, { a: 1 }) // true

// isEmpty - 空チェック
isEmpty([])        // true
isEmpty({})        // true
isEmpty('')        // true
isEmpty(null)      // true
isEmpty([1])       // false
```

---

## Ramda

関数型プログラミングに特化したライブラリ。

### インストール

```bash
npm install ramda
npm install --save-dev @types/ramda
```

### 基本概念

```typescript
import * as R from 'ramda'

// カリー化 - 引数を1つずつ受け取る
const add = R.add
add(2)(3) // 5
add(2, 3) // 5

// 合成 - 関数を組み合わせる
const multiplyBy2 = (x: number) => x * 2
const add3 = (x: number) => x + 3

const multiplyThenAdd = R.compose(add3, multiplyBy2)
multiplyThenAdd(5) // (5 * 2) + 3 = 13

// pipe - composeの逆順
const addThenMultiply = R.pipe(add3, multiplyBy2)
addThenMultiply(5) // (5 + 3) * 2 = 16
```

### 配列操作

```typescript
import * as R from 'ramda'

// map
R.map(R.multiply(2), [1, 2, 3])
// [2, 4, 6]

// filter
R.filter(R.gt(R.__, 3), [1, 2, 3, 4, 5])
// [4, 5]

// reduce
R.reduce(R.add, 0, [1, 2, 3, 4, 5])
// 15

// take / drop
R.take(2, [1, 2, 3, 4]) // [1, 2]
R.drop(2, [1, 2, 3, 4]) // [3, 4]

// uniq
R.uniq([1, 2, 1, 3, 2]) // [1, 2, 3]

// flatten
R.flatten([1, [2, [3, 4]], 5])
// [1, 2, [3, 4], 5]
```

### オブジェクト操作

```typescript
import * as R from 'ramda'

const user = { name: 'John', age: 30, role: 'admin' }

// prop - プロパティ取得
R.prop('name', user) // "John"

// pick
R.pick(['name', 'age'], user)
// { name: 'John', age: 30 }

// omit
R.omit(['role'], user)
// { name: 'John', age: 30 }

// assoc - プロパティ追加（イミュータブル）
R.assoc('email', 'john@example.com', user)
// { name: 'John', age: 30, role: 'admin', email: 'john@example.com' }

// dissoc - プロパティ削除（イミュータブル）
R.dissoc('role', user)
// { name: 'John', age: 30 }

// merge
R.merge(user, { email: 'john@example.com' })

// path - ネストしたプロパティ取得
const data = { user: { address: { city: 'Tokyo' } } }
R.path(['user', 'address', 'city'], data) // "Tokyo"
```

### 関数合成

```typescript
import * as R from 'ramda'

const users = [
  { name: 'John', age: 30 },
  { name: 'Jane', age: 25 },
  { name: 'Bob', age: 35 }
]

// compose で複数操作を組み合わせ
const getAdultNames = R.compose(
  R.map(R.prop('name')),
  R.filter((user) => user.age >= 30)
)

getAdultNames(users)
// ['John', 'Bob']

// pipe で順番に実行
const processUsers = R.pipe(
  R.filter((user) => user.age >= 30),
  R.map(R.prop('name')),
  R.join(', ')
)

processUsers(users)
// "John, Bob"
```

### カリー化

```typescript
import * as R from 'ramda'

// カスタムカリー化関数
const multiply = R.curry((a: number, b: number, c: number) => a * b * c)

multiply(2)(3)(4)     // 24
multiply(2, 3)(4)     // 24
multiply(2)(3, 4)     // 24

const double = multiply(2)
const quadruple = multiply(2, 2)

double(5, 10) // 100
quadruple(5)  // 20

// 実用例
const filterByAge = R.curry((minAge: number, users: any[]) =>
  R.filter(R.propSatisfies(R.gte(R.__, minAge), 'age'), users)
)

const getAdults = filterByAge(18)
getAdults(users)
```

### レンズ

```typescript
import * as R from 'ramda'

const user = {
  name: 'John',
  address: {
    city: 'Tokyo',
    zip: '100-0001'
  }
}

// レンズ作成
const cityLens = R.lensPath(['address', 'city'])

// view - 値取得
R.view(cityLens, user) // "Tokyo"

// set - 値設定（イミュータブル）
R.set(cityLens, 'Osaka', user)
// address.city が "Osaka" に変更された新しいオブジェクト

// over - 値変換（イミュータブル）
R.over(cityLens, R.toUpper, user)
// address.city が "TOKYO" に変換された新しいオブジェクト
```

---

## 比較

| 機能 | Lodash | Ramda |
|------|--------|-------|
| 設計思想 | 汎用的 | 関数型 |
| カリー化 | 部分的 | 全関数 |
| イミュータブル | △ | ○ |
| データ優先 | ○ | × (最後の引数) |
| Tree-shaking | lodash-es | ○ |
| サイズ | ~24KB | ~12KB |
| パフォーマンス | ◎ | ○ |
| 学習コスト | 低 | 高 |

### どちらを選ぶ？

**Lodash**を選ぶ場合:
- 一般的な用途
- パフォーマンス重視
- チームの学習コストを抑えたい
- すぐに使える豊富な関数が必要

**Ramda**を選ぶ場合:
- 関数型プログラミングを実践したい
- イミュータブルな操作が必須
- 関数合成を多用する
- カリー化された関数が必要

---

## パフォーマンス

### ネイティブ vs ライブラリ

```typescript
// ネイティブ（最速）
const doubled = array.map(x => x * 2)

// Lodash
import { map } from 'lodash'
const doubled = map(array, x => x * 2)

// Ramda
import * as R from 'ramda'
const doubled = R.map(x => x * 2, array)
```

### Tree-shaking

```typescript
// ✗ バンドルサイズ大
import _ from 'lodash'
_.map(array, fn)

// ○ 必要な関数のみ
import map from 'lodash/map'
map(array, fn)

// ○ lodash-es (推奨)
import { map } from 'lodash-es'
map(array, fn)
```

### モダンJSで置き換え

```typescript
// Lodash map → Array.prototype.map
import { map } from 'lodash'
map(array, fn) → array.map(fn)

// Lodash filter → Array.prototype.filter
import { filter } from 'lodash'
filter(array, fn) → array.filter(fn)

// Lodash uniq → Set
import { uniq } from 'lodash'
uniq(array) → [...new Set(array)]

// Lodash flatten → Array.prototype.flat
import { flatten } from 'lodash'
flatten(array) → array.flat()

// Lodash pick → destructuring
import { pick } from 'lodash'
pick(obj, ['a', 'b']) → ((({ a, b }) => ({ a, b }))(obj))
```

---

## 参考リンク

- [Lodash 公式](https://lodash.com/)
- [Ramda 公式](https://ramdajs.com/)
- [You Don't Need Lodash/Underscore](https://github.com/you-dont-need/You-Dont-Need-Lodash-Underscore)
