# REST API 設計完全ガイド

## 目次
- [RESTとは](#restとは)
- [HTTPメソッド](#httpメソッド)
- [URLデザイン](#urlデザイン)
- [ステータスコード](#ステータスコード)
- [リクエスト・レスポンス](#リクエストレスポンス)
- [バージョニング](#バージョニング)
- [エラーハンドリング](#エラーハンドリング)
- [セキュリティ](#セキュリティ)
- [ページネーション](#ページネーション)
- [フィルタリング・ソート](#フィルタリングソート)

---

## RESTとは

REpresentational State Transferの略。リソース指向のAPI設計アーキテクチャ。

### REST原則
- 🌐 ステートレス
- 📦 リソースベース
- 🔄 統一インターフェース
- 📝 キャッシュ可能

---

## HTTPメソッド

### 基本メソッド

| メソッド | 用途 | 冪等性 | 安全性 |
|---------|------|--------|--------|
| GET | リソース取得 | ○ | ○ |
| POST | リソース作成 | × | × |
| PUT | リソース更新（完全） | ○ | × |
| PATCH | リソース更新（部分） | × | × |
| DELETE | リソース削除 | ○ | × |

### 使用例

```http
# 一覧取得
GET /api/posts

# 詳細取得
GET /api/posts/123

# 作成
POST /api/posts
Content-Type: application/json

{
  "title": "Hello",
  "body": "Content"
}

# 更新（完全）
PUT /api/posts/123
{
  "title": "Updated Title",
  "body": "Updated Content",
  "status": "published"
}

# 更新（部分）
PATCH /api/posts/123
{
  "title": "Updated Title"
}

# 削除
DELETE /api/posts/123
```

---

## URLデザイン

### 基本ルール

```
✓ 良い例
GET /api/users              # 複数形
GET /api/users/123          # ID指定
GET /api/posts/456/comments # ネスト
GET /api/search/users       # 検索

✗ 悪い例
GET /api/getUsers           # 動詞を含む
GET /api/user               # 単数形
GET /api/users_list         # アンダースコア
```

### リソースのネスト

```http
# 浅いネスト（推奨）
GET /api/users/123
GET /api/posts?userId=123

# 深いネスト（2階層まで）
GET /api/users/123/posts
GET /api/posts/456/comments

# 過度なネスト（非推奨）
GET /api/users/123/posts/456/comments/789/likes
```

### 命名規則

```
✓ ケバブケース（推奨）
/api/user-profiles
/api/blog-posts

○ キャメルケース
/api/userProfiles
/api/blogPosts

✗ スネークケース（非推奨）
/api/user_profiles
```

---

## ステータスコード

### 2xx 成功

```
200 OK              - リクエスト成功
201 Created         - リソース作成成功
204 No Content      - 成功（レスポンスボディなし）
```

### 3xx リダイレクト

```
301 Moved Permanently  - 恒久的リダイレクト
302 Found              - 一時的リダイレクト
304 Not Modified       - キャッシュ有効
```

### 4xx クライアントエラー

```
400 Bad Request          - リクエスト不正
401 Unauthorized         - 認証必要
403 Forbidden            - アクセス拒否
404 Not Found            - リソース未検出
409 Conflict             - リソース競合
422 Unprocessable Entity - バリデーションエラー
429 Too Many Requests    - レート制限超過
```

### 5xx サーバーエラー

```
500 Internal Server Error - サーバーエラー
502 Bad Gateway           - ゲートウェイエラー
503 Service Unavailable   - サービス利用不可
504 Gateway Timeout       - ゲートウェイタイムアウト
```

### 使用例

```typescript
// Express
app.post('/api/posts', async (req, res) => {
  try {
    const post = await createPost(req.body)
    res.status(201).json(post)  // 201 Created
  } catch (error) {
    res.status(400).json({ error: error.message })
  }
})

app.get('/api/posts/:id', async (req, res) => {
  const post = await findPost(req.params.id)
  if (!post) {
    return res.status(404).json({ error: 'Post not found' })
  }
  res.status(200).json(post)  // 200 OK
})

app.delete('/api/posts/:id', async (req, res) => {
  await deletePost(req.params.id)
  res.status(204).send()  // 204 No Content
})
```

---

## リクエスト・レスポンス

### リクエスト形式

```http
POST /api/posts HTTP/1.1
Host: api.example.com
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

{
  "title": "Hello World",
  "body": "Content here",
  "tags": ["tech", "api"]
}
```

### レスポンス形式

```json
// 成功レスポンス
{
  "id": "123",
  "title": "Hello World",
  "body": "Content here",
  "tags": ["tech", "api"],
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}

// リスト形式
{
  "data": [
    { "id": "1", "title": "Post 1" },
    { "id": "2", "title": "Post 2" }
  ],
  "meta": {
    "total": 100,
    "page": 1,
    "perPage": 20
  }
}
```

### 命名規則

```json
// ✓ キャメルケース（推奨）
{
  "userId": 123,
  "createdAt": "2024-01-15T10:30:00Z",
  "firstName": "John"
}

// ○ スネークケース
{
  "user_id": 123,
  "created_at": "2024-01-15T10:30:00Z",
  "first_name": "John"
}
```

---

## バージョニング

### URLパス方式（推奨）

```http
GET /api/v1/users
GET /api/v2/users
```

```typescript
// Express
app.use('/api/v1', v1Router)
app.use('/api/v2', v2Router)
```

### ヘッダー方式

```http
GET /api/users
Accept: application/vnd.api+json;version=1
```

### クエリパラメータ方式

```http
GET /api/users?version=1
```

---

## エラーハンドリング

### エラーレスポンス形式

```json
// 単一エラー
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  }
}

// 複数エラー
{
  "errors": [
    {
      "code": "REQUIRED_FIELD",
      "field": "title",
      "message": "Title is required"
    },
    {
      "code": "INVALID_FORMAT",
      "field": "email",
      "message": "Invalid email format"
    }
  ]
}
```

### 実装例

```typescript
// Express
class ApiError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: any
  ) {
    super(message)
  }
}

app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details
      }
    })
  }

  console.error(err)
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred'
    }
  })
})

// 使用例
app.post('/api/posts', async (req, res, next) => {
  try {
    if (!req.body.title) {
      throw new ApiError(400, 'VALIDATION_ERROR', 'Title is required')
    }
    // ...
  } catch (error) {
    next(error)
  }
})
```

---

## セキュリティ

### 認証

```http
# Bearer Token
GET /api/users/me
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# API Key
GET /api/users
X-API-Key: abc123def456
```

### CORS

```typescript
// Express
import cors from 'cors'

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(','),
  credentials: true
}))
```

### レート制限

```typescript
import rateLimit from 'express-rate-limit'

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 100, // 100リクエストまで
  message: 'Too many requests'
})

app.use('/api/', limiter)
```

### HTTPSのみ

```typescript
app.use((req, res, next) => {
  if (req.protocol !== 'https' && process.env.NODE_ENV === 'production') {
    return res.redirect('https://' + req.headers.host + req.url)
  }
  next()
})
```

---

## ページネーション

### オフセットベース

```http
GET /api/posts?page=2&limit=20
```

```json
{
  "data": [...],
  "meta": {
    "total": 100,
    "page": 2,
    "perPage": 20,
    "totalPages": 5
  },
  "links": {
    "first": "/api/posts?page=1&limit=20",
    "prev": "/api/posts?page=1&limit=20",
    "next": "/api/posts?page=3&limit=20",
    "last": "/api/posts?page=5&limit=20"
  }
}
```

### カーソルベース

```http
GET /api/posts?cursor=eyJpZCI6MTIzfQ&limit=20
```

```json
{
  "data": [...],
  "meta": {
    "hasMore": true,
    "nextCursor": "eyJpZCI6MTQzfQ"
  }
}
```

### 実装例

```typescript
// オフセットベース
app.get('/api/posts', async (req, res) => {
  const page = parseInt(req.query.page as string) || 1
  const limit = parseInt(req.query.limit as string) || 20
  const offset = (page - 1) * limit

  const [posts, total] = await Promise.all([
    db.posts.findMany({ skip: offset, take: limit }),
    db.posts.count()
  ])

  res.json({
    data: posts,
    meta: {
      total,
      page,
      perPage: limit,
      totalPages: Math.ceil(total / limit)
    }
  })
})
```

---

## フィルタリング・ソート

### フィルタリング

```http
# 単一条件
GET /api/posts?status=published

# 複数条件
GET /api/posts?status=published&category=tech

# 範囲指定
GET /api/posts?createdAt[gte]=2024-01-01&createdAt[lte]=2024-12-31

# IN条件
GET /api/posts?tags=tech,api,rest
```

### ソート

```http
# 昇順
GET /api/posts?sort=createdAt

# 降順
GET /api/posts?sort=-createdAt

# 複数フィールド
GET /api/posts?sort=-createdAt,title
```

### 実装例

```typescript
app.get('/api/posts', async (req, res) => {
  const { status, category, sort } = req.query

  const where: any = {}
  if (status) where.status = status
  if (category) where.category = category

  const orderBy: any = {}
  if (sort) {
    const field = (sort as string).startsWith('-')
      ? (sort as string).substring(1)
      : sort
    const direction = (sort as string).startsWith('-') ? 'desc' : 'asc'
    orderBy[field] = direction
  }

  const posts = await db.posts.findMany({
    where,
    orderBy
  })

  res.json({ data: posts })
})
```

---

## フィールド選択

```http
# 必要なフィールドのみ
GET /api/posts?fields=id,title,createdAt

# 除外フィールド指定
GET /api/posts?exclude=body,metadata
```

```typescript
app.get('/api/posts', async (req, res) => {
  const fields = (req.query.fields as string)?.split(',')

  const select = fields?.reduce((acc, field) => {
    acc[field] = true
    return acc
  }, {} as any)

  const posts = await db.posts.findMany({
    select: select || undefined
  })

  res.json({ data: posts })
})
```

---

## 検索

```http
# 全文検索
GET /api/posts?q=keyword

# フィールド指定検索
GET /api/posts?search[title]=keyword
```

---

## ベストプラクティス

### ✓ 推奨

- 複数形のリソース名を使用
- HTTPメソッドを適切に使用
- ステータスコードを正確に返す
- JSONで一貫した命名規則
- バージョニングを実装
- エラーレスポンスを標準化
- ページネーションを実装
- レート制限を設定
- HTTPS を使用
- ドキュメント化（OpenAPI/Swagger）

### ✗ 避けるべき

- URLに動詞を含める
- 過度なネスト
- 一貫性のない命名
- 詳細なエラーメッセージの露出
- 認証なしの機密データ公開

---

## 参考リンク

- [REST API Tutorial](https://restfulapi.net/)
- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines)
- [Google API Design Guide](https://cloud.google.com/apis/design)
