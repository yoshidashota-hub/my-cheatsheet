# Supabase 完全ガイド

## 目次
- [Supabaseとは](#supabaseとは)
- [セットアップ](#セットアップ)
- [認証](#認証)
- [データベース操作](#データベース操作)
- [Realtime](#realtime)
- [Storage](#storage)
- [Edge Functions](#edge-functions)
- [Row Level Security](#row-level-security)
- [Next.js統合](#nextjs統合)
- [React統合](#react統合)
- [ベストプラクティス](#ベストプラクティス)

---

## Supabaseとは

オープンソースの Firebase 代替サービス。PostgreSQL ベースの BaaS (Backend as a Service)。

### 特徴

- 🗄️ PostgreSQL: 本格的なリレーショナルDB
- 🔐 認証: Email, OAuth, Magic Link 対応
- 🔄 Realtime: リアルタイムデータ同期
- 📦 Storage: ファイルストレージ
- ⚡ Edge Functions: Deno ベースのサーバーレス関数
- 🔒 RLS: Row Level Security でデータ保護
- 💰 無料枠: 月500MB、2GB転送、50MBストレージ

### ユースケース

```
✓ SaaSアプリケーション
✓ モバイルアプリ
✓ リアルタイムチャット
✓ SNS
✓ ダッシュボード
✓ コンテンツ管理システム
```

---

## セットアップ

### プロジェクト作成

```bash
# Supabase CLI インストール
npm install -g supabase

# ログイン
supabase login

# プロジェクト初期化
supabase init

# ローカル開発環境起動
supabase start

# マイグレーション作成
supabase migration new create_users_table
```

### クライアントインストール

```bash
npm install @supabase/supabase-js
```

### クライアント初期化

```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

```typescript
// TypeScript 型定義付き
import { createClient } from '@supabase/supabase-js'
import { Database } from './database.types'

export const supabase = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)
```

---

## 認証

### Email/Password 認証

```typescript
// サインアップ
async function signUp(email: string, password: string) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: 'https://example.com/auth/callback'
    }
  })

  if (error) {
    console.error('Error signing up:', error.message)
    return
  }

  console.log('User signed up:', data.user)
}

// サインイン
async function signIn(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  })

  if (error) {
    console.error('Error signing in:', error.message)
    return
  }

  console.log('User signed in:', data.user)
  console.log('Session:', data.session)
}

// サインアウト
async function signOut() {
  const { error } = await supabase.auth.signOut()

  if (error) {
    console.error('Error signing out:', error.message)
  }
}

// パスワードリセット
async function resetPassword(email: string) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: 'https://example.com/reset-password'
  })

  if (error) {
    console.error('Error:', error.message)
  }
}
```

### OAuth 認証

```typescript
// GitHub ログイン
async function signInWithGitHub() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'github',
    options: {
      redirectTo: 'https://example.com/auth/callback'
    }
  })

  if (error) console.error('Error:', error.message)
}

// Google ログイン
async function signInWithGoogle() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: 'https://example.com/auth/callback',
      queryParams: {
        access_type: 'offline',
        prompt: 'consent'
      }
    }
  })
}

// 利用可能なプロバイダー
// - google, github, gitlab, bitbucket, azure, facebook
// - twitter, discord, slack, spotify, twitch, linkedin
```

### Magic Link 認証

```typescript
async function signInWithMagicLink(email: string) {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: 'https://example.com/auth/callback'
    }
  })

  if (error) {
    console.error('Error:', error.message)
    return
  }

  console.log('Check your email for the magic link!')
}
```

### 電話番号認証

```typescript
// SMS ログイン
async function signInWithPhone(phone: string) {
  const { error } = await supabase.auth.signInWithOtp({
    phone,
    options: {
      channel: 'sms'
    }
  })

  if (error) console.error('Error:', error.message)
}

// OTP 検証
async function verifyOtp(phone: string, token: string) {
  const { data, error } = await supabase.auth.verifyOtp({
    phone,
    token,
    type: 'sms'
  })

  if (error) console.error('Error:', error.message)
  return data
}
```

### セッション管理

```typescript
// 現在のユーザー取得
async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser()
  return user
}

// セッション取得
async function getSession() {
  const { data: { session } } = await supabase.auth.getSession()
  return session
}

// 認証状態の監視
supabase.auth.onAuthStateChange((event, session) => {
  console.log('Auth event:', event)
  console.log('Session:', session)

  if (event === 'SIGNED_IN') {
    console.log('User signed in')
  }
  if (event === 'SIGNED_OUT') {
    console.log('User signed out')
  }
})
```

---

## データベース操作

### テーブル作成

```sql
-- SQL Editor で実行
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,
  published BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- インデックス作成
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_published ON posts(published);
```

### Select（取得）

```typescript
// 全件取得
const { data, error } = await supabase
  .from('posts')
  .select('*')

// 特定カラムのみ
const { data } = await supabase
  .from('posts')
  .select('id, title, created_at')

// 関連テーブルも取得
const { data } = await supabase
  .from('posts')
  .select(`
    *,
    users (
      id,
      name,
      avatar_url
    )
  `)

// 条件指定
const { data } = await supabase
  .from('posts')
  .select('*')
  .eq('published', true)
  .order('created_at', { ascending: false })
  .limit(10)

// 単一レコード取得
const { data, error } = await supabase
  .from('posts')
  .select('*')
  .eq('id', postId)
  .single()
```

### Insert（挿入）

```typescript
// 単一レコード挿入
const { data, error } = await supabase
  .from('posts')
  .insert({
    user_id: userId,
    title: 'My First Post',
    content: 'Hello, Supabase!'
  })
  .select()
  .single()

// 複数レコード挿入
const { data, error } = await supabase
  .from('posts')
  .insert([
    { title: 'Post 1', content: 'Content 1' },
    { title: 'Post 2', content: 'Content 2' }
  ])
  .select()
```

### Update（更新）

```typescript
// 更新
const { data, error } = await supabase
  .from('posts')
  .update({
    title: 'Updated Title',
    updated_at: new Date().toISOString()
  })
  .eq('id', postId)
  .select()
  .single()

// 条件付き更新
const { data, error } = await supabase
  .from('posts')
  .update({ published: true })
  .eq('user_id', userId)
  .eq('published', false)
  .select()
```

### Upsert（存在すれば更新、なければ挿入）

```typescript
const { data, error } = await supabase
  .from('posts')
  .upsert({
    id: postId,
    title: 'Title',
    content: 'Content'
  })
  .select()
  .single()
```

### Delete（削除）

```typescript
const { error } = await supabase
  .from('posts')
  .delete()
  .eq('id', postId)

// 条件付き削除
const { error } = await supabase
  .from('posts')
  .delete()
  .eq('user_id', userId)
  .eq('published', false)
```

### フィルター

```typescript
// 等しい
.eq('status', 'active')

// 等しくない
.neq('status', 'deleted')

// より大きい
.gt('age', 18)

// 以上
.gte('age', 18)

// より小さい
.lt('age', 65)

// 以下
.lte('age', 65)

// LIKE
.like('name', '%John%')

// ILIKE（大文字小文字無視）
.ilike('email', '%@gmail.com')

// IN
.in('status', ['active', 'pending'])

// IS NULL
.is('deleted_at', null)

// NOT NULL
.not('deleted_at', 'is', null)

// OR条件
.or('status.eq.active,status.eq.pending')

// AND条件
.and('age.gte.18,age.lte.65')
```

### ページネーション

```typescript
// Offset pagination
const pageSize = 10
const page = 1

const { data, error, count } = await supabase
  .from('posts')
  .select('*', { count: 'exact' })
  .order('created_at', { ascending: false })
  .range((page - 1) * pageSize, page * pageSize - 1)

// Cursor pagination
const { data, error } = await supabase
  .from('posts')
  .select('*')
  .order('created_at', { ascending: false })
  .lt('created_at', lastPostCreatedAt)
  .limit(10)
```

### 全文検索

```typescript
// テーブルに全文検索インデックス作成
-- SQL:
-- ALTER TABLE posts ADD COLUMN fts tsvector
--   GENERATED ALWAYS AS (to_tsvector('english', title || ' ' || content)) STORED;
-- CREATE INDEX posts_fts ON posts USING GIN (fts);

// 検索
const { data, error } = await supabase
  .from('posts')
  .select('*')
  .textSearch('fts', 'supabase')
```

---

## Realtime

### リアルタイム購読

```typescript
// テーブルの変更を監視
const channel = supabase
  .channel('posts-changes')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'posts'
    },
    (payload) => {
      console.log('Change received:', payload)
    }
  )
  .subscribe()

// 特定イベントのみ監視
const channel = supabase
  .channel('posts-inserts')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'posts'
    },
    (payload) => {
      console.log('New post:', payload.new)
    }
  )
  .subscribe()

// フィルター付き監視
const channel = supabase
  .channel('user-posts')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'posts',
      filter: `user_id=eq.${userId}`
    },
    (payload) => {
      console.log('User post changed:', payload)
    }
  )
  .subscribe()

// 購読解除
channel.unsubscribe()
```

### Presence（オンライン状態）

```typescript
// チャンネル参加
const channel = supabase.channel('room1')

const presenceTrackStatus = await channel.track({
  user_id: userId,
  online_at: new Date().toISOString()
})

// オンラインユーザー監視
channel.on('presence', { event: 'sync' }, () => {
  const state = channel.presenceState()
  console.log('Online users:', state)
})

channel.on('presence', { event: 'join' }, ({ key, newPresences }) => {
  console.log('User joined:', newPresences)
})

channel.on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
  console.log('User left:', leftPresences)
})

channel.subscribe()
```

### Broadcast（メッセージング）

```typescript
// チャンネル作成
const channel = supabase.channel('chat-room')

// メッセージ送信
channel.send({
  type: 'broadcast',
  event: 'message',
  payload: {
    user_id: userId,
    message: 'Hello!'
  }
})

// メッセージ受信
channel.on('broadcast', { event: 'message' }, (payload) => {
  console.log('Message received:', payload)
})

channel.subscribe()
```

---

## Storage

### バケット作成

```typescript
// バケット作成（ダッシュボードまたはSQL）
const { data, error } = await supabase.storage.createBucket('avatars', {
  public: true,
  fileSizeLimit: 1024 * 1024 * 5 // 5MB
})
```

### ファイルアップロード

```typescript
// ファイルアップロード
async function uploadFile(file: File) {
  const fileExt = file.name.split('.').pop()
  const fileName = `${Math.random()}.${fileExt}`
  const filePath = `${userId}/${fileName}`

  const { data, error } = await supabase.storage
    .from('avatars')
    .upload(filePath, file)

  if (error) {
    console.error('Upload error:', error.message)
    return null
  }

  // 公開URLを取得
  const { data: { publicUrl } } = supabase.storage
    .from('avatars')
    .getPublicUrl(filePath)

  return publicUrl
}

// Base64アップロード
const { data, error } = await supabase.storage
  .from('avatars')
  .upload('path/to/file.png', decode(base64), {
    contentType: 'image/png'
  })
```

### ファイルダウンロード

```typescript
// ファイルダウンロード
const { data, error } = await supabase.storage
  .from('avatars')
  .download('path/to/file.png')

if (data) {
  const url = URL.createObjectURL(data)
  // 画像表示やダウンロードに使用
}

// 公開URLを取得
const { data } = supabase.storage
  .from('avatars')
  .getPublicUrl('path/to/file.png')

console.log('Public URL:', data.publicUrl)

// 署名付きURL（有効期限付き）
const { data, error } = await supabase.storage
  .from('private-files')
  .createSignedUrl('path/to/file.pdf', 60) // 60秒有効

console.log('Signed URL:', data.signedUrl)
```

### ファイル削除

```typescript
// 単一ファイル削除
const { error } = await supabase.storage
  .from('avatars')
  .remove(['path/to/file.png'])

// 複数ファイル削除
const { error } = await supabase.storage
  .from('avatars')
  .remove(['file1.png', 'file2.png', 'file3.png'])
```

### ファイル一覧

```typescript
const { data, error } = await supabase.storage
  .from('avatars')
  .list('user-folder', {
    limit: 100,
    offset: 0,
    sortBy: { column: 'name', order: 'asc' }
  })

console.log('Files:', data)
```

---

## Edge Functions

### Edge Function 作成

```bash
# Edge Function 作成
supabase functions new hello

# ローカルで実行
supabase functions serve

# デプロイ
supabase functions deploy hello
```

### Edge Function 実装

```typescript
// supabase/functions/hello/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! }
        }
      }
    )

    // 認証ユーザー取得
    const { data: { user } } = await supabase.auth.getUser()

    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // 処理...
    const result = {
      message: 'Hello from Edge Functions!',
      user: user.email
    }

    return new Response(
      JSON.stringify(result),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

### Edge Function 呼び出し

```typescript
// クライアントから呼び出し
const { data, error } = await supabase.functions.invoke('hello', {
  body: { name: 'World' }
})

console.log('Response:', data)
```

---

## Row Level Security

### RLS 有効化

```sql
-- RLS 有効化
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- 全ユーザーが読み取り可能
CREATE POLICY "Public posts are viewable by everyone"
  ON posts FOR SELECT
  USING (published = true);

-- 自分の投稿のみ閲覧可能
CREATE POLICY "Users can view their own posts"
  ON posts FOR SELECT
  USING (auth.uid() = user_id);

-- 自分の投稿のみ挿入可能
CREATE POLICY "Users can insert their own posts"
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 自分の投稿のみ更新可能
CREATE POLICY "Users can update their own posts"
  ON posts FOR UPDATE
  USING (auth.uid() = user_id);

-- 自分の投稿のみ削除可能
CREATE POLICY "Users can delete their own posts"
  ON posts FOR DELETE
  USING (auth.uid() = user_id);
```

### 複雑な RLS ポリシー

```sql
-- 管理者または所有者のみ編集可能
CREATE POLICY "Admins and owners can edit"
  ON posts FOR UPDATE
  USING (
    auth.uid() = user_id
    OR
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- チームメンバーのみアクセス可能
CREATE POLICY "Team members can view"
  ON projects FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.project_id = projects.id
      AND team_members.user_id = auth.uid()
    )
  );
```

---

## Next.js統合

### App Router 対応

```typescript
// app/lib/supabase.ts
import { createClient } from '@supabase/supabase-js'
import { cookies } from 'next/headers'

export function createServerClient() {
  const cookieStore = cookies()

  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value
        }
      }
    }
  )
}
```

```typescript
// app/page.tsx
import { createServerClient } from './lib/supabase'

export default async function Home() {
  const supabase = createServerClient()

  const { data: posts } = await supabase
    .from('posts')
    .select('*')
    .order('created_at', { ascending: false })

  return (
    <div>
      {posts?.map(post => (
        <div key={post.id}>
          <h2>{post.title}</h2>
          <p>{post.content}</p>
        </div>
      ))}
    </div>
  )
}
```

### 認証フロー

```typescript
// app/auth/callback/route.ts
import { createServerClient } from '@/lib/supabase'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')

  if (code) {
    const supabase = createServerClient()
    await supabase.auth.exchangeCodeForSession(code)
  }

  return NextResponse.redirect(requestUrl.origin)
}
```

---

## React統合

### useSupabase Hook

```typescript
// hooks/useSupabase.ts
import { useEffect, useState } from 'react'
import { User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'

export function useSupabase() {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // 初期ユーザー取得
    supabase.auth.getUser().then(({ data: { user } }) => {
      setUser(user)
      setLoading(false)
    })

    // 認証状態の監視
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
      setLoading(false)
    })

    return () => subscription.unsubscribe()
  }, [])

  return { user, loading, supabase }
}
```

### リアルタイムデータフック

```typescript
// hooks/usePosts.ts
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export function usePosts() {
  const [posts, setPosts] = useState<any[]>([])

  useEffect(() => {
    // 初期データ取得
    supabase
      .from('posts')
      .select('*')
      .order('created_at', { ascending: false })
      .then(({ data }) => setPosts(data || []))

    // リアルタイム更新
    const channel = supabase
      .channel('posts-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'posts' }, (payload) => {
        if (payload.eventType === 'INSERT') {
          setPosts((prev) => [payload.new, ...prev])
        }
        if (payload.eventType === 'UPDATE') {
          setPosts((prev) => prev.map((post) =>
            post.id === payload.new.id ? payload.new : post
          ))
        }
        if (payload.eventType === 'DELETE') {
          setPosts((prev) => prev.filter((post) => post.id !== payload.old.id))
        }
      })
      .subscribe()

    return () => {
      channel.unsubscribe()
    }
  }, [])

  return posts
}
```

---

## ベストプラクティス

### 1. 環境変数管理

```bash
# .env.local
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key  # サーバーサイドのみ
```

### 2. 型安全性

```bash
# 型定義生成
supabase gen types typescript --project-id your-project-id > database.types.ts
```

```typescript
import { Database } from './database.types'

export const supabase = createClient<Database>(url, key)

// 型安全なクエリ
const { data } = await supabase
  .from('posts')
  .select('id, title, content')
  .single()
// data の型が自動推論される
```

### 3. RLS を必ず有効化

```sql
-- 全テーブルで RLS 有効化
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
```

### 4. エラーハンドリング

```typescript
async function fetchPosts() {
  const { data, error } = await supabase
    .from('posts')
    .select('*')

  if (error) {
    console.error('Database error:', error)
    throw new Error('Failed to fetch posts')
  }

  return data
}
```

### 5. インデックス最適化

```sql
-- 頻繁に検索するカラムにインデックス
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

-- 複合インデックス
CREATE INDEX idx_posts_user_published ON posts(user_id, published);
```

---

## 参考リンク

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase JavaScript Client](https://supabase.com/docs/reference/javascript)
- [Supabase Next.js Quick Start](https://supabase.com/docs/guides/getting-started/quickstarts/nextjs)
