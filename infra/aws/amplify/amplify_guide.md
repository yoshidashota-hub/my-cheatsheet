# AWS Amplify 完全ガイド

## 目次
1. [AWS Amplifyとは](#aws-amplifyとは)
2. [Amplify Hostingとは](#amplify-hostingとは)
3. [Amplify Backendとは](#amplify-backendとは)
4. [セットアップ](#セットアップ)
5. [Amplify Gen 2の使い方](#amplify-gen-2の使い方)
6. [認証（Auth）](#認証auth)
7. [データ（Data）](#データdata)
8. [ストレージ（Storage）](#ストレージstorage)
9. [API](#api)
10. [デプロイ](#デプロイ)
11. [ベストプラクティス](#ベストプラクティス)

---

## AWS Amplifyとは

AWS Amplifyは、フルスタックアプリケーション（Web・モバイル）を迅速に構築・デプロイできるサービスです。

### 主な機能

- **Amplify Hosting**: 静的サイト・SSRアプリのホスティング
- **Amplify Backend**: バックエンドリソースの構築（Auth、API、Database、Storage等）
- **Amplify Studio**: ノーコード・ローコードでUI作成
- **Amplify Libraries**: フロントエンドからバックエンドにアクセスするSDK

### Amplify Gen 2 の特徴

2024年リリースのGen 2では、TypeScriptベースのコード定義が採用されました。

```typescript
// 従来（Gen 1）: JSONベースの設定
// amplify/backend/api/schema.graphql

// Gen 2: TypeScriptベースのコード定義
// amplify/data/resource.ts
import { type ClientSchema, a, defineData } from '@aws-amplify/backend';

const schema = a.schema({
  Todo: a.model({
    content: a.string(),
    isDone: a.boolean(),
  })
  .authorization(allow => [allow.owner()]),
});

export type Schema = ClientSchema<typeof schema>;
export const data = defineData({ schema });
```

---

## Amplify Hostingとは

### サポートするフレームワーク

- **React** (Create React App, Vite)
- **Next.js** (SSR, SSG, App Router)
- **Vue.js** (Nuxt.js)
- **Angular**
- **Svelte** (SvelteKit)
- **Astro**
- その他静的サイトジェネレーター

### デプロイ方法

1. **Git連携**: GitHub、GitLab、Bitbucketと自動連携
2. **手動デプロイ**: ローカルからビルド成果物をアップロード
3. **CLI**: Amplify CLIを使用したデプロイ

---

## Amplify Backendとは

### バックエンドリソース

```
┌─────────────────────────────────────────────┐
│        Amplify Backend (Gen 2)              │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │   Auth   │  │   Data   │  │ Storage  │ │
│  │ Cognito  │  │ DynamoDB │  │    S3    │ │
│  └──────────┘  └──────────┘  └──────────┘ │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │   API    │  │Functions │  │Analytics │ │
│  │AppSync/  │  │ Lambda   │  │ Pinpoint │ │
│  │API GW    │  └──────────┘  └──────────┘ │
│  └──────────┘                              │
│                                             │
└─────────────────────────────────────────────┘
```

---

## セットアップ

### 1. Amplify CLIのインストール

```bash
# npm
npm install -g @aws-amplify/cli

# yarn
yarn global add @aws-amplify/cli

# pnpm
pnpm add -g @aws-amplify/cli

# CLIの設定
amplify configure
```

### 2. 新規プロジェクトの作成

#### Next.js + Amplify Gen 2

```bash
# Next.jsプロジェクトの作成
npx create-next-app@latest my-amplify-app
cd my-amplify-app

# Amplify依存パッケージのインストール
npm install aws-amplify @aws-amplify/backend @aws-amplify/backend-cli

# Amplifyの初期化
npx ampx sandbox
```

#### React + Vite + Amplify Gen 2

```bash
# Viteプロジェクトの作成
npm create vite@latest my-amplify-app -- --template react-ts
cd my-amplify-app

# Amplify依存パッケージのインストール
npm install aws-amplify @aws-amplify/backend @aws-amplify/backend-cli

# Amplifyの初期化
npx ampx sandbox
```

### 3. プロジェクト構造

```
my-amplify-app/
├── amplify/
│   ├── auth/
│   │   └── resource.ts       # 認証設定
│   ├── data/
│   │   └── resource.ts       # データモデル定義
│   ├── storage/
│   │   └── resource.ts       # ストレージ設定
│   └── backend.ts            # バックエンドリソース統合
├── src/
│   ├── components/
│   ├── pages/
│   └── main.tsx
├── amplify_outputs.json      # 自動生成される設定ファイル
└── package.json
```

---

## Amplify Gen 2の使い方

### バックエンドリソースの定義

#### amplify/backend.ts

```typescript
import { defineBackend } from '@aws-amplify/backend';
import { auth } from './auth/resource';
import { data } from './data/resource';
import { storage } from './storage/resource';

const backend = defineBackend({
  auth,
  data,
  storage,
});
```

---

## 認証（Auth）

### 基本設定

#### amplify/auth/resource.ts

```typescript
import { defineAuth } from '@aws-amplify/backend';

export const auth = defineAuth({
  loginWith: {
    email: true,
    // phone: true,
    // username: true,
  },
  userAttributes: {
    email: {
      required: true,
      mutable: false,
    },
    name: {
      required: true,
      mutable: true,
    },
    profilePicture: {
      required: false,
      mutable: true,
    },
  },
  multifactor: {
    mode: 'OPTIONAL',
    sms: true,
    totp: true,
  },
  accountRecovery: 'EMAIL_ONLY',
});
```

### ソーシャルログイン設定

```typescript
import { defineAuth } from '@aws-amplify/backend';

export const auth = defineAuth({
  loginWith: {
    email: true,
    externalProviders: {
      google: {
        clientId: process.env.GOOGLE_CLIENT_ID!,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
        scopes: ['email', 'profile', 'openid'],
      },
      facebook: {
        clientId: process.env.FACEBOOK_APP_ID!,
        clientSecret: process.env.FACEBOOK_APP_SECRET!,
        scopes: ['email', 'public_profile'],
      },
      loginWithAmazon: {
        clientId: process.env.AMAZON_CLIENT_ID!,
        clientSecret: process.env.AMAZON_CLIENT_SECRET!,
        scopes: ['profile'],
      },
      callbackUrls: [
        'http://localhost:3000/callback',
        'https://example.com/callback',
      ],
      logoutUrls: [
        'http://localhost:3000',
        'https://example.com',
      ],
    },
  },
});
```

### フロントエンド実装

```typescript
// src/main.tsx または src/App.tsx
import { Amplify } from 'aws-amplify';
import { signUp, signIn, signOut, getCurrentUser } from 'aws-amplify/auth';
import outputs from '../amplify_outputs.json';

Amplify.configure(outputs);

// サインアップ
async function handleSignUp(email: string, password: string, name: string) {
  try {
    const { isSignUpComplete, userId, nextStep } = await signUp({
      username: email,
      password,
      options: {
        userAttributes: {
          email,
          name,
        },
      },
    });

    console.log('Sign up result:', { isSignUpComplete, userId, nextStep });

    if (nextStep.signUpStep === 'CONFIRM_SIGN_UP') {
      // 確認コード入力画面へ遷移
      console.log('Please confirm your email');
    }
  } catch (error) {
    console.error('Sign up error:', error);
  }
}

// 確認コードの送信
import { confirmSignUp } from 'aws-amplify/auth';

async function handleConfirmSignUp(username: string, code: string) {
  try {
    const { isSignUpComplete, nextStep } = await confirmSignUp({
      username,
      confirmationCode: code,
    });

    console.log('Confirm sign up result:', { isSignUpComplete, nextStep });
  } catch (error) {
    console.error('Confirm sign up error:', error);
  }
}

// サインイン
async function handleSignIn(email: string, password: string) {
  try {
    const { isSignedIn, nextStep } = await signIn({
      username: email,
      password,
    });

    console.log('Sign in result:', { isSignedIn, nextStep });
  } catch (error) {
    console.error('Sign in error:', error);
  }
}

// ソーシャルログイン
import { signInWithRedirect } from 'aws-amplify/auth';

async function handleSocialSignIn(provider: 'Google' | 'Facebook' | 'Amazon') {
  try {
    await signInWithRedirect({ provider });
  } catch (error) {
    console.error('Social sign in error:', error);
  }
}

// サインアウト
async function handleSignOut() {
  try {
    await signOut();
  } catch (error) {
    console.error('Sign out error:', error);
  }
}

// 現在のユーザー取得
async function getCurrentAuthUser() {
  try {
    const user = await getCurrentUser();
    console.log('Current user:', user);
    return user;
  } catch (error) {
    console.error('Get current user error:', error);
    return null;
  }
}
```

### React UIコンポーネント（Authenticator）

```typescript
import { Authenticator } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';

export default function App() {
  return (
    <Authenticator>
      {({ signOut, user }) => (
        <main>
          <h1>Hello {user?.username}</h1>
          <button onClick={signOut}>Sign out</button>
        </main>
      )}
    </Authenticator>
  );
}
```

カスタマイズ版:

```typescript
import { Authenticator } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';

const formFields = {
  signUp: {
    email: {
      order: 1,
      placeholder: 'Enter your email',
      isRequired: true,
    },
    name: {
      order: 2,
      placeholder: 'Enter your name',
      isRequired: true,
    },
    password: {
      order: 3,
      placeholder: 'Enter your password',
      isRequired: true,
    },
    confirm_password: {
      order: 4,
      placeholder: 'Confirm your password',
      isRequired: true,
    },
  },
};

const components = {
  Header() {
    return (
      <div style={{ textAlign: 'center', padding: '20px' }}>
        <h1>My App</h1>
      </div>
    );
  },
  SignUp: {
    Footer() {
      return (
        <div style={{ textAlign: 'center' }}>
          <p>By signing up, you agree to our Terms of Service</p>
        </div>
      );
    },
  },
};

export default function App() {
  return (
    <Authenticator formFields={formFields} components={components}>
      {({ signOut, user }) => (
        <main>
          <h1>Hello {user?.username}</h1>
          <button onClick={signOut}>Sign out</button>
        </main>
      )}
    </Authenticator>
  );
}
```

---

## データ（Data）

### データモデルの定義

#### amplify/data/resource.ts

```typescript
import { type ClientSchema, a, defineData } from '@aws-amplify/backend';

const schema = a.schema({
  Todo: a
    .model({
      content: a.string(),
      isDone: a.boolean(),
      priority: a.enum(['low', 'medium', 'high']),
      dueDate: a.date(),
      createdAt: a.datetime(),
    })
    .authorization((allow) => [allow.owner()]),

  Post: a
    .model({
      title: a.string(),
      content: a.string(),
      author: a.string(),
      published: a.boolean(),
      tags: a.string().array(),
      comments: a.hasMany('Comment', 'postId'),
    })
    .authorization((allow) => [
      allow.authenticated().to(['read']),
      allow.owner().to(['create', 'update', 'delete']),
    ]),

  Comment: a
    .model({
      postId: a.id(),
      post: a.belongsTo('Post', 'postId'),
      content: a.string(),
      author: a.string(),
    })
    .authorization((allow) => [
      allow.authenticated().to(['read', 'create']),
      allow.owner().to(['update', 'delete']),
    ]),

  Category: a
    .model({
      name: a.string(),
      posts: a.manyToMany('Post', 'PostCategory'),
    })
    .authorization((allow) => [allow.publicApiKey()]),

  PostCategory: a
    .model({
      postId: a.id(),
      categoryId: a.id(),
      post: a.belongsTo('Post', 'postId'),
      category: a.belongsTo('Category', 'categoryId'),
    })
    .authorization((allow) => [allow.publicApiKey()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: 'userPool',
    apiKeyAuthorizationMode: {
      expiresInDays: 30,
    },
  },
});
```

### リレーションシップ

```typescript
const schema = a.schema({
  // 1対多（hasMany / belongsTo）
  Blog: a
    .model({
      name: a.string(),
      posts: a.hasMany('Post', 'blogId'),
    })
    .authorization((allow) => [allow.publicApiKey()]),

  Post: a
    .model({
      blogId: a.id(),
      blog: a.belongsTo('Blog', 'blogId'),
      title: a.string(),
      content: a.string(),
    })
    .authorization((allow) => [allow.publicApiKey()]),

  // 多対多（manyToMany）
  Student: a
    .model({
      name: a.string(),
      courses: a.manyToMany('Course', 'StudentCourse'),
    })
    .authorization((allow) => [allow.publicApiKey()]),

  Course: a
    .model({
      name: a.string(),
      students: a.manyToMany('Student', 'StudentCourse'),
    })
    .authorization((allow) => [allow.publicApiKey()]),

  StudentCourse: a
    .model({
      studentId: a.id(),
      courseId: a.id(),
      student: a.belongsTo('Student', 'studentId'),
      course: a.belongsTo('Course', 'courseId'),
      enrolledDate: a.date(),
    })
    .authorization((allow) => [allow.publicApiKey()]),
});
```

### フロントエンド実装

```typescript
// src/client.ts
import { generateClient } from 'aws-amplify/data';
import type { Schema } from '../amplify/data/resource';

export const client = generateClient<Schema>();

// CRUD操作
import { client } from './client';

// Create
async function createTodo() {
  try {
    const { data: newTodo, errors } = await client.models.Todo.create({
      content: 'Buy groceries',
      isDone: false,
      priority: 'high',
      dueDate: '2024-12-31',
      createdAt: new Date().toISOString(),
    });

    if (errors) {
      console.error('Create errors:', errors);
      return;
    }

    console.log('Created todo:', newTodo);
  } catch (error) {
    console.error('Create todo error:', error);
  }
}

// Read（全件取得）
async function listTodos() {
  try {
    const { data: todos, errors } = await client.models.Todo.list();

    if (errors) {
      console.error('List errors:', errors);
      return;
    }

    console.log('Todos:', todos);
    return todos;
  } catch (error) {
    console.error('List todos error:', error);
  }
}

// Read（フィルタリング）
async function listHighPriorityTodos() {
  try {
    const { data: todos, errors } = await client.models.Todo.list({
      filter: {
        priority: { eq: 'high' },
        isDone: { eq: false },
      },
    });

    if (errors) {
      console.error('List errors:', errors);
      return;
    }

    console.log('High priority todos:', todos);
    return todos;
  } catch (error) {
    console.error('List todos error:', error);
  }
}

// Read（単一取得）
async function getTodo(id: string) {
  try {
    const { data: todo, errors } = await client.models.Todo.get({ id });

    if (errors) {
      console.error('Get errors:', errors);
      return;
    }

    console.log('Todo:', todo);
    return todo;
  } catch (error) {
    console.error('Get todo error:', error);
  }
}

// Update
async function updateTodo(id: string) {
  try {
    const { data: updatedTodo, errors } = await client.models.Todo.update({
      id,
      isDone: true,
    });

    if (errors) {
      console.error('Update errors:', errors);
      return;
    }

    console.log('Updated todo:', updatedTodo);
  } catch (error) {
    console.error('Update todo error:', error);
  }
}

// Delete
async function deleteTodo(id: string) {
  try {
    const { data: deletedTodo, errors } = await client.models.Todo.delete({ id });

    if (errors) {
      console.error('Delete errors:', errors);
      return;
    }

    console.log('Deleted todo:', deletedTodo);
  } catch (error) {
    console.error('Delete todo error:', error);
  }
}

// リアルタイム購読（Subscription）
function subscribeTodos() {
  const subscription = client.models.Todo.observeQuery().subscribe({
    next: ({ items, isSynced }) => {
      console.log('Todos updated:', items);
      console.log('Is synced:', isSynced);
    },
    error: (error) => {
      console.error('Subscription error:', error);
    },
  });

  // クリーンアップ
  return () => subscription.unsubscribe();
}
```

### Reactコンポーネント例

```typescript
import { useState, useEffect } from 'react';
import { client } from './client';
import type { Schema } from '../amplify/data/resource';

type Todo = Schema['Todo']['type'];

export function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // リアルタイム購読
    const subscription = client.models.Todo.observeQuery().subscribe({
      next: ({ items }) => {
        setTodos(items);
        setLoading(false);
      },
    });

    return () => subscription.unsubscribe();
  }, []);

  async function createTodo(content: string) {
    await client.models.Todo.create({
      content,
      isDone: false,
      priority: 'medium',
      createdAt: new Date().toISOString(),
    });
  }

  async function toggleTodo(id: string, isDone: boolean) {
    await client.models.Todo.update({ id, isDone: !isDone });
  }

  async function deleteTodo(id: string) {
    await client.models.Todo.delete({ id });
  }

  if (loading) return <div>Loading...</div>;

  return (
    <div>
      <h1>Todo List</h1>
      <ul>
        {todos.map((todo) => (
          <li key={todo.id}>
            <input
              type="checkbox"
              checked={todo.isDone}
              onChange={() => toggleTodo(todo.id, todo.isDone)}
            />
            <span style={{ textDecoration: todo.isDone ? 'line-through' : 'none' }}>
              {todo.content}
            </span>
            <button onClick={() => deleteTodo(todo.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

---

## ストレージ（Storage）

### ストレージ設定

#### amplify/storage/resource.ts

```typescript
import { defineStorage } from '@aws-amplify/backend';

export const storage = defineStorage({
  name: 'myAppStorage',
  access: (allow) => ({
    'public/*': [
      allow.guest.to(['read']),
      allow.authenticated.to(['read', 'write', 'delete']),
    ],
    'protected/{entity_id}/*': [
      allow.authenticated.to(['read']),
      allow.entity('identity').to(['read', 'write', 'delete']),
    ],
    'private/{entity_id}/*': [
      allow.entity('identity').to(['read', 'write', 'delete']),
    ],
  }),
});
```

### フロントエンド実装

```typescript
import {
  uploadData,
  getUrl,
  list,
  remove,
  downloadData,
  copy,
} from 'aws-amplify/storage';

// ファイルアップロード
async function handleUpload(file: File) {
  try {
    const result = await uploadData({
      path: `public/${file.name}`,
      data: file,
      options: {
        contentType: file.type,
        onProgress: ({ transferredBytes, totalBytes }) => {
          if (totalBytes) {
            const progress = (transferredBytes / totalBytes) * 100;
            console.log(`Upload progress: ${progress}%`);
          }
        },
      },
    }).result;

    console.log('Upload result:', result);
  } catch (error) {
    console.error('Upload error:', error);
  }
}

// プライベートアップロード（ユーザー専用）
async function handlePrivateUpload(file: File) {
  try {
    const result = await uploadData({
      path: ({ identityId }) => `private/${identityId}/${file.name}`,
      data: file,
    }).result;

    console.log('Private upload result:', result);
  } catch (error) {
    console.error('Private upload error:', error);
  }
}

// ファイルURL取得（ダウンロード用）
async function getFileUrl(fileName: string) {
  try {
    const result = await getUrl({
      path: `public/${fileName}`,
      options: {
        expiresIn: 900, // 15分間有効
      },
    });

    console.log('File URL:', result.url.toString());
    return result.url.toString();
  } catch (error) {
    console.error('Get URL error:', error);
  }
}

// ファイル一覧取得
async function listFiles() {
  try {
    const result = await list({
      path: 'public/',
      options: {
        listAll: true,
      },
    });

    console.log('Files:', result.items);
    return result.items;
  } catch (error) {
    console.error('List files error:', error);
  }
}

// ファイル削除
async function deleteFile(fileName: string) {
  try {
    await remove({
      path: `public/${fileName}`,
    });

    console.log('File deleted');
  } catch (error) {
    console.error('Delete file error:', error);
  }
}

// ファイルダウンロード
async function downloadFile(fileName: string) {
  try {
    const { body, eTag } = await downloadData({
      path: `public/${fileName}`,
    }).result;

    const blob = await body.blob();
    const url = URL.createObjectURL(blob);

    // ダウンロードリンク生成
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    a.click();

    URL.revokeObjectURL(url);
  } catch (error) {
    console.error('Download error:', error);
  }
}

// ファイルコピー
async function copyFile(sourcePath: string, destinationPath: string) {
  try {
    const result = await copy({
      source: {
        path: sourcePath,
      },
      destination: {
        path: destinationPath,
      },
    });

    console.log('Copy result:', result);
  } catch (error) {
    console.error('Copy error:', error);
  }
}
```

### React コンポーネント例

```typescript
import { useState } from 'react';
import { uploadData, getUrl } from 'aws-amplify/storage';

export function FileUploader() {
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [uploadedUrl, setUploadedUrl] = useState<string>('');

  async function handleUpload() {
    if (!file) return;

    setUploading(true);

    try {
      const result = await uploadData({
        path: `public/${file.name}`,
        data: file,
        options: {
          onProgress: ({ transferredBytes, totalBytes }) => {
            if (totalBytes) {
              const percent = (transferredBytes / totalBytes) * 100;
              setProgress(Math.round(percent));
            }
          },
        },
      }).result;

      console.log('Upload complete:', result);

      // アップロード後にURLを取得
      const urlResult = await getUrl({ path: `public/${file.name}` });
      setUploadedUrl(urlResult.url.toString());
    } catch (error) {
      console.error('Upload failed:', error);
    } finally {
      setUploading(false);
      setProgress(0);
    }
  }

  return (
    <div>
      <input
        type="file"
        onChange={(e) => setFile(e.target.files?.[0] || null)}
      />
      <button onClick={handleUpload} disabled={!file || uploading}>
        {uploading ? `Uploading... ${progress}%` : 'Upload'}
      </button>

      {uploadedUrl && (
        <div>
          <p>File uploaded!</p>
          <a href={uploadedUrl} target="_blank" rel="noopener noreferrer">
            View file
          </a>
        </div>
      )}
    </div>
  );
}
```

---

## API

### カスタムクエリ・ミューテーション

```typescript
import { a } from '@aws-amplify/backend';

const schema = a.schema({
  // カスタムクエリ
  listRecentPosts: a
    .query()
    .arguments({ limit: a.integer() })
    .returns(a.ref('Post').array())
    .authorization((allow) => [allow.publicApiKey()])
    .handler(
      a.handler.function({
        entry: './listRecentPosts.ts',
      })
    ),

  // カスタムミューテーション
  publishPost: a
    .mutation()
    .arguments({ postId: a.id() })
    .returns(a.ref('Post'))
    .authorization((allow) => [allow.owner()])
    .handler(
      a.handler.function({
        entry: './publishPost.ts',
      })
    ),

  Post: a
    .model({
      title: a.string(),
      content: a.string(),
      published: a.boolean(),
    })
    .authorization((allow) => [allow.publicApiKey()]),
});
```

### Lambda Resolver

```typescript
// amplify/data/listRecentPosts.ts
import type { Schema } from './resource';

export const handler: Schema['listRecentPosts']['functionHandler'] = async (
  event
) => {
  const { limit = 10 } = event.arguments;

  // DynamoDBからデータ取得（例）
  // 実際にはAWS SDKを使用してDynamoDBにアクセス

  return [
    {
      id: '1',
      title: 'Recent Post',
      content: 'This is a recent post',
      published: true,
    },
  ];
};
```

---

## デプロイ

### サンドボックス環境（開発用）

```bash
# サンドボックスの起動
npx ampx sandbox

# サンドボックスの削除
npx ampx sandbox delete
```

### 本番環境デプロイ

#### CI/CDパイプライン設定

```bash
# GitHub連携でのデプロイ
# 1. AWS Amplifyコンソールでアプリを作成
# 2. GitHubリポジトリを接続
# 3. ブランチを選択（main/production）
# 4. ビルド設定を確認

# amplify.yml（自動検出される）
```

#### amplify.yml

```yaml
version: 1
backend:
  phases:
    build:
      commands:
        - npm ci --cache .npm --prefer-offline
        - npx ampx pipeline-deploy --branch $AWS_BRANCH --app-id $AWS_APP_ID
frontend:
  phases:
    preBuild:
      commands:
        - npm ci --cache .npm --prefer-offline
    build:
      commands:
        - npm run build
  artifacts:
    baseDirectory: .next
    files:
      - '**/*'
  cache:
    paths:
      - .next/cache/**/*
      - .npm/**/*
      - node_modules/**/*
```

### 環境変数の設定

```bash
# Amplify Hostingコンソールで環境変数を設定
NEXT_PUBLIC_API_URL=https://api.example.com
DATABASE_URL=postgresql://...
```

---

## ベストプラクティス

### 1. 型安全性の活用

```typescript
// スキーマから型を生成
import type { Schema } from '../amplify/data/resource';

type Todo = Schema['Todo']['type'];
type CreateTodoInput = Schema['Todo']['createType'];
type UpdateTodoInput = Schema['Todo']['updateType'];

// 型安全なクライアント使用
const client = generateClient<Schema>();
```

### 2. エラーハンドリング

```typescript
async function safeTodoOperation() {
  try {
    const { data, errors } = await client.models.Todo.create({
      content: 'New todo',
      isDone: false,
    });

    if (errors) {
      // GraphQLエラーのハンドリング
      console.error('GraphQL errors:', errors);
      errors.forEach((error) => {
        console.error('Error type:', error.errorType);
        console.error('Error message:', error.message);
      });
      return null;
    }

    return data;
  } catch (error) {
    // ネットワークエラーなどのハンドリング
    console.error('Network or unexpected error:', error);
    return null;
  }
}
```

### 3. パフォーマンス最適化

```typescript
// ページネーション
async function listTodosWithPagination() {
  let nextToken: string | null | undefined = null;
  const allTodos: Todo[] = [];

  do {
    const { data, nextToken: newNextToken } = await client.models.Todo.list({
      limit: 100,
      nextToken,
    });

    allTodos.push(...data);
    nextToken = newNextToken;
  } while (nextToken);

  return allTodos;
}

// 選択的フィールド取得
async function getTodoTitle(id: string) {
  const { data } = await client.models.Todo.get(
    { id },
    { selectionSet: ['id', 'title'] }
  );

  return data;
}
```

### 4. セキュリティ

```typescript
// 細かい権限設定
const schema = a.schema({
  Post: a
    .model({
      title: a.string(),
      content: a.string(),
      status: a.enum(['draft', 'published']),
    })
    .authorization((allow) => [
      // 公開記事は全員が読める
      allow.authenticated().to(['read']).where((post) => post.status.eq('published')),
      // 下書きは所有者のみ
      allow.owner().to(['read', 'create', 'update', 'delete']),
      // 管理者は全権限
      allow.groups(['admin']).to(['read', 'create', 'update', 'delete']),
    ]),
});
```

---

## 参考リンク

- [AWS Amplify公式ドキュメント](https://docs.amplify.aws/)
- [AWS Amplify Gen 2](https://docs.amplify.aws/react/)
- [Amplify UI](https://ui.docs.amplify.aws/)
- [Amplify CLI](https://docs.amplify.aws/cli/)
