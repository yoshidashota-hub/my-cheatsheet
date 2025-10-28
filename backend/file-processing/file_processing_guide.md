# ファイル処理ガイド

業務アプリケーションでよく必要となるファイル処理（PDF生成、Excel処理、画像処理）の実装方法をまとめたガイドです。

## ライブラリ比較

### PDF生成

| ライブラリ | サイズ | 用途 | レンダリング | 日本語対応 |
|-----------|--------|------|-------------|-----------|
| **PDFKit** | 軽量 | プログラマティック生成 | サーバー | ✓ |
| **Puppeteer** | 重量 | HTML→PDF変換 | ブラウザ | ✓ |
| **@react-pdf/renderer** | 中量 | React→PDF | サーバー | ✓ |
| **jsPDF** | 軽量 | ブラウザ内生成 | ブラウザ | △ |

### Excel処理

| ライブラリ | 読込 | 書込 | スタイル | 数式 |
|-----------|------|------|---------|------|
| **ExcelJS** | ✓ | ✓ | ✓ | ✓ |
| **SheetJS (xlsx)** | ✓ | ✓ | △ | △ |
| **node-xlsx** | ✓ | ✓ | ✗ | ✗ |

### 画像処理

| ライブラリ | サイズ | パフォーマンス | 機能 | フォーマット |
|-----------|--------|--------------|------|-------------|
| **Sharp** | ネイティブ | ⭐⭐⭐⭐⭐ | 豊富 | JPEG, PNG, WebP等 |
| **Jimp** | Pure JS | ⭐⭐⭐ | 基本 | JPEG, PNG, BMP, GIF |

## PDF生成

### PDFKit

#### 特徴

- **軽量**: サーバーサイドで高速
- **プログラマティック**: コードで細かく制御
- **日本語対応**: フォント埋め込み可能
- **ストリーミング**: 大きなPDFも効率的

#### インストール

```bash
npm install pdfkit
npm install @types/pdfkit -D
```

#### 基本的な使い方

```typescript
import PDFDocument from 'pdfkit'
import fs from 'fs'

// PDF生成
function createPDF() {
  const doc = new PDFDocument()

  // ファイルに保存
  doc.pipe(fs.createWriteStream('output.pdf'))

  // テキスト追加
  doc.fontSize(25).text('Hello World!', 100, 100)

  // 完了
  doc.end()
}
```

#### 日本語対応

```typescript
import PDFDocument from 'pdfkit'
import fs from 'fs'

function createJapanesePDF() {
  const doc = new PDFDocument()
  doc.pipe(fs.createWriteStream('japanese.pdf'))

  // フォント登録
  doc.registerFont('NotoSans', 'path/to/NotoSansJP-Regular.ttf')

  // 日本語テキスト
  doc
    .font('NotoSans')
    .fontSize(20)
    .text('こんにちは、世界！', 100, 100)

  doc.end()
}
```

#### 請求書の例

```typescript
import PDFDocument from 'pdfkit'
import fs from 'fs'

interface InvoiceItem {
  description: string
  quantity: number
  price: number
}

interface Invoice {
  invoiceNumber: string
  date: string
  customerName: string
  items: InvoiceItem[]
}

function generateInvoice(invoice: Invoice) {
  const doc = new PDFDocument({ margin: 50 })
  doc.pipe(fs.createWriteStream(`invoice-${invoice.invoiceNumber}.pdf`))

  // ヘッダー
  doc.fontSize(20).text('請求書', 50, 50)

  doc
    .fontSize(10)
    .text(`請求書番号: ${invoice.invoiceNumber}`, 50, 80)
    .text(`発行日: ${invoice.date}`, 50, 95)
    .text(`お客様名: ${invoice.customerName}`, 50, 110)

  // 表のヘッダー
  const tableTop = 150
  doc
    .fontSize(12)
    .text('品名', 50, tableTop)
    .text('数量', 250, tableTop)
    .text('単価', 350, tableTop)
    .text('金額', 450, tableTop)

  // 区切り線
  doc
    .moveTo(50, tableTop + 15)
    .lineTo(550, tableTop + 15)
    .stroke()

  // 品目
  let position = tableTop + 30
  let total = 0

  invoice.items.forEach((item) => {
    const amount = item.quantity * item.price

    doc
      .fontSize(10)
      .text(item.description, 50, position)
      .text(item.quantity.toString(), 250, position)
      .text(`¥${item.price.toLocaleString()}`, 350, position)
      .text(`¥${amount.toLocaleString()}`, 450, position)

    total += amount
    position += 20
  })

  // 合計
  doc
    .moveTo(350, position)
    .lineTo(550, position)
    .stroke()

  doc
    .fontSize(12)
    .text('合計:', 350, position + 10)
    .text(`¥${total.toLocaleString()}`, 450, position + 10)

  doc.end()
}

// 使用例
generateInvoice({
  invoiceNumber: 'INV-2024-001',
  date: '2024-10-28',
  customerName: '株式会社サンプル',
  items: [
    { description: '商品A', quantity: 2, price: 10000 },
    { description: '商品B', quantity: 1, price: 25000 },
    { description: 'サービスC', quantity: 3, price: 5000 },
  ],
})
```

#### Next.js API Route

```typescript
// app/api/invoice/route.ts
import { NextRequest, NextResponse } from 'next/server'
import PDFDocument from 'pdfkit'

export async function POST(request: NextRequest) {
  const data = await request.json()

  // PDFストリームを作成
  const chunks: Uint8Array[] = []
  const doc = new PDFDocument()

  doc.on('data', (chunk) => chunks.push(chunk))
  doc.on('end', () => {
    // 完了処理
  })

  // PDF生成
  doc.fontSize(25).text('請求書', 100, 100)
  doc.fontSize(12).text(`顧客: ${data.customerName}`, 100, 150)
  // ...

  doc.end()

  // バッファを結合
  await new Promise((resolve) => doc.on('end', resolve))
  const pdfBuffer = Buffer.concat(chunks)

  // レスポンスを返す
  return new NextResponse(pdfBuffer, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'attachment; filename=invoice.pdf',
    },
  })
}
```

### Puppeteer

#### 特徴

- **HTML→PDF**: HTMLをPDFに変換
- **高品質**: ブラウザでレンダリング
- **複雑なレイアウト**: CSSを活用可能
- **スクリーンショット**: 画像出力も可能

#### インストール

```bash
npm install puppeteer
```

#### 基本的な使い方

```typescript
import puppeteer from 'puppeteer'

async function htmlToPDF(html: string) {
  const browser = await puppeteer.launch()
  const page = await browser.newPage()

  // HTMLを設定
  await page.setContent(html)

  // PDFを生成
  await page.pdf({
    path: 'output.pdf',
    format: 'A4',
    printBackground: true,
    margin: {
      top: '20mm',
      right: '20mm',
      bottom: '20mm',
      left: '20mm',
    },
  })

  await browser.close()
}
```

#### 請求書テンプレート

```typescript
import puppeteer from 'puppeteer'

const invoiceHTML = `
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: 'Noto Sans JP', sans-serif;
      margin: 0;
      padding: 20px;
    }
    .header {
      text-align: center;
      margin-bottom: 30px;
    }
    .header h1 {
      font-size: 28px;
      margin: 0;
    }
    .info {
      margin-bottom: 20px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 20px;
    }
    th, td {
      border: 1px solid #ddd;
      padding: 12px;
      text-align: left;
    }
    th {
      background-color: #f2f2f2;
    }
    .total {
      text-align: right;
      font-size: 18px;
      font-weight: bold;
      margin-top: 20px;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>請求書</h1>
  </div>
  <div class="info">
    <p><strong>請求書番号:</strong> {{invoiceNumber}}</p>
    <p><strong>発行日:</strong> {{date}}</p>
    <p><strong>お客様名:</strong> {{customerName}}</p>
  </div>
  <table>
    <thead>
      <tr>
        <th>品名</th>
        <th>数量</th>
        <th>単価</th>
        <th>金額</th>
      </tr>
    </thead>
    <tbody>
      {{items}}
    </tbody>
  </table>
  <div class="total">
    合計: ¥{{total}}
  </div>
</body>
</html>
`

async function generateInvoicePDF(data: any) {
  const browser = await puppeteer.launch()
  const page = await browser.newPage()

  // テンプレートに値を埋め込み
  const itemsHTML = data.items
    .map(
      (item: any) => `
    <tr>
      <td>${item.description}</td>
      <td>${item.quantity}</td>
      <td>¥${item.price.toLocaleString()}</td>
      <td>¥${(item.quantity * item.price).toLocaleString()}</td>
    </tr>
  `
    )
    .join('')

  const total = data.items.reduce(
    (sum: number, item: any) => sum + item.quantity * item.price,
    0
  )

  const html = invoiceHTML
    .replace('{{invoiceNumber}}', data.invoiceNumber)
    .replace('{{date}}', data.date)
    .replace('{{customerName}}', data.customerName)
    .replace('{{items}}', itemsHTML)
    .replace('{{total}}', total.toLocaleString())

  await page.setContent(html)

  await page.pdf({
    path: `invoice-${data.invoiceNumber}.pdf`,
    format: 'A4',
    printBackground: true,
  })

  await browser.close()
}
```

### @react-pdf/renderer

#### 特徴

- **React**: Reactコンポーネントでデザイン
- **宣言的**: JSX構文で記述
- **レスポンシブ**: Flexboxレイアウト
- **サーバー/ブラウザ**: 両方で動作

#### インストール

```bash
npm install @react-pdf/renderer
```

#### 基本的な使い方

```typescript
import React from 'react'
import { Document, Page, Text, View, StyleSheet, pdf } from '@react-pdf/renderer'
import fs from 'fs'

// スタイル定義
const styles = StyleSheet.create({
  page: {
    padding: 30,
  },
  header: {
    fontSize: 24,
    marginBottom: 20,
    textAlign: 'center',
  },
  text: {
    fontSize: 12,
    marginBottom: 10,
  },
})

// PDFコンポーネント
const MyDocument = () => (
  <Document>
    <Page size="A4" style={styles.page}>
      <Text style={styles.header}>請求書</Text>
      <Text style={styles.text}>請求書番号: INV-2024-001</Text>
      <Text style={styles.text}>発行日: 2024-10-28</Text>
    </Page>
  </Document>
)

// PDF生成
async function generatePDF() {
  const blob = await pdf(<MyDocument />).toBlob()
  // Node.jsの場合
  const buffer = await pdf(<MyDocument />).toBuffer()
  fs.writeFileSync('output.pdf', buffer)
}
```

#### 請求書コンポーネント

```typescript
import React from 'react'
import { Document, Page, Text, View, StyleSheet } from '@react-pdf/renderer'

const styles = StyleSheet.create({
  page: {
    padding: 30,
    fontFamily: 'Helvetica',
  },
  header: {
    fontSize: 24,
    marginBottom: 20,
    textAlign: 'center',
  },
  section: {
    marginBottom: 10,
  },
  table: {
    display: 'flex',
    width: 'auto',
    marginTop: 20,
  },
  tableRow: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: '#ddd',
    paddingVertical: 8,
  },
  tableHeader: {
    backgroundColor: '#f2f2f2',
  },
  tableCol: {
    width: '25%',
    paddingHorizontal: 8,
  },
  tableCell: {
    fontSize: 10,
  },
  total: {
    marginTop: 20,
    fontSize: 14,
    fontWeight: 'bold',
    textAlign: 'right',
  },
})

interface InvoiceProps {
  invoiceNumber: string
  date: string
  customerName: string
  items: Array<{
    description: string
    quantity: number
    price: number
  }>
}

const InvoiceDocument = ({ invoiceNumber, date, customerName, items }: InvoiceProps) => {
  const total = items.reduce((sum, item) => sum + item.quantity * item.price, 0)

  return (
    <Document>
      <Page size="A4" style={styles.page}>
        <Text style={styles.header}>請求書</Text>

        <View style={styles.section}>
          <Text>請求書番号: {invoiceNumber}</Text>
          <Text>発行日: {date}</Text>
          <Text>お客様名: {customerName}</Text>
        </View>

        <View style={styles.table}>
          {/* ヘッダー */}
          <View style={[styles.tableRow, styles.tableHeader]}>
            <View style={styles.tableCol}>
              <Text style={styles.tableCell}>品名</Text>
            </View>
            <View style={styles.tableCol}>
              <Text style={styles.tableCell}>数量</Text>
            </View>
            <View style={styles.tableCol}>
              <Text style={styles.tableCell}>単価</Text>
            </View>
            <View style={styles.tableCol}>
              <Text style={styles.tableCell}>金額</Text>
            </View>
          </View>

          {/* 品目 */}
          {items.map((item, index) => (
            <View key={index} style={styles.tableRow}>
              <View style={styles.tableCol}>
                <Text style={styles.tableCell}>{item.description}</Text>
              </View>
              <View style={styles.tableCol}>
                <Text style={styles.tableCell}>{item.quantity}</Text>
              </View>
              <View style={styles.tableCol}>
                <Text style={styles.tableCell}>¥{item.price.toLocaleString()}</Text>
              </View>
              <View style={styles.tableCol}>
                <Text style={styles.tableCell}>
                  ¥{(item.quantity * item.price).toLocaleString()}
                </Text>
              </View>
            </View>
          ))}
        </View>

        <Text style={styles.total}>合計: ¥{total.toLocaleString()}</Text>
      </Page>
    </Document>
  )
}

export default InvoiceDocument
```

## Excel処理

### ExcelJS

#### 特徴

- **高機能**: セルのスタイル、数式、グラフ対応
- **読み書き**: 既存ファイルの編集可能
- **大容量**: ストリーミング対応
- **型安全**: TypeScript完全サポート

#### インストール

```bash
npm install exceljs
```

#### 基本的な使い方

```typescript
import ExcelJS from 'exceljs'

async function createExcel() {
  const workbook = new ExcelJS.Workbook()
  const worksheet = workbook.addWorksheet('Sheet1')

  // ヘッダー
  worksheet.columns = [
    { header: 'ID', key: 'id', width: 10 },
    { header: '名前', key: 'name', width: 20 },
    { header: 'メール', key: 'email', width: 30 },
  ]

  // データ追加
  worksheet.addRow({ id: 1, name: '山田太郎', email: 'yamada@example.com' })
  worksheet.addRow({ id: 2, name: '佐藤花子', email: 'sato@example.com' })

  // ファイル保存
  await workbook.xlsx.writeFile('output.xlsx')
}
```

#### スタイリング

```typescript
import ExcelJS from 'exceljs'

async function createStyledExcel() {
  const workbook = new ExcelJS.Workbook()
  const worksheet = workbook.addWorksheet('レポート')

  // ヘッダー行
  const headerRow = worksheet.addRow(['商品名', '数量', '単価', '金額'])

  // ヘッダーのスタイル
  headerRow.font = { bold: true, size: 12 }
  headerRow.fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFD9D9D9' },
  }
  headerRow.alignment = { vertical: 'middle', horizontal: 'center' }

  // データ追加
  worksheet.addRow(['商品A', 10, 1000, 10000])
  worksheet.addRow(['商品B', 5, 2000, 10000])
  worksheet.addRow(['商品C', 3, 3000, 9000])

  // 合計行
  const totalRow = worksheet.addRow(['合計', '', '', 29000])
  totalRow.font = { bold: true }
  totalRow.getCell(4).fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFFFFF00' },
  }

  // 列幅調整
  worksheet.columns = [
    { key: 'name', width: 20 },
    { key: 'quantity', width: 10 },
    { key: 'price', width: 15 },
    { key: 'total', width: 15 },
  ]

  // 数値フォーマット
  worksheet.getColumn(3).numFmt = '¥#,##0'
  worksheet.getColumn(4).numFmt = '¥#,##0'

  await workbook.xlsx.writeFile('styled.xlsx')
}
```

#### データエクスポート

```typescript
import ExcelJS from 'exceljs'

interface User {
  id: number
  name: string
  email: string
  age: number
  createdAt: Date
}

async function exportUsers(users: User[]) {
  const workbook = new ExcelJS.Workbook()
  const worksheet = workbook.addWorksheet('ユーザー一覧')

  // 列定義
  worksheet.columns = [
    { header: 'ID', key: 'id', width: 10 },
    { header: '名前', key: 'name', width: 20 },
    { header: 'メール', key: 'email', width: 30 },
    { header: '年齢', key: 'age', width: 10 },
    { header: '登録日', key: 'createdAt', width: 20 },
  ]

  // ヘッダースタイル
  worksheet.getRow(1).font = { bold: true }
  worksheet.getRow(1).fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FF4472C4' },
  }
  worksheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } }

  // データ追加
  users.forEach((user) => {
    worksheet.addRow({
      id: user.id,
      name: user.name,
      email: user.email,
      age: user.age,
      createdAt: user.createdAt,
    })
  })

  // 日付フォーマット
  worksheet.getColumn(5).numFmt = 'yyyy/mm/dd'

  // オートフィルター
  worksheet.autoFilter = {
    from: 'A1',
    to: 'E1',
  }

  // ファイル生成
  const buffer = await workbook.xlsx.writeBuffer()
  return buffer
}
```

#### Next.js API Route

```typescript
// app/api/export/users/route.ts
import { NextRequest, NextResponse } from 'next/server'
import ExcelJS from 'exceljs'

export async function GET(request: NextRequest) {
  // データ取得（例）
  const users = await fetchUsers()

  // Excelワークブック作成
  const workbook = new ExcelJS.Workbook()
  const worksheet = workbook.addWorksheet('ユーザー一覧')

  worksheet.columns = [
    { header: 'ID', key: 'id', width: 10 },
    { header: '名前', key: 'name', width: 20 },
    { header: 'メール', key: 'email', width: 30 },
  ]

  users.forEach((user) => {
    worksheet.addRow(user)
  })

  // バッファ生成
  const buffer = await workbook.xlsx.writeBuffer()

  // レスポンス
  return new NextResponse(buffer, {
    headers: {
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': 'attachment; filename=users.xlsx',
    },
  })
}
```

### SheetJS (xlsx)

#### 特徴

- **軽量**: ExcelJSより軽量
- **シンプル**: 基本機能のみ
- **互換性**: 多様なフォーマット対応

#### インストール

```bash
npm install xlsx
```

#### 基本的な使い方

```typescript
import XLSX from 'xlsx'

// JSON to Excel
function jsonToExcel(data: any[], filename: string) {
  // ワークブック作成
  const workbook = XLSX.utils.book_new()

  // ワークシート作成
  const worksheet = XLSX.utils.json_to_sheet(data)

  // ワークブックに追加
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Sheet1')

  // ファイル出力
  XLSX.writeFile(workbook, filename)
}

// 使用例
const users = [
  { id: 1, name: '山田太郎', email: 'yamada@example.com' },
  { id: 2, name: '佐藤花子', email: 'sato@example.com' },
]

jsonToExcel(users, 'users.xlsx')
```

## 画像処理

### Sharp

#### 特徴

- **高速**: libvipsベース、ネイティブ実装
- **多機能**: リサイズ、圧縮、変換、合成
- **フォーマット**: JPEG, PNG, WebP, AVIF等
- **メモリ効率**: ストリーミング処理

#### インストール

```bash
npm install sharp
```

#### 基本的な使い方

```typescript
import sharp from 'sharp'

// リサイズ
await sharp('input.jpg')
  .resize(800, 600)
  .toFile('output.jpg')

// アスペクト比を維持
await sharp('input.jpg')
  .resize(800, 600, { fit: 'inside' })
  .toFile('output.jpg')

// フォーマット変換
await sharp('input.jpg')
  .toFormat('webp')
  .toFile('output.webp')

// 圧縮
await sharp('input.jpg')
  .jpeg({ quality: 80 })
  .toFile('compressed.jpg')
```

#### サムネイル生成

```typescript
import sharp from 'sharp'

async function generateThumbnails(inputPath: string, outputPrefix: string) {
  const sizes = [
    { width: 150, height: 150, suffix: 'thumbnail' },
    { width: 300, height: 300, suffix: 'small' },
    { width: 800, height: 600, suffix: 'medium' },
    { width: 1920, height: 1080, suffix: 'large' },
  ]

  for (const size of sizes) {
    await sharp(inputPath)
      .resize(size.width, size.height, {
        fit: 'cover',
        position: 'center',
      })
      .toFile(`${outputPrefix}-${size.suffix}.jpg`)
  }
}

// 使用例
await generateThumbnails('photo.jpg', 'output')
```

#### 画像最適化

```typescript
import sharp from 'sharp'

async function optimizeImage(inputPath: string, outputPath: string) {
  await sharp(inputPath)
    .resize(1920, 1080, {
      fit: 'inside',
      withoutEnlargement: true,
    })
    .jpeg({
      quality: 80,
      progressive: true,
    })
    .toFile(outputPath)
}
```

#### Next.js API Route（画像アップロード）

```typescript
// app/api/upload/image/route.ts
import { NextRequest, NextResponse } from 'next/server'
import sharp from 'sharp'
import { writeFile } from 'fs/promises'
import path from 'path'

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File

    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 })
    }

    // バッファに変換
    const bytes = await file.arrayBuffer()
    const buffer = Buffer.from(bytes)

    // 画像処理
    const optimized = await sharp(buffer)
      .resize(1920, 1080, {
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({ quality: 80 })
      .toBuffer()

    // 保存
    const filename = `${Date.now()}.jpg`
    const filepath = path.join(process.cwd(), 'public/uploads', filename)
    await writeFile(filepath, optimized)

    return NextResponse.json({
      success: true,
      filename,
      url: `/uploads/${filename}`,
    })
  } catch (error) {
    console.error('Upload error:', error)
    return NextResponse.json({ error: 'Upload failed' }, { status: 500 })
  }
}
```

## ベストプラクティス

### 1. ストリーミング処理

```typescript
import { createReadStream, createWriteStream } from 'fs'
import sharp from 'sharp'

// メモリ効率的な処理
createReadStream('input.jpg')
  .pipe(sharp().resize(800, 600))
  .pipe(createWriteStream('output.jpg'))
```

### 2. エラーハンドリング

```typescript
import sharp from 'sharp'

async function safeImageProcessing(inputPath: string) {
  try {
    const metadata = await sharp(inputPath).metadata()
    console.log('Image format:', metadata.format)
    console.log('Dimensions:', metadata.width, 'x', metadata.height)

    // 処理
    await sharp(inputPath).resize(800, 600).toFile('output.jpg')
  } catch (error) {
    if (error instanceof Error) {
      console.error('Image processing failed:', error.message)
    }
    throw error
  }
}
```

### 3. 一時ファイルの管理

```typescript
import { unlink } from 'fs/promises'
import sharp from 'sharp'

async function processAndCleanup(tempPath: string, outputPath: string) {
  try {
    await sharp(tempPath).resize(800, 600).toFile(outputPath)
  } finally {
    // 一時ファイルを削除
    await unlink(tempPath).catch(() => {})
  }
}
```

### 4. バッチ処理

```typescript
import sharp from 'sharp'
import { readdir } from 'fs/promises'
import path from 'path'

async function batchOptimize(inputDir: string, outputDir: string) {
  const files = await readdir(inputDir)

  const promises = files
    .filter((file) => /\.(jpg|jpeg|png)$/i.test(file))
    .map(async (file) => {
      const inputPath = path.join(inputDir, file)
      const outputPath = path.join(outputDir, file)

      await sharp(inputPath)
        .resize(1920, 1080, { fit: 'inside' })
        .jpeg({ quality: 80 })
        .toFile(outputPath)
    })

  await Promise.all(promises)
}
```

## 参考リンク

### PDF
- [PDFKit 公式ドキュメント](https://pdfkit.org/)
- [Puppeteer 公式ドキュメント](https://pptr.dev/)
- [@react-pdf/renderer 公式ドキュメント](https://react-pdf.org/)

### Excel
- [ExcelJS 公式ドキュメント](https://github.com/exceljs/exceljs)
- [SheetJS 公式ドキュメント](https://sheetjs.com/)

### 画像
- [Sharp 公式ドキュメント](https://sharp.pixelplumbing.com/)
- [Jimp 公式ドキュメント](https://github.com/jimp-dev/jimp)
