# LangChain 完全ガイド

## 目次
1. [LangChainとは](#langchainとは)
2. [セットアップ](#セットアップ)
3. [基本的な使い方](#基本的な使い方)
4. [チェーン構築](#チェーン構築)
5. [エージェント](#エージェント)
6. [メモリ管理](#メモリ管理)
7. [ドキュメント処理](#ドキュメント処理)
8. [ベストプラクティス](#ベストプラクティス)

---

## LangChainとは

LangChainは、大規模言語モデル（LLM）を使用したアプリケーション開発を簡素化するフレームワークです。

### 主な機能

- **チェーン**: 複数のコンポーネントを連結
- **エージェント**: 動的にツールを選択して実行
- **メモリ**: 会話履歴の管理
- **ドキュメントローダー**: 様々な形式のデータ読み込み

---

## セットアップ

### インストール

```bash
npm install langchain
npm install @langchain/openai
npm install @langchain/community
```

### 環境変数

```bash
# .env
OPENAI_API_KEY=your-api-key-here
```

---

## 基本的な使い方

### LLMの初期化

```typescript
import { ChatOpenAI } from '@langchain/openai';

const llm = new ChatOpenAI({
  modelName: 'gpt-4-turbo-preview',
  temperature: 0.7,
  maxTokens: 1000,
});

// 基本的な呼び出し
const response = await llm.invoke('こんにちは！');
console.log(response.content);
```

### プロンプトテンプレート

```typescript
import { PromptTemplate } from '@langchain/core/prompts';

const template = new PromptTemplate({
  template: '次の質問に答えてください: {question}',
  inputVariables: ['question'],
});

const prompt = await template.format({
  question: 'LangChainとは何ですか？',
});

const response = await llm.invoke(prompt);
console.log(response.content);
```

### ChatPromptTemplate

```typescript
import { ChatPromptTemplate } from '@langchain/core/prompts';

const chatPrompt = ChatPromptTemplate.fromMessages([
  ['system', 'あなたは親切なアシスタントです。'],
  ['human', '{question}'],
]);

const chain = chatPrompt.pipe(llm);

const response = await chain.invoke({
  question: 'TypeScriptの利点は何ですか？',
});

console.log(response.content);
```

---

## チェーン構築

### 基本的なチェーン

```typescript
import { RunnableSequence } from '@langchain/core/runnables';
import { StringOutputParser } from '@langchain/core/output_parsers';

const chain = RunnableSequence.from([
  chatPrompt,
  llm,
  new StringOutputParser(),
]);

const result = await chain.invoke({
  question: 'Reactとは何ですか？',
});

console.log(result); // 文字列として出力
```

### 複数ステップのチェーン

```typescript
const translationPrompt = ChatPromptTemplate.fromMessages([
  ['system', 'あなたは翻訳者です。英語から日本語に翻訳してください。'],
  ['human', '{text}'],
]);

const summaryPrompt = ChatPromptTemplate.fromMessages([
  ['system', 'あなたは要約の専門家です。以下のテキストを簡潔に要約してください。'],
  ['human', '{text}'],
]);

// 翻訳 → 要約のチェーン
const translateAndSummarize = RunnableSequence.from([
  {
    translatedText: translationPrompt.pipe(llm).pipe(new StringOutputParser()),
  },
  summaryPrompt,
  llm,
  new StringOutputParser(),
]);

const result = await translateAndSummarize.invoke({
  text: 'LangChain is a framework for developing applications powered by language models.',
});

console.log(result);
```

### 並列実行チェーン

```typescript
import { RunnableParallel } from '@langchain/core/runnables';

const parallel = RunnableParallel.from({
  translation: translationPrompt.pipe(llm).pipe(new StringOutputParser()),
  summary: summaryPrompt.pipe(llm).pipe(new StringOutputParser()),
});

const results = await parallel.invoke({
  text: 'Some English text...',
});

console.log('Translation:', results.translation);
console.log('Summary:', results.summary);
```

---

## エージェント

### ツールの定義

```typescript
import { DynamicStructuredTool } from '@langchain/core/tools';
import { z } from 'zod';

const weatherTool = new DynamicStructuredTool({
  name: 'get_weather',
  description: '指定された都市の天気を取得します',
  schema: z.object({
    city: z.string().describe('都市名'),
  }),
  func: async ({ city }) => {
    // 実際のAPI呼び出し
    return `${city}の天気は晴れです。気温は25度です。`;
  },
});

const calculatorTool = new DynamicStructuredTool({
  name: 'calculator',
  description: '数学的な計算を実行します',
  schema: z.object({
    expression: z.string().describe('計算式（例: 2 + 2）'),
  }),
  func: async ({ expression }) => {
    try {
      const result = eval(expression);
      return `計算結果: ${result}`;
    } catch (error) {
      return 'エラー: 計算できませんでした';
    }
  },
});
```

### エージェントの作成

```typescript
import { AgentExecutor, createOpenAIFunctionsAgent } from 'langchain/agents';
import { ChatPromptTemplate } from '@langchain/core/prompts';

const tools = [weatherTool, calculatorTool];

const prompt = ChatPromptTemplate.fromMessages([
  ['system', 'あなたは親切なアシスタントです。ツールを使って質問に答えてください。'],
  ['human', '{input}'],
  ['placeholder', '{agent_scratchpad}'],
]);

const agent = await createOpenAIFunctionsAgent({
  llm,
  tools,
  prompt,
});

const agentExecutor = new AgentExecutor({
  agent,
  tools,
  verbose: true,
});

// エージェントの実行
const result = await agentExecutor.invoke({
  input: '東京の天気を教えて、その後に10+5を計算して',
});

console.log(result.output);
```

---

## メモリ管理

### BufferMemory

```typescript
import { BufferMemory } from 'langchain/memory';
import { ConversationChain } from 'langchain/chains';

const memory = new BufferMemory({
  returnMessages: true,
  memoryKey: 'history',
});

const chain = new ConversationChain({
  llm,
  memory,
});

// 会話1
await chain.call({ input: '私の名前はタロウです' });

// 会話2（前の会話を覚えている）
const response = await chain.call({ input: '私の名前は何でしたか？' });
console.log(response.response); // "タロウです"
```

### ConversationBufferWindowMemory

```typescript
import { BufferWindowMemory } from 'langchain/memory';

// 最新の5メッセージのみ保持
const windowMemory = new BufferWindowMemory({
  k: 5,
  returnMessages: true,
  memoryKey: 'history',
});

const chain = new ConversationChain({
  llm,
  memory: windowMemory,
});
```

### ConversationSummaryMemory

```typescript
import { ConversationSummaryMemory } from 'langchain/memory';

// 会話を要約して保存
const summaryMemory = new ConversationSummaryMemory({
  llm,
  returnMessages: true,
  memoryKey: 'history',
});

const chain = new ConversationChain({
  llm,
  memory: summaryMemory,
});
```

### カスタムメモリ（Redis）

```typescript
import { BufferMemory } from 'langchain/memory';
import { RedisChatMessageHistory } from '@langchain/community/stores/message/redis';
import Redis from 'ioredis';

const redis = new Redis();

async function createChatWithMemory(sessionId: string) {
  const messageHistory = new RedisChatMessageHistory({
    sessionId,
    client: redis,
  });

  const memory = new BufferMemory({
    chatHistory: messageHistory,
    returnMessages: true,
  });

  return new ConversationChain({
    llm,
    memory,
  });
}

// 使用例
const chat = await createChatWithMemory('user-123');
await chat.call({ input: 'こんにちは' });
```

---

## ドキュメント処理

### ドキュメントローダー

```typescript
import { TextLoader } from 'langchain/document_loaders/fs/text';
import { PDFLoader } from 'langchain/document_loaders/fs/pdf';
import { CSVLoader } from 'langchain/document_loaders/fs/csv';

// テキストファイル
const textLoader = new TextLoader('document.txt');
const docs = await textLoader.load();

// PDFファイル
const pdfLoader = new PDFLoader('document.pdf');
const pdfDocs = await pdfLoader.load();

// CSVファイル
const csvLoader = new CSVLoader('data.csv');
const csvDocs = await csvLoader.load();
```

### テキスト分割

```typescript
import { RecursiveCharacterTextSplitter } from 'langchain/text_splitter';

const textSplitter = new RecursiveCharacterTextSplitter({
  chunkSize: 1000,
  chunkOverlap: 200,
});

const splitDocs = await textSplitter.splitDocuments(docs);
```

### Vector Store（Pinecone）

```typescript
import { PineconeStore } from '@langchain/pinecone';
import { OpenAIEmbeddings } from '@langchain/openai';
import { Pinecone } from '@pinecone-database/pinecone';

const pinecone = new Pinecone();
const pineconeIndex = pinecone.Index('my-index');

const embeddings = new OpenAIEmbeddings();

// ドキュメントをベクトル化してPineconeに保存
const vectorStore = await PineconeStore.fromDocuments(
  splitDocs,
  embeddings,
  {
    pineconeIndex,
    namespace: 'my-docs',
  }
);

// 類似検索
const results = await vectorStore.similaritySearch('LangChainとは', 3);
console.log(results);
```

### RAG（Retrieval-Augmented Generation）

```typescript
import { RetrievalQAChain } from 'langchain/chains';

const retriever = vectorStore.asRetriever({
  k: 3, // 上位3件を取得
});

const chain = RetrievalQAChain.fromLLM(llm, retriever);

const response = await chain.call({
  query: 'LangChainのメモリ管理について教えて',
});

console.log(response.text);
```

### ConversationalRetrievalChain

```typescript
import { ConversationalRetrievalQAChain } from 'langchain/chains';

const conversationalChain = ConversationalRetrievalQAChain.fromLLM(
  llm,
  retriever,
  {
    memory: new BufferMemory({
      memoryKey: 'chat_history',
      returnMessages: true,
    }),
  }
);

// 会話形式でRAG
const response1 = await conversationalChain.call({
  question: 'LangChainとは何ですか？',
});

const response2 = await conversationalChain.call({
  question: 'それの利点は？', // 前の会話を踏まえた質問
});
```

---

## ベストプラクティス

### 1. ストリーミングレスポンス

```typescript
const stream = await llm.stream('AIについて説明してください');

for await (const chunk of stream) {
  process.stdout.write(chunk.content);
}
```

### 2. エラーハンドリング

```typescript
import { RunnableWithFallbacks } from '@langchain/core/runnables';

const primaryLLM = new ChatOpenAI({
  modelName: 'gpt-4-turbo-preview',
});

const fallbackLLM = new ChatOpenAI({
  modelName: 'gpt-3.5-turbo',
});

const llmWithFallback = primaryLLM.withFallbacks({
  fallbacks: [fallbackLLM],
});

const response = await llmWithFallback.invoke('Hello');
```

### 3. キャッシング

```typescript
import { ChatOpenAI } from '@langchain/openai';

const llm = new ChatOpenAI({
  modelName: 'gpt-4-turbo-preview',
  cache: true, // レスポンスをキャッシュ
});

// 同じ入力は2回目以降キャッシュから返す
const response1 = await llm.invoke('Hello');
const response2 = await llm.invoke('Hello'); // キャッシュヒット
```

### 4. コールバック

```typescript
import { BaseCallbackHandler } from '@langchain/core/callbacks/base';

class CustomHandler extends BaseCallbackHandler {
  name = 'custom_handler';

  async handleLLMStart(llm: any, prompts: string[]) {
    console.log('LLM開始:', prompts);
  }

  async handleLLMEnd(output: any) {
    console.log('LLM完了:', output);
  }

  async handleLLMError(error: Error) {
    console.error('LLMエラー:', error);
  }
}

const llm = new ChatOpenAI({
  callbacks: [new CustomHandler()],
});
```

### 5. バッチ処理

```typescript
const questions = [
  'TypeScriptとは？',
  'Reactとは？',
  'Next.jsとは？',
];

// 複数のクエリを並列実行
const responses = await llm.batch(questions);

responses.forEach((response, index) => {
  console.log(`Q${index + 1}:`, questions[index]);
  console.log(`A${index + 1}:`, response.content);
});
```

### 6. Express統合

```typescript
import express from 'express';

const app = express();
app.use(express.json());

app.post('/chat', async (req, res) => {
  const { message, sessionId } = req.body;

  try {
    const chain = await createChatWithMemory(sessionId);
    const response = await chain.call({ input: message });

    res.json({ response: response.response });
  } catch (error) {
    res.status(500).json({ error: 'Failed to process chat' });
  }
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

### 7. ストリーミングAPI

```typescript
app.post('/chat/stream', async (req, res) => {
  const { message } = req.body;

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const stream = await llm.stream(message);

  for await (const chunk of stream) {
    res.write(`data: ${JSON.stringify({ content: chunk.content })}\n\n`);
  }

  res.end();
});
```

---

## 参考リンク

- [LangChain Documentation](https://js.langchain.com/)
- [LangChain GitHub](https://github.com/langchain-ai/langchainjs)
- [LangChain Examples](https://js.langchain.com/docs/get_started/quickstart)
