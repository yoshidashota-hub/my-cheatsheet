# AWS API Gateway 完全ガイド

## 目次
- [API Gatewayとは](#api-gatewayとは)
- [REST API vs HTTP API](#rest-api-vs-http-api)
- [HTTP API](#http-api)
- [REST API](#rest-api)
- [認証・認可](#認証認可)
- [CORS設定](#cors設定)
- [リクエスト/レスポンス変換](#リクエストレスポンス変換)
- [レート制限とスロットリング](#レート制限とスロットリング)
- [カスタムドメイン](#カスタムドメイン)
- [WebSocket API](#websocket-api)
- [モニタリング](#モニタリング)
- [ベストプラクティス](#ベストプラクティス)

---

## API Gatewayとは

AWS のフルマネージド API 管理サービス。RESTful API、HTTP API、WebSocket API を構築・公開できる。

### 特徴

- 🌐 完全マネージド: サーバー管理不要
- 📈 自動スケール: トラフィックに応じて自動スケール
- 🔒 セキュリティ: 認証・認可、DDoS保護
- 💰 従量課金: リクエスト数に応じた課金
- 🔄 統合: Lambda, EC2, 外部APIと統合

### ユースケース

```
✓ サーバーレスAPI
✓ マイクロサービスのゲートウェイ
✓ レガシーシステムのAPI化
✓ WebSocketアプリケーション
✓ モバイル/Webアプリのバックエンド
```

---

## REST API vs HTTP API

### 比較表

| 機能 | HTTP API | REST API |
|-----|---------|----------|
| 料金 | 安い | 高い |
| パフォーマンス | 高速 | 標準 |
| リクエスト変換 | 限定的 | 高機能 |
| API Keys | ❌ | ✓ |
| Usage Plans | ❌ | ✓ |
| WAF統合 | ❌ | ✓ |
| JWT認証 | ✓ | カスタム実装 |
| Cognito統合 | ✓ | ✓ |
| Lambda統合 | ✓ | ✓ |

### 選択基準

```
HTTP API を選ぶ場合:
✓ コスト重視
✓ シンプルなAPI
✓ JWT認証のみ
✓ 高パフォーマンス要求

REST API を選ぶ場合:
✓ 高度なリクエスト変換
✓ API Keys / Usage Plans
✓ WAF統合
✓ レガシーシステム統合
```

---

## HTTP API

### Serverless Framework で作成

```yaml
# serverless.yml
service: my-http-api

provider:
  name: aws
  runtime: nodejs18.x
  region: ap-northeast-1

functions:
  getUsers:
    handler: src/functions/users/list.handler
    events:
      - httpApi:
          path: /users
          method: get

  getUser:
    handler: src/functions/users/get.handler
    events:
      - httpApi:
          path: /users/{id}
          method: get

  createUser:
    handler: src/functions/users/create.handler
    events:
      - httpApi:
          path: /users
          method: post

  updateUser:
    handler: src/functions/users/update.handler
    events:
      - httpApi:
          path: /users/{id}
          method: put

  deleteUser:
    handler: src/functions/users/delete.handler
    events:
      - httpApi:
          path: /users/{id}
          method: delete
```

### Lambda 関数実装

```typescript
// src/functions/users/list.ts
import { APIGatewayProxyHandlerV2 } from 'aws-lambda'
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, ScanCommand } from '@aws-sdk/lib-dynamodb'

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}))
const TABLE_NAME = process.env.TABLE_NAME!

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const result = await client.send(new ScanCommand({
      TableName: TABLE_NAME
    }))

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        users: result.Items
      })
    }
  } catch (error) {
    console.error('Error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' })
    }
  }
}
```

```typescript
// src/functions/users/get.ts
import { APIGatewayProxyHandlerV2 } from 'aws-lambda'
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb'

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const userId = event.pathParameters?.id

  if (!userId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: 'User ID is required' })
    }
  }

  try {
    const result = await client.send(new GetCommand({
      TableName: TABLE_NAME,
      Key: {
        PK: `USER#${userId}`,
        SK: 'PROFILE'
      }
    }))

    if (!result.Item) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' })
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify(result.Item)
    }
  } catch (error) {
    console.error('Error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' })
    }
  }
}
```

### CORS設定

```yaml
# serverless.yml
provider:
  httpApi:
    cors:
      allowedOrigins:
        - https://example.com
        - https://app.example.com
      allowedHeaders:
        - Content-Type
        - Authorization
      allowedMethods:
        - GET
        - POST
        - PUT
        - DELETE
      allowCredentials: true
      maxAge: 6000
```

---

## REST API

### Serverless Framework で作成

```yaml
# serverless.yml
service: my-rest-api

provider:
  name: aws
  runtime: nodejs18.x
  region: ap-northeast-1

  apiGateway:
    restApiId: ${ssm:/myapp/api-gateway-id}  # 既存APIを使用
    restApiRootResourceId: ${ssm:/myapp/api-gateway-root-id}

functions:
  getUsers:
    handler: src/functions/users/list.handler
    events:
      - http:
          path: users
          method: get
          cors: true

  createUser:
    handler: src/functions/users/create.handler
    events:
      - http:
          path: users
          method: post
          cors: true
          # リクエストバリデーション
          request:
            schemas:
              application/json: ${file(schemas/user-create.json)}
```

### リクエストバリデーション

```json
// schemas/user-create.json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "User Create Schema",
  "type": "object",
  "properties": {
    "email": {
      "type": "string",
      "format": "email"
    },
    "name": {
      "type": "string",
      "minLength": 2,
      "maxLength": 100
    }
  },
  "required": ["email", "name"]
}
```

### API Keys & Usage Plans

```yaml
# serverless.yml
provider:
  apiGateway:
    apiKeys:
      - name: free-tier
        value: ${env:FREE_TIER_API_KEY}
      - name: premium-tier
        value: ${env:PREMIUM_TIER_API_KEY}

    usagePlan:
      - free:
          quota:
            limit: 1000
            period: MONTH
          throttle:
            rateLimit: 10
            burstLimit: 20
      - premium:
          quota:
            limit: 10000
            period: MONTH
          throttle:
            rateLimit: 100
            burstLimit: 200

functions:
  publicApi:
    handler: handler.public
    events:
      - http:
          path: public
          method: get

  privateApi:
    handler: handler.private
    events:
      - http:
          path: private
          method: get
          private: true  # API Key必須
```

---

## 認証・認可

### JWT認証（HTTP API）

```yaml
# serverless.yml
provider:
  httpApi:
    authorizers:
      jwtAuthorizer:
        type: jwt
        identitySource: $request.header.Authorization
        issuerUrl: https://cognito-idp.ap-northeast-1.amazonaws.com/${self:custom.userPoolId}
        audience:
          - ${self:custom.userPoolClientId}

functions:
  protectedApi:
    handler: handler.main
    events:
      - httpApi:
          path: /protected
          method: get
          authorizer:
            name: jwtAuthorizer
```

### Lambda オーソライザー

```typescript
// src/authorizers/custom.ts
import { APIGatewayAuthorizerResult, APIGatewayTokenAuthorizerEvent } from 'aws-lambda'
import jwt from 'jsonwebtoken'

export const handler = async (
  event: APIGatewayTokenAuthorizerEvent
): Promise<APIGatewayAuthorizerResult> => {
  const token = event.authorizationToken.replace('Bearer ', '')

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!)

    return {
      principalId: decoded.sub,
      policyDocument: {
        Version: '2012-10-17',
        Statement: [
          {
            Action: 'execute-api:Invoke',
            Effect: 'Allow',
            Resource: event.methodArn
          }
        ]
      },
      context: {
        userId: decoded.sub,
        email: decoded.email
      }
    }
  } catch (error) {
    throw new Error('Unauthorized')
  }
}
```

```yaml
# serverless.yml
functions:
  customAuthorizer:
    handler: src/authorizers/custom.handler

  protectedApi:
    handler: handler.main
    events:
      - http:
          path: protected
          method: get
          authorizer:
            name: customAuthorizer
            resultTtlInSeconds: 300
            identitySource: method.request.header.Authorization
```

### Cognito オーソライザー

```yaml
# serverless.yml
provider:
  httpApi:
    authorizers:
      cognitoAuthorizer:
        type: jwt
        identitySource: $request.header.Authorization
        issuerUrl: https://cognito-idp.${self:provider.region}.amazonaws.com/${self:custom.userPoolId}
        audience:
          - ${self:custom.userPoolClientId}

functions:
  protectedApi:
    handler: handler.main
    events:
      - httpApi:
          path: /protected
          method: get
          authorizer:
            name: cognitoAuthorizer
            scopes:
              - email
              - profile
```

### Lambda関数内で認証情報取得

```typescript
// src/functions/protected.ts
import { APIGatewayProxyHandlerV2 } from 'aws-lambda'

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  // JWT認証の場合
  const userId = event.requestContext.authorizer?.jwt.claims.sub
  const email = event.requestContext.authorizer?.jwt.claims.email

  // Lambdaオーソライザーの場合
  const userIdFromContext = event.requestContext.authorizer?.userId

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Protected resource',
      userId,
      email
    })
  }
}
```

---

## CORS設定

### HTTP API の CORS

```yaml
# serverless.yml
provider:
  httpApi:
    cors:
      allowedOrigins:
        - https://example.com
      allowedHeaders:
        - Content-Type
        - Authorization
        - X-Api-Key
      allowedMethods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
      allowCredentials: true
      exposedResponseHeaders:
        - X-Request-Id
      maxAge: 6000
```

### REST API の CORS

```yaml
# serverless.yml（簡易版）
functions:
  api:
    handler: handler.main
    events:
      - http:
          path: api
          method: any
          cors: true
```

```yaml
# serverless.yml（詳細版）
functions:
  api:
    handler: handler.main
    events:
      - http:
          path: api
          method: any
          cors:
            origin: 'https://example.com'
            headers:
              - Content-Type
              - Authorization
            allowCredentials: true
```

### Lambda関数でCORS設定

```typescript
// ヘッダーに追加
export const handler = async (event: any) => {
  return {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    },
    body: JSON.stringify({ message: 'Success' })
  }
}
```

---

## リクエスト/レスポンス変換

### リクエストマッピング

```yaml
# serverless.yml
functions:
  legacy:
    handler: handler.main
    events:
      - http:
          path: legacy
          method: post
          integration: lambda
          request:
            template:
              application/json: |
                {
                  "body": $input.json('$'),
                  "method": "$context.httpMethod",
                  "headers": {
                    #foreach($header in $input.params().header.keySet())
                    "$header": "$util.escapeJavaScript($input.params().header.get($header))"
                    #if($foreach.hasNext),#end
                    #end
                  }
                }
```

### レスポンスマッピング

```yaml
# serverless.yml
functions:
  api:
    handler: handler.main
    events:
      - http:
          path: api
          method: get
          integration: lambda
          response:
            headers:
              Content-Type: "'application/json'"
            template: $input.path('$.body')
```

---

## レート制限とスロットリング

### Usage Plans（REST API）

```yaml
# serverless.yml
provider:
  apiGateway:
    usagePlan:
      - basic:
          quota:
            limit: 1000        # 月間リクエスト数
            period: MONTH
          throttle:
            rateLimit: 10      # 秒間リクエスト数
            burstLimit: 20     # バーストリクエスト数
```

### アカウントレベルのスロットリング

```bash
# AWS CLI でアカウント設定
aws apigateway update-account \
  --patch-operations \
    op=replace,path=/throttle/rateLimit,value=1000 \
    op=replace,path=/throttle/burstLimit,value=2000
```

### ステージレベルのスロットリング

```yaml
# serverless.yml
provider:
  apiGateway:
    throttle:
      rateLimit: 100
      burstLimit: 200
```

### メソッドレベルのスロットリング

```yaml
# serverless.yml
functions:
  expensiveOperation:
    handler: handler.main
    events:
      - http:
          path: expensive
          method: post
          throttle:
            rateLimit: 10
            burstLimit: 20
```

---

## カスタムドメイン

### Route53 + ACM + API Gateway

```yaml
# serverless.yml
plugins:
  - serverless-domain-manager

custom:
  customDomain:
    domainName: api.example.com
    basePath: ''
    stage: ${self:provider.stage}
    createRoute53Record: true
    certificateName: '*.example.com'
    endpointType: 'regional'
    securityPolicy: tls_1_2
    apiType: rest
```

```bash
# カスタムドメイン作成
serverless create_domain

# デプロイ
serverless deploy

# ドメイン削除
serverless delete_domain
```

### マッピング設定

```yaml
custom:
  customDomain:
    domainName: api.example.com
    basePath: v1         # https://api.example.com/v1/...
    stage: prod
```

---

## WebSocket API

### WebSocket API 作成

```yaml
# serverless.yml
service: websocket-api

provider:
  name: aws
  runtime: nodejs18.x
  region: ap-northeast-1

  environment:
    CONNECTIONS_TABLE: ${self:service}-${self:provider.stage}-connections

  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:PutItem
            - dynamodb:GetItem
            - dynamodb:DeleteItem
            - dynamodb:Scan
          Resource:
            - Fn::GetAtt: [ConnectionsTable, Arn]
        - Effect: Allow
          Action:
            - execute-api:ManageConnections
          Resource:
            - arn:aws:execute-api:*:*:**/@connections/*

functions:
  connectionHandler:
    handler: src/handlers/connection.handler
    events:
      - websocket:
          route: $connect
      - websocket:
          route: $disconnect

  defaultHandler:
    handler: src/handlers/default.handler
    events:
      - websocket:
          route: $default

  messageHandler:
    handler: src/handlers/message.handler
    events:
      - websocket:
          route: sendMessage

resources:
  Resources:
    ConnectionsTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:provider.environment.CONNECTIONS_TABLE}
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: connectionId
            AttributeType: S
        KeySchema:
          - AttributeName: connectionId
            KeyType: HASH
        TimeToLiveSpecification:
          AttributeName: ttl
          Enabled: true
```

### WebSocket ハンドラー実装

```typescript
// src/handlers/connection.ts
import { APIGatewayProxyHandler } from 'aws-lambda'
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, PutCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb'

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}))
const TABLE_NAME = process.env.CONNECTIONS_TABLE!

export const handler: APIGatewayProxyHandler = async (event) => {
  const connectionId = event.requestContext.connectionId!
  const eventType = event.requestContext.eventType

  if (eventType === 'CONNECT') {
    // 接続保存
    await client.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        connectionId,
        connectedAt: new Date().toISOString(),
        ttl: Math.floor(Date.now() / 1000) + 86400 // 24時間後に削除
      }
    }))

    return { statusCode: 200, body: 'Connected' }
  }

  if (eventType === 'DISCONNECT') {
    // 接続削除
    await client.send(new DeleteCommand({
      TableName: TABLE_NAME,
      Key: { connectionId }
    }))

    return { statusCode: 200, body: 'Disconnected' }
  }

  return { statusCode: 200, body: 'OK' }
}
```

```typescript
// src/handlers/message.ts
import { APIGatewayProxyHandler } from 'aws-lambda'
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi'
import { DynamoDBDocumentClient, ScanCommand } from '@aws-sdk/lib-dynamodb'

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}))
const TABLE_NAME = process.env.CONNECTIONS_TABLE!

export const handler: APIGatewayProxyHandler = async (event) => {
  const connectionId = event.requestContext.connectionId!
  const body = JSON.parse(event.body || '{}')

  // API Gateway Management API クライアント
  const apiGatewayClient = new ApiGatewayManagementApiClient({
    endpoint: `https://${event.requestContext.domainName}/${event.requestContext.stage}`
  })

  // 全接続取得
  const connections = await dynamoClient.send(new ScanCommand({
    TableName: TABLE_NAME
  }))

  // 全接続にブロードキャスト
  const postCalls = connections.Items?.map(async ({ connectionId: connId }) => {
    try {
      await apiGatewayClient.send(new PostToConnectionCommand({
        ConnectionId: connId,
        Data: JSON.stringify({
          type: 'message',
          from: connectionId,
          message: body.message
        })
      }))
    } catch (error) {
      console.error(`Failed to send to ${connId}:`, error)
    }
  })

  await Promise.all(postCalls || [])

  return { statusCode: 200, body: 'Message sent' }
}
```

### WebSocket クライアント

```typescript
// クライアント側
const ws = new WebSocket('wss://your-api-id.execute-api.ap-northeast-1.amazonaws.com/dev')

ws.onopen = () => {
  console.log('Connected')

  // メッセージ送信
  ws.send(JSON.stringify({
    action: 'sendMessage',
    message: 'Hello, WebSocket!'
  }))
}

ws.onmessage = (event) => {
  const data = JSON.parse(event.data)
  console.log('Received:', data)
}

ws.onerror = (error) => {
  console.error('WebSocket error:', error)
}

ws.onclose = () => {
  console.log('Disconnected')
}
```

---

## モニタリング

### CloudWatch メトリクス

```
主要メトリクス:
- Count: リクエスト数
- IntegrationLatency: バックエンド処理時間
- Latency: 総レスポンス時間
- 4XXError: クライアントエラー
- 5XXError: サーバーエラー
```

### CloudWatch Logs

```yaml
# serverless.yml
provider:
  logs:
    restApi:
      accessLogging: true
      executionLogging: true
      level: INFO
      fullRequestResponse: true

  httpApi:
    accessLogging: true
```

### X-Ray トレーシング

```yaml
# serverless.yml
provider:
  tracing:
    apiGateway: true
    lambda: true

functions:
  api:
    handler: handler.main
    tracing: Active
```

---

## ベストプラクティス

### 1. API設計

```
✓ RESTful な URL 設計
✓ 適切な HTTP メソッド使用
✓ バージョニング（/v1/users）
✓ ページネーション対応
✓ レスポンス形式統一
```

### 2. エラーハンドリング

```typescript
// 統一エラーレスポンス
interface ErrorResponse {
  error: {
    code: string
    message: string
    details?: any
  }
}

export const errorResponse = (statusCode: number, code: string, message: string) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
  },
  body: JSON.stringify({
    error: { code, message }
  })
})

// 使用例
return errorResponse(404, 'USER_NOT_FOUND', 'User not found')
return errorResponse(400, 'INVALID_REQUEST', 'Email is required')
```

### 3. レスポンスキャッシング

```yaml
# serverless.yml
functions:
  getUsers:
    handler: handler.getUsers
    events:
      - http:
          path: users
          method: get
          caching:
            enabled: true
            ttlInSeconds: 300  # 5分間キャッシュ
```

### 4. リクエストサイズ制限

```yaml
# serverless.yml（デフォルト10MB）
provider:
  apiGateway:
    minimumCompressionSize: 1024  # 1KB以上を圧縮
```

### 5. ステージ変数

```yaml
# serverless.yml
provider:
  stage: ${opt:stage, 'dev'}
  environment:
    LAMBDA_ENDPOINT: ${self:custom.lambdaEndpoints.${self:provider.stage}}

custom:
  lambdaEndpoints:
    dev: https://dev-api.example.com
    prod: https://api.example.com
```

### 6. APIドキュメント生成

```bash
# OpenAPI 仕様書エクスポート
aws apigateway get-export \
  --rest-api-id your-api-id \
  --stage-name prod \
  --export-type swagger \
  --accepts application/json \
  output.json
```

---

## 参考リンク

- [AWS API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [HTTP APIs vs REST APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html)
- [WebSocket APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api.html)
