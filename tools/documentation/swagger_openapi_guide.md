# Swagger / OpenAPI 完全ガイド

## 目次
- [概要](#概要)
- [OpenAPI仕様](#openapi仕様)
- [Swagger UI](#swagger-ui)
- [コード生成](#コード生成)
- [フレームワーク統合](#フレームワーク統合)
- [バリデーション](#バリデーション)

---

## 概要

REST API の仕様を記述・文書化するための標準フォーマット。

### 用語
- **OpenAPI**: API仕様の標準フォーマット (旧: Swagger Specification)
- **Swagger**: OpenAPIのツールセット (UI, Editor, Codegen等)

### メリット
- 📝 API仕様の標準化
- 🎨 インタラクティブなドキュメント
- 🔧 コード自動生成
- ✅ リクエスト/レスポンスのバリデーション

---

## OpenAPI仕様

### 基本構造

```yaml
# openapi.yaml
openapi: 3.0.3
info:
  title: My API
  description: API documentation
  version: 1.0.0
  contact:
    name: API Support
    email: support@example.com

servers:
  - url: https://api.example.com/v1
    description: Production
  - url: http://localhost:3000/v1
    description: Development

paths:
  /users:
    get:
      summary: Get all users
      tags:
        - Users
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'

components:
  schemas:
    User:
      type: object
      required:
        - id
        - name
      properties:
        id:
          type: string
        name:
          type: string
        email:
          type: string
          format: email
```

### パス定義

```yaml
paths:
  /users:
    get:
      summary: Get all users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
      responses:
        '200':
          description: Success

    post:
      summary: Create user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UserInput'
      responses:
        '201':
          description: Created

  /users/{id}:
    get:
      summary: Get user by ID
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Success
        '404':
          description: Not found
```

### スキーマ定義

```yaml
components:
  schemas:
    User:
      type: object
      required:
        - id
        - name
        - email
      properties:
        id:
          type: string
          example: "123"
        name:
          type: string
          minLength: 1
          maxLength: 100
          example: "John Doe"
        email:
          type: string
          format: email
          example: "john@example.com"
        age:
          type: integer
          minimum: 0
          maximum: 150
          example: 30
        role:
          type: string
          enum: [admin, user, guest]
          default: user
        createdAt:
          type: string
          format: date-time

    UserInput:
      type: object
      required:
        - name
        - email
      properties:
        name:
          type: string
        email:
          type: string
          format: email
        age:
          type: integer
```

### 認証

```yaml
components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

    ApiKey:
      type: apiKey
      in: header
      name: X-API-Key

    OAuth2:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://example.com/oauth/authorize
          tokenUrl: https://example.com/oauth/token
          scopes:
            read: Read access
            write: Write access

security:
  - BearerAuth: []

paths:
  /users:
    get:
      security:
        - BearerAuth: []
      responses:
        '200':
          description: Success
        '401':
          description: Unauthorized
```

---

## Swagger UI

インタラクティブなAPIドキュメント。

### Express統合

```bash
npm install swagger-ui-express yamljs
```

```typescript
import express from 'express'
import swaggerUi from 'swagger-ui-express'
import YAML from 'yamljs'

const app = express()
const swaggerDocument = YAML.load('./openapi.yaml')

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'My API Documentation'
}))

app.listen(3000, () => {
  console.log('API docs: http://localhost:3000/api-docs')
})
```

### Fastify統合

```bash
npm install @fastify/swagger @fastify/swagger-ui
```

```typescript
import fastify from 'fastify'
import swagger from '@fastify/swagger'
import swaggerUi from '@fastify/swagger-ui'

const server = fastify()

await server.register(swagger, {
  openapi: {
    info: {
      title: 'My API',
      version: '1.0.0'
    }
  }
})

await server.register(swaggerUi, {
  routePrefix: '/docs',
  uiConfig: {
    docExpansion: 'list',
    deepLinking: false
  }
})

server.get('/users', {
  schema: {
    description: 'Get all users',
    tags: ['Users'],
    response: {
      200: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            name: { type: 'string' }
          }
        }
      }
    }
  }
}, async (req, reply) => {
  return [{ id: '1', name: 'John' }]
})

await server.listen({ port: 3000 })
```

### NestJS統合

```bash
npm install @nestjs/swagger
```

```typescript
// main.ts
import { NestFactory } from '@nestjs/core'
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger'
import { AppModule } from './app.module'

async function bootstrap() {
  const app = await NestFactory.create(AppModule)

  const config = new DocumentBuilder()
    .setTitle('My API')
    .setDescription('API documentation')
    .setVersion('1.0')
    .addBearerAuth()
    .build()

  const document = SwaggerModule.createDocument(app, config)
  SwaggerModule.setup('api', app, document)

  await app.listen(3000)
}
bootstrap()

// user.controller.ts
import { Controller, Get, Post, Body } from '@nestjs/common'
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger'
import { CreateUserDto } from './dto/create-user.dto'
import { User } from './entities/user.entity'

@ApiTags('users')
@Controller('users')
export class UserController {
  @Get()
  @ApiOperation({ summary: 'Get all users' })
  @ApiResponse({ status: 200, description: 'Success', type: [User] })
  findAll(): User[] {
    return []
  }

  @Post()
  @ApiOperation({ summary: 'Create user' })
  @ApiResponse({ status: 201, description: 'Created', type: User })
  create(@Body() createUserDto: CreateUserDto): User {
    return {} as User
  }
}
```

---

## コード生成

OpenAPI仕様からコードを自動生成。

### クライアントコード生成

```bash
npm install @openapitools/openapi-generator-cli
```

```bash
# TypeScript Axios
npx openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-axios \
  -o ./src/api

# TypeScript Fetch
npx openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-fetch \
  -o ./src/api
```

### 生成されたコード使用例

```typescript
import { UsersApi, Configuration } from './api'

const config = new Configuration({
  basePath: 'https://api.example.com',
  accessToken: 'your-token'
})

const api = new UsersApi(config)

// ユーザー一覧取得
const users = await api.getUsers()

// ユーザー作成
const newUser = await api.createUser({
  name: 'John Doe',
  email: 'john@example.com'
})
```

### orval

よりモダンなコード生成ツール。

```bash
npm install --save-dev orval
```

```javascript
// orval.config.js
module.exports = {
  api: {
    input: './openapi.yaml',
    output: {
      mode: 'tags-split',
      target: './src/api',
      client: 'react-query',
      mock: true
    }
  }
}
```

```bash
npx orval
```

```typescript
// 生成されたReact Query hooks
import { useGetUsers, useCreateUser } from './api/users'

function UserList() {
  const { data: users, isLoading } = useGetUsers()
  const createUser = useCreateUser()

  const handleCreate = async () => {
    await createUser.mutateAsync({
      data: { name: 'John', email: 'john@example.com' }
    })
  }

  if (isLoading) return <div>Loading...</div>

  return (
    <div>
      {users?.map(user => <div key={user.id}>{user.name}</div>)}
      <button onClick={handleCreate}>Create</button>
    </div>
  )
}
```

---

## フレームワーク統合

### tRPC + OpenAPI

```bash
npm install trpc-openapi
```

```typescript
import { initTRPC } from '@trpc/server'
import { OpenApiMeta } from 'trpc-openapi'

const t = initTRPC.meta<OpenApiMeta>().create()

export const appRouter = t.router({
  getUsers: t.procedure
    .meta({
      openapi: {
        method: 'GET',
        path: '/users',
        tags: ['Users'],
        summary: 'Get all users'
      }
    })
    .input(z.void())
    .output(z.array(UserSchema))
    .query(async () => {
      return await db.users.findMany()
    })
})

// OpenAPI仕様生成
import { generateOpenApiDocument } from 'trpc-openapi'

export const openApiDocument = generateOpenApiDocument(appRouter, {
  title: 'My API',
  version: '1.0.0',
  baseUrl: 'http://localhost:3000'
})
```

### Hono + Zod OpenAPI

```bash
npm install @hono/zod-openapi
```

```typescript
import { createRoute, OpenAPIHono, z } from '@hono/zod-openapi'

const app = new OpenAPIHono()

const UserSchema = z.object({
  id: z.string().openapi({ example: '123' }),
  name: z.string().openapi({ example: 'John Doe' }),
  email: z.string().email().openapi({ example: 'john@example.com' })
})

const route = createRoute({
  method: 'get',
  path: '/users',
  responses: {
    200: {
      content: {
        'application/json': {
          schema: z.array(UserSchema)
        }
      },
      description: 'Get all users'
    }
  }
})

app.openapi(route, (c) => {
  return c.json([
    { id: '1', name: 'John', email: 'john@example.com' }
  ])
})

// OpenAPI JSON
app.doc('/doc', {
  openapi: '3.0.0',
  info: {
    version: '1.0.0',
    title: 'My API'
  }
})
```

---

## バリデーション

### express-openapi-validator

```bash
npm install express-openapi-validator
```

```typescript
import express from 'express'
import * as OpenApiValidator from 'express-openapi-validator'

const app = express()

app.use(
  OpenApiValidator.middleware({
    apiSpec: './openapi.yaml',
    validateRequests: true,
    validateResponses: true
  })
)

app.get('/users', (req, res) => {
  res.json([{ id: '1', name: 'John' }])
})

// エラーハンドラー
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    error: err.message
  })
})
```

---

## ツール

### Swagger Editor

```bash
# Docker
docker run -p 8080:8080 swaggerapi/swagger-editor

# オンライン
https://editor.swagger.io/
```

### Swagger Codegen

```bash
# CLI
npm install -g @openapitools/openapi-generator-cli

# コード生成
openapi-generator-cli generate -i openapi.yaml -g typescript-axios -o ./client
```

### Postman連携

```
Postman → Import → OpenAPI 3.0 → openapi.yamlをインポート
```

---

## ベストプラクティス

### ✓ 推奨

```yaml
# 詳細な説明
paths:
  /users:
    get:
      summary: Get all users
      description: |
        Returns a list of users with pagination support.
        Requires authentication.
      parameters:
        - name: page
          description: Page number (1-indexed)
          schema:
            type: integer
            minimum: 1
            default: 1

# 例を含める
components:
  schemas:
    User:
      properties:
        id:
          type: string
          example: "123"
        name:
          type: string
          example: "John Doe"

# エラーレスポンス定義
responses:
  '400':
    description: Bad Request
    content:
      application/json:
        schema:
          $ref: '#/components/schemas/Error'
```

### ✗ 避けるべき

```yaml
# 不十分な説明
paths:
  /users:
    get:
      summary: Get users

# 例がない
components:
  schemas:
    User:
      properties:
        id:
          type: string

# エラーレスポンスがない
```

---

## 参考リンク

- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)
- [Swagger Editor](https://editor.swagger.io/)
- [OpenAPI Generator](https://openapi-generator.tech/)
