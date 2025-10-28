# CSV パース・生成ガイド

CSVファイルの読み込み、書き込み、データインポート/エクスポート機能の実装方法をまとめたガイドです。

## ライブラリ比較

| ライブラリ | 読込 | 書込 | ストリーミング | ブラウザ | サイズ |
|-----------|------|------|--------------|---------|--------|
| **PapaParse** | ✓ | ✓ | ✓ | ✓ | 軽量 |
| **csv-parser** | ✓ | ✗ | ✓ | ✗ | 軽量 |
| **fast-csv** | ✓ | ✓ | ✓ | ✗ | 中量 |
| **csv-stringify** | ✗ | ✓ | ✓ | ✗ | 軽量 |

### 選択基準

- **PapaParse**: ブラウザ・サーバー両対応、最も汎用的
- **csv-parser**: Node.jsで読込のみ、高速
- **fast-csv**: Node.jsでフル機能、大容量対応
- **csv-stringify**: 書き込み専用

## PapaParse

### 特徴

- **ブラウザ/Node.js両対応**: ユニバーサル
- **自動型変換**: 数値、真偽値を自動変換
- **エラーハンドリング**: 詳細なエラー情報
- **ストリーミング**: 大容量ファイル対応
- **ヘッダー認識**: 自動的にオブジェクト化

### インストール

```bash
npm install papaparse
npm install @types/papaparse -D
```

### 基本的な読み込み

```typescript
import Papa from 'papaparse'

// 文字列からパース
const csv = `
name,age,email
太郎,25,taro@example.com
花子,30,hanako@example.com
`

const result = Papa.parse(csv, {
  header: true, // 1行目をヘッダーとして使用
  dynamicTyping: true, // 数値を自動変換
  skipEmptyLines: true,
})

console.log(result.data)
// [
//   { name: '太郎', age: 25, email: 'taro@example.com' },
//   { name: '花子', age: 30, email: 'hanako@example.com' }
// ]
```

### ファイルからの読み込み（ブラウザ）

```typescript
'use client'

import Papa from 'papaparse'
import { useState } from 'react'

export default function CSVUpload() {
  const [data, setData] = useState<any[]>([])

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    Papa.parse(file, {
      header: true,
      dynamicTyping: true,
      complete: (results) => {
        setData(results.data)
        console.log('Parsed:', results.data)
      },
      error: (error) => {
        console.error('Parse error:', error)
      },
    })
  }

  return (
    <div>
      <input type="file" accept=".csv" onChange={handleFileUpload} />
      {data.length > 0 && (
        <table>
          <thead>
            <tr>
              {Object.keys(data[0]).map((key) => (
                <th key={key}>{key}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.map((row, i) => (
              <tr key={i}>
                {Object.values(row).map((value: any, j) => (
                  <td key={j}>{value}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
```

### ファイルからの読み込み（Node.js）

```typescript
import Papa from 'papaparse'
import fs from 'fs'

async function readCSV(filePath: string) {
  const file = fs.createReadStream(filePath)

  return new Promise((resolve, reject) => {
    Papa.parse(file, {
      header: true,
      dynamicTyping: true,
      complete: (results) => {
        resolve(results.data)
      },
      error: (error) => {
        reject(error)
      },
    })
  })
}

// 使用例
const data = await readCSV('users.csv')
console.log(data)
```

### CSV生成・ダウンロード

```typescript
import Papa from 'papaparse'

interface User {
  name: string
  age: number
  email: string
}

function exportToCSV(data: User[], filename: string) {
  const csv = Papa.unparse(data, {
    header: true,
  })

  // ブラウザでダウンロード
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const link = document.createElement('a')
  const url = URL.createObjectURL(blob)

  link.setAttribute('href', url)
  link.setAttribute('download', filename)
  link.style.visibility = 'hidden'
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
}

// 使用例
const users: User[] = [
  { name: '太郎', age: 25, email: 'taro@example.com' },
  { name: '花子', age: 30, email: 'hanako@example.com' },
]

exportToCSV(users, 'users.csv')
```

### Next.js API Route（アップロード）

```typescript
// app/api/csv/upload/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Papa from 'papaparse'

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File

    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 })
    }

    // ファイルをテキストとして読み込み
    const text = await file.text()

    // CSVパース
    const result = Papa.parse(text, {
      header: true,
      dynamicTyping: true,
      skipEmptyLines: true,
    })

    if (result.errors.length > 0) {
      return NextResponse.json({ error: 'Parse errors', errors: result.errors }, { status: 400 })
    }

    // データ処理（例：データベースに保存）
    // await saveToDatabase(result.data)

    return NextResponse.json({
      success: true,
      rowCount: result.data.length,
      data: result.data,
    })
  } catch (error) {
    console.error('Upload error:', error)
    return NextResponse.json({ error: 'Upload failed' }, { status: 500 })
  }
}
```

### Next.js API Route（エクスポート）

```typescript
// app/api/csv/export/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Papa from 'papaparse'
import { prisma } from '@/lib/db'

export async function GET(request: NextRequest) {
  try {
    // データベースからデータ取得
    const users = await prisma.user.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
      },
    })

    // CSV生成
    const csv = Papa.unparse(users, {
      header: true,
    })

    // レスポンス
    return new NextResponse(csv, {
      headers: {
        'Content-Type': 'text/csv',
        'Content-Disposition': 'attachment; filename=users.csv',
      },
    })
  } catch (error) {
    console.error('Export error:', error)
    return NextResponse.json({ error: 'Export failed' }, { status: 500 })
  }
}
```

### バリデーション付きインポート

```typescript
import Papa from 'papaparse'
import { z } from 'zod'

// スキーマ定義
const userSchema = z.object({
  name: z.string().min(1),
  age: z.number().int().positive(),
  email: z.string().email(),
})

type User = z.infer<typeof userSchema>

async function importCSVWithValidation(file: File) {
  return new Promise<{ valid: User[]; invalid: any[] }>((resolve, reject) => {
    Papa.parse(file, {
      header: true,
      dynamicTyping: true,
      complete: (results) => {
        const valid: User[] = []
        const invalid: any[] = []

        results.data.forEach((row: any, index) => {
          try {
            const validated = userSchema.parse(row)
            valid.push(validated)
          } catch (error) {
            invalid.push({ row: index + 1, data: row, error })
          }
        })

        resolve({ valid, invalid })
      },
      error: reject,
    })
  })
}

// 使用例
const { valid, invalid } = await importCSVWithValidation(file)

if (invalid.length > 0) {
  console.log('Invalid rows:', invalid)
}

// 有効なデータのみ処理
await saveUsers(valid)
```

## fast-csv (Node.js)

### 特徴

- **ストリーミング**: 大容量ファイルに最適
- **Node.js専用**: サーバーサイド処理
- **変換**: データ変換パイプライン
- **読み書き両対応**: フル機能

### インストール

```bash
npm install fast-csv
npm install @types/fast-csv -D
```

### 読み込み

```typescript
import fs from 'fs'
import { parseFile } from '@fast-csv/parse'

async function readCSV(filePath: string): Promise<any[]> {
  const rows: any[] = []

  return new Promise((resolve, reject) => {
    fs.createReadStream(filePath)
      .pipe(
        parseFile({ headers: true })
      )
      .on('data', (row) => {
        rows.push(row)
      })
      .on('end', () => {
        resolve(rows)
      })
      .on('error', reject)
  })
}
```

### 書き込み

```typescript
import fs from 'fs'
import { format } from '@fast-csv/format'

async function writeCSV(data: any[], filePath: string) {
  return new Promise((resolve, reject) => {
    const stream = format({ headers: true })
    const writeStream = fs.createWriteStream(filePath)

    stream.pipe(writeStream)

    data.forEach((row) => {
      stream.write(row)
    })

    stream.end()

    writeStream.on('finish', resolve)
    writeStream.on('error', reject)
  })
}

// 使用例
const users = [
  { name: '太郎', age: 25, email: 'taro@example.com' },
  { name: '花子', age: 30, email: 'hanako@example.com' },
]

await writeCSV(users, 'output.csv')
```

### ストリーミング変換

```typescript
import fs from 'fs'
import { parse, format } from 'fast-csv'

// CSVを読み込みながら変換して別のCSVに書き出し
fs.createReadStream('input.csv')
  .pipe(parse({ headers: true }))
  .transform((row) => {
    // データ変換
    return {
      ...row,
      age: parseInt(row.age),
      email: row.email.toLowerCase(),
      createdAt: new Date().toISOString(),
    }
  })
  .pipe(format({ headers: true }))
  .pipe(fs.createWriteStream('output.csv'))
  .on('finish', () => {
    console.log('Transformation complete')
  })
```

## 実践例

### ユーザー一括インポート

```typescript
// app/api/users/import/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Papa from 'papaparse'
import { prisma } from '@/lib/db'
import { hash } from '@node-rs/argon2'

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File
    const text = await file.text()

    const result = Papa.parse(text, {
      header: true,
      skipEmptyLines: true,
    })

    const users = result.data as Array<{
      name: string
      email: string
      password: string
    }>

    // バリデーション
    const errors: any[] = []
    const validUsers: any[] = []

    for (let i = 0; i < users.length; i++) {
      const user = users[i]

      // メールの重複チェック
      const existing = await prisma.user.findUnique({
        where: { email: user.email },
      })

      if (existing) {
        errors.push({ row: i + 2, email: user.email, error: 'Email already exists' })
        continue
      }

      // パスワードハッシュ化
      const passwordHash = await hash(user.password)

      validUsers.push({
        name: user.name,
        email: user.email,
        passwordHash,
      })
    }

    // 一括作成
    const created = await prisma.user.createMany({
      data: validUsers,
      skipDuplicates: true,
    })

    return NextResponse.json({
      success: true,
      imported: created.count,
      errors: errors.length > 0 ? errors : undefined,
    })
  } catch (error) {
    console.error('Import error:', error)
    return NextResponse.json({ error: 'Import failed' }, { status: 500 })
  }
}
```

### 注文データエクスポート

```typescript
// app/api/orders/export/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Papa from 'papaparse'
import { prisma } from '@/lib/db'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const startDate = searchParams.get('startDate')
    const endDate = searchParams.get('endDate')

    // 注文データ取得
    const orders = await prisma.order.findMany({
      where: {
        createdAt: {
          gte: startDate ? new Date(startDate) : undefined,
          lte: endDate ? new Date(endDate) : undefined,
        },
      },
      include: {
        user: true,
        items: true,
      },
    })

    // CSVデータに変換
    const csvData = orders.map((order) => ({
      '注文ID': order.id,
      '注文日時': order.createdAt.toISOString(),
      '顧客名': order.user.name,
      'メール': order.user.email,
      '商品数': order.items.length,
      '合計金額': order.total,
      'ステータス': order.status,
    }))

    // CSV生成
    const csv = Papa.unparse(csvData, {
      header: true,
    })

    return new NextResponse(csv, {
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename=orders-${Date.now()}.csv`,
      },
    })
  } catch (error) {
    console.error('Export error:', error)
    return NextResponse.json({ error: 'Export failed' }, { status: 500 })
  }
}
```

### 進捗表示付きインポート

```typescript
'use client'

import Papa from 'papaparse'
import { useState } from 'react'

export default function BulkImport() {
  const [progress, setProgress] = useState(0)
  const [status, setStatus] = useState('')

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setStatus('パース中...')

    Papa.parse(file, {
      header: true,
      chunk: async (results, parser) => {
        parser.pause()

        // バッチ処理
        const batch = results.data

        setStatus(`${batch.length}件処理中...`)

        // APIに送信
        await fetch('/api/users/import-batch', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ users: batch }),
        })

        setProgress((prev) => prev + batch.length)

        parser.resume()
      },
      complete: () => {
        setStatus('完了')
      },
      error: (error) => {
        setStatus(`エラー: ${error.message}`)
      },
    })
  }

  return (
    <div>
      <input type="file" accept=".csv" onChange={handleImport} />
      {status && (
        <div>
          <p>{status}</p>
          <p>処理済み: {progress}件</p>
        </div>
      )}
    </div>
  )
}
```

## ベストプラクティス

### 1. 文字エンコーディング

```typescript
// UTF-8 BOM付きで出力（Excel対応）
const csv = Papa.unparse(data, { header: true })
const bom = '\uFEFF'
const blob = new Blob([bom + csv], { type: 'text/csv;charset=utf-8;' })
```

### 2. 大容量ファイル処理

```typescript
// ストリーミング処理で メモリ効率化
Papa.parse(file, {
  header: true,
  chunk: (results) => {
    // バッチごとに処理
    processBatch(results.data)
  },
  complete: () => {
    console.log('All done!')
  },
})
```

### 3. エラーハンドリング

```typescript
Papa.parse(file, {
  header: true,
  error: (error, file) => {
    console.error('Parse error:', error)
    // ユーザーに通知
  },
  complete: (results) => {
    if (results.errors.length > 0) {
      console.log('Row errors:', results.errors)
      // 行ごとのエラーを表示
    }
  },
})
```

### 4. 型安全なパース

```typescript
interface User {
  name: string
  age: number
  email: string
}

const result = Papa.parse<User>(csv, {
  header: true,
  dynamicTyping: true,
})

// result.data は User[] 型
```

### 5. カスタムデリミタ

```typescript
// TSV（タブ区切り）
Papa.parse(file, {
  delimiter: '\t',
})

// セミコロン区切り
Papa.parse(file, {
  delimiter: ';',
})

// 自動検出
Papa.parse(file, {
  delimiter: '', // 自動検出
})
```

## 参考リンク

- [PapaParse 公式ドキュメント](https://www.papaparse.com/)
- [fast-csv 公式ドキュメント](https://c2fo.github.io/fast-csv/)
- [csv-parser GitHub](https://github.com/mafintosh/csv-parser)
