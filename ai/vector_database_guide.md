# Vector Database 完全ガイド

## 目次
1. [Vector Databaseとは](#vector-databaseとは)
2. [Pinecone](#pinecone)
3. [Qdrant](#qdrant)
4. [Chroma](#chroma)
5. [PostgreSQL pgvector](#postgresql-pgvector)
6. [類似度検索](#類似度検索)
7. [ベストプラクティス](#ベストプラクティス)

---

## Vector Databaseとは

Vector Databaseは、高次元ベクトルデータを効率的に保存・検索するための専用データベースです。

### 主な用途

- **セマンティック検索**: 意味的に類似したテキストの検索
- **RAG（Retrieval-Augmented Generation）**: LLMに外部知識を提供
- **レコメンデーション**: 類似アイテムの推薦
- **画像検索**: 類似画像の検索

### 主要なVector Database

- **Pinecone**: フルマネージド、スケーラブル
- **Qdrant**: オープンソース、高性能
- **Chroma**: 開発者フレンドリー
- **pgvector**: PostgreSQL拡張、既存DBと統合可能

---

## Pinecone

### セットアップ

```bash
npm install @pinecone-database/pinecone
npm install @langchain/openai
```

### 初期化

```typescript
import { Pinecone } from '@pinecone-database/pinecone';

const pinecone = new Pinecone({
  apiKey: process.env.PINECONE_API_KEY!,
});

// インデックス一覧取得
const indexes = await pinecone.listIndexes();
console.log(indexes);
```

### インデックス作成

```typescript
// インデックスを作成（OpenAI Embeddingsは1536次元）
await pinecone.createIndex({
  name: 'my-index',
  dimension: 1536,
  metric: 'cosine',
  spec: {
    serverless: {
      cloud: 'aws',
      region: 'us-east-1',
    },
  },
});
```

### ベクトル挿入

```typescript
import { OpenAIEmbeddings } from '@langchain/openai';

const embeddings = new OpenAIEmbeddings();
const index = pinecone.Index('my-index');

// テキストをベクトル化
const texts = [
  'TypeScriptは型安全なJavaScriptです。',
  'Reactはコンポーネントベースのライブラリです。',
  'Next.jsはReactのフレームワークです。',
];

const vectors = await embeddings.embedDocuments(texts);

// Pineconeに挿入
await index.upsert(
  texts.map((text, i) => ({
    id: `doc-${i}`,
    values: vectors[i],
    metadata: { text },
  }))
);
```

### 類似度検索

```typescript
// クエリをベクトル化
const queryText = 'JavaScriptの型について知りたい';
const queryVector = await embeddings.embedQuery(queryText);

// 類似検索
const results = await index.query({
  vector: queryVector,
  topK: 3,
  includeMetadata: true,
});

results.matches.forEach((match) => {
  console.log('Score:', match.score);
  console.log('Text:', match.metadata?.text);
});
```

### LangChain統合

```typescript
import { PineconeStore } from '@langchain/pinecone';
import { Document } from '@langchain/core/documents';

const docs = [
  new Document({
    pageContent: 'TypeScriptは型安全なJavaScriptです。',
    metadata: { source: 'doc1' },
  }),
  new Document({
    pageContent: 'Reactはコンポーネントベースのライブラリです。',
    metadata: { source: 'doc2' },
  }),
];

// ドキュメントを追加
const vectorStore = await PineconeStore.fromDocuments(
  docs,
  embeddings,
  {
    pineconeIndex: index,
    namespace: 'my-namespace',
  }
);

// 検索
const results = await vectorStore.similaritySearch('JavaScript', 2);
console.log(results);
```

### Namespace管理

```typescript
// Namespace別に保存
await PineconeStore.fromDocuments(
  userDocs,
  embeddings,
  {
    pineconeIndex: index,
    namespace: `user-${userId}`,
  }
);

// Namespace指定で検索
const userVectorStore = new PineconeStore(embeddings, {
  pineconeIndex: index,
  namespace: `user-${userId}`,
});

const results = await userVectorStore.similaritySearch('query', 5);
```

---

## Qdrant

### セットアップ

```bash
npm install @qdrant/js-client-rest
```

### 初期化

```typescript
import { QdrantClient } from '@qdrant/js-client-rest';

const client = new QdrantClient({
  url: process.env.QDRANT_URL!,
  apiKey: process.env.QDRANT_API_KEY,
});
```

### コレクション作成

```typescript
await client.createCollection('my_collection', {
  vectors: {
    size: 1536,
    distance: 'Cosine',
  },
});
```

### ポイント追加

```typescript
const texts = [
  'TypeScriptは型安全なJavaScriptです。',
  'Reactはコンポーネントベースのライブラリです。',
];

const vectors = await embeddings.embedDocuments(texts);

await client.upsert('my_collection', {
  points: texts.map((text, i) => ({
    id: i + 1,
    vector: vectors[i],
    payload: { text },
  })),
});
```

### 検索

```typescript
const queryVector = await embeddings.embedQuery('JavaScript');

const results = await client.search('my_collection', {
  vector: queryVector,
  limit: 3,
  with_payload: true,
});

results.forEach((result) => {
  console.log('Score:', result.score);
  console.log('Text:', result.payload?.text);
});
```

### LangChain統合

```typescript
import { QdrantVectorStore } from '@langchain/community/vectorstores/qdrant';

const vectorStore = await QdrantVectorStore.fromDocuments(
  docs,
  embeddings,
  {
    url: process.env.QDRANT_URL!,
    collectionName: 'my_collection',
  }
);

const results = await vectorStore.similaritySearch('query', 3);
```

---

## Chroma

### セットアップ

```bash
npm install chromadb
```

### 初期化

```typescript
import { ChromaClient } from 'chromadb';

const client = new ChromaClient({
  path: process.env.CHROMA_URL || 'http://localhost:8000',
});
```

### コレクション作成

```typescript
const collection = await client.createCollection({
  name: 'my_collection',
  metadata: { description: 'My document collection' },
});
```

### ドキュメント追加

```typescript
await collection.add({
  ids: ['doc1', 'doc2', 'doc3'],
  documents: [
    'TypeScriptは型安全なJavaScriptです。',
    'Reactはコンポーネントベースのライブラリです。',
    'Next.jsはReactのフレームワークです。',
  ],
  metadatas: [
    { source: 'doc1' },
    { source: 'doc2' },
    { source: 'doc3' },
  ],
});
```

### 検索

```typescript
const results = await collection.query({
  queryTexts: ['JavaScript'],
  nResults: 3,
});

console.log(results);
```

### LangChain統合

```typescript
import { Chroma } from '@langchain/community/vectorstores/chroma';

const vectorStore = await Chroma.fromDocuments(
  docs,
  embeddings,
  {
    collectionName: 'my_collection',
    url: process.env.CHROMA_URL,
  }
);

const results = await vectorStore.similaritySearch('query', 3);
```

---

## PostgreSQL pgvector

### セットアップ

```sql
-- PostgreSQL拡張をインストール
CREATE EXTENSION vector;

-- テーブル作成
CREATE TABLE documents (
  id SERIAL PRIMARY KEY,
  content TEXT,
  embedding VECTOR(1536),
  metadata JSONB
);

-- インデックス作成（高速検索用）
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
```

### Node.js統合

```bash
npm install pg
npm install pgvector
```

```typescript
import { Pool } from 'pg';
import pgvector from 'pgvector/pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

await pool.query('CREATE EXTENSION IF NOT EXISTS vector');
await pgvector.registerType(pool);
```

### ベクトル挿入

```typescript
const texts = ['TypeScriptは型安全なJavaScriptです。'];
const vectors = await embeddings.embedDocuments(texts);

await pool.query(
  'INSERT INTO documents (content, embedding, metadata) VALUES ($1, $2, $3)',
  [texts[0], pgvector.toSql(vectors[0]), JSON.stringify({ source: 'doc1' })]
);
```

### 類似度検索

```typescript
const queryVector = await embeddings.embedQuery('JavaScript');

const { rows } = await pool.query(
  `SELECT
    content,
    metadata,
    1 - (embedding <=> $1) AS similarity
  FROM documents
  ORDER BY embedding <=> $1
  LIMIT 3`,
  [pgvector.toSql(queryVector)]
);

rows.forEach((row) => {
  console.log('Similarity:', row.similarity);
  console.log('Content:', row.content);
});
```

### LangChain統合

```typescript
import { PGVectorStore } from '@langchain/community/vectorstores/pgvector';

const vectorStore = await PGVectorStore.fromDocuments(
  docs,
  embeddings,
  {
    postgresConnectionOptions: {
      connectionString: process.env.DATABASE_URL!,
    },
    tableName: 'documents',
  }
);

const results = await vectorStore.similaritySearch('query', 3);
```

---

## 類似度検索

### コサイン類似度

```typescript
function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const magnitudeA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const magnitudeB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}
```

### ユークリッド距離

```typescript
function euclideanDistance(a: number[], b: number[]): number {
  return Math.sqrt(
    a.reduce((sum, val, i) => sum + Math.pow(val - b[i], 2), 0)
  );
}
```

### 類似度検索 + フィルター

```typescript
// Pinecone
const results = await index.query({
  vector: queryVector,
  topK: 5,
  filter: {
    category: { $eq: 'technology' },
    published: { $gte: '2024-01-01' },
  },
  includeMetadata: true,
});

// pgvector
const { rows } = await pool.query(
  `SELECT * FROM documents
  WHERE metadata->>'category' = $1
  ORDER BY embedding <=> $2
  LIMIT 5`,
  ['technology', pgvector.toSql(queryVector)]
);
```

### Hybrid検索（ベクトル + キーワード）

```typescript
// pgvector + Full-text search
const { rows } = await pool.query(
  `SELECT
    *,
    1 - (embedding <=> $1) AS vector_score,
    ts_rank(to_tsvector('english', content), plainto_tsquery('english', $2)) AS text_score
  FROM documents
  WHERE to_tsvector('english', content) @@ plainto_tsquery('english', $2)
  ORDER BY (vector_score * 0.7 + text_score * 0.3) DESC
  LIMIT 5`,
  [pgvector.toSql(queryVector), 'JavaScript']
);
```

---

## ベストプラクティス

### 1. バッチ挿入

```typescript
// 大量データは分割して挿入
async function batchUpsert(documents: Document[], batchSize = 100) {
  const batches = [];

  for (let i = 0; i < documents.length; i += batchSize) {
    batches.push(documents.slice(i, i + batchSize));
  }

  for (const batch of batches) {
    await vectorStore.addDocuments(batch);
  }
}
```

### 2. キャッシング

```typescript
const cache = new Map<string, number[]>();

async function getEmbeddingWithCache(text: string): Promise<number[]> {
  if (cache.has(text)) {
    return cache.get(text)!;
  }

  const embedding = await embeddings.embedQuery(text);
  cache.set(text, embedding);

  return embedding;
}
```

### 3. エラーハンドリング

```typescript
async function safeVectorSearch(query: string) {
  try {
    const results = await vectorStore.similaritySearch(query, 5);
    return results;
  } catch (error) {
    console.error('Vector search failed:', error);

    // フォールバック: キーワード検索
    return await fallbackKeywordSearch(query);
  }
}
```

### 4. メタデータ管理

```typescript
interface DocumentMetadata {
  source: string;
  timestamp: string;
  author: string;
  category: string;
}

const doc = new Document({
  pageContent: 'Content here...',
  metadata: {
    source: 'blog',
    timestamp: new Date().toISOString(),
    author: 'John Doe',
    category: 'technology',
  } as DocumentMetadata,
});
```

### 5. Retrieverパターン

```typescript
import { VectorStoreRetriever } from '@langchain/core/vectorstores';

const retriever = vectorStore.asRetriever({
  k: 5, // 上位5件
  searchType: 'similarity',
  scoreThreshold: 0.8, // 類似度閾値
});

const docs = await retriever.getRelevantDocuments('query');
```

### 6. 定期的な再インデックス

```typescript
async function reindexDocuments() {
  // 古いインデックスを削除
  await pinecone.deleteIndex('my-index');

  // 新しいインデックスを作成
  await pinecone.createIndex({
    name: 'my-index',
    dimension: 1536,
    metric: 'cosine',
  });

  // 全ドキュメントを再挿入
  const documents = await fetchAllDocuments();
  await batchUpsert(documents);
}
```

### 7. モニタリング

```typescript
async function monitorVectorStore() {
  const stats = await index.describeIndexStats();

  console.log('Total vectors:', stats.totalRecordCount);
  console.log('Dimension:', stats.dimension);
  console.log('Index fullness:', stats.indexFullness);
}
```

---

## 参考リンク

- [Pinecone Documentation](https://docs.pinecone.io/)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Chroma Documentation](https://docs.trychroma.com/)
- [pgvector GitHub](https://github.com/pgvector/pgvector)
