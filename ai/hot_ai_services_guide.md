# 現在ホットなAIサービスガイド

2024-2025年に注目されている主要なAIサービスと開発者向けツールをまとめたガイドです。

## AI言語モデル / チャットボット

### Claude (Anthropic)

#### 概要

- Anthropic社が開発した高性能なLLM
- 最新モデル: Claude 3.5 Sonnet (2024), Claude 3 Opus
- 長文コンテキスト対応（最大200K トークン）
- 安全性と倫理面を重視した設計

#### 特徴

- **高精度な推論**: 複雑なタスクで高いパフォーマンス
- **長文理解**: 大量のドキュメントを一度に処理可能
- **コーディング**: プログラミング支援に優れる
- **日本語対応**: 高品質な日本語処理

#### 料金（2024年12月時点）

| モデル | 入力 (per 1M tokens) | 出力 (per 1M tokens) |
|--------|---------------------|---------------------|
| Claude 3.5 Sonnet | $3.00 | $15.00 |
| Claude 3 Opus | $15.00 | $75.00 |
| Claude 3 Haiku | $0.25 | $1.25 |

#### API使用例

```typescript
import Anthropic from '@anthropic-ai/sdk'

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
})

async function chat(message: string) {
  const response = await client.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 1024,
    messages: [
      {
        role: 'user',
        content: message,
      },
    ],
  })

  return response.content[0].text
}

// 使用例
const answer = await chat('TypeScriptでHello Worldを書いて')
console.log(answer)
```

#### ストリーミング

```typescript
async function chatStream(message: string) {
  const stream = await client.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 1024,
    messages: [{ role: 'user', content: message }],
    stream: true,
  })

  for await (const event of stream) {
    if (event.type === 'content_block_delta') {
      process.stdout.write(event.delta.text)
    }
  }
}
```

#### 関数呼び出し（Tool Use）

```typescript
async function chatWithTools(message: string) {
  const response = await client.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 1024,
    tools: [
      {
        name: 'get_weather',
        description: '指定された都市の天気を取得します',
        input_schema: {
          type: 'object',
          properties: {
            city: {
              type: 'string',
              description: '都市名（例: 東京、大阪）',
            },
          },
          required: ['city'],
        },
      },
    ],
    messages: [{ role: 'user', content: message }],
  })

  // ツール呼び出しを処理
  if (response.stop_reason === 'tool_use') {
    const toolUse = response.content.find((c) => c.type === 'tool_use')
    if (toolUse && toolUse.name === 'get_weather') {
      const { city } = toolUse.input
      // 実際の天気APIを呼び出し
      const weather = await fetchWeather(city)

      // 結果をClaudeに返す
      const finalResponse = await client.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 1024,
        messages: [
          { role: 'user', content: message },
          { role: 'assistant', content: response.content },
          {
            role: 'user',
            content: [
              {
                type: 'tool_result',
                tool_use_id: toolUse.id,
                content: JSON.stringify(weather),
              },
            ],
          },
        ],
        tools: [...],
      })

      return finalResponse.content[0].text
    }
  }
}
```

### ChatGPT / GPT-4 (OpenAI)

#### 概要

- OpenAI社が開発した最も有名なLLM
- 最新モデル: GPT-4 Turbo, GPT-4o
- 画像理解、音声入出力対応
- ChatGPT Plusで最新機能を利用可能

#### 特徴

- **汎用性**: あらゆるタスクに対応
- **プラグイン**: 様々な外部サービスと連携
- **DALL-E統合**: 画像生成機能
- **Code Interpreter**: データ分析・可視化

#### 料金

| モデル | 入力 (per 1M tokens) | 出力 (per 1M tokens) |
|--------|---------------------|---------------------|
| GPT-4o | $2.50 | $10.00 |
| GPT-4 Turbo | $10.00 | $30.00 |
| GPT-3.5 Turbo | $0.50 | $1.50 |

#### API使用例

```typescript
import OpenAI from 'openai'

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
})

async function chat(message: string) {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      {
        role: 'user',
        content: message,
      },
    ],
  })

  return response.choices[0].message.content
}
```

#### ストリーミング

```typescript
async function chatStream(message: string) {
  const stream = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: message }],
    stream: true,
  })

  for await (const chunk of stream) {
    process.stdout.write(chunk.choices[0]?.delta?.content || '')
  }
}
```

#### 関数呼び出し

```typescript
async function chatWithFunctions(message: string) {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: message }],
    tools: [
      {
        type: 'function',
        function: {
          name: 'get_current_weather',
          description: '指定された場所の現在の天気を取得',
          parameters: {
            type: 'object',
            properties: {
              location: {
                type: 'string',
                description: '都市名（例: Tokyo, Osaka）',
              },
              unit: {
                type: 'string',
                enum: ['celsius', 'fahrenheit'],
              },
            },
            required: ['location'],
          },
        },
      },
    ],
  })

  const toolCall = response.choices[0].message.tool_calls?.[0]
  if (toolCall && toolCall.function.name === 'get_current_weather') {
    const args = JSON.parse(toolCall.function.arguments)
    const weather = await fetchWeather(args.location)

    const finalResponse = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        { role: 'user', content: message },
        response.choices[0].message,
        {
          role: 'tool',
          tool_call_id: toolCall.id,
          content: JSON.stringify(weather),
        },
      ],
    })

    return finalResponse.choices[0].message.content
  }
}
```

### Gemini (Google)

#### 概要

- Google DeepMindが開発したマルチモーダルAI
- 最新モデル: Gemini 1.5 Pro, Gemini 2.0 Flash
- 長文コンテキスト（最大2M トークン）
- 動画・音声の直接理解

#### 特徴

- **マルチモーダル**: テキスト、画像、動画、音声を統合処理
- **超長文対応**: 200万トークンのコンテキスト
- **Google統合**: Google検索、YouTube等と連携
- **無料枠**: 充実した無料利用枠

#### 料金

| モデル | 入力 (per 1M tokens) | 出力 (per 1M tokens) |
|--------|---------------------|---------------------|
| Gemini 1.5 Pro | $1.25 | $5.00 |
| Gemini 1.5 Flash | $0.075 | $0.30 |
| Gemini 2.0 Flash | $0.075 | $0.30 |

#### API使用例

```typescript
import { GoogleGenerativeAI } from '@google/generative-ai'

const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY!)

async function chat(message: string) {
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' })
  const result = await model.generateContent(message)
  return result.response.text()
}
```

#### 画像を含むチャット

```typescript
import { readFileSync } from 'fs'

async function chatWithImage(message: string, imagePath: string) {
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' })

  const imageData = readFileSync(imagePath).toString('base64')
  const result = await model.generateContent([
    message,
    {
      inlineData: {
        data: imageData,
        mimeType: 'image/jpeg',
      },
    },
  ])

  return result.response.text()
}

// 使用例
const answer = await chatWithImage(
  'この画像に何が写っていますか？',
  './photo.jpg'
)
```

## AIコーディングツール

### Cursor

#### 概要

- VSCodeベースのAI統合エディタ
- Claude 3.5 Sonnet、GPT-4等のモデルを使用
- コード全体を理解してコンテキストに応じた提案

#### 特徴

- **Composer**: 複数ファイルを同時編集
- **Tab補完**: AIによるコード補完
- **Chat**: コードベース全体を理解したチャット
- **Cmd+K**: インライン編集

#### 料金

- **Free**: 月2,000回のコード補完、50回のSlow Premium
- **Pro**: $20/月 - 無制限のコード補完、500回のFast Premium
- **Business**: $40/月 - 企業向け、セキュリティ強化

#### 主な機能

```typescript
// Composerモード: 複数ファイルの同時編集
// 「ユーザー認証機能を追加して」とプロンプトすると、
// 関連する複数ファイルを自動編集

// Chatモード: プロジェクト全体を理解
// 「このプロジェクトでのエラーハンドリング方針は？」

// Cmd+K: インライン編集
// コードを選択して「この関数を最適化」
```

### GitHub Copilot

#### 概要

- GitHub公式のAIコーディングアシスタント
- OpenAI Codexベース
- あらゆるエディタで利用可能（VSCode、JetBrains等）

#### 特徴

- **リアルタイム補完**: コードを書きながら提案
- **Chat**: 自然言語でコード生成
- **PR要約**: プルリクエストの自動要約
- **脆弱性検出**: セキュリティリスクを指摘

#### 料金

- **Individual**: $10/月 または $100/年
- **Business**: $19/ユーザー/月
- **Enterprise**: $39/ユーザー/月

#### VSCodeでの使用例

```typescript
// コメントを書くとコードを生成
// 関数を宣言すると実装を提案

// 例1: コメントからコード生成
// Calculate fibonacci number recursively
function fibonacci(n: number): number {
  // Copilotが自動的に実装を提案
  if (n <= 1) return n
  return fibonacci(n - 1) + fibonacci(n - 2)
}

// 例2: テスト生成
// Copilot Chatで「このfibonacci関数のテストを書いて」
```

### Windsurf (Codeium)

#### 概要

- Codeium社が開発した次世代AIエディタ
- 「Cascade」という協調モードが特徴
- 完全無料で利用可能

#### 特徴

- **Cascade**: AIとの共同開発モード
- **Supercomplete**: 高度なコード補完
- **無料**: 全機能を無料で提供
- **プライバシー**: ローカル処理も可能

#### 料金

- **Free**: 全機能無料
- **Pro**: より高速なレスポンス（価格未発表）

### v0.dev (Vercel)

#### 概要

- Vercelが提供するAI UIジェネレーター
- プロンプトからReactコンポーネントを生成
- shadcn/uiベースのコードを出力

#### 特徴

- **即座にプレビュー**: リアルタイムでUIを確認
- **shadcn/ui**: 高品質なコンポーネントライブラリ
- **カスタマイズ**: 生成後も編集可能
- **エクスポート**: コードをダウンロード

#### 料金

- **Free**: 月30クレジット
- **Premium**: $20/月 - 月500クレジット

#### 使用例

```text
プロンプト:
「ダークモード対応のログインフォームを作成。
メールアドレス、パスワード、Remember meチェックボックス、
ソーシャルログインボタン（Google、GitHub）を含める」

→ v0が即座にReact + TypeScriptのコードを生成
→ プレビューで確認しながら微調整
→ 完成したらコードをコピーしてプロジェクトに追加
```

#### 生成されるコード例

```typescript
// v0.devが生成するコード（shadcn/uiベース）
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Checkbox } from '@/components/ui/checkbox'

export function LoginForm() {
  return (
    <div className="w-full max-w-md space-y-8 rounded-lg border bg-card p-8">
      <div className="space-y-2 text-center">
        <h1 className="text-3xl font-bold">ログイン</h1>
        <p className="text-muted-foreground">
          アカウントにログインしてください
        </p>
      </div>
      <form className="space-y-6">
        <div className="space-y-2">
          <Label htmlFor="email">メールアドレス</Label>
          <Input id="email" type="email" placeholder="you@example.com" />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">パスワード</Label>
          <Input id="password" type="password" />
        </div>
        <div className="flex items-center space-x-2">
          <Checkbox id="remember" />
          <Label htmlFor="remember">ログイン状態を保持</Label>
        </div>
        <Button className="w-full">ログイン</Button>
        <div className="space-y-2">
          <Button variant="outline" className="w-full">
            Googleでログイン
          </Button>
          <Button variant="outline" className="w-full">
            GitHubでログイン
          </Button>
        </div>
      </form>
    </div>
  )
}
```

### Bolt.new (StackBlitz)

#### 概要

- StackBlitzが提供するAIフルスタック開発環境
- プロンプトから完全なWebアプリを生成
- ブラウザ内で即座に動作確認

#### 特徴

- **フルスタック**: フロントエンド + バックエンドを生成
- **即座に実行**: コード生成と同時にアプリが起動
- **デプロイ**: そのままNetlify等にデプロイ可能
- **イテレーション**: チャットで継続的に改善

#### 料金

- **Free**: 基本機能
- **Pro**: $20/月 - 高速生成、優先サポート

#### 使用例

```text
プロンプト:
「ToDoアプリを作成。
- React + TypeScript + Tailwind CSS
- ローカルストレージでデータ永続化
- 追加、完了、削除機能
- フィルター機能（全て、未完了、完了済み）」

→ Bolt.newが完全なアプリを生成
→ ブラウザ内で即座に動作確認
→ 「ダークモード追加して」等、追加機能をチャットで依頼
→ 完成したらコードをダウンロードまたはデプロイ
```

## AI検索

### Perplexity

#### 概要

- AIを活用した次世代検索エンジン
- リアルタイムWeb検索 + LLMによる回答生成
- 情報源を明示（引用付き）

#### 特徴

- **正確性**: 最新情報を参照して回答
- **引用**: 全ての情報に出典を表示
- **フォローアップ**: 会話形式で深掘り
- **Pro検索**: GPT-4、Claude使用可能

#### 料金

- **Free**: 基本検索、標準AI
- **Pro**: $20/月 - GPT-4、Claude、300回/日のPro検索

#### API使用例

```typescript
// Perplexity API
const response = await fetch('https://api.perplexity.ai/chat/completions', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${process.env.PERPLEXITY_API_KEY}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'sonar-pro',
    messages: [
      {
        role: 'user',
        content: '2024年のAI業界の主要トレンドは？',
      },
    ],
  }),
})

const data = await response.json()
console.log(data.choices[0].message.content)
```

### ChatGPT Search

#### 概要

- ChatGPTに統合されたWeb検索機能
- リアルタイムの情報を取得して回答
- ChatGPT Plusユーザーが利用可能

#### 特徴

- **シームレス**: チャット中に自動でWeb検索
- **最新情報**: ニュース、株価、天気等に対応
- **引用**: 情報源へのリンクを表示

#### 料金

- ChatGPT Plus: $20/月（検索機能含む）

## 画像生成AI

### Midjourney

#### 概要

- 最も人気の高い画像生成AI
- Discordベースのインターフェース
- フォトリアルからアート作品まで幅広く対応

#### 特徴

- **高品質**: 非常にリアルな画像生成
- **スタイル**: 多様なアートスタイル
- **バージョン管理**: 複数バージョンで微調整
- **コミュニティ**: 作品ギャラリー

#### 料金

- **Basic**: $10/月 - 3.3時間/月の生成時間
- **Standard**: $30/月 - 15時間/月
- **Pro**: $60/月 - 30時間/月、ステルスモード

#### 使用例

```text
Discordでのプロンプト例:

/imagine prompt: a serene Japanese garden with cherry blossoms,
soft morning light, photorealistic, 8k, ultra detailed

/imagine prompt: cyberpunk city at night, neon lights,
rain-soaked streets, cinematic lighting, concept art style

パラメータ:
--ar 16:9  (アスペクト比)
--v 6     (バージョン6使用)
--stylize 1000 (スタイル強度)
```

### DALL-E 3 (OpenAI)

#### 概要

- OpenAIの画像生成AI
- ChatGPT Plusに統合
- プロンプト理解力に優れる

#### 特徴

- **自然言語理解**: 詳細なプロンプトを正確に理解
- **ChatGPT統合**: チャット中に画像生成
- **安全性**: 有害コンテンツのフィルタリング

#### 料金

- **ChatGPT Plus**: $20/月（DALL-E 3含む）
- **API**: $0.040/画像（1024x1024）

#### API使用例

```typescript
import OpenAI from 'openai'

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
})

async function generateImage(prompt: string) {
  const response = await openai.images.generate({
    model: 'dall-e-3',
    prompt: prompt,
    n: 1,
    size: '1024x1024',
    quality: 'hd',
    style: 'vivid', // または 'natural'
  })

  return response.data[0].url
}

// 使用例
const imageUrl = await generateImage(
  '桜が満開の日本庭園、朝の柔らかい光、フォトリアリスティック'
)
console.log('生成された画像:', imageUrl)
```

### Stable Diffusion

#### 概要

- オープンソースの画像生成AI
- ローカル実行可能
- 多数のカスタムモデル（LoRA）

#### 特徴

- **オープンソース**: 無料で利用可能
- **カスタマイズ**: モデルのファインチューニング
- **コミュニティ**: 豊富なモデル・LoRA
- **ControlNet**: 画像の構図を細かく制御

#### 料金

- **ローカル**: 無料（要GPU）
- **Stability AI API**: 従量課金
- **Dream Studio**: $10で1,000クレジット

#### APIを使用した例

```typescript
import fs from 'fs'

async function generateImageSD(prompt: string) {
  const response = await fetch(
    'https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.STABILITY_API_KEY}`,
      },
      body: JSON.stringify({
        text_prompts: [
          {
            text: prompt,
            weight: 1,
          },
        ],
        cfg_scale: 7,
        height: 1024,
        width: 1024,
        steps: 30,
        samples: 1,
      }),
    }
  )

  const data = await response.json()
  const image = data.artifacts[0].base64

  // 画像を保存
  fs.writeFileSync('output.png', Buffer.from(image, 'base64'))

  return 'output.png'
}
```

### Flux (Black Forest Labs)

#### 概要

- Stable Diffusionの開発チームが作成
- 最新の画像生成技術
- 高速かつ高品質

#### 特徴

- **Pro/Dev/Schnell**: 用途別の3モデル
- **高速生成**: Schnellは数秒で生成
- **高品質**: Proは最高品質
- **オープンウェイト**: Dev/Schnellはオープン

#### 料金

- **Flux Schnell**: 無料（オープンウェイト）
- **Flux Dev**: 無料（非商用）
- **Flux Pro**: API経由（従量課金）

## その他の注目AIサービス

### Notion AI

#### 概要

- Notion統合のAIアシスタント
- ドキュメント作成・編集支援
- データベースの自動生成

#### 特徴

- **執筆支援**: 要約、翻訳、改善提案
- **アイデア生成**: ブレインストーミング支援
- **自動化**: テンプレート作成、データ整理
- **Q&A**: ワークスペース全体を検索

#### 料金

- **AI Add-on**: $10/ユーザー/月（Notionプランに追加）

#### 使用例

```text
Notionページ内で:
- 「この議事録を要約して」
- 「プロジェクト計画書のアウトラインを作成」
- 「この英文を日本語に翻訳」
- 「チーム全体でこのトピックについて何が話し合われた？」
```

### Suno

#### 概要

- AIによる音楽生成サービス
- プロンプトから楽曲を作成
- ボーカル入りの完全な楽曲

#### 特徴

- **全自動**: 作詞、作曲、ボーカルを自動生成
- **多様なジャンル**: あらゆる音楽ジャンルに対応
- **高音質**: プロレベルの音質
- **商用利用**: Proプランで可能

#### 料金

- **Free**: 50クレジット/月
- **Pro**: $10/月 - 2,500クレジット/月
- **Premier**: $30/月 - 10,000クレジット/月

#### 使用例

```text
プロンプト例:
「アップビートなポップソング、夏の思い出について、
女性ボーカル、キャッチーなコーラス」

「チルアウトLofi Hip Hop、雨の日の雰囲気、
ピアノとドラムループ、インストゥルメンタル」

→ 約30秒で2分間の楽曲を生成
→ 歌詞も自動生成（または自分で指定可能）
```

### ElevenLabs

#### 概要

- 最高品質のAI音声合成サービス
- リアルな音声クローン機能
- 多言語対応

#### 特徴

- **自然な音声**: 人間と区別困難なレベル
- **音声クローン**: わずか1分の音声から複製
- **多言語**: 29言語に対応
- **感情表現**: トーン・感情を細かく制御

#### 料金

- **Free**: 10,000文字/月
- **Starter**: $5/月 - 30,000文字/月
- **Creator**: $22/月 - 100,000文字/月
- **Pro**: $99/月 - 500,000文字/月

#### API使用例

```typescript
import { ElevenLabsClient } from 'elevenlabs'

const client = new ElevenLabsClient({
  apiKey: process.env.ELEVENLABS_API_KEY,
})

async function textToSpeech(text: string) {
  const audio = await client.generate({
    voice: 'Rachel', // 音声ID
    text: text,
    model_id: 'eleven_multilingual_v2',
  })

  // 音声を保存
  const fs = require('fs')
  const buffer = Buffer.from(await audio.arrayBuffer())
  fs.writeFileSync('output.mp3', buffer)
}

// 使用例
await textToSpeech(
  'こんにちは。ElevenLabsのAI音声合成サービスです。'
)
```

#### 音声クローン

```typescript
async function cloneVoice(name: string, audioFiles: string[]) {
  const voice = await client.voices.add({
    name: name,
    files: audioFiles.map((file) => fs.readFileSync(file)),
    description: 'カスタム音声',
  })

  return voice.voice_id
}

// 使用例
const voiceId = await cloneVoice('my-voice', ['sample1.mp3', 'sample2.mp3'])
```

### Runway

#### 概要

- AI動画生成・編集プラットフォーム
- テキスト・画像から動画を生成
- プロ向けの動画編集ツール

#### 特徴

- **Gen-2**: テキストから動画生成
- **動画編集**: AIによる自動編集
- **グリーンバック**: 背景除去
- **モーショントラッキング**: 自動追跡

#### 料金

- **Free**: 125クレジット（初回）
- **Standard**: $15/月 - 625クレジット/月
- **Pro**: $35/月 - 2,250クレジット/月
- **Unlimited**: $95/月 - 無制限

#### 使用例

```text
Gen-2での動画生成:

プロンプト:
「夕焼けのビーチ、波が穏やかに打ち寄せる、
シネマティックなスローモーション、
4K品質」

画像から動画:
- 静止画をアップロード
- モーションプロンプトを入力
- 4秒の動画を生成
```

## 実装例: 複数AIサービスの統合

### Next.js アプリケーションでの統合

```typescript
// app/api/ai/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import { GoogleGenerativeAI } from '@google/generative-ai'

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
const gemini = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY!)

export async function POST(request: NextRequest) {
  const { provider, prompt, task } = await request.json()

  try {
    switch (provider) {
      case 'claude':
        return await chatWithClaude(prompt)
      case 'gpt':
        return await chatWithGPT(prompt)
      case 'gemini':
        return await chatWithGemini(prompt)
      case 'dalle':
        return await generateImage(prompt)
      default:
        return NextResponse.json({ error: 'Unknown provider' }, { status: 400 })
    }
  } catch (error) {
    console.error('AI Error:', error)
    return NextResponse.json({ error: 'AI request failed' }, { status: 500 })
  }
}

async function chatWithClaude(prompt: string) {
  const response = await anthropic.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  })

  return NextResponse.json({
    provider: 'claude',
    content: response.content[0].text,
  })
}

async function chatWithGPT(prompt: string) {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
  })

  return NextResponse.json({
    provider: 'gpt',
    content: response.choices[0].message.content,
  })
}

async function chatWithGemini(prompt: string) {
  const model = gemini.getGenerativeModel({ model: 'gemini-1.5-pro' })
  const result = await model.generateContent(prompt)

  return NextResponse.json({
    provider: 'gemini',
    content: result.response.text(),
  })
}

async function generateImage(prompt: string) {
  const response = await openai.images.generate({
    model: 'dall-e-3',
    prompt: prompt,
    size: '1024x1024',
  })

  return NextResponse.json({
    provider: 'dalle',
    imageUrl: response.data[0].url,
  })
}
```

### フロントエンド

```typescript
'use client'

import { useState } from 'react'

export default function AIChat() {
  const [prompt, setPrompt] = useState('')
  const [response, setResponse] = useState('')
  const [provider, setProvider] = useState<'claude' | 'gpt' | 'gemini'>('claude')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      const res = await fetch('/api/ai', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider, prompt }),
      })

      const data = await res.json()
      setResponse(data.content || data.imageUrl)
    } catch (error) {
      console.error('Error:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto p-4">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block mb-2">AIプロバイダー</label>
          <select
            value={provider}
            onChange={(e) => setProvider(e.target.value as any)}
            className="w-full p-2 border rounded"
          >
            <option value="claude">Claude (Anthropic)</option>
            <option value="gpt">GPT-4 (OpenAI)</option>
            <option value="gemini">Gemini (Google)</option>
          </select>
        </div>

        <div>
          <label className="block mb-2">プロンプト</label>
          <textarea
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            className="w-full p-2 border rounded h-32"
            placeholder="質問や指示を入力..."
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-500 text-white p-2 rounded hover:bg-blue-600 disabled:bg-gray-400"
        >
          {loading ? '処理中...' : '送信'}
        </button>
      </form>

      {response && (
        <div className="mt-8 p-4 bg-gray-50 rounded">
          <h3 className="font-bold mb-2">AI応答:</h3>
          <p className="whitespace-pre-wrap">{response}</p>
        </div>
      )}
    </div>
  )
}
```

## サービス選択ガイド

### ユースケース別推奨

#### コーディング支援
- **1位**: Cursor - 最も統合的
- **2位**: GitHub Copilot - 安定性
- **3位**: Windsurf - 無料

#### UI開発
- **1位**: v0.dev - shadcn/ui統合
- **2位**: Bolt.new - フルスタック対応

#### チャットボット開発
- **1位**: Claude - 高品質な応答
- **2位**: GPT-4 - 汎用性
- **3位**: Gemini - コスパ

#### 画像生成
- **1位**: Midjourney - 品質最高
- **2位**: DALL-E 3 - 使いやすさ
- **3位**: Flux - 速度

#### コンテンツ作成
- **1位**: Claude - 長文生成
- **2位**: GPT-4 - 多様性
- **3位**: Notion AI - Notion統合

## 参考リンク

### AI言語モデル
- [Claude API Documentation](https://docs.anthropic.com/)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Google AI Studio](https://ai.google.dev/)

### AIコーディングツール
- [Cursor](https://cursor.sh/)
- [GitHub Copilot](https://github.com/features/copilot)
- [Windsurf](https://codeium.com/windsurf)
- [v0.dev](https://v0.dev/)
- [Bolt.new](https://bolt.new/)

### 画像・動画・音声
- [Midjourney](https://www.midjourney.com/)
- [Stability AI](https://stability.ai/)
- [ElevenLabs](https://elevenlabs.io/)
- [Runway](https://runwayml.com/)
- [Suno](https://suno.ai/)

### その他
- [Perplexity](https://www.perplexity.ai/)
- [Notion AI](https://www.notion.so/product/ai)
