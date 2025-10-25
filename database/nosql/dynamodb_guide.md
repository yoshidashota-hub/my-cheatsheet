# AWS DynamoDB 完全ガイド

## 目次
- [DynamoDBとは](#dynamodbとは)
- [テーブル設計](#テーブル設計)
- [基本操作](#基本操作)
- [クエリとスキャン](#クエリとスキャン)
- [インデックス](#インデックス)
- [トランザクション](#トランザクション)
- [DynamoDB Streams](#dynamodb-streams)
- [ベストプラクティス](#ベストプラクティス)

---

## DynamoDBとは

AWSのフルマネージドNoSQLデータベース。サーバーレスアプリケーションに最適。

### 特徴

- ⚡ 高速・低レイテンシー（ミリ秒単位）
- 📈 自動スケーリング
- 💰 従量課金
- 🔄 レプリケーション
- 🔒 暗号化

### ユースケース

```
✓ モバイル・Webアプリケーション
✓ ゲーム
✓ IoT
✓ リアルタイムアプリ
✓ セッション管理
```

---

## テーブル設計

### キー設計

```
Primary Key:
- Partition Key (PK): データ分散のキー
- Sort Key (SK): パーティション内のソート順
```

#### シングルテーブルデザイン

```typescript
// 1つのテーブルで複数のエンティティを管理

Table: AppData
┌──────────────┬──────────────┬────────────┐
│ PK           │ SK           │ Attributes │
├──────────────┼──────────────┼────────────┤
│ USER#123     │ PROFILE      │ {name,...} │
│ USER#123     │ ORDER#001    │ {total,..} │
│ USER#123     │ ORDER#002    │ {total,..} │
│ PRODUCT#456  │ METADATA     │ {price,..} │
│ PRODUCT#456  │ REVIEW#001   │ {rating,..}│
└──────────────┴──────────────┴────────────┘

利点:
- テーブル数削減
- JOIN不要
- 効率的なクエリ
```

### データ型

```typescript
// String
PK: 'USER#123'

// Number
age: 30

// Binary
image: Buffer.from('...')

// Boolean
active: true

// Null
deleted: null

// List
tags: ['tech', 'news']

// Map
address: { city: 'Tokyo', zip: '100-0001' }

// Set
categories: new Set(['A', 'B', 'C'])
```

---

## 基本操作

### セットアップ

```bash
npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb
```

```typescript
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, PutCommand, GetCommand, UpdateCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb'

const client = new DynamoDBClient({ region: 'ap-northeast-1' })
const docClient = DynamoDBDocumentClient.from(client)

const TABLE_NAME = 'Users'
```

### Put Item（作成・上書き）

```typescript
async function createUser(userId: string, email: string, name: string) {
  const command = new PutCommand({
    TableName: TABLE_NAME,
    Item: {
      PK: `USER#${userId}`,
      SK: 'PROFILE',
      userId,
      email,
      name,
      createdAt: new Date().toISOString()
    }
  })

  await docClient.send(command)
}
```

### Get Item（取得）

```typescript
async function getUser(userId: string) {
  const command = new GetCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: `USER#${userId}`,
      SK: 'PROFILE'
    }
  })

  const response = await docClient.send(command)
  return response.Item
}
```

### Update Item（更新）

```typescript
async function updateUserEmail(userId: string, newEmail: string) {
  const command = new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: `USER#${userId}`,
      SK: 'PROFILE'
    },
    UpdateExpression: 'SET email = :email, updatedAt = :updatedAt',
    ExpressionAttributeValues: {
      ':email': newEmail,
      ':updatedAt': new Date().toISOString()
    },
    ReturnValues: 'ALL_NEW'
  })

  const response = await docClient.send(command)
  return response.Attributes
}

// 条件付き更新
async function incrementViewCount(postId: string) {
  const command = new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: `POST#${postId}`,
      SK: 'METADATA'
    },
    UpdateExpression: 'ADD viewCount :inc',
    ExpressionAttributeValues: {
      ':inc': 1
    }
  })

  await docClient.send(command)
}
```

### Delete Item（削除）

```typescript
async function deleteUser(userId: string) {
  const command = new DeleteCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: `USER#${userId}`,
      SK: 'PROFILE'
    }
  })

  await docClient.send(command)
}

// 条件付き削除
async function deleteIfExists(userId: string) {
  const command = new DeleteCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: `USER#${userId}`,
      SK: 'PROFILE'
    },
    ConditionExpression: 'attribute_exists(PK)'
  })

  try {
    await docClient.send(command)
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      console.log('Item does not exist')
    }
  }
}
```

---

## クエリとスキャン

### Query（効率的）

```typescript
import { QueryCommand } from '@aws-sdk/lib-dynamodb'

// ユーザーの全注文を取得
async function getUserOrders(userId: string) {
  const command = new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
    ExpressionAttributeValues: {
      ':pk': `USER#${userId}`,
      ':sk': 'ORDER#'
    }
  })

  const response = await docClient.send(command)
  return response.Items
}

// 範囲指定
async function getOrdersInRange(userId: string, startDate: string, endDate: string) {
  const command = new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: 'PK = :pk AND SK BETWEEN :start AND :end',
    ExpressionAttributeValues: {
      ':pk': `USER#${userId}`,
      ':start': `ORDER#${startDate}`,
      ':end': `ORDER#${endDate}`
    }
  })

  const response = await docClient.send(command)
  return response.Items
}

// ページネーション
async function queryWithPagination(userId: string, limit: number = 20, lastKey?: any) {
  const command = new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: 'PK = :pk',
    ExpressionAttributeValues: {
      ':pk': `USER#${userId}`
    },
    Limit: limit,
    ExclusiveStartKey: lastKey
  })

  const response = await docClient.send(command)

  return {
    items: response.Items,
    lastKey: response.LastEvaluatedKey
  }
}
```

### Scan（全件検索・非効率）

```typescript
import { ScanCommand } from '@aws-sdk/lib-dynamodb'

// 全ユーザー取得（非推奨：テーブルが大きいと遅い）
async function getAllUsers() {
  const command = new ScanCommand({
    TableName: TABLE_NAME,
    FilterExpression: 'begins_with(SK, :sk)',
    ExpressionAttributeValues: {
      ':sk': 'PROFILE'
    }
  })

  const response = await docClient.send(command)
  return response.Items
}

// 並列スキャン（大量データ向け）
async function parallelScan(totalSegments: number = 4) {
  const promises = []

  for (let segment = 0; segment < totalSegments; segment++) {
    const command = new ScanCommand({
      TableName: TABLE_NAME,
      Segment: segment,
      TotalSegments: totalSegments
    })

    promises.push(docClient.send(command))
  }

  const results = await Promise.all(promises)
  return results.flatMap(r => r.Items || [])
}
```

---

## インデックス

### Global Secondary Index (GSI)

```typescript
// テーブル作成時にGSI定義
// GSI: email → userId

async function getUserByEmail(email: string) {
  const command = new QueryCommand({
    TableName: TABLE_NAME,
    IndexName: 'EmailIndex', // GSI名
    KeyConditionExpression: 'email = :email',
    ExpressionAttributeValues: {
      ':email': email
    }
  })

  const response = await docClient.send(command)
  return response.Items?.[0]
}
```

### Local Secondary Index (LSI)

```typescript
// 同じパーティションキー、異なるソートキー

async function getPostsByDate(userId: string) {
  const command = new QueryCommand({
    TableName: TABLE_NAME,
    IndexName: 'UserDateIndex', // LSI名
    KeyConditionExpression: 'PK = :pk',
    ExpressionAttributeValues: {
      ':pk': `USER#${userId}`
    },
    ScanIndexForward: false // 降順
  })

  const response = await docClient.send(command)
  return response.Items
}
```

---

## トランザクション

### TransactWrite（複数の書き込み）

```typescript
import { TransactWriteCommand } from '@aws-sdk/lib-dynamodb'

async function transferPoints(fromUserId: string, toUserId: string, points: number) {
  const command = new TransactWriteCommand({
    TransactItems: [
      {
        Update: {
          TableName: TABLE_NAME,
          Key: { PK: `USER#${fromUserId}`, SK: 'PROFILE' },
          UpdateExpression: 'SET points = points - :points',
          ConditionExpression: 'points >= :points',
          ExpressionAttributeValues: { ':points': points }
        }
      },
      {
        Update: {
          TableName: TABLE_NAME,
          Key: { PK: `USER#${toUserId}`, SK: 'PROFILE' },
          UpdateExpression: 'SET points = points + :points',
          ExpressionAttributeValues: { ':points': points }
        }
      }
    ]
  })

  try {
    await docClient.send(command)
    return { success: true }
  } catch (error) {
    if (error.name === 'TransactionCanceledException') {
      console.error('Transaction failed:', error)
      return { success: false, error: 'Insufficient points' }
    }
    throw error
  }
}
```

### TransactGet（複数の読み込み）

```typescript
import { TransactGetCommand } from '@aws-sdk/lib-dynamodb'

async function getMultipleItems(userIds: string[]) {
  const command = new TransactGetCommand({
    TransactItems: userIds.map(userId => ({
      Get: {
        TableName: TABLE_NAME,
        Key: { PK: `USER#${userId}`, SK: 'PROFILE' }
      }
    }))
  })

  const response = await docClient.send(command)
  return response.Responses?.map(r => r.Item)
}
```

---

## DynamoDB Streams

変更をリアルタイムでキャプチャ。

### Lambda連携

```typescript
// Lambda関数でStream処理
import { DynamoDBStreamEvent } from 'aws-lambda'

export const handler = async (event: DynamoDBStreamEvent) => {
  for (const record of event.Records) {
    if (record.eventName === 'INSERT') {
      const newItem = record.dynamodb?.NewImage
      console.log('New item:', newItem)

      // 例: Elasticsearchにインデックス
      await indexToElasticsearch(newItem)
    }

    if (record.eventName === 'MODIFY') {
      const oldItem = record.dynamodb?.OldImage
      const newItem = record.dynamodb?.NewImage
      console.log('Updated:', { old: oldItem, new: newItem })
    }

    if (record.eventName === 'REMOVE') {
      const deletedItem = record.dynamodb?.OldImage
      console.log('Deleted:', deletedItem)
    }
  }
}
```

---

## ベストプラクティス

### 1. アクセスパターンを先に設計

```
✓ 最初にクエリパターンを定義
✓ テーブル・インデックス設計
✓ RDBMSの正規化は不要
```

### 2. ホットパーティション回避

```typescript
// ✗ 悪い例
PK: 'USER' // 全データが1パーティション

// ○ 良い例
PK: `USER#${userId}` // ユーザーごとに分散
```

### 3. 適切なキャパシティモード

```
On-Demand:
- 予測不可能なトラフィック
- 新規アプリケーション

Provisioned:
- 予測可能なトラフィック
- コスト最適化
```

### 4. バッチ操作

```typescript
import { BatchWriteCommand, BatchGetCommand } from '@aws-sdk/lib-dynamodb'

// バッチ書き込み（最大25件）
async function batchWrite(items: any[]) {
  const command = new BatchWriteCommand({
    RequestItems: {
      [TABLE_NAME]: items.map(item => ({
        PutRequest: { Item: item }
      }))
    }
  })

  await docClient.send(command)
}

// バッチ取得（最大100件）
async function batchGet(keys: any[]) {
  const command = new BatchGetCommand({
    RequestItems: {
      [TABLE_NAME]: {
        Keys: keys
      }
    }
  })

  const response = await docClient.send(command)
  return response.Responses?.[TABLE_NAME]
}
```

### 5. TTL（Time To Live）

```typescript
// 自動削除（セッション管理等）
async function createSession(sessionId: string, userId: string) {
  const ttl = Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24時間後

  const command = new PutCommand({
    TableName: TABLE_NAME,
    Item: {
      PK: `SESSION#${sessionId}`,
      SK: 'DATA',
      userId,
      ttl // TTL属性
    }
  })

  await docClient.send(command)
}
```

### 6. 条件式

```typescript
// 重複防止
async function createUserIfNotExists(userId: string, email: string) {
  const command = new PutCommand({
    TableName: TABLE_NAME,
    Item: {
      PK: `USER#${userId}`,
      SK: 'PROFILE',
      email
    },
    ConditionExpression: 'attribute_not_exists(PK)'
  })

  try {
    await docClient.send(command)
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      throw new Error('User already exists')
    }
  }
}
```

---

## パフォーマンス最適化

### 1. Projection（必要な属性のみ取得）

```typescript
const command = new QueryCommand({
  TableName: TABLE_NAME,
  KeyConditionExpression: 'PK = :pk',
  ExpressionAttributeValues: { ':pk': userId },
  ProjectionExpression: 'userId, email, #name',
  ExpressionAttributeNames: { '#name': 'name' } // 予約語の場合
})
```

### 2. 並列クエリ

```typescript
async function getMultipleUsers(userIds: string[]) {
  const promises = userIds.map(userId =>
    docClient.send(new GetCommand({
      TableName: TABLE_NAME,
      Key: { PK: `USER#${userId}`, SK: 'PROFILE' }
    }))
  )

  const results = await Promise.all(promises)
  return results.map(r => r.Item)
}
```

---

## 参考リンク

- [AWS DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Single Table Design](https://www.alexdebrie.com/posts/dynamodb-single-table/)
