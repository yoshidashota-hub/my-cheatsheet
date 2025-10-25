# MongoDB 完全ガイド

## 目次
1. [MongoDBとは](#mongodbとは)
2. [基本概念](#基本概念)
3. [セットアップ](#セットアップ)
4. [CRUD操作](#crud操作)
5. [クエリとフィルタリング](#クエリとフィルタリング)
6. [インデックス](#インデックス)
7. [集計パイプライン](#集計パイプライン)
8. [トランザクション](#トランザクション)
9. [Mongoose（Node.js ODM）](#mongoosenode-js-odm)
10. [ベストプラクティス](#ベストプラクティス)

---

## MongoDBとは

MongoDBは、ドキュメント指向のNoSQLデータベースです。

### 主な特徴

- **ドキュメント指向**: JSON形式のドキュメントで保存
- **柔軟なスキーマ**: スキーマレスで柔軟なデータ構造
- **水平スケーリング**: シャーディングによる分散
- **高パフォーマンス**: インデックスとクエリ最適化
- **レプリケーション**: 高可用性の実現

### ユースケース

- コンテンツ管理システム
- リアルタイムアナリティクス
- IoTデータストレージ
- モバイルアプリバックエンド
- カタログ・在庫管理

---

## 基本概念

### データ構造

```
Database
├── Collection (テーブル相当)
│   ├── Document (行相当)
│   │   ├── Field: Value (カラム相当)
│   │   └── Field: Value
│   └── Document
└── Collection
```

### ドキュメント例

```json
{
  "_id": ObjectId("507f1f77bcf86cd799439011"),
  "name": "John Doe",
  "email": "john@example.com",
  "age": 30,
  "address": {
    "street": "123 Main St",
    "city": "New York",
    "country": "USA"
  },
  "hobbies": ["reading", "gaming", "cooking"],
  "createdAt": ISODate("2024-01-15T10:30:00Z")
}
```

---

## セットアップ

### Docker Composeでのセットアップ

```yaml
# docker-compose.yml
version: '3.8'

services:
  mongodb:
    image: mongo:7.0
    container_name: mongodb
    restart: always
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: password123
      MONGO_INITDB_DATABASE: myapp
    ports:
      - '27017:27017'
    volumes:
      - mongodb_data:/data/db
      - ./mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js

volumes:
  mongodb_data:
```

```javascript
// mongo-init.js
db = db.getSiblingDB('myapp');

db.createUser({
  user: 'appuser',
  pwd: 'apppassword',
  roles: [
    {
      role: 'readWrite',
      db: 'myapp',
    },
  ],
});

db.createCollection('users');
db.createCollection('posts');
```

### MongoDB Atlas（クラウド）

```bash
# 接続文字列
mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/myapp?retryWrites=true&w=majority
```

### Node.js ドライバーのインストール

```bash
npm install mongodb
# または
npm install mongoose
```

---

## CRUD操作

### MongoDB Native Driver

```typescript
import { MongoClient, ObjectId } from 'mongodb';

const uri = 'mongodb://admin:password123@localhost:27017';
const client = new MongoClient(uri);

async function main() {
  try {
    await client.connect();
    console.log('Connected to MongoDB');

    const db = client.db('myapp');
    const users = db.collection('users');

    // Create (Insert)
    await createUser(users);

    // Read (Find)
    await findUsers(users);

    // Update
    await updateUser(users);

    // Delete
    await deleteUser(users);
  } finally {
    await client.close();
  }
}

// Create
async function createUser(users: any) {
  // 単一ドキュメントの挿入
  const result = await users.insertOne({
    name: 'John Doe',
    email: 'john@example.com',
    age: 30,
    createdAt: new Date(),
  });

  console.log('Inserted user:', result.insertedId);

  // 複数ドキュメントの挿入
  const bulkResult = await users.insertMany([
    { name: 'Alice', email: 'alice@example.com', age: 25 },
    { name: 'Bob', email: 'bob@example.com', age: 35 },
  ]);

  console.log('Inserted users:', bulkResult.insertedCount);
}

// Read
async function findUsers(users: any) {
  // 全件取得
  const allUsers = await users.find({}).toArray();
  console.log('All users:', allUsers);

  // 条件付き検索
  const user = await users.findOne({ email: 'john@example.com' });
  console.log('Found user:', user);

  // IDで検索
  const userById = await users.findOne({
    _id: new ObjectId('507f1f77bcf86cd799439011'),
  });

  // 複数条件
  const adults = await users.find({ age: { $gte: 18 } }).toArray();
  console.log('Adult users:', adults);

  // プロジェクション（フィールド選択）
  const names = await users
    .find({}, { projection: { name: 1, email: 1, _id: 0 } })
    .toArray();
  console.log('User names:', names);

  // ソート
  const sortedUsers = await users.find({}).sort({ age: -1 }).toArray();

  // リミット・スキップ（ページネーション）
  const page = await users.find({}).skip(10).limit(10).toArray();
}

// Update
async function updateUser(users: any) {
  // 単一ドキュメント更新
  const updateResult = await users.updateOne(
    { email: 'john@example.com' },
    {
      $set: { age: 31 },
      $currentDate: { lastModified: true },
    }
  );

  console.log('Updated count:', updateResult.modifiedCount);

  // 複数ドキュメント更新
  const bulkUpdateResult = await users.updateMany(
    { age: { $lt: 18 } },
    { $set: { category: 'minor' } }
  );

  // Upsert（存在しなければ挿入）
  const upsertResult = await users.updateOne(
    { email: 'jane@example.com' },
    {
      $set: { name: 'Jane Doe', age: 28 },
      $setOnInsert: { createdAt: new Date() },
    },
    { upsert: true }
  );

  // フィールド操作
  await users.updateOne(
    { email: 'john@example.com' },
    {
      $inc: { age: 1 }, // インクリメント
      $push: { hobbies: 'swimming' }, // 配列に追加
      $unset: { tempField: '' }, // フィールド削除
    }
  );
}

// Delete
async function deleteUser(users: any) {
  // 単一ドキュメント削除
  const deleteResult = await users.deleteOne({ email: 'john@example.com' });
  console.log('Deleted count:', deleteResult.deletedCount);

  // 複数ドキュメント削除
  const bulkDeleteResult = await users.deleteMany({ age: { $lt: 18 } });

  // 全件削除（注意！）
  // await users.deleteMany({});
}

main().catch(console.error);
```

---

## クエリとフィルタリング

### 比較演算子

```typescript
// 等価
await users.find({ age: 30 }).toArray();

// $eq, $ne
await users.find({ age: { $eq: 30 } }).toArray();
await users.find({ age: { $ne: 30 } }).toArray();

// $gt, $gte, $lt, $lte
await users.find({ age: { $gt: 25 } }).toArray();
await users.find({ age: { $gte: 25, $lte: 35 } }).toArray();

// $in, $nin
await users.find({ age: { $in: [25, 30, 35] } }).toArray();
await users.find({ status: { $nin: ['deleted', 'banned'] } }).toArray();
```

### 論理演算子

```typescript
// $and
await users
  .find({
    $and: [{ age: { $gte: 25 } }, { age: { $lte: 35 } }],
  })
  .toArray();

// 暗黙的な$and
await users.find({ age: { $gte: 25 }, status: 'active' }).toArray();

// $or
await users
  .find({
    $or: [{ age: { $lt: 18 } }, { age: { $gt: 65 } }],
  })
  .toArray();

// $not
await users.find({ age: { $not: { $gt: 30 } } }).toArray();

// $nor
await users
  .find({
    $nor: [{ status: 'deleted' }, { status: 'banned' }],
  })
  .toArray();
```

### 配列クエリ

```typescript
// 配列に要素が含まれる
await users.find({ hobbies: 'reading' }).toArray();

// $all（全ての要素が含まれる）
await users.find({ hobbies: { $all: ['reading', 'gaming'] } }).toArray();

// $elemMatch（配列要素が条件を満たす）
await users
  .find({
    scores: { $elemMatch: { $gte: 80, $lt: 90 } },
  })
  .toArray();

// $size（配列のサイズ）
await users.find({ hobbies: { $size: 3 } }).toArray();
```

### テキスト検索

```typescript
// テキストインデックスの作成
await users.createIndex({ name: 'text', bio: 'text' });

// テキスト検索
await users.find({ $text: { $search: 'john developer' } }).toArray();

// スコア付きテキスト検索
await users
  .find(
    { $text: { $search: 'john developer' } },
    { projection: { score: { $meta: 'textScore' } } }
  )
  .sort({ score: { $meta: 'textScore' } })
  .toArray();
```

### 正規表現

```typescript
// 正規表現マッチ
await users.find({ name: /^John/i }).toArray();

// $regex
await users.find({ email: { $regex: '@example\\.com$', $options: 'i' } }).toArray();
```

---

## インデックス

### インデックスの作成

```typescript
// 単一フィールドインデックス
await users.createIndex({ email: 1 }); // 昇順
await users.createIndex({ age: -1 }); // 降順

// 複合インデックス
await users.createIndex({ lastName: 1, firstName: 1 });

// ユニークインデックス
await users.createIndex({ email: 1 }, { unique: true });

// 部分インデックス
await users.createIndex(
  { email: 1 },
  {
    partialFilterExpression: { age: { $gte: 18 } },
  }
);

// TTLインデックス（自動削除）
await users.createIndex({ createdAt: 1 }, { expireAfterSeconds: 86400 }); // 24時間後に削除

// テキストインデックス
await users.createIndex({ description: 'text' });

// 地理空間インデックス
await locations.createIndex({ location: '2dsphere' });
```

### インデックスの確認

```typescript
// インデックス一覧
const indexes = await users.indexes();
console.log('Indexes:', indexes);

// クエリプラン確認
const explainResult = await users.find({ email: 'john@example.com' }).explain();
console.log('Query plan:', explainResult);
```

---

## 集計パイプライン

### 基本的な集計

```typescript
// $match, $group, $sort
const result = await users
  .aggregate([
    // フィルター
    { $match: { age: { $gte: 18 } } },

    // グループ化
    {
      $group: {
        _id: '$country',
        averageAge: { $avg: '$age' },
        count: { $sum: 1 },
        maxAge: { $max: '$age' },
        minAge: { $min: '$age' },
      },
    },

    // ソート
    { $sort: { averageAge: -1 } },

    // リミット
    { $limit: 10 },
  ])
  .toArray();

console.log('Aggregation result:', result);
```

### 高度な集計

```typescript
const orders = db.collection('orders');

const salesReport = await orders
  .aggregate([
    // 日付範囲でフィルター
    {
      $match: {
        orderDate: {
          $gte: new Date('2024-01-01'),
          $lt: new Date('2024-02-01'),
        },
      },
    },

    // 配列を展開
    { $unwind: '$items' },

    // フィールド追加
    {
      $addFields: {
        itemTotal: { $multiply: ['$items.price', '$items.quantity'] },
      },
    },

    // グループ化
    {
      $group: {
        _id: {
          year: { $year: '$orderDate' },
          month: { $month: '$orderDate' },
          product: '$items.productName',
        },
        totalSales: { $sum: '$itemTotal' },
        totalQuantity: { $sum: '$items.quantity' },
        orderCount: { $sum: 1 },
      },
    },

    // フィールドを再構成
    {
      $project: {
        _id: 0,
        year: '$_id.year',
        month: '$_id.month',
        product: '$_id.product',
        totalSales: 1,
        totalQuantity: 1,
        orderCount: 1,
        averageOrderValue: {
          $divide: ['$totalSales', '$orderCount'],
        },
      },
    },

    // ソート
    { $sort: { totalSales: -1 } },

    // 上位10件
    { $limit: 10 },
  ])
  .toArray();

console.log('Sales report:', salesReport);
```

### Lookup（JOIN）

```typescript
const result = await users
  .aggregate([
    // 他のコレクションと結合
    {
      $lookup: {
        from: 'orders',
        localField: '_id',
        foreignField: 'userId',
        as: 'userOrders',
      },
    },

    // 配列のサイズを計算
    {
      $addFields: {
        orderCount: { $size: '$userOrders' },
      },
    },

    // 不要なフィールドを削除
    { $project: { userOrders: 0 } },
  ])
  .toArray();
```

---

## トランザクション

### ACID トランザクション

```typescript
import { MongoClient } from 'mongodb';

const client = new MongoClient(uri);

async function transferMoney(fromUserId: string, toUserId: string, amount: number) {
  const session = client.startSession();

  try {
    await session.withTransaction(async () => {
      const accounts = client.db('myapp').collection('accounts');

      // 送金元の残高を減らす
      const fromResult = await accounts.updateOne(
        { userId: fromUserId, balance: { $gte: amount } },
        { $inc: { balance: -amount } },
        { session }
      );

      if (fromResult.modifiedCount === 0) {
        throw new Error('Insufficient funds');
      }

      // 送金先の残高を増やす
      await accounts.updateOne(
        { userId: toUserId },
        { $inc: { balance: amount } },
        { session }
      );

      console.log('Transfer successful');
    });
  } finally {
    await session.endSession();
  }
}

// 使用例
await transferMoney('user1', 'user2', 100);
```

---

## Mongoose（Node.js ODM）

### スキーマ定義

```typescript
import mongoose, { Schema, Document } from 'mongoose';

// インターフェース定義
interface IUser extends Document {
  name: string;
  email: string;
  age: number;
  address: {
    street: string;
    city: string;
    country: string;
  };
  hobbies: string[];
  createdAt: Date;
  updatedAt: Date;
}

// スキーマ定義
const userSchema = new Schema<IUser>(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      minlength: [2, 'Name must be at least 2 characters'],
      maxlength: [50, 'Name must be less than 50 characters'],
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email'],
    },
    age: {
      type: Number,
      min: [0, 'Age must be positive'],
      max: [120, 'Age must be less than 120'],
    },
    address: {
      street: String,
      city: String,
      country: {
        type: String,
        enum: ['USA', 'Canada', 'UK', 'Japan'],
      },
    },
    hobbies: [String],
  },
  {
    timestamps: true, // createdAt, updatedAt を自動生成
  }
);

// インデックス
userSchema.index({ email: 1 });
userSchema.index({ name: 'text' });

// 仮想フィールド
userSchema.virtual('fullName').get(function () {
  return `${this.name} (${this.age})`;
});

// インスタンスメソッド
userSchema.methods.isAdult = function (): boolean {
  return this.age >= 18;
};

// スタティックメソッド
userSchema.statics.findByEmail = function (email: string) {
  return this.findOne({ email });
};

// ミドルウェア（pre/post hooks）
userSchema.pre('save', async function (next) {
  console.log('About to save user:', this.email);
  next();
});

userSchema.post('save', function (doc) {
  console.log('User saved:', doc.email);
});

// モデル作成
const User = mongoose.model<IUser>('User', userSchema);

export default User;
```

### Mongoose CRUD操作

```typescript
import mongoose from 'mongoose';
import User from './models/User';

// MongoDB接続
await mongoose.connect('mongodb://admin:password123@localhost:27017/myapp');

// Create
const user = new User({
  name: 'John Doe',
  email: 'john@example.com',
  age: 30,
  address: {
    street: '123 Main St',
    city: 'New York',
    country: 'USA',
  },
  hobbies: ['reading', 'gaming'],
});

await user.save();
console.log('User created:', user._id);

// または create()
const newUser = await User.create({
  name: 'Alice',
  email: 'alice@example.com',
  age: 25,
});

// Read
const allUsers = await User.find();
const johnUser = await User.findOne({ email: 'john@example.com' });
const userById = await User.findById('507f1f77bcf86cd799439011');

// クエリチェーン
const adults = await User.find({ age: { $gte: 18 } })
  .select('name email age')
  .sort({ age: -1 })
  .limit(10)
  .exec();

// Populate（リレーション）
const posts = await Post.find()
  .populate('author') // Userを展開
  .populate({
    path: 'comments',
    select: 'content createdAt',
    populate: {
      path: 'author',
      select: 'name email',
    },
  })
  .exec();

// Update
const updatedUser = await User.findByIdAndUpdate(
  userId,
  { age: 31 },
  { new: true, runValidators: true }
);

await User.updateOne({ email: 'john@example.com' }, { $set: { age: 31 } });

await User.updateMany({ age: { $lt: 18 } }, { $set: { category: 'minor' } });

// Delete
await User.findByIdAndDelete(userId);
await User.deleteOne({ email: 'john@example.com' });
await User.deleteMany({ age: { $lt: 18 } });
```

### リレーション

```typescript
// Post スキーマ
const postSchema = new Schema({
  title: { type: String, required: true },
  content: { type: String, required: true },
  author: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  comments: [
    {
      type: Schema.Types.ObjectId,
      ref: 'Comment',
    },
  ],
  tags: [String],
  likes: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
});

const Post = mongoose.model('Post', postSchema);

// Comment スキーマ
const commentSchema = new Schema({
  content: { type: String, required: true },
  author: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  post: {
    type: Schema.Types.ObjectId,
    ref: 'Post',
    required: true,
  },
  createdAt: { type: Date, default: Date.now },
});

const Comment = mongoose.model('Comment', commentSchema);

// 使用例
const post = await Post.create({
  title: 'My First Post',
  content: 'Hello World',
  author: userId,
});

const comment = await Comment.create({
  content: 'Great post!',
  author: commenterId,
  post: post._id,
});

// Postにコメントを追加
await Post.findByIdAndUpdate(post._id, {
  $push: { comments: comment._id },
});

// Populate
const postWithDetails = await Post.findById(post._id)
  .populate('author', 'name email')
  .populate({
    path: 'comments',
    populate: {
      path: 'author',
      select: 'name',
    },
  })
  .exec();
```

---

## ベストプラクティス

### 1. インデックスの最適化

```typescript
// クエリパターンに基づいてインデックスを作成
await users.createIndex({ email: 1 }); // 頻繁に検索するフィールド
await users.createIndex({ lastName: 1, firstName: 1 }); // 複合クエリ
await users.createIndex({ createdAt: -1 }); // ソート用

// 不要なインデックスは削除
await users.dropIndex('old_index_name');
```

### 2. プロジェクションの使用

```typescript
// 必要なフィールドのみ取得
const users = await User.find({}, 'name email age').exec();

// または
const users = await User.find().select('name email age').exec();

// 除外
const users = await User.find().select('-password -secretField').exec();
```

### 3. ページネーション

```typescript
async function getPaginatedUsers(page: number = 1, limit: number = 10) {
  const skip = (page - 1) * limit;

  const [users, total] = await Promise.all([
    User.find().skip(skip).limit(limit).exec(),
    User.countDocuments(),
  ]);

  return {
    users,
    pagination: {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    },
  };
}
```

### 4. バルク操作

```typescript
// バルク書き込み
const bulkOps = users.map((user) => ({
  updateOne: {
    filter: { _id: user._id },
    update: { $set: { status: 'active' } },
    upsert: true,
  },
}));

await User.bulkWrite(bulkOps);
```

### 5. エラーハンドリング

```typescript
try {
  await User.create({ email: 'duplicate@example.com' });
} catch (error: any) {
  if (error.code === 11000) {
    // 重複キーエラー
    console.error('Email already exists');
  } else if (error.name === 'ValidationError') {
    // バリデーションエラー
    console.error('Validation failed:', error.errors);
  } else {
    console.error('Unknown error:', error);
  }
}
```

### 6. 接続プール

```typescript
// Mongoose
await mongoose.connect(uri, {
  maxPoolSize: 10,
  minPoolSize: 2,
  socketTimeoutMS: 45000,
  serverSelectionTimeoutMS: 5000,
});

// Native Driver
const client = new MongoClient(uri, {
  maxPoolSize: 10,
  minPoolSize: 2,
});
```

### 7. クエリ最適化

```typescript
// Lean（Mongoose）- Plain JavaScript Object を返す（速い）
const users = await User.find().lean().exec();

// Explain でクエリプランを確認
const plan = await User.find({ email: 'john@example.com' }).explain();
console.log('Query plan:', plan);
```

---

## 参考リンク

- [MongoDB 公式ドキュメント](https://www.mongodb.com/docs/)
- [MongoDB Node.js Driver](https://www.mongodb.com/docs/drivers/node/current/)
- [Mongoose](https://mongoosejs.com/)
- [MongoDB University](https://university.mongodb.com/)
