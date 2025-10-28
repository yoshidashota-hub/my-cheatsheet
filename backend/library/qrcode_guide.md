# QRコード生成・読み取りガイド

## 目次
- [概要](#概要)
- [主要ライブラリ比較](#主要ライブラリ比較)
- [qrcode - QRコード生成](#qrcode---qrコード生成)
- [jsQR - QRコード読み取り](#jsqr---qrコード読み取り)
- [react-qr-code - React専用コンポーネント](#react-qr-code---react専用コンポーネント)
- [Next.js統合例](#nextjs統合例)
- [実践的な使用例](#実践的な使用例)
- [ベストプラクティス](#ベストプラクティス)

## 概要

QRコードは二次元バーコードの一種で、URLや文字列データを視覚的にエンコードします。認証、決済、チケット管理、情報共有など幅広い用途で使用されています。

### QRコードの特徴

- **高密度情報**: 最大7,089文字の数字データを格納可能
- **エラー訂正**: 最大30%のコード損傷でも読み取り可能
- **高速読み取り**: スマートフォンカメラで瞬時にスキャン
- **多用途対応**: URL、vCard、WiFi情報、決済情報など

### 主なユースケース

1. **認証システム**: 2FA、ログイン、本人確認
2. **決済**: QRコード決済、請求書表示
3. **チケット**: イベントチケット、搭乗券
4. **情報共有**: vCard、WiFi設定、アプリダウンロード
5. **在庫管理**: 商品追跡、倉庫管理

## 主要ライブラリ比較

| ライブラリ | 用途 | サイズ | 特徴 |
|----------|------|--------|------|
| qrcode | 生成 | 53.4KB | Node.js/ブラウザ両対応、多様な出力形式 |
| jsQR | 読み取り | 44.3KB | ブラウザ専用、WebRTC対応 |
| react-qr-code | 生成 | 5.1KB | React専用、SVG出力、軽量 |
| qr-scanner | 読み取り | 46.2KB | Web Worker対応、高性能 |

### 選択基準

**qrcode を使用すべき場合**:
- サーバーサイドでQRコード生成が必要
- PNG/JPEG形式での出力が必要
- Node.jsとブラウザの両方で動作させたい

**react-qr-code を使用すべき場合**:
- Reactアプリケーション内でQRコードを表示
- SVG形式で軽量に表示したい
- コンポーネントとして再利用したい

**jsQR を使用すべき場合**:
- ブラウザでQRコード読み取り機能を実装
- WebRTCと統合してカメラからスキャン
- シンプルな読み取り処理のみ必要

## qrcode - QRコード生成

### インストール

```bash
npm install qrcode
npm install --save-dev @types/qrcode
```

### 基本的な使用方法

#### 1. Data URL形式で生成（ブラウザ）

```typescript
import QRCode from 'qrcode'

// Data URLとして生成
const generateQRCode = async (text: string): Promise<string> => {
  try {
    const dataUrl = await QRCode.toDataURL(text, {
      errorCorrectionLevel: 'M',
      type: 'image/png',
      quality: 0.92,
      margin: 1,
      color: {
        dark: '#000000',
        light: '#FFFFFF',
      },
      width: 300,
    })
    return dataUrl
  } catch (error) {
    console.error('QRコード生成エラー:', error)
    throw error
  }
}

// 使用例
const qrCodeDataUrl = await generateQRCode('https://example.com')
// img要素のsrcに設定: <img src={qrCodeDataUrl} />
```

#### 2. Canvas要素に直接描画

```typescript
import QRCode from 'qrcode'

const drawQRCodeToCanvas = async (
  canvasElement: HTMLCanvasElement,
  text: string
) => {
  try {
    await QRCode.toCanvas(canvasElement, text, {
      errorCorrectionLevel: 'H',
      width: 400,
      margin: 2,
    })
  } catch (error) {
    console.error('Canvas描画エラー:', error)
    throw error
  }
}

// 使用例
const canvas = document.getElementById('qr-canvas') as HTMLCanvasElement
await drawQRCodeToCanvas(canvas, 'https://example.com')
```

#### 3. SVG文字列として生成

```typescript
import QRCode from 'qrcode'

const generateQRCodeSVG = async (text: string): Promise<string> => {
  try {
    const svg = await QRCode.toString(text, {
      type: 'svg',
      errorCorrectionLevel: 'M',
      margin: 1,
      color: {
        dark: '#000',
        light: '#fff',
      },
    })
    return svg
  } catch (error) {
    console.error('SVG生成エラー:', error)
    throw error
  }
}

// 使用例
const svgString = await generateQRCodeSVG('https://example.com')
// dangerouslySetInnerHTMLで挿入: <div dangerouslySetInnerHTML={{ __html: svgString }} />
```

#### 4. Node.jsでファイルとして保存

```typescript
import QRCode from 'qrcode'
import fs from 'fs/promises'

const generateQRCodeFile = async (
  text: string,
  outputPath: string
): Promise<void> => {
  try {
    // PNG形式で保存
    await QRCode.toFile(outputPath, text, {
      errorCorrectionLevel: 'M',
      type: 'png',
      quality: 0.92,
      margin: 1,
      width: 500,
    })
    console.log(`QRコードを保存しました: ${outputPath}`)
  } catch (error) {
    console.error('ファイル保存エラー:', error)
    throw error
  }
}

// 使用例
await generateQRCodeFile('https://example.com', './qrcode.png')
```

### 高度な設定

#### エラー訂正レベル

```typescript
import QRCode from 'qrcode'

type ErrorCorrectionLevel = 'L' | 'M' | 'Q' | 'H'

const generateQRWithErrorCorrection = async (
  text: string,
  level: ErrorCorrectionLevel
): Promise<string> => {
  // L: 約7%  - 最小サイズ、データ優先
  // M: 約15% - バランス型（デフォルト）
  // Q: 約25% - 高い耐久性
  // H: 約30% - 最大耐久性、ロゴ埋め込み可能

  return await QRCode.toDataURL(text, {
    errorCorrectionLevel: level,
    width: 300,
  })
}

// 使用例: ロゴを中央に配置する場合はHレベル推奨
const qrWithLogo = await generateQRWithErrorCorrection(
  'https://example.com',
  'H'
)
```

#### カスタムカラー

```typescript
const generateColoredQRCode = async (text: string): Promise<string> => {
  return await QRCode.toDataURL(text, {
    errorCorrectionLevel: 'M',
    width: 300,
    color: {
      dark: '#1e40af', // 青色
      light: '#f0f9ff', // 薄い青背景
    },
  })
}

// グラデーション風（疑似的）
const generateGradientStyleQRCode = async (text: string): Promise<string> => {
  return await QRCode.toDataURL(text, {
    errorCorrectionLevel: 'H',
    width: 400,
    color: {
      dark: '#7c3aed', // 紫
      light: '#faf5ff', // 薄紫背景
    },
  })
}
```

#### 複雑なデータのエンコード

```typescript
// vCard形式
const generateVCardQR = async (contact: {
  name: string
  email: string
  phone: string
  company: string
}): Promise<string> => {
  const vcard = `BEGIN:VCARD
VERSION:3.0
FN:${contact.name}
ORG:${contact.company}
TEL:${contact.phone}
EMAIL:${contact.email}
END:VCARD`

  return await QRCode.toDataURL(vcard, {
    errorCorrectionLevel: 'M',
    width: 350,
  })
}

// WiFi設定
const generateWiFiQR = async (wifi: {
  ssid: string
  password: string
  security: 'WPA' | 'WEP' | 'nopass'
}): Promise<string> => {
  const wifiString = `WIFI:T:${wifi.security};S:${wifi.ssid};P:${wifi.password};;`

  return await QRCode.toDataURL(wifiString, {
    errorCorrectionLevel: 'H',
    width: 350,
  })
}

// 使用例
const contactQR = await generateVCardQR({
  name: '山田太郎',
  email: 'yamada@example.com',
  phone: '+81-90-1234-5678',
  company: '株式会社Example',
})

const wifiQR = await generateWiFiQR({
  ssid: 'MyWiFi',
  password: 'password123',
  security: 'WPA',
})
```

## jsQR - QRコード読み取り

### インストール

```bash
npm install jsqr
```

### 基本的な使用方法

#### 画像ファイルからQRコード読み取り

```typescript
import jsQR from 'jsqr'

const readQRCodeFromImage = async (
  imageFile: File
): Promise<string | null> => {
  return new Promise((resolve, reject) => {
    const img = new Image()
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')

    img.onload = () => {
      if (!ctx) {
        reject(new Error('Canvas context取得失敗'))
        return
      }

      canvas.width = img.width
      canvas.height = img.height
      ctx.drawImage(img, 0, 0)

      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
      const code = jsQR(imageData.data, imageData.width, imageData.height)

      if (code) {
        resolve(code.data)
      } else {
        resolve(null)
      }
    }

    img.onerror = () => {
      reject(new Error('画像読み込み失敗'))
    }

    img.src = URL.createObjectURL(imageFile)
  })
}

// 使用例
const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
  const file = event.target.files?.[0]
  if (!file) return

  try {
    const qrData = await readQRCodeFromImage(file)
    if (qrData) {
      console.log('読み取ったデータ:', qrData)
    } else {
      console.log('QRコードが見つかりませんでした')
    }
  } catch (error) {
    console.error('読み取りエラー:', error)
  }
}
```

#### Webカメラからリアルタイム読み取り

```typescript
'use client'

import { useEffect, useRef, useState } from 'react'
import jsQR from 'jsqr'

export default function QRScanner() {
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [scannedData, setScannedData] = useState<string | null>(null)
  const [isScanning, setIsScanning] = useState(false)

  useEffect(() => {
    let animationFrameId: number

    const startScanning = async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'environment' }, // 背面カメラ
        })

        if (videoRef.current) {
          videoRef.current.srcObject = stream
          videoRef.current.play()
          setIsScanning(true)
          scanFrame()
        }
      } catch (error) {
        console.error('カメラアクセスエラー:', error)
      }
    }

    const scanFrame = () => {
      const video = videoRef.current
      const canvas = canvasRef.current
      const ctx = canvas?.getContext('2d')

      if (video && canvas && ctx && video.readyState === video.HAVE_ENOUGH_DATA) {
        canvas.width = video.videoWidth
        canvas.height = video.videoHeight
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height)

        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
        const code = jsQR(imageData.data, imageData.width, imageData.height)

        if (code) {
          setScannedData(code.data)
          // 読み取り成功後、スキャン停止
          stopScanning()
          return
        }
      }

      animationFrameId = requestAnimationFrame(scanFrame)
    }

    const stopScanning = () => {
      if (videoRef.current?.srcObject) {
        const stream = videoRef.current.srcObject as MediaStream
        stream.getTracks().forEach((track) => track.stop())
      }
      if (animationFrameId) {
        cancelAnimationFrame(animationFrameId)
      }
      setIsScanning(false)
    }

    startScanning()

    return () => {
      stopScanning()
    }
  }, [])

  return (
    <div className="flex flex-col items-center gap-4">
      <div className="relative">
        <video ref={videoRef} className="w-full max-w-md rounded-lg" />
        <canvas ref={canvasRef} className="hidden" />
        {isScanning && (
          <div className="absolute inset-0 border-4 border-blue-500 rounded-lg pointer-events-none">
            <div className="absolute top-1/2 left-0 right-0 h-0.5 bg-blue-500 animate-pulse" />
          </div>
        )}
      </div>
      {scannedData && (
        <div className="p-4 bg-green-100 rounded-lg">
          <p className="font-semibold">読み取り成功:</p>
          <p className="break-all">{scannedData}</p>
        </div>
      )}
    </div>
  )
}
```

#### 読み取り品質の向上

```typescript
import jsQR from 'jsqr'

const readQRCodeWithEnhancement = (
  canvas: HTMLCanvasElement
): string | null => {
  const ctx = canvas.getContext('2d')
  if (!ctx) return null

  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)

  // まず通常読み取り
  let code = jsQR(imageData.data, imageData.width, imageData.height, {
    inversionAttempts: 'dontInvert',
  })

  if (code) return code.data

  // 反転して再試行
  code = jsQR(imageData.data, imageData.width, imageData.height, {
    inversionAttempts: 'invertFirst',
  })

  if (code) return code.data

  // 複数パターンで試行
  code = jsQR(imageData.data, imageData.width, imageData.height, {
    inversionAttempts: 'attemptBoth',
  })

  return code?.data || null
}
```

## react-qr-code - React専用コンポーネント

### インストール

```bash
npm install react-qr-code
```

### 基本的な使用方法

```typescript
'use client'

import { QRCodeSVG } from 'react-qr-code'

export default function QRCodeDisplay({ value }: { value: string }) {
  return (
    <div className="p-4">
      <QRCodeSVG
        value={value}
        size={256}
        level="M"
        bgColor="#ffffff"
        fgColor="#000000"
      />
    </div>
  )
}
```

### カスタマイズ例

```typescript
'use client'

import { QRCodeSVG } from 'react-qr-code'

interface QRCodeProps {
  value: string
  size?: number
  level?: 'L' | 'M' | 'Q' | 'H'
  includeMargin?: boolean
  imageSettings?: {
    src: string
    height: number
    width: number
    excavate: boolean
  }
}

export default function CustomQRCode({
  value,
  size = 256,
  level = 'M',
  includeMargin = true,
  imageSettings,
}: QRCodeProps) {
  return (
    <div className="flex flex-col items-center gap-4">
      <div className="p-4 bg-white rounded-lg shadow-lg">
        <QRCodeSVG
          value={value}
          size={size}
          level={level}
          bgColor="#ffffff"
          fgColor="#1e40af"
          includeMargin={includeMargin}
          imageSettings={imageSettings}
        />
      </div>
      <p className="text-sm text-gray-600 break-all max-w-md">{value}</p>
    </div>
  )
}
```

### ロゴ埋め込み

```typescript
'use client'

import { QRCodeSVG } from 'react-qr-code'

export default function QRCodeWithLogo({ value }: { value: string }) {
  return (
    <QRCodeSVG
      value={value}
      size={300}
      level="H" // ロゴ埋め込み時は高エラー訂正レベル必須
      bgColor="#ffffff"
      fgColor="#000000"
      imageSettings={{
        src: '/logo.png',
        height: 50,
        width: 50,
        excavate: true, // QRコードをくり抜いてロゴを配置
      }}
    />
  )
}
```

### ダウンロード機能付きQRコード

```typescript
'use client'

import { QRCodeSVG } from 'react-qr-code'
import { useRef } from 'react'

export default function DownloadableQRCode({ value }: { value: string }) {
  const qrRef = useRef<HTMLDivElement>(null)

  const downloadQRCode = () => {
    const svg = qrRef.current?.querySelector('svg')
    if (!svg) return

    const svgData = new XMLSerializer().serializeToString(svg)
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')
    const img = new Image()

    img.onload = () => {
      canvas.width = img.width
      canvas.height = img.height
      ctx?.drawImage(img, 0, 0)

      const pngUrl = canvas.toDataURL('image/png')
      const downloadLink = document.createElement('a')
      downloadLink.href = pngUrl
      downloadLink.download = 'qrcode.png'
      downloadLink.click()
    }

    img.src = 'data:image/svg+xml;base64,' + btoa(svgData)
  }

  return (
    <div className="flex flex-col items-center gap-4">
      <div ref={qrRef}>
        <QRCodeSVG value={value} size={300} level="M" />
      </div>
      <button
        onClick={downloadQRCode}
        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
      >
        QRコードをダウンロード
      </button>
    </div>
  )
}
```

## Next.js統合例

### API Route: QRコード生成

```typescript
// app/api/qrcode/generate/route.ts
import { NextRequest, NextResponse } from 'next/server'
import QRCode from 'qrcode'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { text, format = 'png', options = {} } = body

    if (!text) {
      return NextResponse.json(
        { success: false, error: 'テキストが必要です' },
        { status: 400 }
      )
    }

    const defaultOptions = {
      errorCorrectionLevel: 'M',
      type: 'image/png',
      quality: 0.92,
      margin: 1,
      width: 300,
      ...options,
    }

    let result: string

    if (format === 'svg') {
      result = await QRCode.toString(text, {
        ...defaultOptions,
        type: 'svg',
      })
    } else {
      result = await QRCode.toDataURL(text, defaultOptions)
    }

    return NextResponse.json({
      success: true,
      data: result,
      format,
    })
  } catch (error) {
    console.error('QRコード生成エラー:', error)
    return NextResponse.json(
      { success: false, error: 'QRコード生成に失敗しました' },
      { status: 500 }
    )
  }
}
```

### API Route: QRコード読み取り

```typescript
// app/api/qrcode/read/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Jimp from 'jimp'
import jsQR from 'jsqr'

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File

    if (!file) {
      return NextResponse.json(
        { success: false, error: 'ファイルが必要です' },
        { status: 400 }
      )
    }

    const buffer = Buffer.from(await file.arrayBuffer())
    const image = await Jimp.read(buffer)

    const imageData = {
      data: new Uint8ClampedArray(image.bitmap.data),
      width: image.bitmap.width,
      height: image.bitmap.height,
    }

    const code = jsQR(imageData.data, imageData.width, imageData.height, {
      inversionAttempts: 'attemptBoth',
    })

    if (code) {
      return NextResponse.json({
        success: true,
        data: code.data,
      })
    } else {
      return NextResponse.json(
        { success: false, error: 'QRコードが見つかりませんでした' },
        { status: 404 }
      )
    }
  } catch (error) {
    console.error('QRコード読み取りエラー:', error)
    return NextResponse.json(
      { success: false, error: 'QRコード読み取りに失敗しました' },
      { status: 500 }
    )
  }
}
```

### フロントエンド: QRコード生成UI

```typescript
'use client'

import { useState } from 'react'
import { QRCodeSVG } from 'react-qr-code'

export default function QRCodeGenerator() {
  const [inputText, setInputText] = useState('')
  const [qrValue, setQrValue] = useState('')
  const [errorLevel, setErrorLevel] = useState<'L' | 'M' | 'Q' | 'H'>('M')

  const handleGenerate = () => {
    if (inputText.trim()) {
      setQrValue(inputText)
    }
  }

  const handleClear = () => {
    setInputText('')
    setQrValue('')
  }

  return (
    <div className="max-w-2xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">QRコード生成</h1>

      <div className="space-y-4 mb-6">
        <div>
          <label className="block text-sm font-medium mb-2">
            エンコードするテキスト
          </label>
          <textarea
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            className="w-full p-3 border rounded-lg focus:ring-2 focus:ring-blue-500"
            rows={4}
            placeholder="URL、テキスト、またはその他のデータを入力..."
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-2">
            エラー訂正レベル
          </label>
          <select
            value={errorLevel}
            onChange={(e) => setErrorLevel(e.target.value as 'L' | 'M' | 'Q' | 'H')}
            className="w-full p-3 border rounded-lg focus:ring-2 focus:ring-blue-500"
          >
            <option value="L">L (約7%) - 最小サイズ</option>
            <option value="M">M (約15%) - 標準</option>
            <option value="Q">Q (約25%) - 高耐久性</option>
            <option value="H">H (約30%) - ロゴ埋め込み可</option>
          </select>
        </div>

        <div className="flex gap-2">
          <button
            onClick={handleGenerate}
            disabled={!inputText.trim()}
            className="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
          >
            QRコード生成
          </button>
          <button
            onClick={handleClear}
            className="px-6 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300"
          >
            クリア
          </button>
        </div>
      </div>

      {qrValue && (
        <div className="flex flex-col items-center gap-4 p-6 bg-gray-50 rounded-lg">
          <div className="p-4 bg-white rounded-lg shadow">
            <QRCodeSVG value={qrValue} size={300} level={errorLevel} />
          </div>
          <p className="text-sm text-gray-600 text-center break-all max-w-md">
            {qrValue}
          </p>
        </div>
      )}
    </div>
  )
}
```

### フロントエンド: QRコードスキャナーUI

```typescript
'use client'

import { useState, useRef } from 'react'

export default function QRCodeReader() {
  const [scannedData, setScannedData] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const handleFileUpload = async (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = event.target.files?.[0]
    if (!file) return

    setError(null)
    setScannedData(null)

    const formData = new FormData()
    formData.append('file', file)

    try {
      const response = await fetch('/api/qrcode/read', {
        method: 'POST',
        body: formData,
      })

      const result = await response.json()

      if (result.success) {
        setScannedData(result.data)
      } else {
        setError(result.error || 'QRコードの読み取りに失敗しました')
      }
    } catch (err) {
      setError('エラーが発生しました')
      console.error(err)
    }
  }

  const handleUploadClick = () => {
    fileInputRef.current?.click()
  }

  return (
    <div className="max-w-2xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">QRコード読み取り</h1>

      <div className="space-y-4">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleFileUpload}
          className="hidden"
        />

        <button
          onClick={handleUploadClick}
          className="w-full px-6 py-4 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium"
        >
          画像をアップロード
        </button>

        {scannedData && (
          <div className="p-6 bg-green-50 border border-green-200 rounded-lg">
            <h2 className="text-lg font-semibold mb-2 text-green-800">
              読み取り成功
            </h2>
            <p className="break-all text-gray-800">{scannedData}</p>
            {scannedData.startsWith('http') && (
              <a
                href={scannedData}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-block mt-3 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
              >
                リンクを開く
              </a>
            )}
          </div>
        )}

        {error && (
          <div className="p-6 bg-red-50 border border-red-200 rounded-lg">
            <h2 className="text-lg font-semibold mb-2 text-red-800">エラー</h2>
            <p className="text-gray-800">{error}</p>
          </div>
        )}
      </div>
    </div>
  )
}
```

## 実践的な使用例

### 1. 2FA認証用QRコード

```typescript
// app/api/auth/totp/setup/route.ts
import { NextRequest, NextResponse } from 'next/server'
import QRCode from 'qrcode'
import { authenticator } from 'otplib'

export async function POST(request: NextRequest) {
  try {
    const { userId, userEmail } = await request.json()

    // シークレットキーを生成
    const secret = authenticator.generateSecret()

    // TOTP URI形式
    const otpauth = authenticator.keyuri(
      userEmail,
      'MyApp',
      secret
    )

    // QRコードを生成
    const qrCodeDataUrl = await QRCode.toDataURL(otpauth, {
      errorCorrectionLevel: 'H',
      width: 300,
    })

    // シークレットをデータベースに保存（実際の実装）
    // await prisma.user.update({
    //   where: { id: userId },
    //   data: { totpSecret: secret },
    // })

    return NextResponse.json({
      success: true,
      qrCode: qrCodeDataUrl,
      secret, // バックアップ用に表示
    })
  } catch (error) {
    console.error('TOTP設定エラー:', error)
    return NextResponse.json(
      { success: false, error: 'TOTP設定に失敗しました' },
      { status: 500 }
    )
  }
}
```

```typescript
'use client'

import { useState, useEffect } from 'react'

export default function TwoFactorSetup() {
  const [qrCode, setQrCode] = useState<string | null>(null)
  const [secret, setSecret] = useState<string | null>(null)
  const [verificationCode, setVerificationCode] = useState('')

  useEffect(() => {
    setupTOTP()
  }, [])

  const setupTOTP = async () => {
    const response = await fetch('/api/auth/totp/setup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: 'user-123',
        userEmail: 'user@example.com',
      }),
    })

    const data = await response.json()
    if (data.success) {
      setQrCode(data.qrCode)
      setSecret(data.secret)
    }
  }

  const verifyCode = async () => {
    // 検証ロジック
    console.log('検証コード:', verificationCode)
  }

  return (
    <div className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">二段階認証の設定</h1>

      {qrCode && (
        <div className="space-y-4">
          <div className="flex justify-center">
            <img src={qrCode} alt="TOTP QR Code" className="w-64 h-64" />
          </div>

          <div className="p-4 bg-gray-100 rounded">
            <p className="text-sm font-medium mb-2">
              手動入力用シークレット:
            </p>
            <code className="text-xs break-all">{secret}</code>
          </div>

          <div>
            <label className="block text-sm font-medium mb-2">
              認証コードを入力
            </label>
            <input
              type="text"
              value={verificationCode}
              onChange={(e) => setVerificationCode(e.target.value)}
              className="w-full p-3 border rounded"
              placeholder="6桁のコード"
              maxLength={6}
            />
          </div>

          <button
            onClick={verifyCode}
            className="w-full px-4 py-3 bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            設定を完了
          </button>
        </div>
      )}
    </div>
  )
}
```

### 2. 決済用QRコード

```typescript
// app/api/payment/qrcode/route.ts
import { NextRequest, NextResponse } from 'next/server'
import QRCode from 'qrcode'
import crypto from 'crypto'

interface PaymentRequest {
  amount: number
  currency: string
  merchantId: string
  orderId: string
}

export async function POST(request: NextRequest) {
  try {
    const body: PaymentRequest = await request.json()

    // 決済リンクを生成
    const paymentId = crypto.randomUUID()
    const paymentUrl = `https://payment.example.com/pay?id=${paymentId}&amount=${body.amount}&currency=${body.currency}`

    // データベースに決済情報を保存
    // await prisma.payment.create({
    //   data: {
    //     id: paymentId,
    //     amount: body.amount,
    //     currency: body.currency,
    //     merchantId: body.merchantId,
    //     orderId: body.orderId,
    //     status: 'pending',
    //   },
    // })

    // QRコード生成
    const qrCode = await QRCode.toDataURL(paymentUrl, {
      errorCorrectionLevel: 'H',
      width: 400,
      color: {
        dark: '#000000',
        light: '#FFFFFF',
      },
    })

    return NextResponse.json({
      success: true,
      paymentId,
      qrCode,
      paymentUrl,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000), // 15分後
    })
  } catch (error) {
    console.error('決済QRコード生成エラー:', error)
    return NextResponse.json(
      { success: false, error: '決済QRコード生成に失敗しました' },
      { status: 500 }
    )
  }
}
```

```typescript
'use client'

import { useState } from 'react'

export default function PaymentQRCode() {
  const [qrCode, setQrCode] = useState<string | null>(null)
  const [paymentId, setPaymentId] = useState<string | null>(null)
  const [amount, setAmount] = useState('1000')

  const generatePaymentQR = async () => {
    const response = await fetch('/api/payment/qrcode', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: parseInt(amount),
        currency: 'JPY',
        merchantId: 'merchant-123',
        orderId: 'order-456',
      }),
    })

    const data = await response.json()
    if (data.success) {
      setQrCode(data.qrCode)
      setPaymentId(data.paymentId)
    }
  }

  return (
    <div className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">QRコード決済</h1>

      <div className="space-y-4 mb-6">
        <div>
          <label className="block text-sm font-medium mb-2">金額</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="w-full p-3 border rounded"
            placeholder="金額を入力"
          />
        </div>

        <button
          onClick={generatePaymentQR}
          className="w-full px-4 py-3 bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          決済QRコード生成
        </button>
      </div>

      {qrCode && (
        <div className="space-y-4">
          <div className="flex flex-col items-center p-6 bg-gray-50 rounded-lg">
            <img src={qrCode} alt="Payment QR Code" className="w-80 h-80" />
            <p className="text-2xl font-bold mt-4">¥{amount}</p>
            <p className="text-sm text-gray-600">
              決済ID: {paymentId}
            </p>
          </div>
          <p className="text-xs text-gray-500 text-center">
            このQRコードは15分間有効です
          </p>
        </div>
      )}
    </div>
  )
}
```

### 3. イベントチケット用QRコード

```typescript
// app/api/ticket/generate/route.ts
import { NextRequest, NextResponse } from 'next/server'
import QRCode from 'qrcode'
import crypto from 'crypto'

interface TicketData {
  eventId: string
  eventName: string
  userId: string
  userName: string
  ticketType: string
  seatNumber?: string
}

export async function POST(request: NextRequest) {
  try {
    const ticketData: TicketData = await request.json()

    // チケットIDを生成
    const ticketId = crypto.randomUUID()

    // 検証用データ（JWTなど暗号化推奨）
    const ticketPayload = JSON.stringify({
      ticketId,
      eventId: ticketData.eventId,
      userId: ticketData.userId,
      issuedAt: Date.now(),
    })

    // Base64エンコード（本番環境ではJWT使用推奨）
    const encodedPayload = Buffer.from(ticketPayload).toString('base64')

    // QRコード生成
    const qrCode = await QRCode.toDataURL(encodedPayload, {
      errorCorrectionLevel: 'H',
      width: 400,
      margin: 2,
    })

    // データベースに保存
    // await prisma.ticket.create({
    //   data: {
    //     id: ticketId,
    //     eventId: ticketData.eventId,
    //     userId: ticketData.userId,
    //     ticketType: ticketData.ticketType,
    //     seatNumber: ticketData.seatNumber,
    //     status: 'valid',
    //   },
    // })

    return NextResponse.json({
      success: true,
      ticket: {
        ticketId,
        qrCode,
        ...ticketData,
      },
    })
  } catch (error) {
    console.error('チケット生成エラー:', error)
    return NextResponse.json(
      { success: false, error: 'チケット生成に失敗しました' },
      { status: 500 }
    )
  }
}

// app/api/ticket/verify/route.ts
export async function POST(request: NextRequest) {
  try {
    const { qrData } = await request.json()

    // QRデータをデコード
    const decodedPayload = JSON.parse(
      Buffer.from(qrData, 'base64').toString()
    )

    // データベースでチケット検証
    // const ticket = await prisma.ticket.findUnique({
    //   where: { id: decodedPayload.ticketId },
    // })

    // if (!ticket || ticket.status !== 'valid') {
    //   return NextResponse.json({ valid: false, reason: '無効なチケット' })
    // }

    // チケットを使用済みに更新
    // await prisma.ticket.update({
    //   where: { id: decodedPayload.ticketId },
    //   data: { status: 'used', usedAt: new Date() },
    // })

    return NextResponse.json({
      valid: true,
      ticket: decodedPayload,
    })
  } catch (error) {
    console.error('チケット検証エラー:', error)
    return NextResponse.json(
      { valid: false, reason: '検証エラー' },
      { status: 500 }
    )
  }
}
```

### 4. WiFi共有用QRコード

```typescript
'use client'

import { useState } from 'react'
import { QRCodeSVG } from 'react-qr-code'

export default function WiFiQRCode() {
  const [ssid, setSsid] = useState('')
  const [password, setPassword] = useState('')
  const [security, setSecurity] = useState<'WPA' | 'WEP' | 'nopass'>('WPA')
  const [hidden, setHidden] = useState(false)
  const [wifiString, setWifiString] = useState('')

  const generateWiFiQR = () => {
    // WiFi QRコードフォーマット
    const wifiData = `WIFI:T:${security};S:${ssid};P:${password};H:${hidden};;`
    setWifiString(wifiData)
  }

  return (
    <div className="max-w-2xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">WiFi共有QRコード</h1>

      <div className="space-y-4 mb-6">
        <div>
          <label className="block text-sm font-medium mb-2">
            ネットワーク名 (SSID)
          </label>
          <input
            type="text"
            value={ssid}
            onChange={(e) => setSsid(e.target.value)}
            className="w-full p-3 border rounded"
            placeholder="WiFiネットワーク名"
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-2">
            パスワード
          </label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full p-3 border rounded"
            placeholder="WiFiパスワード"
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-2">
            セキュリティタイプ
          </label>
          <select
            value={security}
            onChange={(e) => setSecurity(e.target.value as 'WPA' | 'WEP' | 'nopass')}
            className="w-full p-3 border rounded"
          >
            <option value="WPA">WPA/WPA2</option>
            <option value="WEP">WEP</option>
            <option value="nopass">なし</option>
          </select>
        </div>

        <div className="flex items-center gap-2">
          <input
            type="checkbox"
            id="hidden"
            checked={hidden}
            onChange={(e) => setHidden(e.target.checked)}
            className="w-4 h-4"
          />
          <label htmlFor="hidden" className="text-sm">
            非表示ネットワーク
          </label>
        </div>

        <button
          onClick={generateWiFiQR}
          disabled={!ssid}
          className="w-full px-4 py-3 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300"
        >
          QRコード生成
        </button>
      </div>

      {wifiString && (
        <div className="flex flex-col items-center gap-4 p-6 bg-gray-50 rounded-lg">
          <div className="p-4 bg-white rounded-lg shadow">
            <QRCodeSVG value={wifiString} size={300} level="H" />
          </div>
          <p className="text-sm text-gray-600 text-center">
            このQRコードをスキャンしてWiFiに接続
          </p>
        </div>
      )}
    </div>
  )
}
```

## ベストプラクティス

### 1. セキュリティ

```typescript
// 機密データを含むQRコード生成時の注意点

// ❌ 悪い例: 平文でデータを含める
const badQR = await QRCode.toDataURL(
  JSON.stringify({
    userId: '12345',
    secret: 'my-secret-key',
    apiToken: 'abc123',
  })
)

// ✅ 良い例: 暗号化またはトークン化
import jwt from 'jsonwebtoken'

const payload = {
  userId: '12345',
  exp: Math.floor(Date.now() / 1000) + 3600, // 1時間有効
}

const token = jwt.sign(payload, process.env.JWT_SECRET!)
const goodQR = await QRCode.toDataURL(token, {
  errorCorrectionLevel: 'H',
})
```

### 2. エラーハンドリング

```typescript
const generateQRWithRetry = async (
  text: string,
  maxRetries = 3
): Promise<string> => {
  let lastError: Error | null = null

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await QRCode.toDataURL(text, {
        errorCorrectionLevel: 'M',
        width: 300,
      })
    } catch (error) {
      lastError = error as Error
      console.warn(`QRコード生成失敗 (試行 ${attempt}/${maxRetries})`, error)

      if (attempt < maxRetries) {
        // 指数バックオフ
        await new Promise((resolve) =>
          setTimeout(resolve, Math.pow(2, attempt) * 1000)
        )
      }
    }
  }

  throw new Error(
    `QRコード生成が${maxRetries}回失敗しました: ${lastError?.message}`
  )
}
```

### 3. パフォーマンス最適化

```typescript
// キャッシュを利用してパフォーマンス向上
import { LRUCache } from 'lru-cache'

const qrCodeCache = new LRUCache<string, string>({
  max: 500,
  ttl: 1000 * 60 * 60, // 1時間
})

const generateQRWithCache = async (text: string): Promise<string> => {
  const cached = qrCodeCache.get(text)
  if (cached) {
    return cached
  }

  const qrCode = await QRCode.toDataURL(text, {
    errorCorrectionLevel: 'M',
    width: 300,
  })

  qrCodeCache.set(text, qrCode)
  return qrCode
}
```

### 4. アクセシビリティ

```typescript
'use client'

import { QRCodeSVG } from 'react-qr-code'

export default function AccessibleQRCode({
  value,
  description,
}: {
  value: string
  description: string
}) {
  return (
    <div role="img" aria-label={description}>
      <QRCodeSVG
        value={value}
        size={256}
        level="M"
        title={description}
        aria-label={description}
      />
      <p className="sr-only">{description}</p>
      <p className="mt-2 text-sm text-gray-600">{value}</p>
    </div>
  )
}
```

### 5. レスポンシブデザイン

```typescript
'use client'

import { QRCodeSVG } from 'react-qr-code'
import { useState, useEffect } from 'react'

export default function ResponsiveQRCode({ value }: { value: string }) {
  const [qrSize, setQrSize] = useState(256)

  useEffect(() => {
    const updateSize = () => {
      const width = window.innerWidth
      if (width < 640) {
        setQrSize(200)
      } else if (width < 768) {
        setQrSize(256)
      } else {
        setQrSize(300)
      }
    }

    updateSize()
    window.addEventListener('resize', updateSize)
    return () => window.removeEventListener('resize', updateSize)
  }, [])

  return (
    <div className="w-full flex justify-center">
      <QRCodeSVG value={value} size={qrSize} level="M" />
    </div>
  )
}
```

### 6. データサイズ制限

```typescript
const validateQRCodeData = (text: string): { valid: boolean; error?: string } => {
  // QRコードの最大容量チェック
  const maxBytes = 2953 // バイナリモード最大容量

  const byteLength = new TextEncoder().encode(text).length

  if (byteLength > maxBytes) {
    return {
      valid: false,
      error: `データサイズが大きすぎます (${byteLength}バイト / 最大${maxBytes}バイト)`,
    }
  }

  return { valid: true }
}

const generateSafeQRCode = async (text: string): Promise<string> => {
  const validation = validateQRCodeData(text)

  if (!validation.valid) {
    throw new Error(validation.error)
  }

  return await QRCode.toDataURL(text, {
    errorCorrectionLevel: 'M',
    width: 300,
  })
}
```

### 7. 有効期限付きQRコード

```typescript
import jwt from 'jsonwebtoken'
import QRCode from 'qrcode'

interface QRPayload {
  data: any
  expiresIn: string // '1h', '30m', '1d'
}

const generateExpiringQRCode = async (
  payload: QRPayload
): Promise<{ qrCode: string; expiresAt: Date }> => {
  // JWTで有効期限を設定
  const token = jwt.sign(
    { data: payload.data },
    process.env.JWT_SECRET!,
    { expiresIn: payload.expiresIn }
  )

  const qrCode = await QRCode.toDataURL(token, {
    errorCorrectionLevel: 'H',
    width: 350,
  })

  // 有効期限を計算
  const decoded = jwt.verify(token, process.env.JWT_SECRET!) as jwt.JwtPayload
  const expiresAt = new Date(decoded.exp! * 1000)

  return { qrCode, expiresAt }
}

// 使用例
const { qrCode, expiresAt } = await generateExpiringQRCode({
  data: { orderId: '12345', amount: 5000 },
  expiresIn: '15m', // 15分間有効
})
```

## まとめ

### 用途別推奨ライブラリ

| 用途 | 推奨ライブラリ | 理由 |
|------|--------------|------|
| サーバーサイドQR生成 | qrcode | Node.js対応、多様な出力形式 |
| React/Next.jsでの表示 | react-qr-code | 軽量、SVG、コンポーネント化 |
| QRコード読み取り | jsQR | シンプル、WebRTC対応 |
| 高性能スキャン | qr-scanner | Web Worker、最適化済み |

### 実装時のチェックリスト

- [ ] 適切なエラー訂正レベルを選択
- [ ] 機密データは暗号化またはトークン化
- [ ] QRコードに有効期限を設定（必要に応じて）
- [ ] データサイズを検証
- [ ] キャッシュを活用してパフォーマンス向上
- [ ] レスポンシブ対応
- [ ] アクセシビリティを考慮
- [ ] エラーハンドリングを実装
- [ ] ユーザーフィードバックを表示

このガイドを参考に、QRコード機能を適切に実装してください。
