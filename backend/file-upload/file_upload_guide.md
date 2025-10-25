# ファイルアップロード 完全ガイド

## 目次
1. [ファイルアップロードとは](#ファイルアップロードとは)
2. [Multer（Node.js）](#multernodejs)
3. [AWS S3アップロード](#aws-s3アップロード)
4. [Presigned URL](#presigned-url)
5. [画像処理](#画像処理)
6. [ベストプラクティス](#ベストプラクティス)

---

## ファイルアップロードとは

ファイルアップロードは、ユーザーがファイルをサーバーまたはストレージに送信する機能です。

### 主な方法

- **直接アップロード**: サーバー経由でアップロード
- **Presigned URL**: クライアントから直接S3へアップロード
- **Multipart Upload**: 大きなファイルを分割してアップロード

---

## Multer（Node.js）

### セットアップ

```typescript
import express from 'express';
import multer from 'multer';
import path from 'path';

const app = express();

// ストレージ設定
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  },
});

// ファイルフィルター
const fileFilter = (req: any, file: Express.Multer.File, cb: any) => {
  const allowedTypes = /jpeg|jpg|png|gif|pdf/;
  const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
  const mimetype = allowedTypes.test(file.mimetype);

  if (extname && mimetype) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type'));
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB
  },
});

// 単一ファイルアップロード
app.post('/upload', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  res.json({
    message: 'File uploaded successfully',
    file: {
      filename: req.file.filename,
      size: req.file.size,
      mimetype: req.file.mimetype,
    },
  });
});

// 複数ファイルアップロード
app.post('/upload/multiple', upload.array('files', 10), (req, res) => {
  const files = req.files as Express.Multer.File[];

  res.json({
    message: 'Files uploaded successfully',
    files: files.map(f => ({
      filename: f.filename,
      size: f.size,
    })),
  });
});
```

---

## AWS S3アップロード

### セットアップ

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import fs from 'fs';

const s3 = new S3Client({ region: 'us-east-1' });

// 単純なアップロード
async function uploadToS3(file: Express.Multer.File) {
  const fileContent = fs.readFileSync(file.path);

  const command = new PutObjectCommand({
    Bucket: 'my-bucket',
    Key: `uploads/${Date.now()}-${file.originalname}`,
    Body: fileContent,
    ContentType: file.mimetype,
    ACL: 'public-read',
  });

  try {
    await s3.send(command);
    console.log('File uploaded successfully');
  } catch (error) {
    console.error('Upload error:', error);
    throw error;
  }
}

// マルチパートアップロード（大きなファイル）
async function uploadLargeFile(file: Express.Multer.File) {
  const fileStream = fs.createReadStream(file.path);

  const upload = new Upload({
    client: s3,
    params: {
      Bucket: 'my-bucket',
      Key: `uploads/${Date.now()}-${file.originalname}`,
      Body: fileStream,
      ContentType: file.mimetype,
    },
  });

  upload.on('httpUploadProgress', (progress) => {
    console.log(`Uploaded: ${progress.loaded}/${progress.total}`);
  });

  await upload.done();
}
```

### Express統合

```typescript
app.post('/upload/s3', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    await uploadToS3(req.file);

    // ローカルファイル削除
    fs.unlinkSync(req.file.path);

    res.json({
      message: 'File uploaded to S3',
      url: `https://my-bucket.s3.amazonaws.com/uploads/${req.file.filename}`,
    });
  } catch (error) {
    res.status(500).json({ error: 'Upload failed' });
  }
});
```

---

## Presigned URL

### アップロード用URL生成

```typescript
import { PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

// アップロード用Presigned URL
async function generateUploadUrl(filename: string, contentType: string) {
  const key = `uploads/${Date.now()}-${filename}`;

  const command = new PutObjectCommand({
    Bucket: 'my-bucket',
    Key: key,
    ContentType: contentType,
  });

  const url = await getSignedUrl(s3, command, { expiresIn: 3600 });

  return { url, key };
}

// Express エンドポイント
app.post('/upload/presigned-url', async (req, res) => {
  const { filename, contentType } = req.body;

  try {
    const { url, key } = await generateUploadUrl(filename, contentType);

    res.json({
      uploadUrl: url,
      key,
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate URL' });
  }
});
```

### フロントエンド実装

```typescript
// Presigned URLを取得
const response = await fetch('/upload/presigned-url', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    filename: file.name,
    contentType: file.type,
  }),
});

const { uploadUrl, key } = await response.json();

// S3に直接アップロード
await fetch(uploadUrl, {
  method: 'PUT',
  headers: {
    'Content-Type': file.type,
  },
  body: file,
});

console.log('File uploaded:', key);
```

---

## 画像処理

### Sharp（リサイズ・圧縮）

```typescript
import sharp from 'sharp';

async function processImage(file: Express.Multer.File) {
  const outputPath = `processed/${Date.now()}.jpg`;

  await sharp(file.path)
    .resize(800, 600, {
      fit: 'inside',
      withoutEnlargement: true,
    })
    .jpeg({ quality: 80 })
    .toFile(outputPath);

  return outputPath;
}

// サムネイル生成
async function generateThumbnail(file: Express.Multer.File) {
  const thumbnailPath = `thumbnails/${Date.now()}.jpg`;

  await sharp(file.path)
    .resize(200, 200, {
      fit: 'cover',
    })
    .jpeg({ quality: 70 })
    .toFile(thumbnailPath);

  return thumbnailPath;
}
```

---

## ベストプラクティス

### 1. ファイルバリデーション

```typescript
function validateFile(file: Express.Multer.File) {
  const maxSize = 5 * 1024 * 1024; // 5MB
  const allowedTypes = ['image/jpeg', 'image/png', 'application/pdf'];

  if (file.size > maxSize) {
    throw new Error('File too large');
  }

  if (!allowedTypes.includes(file.mimetype)) {
    throw new Error('Invalid file type');
  }

  return true;
}
```

### 2. セキュリティ

```typescript
import crypto from 'crypto';
import path from 'path';

// ランダムファイル名生成
function generateSecureFilename(originalname: string) {
  const hash = crypto.randomBytes(16).toString('hex');
  const ext = path.extname(originalname);
  return `${hash}${ext}`;
}

// ウイルススキャン統合（例）
async function scanFile(filepath: string) {
  // ClamAV などのウイルススキャンツールと統合
  // 実装省略
  return true;
}
```

### 3. プログレストラッキング

```typescript
app.post('/upload/progress', upload.single('file'), (req, res) => {
  let uploadedBytes = 0;

  req.on('data', (chunk) => {
    uploadedBytes += chunk.length;
    console.log(`Uploaded: ${uploadedBytes} bytes`);
  });

  req.on('end', () => {
    res.json({ message: 'Upload complete' });
  });
});
```

---

## 参考リンク

- [Multer Documentation](https://github.com/expressjs/multer)
- [AWS S3 Upload](https://docs.aws.amazon.com/sdk-for-javascript/v3/developer-guide/s3-example-creating-buckets.html)
- [Sharp](https://sharp.pixelplumbing.com/)
