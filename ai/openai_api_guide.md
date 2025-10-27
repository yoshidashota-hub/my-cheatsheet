# OpenAI API 完全ガイド

## 目次
1. [OpenAI APIとは](#openai-apiとは)
2. [セットアップ](#セットアップ)
3. [Chat Completions API](#chat-completions-api)
4. [ストリーミング](#ストリーミング)
5. [Function Calling](#function-calling)
6. [Embeddings](#embeddings)
7. [画像生成（DALL-E）](#画像生成dall-e)
8. [音声（Whisper & TTS）](#音声whisper--tts)
9. [ベストプラクティス](#ベストプラクティス)

---

## OpenAI APIとは

OpenAI APIは、GPT-4、GPT-3.5、DALL-E、Whisperなどの強力なAIモデルへアクセスできるAPIです。

### 主なモデル

- **GPT-4 Turbo**: 最も高性能なテキスト生成モデル
- **GPT-3.5 Turbo**: コストパフォーマンスに優れたモデル
- **DALL-E 3**: 高品質な画像生成
- **Whisper**: 音声認識
- **TTS**: テキスト読み上げ

---

## セットアップ

### インストール

```bash
npm install openai
```

### 初期化

```typescript
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export default openai;
```

### 環境変数

```bash
# .env
OPENAI_API_KEY=sk-...
OPENAI_ORG_ID=org-...  # オプション
```

---

## Chat Completions API

### 基本的な使い方

```typescript
import openai from './openai';

async function chat(prompt: string) {
  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'You are a helpful assistant.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: 0.7,
      max_tokens: 1000,
    });

    return completion.choices[0].message.content;
  } catch (error) {
    console.error('OpenAI API error:', error);
    throw error;
  }
}

// 使用例
const response = await chat('JavaScriptとTypeScriptの違いを教えて');
console.log(response);
```

### 会話履歴の管理

```typescript
interface Message {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

class ChatSession {
  private messages: Message[] = [];

  constructor(systemPrompt?: string) {
    if (systemPrompt) {
      this.messages.push({
        role: 'system',
        content: systemPrompt,
      });
    }
  }

  async sendMessage(userMessage: string): Promise<string> {
    // ユーザーメッセージを追加
    this.messages.push({
      role: 'user',
      content: userMessage,
    });

    // OpenAI APIに送信
    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: this.messages,
      temperature: 0.7,
    });

    const assistantMessage = completion.choices[0].message.content!;

    // アシスタントの返答を履歴に追加
    this.messages.push({
      role: 'assistant',
      content: assistantMessage,
    });

    return assistantMessage;
  }

  getMessages(): Message[] {
    return this.messages;
  }

  clearHistory(): void {
    const systemMessage = this.messages.find((m) => m.role === 'system');
    this.messages = systemMessage ? [systemMessage] : [];
  }
}

// 使用例
const session = new ChatSession('You are a programming tutor.');

const response1 = await session.sendMessage('Reactとは何ですか？');
console.log(response1);

const response2 = await session.sendMessage('useStateフックについて教えて');
console.log(response2);
```

### パラメータ詳細

```typescript
const completion = await openai.chat.completions.create({
  model: 'gpt-4-turbo-preview',
  messages: [...],

  // 創造性の制御（0-2、デフォルト1）
  temperature: 0.7,

  // より決定的な出力（0-1）
  top_p: 0.9,

  // 最大トークン数
  max_tokens: 1000,

  // 繰り返しの抑制（-2.0 - 2.0）
  presence_penalty: 0.6,
  frequency_penalty: 0.5,

  // 複数の候補を生成
  n: 1,

  // 停止シーケンス
  stop: ['\n\n', '###'],

  // ユーザー識別子（レート制限・監視用）
  user: 'user-123',
});
```

---

## ストリーミング

### ストリーミングレスポンス

```typescript
async function streamChat(prompt: string) {
  const stream = await openai.chat.completions.create({
    model: 'gpt-4-turbo-preview',
    messages: [{ role: 'user', content: prompt }],
    stream: true,
  });

  let fullResponse = '';

  for await (const chunk of stream) {
    const content = chunk.choices[0]?.delta?.content || '';
    fullResponse += content;
    process.stdout.write(content);
  }

  console.log('\n--- Complete ---');
  return fullResponse;
}

// 使用例
await streamChat('JavaScriptの非同期処理について詳しく説明して');
```

### Express.jsでのストリーミング

```typescript
import express from 'express';

const app = express();
app.use(express.json());

app.post('/api/chat/stream', async (req, res) => {
  const { message } = req.body;

  // SSE（Server-Sent Events）を設定
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  try {
    const stream = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [{ role: 'user', content: message }],
      stream: true,
    });

    for await (const chunk of stream) {
      const content = chunk.choices[0]?.delta?.content || '';
      if (content) {
        res.write(`data: ${JSON.stringify({ content })}\n\n`);
      }
    }

    res.write('data: [DONE]\n\n');
    res.end();
  } catch (error) {
    res.write(`data: ${JSON.stringify({ error: 'Stream error' })}\n\n`);
    res.end();
  }
});

app.listen(3000);
```

---

## Function Calling

### 関数定義

```typescript
const tools = [
  {
    type: 'function' as const,
    function: {
      name: 'get_weather',
      description: '指定された場所の天気を取得します',
      parameters: {
        type: 'object',
        properties: {
          location: {
            type: 'string',
            description: '都市名（例: Tokyo）',
          },
          unit: {
            type: 'string',
            enum: ['celsius', 'fahrenheit'],
            description: '温度の単位',
          },
        },
        required: ['location'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'search_database',
      description: 'データベースからユーザー情報を検索します',
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: '検索クエリ',
          },
          limit: {
            type: 'number',
            description: '取得件数',
            default: 10,
          },
        },
        required: ['query'],
      },
    },
  },
];

// 実際の関数実装
async function getWeather(location: string, unit: string = 'celsius') {
  // API呼び出しなど
  return {
    location,
    temperature: 22,
    unit,
    condition: 'sunny',
  };
}

async function searchDatabase(query: string, limit: number = 10) {
  // データベース検索
  return [
    { id: 1, name: 'John Doe', email: 'john@example.com' },
    { id: 2, name: 'Jane Smith', email: 'jane@example.com' },
  ];
}
```

### Function Calling実行

```typescript
async function chatWithFunctions(userMessage: string) {
  const messages: any[] = [
    { role: 'user', content: userMessage },
  ];

  // 最初のリクエスト
  let response = await openai.chat.completions.create({
    model: 'gpt-4-turbo-preview',
    messages,
    tools,
    tool_choice: 'auto',
  });

  let responseMessage = response.choices[0].message;
  messages.push(responseMessage);

  // 関数呼び出しが必要か確認
  const toolCalls = responseMessage.tool_calls;

  if (toolCalls) {
    // 各関数を実行
    for (const toolCall of toolCalls) {
      const functionName = toolCall.function.name;
      const functionArgs = JSON.parse(toolCall.function.arguments);

      console.log(`Calling function: ${functionName}`, functionArgs);

      let functionResponse;

      // 関数を実行
      if (functionName === 'get_weather') {
        functionResponse = await getWeather(
          functionArgs.location,
          functionArgs.unit
        );
      } else if (functionName === 'search_database') {
        functionResponse = await searchDatabase(
          functionArgs.query,
          functionArgs.limit
        );
      }

      // 関数の結果をメッセージに追加
      messages.push({
        role: 'tool',
        tool_call_id: toolCall.id,
        content: JSON.stringify(functionResponse),
      });
    }

    // 関数の結果を含めて再度リクエスト
    const secondResponse = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages,
    });

    return secondResponse.choices[0].message.content;
  }

  return responseMessage.content;
}

// 使用例
const result = await chatWithFunctions('東京の天気を教えて');
console.log(result);
```

---

## Embeddings

### テキストのベクトル化

```typescript
async function getEmbedding(text: string) {
  const response = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: text,
  });

  return response.data[0].embedding;
}

// 使用例
const embedding = await getEmbedding('機械学習とは何ですか？');
console.log('Embedding dimensions:', embedding.length); // 1536次元
```

### コサイン類似度計算

```typescript
function cosineSimilarity(vecA: number[], vecB: number[]): number {
  const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
  const magnitudeA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
  const magnitudeB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}

// 類似度計算
const text1 = 'AIについて学びたい';
const text2 = '人工知能を勉強する';
const text3 = '明日の天気は晴れです';

const [emb1, emb2, emb3] = await Promise.all([
  getEmbedding(text1),
  getEmbedding(text2),
  getEmbedding(text3),
]);

console.log('text1 vs text2:', cosineSimilarity(emb1, emb2)); // 高い類似度
console.log('text1 vs text3:', cosineSimilarity(emb1, emb3)); // 低い類似度
```

### セマンティック検索

```typescript
interface Document {
  id: string;
  text: string;
  embedding?: number[];
}

async function semanticSearch(query: string, documents: Document[]) {
  // クエリをベクトル化
  const queryEmbedding = await getEmbedding(query);

  // 各ドキュメントとの類似度を計算
  const results = documents.map((doc) => ({
    ...doc,
    similarity: cosineSimilarity(queryEmbedding, doc.embedding!),
  }));

  // 類似度でソート
  results.sort((a, b) => b.similarity - a.similarity);

  return results;
}

// 使用例
const documents: Document[] = [
  { id: '1', text: 'JavaScriptは動的型付け言語です' },
  { id: '2', text: 'TypeScriptは静的型付けを提供します' },
  { id: '3', text: 'Pythonはデータサイエンスに人気です' },
];

// 事前にembeddingを生成
for (const doc of documents) {
  doc.embedding = await getEmbedding(doc.text);
}

const results = await semanticSearch('型安全なプログラミング', documents);
console.log('Search results:', results.slice(0, 3));
```

---

## 画像生成（DALL-E）

### 画像生成

```typescript
async function generateImage(prompt: string) {
  const response = await openai.images.generate({
    model: 'dall-e-3',
    prompt,
    n: 1,
    size: '1024x1024',
    quality: 'standard', // or 'hd'
    style: 'vivid', // or 'natural'
  });

  return response.data[0].url;
}

// 使用例
const imageUrl = await generateImage('未来的な都市の風景、サイバーパンクスタイル');
console.log('Generated image:', imageUrl);
```

### 画像編集

```typescript
import fs from 'fs';

async function editImage(
  imagePath: string,
  maskPath: string,
  prompt: string
) {
  const response = await openai.images.edit({
    image: fs.createReadStream(imagePath),
    mask: fs.createReadStream(maskPath),
    prompt,
    n: 1,
    size: '1024x1024',
  });

  return response.data[0].url;
}
```

---

## 音声（Whisper & TTS）

### 音声認識（Whisper）

```typescript
import fs from 'fs';

async function transcribeAudio(audioPath: string) {
  const response = await openai.audio.transcriptions.create({
    file: fs.createReadStream(audioPath),
    model: 'whisper-1',
    language: 'ja', // オプション
    response_format: 'json', // or 'text', 'srt', 'vtt'
  });

  return response.text;
}

// 使用例
const transcript = await transcribeAudio('./audio.mp3');
console.log('Transcript:', transcript);
```

### テキスト読み上げ（TTS）

```typescript
import fs from 'fs';
import path from 'path';

async function textToSpeech(text: string, outputPath: string) {
  const mp3 = await openai.audio.speech.create({
    model: 'tts-1', // or 'tts-1-hd'
    voice: 'alloy', // alloy, echo, fable, onyx, nova, shimmer
    input: text,
    speed: 1.0, // 0.25 - 4.0
  });

  const buffer = Buffer.from(await mp3.arrayBuffer());
  await fs.promises.writeFile(outputPath, buffer);
}

// 使用例
await textToSpeech(
  'こんにちは。OpenAI APIのテキスト読み上げ機能です。',
  './output.mp3'
);
```

---

## ベストプラクティス

### 1. エラーハンドリング

```typescript
import { OpenAI } from 'openai';

async function safeChatCompletion(prompt: string) {
  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [{ role: 'user', content: prompt }],
    });

    return completion.choices[0].message.content;
  } catch (error: any) {
    if (error instanceof OpenAI.APIError) {
      console.error('OpenAI API Error:', error.status, error.message);

      // レート制限
      if (error.status === 429) {
        console.error('Rate limit exceeded. Retry after:', error.headers['retry-after']);
      }

      // 無効なリクエスト
      if (error.status === 400) {
        console.error('Invalid request:', error.message);
      }
    }

    throw error;
  }
}
```

### 2. リトライロジック

```typescript
async function chatWithRetry(
  prompt: string,
  maxRetries: number = 3
): Promise<string> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-4-turbo-preview',
        messages: [{ role: 'user', content: prompt }],
      });

      return completion.choices[0].message.content!;
    } catch (error: any) {
      if (i === maxRetries - 1) throw error;

      // レート制限の場合は待機
      if (error.status === 429) {
        const waitTime = Math.pow(2, i) * 1000;
        await new Promise((resolve) => setTimeout(resolve, waitTime));
      } else {
        throw error;
      }
    }
  }

  throw new Error('Max retries exceeded');
}
```

### 3. コスト管理

```typescript
// トークン数を計算（概算）
function estimateTokens(text: string): number {
  // 英語: 約4文字 = 1トークン
  // 日本語: 約1文字 = 1トークン
  return Math.ceil(text.length / 2);
}

// コスト計算
function calculateCost(inputTokens: number, outputTokens: number, model: string) {
  const pricing: Record<string, { input: number; output: number }> = {
    'gpt-4-turbo-preview': { input: 0.01, output: 0.03 }, // per 1K tokens
    'gpt-3.5-turbo': { input: 0.0005, output: 0.0015 },
  };

  const price = pricing[model] || pricing['gpt-3.5-turbo'];

  return {
    inputCost: (inputTokens / 1000) * price.input,
    outputCost: (outputTokens / 1000) * price.output,
    totalCost: (inputTokens / 1000) * price.input + (outputTokens / 1000) * price.output,
  };
}
```

### 4. プロンプトテンプレート

```typescript
class PromptTemplate {
  private template: string;

  constructor(template: string) {
    this.template = template;
  }

  format(variables: Record<string, string>): string {
    let result = this.template;

    for (const [key, value] of Object.entries(variables)) {
      result = result.replace(new RegExp(`\\{${key}\\}`, 'g'), value);
    }

    return result;
  }
}

// 使用例
const summaryTemplate = new PromptTemplate(`
以下のテキストを{length}文字以内で要約してください。
言語: {language}

テキスト:
{text}
`);

const prompt = summaryTemplate.format({
  length: '100',
  language: '日本語',
  text: '長い文章...',
});

const summary = await chat(prompt);
```

---

## 参考リンク

- [OpenAI API Documentation](https://platform.openai.com/docs)
- [OpenAI Pricing](https://openai.com/pricing)
- [OpenAI Cookbook](https://github.com/openai/openai-cookbook)
- [Best Practices](https://platform.openai.com/docs/guides/production-best-practices)
