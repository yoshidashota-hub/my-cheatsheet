# AWS Secrets Manager / Systems Manager Parameter Store ガイド

AWS Secrets ManagerとSystems Manager Parameter Storeは、機密情報を安全に管理するためのサービスです。

## サービス比較

| 機能 | Secrets Manager | Parameter Store |
|------|----------------|-----------------|
| **料金** | $0.40/シークレット/月 + API呼び出し料金 | 無料（標準パラメータ）、$0.05/月（高度なパラメータ） |
| **自動ローテーション** | ✓ サポート | ✗ サポートなし |
| **バージョン管理** | ✓ 自動 | ✓ 手動 |
| **暗号化** | ✓ KMS必須 | ✓ KMSオプション |
| **クロスアカウントアクセス** | ✓ サポート | ✗ サポートなし |
| **最大サイズ** | 65KB | 4KB（標準）、8KB（高度） |
| **用途** | DB認証情報、APIキー等の機密情報 | 設定値、パラメータ |

## AWS Secrets Manager

### 特徴

- **自動ローテーション**: RDS、Redshift、DocumentDBの認証情報を自動更新
- **バージョン管理**: シークレットの履歴を自動保存
- **きめ細かいアクセス制御**: IAMポリシーで制御
- **監査**: CloudTrailで全操作をログ記録
- **VPCエンドポイント**: プライベートサブネットから安全にアクセス

### AWS CLI でのSecrets Manager操作

#### インストールと認証

```bash
# AWS CLI インストール
brew install awscli

# 認証設定
aws configure
```

#### シークレットの操作

```bash
# シークレット作成
aws secretsmanager create-secret \
  --name production/db/password \
  --description "Production database password" \
  --secret-string "MySecretPassword123"

# JSON形式のシークレット作成
aws secretsmanager create-secret \
  --name production/api/credentials \
  --secret-string '{"username":"admin","password":"MyPass123","api_key":"abc123xyz"}'

# シークレット取得
aws secretsmanager get-secret-value --secret-id production/db/password

# JSON形式で取得（jqで解析）
aws secretsmanager get-secret-value --secret-id production/api/credentials \
  | jq -r '.SecretString | fromjson'

# シークレット更新
aws secretsmanager update-secret \
  --secret-id production/db/password \
  --secret-string "NewSecretPassword456"

# シークレット一覧
aws secretsmanager list-secrets

# シークレット削除（猶予期間付き）
aws secretsmanager delete-secret \
  --secret-id production/db/password \
  --recovery-window-in-days 30

# 即座に削除
aws secretsmanager delete-secret \
  --secret-id production/db/password \
  --force-delete-without-recovery

# 削除のキャンセル（復元）
aws secretsmanager restore-secret --secret-id production/db/password
```

#### ローテーション設定

```bash
# ローテーション設定
aws secretsmanager rotate-secret \
  --secret-id production/db/password \
  --rotation-lambda-arn arn:aws:lambda:ap-northeast-1:123456789012:function:RotateSecret \
  --rotation-rules AutomaticallyAfterDays=30
```

### AWS SDK (JavaScript/TypeScript)

#### インストール

```bash
npm install @aws-sdk/client-secrets-manager
```

#### 基本設定

```typescript
import { SecretsManagerClient } from '@aws-sdk/client-secrets-manager'

const secretsClient = new SecretsManagerClient({
  region: 'ap-northeast-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})
```

#### シークレットの操作

```typescript
import {
  CreateSecretCommand,
  GetSecretValueCommand,
  UpdateSecretCommand,
  DeleteSecretCommand,
  ListSecretsCommand,
  DescribeSecretCommand,
  PutSecretValueCommand,
} from '@aws-sdk/client-secrets-manager'

// シークレット作成
async function createSecret(name: string, value: string, description?: string) {
  const command = new CreateSecretCommand({
    Name: name,
    Description: description,
    SecretString: value,
  })

  const response = await secretsClient.send(command)
  return response.ARN
}

// JSON形式のシークレット作成
async function createJSONSecret(
  name: string,
  data: Record<string, any>,
  description?: string
) {
  const command = new CreateSecretCommand({
    Name: name,
    Description: description,
    SecretString: JSON.stringify(data),
  })

  const response = await secretsClient.send(command)
  return response.ARN
}

// シークレット取得
async function getSecret(secretId: string): Promise<string> {
  const command = new GetSecretValueCommand({
    SecretId: secretId,
  })

  const response = await secretsClient.send(command)
  return response.SecretString || ''
}

// JSON形式のシークレット取得
async function getJSONSecret(secretId: string): Promise<any> {
  const secretString = await getSecret(secretId)
  return JSON.parse(secretString)
}

// シークレット更新
async function updateSecret(secretId: string, newValue: string) {
  const command = new UpdateSecretCommand({
    SecretId: secretId,
    SecretString: newValue,
  })

  const response = await secretsClient.send(command)
  return response.ARN
}

// 新しいバージョンを追加
async function putSecretValue(secretId: string, value: string) {
  const command = new PutSecretValueCommand({
    SecretId: secretId,
    SecretString: value,
  })

  const response = await secretsClient.send(command)
  return response.VersionId
}

// シークレット削除
async function deleteSecret(secretId: string, recoveryDays = 30) {
  const command = new DeleteSecretCommand({
    SecretId: secretId,
    RecoveryWindowInDays: recoveryDays,
  })

  await secretsClient.send(command)
}

// シークレット一覧
async function listSecrets() {
  const command = new ListSecretsCommand({})
  const response = await secretsClient.send(command)
  return response.SecretList || []
}

// シークレット詳細取得
async function describeSecret(secretId: string) {
  const command = new DescribeSecretCommand({
    SecretId: secretId,
  })

  const response = await secretsClient.send(command)
  return response
}
```

#### キャッシュ機能付きシークレット取得

```typescript
// シンプルなキャッシュ実装
class SecretCache {
  private cache = new Map<string, { value: string; expiry: number }>()
  private ttl: number

  constructor(ttlSeconds = 300) {
    this.ttl = ttlSeconds * 1000
  }

  async get(secretId: string): Promise<string> {
    const cached = this.cache.get(secretId)

    if (cached && Date.now() < cached.expiry) {
      return cached.value
    }

    const value = await getSecret(secretId)
    this.cache.set(secretId, {
      value,
      expiry: Date.now() + this.ttl,
    })

    return value
  }

  invalidate(secretId: string) {
    this.cache.delete(secretId)
  }

  clear() {
    this.cache.clear()
  }
}

// 使用例
const cache = new SecretCache(300) // 5分間キャッシュ
const dbPassword = await cache.get('production/db/password')
```

### 実装例

#### Next.js API Route

```typescript
// app/api/db/route.ts
import { NextResponse } from 'next/server'
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'

const client = new SecretsManagerClient({ region: 'ap-northeast-1' })

export async function GET() {
  try {
    const command = new GetSecretValueCommand({
      SecretId: 'production/db/credentials',
    })

    const response = await client.send(command)
    const credentials = JSON.parse(response.SecretString || '{}')

    // データベース接続に使用
    // const db = connectToDatabase(credentials)

    return NextResponse.json({ status: 'ok' })
  } catch (error) {
    console.error('Failed to get secret:', error)
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
```

#### Prismaとの統合

```typescript
// lib/db.ts
import { PrismaClient } from '@prisma/client'
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'

const secretsClient = new SecretsManagerClient({ region: 'ap-northeast-1' })

async function getDatabaseUrl(): Promise<string> {
  const command = new GetSecretValueCommand({
    SecretId: 'production/db/url',
  })

  const response = await secretsClient.send(command)
  return response.SecretString || ''
}

let prisma: PrismaClient

async function getPrismaClient() {
  if (!prisma) {
    const databaseUrl = await getDatabaseUrl()
    prisma = new PrismaClient({
      datasources: {
        db: {
          url: databaseUrl,
        },
      },
    })
  }

  return prisma
}

export { getPrismaClient }
```

#### Lambda関数での使用

```typescript
// lambda/handler.ts
import { Handler } from 'aws-lambda'
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager'

const client = new SecretsManagerClient({ region: process.env.AWS_REGION })
let cachedSecret: string | null = null

export const handler: Handler = async (event) => {
  try {
    // キャッシュから取得
    if (!cachedSecret) {
      const command = new GetSecretValueCommand({
        SecretId: process.env.SECRET_NAME,
      })

      const response = await client.send(command)
      cachedSecret = response.SecretString || ''
    }

    const credentials = JSON.parse(cachedSecret)

    // ビジネスロジック
    // ...

    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Success' }),
    }
  } catch (error) {
    console.error('Error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal error' }),
    }
  }
}
```

## Systems Manager Parameter Store

### 特徴

- **無料（標準パラメータ）**: 4KB以下のパラメータは無料
- **階層構造**: パスベースでパラメータを整理
- **暗号化オプション**: KMSで暗号化可能
- **バージョン管理**: パラメータの履歴を保存
- **パブリックパラメータ**: AWS公式のAMI IDなどを取得可能

### パラメータタイプ

| タイプ | 説明 | 暗号化 | 最大サイズ |
|--------|------|--------|-----------|
| String | プレーンテキスト | ✗ | 4KB |
| StringList | カンマ区切りリスト | ✗ | 4KB |
| SecureString | 暗号化された文字列 | ✓ | 4KB |

### AWS CLI でのParameter Store操作

```bash
# パラメータ作成（String）
aws ssm put-parameter \
  --name "/myapp/config/api_url" \
  --value "https://api.example.com" \
  --type String \
  --description "API endpoint URL"

# パラメータ作成（SecureString）
aws ssm put-parameter \
  --name "/myapp/prod/db/password" \
  --value "MySecretPassword123" \
  --type SecureString \
  --description "Production database password"

# カスタムKMSキーで暗号化
aws ssm put-parameter \
  --name "/myapp/prod/api/key" \
  --value "abc123xyz" \
  --type SecureString \
  --key-id "alias/my-key"

# パラメータ取得
aws ssm get-parameter --name "/myapp/config/api_url"

# 暗号化されたパラメータを復号化して取得
aws ssm get-parameter --name "/myapp/prod/db/password" --with-decryption

# 複数パラメータ取得
aws ssm get-parameters \
  --names "/myapp/config/api_url" "/myapp/config/timeout" \
  --with-decryption

# パス配下の全パラメータ取得
aws ssm get-parameters-by-path \
  --path "/myapp/prod/" \
  --recursive \
  --with-decryption

# パラメータ更新
aws ssm put-parameter \
  --name "/myapp/config/api_url" \
  --value "https://api-v2.example.com" \
  --type String \
  --overwrite

# パラメータ削除
aws ssm delete-parameter --name "/myapp/config/api_url"

# 複数パラメータ削除
aws ssm delete-parameters \
  --names "/myapp/config/api_url" "/myapp/config/timeout"

# パラメータ履歴取得
aws ssm get-parameter-history --name "/myapp/config/api_url"
```

### AWS SDK (JavaScript/TypeScript)

#### インストール

```bash
npm install @aws-sdk/client-ssm
```

#### 基本設定

```typescript
import { SSMClient } from '@aws-sdk/client-ssm'

const ssmClient = new SSMClient({
  region: 'ap-northeast-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})
```

#### パラメータ操作

```typescript
import {
  PutParameterCommand,
  GetParameterCommand,
  GetParametersCommand,
  GetParametersByPathCommand,
  DeleteParameterCommand,
  DeleteParametersCommand,
  GetParameterHistoryCommand,
} from '@aws-sdk/client-ssm'

// パラメータ作成
async function putParameter(
  name: string,
  value: string,
  type: 'String' | 'StringList' | 'SecureString' = 'String',
  description?: string
) {
  const command = new PutParameterCommand({
    Name: name,
    Value: value,
    Type: type,
    Description: description,
    Overwrite: false,
  })

  const response = await ssmClient.send(command)
  return response.Version
}

// パラメータ更新
async function updateParameter(name: string, value: string) {
  const command = new PutParameterCommand({
    Name: name,
    Value: value,
    Overwrite: true,
  })

  const response = await ssmClient.send(command)
  return response.Version
}

// パラメータ取得
async function getParameter(name: string, decrypt = true): Promise<string> {
  const command = new GetParameterCommand({
    Name: name,
    WithDecryption: decrypt,
  })

  const response = await ssmClient.send(command)
  return response.Parameter?.Value || ''
}

// 複数パラメータ取得
async function getParameters(names: string[], decrypt = true) {
  const command = new GetParametersCommand({
    Names: names,
    WithDecryption: decrypt,
  })

  const response = await ssmClient.send(command)
  return response.Parameters || []
}

// パス配下の全パラメータ取得
async function getParametersByPath(path: string, recursive = true, decrypt = true) {
  const command = new GetParametersByPathCommand({
    Path: path,
    Recursive: recursive,
    WithDecryption: decrypt,
  })

  const response = await ssmClient.send(command)
  return response.Parameters || []
}

// パラメータ削除
async function deleteParameter(name: string) {
  const command = new DeleteParameterCommand({
    Name: name,
  })

  await ssmClient.send(command)
}

// 複数パラメータ削除
async function deleteParameters(names: string[]) {
  const command = new DeleteParametersCommand({
    Names: names,
  })

  const response = await ssmClient.send(command)
  return {
    deleted: response.DeletedParameters || [],
    failed: response.InvalidParameters || [],
  }
}

// パラメータ履歴取得
async function getParameterHistory(name: string) {
  const command = new GetParameterHistoryCommand({
    Name: name,
  })

  const response = await ssmClient.send(command)
  return response.Parameters || []
}
```

#### 階層的パラメータ管理

```typescript
// 環境ごとの設定管理
class ParameterStoreConfig {
  private basePath: string

  constructor(environment: string, appName: string) {
    this.basePath = `/${appName}/${environment}`
  }

  async get(key: string): Promise<string> {
    const fullPath = `${this.basePath}/${key}`
    return await getParameter(fullPath)
  }

  async getAll(): Promise<Record<string, string>> {
    const parameters = await getParametersByPath(this.basePath)
    const config: Record<string, string> = {}

    for (const param of parameters) {
      if (param.Name && param.Value) {
        const key = param.Name.replace(`${this.basePath}/`, '')
        config[key] = param.Value
      }
    }

    return config
  }

  async set(key: string, value: string, secure = false) {
    const fullPath = `${this.basePath}/${key}`
    return await putParameter(fullPath, value, secure ? 'SecureString' : 'String')
  }
}

// 使用例
const config = new ParameterStoreConfig('production', 'myapp')
const apiUrl = await config.get('api/url')
const dbPassword = await config.get('db/password')
const allConfig = await config.getAll()
```

### 実装例

#### 環境変数の代替

```typescript
// lib/config.ts
import { SSMClient, GetParametersByPathCommand } from '@aws-sdk/client-ssm'

const ssmClient = new SSMClient({ region: 'ap-northeast-1' })

export async function loadConfig() {
  const environment = process.env.NODE_ENV || 'development'
  const appName = process.env.APP_NAME || 'myapp'

  const command = new GetParametersByPathCommand({
    Path: `/${appName}/${environment}`,
    Recursive: true,
    WithDecryption: true,
  })

  const response = await ssmClient.send(command)
  const config: Record<string, string> = {}

  for (const param of response.Parameters || []) {
    if (param.Name && param.Value) {
      const key = param.Name.split('/').pop()!
      config[key] = param.Value
    }
  }

  return config
}

// 使用例
const config = await loadConfig()
const dbUrl = config.db_url
const apiKey = config.api_key
```

#### Next.js での使用

```typescript
// lib/ssm-config.ts
import { SSMClient, GetParametersCommand } from '@aws-sdk/client-ssm'

const client = new SSMClient({ region: 'ap-northeast-1' })

export async function getAppConfig() {
  const parameterNames = [
    '/myapp/prod/database_url',
    '/myapp/prod/api_key',
    '/myapp/prod/secret_key',
  ]

  const command = new GetParametersCommand({
    Names: parameterNames,
    WithDecryption: true,
  })

  const response = await client.send(command)
  const params = response.Parameters || []

  return {
    databaseUrl: params.find((p) => p.Name?.includes('database_url'))?.Value,
    apiKey: params.find((p) => p.Name?.includes('api_key'))?.Value,
    secretKey: params.find((p) => p.Name?.includes('secret_key'))?.Value,
  }
}
```

## Terraform での管理

### Secrets Manager

```hcl
# シークレット作成
resource "aws_secretsmanager_secret" "db_password" {
  name        = "production/db/password"
  description = "Production database password"

  recovery_window_in_days = 30

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# シークレットの値を設定
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password # 変数から取得
}

# JSON形式のシークレット
resource "aws_secretsmanager_secret" "api_credentials" {
  name = "production/api/credentials"
}

resource "aws_secretsmanager_secret_version" "api_credentials" {
  secret_id = aws_secretsmanager_secret.api_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = var.api_password
    api_key  = var.api_key
  })
}

# ローテーション設定
resource "aws_secretsmanager_secret_rotation" "db_password" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### Parameter Store

```hcl
# 通常のパラメータ
resource "aws_ssm_parameter" "api_url" {
  name        = "/myapp/prod/api/url"
  description = "API endpoint URL"
  type        = "String"
  value       = "https://api.example.com"

  tags = {
    Environment = "production"
  }
}

# 暗号化されたパラメータ
resource "aws_ssm_parameter" "db_password" {
  name        = "/myapp/prod/db/password"
  description = "Database password"
  type        = "SecureString"
  value       = var.db_password

  tags = {
    Environment = "production"
  }
}

# カスタムKMSキーを使用
resource "aws_ssm_parameter" "api_key" {
  name   = "/myapp/prod/api/key"
  type   = "SecureString"
  value  = var.api_key
  key_id = aws_kms_key.main.id
}
```

## Lambda/ECS連携

### Lambda環境変数でシークレットを参照

```hcl
resource "aws_lambda_function" "app" {
  function_name = "my-app"
  role          = aws_iam_role.lambda.arn

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.db_password.arn
    }
  }
}

# IAMロールにSecrets Managerアクセス権限を付与
resource "aws_iam_role_policy" "lambda_secrets" {
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}
```

### ECS Task DefinitionでSecrets Managerを使用

```hcl
resource "aws_ecs_task_definition" "app" {
  family = "my-app"

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "my-app:latest"

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        },
        {
          name      = "API_KEY"
          valueFrom = "${aws_ssm_parameter.api_key.arn}"
        }
      ]
    }
  ])
}

# タスクロールにアクセス権限を付与
resource "aws_iam_role_policy" "ecs_secrets" {
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_ssm_parameter.api_key.arn
        ]
      }
    ]
  })
}
```

## ベストプラクティス

### 1. 適切なサービスの選択

```typescript
// Secrets Manager: 自動ローテーションが必要な機密情報
await createSecret('prod/db/password', dbPassword)
await createSecret('prod/api/key', apiKey)

// Parameter Store: 設定値、変更頻度が低い情報
await putParameter('/myapp/prod/region', 'ap-northeast-1', 'String')
await putParameter('/myapp/prod/timeout', '30', 'String')
```

### 2. 階層的な命名規則

```typescript
// パス構造: /{app}/{environment}/{category}/{name}
const paths = {
  dbPassword: '/myapp/prod/database/password',
  apiKey: '/myapp/prod/api/key',
  redisUrl: '/myapp/prod/cache/redis_url',
  devDbPassword: '/myapp/dev/database/password',
}
```

### 3. キャッシュの活用

```typescript
// Lambda: グローバルスコープでキャッシュ
let cachedSecret: string | null = null

export const handler = async (event: any) => {
  if (!cachedSecret) {
    cachedSecret = await getSecret('prod/db/password')
  }

  // cachedSecretを使用
}
```

### 4. IAMポリシーで最小権限

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:production/*"
      ]
    }
  ]
}
```

### 5. タグ付けによる管理

```typescript
await createSecret('prod/db/password', password, 'DB password')

// タグは別途設定
import { TagResourceCommand } from '@aws-sdk/client-secrets-manager'

const tagCommand = new TagResourceCommand({
  SecretId: secretArn,
  Tags: [
    { Key: 'Environment', Value: 'production' },
    { Key: 'Team', Value: 'backend' },
    { Key: 'ManagedBy', Value: 'terraform' },
  ],
})

await secretsClient.send(tagCommand)
```

## セキュリティ

### 1. VPCエンドポイントの使用

```hcl
# Secrets Manager VPCエンドポイント
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# SSM VPCエンドポイント
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}
```

### 2. KMS暗号化

```typescript
// カスタムKMSキーで暗号化
await putParameter('/myapp/prod/secret', value, 'SecureString')

// KMSキーIDを指定（Terraformで管理推奨）
```

### 3. CloudTrailによる監査

```typescript
// 全てのアクセスがCloudTrailに記録される
// 定期的にログを確認
```

## コスト最適化

### 料金比較

```typescript
// Secrets Manager
// - $0.40/シークレット/月
// - 10,000 APIコール: $0.05

// Parameter Store（標準）
// - 無料（10,000パラメータまで）
// - APIコール: 無料（標準スループット）

// Parameter Store（高度）
// - $0.05/パラメータ/月
// - 高スループットAPIコール: $0.05/10,000コール
```

### コスト削減のヒント

1. **設定値はParameter Store（標準）を使用**
2. **機密情報で自動ローテーションが必要な場合のみSecrets Manager**
3. **キャッシュを活用してAPI呼び出しを削減**
4. **不要なシークレット/パラメータは削除**

## 参考リンク

- [AWS Secrets Manager 公式ドキュメント](https://docs.aws.amazon.com/secretsmanager/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Secrets Manager SDK](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-secrets-manager/)
- [SSM SDK](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ssm/)
- [料金](https://aws.amazon.com/secrets-manager/pricing/)
