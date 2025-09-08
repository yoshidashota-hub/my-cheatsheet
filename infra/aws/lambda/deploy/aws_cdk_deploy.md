# AWS CDK Lambda Deploy

## 概要

プログラミング言語で AWS インフラを定義するフレームワーク

## 前提条件

- Node.js または Python
- AWS CLI
- AWS CDK CLI (`npm install -g aws-cdk`)
- Docker（コンテナビルド用）

## 実務レベルのセットアップ

### 1. プロジェクト構造

```project
my-lambda-cdk/
├── bin/
│   └── my-lambda-cdk.ts
├── lib/
│   ├── stacks/
│   │   ├── lambda-stack.ts
│   │   ├── database-stack.ts
│   │   └── monitoring-stack.ts
│   ├── constructs/
│   │   ├── lambda-function.ts
│   │   └── api-gateway.ts
│   └── config/
│       ├── dev.ts
│       ├── staging.ts
│       └── prod.ts
├── lambda/
│   ├── users/
│   │   ├── index.js
│   │   ├── package.json
│   │   └── tests/
│   └── orders/
├── tests/
├── cdk.json
├── cdk.context.json
└── package.json
```

### 2. エントリーポイント（bin/my-lambda-cdk.ts）

```typescript
#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { LambdaStack } from "../lib/stacks/lambda-stack";
import { DatabaseStack } from "../lib/stacks/database-stack";
import { MonitoringStack } from "../lib/stacks/monitoring-stack";
import { getConfig } from "../lib/config";

const app = new cdk.App();

// 環境とステージの取得
const environment = app.node.tryGetContext("environment") || "dev";
const config = getConfig(environment);

// 共通のタグ
const commonTags = {
  Environment: environment,
  Project: "MyLambdaApp",
  Owner: "DevTeam",
  CostCenter: "Engineering",
};

// データベーススタック
const databaseStack = new DatabaseStack(app, `MyApp-Database-${environment}`, {
  env: config.env,
  config: config.database,
  tags: commonTags,
});

// Lambdaスタック
const lambdaStack = new LambdaStack(app, `MyApp-Lambda-${environment}`, {
  env: config.env,
  config: config.lambda,
  userTable: databaseStack.userTable,
  tags: commonTags,
});

// 監視スタック
new MonitoringStack(app, `MyApp-Monitoring-${environment}`, {
  env: config.env,
  lambdaFunctions: lambdaStack.functions,
  tags: commonTags,
});
```

### 3. 設定管理（lib/config/index.ts）

```typescript
export interface Config {
  env: {
    account: string;
    region: string;
  };
  lambda: {
    memorySize: number;
    timeout: number;
    reservedConcurrency?: number;
    logLevel: string;
  };
  database: {
    billingMode: string;
    pointInTimeRecovery: boolean;
  };
  vpc?: {
    vpcId: string;
    subnetIds: string[];
    securityGroupIds: string[];
  };
}

export function getConfig(environment: string): Config {
  switch (environment) {
    case "dev":
      return require("./dev").config;
    case "staging":
      return require("./staging").config;
    case "prod":
      return require("./prod").config;
    default:
      throw new Error(`Unknown environment: ${environment}`);
  }
}
```

### 4. 本番レベル Lambda スタック（lib/stacks/lambda-stack.ts）

```typescript
import * as cdk from "aws-cdk-lib";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as apigateway from "aws-cdk-lib/aws-apigateway";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import * as logs from "aws-cdk-lib/aws-logs";
import * as sqs from "aws-cdk-lib/aws-sqs";
import { Construct } from "constructs";
import { Config } from "../config";

interface LambdaStackProps extends cdk.StackProps {
  config: Config["lambda"];
  userTable: dynamodb.Table;
}

export class LambdaStack extends cdk.Stack {
  public readonly functions: lambda.Function[] = [];
  public readonly api: apigateway.RestApi;

  constructor(scope: Construct, id: string, props: LambdaStackProps) {
    super(scope, id, props);

    // Dead Letter Queue
    const dlq = new sqs.Queue(this, "DeadLetterQueue", {
      queueName: `${id}-dlq`,
      retentionPeriod: cdk.Duration.days(14),
    });

    // Lambda Layer（共通ライブラリ）
    const utilsLayer = new lambda.LayerVersion(this, "UtilsLayer", {
      code: lambda.Code.fromAsset("lambda/layers/utils"),
      compatibleRuntimes: [lambda.Runtime.NODEJS_18_X],
      description: "Shared utilities layer",
    });

    // VPC設定（本番環境の場合）
    const vpcConfig = props.config.vpc
      ? {
          vpc: cdk.aws_ec2.Vpc.fromLookup(this, "ExistingVpc", {
            vpcId: props.config.vpc.vpcId,
          }),
          allowAllOutbound: false,
          securityGroups: props.config.vpc.securityGroupIds.map((sgId, index) =>
            cdk.aws_ec2.SecurityGroup.fromSecurityGroupId(
              this,
              `SG${index}`,
              sgId
            )
          ),
        }
      : undefined;

    // User Management Lambda
    const userFunction = new lambda.Function(this, "UserFunction", {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: "index.handler",
      code: lambda.Code.fromAsset("lambda/users"),
      memorySize: props.config.memorySize,
      timeout: cdk.Duration.seconds(props.config.timeout),
      layers: [utilsLayer],
      tracing: lambda.Tracing.ACTIVE,
      deadLetterQueue: dlq,
      reservedConcurrentExecutions: props.config.reservedConcurrency,
      vpc: vpcConfig?.vpc,
      vpcSubnets: vpcConfig
        ? {
            subnets: props.config.vpc!.subnetIds.map((subnetId, index) =>
              cdk.aws_ec2.Subnet.fromSubnetId(this, `Subnet${index}`, subnetId)
            ),
          }
        : undefined,
      securityGroups: vpcConfig?.securityGroups,
      environment: {
        USER_TABLE: props.userTable.tableName,
        LOG_LEVEL: props.config.logLevel,
        NODE_ENV: this.node.tryGetContext("environment") || "dev",
      },
      logRetention: logs.RetentionDays.ONE_MONTH,
    });

    // DynamoDB権限の付与
    props.userTable.grantReadWriteData(userFunction);

    // Secrets Manager権限
    userFunction.addToRolePolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ["secretsmanager:GetSecretValue"],
        resources: [
          `arn:aws:secretsmanager:${this.region}:${this.account}:secret:${id}/*`,
        ],
      })
    );

    this.functions.push(userFunction);

    // API Gateway
    this.api = new apigateway.RestApi(this, "Api", {
      restApiName: `${id}-api`,
      description: "Lambda API Gateway",
      deployOptions: {
        stageName: this.node.tryGetContext("environment") || "dev",
        tracingEnabled: true,
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: ["Content-Type", "X-Amz-Date", "Authorization"],
      },
    });

    // Cognito Authorizer
    const cognitoUserPool = cdk.aws_cognito.UserPool.fromUserPoolId(
      this,
      "UserPool",
      "us-east-1_XXXXXXXXX"
    );

    const authorizer = new apigateway.CognitoUserPoolsAuthorizer(
      this,
      "Authorizer",
      {
        cognitoUserPools: [cognitoUserPool],
      }
    );

    // API リソースとメソッド
    const usersResource = this.api.root.addResource("users");
    usersResource.addMethod(
      "POST",
      new apigateway.LambdaIntegration(userFunction),
      {
        authorizer,
      }
    );

    const userResource = usersResource.addResource("{id}");
    userResource.addMethod(
      "GET",
      new apigateway.LambdaIntegration(userFunction),
      {
        authorizer,
        requestParameters: {
          "method.request.path.id": true,
        },
      }
    );

    // CloudWatch カスタムメトリクス
    userFunction.addToRolePolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ["cloudwatch:PutMetricData"],
        resources: ["*"],
      })
    );

    // Outputs
    new cdk.CfnOutput(this, "ApiUrl", {
      value: this.api.url,
      description: "API Gateway URL",
    });

    new cdk.CfnOutput(this, "UserFunctionArn", {
      value: userFunction.functionArn,
      description: "User Function ARN",
    });
  }
}
```

### 5. データベーススタック（lib/stacks/database-stack.ts）

```typescript
import * as cdk from "aws-cdk-lib";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import { Construct } from "constructs";
import { Config } from "../config";

interface DatabaseStackProps extends cdk.StackProps {
  config: Config["database"];
}

export class DatabaseStack extends cdk.Stack {
  public readonly userTable: dynamodb.Table;

  constructor(scope: Construct, id: string, props: DatabaseStackProps) {
    super(scope, id, props);

    this.userTable = new dynamodb.Table(this, "UserTable", {
      tableName: `${id}-users`,
      partitionKey: { name: "userId", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "createdAt", type: dynamodb.AttributeType.STRING },
      billingMode:
        props.config.billingMode === "PAY_PER_REQUEST"
          ? dynamodb.BillingMode.PAY_PER_REQUEST
          : dynamodb.BillingMode.PROVISIONED,
      pointInTimeRecovery: props.config.pointInTimeRecovery,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
    });

    // GSI for email lookup
    this.userTable.addGlobalSecondaryIndex({
      indexName: "email-index",
      partitionKey: { name: "email", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // Backup設定
    this.userTable.addGlobalSecondaryIndex({
      indexName: "status-index",
      partitionKey: { name: "status", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "createdAt", type: dynamodb.AttributeType.STRING },
    });

    new cdk.CfnOutput(this, "UserTableName", {
      value: this.userTable.tableName,
      exportName: `${id}-UserTableName`,
    });
  }
}
```

### 6. 監視スタック（lib/stacks/monitoring-stack.ts）

```typescript
import * as cdk from "aws-cdk-lib";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as sns from "aws-cdk-lib/aws-sns";
import * as subscriptions from "aws-cdk-lib/aws-sns-subscriptions";
import { Construct } from "constructs";

interface MonitoringStackProps extends cdk.StackProps {
  lambdaFunctions: lambda.Function[];
}

export class MonitoringStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: MonitoringStackProps) {
    super(scope, id, props);

    // SNS Topic for alerts
    const alertTopic = new sns.Topic(this, "AlertTopic", {
      topicName: `${id}-alerts`,
    });

    alertTopic.addSubscription(
      new subscriptions.EmailSubscription("devops@company.com")
    );

    // CloudWatch Alarms for each function
    props.lambdaFunctions.forEach((func, index) => {
      // Error Rate Alarm
      new cloudwatch.Alarm(this, `ErrorAlarm${index}`, {
        alarmName: `${func.functionName}-errors`,
        metric: func.metricErrors({
          period: cdk.Duration.minutes(5),
        }),
        threshold: 5,
        evaluationPeriods: 2,
        comparisonOperator:
          cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      }).addAlarmAction(new cdk.aws_cloudwatch_actions.SnsAction(alertTopic));

      // Duration Alarm
      new cloudwatch.Alarm(this, `DurationAlarm${index}`, {
        alarmName: `${func.functionName}-duration`,
        metric: func.metricDuration({
          period: cdk.Duration.minutes(5),
        }),
        threshold: 5000, // 5 seconds
        evaluationPeriods: 3,
      }).addAlarmAction(new cdk.aws_cloudwatch_actions.SnsAction(alertTopic));

      // Throttle Alarm
      new cloudwatch.Alarm(this, `ThrottleAlarm${index}`, {
        alarmName: `${func.functionName}-throttles`,
        metric: func.metricThrottles({
          period: cdk.Duration.minutes(5),
        }),
        threshold: 1,
        evaluationPeriods: 1,
      }).addAlarmAction(new cdk.aws_cloudwatch_actions.SnsAction(alertTopic));
    });

    // Custom Dashboard
    const dashboard = new cloudwatch.Dashboard(this, "Dashboard", {
      dashboardName: `${id}-lambda-dashboard`,
    });

    dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: "Lambda Invocations",
        left: props.lambdaFunctions.map((func) => func.metricInvocations()),
      }),
      new cloudwatch.GraphWidget({
        title: "Lambda Errors",
        left: props.lambdaFunctions.map((func) => func.metricErrors()),
      })
    );
  }
}
```

## デプロイ手順

### 1. 環境別デプロイ

```bash
# 依存関係のインストール
npm install

# ビルド
npm run build

# 開発環境デプロイ
cdk deploy --all -c environment=dev

# 本番環境デプロイ（承認付き）
cdk deploy --all -c environment=prod --require-approval=broadening
```

### 2. 単一スタックデプロイ

```bash
# 特定のスタックのみデプロイ
cdk deploy MyApp-Lambda-prod -c environment=prod

# ホットスワップデプロイ（開発時）
cdk deploy --hotswap MyApp-Lambda-dev -c environment=dev
```

## テストとデバッグ

### 1. ユニットテスト（tests/lambda-stack.test.ts）

```typescript
import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";
import { LambdaStack } from "../lib/stacks/lambda-stack";

test("Lambda Function Created", () => {
  const app = new cdk.App();
  const stack = new LambdaStack(app, "TestStack", {
    config: {
      memorySize: 256,
      timeout: 30,
      logLevel: "info",
    },
  });

  const template = Template.fromStack(stack);
  template.hasResourceProperties("AWS::Lambda::Function", {
    Runtime: "nodejs18.x",
    MemorySize: 256,
  });
});
```

### 2. ローカルテスト

```bash
# CDK CLI でテスト
npm test

# SAM CLI との統合
cdk synth --no-staging > template.yaml
sam local start-api -t template.yaml
```

## CI/CD 統合

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy CDK App

on:
  push:
    branches: [main, develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, prod]
        include:
          - environment: dev
            branch: develop
          - environment: prod
            branch: main

    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: us-east-1

      - name: CDK Bootstrap
        run: cdk bootstrap

      - name: CDK Deploy
        run: |
          if [[ "${{ matrix.environment }}" == "prod" ]]; then
            cdk deploy --all -c environment=prod --require-approval=never
          else
            cdk deploy --all -c environment=dev --require-approval=never
          fi
```

## ベストプラクティス

### 1. コスト最適化

```typescript
// 予約済み同時実行の設定
reservedConcurrentExecutions: environment === "prod" ? 100 : undefined;

// オートスケーリング設定
if (environment === "prod") {
  table.autoScaleWriteCapacity({
    minCapacity: 5,
    maxCapacity: 200,
  });
}
```

### 2. セキュリティ

```typescript
// KMS暗号化
const kmsKey = new kms.Key(this, "LambdaKey", {
  description: "Lambda environment variables encryption",
});

const lambdaFunction = new lambda.Function(this, "Function", {
  environmentEncryption: kmsKey,
});
```

## メリット・デメリット

**メリット**: プログラマティック、型安全、IDE 支援、再利用性、テスタブル  
**デメリット**: 学習コストが高い、ビルド時間が長い、TypeScript 必須（推奨）
