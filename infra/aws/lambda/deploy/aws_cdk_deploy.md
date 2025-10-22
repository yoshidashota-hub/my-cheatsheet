# AWS CDK Lambda Deploy

## 概要

プログラミング言語でAWSインフラを定義するフレームワーク。

## 前提条件

- Node.js
- AWS CLI
- AWS CDK CLI (`npm install -g aws-cdk`)

## 基本セットアップ

### bin/app.ts

```typescript
#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib'
import { LambdaStack } from '../lib/lambda-stack'

const app = new cdk.App()

new LambdaStack(app, 'MyLambdaStack-dev', {
  env: { region: 'us-east-1' },
  environment: 'dev',
})
```

### lib/lambda-stack.ts

```typescript
import * as cdk from 'aws-cdk-lib'
import * as lambda from 'aws-cdk-lib/aws-lambda'
import * as apigateway from 'aws-cdk-lib/aws-apigateway'
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb'
import { Construct } from 'constructs'

export class LambdaStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props)

    // DynamoDB Table
    const table = new dynamodb.Table(this, 'UserTable', {
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
    })

    // Lambda Function
    const userFunction = new lambda.Function(this, 'UserFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda/users'),
      memorySize: 256,
      timeout: cdk.Duration.seconds(30),
      environment: {
        USER_TABLE: table.tableName,
      },
      tracing: lambda.Tracing.ACTIVE,
    })

    // DynamoDB権限の付与
    table.grantReadWriteData(userFunction)

    // API Gateway
    const api = new apigateway.RestApi(this, 'Api', {
      restApiName: 'user-api',
    })

    const usersResource = api.root.addResource('users')
    usersResource.addMethod('POST', new apigateway.LambdaIntegration(userFunction))

    // Outputs
    new cdk.CfnOutput(this, 'ApiUrl', {
      value: api.url,
    })
  }
}
```

## デプロイ

```bash
# 依存関係インストール
npm install

# ビルド
npm run build

# 開発環境デプロイ
cdk deploy --all -c environment=dev

# 本番環境デプロイ
cdk deploy --all -c environment=prod --require-approval=broadening

# ホットスワップ（開発時）
cdk deploy --hotswap MyLambdaStack-dev
```

## テスト

```typescript
// tests/lambda-stack.test.ts
import * as cdk from 'aws-cdk-lib'
import { Template } from 'aws-cdk-lib/assertions'
import { LambdaStack } from '../lib/lambda-stack'

test('Lambda Function Created', () => {
  const app = new cdk.App()
  const stack = new LambdaStack(app, 'TestStack')
  const template = Template.fromStack(stack)

  template.hasResourceProperties('AWS::Lambda::Function', {
    Runtime: 'nodejs18.x',
    MemorySize: 256,
  })
})
```

## メリット・デメリット

**メリット**: プログラマティック、型安全、IDE支援、テスタブル
**デメリット**: 学習コスト高、ビルド時間長
