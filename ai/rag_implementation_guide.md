# RAG（Retrieval-Augmented Generation）完全ガイド

## 目次
1. [RAGとは](#ragとは)
2. [基本的なRAG実装](#基本的なrag実装)
3. [高度なRAGパターン](#高度なragパターン)
4. [チャンク戦略](#チャンク戦略)
5. [リランキング](#リランキング)
6. [ハイブリッド検索](#ハイブリッド検索)
7. [本番環境実装](#本番環境実装)
8. [ベストプラクティス](#ベストプラクティス)

---

## RAGとは

RAG（Retrieval-Augmented Generation）は、外部知識ベースから関連情報を検索し、その情報を使ってLLMがより正確な回答を生成する手法です。

### RAGの利点

- **最新情報**: トレーニングデータ以降の情報も利用可能
- **正確性向上**: 事実に基づいた回答
- **ハルシネーション削減**: 誤情報の生成を抑制
- **ドメイン特化**: 特定分野の専門知識を提供

---

## 基本的なRAG実装

### シンプルなRAG

```typescript
import { OpenAIEmbeddings, ChatOpenAI } from '@langchain/openai';
import { PineconeStore } from '@langchain/pinecone';
import { Pinecone } from '@pinecone-database/pinecone';
import { PromptTemplate } from '@langchain/core/prompts';

// 初期化
const embeddings = new OpenAIEmbeddings();
const llm = new ChatOpenAI({ modelName: 'gpt-4-turbo-preview' });

const pinecone = new Pinecone();
const index = pinecone.Index('my-index');

const vectorStore = new PineconeStore(embeddings, {
  pineconeIndex: index,
});

// RAG関数
async function simpleRAG(query: string) {
  // 1. 関連ドキュメントを検索
  const relevantDocs = await vectorStore.similaritySearch(query, 3);

  // 2. コンテキストを構築
  const context = relevantDocs
    .map((doc) => doc.pageContent)
    .join('\n\n');

  // 3. プロンプトを作成
  const prompt = PromptTemplate.fromTemplate(`
以下のコンテキストを使用して質問に答えてください。
コンテキストに情報がない場合は「わかりません」と答えてください。

コンテキスト:
{context}

質問: {question}

回答:`);

  const formattedPrompt = await prompt.format({
    context,
    question: query,
  });

  // 4. LLMで回答生成
  const response = await llm.invoke(formattedPrompt);

  return {
    answer: response.content,
    sources: relevantDocs,
  };
}

// 使用例
const result = await simpleRAG('LangChainのメモリ管理について教えて');
console.log('Answer:', result.answer);
console.log('Sources:', result.sources.length);
```

### RetrievalQAChain

```typescript
import { RetrievalQAChain } from 'langchain/chains';

const chain = RetrievalQAChain.fromLLM(
  llm,
  vectorStore.asRetriever({
    k: 3,
  })
);

const response = await chain.call({
  query: 'LangChainとは何ですか？',
});

console.log(response.text);
```

### ConversationalRetrievalChain

```typescript
import { ConversationalRetrievalQAChain } from 'langchain/chains';
import { BufferMemory } from 'langchain/memory';

const memory = new BufferMemory({
  memoryKey: 'chat_history',
  returnMessages: true,
});

const conversationalChain = ConversationalRetrievalQAChain.fromLLM(
  llm,
  vectorStore.asRetriever(),
  {
    memory,
    returnSourceDocuments: true,
  }
);

// 会話1
const response1 = await conversationalChain.call({
  question: 'LangChainとは何ですか？',
});

// 会話2（前の文脈を踏まえた質問）
const response2 = await conversationalChain.call({
  question: 'それの主な機能は？',
});

console.log(response2.text);
console.log('Sources:', response2.sourceDocuments);
```

---

## 高度なRAGパターン

### Multi-Query RAG

```typescript
import { MultiQueryRetriever } from 'langchain/retrievers/multi_query';

// 1つの質問から複数のクエリを生成
const retriever = MultiQueryRetriever.fromLLM({
  llm,
  retriever: vectorStore.asRetriever(),
  verbose: true,
});

const docs = await retriever.getRelevantDocuments(
  'JavaScriptのフレームワークについて教えて'
);
```

### Parent Document Retriever

```typescript
import { ParentDocumentRetriever } from 'langchain/retrievers/parent_document_retriever';
import { InMemoryStore } from 'langchain/storage/in_memory';
import { RecursiveCharacterTextSplitter } from 'langchain/text_splitter';

// 小さいチャンクで検索、大きいチャンクを返す
const parentDocumentRetriever = new ParentDocumentRetriever({
  vectorstore: vectorStore,
  docstore: new InMemoryStore(),
  parentSplitter: new RecursiveCharacterTextSplitter({
    chunkSize: 2000,
    chunkOverlap: 200,
  }),
  childSplitter: new RecursiveCharacterTextSplitter({
    chunkSize: 400,
    chunkOverlap: 50,
  }),
});

await parentDocumentRetriever.addDocuments(documents);

const docs = await parentDocumentRetriever.getRelevantDocuments('query');
```

### Ensemble Retriever

```typescript
import { EnsembleRetriever } from 'langchain/retrievers/ensemble';

// 複数のRetrieverを組み合わせる
const ensembleRetriever = new EnsembleRetriever({
  retrievers: [
    vectorStore.asRetriever({ k: 3 }),
    bm25Retriever,
  ],
  weights: [0.7, 0.3], // ベクトル検索70%、BM25 30%
});

const docs = await ensembleRetriever.getRelevantDocuments('query');
```

---

## チャンク戦略

### RecursiveCharacterTextSplitter

```typescript
import { RecursiveCharacterTextSplitter } from 'langchain/text_splitter';

const splitter = new RecursiveCharacterTextSplitter({
  chunkSize: 1000,
  chunkOverlap: 200,
  separators: ['\n\n', '\n', ' ', ''],
});

const docs = await splitter.createDocuments([longText]);
```

### MarkdownTextSplitter

```typescript
import { MarkdownTextSplitter } from 'langchain/text_splitter';

const markdownSplitter = new MarkdownTextSplitter({
  chunkSize: 1000,
  chunkOverlap: 200,
});

const docs = await markdownSplitter.createDocuments([markdownText]);
```

### Semantic Chunking

```typescript
import { Document } from '@langchain/core/documents';

async function semanticChunking(text: string): Promise<Document[]> {
  // テキストを文に分割
  const sentences = text.split(/[.!?]+/);

  const chunks: Document[] = [];
  let currentChunk = '';
  let previousEmbedding: number[] | null = null;

  for (const sentence of sentences) {
    const currentText = currentChunk + sentence;
    const currentEmbedding = await embeddings.embedQuery(currentText);

    if (previousEmbedding) {
      // 類似度を計算
      const similarity = cosineSimilarity(previousEmbedding, currentEmbedding);

      // 類似度が閾値以下なら新しいチャンクを作成
      if (similarity < 0.8 || currentChunk.length > 1000) {
        chunks.push(new Document({ pageContent: currentChunk }));
        currentChunk = sentence;
      } else {
        currentChunk += sentence;
      }
    } else {
      currentChunk += sentence;
    }

    previousEmbedding = currentEmbedding;
  }

  if (currentChunk) {
    chunks.push(new Document({ pageContent: currentChunk }));
  }

  return chunks;
}

function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const magnitudeA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const magnitudeB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}
```

---

## リランキング

### Cohere Reranking

```typescript
import { CohereRerank } from '@langchain/cohere';

const reranker = new CohereRerank({
  apiKey: process.env.COHERE_API_KEY,
  topN: 3,
  model: 'rerank-english-v2.0',
});

// 1. 初期検索（多めに取得）
const initialDocs = await vectorStore.similaritySearch(query, 10);

// 2. リランキング
const rerankedDocs = await reranker.compressDocuments(initialDocs, query);

console.log('Reranked docs:', rerankedDocs);
```

### カスタムリランキング

```typescript
async function customReranking(
  query: string,
  docs: Document[]
): Promise<Document[]> {
  const queryEmbedding = await embeddings.embedQuery(query);

  // 各ドキュメントとクエリの類似度を計算
  const scores = await Promise.all(
    docs.map(async (doc) => {
      const docEmbedding = await embeddings.embedQuery(doc.pageContent);
      const similarity = cosineSimilarity(queryEmbedding, docEmbedding);

      return {
        doc,
        score: similarity,
      };
    })
  );

  // スコアでソート
  scores.sort((a, b) => b.score - a.score);

  // 上位を返す
  return scores.slice(0, 3).map((s) => s.doc);
}
```

---

## ハイブリッド検索

### ベクトル検索 + キーワード検索

```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function hybridSearch(query: string) {
  // 1. ベクトル検索
  const vectorResults = await vectorStore.similaritySearch(query, 10);

  // 2. キーワード検索（PostgreSQL Full-text）
  const keywordResults = await prisma.$queryRaw`
    SELECT *
    FROM documents
    WHERE to_tsvector('english', content) @@ plainto_tsquery('english', ${query})
    ORDER BY ts_rank(to_tsvector('english', content), plainto_tsquery('english', ${query})) DESC
    LIMIT 10
  `;

  // 3. スコアを組み合わせる
  const combinedScores = new Map<string, number>();

  vectorResults.forEach((doc, index) => {
    const score = (10 - index) / 10; // 0.1〜1.0
    combinedScores.set(doc.id, (combinedScores.get(doc.id) || 0) + score * 0.7);
  });

  keywordResults.forEach((doc: any, index: number) => {
    const score = (10 - index) / 10;
    combinedScores.set(doc.id, (combinedScores.get(doc.id) || 0) + score * 0.3);
  });

  // 4. スコアでソート
  const sortedResults = Array.from(combinedScores.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3);

  return sortedResults;
}
```

---

## 本番環境実装

### Express API

```typescript
import express from 'express';
import { z } from 'zod';

const app = express();
app.use(express.json());

const querySchema = z.object({
  question: z.string().min(1),
  sessionId: z.string().optional(),
});

// RAGエンドポイント
app.post('/api/rag/query', async (req, res) => {
  try {
    const { question, sessionId } = querySchema.parse(req.body);

    const result = await simpleRAG(question);

    res.json({
      answer: result.answer,
      sources: result.sources.map((doc) => ({
        content: doc.pageContent,
        metadata: doc.metadata,
      })),
    });
  } catch (error) {
    console.error('RAG error:', error);
    res.status(500).json({ error: 'Failed to process query' });
  }
});

// ストリーミングRAG
app.post('/api/rag/stream', async (req, res) => {
  const { question } = req.body;

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  try {
    // 関連ドキュメントを検索
    const relevantDocs = await vectorStore.similaritySearch(question, 3);
    const context = relevantDocs.map((doc) => doc.pageContent).join('\n\n');

    const prompt = `コンテキスト: ${context}\n\n質問: ${question}\n\n回答:`;

    // ストリーミング
    const stream = await llm.stream(prompt);

    for await (const chunk of stream) {
      res.write(`data: ${JSON.stringify({ content: chunk.content })}\n\n`);
    }

    res.write(`data: [DONE]\n\n`);
    res.end();
  } catch (error) {
    res.write(`data: ${JSON.stringify({ error: 'Failed' })}\n\n`);
    res.end();
  }
});

app.listen(3000, () => {
  console.log('RAG API running on port 3000');
});
```

### ドキュメント管理API

```typescript
// ドキュメント追加
app.post('/api/rag/documents', async (req, res) => {
  try {
    const { content, metadata } = req.body;

    const doc = new Document({
      pageContent: content,
      metadata,
    });

    await vectorStore.addDocuments([doc]);

    res.json({ message: 'Document added successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to add document' });
  }
});

// ドキュメント削除
app.delete('/api/rag/documents/:id', async (req, res) => {
  try {
    const { id } = req.params;

    await index.deleteOne(id);

    res.json({ message: 'Document deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete document' });
  }
});
```

---

## ベストプラクティス

### 1. クエリ最適化

```typescript
async function optimizeQuery(query: string): Promise<string> {
  const prompt = `以下のユーザーの質問を、検索に最適化したクエリに変換してください。

ユーザーの質問: ${query}

最適化されたクエリ:`;

  const response = await llm.invoke(prompt);
  return response.content as string;
}

// 使用例
const userQuery = 'JavaScriptのフレームワークで一番人気なのは？';
const optimizedQuery = await optimizeQuery(userQuery);
const results = await vectorStore.similaritySearch(optimizedQuery, 3);
```

### 2. ソース引用

```typescript
interface RAGResponse {
  answer: string;
  sources: {
    content: string;
    metadata: {
      source: string;
      page?: number;
    };
    relevanceScore: number;
  }[];
}

async function ragWithCitations(query: string): Promise<RAGResponse> {
  const results = await vectorStore.similaritySearchWithScore(query, 3);

  const context = results
    .map(([doc, score], index) => `[${index + 1}] ${doc.pageContent}`)
    .join('\n\n');

  const prompt = `以下のコンテキストを使用して質問に答えてください。
回答には必ず引用番号[1], [2]を含めてください。

コンテキスト:
${context}

質問: ${query}

回答:`;

  const response = await llm.invoke(prompt);

  return {
    answer: response.content as string,
    sources: results.map(([doc, score], index) => ({
      content: doc.pageContent,
      metadata: doc.metadata,
      relevanceScore: score,
    })),
  };
}
```

### 3. キャッシング

```typescript
import Redis from 'ioredis';

const redis = new Redis();

async function cachedRAG(query: string) {
  const cacheKey = `rag:${query}`;

  // キャッシュチェック
  const cached = await redis.get(cacheKey);
  if (cached) {
    return JSON.parse(cached);
  }

  // RAG実行
  const result = await simpleRAG(query);

  // キャッシュに保存（1時間）
  await redis.setex(cacheKey, 3600, JSON.stringify(result));

  return result;
}
```

### 4. エラーハンドリング

```typescript
async function robustRAG(query: string) {
  try {
    // RAG実行
    const result = await simpleRAG(query);

    // ソースがない場合
    if (result.sources.length === 0) {
      return {
        answer: '関連する情報が見つかりませんでした。',
        sources: [],
      };
    }

    return result;
  } catch (error) {
    console.error('RAG error:', error);

    // フォールバック: ソースなしで回答
    const response = await llm.invoke(query);
    return {
      answer: response.content,
      sources: [],
      fallback: true,
    };
  }
}
```

### 5. メトリクス収集

```typescript
interface RAGMetrics {
  query: string;
  retrievalTime: number;
  generationTime: number;
  totalTime: number;
  numSources: number;
  relevanceScores: number[];
}

async function ragWithMetrics(query: string): Promise<RAGMetrics> {
  const startTime = Date.now();

  // 検索
  const retrievalStart = Date.now();
  const results = await vectorStore.similaritySearchWithScore(query, 3);
  const retrievalTime = Date.now() - retrievalStart;

  const context = results.map(([doc]) => doc.pageContent).join('\n\n');
  const prompt = `コンテキスト: ${context}\n\n質問: ${query}\n\n回答:`;

  // 生成
  const generationStart = Date.now();
  await llm.invoke(prompt);
  const generationTime = Date.now() - generationStart;

  const totalTime = Date.now() - startTime;

  return {
    query,
    retrievalTime,
    generationTime,
    totalTime,
    numSources: results.length,
    relevanceScores: results.map(([, score]) => score),
  };
}
```

### 6. マルチテナント対応

```typescript
async function tenantRAG(tenantId: string, query: string) {
  // テナント専用のNamespaceを使用
  const tenantVectorStore = new PineconeStore(embeddings, {
    pineconeIndex: index,
    namespace: `tenant-${tenantId}`,
  });

  const results = await tenantVectorStore.similaritySearch(query, 3);

  // ... RAG処理
}
```

---

## 参考リンク

- [LangChain RAG Tutorial](https://js.langchain.com/docs/use_cases/question_answering/)
- [RAG Best Practices](https://www.pinecone.io/learn/retrieval-augmented-generation/)
- [Advanced RAG Techniques](https://www.anthropic.com/index/retrieval-augmented-generation)
