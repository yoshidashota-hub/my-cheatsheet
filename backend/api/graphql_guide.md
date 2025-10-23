# GraphQL ガイド

GraphQLは、APIのためのクエリ言語およびランタイムです。

## 特徴

- **必要なデータだけ取得**: 過剰取得・不足取得を防ぐ
- **単一エンドポイント**: `/graphql` 一つで全てのデータにアクセス
- **強力な型システム**: スキーマで定義された型安全なAPI
- **イントロスペクション**: APIの構造を自己文書化
- **リアルタイム通信**: Subscriptionでリアルタイム更新

## RESTとの比較

| 特徴 | REST | GraphQL |
|------|------|---------|
| エンドポイント | 複数 | 単一 |
| データ取得 | 固定形式 | クライアントが指定 |
| 過剰取得 | あり | なし |
| バージョニング | 必要 | 不要（非推奨フィールド） |
| リアルタイム | 別途実装 | Subscription |

## 基本概念

### スキーマ

```graphql
type User {
  id: ID!
  name: String!
  email: String!
  age: Int
  posts: [Post!]!
}

type Post {
  id: ID!
  title: String!
  content: String!
  author: User!
  createdAt: String!
}

type Query {
  user(id: ID!): User
  users: [User!]!
  post(id: ID!): Post
  posts: [Post!]!
}

type Mutation {
  createUser(name: String!, email: String!): User!
  updateUser(id: ID!, name: String, email: String): User!
  deleteUser(id: ID!): Boolean!
  createPost(title: String!, content: String!, authorId: ID!): Post!
}
```

### クエリ

```graphql
# 単一ユーザー取得
query {
  user(id: "1") {
    id
    name
    email
  }
}

# 複数ユーザー取得
query {
  users {
    id
    name
    posts {
      id
      title
    }
  }
}

# エイリアス
query {
  user1: user(id: "1") {
    name
  }
  user2: user(id: "2") {
    name
  }
}

# フラグメント
query {
  user(id: "1") {
    ...UserFields
  }
}

fragment UserFields on User {
  id
  name
  email
}
```

### ミューテーション

```graphql
# ユーザー作成
mutation {
  createUser(name: "John Doe", email: "john@example.com") {
    id
    name
    email
  }
}

# ユーザー更新
mutation {
  updateUser(id: "1", name: "Jane Doe") {
    id
    name
  }
}

# ユーザー削除
mutation {
  deleteUser(id: "1")
}
```

### 変数

```graphql
# クエリ定義
query GetUser($userId: ID!) {
  user(id: $userId) {
    id
    name
    email
  }
}

# 変数
{
  "userId": "1"
}
```

## Apollo Server（Node.js）

### インストール

```bash
npm install @apollo/server graphql
```

### 基本セットアップ

```typescript
// server.ts
import { ApolloServer } from '@apollo/server'
import { startStandaloneServer } from '@apollo/server/standalone'

// スキーマ定義
const typeDefs = `
  type User {
    id: ID!
    name: String!
    email: String!
  }

  type Query {
    users: [User!]!
    user(id: ID!): User
  }

  type Mutation {
    createUser(name: String!, email: String!): User!
  }
`

// モックデータ
const users = [
  { id: '1', name: 'John Doe', email: 'john@example.com' },
  { id: '2', name: 'Jane Smith', email: 'jane@example.com' },
]

// リゾルバー
const resolvers = {
  Query: {
    users: () => users,
    user: (_, { id }) => users.find(user => user.id === id),
  },
  Mutation: {
    createUser: (_, { name, email }) => {
      const user = {
        id: String(users.length + 1),
        name,
        email,
      }
      users.push(user)
      return user
    },
  },
}

// サーバー起動
const server = new ApolloServer({
  typeDefs,
  resolvers,
})

const { url } = await startStandaloneServer(server, {
  listen: { port: 4000 },
})

console.log(`Server ready at ${url}`)
```

### データベース統合（Prisma）

```typescript
import { PrismaClient } from '@prisma/client'
import { ApolloServer } from '@apollo/server'

const prisma = new PrismaClient()

const typeDefs = `
  type User {
    id: ID!
    name: String!
    email: String!
    posts: [Post!]!
  }

  type Post {
    id: ID!
    title: String!
    content: String!
    author: User!
  }

  type Query {
    users: [User!]!
    user(id: ID!): User
    posts: [Post!]!
    post(id: ID!): Post
  }

  type Mutation {
    createUser(name: String!, email: String!): User!
    createPost(title: String!, content: String!, authorId: ID!): Post!
  }
`

const resolvers = {
  Query: {
    users: () => prisma.user.findMany(),
    user: (_, { id }) => prisma.user.findUnique({ where: { id } }),
    posts: () => prisma.post.findMany(),
    post: (_, { id }) => prisma.post.findUnique({ where: { id } }),
  },
  Mutation: {
    createUser: (_, { name, email }) =>
      prisma.user.create({
        data: { name, email },
      }),
    createPost: (_, { title, content, authorId }) =>
      prisma.post.create({
        data: {
          title,
          content,
          authorId,
        },
      }),
  },
  User: {
    posts: (parent) =>
      prisma.post.findMany({
        where: { authorId: parent.id },
      }),
  },
  Post: {
    author: (parent) =>
      prisma.user.findUnique({
        where: { id: parent.authorId },
      }),
  },
}
```

### コンテキスト

```typescript
interface Context {
  user?: User
  prisma: PrismaClient
}

const server = new ApolloServer<Context>({
  typeDefs,
  resolvers,
})

const { url } = await startStandaloneServer(server, {
  context: async ({ req }) => {
    // 認証トークンからユーザーを取得
    const token = req.headers.authorization || ''
    const user = await getUserFromToken(token)

    return {
      user,
      prisma,
    }
  },
  listen: { port: 4000 },
})
```

### 認証・認可

```typescript
const typeDefs = `
  type Query {
    me: User
    users: [User!]!
  }

  type Mutation {
    login(email: String!, password: String!): AuthPayload!
  }

  type AuthPayload {
    token: String!
    user: User!
  }
`

const resolvers = {
  Query: {
    me: (_, __, context: Context) => {
      if (!context.user) {
        throw new Error('Not authenticated')
      }
      return context.user
    },
    users: (_, __, context: Context) => {
      if (!context.user?.isAdmin) {
        throw new Error('Not authorized')
      }
      return prisma.user.findMany()
    },
  },
  Mutation: {
    login: async (_, { email, password }) => {
      const user = await prisma.user.findUnique({ where: { email } })

      if (!user || !await verifyPassword(password, user.password)) {
        throw new Error('Invalid credentials')
      }

      const token = generateToken(user)

      return { token, user }
    },
  },
}
```

### DataLoader（N+1問題の解決）

```bash
npm install dataloader
```

```typescript
import DataLoader from 'dataloader'

// バッチ読み込み関数
const batchUsers = async (ids: string[]) => {
  const users = await prisma.user.findMany({
    where: { id: { in: ids } },
  })

  // IDの順序を保持
  return ids.map(id => users.find(user => user.id === id))
}

// DataLoaderの作成
const createLoaders = () => ({
  userLoader: new DataLoader(batchUsers),
})

// コンテキストに追加
const { url } = await startStandaloneServer(server, {
  context: async ({ req }) => ({
    prisma,
    loaders: createLoaders(),
  }),
})

// リゾルバーで使用
const resolvers = {
  Post: {
    author: (parent, _, context: Context) =>
      context.loaders.userLoader.load(parent.authorId),
  },
}
```

## Apollo Client（React）

### インストール

```bash
npm install @apollo/client graphql
```

### セットアップ

```typescript
// app/providers.tsx
'use client'

import { ApolloClient, InMemoryCache, ApolloProvider, HttpLink } from '@apollo/client'

const client = new ApolloClient({
  link: new HttpLink({
    uri: 'http://localhost:4000/graphql',
  }),
  cache: new InMemoryCache(),
})

export function ApolloWrapper({ children }: { children: React.ReactNode }) {
  return <ApolloProvider client={client}>{children}</ApolloProvider>
}

// app/layout.tsx
import { ApolloWrapper } from './providers'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <ApolloWrapper>{children}</ApolloWrapper>
      </body>
    </html>
  )
}
```

### クエリ

```typescript
import { useQuery, gql } from '@apollo/client'

const GET_USERS = gql`
  query GetUsers {
    users {
      id
      name
      email
    }
  }
`

export function UserList() {
  const { loading, error, data } = useQuery(GET_USERS)

  if (loading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>

  return (
    <ul>
      {data.users.map((user) => (
        <li key={user.id}>
          {user.name} - {user.email}
        </li>
      ))}
    </ul>
  )
}
```

### 変数付きクエリ

```typescript
const GET_USER = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      name
      email
      posts {
        id
        title
      }
    }
  }
`

export function UserProfile({ userId }: { userId: string }) {
  const { loading, error, data } = useQuery(GET_USER, {
    variables: { id: userId },
  })

  if (loading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>

  return (
    <div>
      <h1>{data.user.name}</h1>
      <p>{data.user.email}</p>
      <h2>Posts</h2>
      <ul>
        {data.user.posts.map((post) => (
          <li key={post.id}>{post.title}</li>
        ))}
      </ul>
    </div>
  )
}
```

### ミューテーション

```typescript
import { useMutation, gql } from '@apollo/client'

const CREATE_USER = gql`
  mutation CreateUser($name: String!, $email: String!) {
    createUser(name: $name, email: $email) {
      id
      name
      email
    }
  }
`

export function CreateUserForm() {
  const [createUser, { loading, error }] = useMutation(CREATE_USER, {
    // キャッシュを更新
    refetchQueries: [{ query: GET_USERS }],
  })

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const formData = new FormData(e.currentTarget)

    try {
      const { data } = await createUser({
        variables: {
          name: formData.get('name'),
          email: formData.get('email'),
        },
      })
      console.log('Created user:', data.createUser)
    } catch (err) {
      console.error('Error creating user:', err)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <input name="name" placeholder="Name" required />
      <input name="email" type="email" placeholder="Email" required />
      <button type="submit" disabled={loading}>
        {loading ? 'Creating...' : 'Create User'}
      </button>
      {error && <p>Error: {error.message}</p>}
    </form>
  )
}
```

### 楽観的UI更新

```typescript
const DELETE_USER = gql`
  mutation DeleteUser($id: ID!) {
    deleteUser(id: $id)
  }
`

const [deleteUser] = useMutation(DELETE_USER, {
  optimisticResponse: {
    deleteUser: true,
  },
  update: (cache, { data }) => {
    if (data?.deleteUser) {
      cache.modify({
        fields: {
          users(existingUsers = [], { readField }) {
            return existingUsers.filter(
              (userRef) => userId !== readField('id', userRef)
            )
          },
        },
      })
    }
  },
})
```

### キャッシュ管理

```typescript
// キャッシュから読み取り
const user = client.readQuery({
  query: GET_USER,
  variables: { id: '1' },
})

// キャッシュに書き込み
client.writeQuery({
  query: GET_USER,
  variables: { id: '1' },
  data: { user: { id: '1', name: 'John', email: 'john@example.com' } },
})

// キャッシュをクリア
client.cache.reset()

// 特定のクエリを再取得
client.refetchQueries({
  include: [GET_USERS],
})
```

## Subscriptions（リアルタイム）

### サーバー側

```bash
npm install graphql-ws ws
```

```typescript
import { ApolloServer } from '@apollo/server'
import { expressMiddleware } from '@apollo/server/express4'
import { createServer } from 'http'
import { WebSocketServer } from 'ws'
import { useServer } from 'graphql-ws/lib/use/ws'
import { makeExecutableSchema } from '@graphql-tools/schema'
import express from 'express'
import { PubSub } from 'graphql-subscriptions'

const pubsub = new PubSub()

const typeDefs = `
  type Post {
    id: ID!
    title: String!
    content: String!
  }

  type Query {
    posts: [Post!]!
  }

  type Mutation {
    createPost(title: String!, content: String!): Post!
  }

  type Subscription {
    postCreated: Post!
  }
`

const resolvers = {
  Query: {
    posts: () => prisma.post.findMany(),
  },
  Mutation: {
    createPost: async (_, { title, content }) => {
      const post = await prisma.post.create({
        data: { title, content },
      })

      // サブスクリプションに通知
      pubsub.publish('POST_CREATED', { postCreated: post })

      return post
    },
  },
  Subscription: {
    postCreated: {
      subscribe: () => pubsub.asyncIterator(['POST_CREATED']),
    },
  },
}

const schema = makeExecutableSchema({ typeDefs, resolvers })

const app = express()
const httpServer = createServer(app)

// WebSocketサーバー
const wsServer = new WebSocketServer({
  server: httpServer,
  path: '/graphql',
})

useServer({ schema }, wsServer)

// Apollo Server
const server = new ApolloServer({ schema })
await server.start()

app.use('/graphql', express.json(), expressMiddleware(server))

httpServer.listen(4000, () => {
  console.log('Server ready at http://localhost:4000/graphql')
})
```

### クライアント側

```bash
npm install graphql-ws
```

```typescript
import { ApolloClient, InMemoryCache, split, HttpLink } from '@apollo/client'
import { GraphQLWsLink } from '@apollo/client/link/subscriptions'
import { getMainDefinition } from '@apollo/client/utilities'
import { createClient } from 'graphql-ws'

const httpLink = new HttpLink({
  uri: 'http://localhost:4000/graphql',
})

const wsLink = new GraphQLWsLink(
  createClient({
    url: 'ws://localhost:4000/graphql',
  })
)

// HTTPとWebSocketを使い分け
const splitLink = split(
  ({ query }) => {
    const definition = getMainDefinition(query)
    return (
      definition.kind === 'OperationDefinition' &&
      definition.operation === 'subscription'
    )
  },
  wsLink,
  httpLink
)

const client = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache(),
})
```

```typescript
import { useSubscription, gql } from '@apollo/client'

const POST_CREATED = gql`
  subscription OnPostCreated {
    postCreated {
      id
      title
      content
    }
  }
`

export function PostSubscription() {
  const { data, loading } = useSubscription(POST_CREATED)

  if (loading) return <div>Waiting for new posts...</div>

  return (
    <div>
      <h3>New Post!</h3>
      <p>{data?.postCreated.title}</p>
    </div>
  )
}
```

## ページネーション

### オフセットベース

```graphql
type Query {
  posts(offset: Int!, limit: Int!): PostConnection!
}

type PostConnection {
  items: [Post!]!
  total: Int!
  hasMore: Boolean!
}
```

```typescript
const resolvers = {
  Query: {
    posts: async (_, { offset, limit }) => {
      const [items, total] = await Promise.all([
        prisma.post.findMany({
          skip: offset,
          take: limit,
        }),
        prisma.post.count(),
      ])

      return {
        items,
        total,
        hasMore: offset + limit < total,
      }
    },
  },
}
```

### カーソルベース

```graphql
type Query {
  posts(first: Int!, after: String): PostConnection!
}

type PostConnection {
  edges: [PostEdge!]!
  pageInfo: PageInfo!
}

type PostEdge {
  node: Post!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  endCursor: String
}
```

```typescript
const resolvers = {
  Query: {
    posts: async (_, { first, after }) => {
      const posts = await prisma.post.findMany({
        take: first + 1,
        ...(after && {
          cursor: { id: after },
          skip: 1,
        }),
        orderBy: { createdAt: 'desc' },
      })

      const hasNextPage = posts.length > first
      const edges = posts.slice(0, first).map(post => ({
        node: post,
        cursor: post.id,
      }))

      return {
        edges,
        pageInfo: {
          hasNextPage,
          endCursor: edges[edges.length - 1]?.cursor,
        },
      }
    },
  },
}
```

## エラーハンドリング

```typescript
import { GraphQLError } from 'graphql'

const resolvers = {
  Query: {
    user: async (_, { id }) => {
      const user = await prisma.user.findUnique({ where: { id } })

      if (!user) {
        throw new GraphQLError('User not found', {
          extensions: {
            code: 'USER_NOT_FOUND',
            http: { status: 404 },
          },
        })
      }

      return user
    },
  },
}
```

## ベストプラクティス

1. **スキーマファースト設計**: スキーマを先に設計
2. **命名規則**: camelCaseを使用
3. **NULL許容性**: 必須フィールドには `!` を付ける
4. **DataLoaderでN+1問題を解決**: バッチ処理で効率化
5. **ページネーション**: 大量データはページネーション
6. **エラーハンドリング**: 適切なエラーコードと メッセージ
7. **認証・認可**: コンテキストで管理
8. **キャッシュ戦略**: Apollo Clientのキャッシュを活用

## 参考リンク

- [GraphQL 公式ドキュメント](https://graphql.org/)
- [Apollo Server Documentation](https://www.apollographql.com/docs/apollo-server/)
- [Apollo Client Documentation](https://www.apollographql.com/docs/react/)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
- [How to GraphQL](https://www.howtographql.com/)
