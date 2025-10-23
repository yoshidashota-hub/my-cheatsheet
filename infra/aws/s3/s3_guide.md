# AWS S3 ガイド

Amazon S3（Simple Storage Service）は、高い耐久性とスケーラビリティを備えたオブジェクトストレージサービスです。

## 特徴

- **高耐久性**: 99.999999999%（イレブンナイン）の耐久性
- **スケーラブル**: 容量制限なし
- **低コスト**: 使用した分だけ課金
- **セキュア**: 暗号化、アクセス制御が充実
- **高可用性**: 複数のアベイラビリティゾーンにデータを保存

## 基本概念

### バケット（Bucket）

- S3のコンテナ単位
- バケット名はグローバルで一意
- リージョンごとに作成

### オブジェクト（Object）

- S3に保存されるファイル
- 最大5TBまで保存可能
- キー（ファイルパス）で識別

### キー（Key）

- オブジェクトの一意な識別子
- ファイルパスのような構造（例: `images/2024/photo.jpg`）

## AWS CLI でのS3操作

### インストール

```bash
# AWS CLI v2 のインストール
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 確認
aws --version
```

### 認証設定

```bash
# AWS認証情報の設定
aws configure

# 入力内容:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: ap-northeast-1
# Default output format: json
```

### バケット操作

```bash
# バケット一覧
aws s3 ls

# バケット作成
aws s3 mb s3://my-bucket-name --region ap-northeast-1

# バケット削除（空のバケットのみ）
aws s3 rb s3://my-bucket-name

# バケット削除（中身ごと）
aws s3 rb s3://my-bucket-name --force

# バケット内のオブジェクト一覧
aws s3 ls s3://my-bucket-name
aws s3 ls s3://my-bucket-name/path/ --recursive
```

### ファイルのアップロード/ダウンロード

```bash
# ファイルをアップロード
aws s3 cp file.txt s3://my-bucket-name/

# フォルダごとアップロード
aws s3 cp ./local-folder s3://my-bucket-name/remote-folder/ --recursive

# ファイルをダウンロード
aws s3 cp s3://my-bucket-name/file.txt ./

# フォルダごとダウンロード
aws s3 cp s3://my-bucket-name/remote-folder/ ./local-folder/ --recursive

# 同期（差分のみアップロード）
aws s3 sync ./local-folder s3://my-bucket-name/remote-folder/

# 同期（S3からローカルへ）
aws s3 sync s3://my-bucket-name/remote-folder/ ./local-folder/

# 削除を含む同期
aws s3 sync ./local-folder s3://my-bucket-name/remote-folder/ --delete
```

### ファイルの移動/削除

```bash
# ファイル移動
aws s3 mv s3://my-bucket-name/old-path/file.txt s3://my-bucket-name/new-path/file.txt

# ファイル削除
aws s3 rm s3://my-bucket-name/file.txt

# フォルダごと削除
aws s3 rm s3://my-bucket-name/folder/ --recursive
```

### 公開設定

```bash
# ファイルを公開でアップロード
aws s3 cp file.txt s3://my-bucket-name/ --acl public-read

# Content-Typeを指定
aws s3 cp index.html s3://my-bucket-name/ --content-type "text/html"

# キャッシュ設定
aws s3 cp image.jpg s3://my-bucket-name/ --cache-control "max-age=31536000"
```

## AWS SDK (JavaScript/TypeScript)

### インストール

```bash
npm install @aws-sdk/client-s3
npm install @aws-sdk/s3-request-presigner
```

### 基本設定

```typescript
import { S3Client } from '@aws-sdk/client-s3'

const s3Client = new S3Client({
  region: 'ap-northeast-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})
```

### ファイルのアップロード

```typescript
import { PutObjectCommand } from '@aws-sdk/client-s3'
import fs from 'fs'

// ファイルをアップロード
async function uploadFile(filePath: string, key: string) {
  const fileContent = fs.readFileSync(filePath)

  const command = new PutObjectCommand({
    Bucket: 'my-bucket-name',
    Key: key,
    Body: fileContent,
    ContentType: 'image/jpeg',
  })

  const response = await s3Client.send(command)
  console.log('Upload success:', response)
}

// Bufferをアップロード
async function uploadBuffer(buffer: Buffer, key: string) {
  const command = new PutObjectCommand({
    Bucket: 'my-bucket-name',
    Key: key,
    Body: buffer,
    ContentType: 'application/pdf',
  })

  await s3Client.send(command)
}

// ストリームをアップロード
import { Upload } from '@aws-sdk/lib-storage'

async function uploadStream(stream: NodeJS.ReadableStream, key: string) {
  const upload = new Upload({
    client: s3Client,
    params: {
      Bucket: 'my-bucket-name',
      Key: key,
      Body: stream,
    },
  })

  upload.on('httpUploadProgress', (progress) => {
    console.log('Progress:', progress)
  })

  await upload.done()
}
```

### ファイルのダウンロード

```typescript
import { GetObjectCommand } from '@aws-sdk/client-s3'

async function downloadFile(key: string) {
  const command = new GetObjectCommand({
    Bucket: 'my-bucket-name',
    Key: key,
  })

  const response = await s3Client.send(command)

  // Streamを文字列に変換
  const str = await response.Body?.transformToString()
  console.log(str)

  // Streamをバッファに変換
  const buffer = await response.Body?.transformToByteArray()
  return buffer
}

// ファイルとして保存
import { pipeline } from 'stream/promises'
import { createWriteStream } from 'fs'

async function downloadToFile(key: string, outputPath: string) {
  const command = new GetObjectCommand({
    Bucket: 'my-bucket-name',
    Key: key,
  })

  const response = await s3Client.send(command)

  if (response.Body) {
    await pipeline(
      response.Body as NodeJS.ReadableStream,
      createWriteStream(outputPath)
    )
  }
}
```

### ファイルの削除

```typescript
import { DeleteObjectCommand, DeleteObjectsCommand } from '@aws-sdk/client-s3'

// 単一ファイル削除
async function deleteFile(key: string) {
  const command = new DeleteObjectCommand({
    Bucket: 'my-bucket-name',
    Key: key,
  })

  await s3Client.send(command)
}

// 複数ファイル削除
async function deleteFiles(keys: string[]) {
  const command = new DeleteObjectsCommand({
    Bucket: 'my-bucket-name',
    Delete: {
      Objects: keys.map((key) => ({ Key: key })),
    },
  })

  const response = await s3Client.send(command)
  console.log('Deleted:', response.Deleted)
}
```

### ファイル一覧取得

```typescript
import { ListObjectsV2Command } from '@aws-sdk/client-s3'

async function listFiles(prefix?: string) {
  const command = new ListObjectsV2Command({
    Bucket: 'my-bucket-name',
    Prefix: prefix,
    MaxKeys: 1000,
  })

  const response = await s3Client.send(command)
  return response.Contents || []
}

// ページネーション
async function listAllFiles(prefix?: string) {
  const allFiles = []
  let continuationToken: string | undefined

  do {
    const command = new ListObjectsV2Command({
      Bucket: 'my-bucket-name',
      Prefix: prefix,
      ContinuationToken: continuationToken,
    })

    const response = await s3Client.send(command)
    allFiles.push(...(response.Contents || []))
    continuationToken = response.NextContinuationToken
  } while (continuationToken)

  return allFiles
}
```

### ファイルの存在確認

```typescript
import { HeadObjectCommand } from '@aws-sdk/client-s3'

async function fileExists(key: string): Promise<boolean> {
  try {
    const command = new HeadObjectCommand({
      Bucket: 'my-bucket-name',
      Key: key,
    })
    await s3Client.send(command)
    return true
  } catch (error) {
    if (error.name === 'NotFound') {
      return false
    }
    throw error
  }
}

// メタデータ取得
async function getFileMetadata(key: string) {
  const command = new HeadObjectCommand({
    Bucket: 'my-bucket-name',
    Key: key,
  })

  const response = await s3Client.send(command)
  return {
    contentType: response.ContentType,
    contentLength: response.ContentLength,
    lastModified: response.LastModified,
    metadata: response.Metadata,
  }
}
```

### 署名付きURL（プリサインドURL）

```typescript
import { GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'

// ダウンロード用の署名付きURL
async function getDownloadUrl(key: string, expiresIn = 3600) {
  const command = new GetObjectCommand({
    Bucket: 'my-bucket-name',
    Key: key,
  })

  const url = await getSignedUrl(s3Client, command, { expiresIn })
  return url
}

// アップロード用の署名付きURL
async function getUploadUrl(key: string, expiresIn = 3600) {
  const command = new PutObjectCommand({
    Bucket: 'my-bucket-name',
    Key: key,
    ContentType: 'image/jpeg',
  })

  const url = await getSignedUrl(s3Client, command, { expiresIn })
  return url
}
```

### コピー

```typescript
import { CopyObjectCommand } from '@aws-sdk/client-s3'

async function copyFile(sourceKey: string, destKey: string) {
  const command = new CopyObjectCommand({
    Bucket: 'my-bucket-name',
    CopySource: `my-bucket-name/${sourceKey}`,
    Key: destKey,
  })

  await s3Client.send(command)
}

// 別のバケットへコピー
async function copyToBucket(sourceKey: string, destBucket: string, destKey: string) {
  const command = new CopyObjectCommand({
    Bucket: destBucket,
    CopySource: `my-bucket-name/${sourceKey}`,
    Key: destKey,
  })

  await s3Client.send(command)
}
```

## Next.js での実装例

### API Route でファイルアップロード

```typescript
// app/api/upload/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3'

const s3Client = new S3Client({
  region: process.env.AWS_REGION!,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File

    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 })
    }

    const buffer = Buffer.from(await file.arrayBuffer())
    const key = `uploads/${Date.now()}-${file.name}`

    const command = new PutObjectCommand({
      Bucket: process.env.AWS_S3_BUCKET_NAME!,
      Key: key,
      Body: buffer,
      ContentType: file.type,
    })

    await s3Client.send(command)

    return NextResponse.json({
      success: true,
      key,
      url: `https://${process.env.AWS_S3_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`,
    })
  } catch (error) {
    console.error('Upload error:', error)
    return NextResponse.json({ error: 'Upload failed' }, { status: 500 })
  }
}
```

### フロントエンドでのアップロード

```typescript
'use client'

import { useState } from 'react'

export default function UploadForm() {
  const [file, setFile] = useState<File | null>(null)
  const [uploading, setUploading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!file) return

    setUploading(true)

    const formData = new FormData()
    formData.append('file', file)

    try {
      const response = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      })

      const data = await response.json()

      if (data.success) {
        console.log('Uploaded:', data.url)
      }
    } catch (error) {
      console.error('Error:', error)
    } finally {
      setUploading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="file"
        onChange={(e) => setFile(e.target.files?.[0] || null)}
      />
      <button type="submit" disabled={!file || uploading}>
        {uploading ? 'Uploading...' : 'Upload'}
      </button>
    </form>
  )
}
```

### 署名付きURLでの直接アップロード

```typescript
// app/api/presigned-url/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'

const s3Client = new S3Client({
  region: process.env.AWS_REGION!,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})

export async function POST(request: NextRequest) {
  const { filename, contentType } = await request.json()

  const key = `uploads/${Date.now()}-${filename}`

  const command = new PutObjectCommand({
    Bucket: process.env.AWS_S3_BUCKET_NAME!,
    Key: key,
    ContentType: contentType,
  })

  const url = await getSignedUrl(s3Client, command, { expiresIn: 3600 })

  return NextResponse.json({ url, key })
}
```

```typescript
// フロントエンド
async function uploadWithPresignedUrl(file: File) {
  // 署名付きURLを取得
  const response = await fetch('/api/presigned-url', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: file.name,
      contentType: file.type,
    }),
  })

  const { url, key } = await response.json()

  // S3に直接アップロード
  await fetch(url, {
    method: 'PUT',
    body: file,
    headers: {
      'Content-Type': file.type,
    },
  })

  console.log('Uploaded:', key)
}
```

## バケットポリシー

### 公開読み取り許可

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket-name/*"
    }
  ]
}
```

### 特定のIPアドレスからのアクセス許可

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket-name/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "203.0.113.0/24"
        }
      }
    }
  ]
}
```

### CloudFrontからのアクセスのみ許可

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket-name/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/DISTRIBUTIONID"
        }
      }
    }
  ]
}
```

## CORS設定

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedOrigins": ["https://example.com"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

AWS CLIで設定:

```bash
aws s3api put-bucket-cors --bucket my-bucket-name --cors-configuration file://cors.json
```

## ライフサイクルポリシー

### 古いファイルを自動削除

```json
{
  "Rules": [
    {
      "Id": "DeleteOldFiles",
      "Status": "Enabled",
      "Prefix": "logs/",
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
```

### Glacier への移行

```json
{
  "Rules": [
    {
      "Id": "ArchiveOldFiles",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

## ストレージクラス

| クラス | 用途 | 特徴 |
|--------|------|------|
| Standard | 頻繁にアクセスするデータ | 最も高速、高コスト |
| Intelligent-Tiering | アクセス頻度が不明 | 自動的に最適化 |
| Standard-IA | 低頻度アクセス | 低コスト、取得料金あり |
| One Zone-IA | 低頻度、単一AZ | さらに低コスト |
| Glacier Instant Retrieval | アーカイブ、即時取得 | 非常に低コスト |
| Glacier Flexible Retrieval | アーカイブ、数分〜数時間 | 超低コスト |
| Glacier Deep Archive | 長期アーカイブ | 最低コスト |

## セキュリティのベストプラクティス

1. **バケットのパブリックアクセスをブロック**: デフォルトで有効化
2. **IAMロールを使用**: アクセスキーをハードコードしない
3. **暗号化を有効化**: サーバーサイド暗号化（SSE-S3またはSSE-KMS）
4. **署名付きURLを使用**: 直接アクセスを避ける
5. **バージョニングを有効化**: 誤削除対策
6. **ログを有効化**: アクセスログを記録
7. **最小権限の原則**: 必要最小限の権限のみ付与

## コスト最適化

1. **適切なストレージクラスを選択**: アクセス頻度に応じて使い分け
2. **ライフサイクルポリシーを設定**: 自動的に移行・削除
3. **不要なデータを削除**: 定期的にクリーンアップ
4. **マルチパートアップロードの未完了分を削除**: コストが発生する
5. **CloudFrontを使用**: 転送コストを削減
6. **リクエスト数を最適化**: 一覧取得の頻度を減らす

## 参考リンク

- [AWS S3 公式ドキュメント](https://docs.aws.amazon.com/s3/)
- [AWS SDK for JavaScript v3](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-s3/)
- [AWS CLI S3 コマンドリファレンス](https://docs.aws.amazon.com/cli/latest/reference/s3/)
- [S3 料金](https://aws.amazon.com/s3/pricing/)
