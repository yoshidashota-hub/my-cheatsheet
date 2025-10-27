# AWS CloudFormation ガイド

AWS CloudFormationは、インフラをコードとして管理するAWS公式のIaC（Infrastructure as Code）サービスです。

## 特徴

- **宣言的**: 望ましい状態をテンプレートで定義
- **AWSネイティブ**: AWS公式サービスで完全統合
- **スタック管理**: リソースをスタック単位で一括管理
- **変更セット**: 変更内容を事前にプレビュー
- **ロールバック**: エラー時に自動ロールバック
- **ドリフト検出**: 実際の状態とテンプレートの差分を検出
- **無料**: CloudFormation自体は無料（作成したリソースのみ課金）

## Terraform との比較

| 機能 | CloudFormation | Terraform |
|------|---------------|-----------|
| **対応プロバイダ** | AWS専用 | マルチクラウド |
| **言語** | JSON/YAML | HCL |
| **状態管理** | AWS側で管理 | ファイルまたはリモートバックエンド |
| **プラン機能** | 変更セット | terraform plan |
| **料金** | 無料 | 無料（Terraform Cloud除く） |
| **エコシステム** | AWS統合 | 豊富なプラグイン |

## 基本概念

### テンプレート (Template)

- JSON または YAML 形式のファイル
- インフラのリソースと設定を定義
- パラメータ、マッピング、条件、出力を含む

### スタック (Stack)

- テンプレートから作成されたリソースの集合
- 1つの単位として作成・更新・削除
- スタック名でリソースを識別

### 変更セット (Change Set)

- スタック更新前の変更内容をプレビュー
- リソースの追加、更新、削除を確認
- 実行前に変更の影響を把握可能

### ドリフト検出 (Drift Detection)

- テンプレートと実際のリソース状態の差異を検出
- 手動変更されたリソースを特定
- インフラの一貫性を確保

## テンプレートの基本構造

### 最小テンプレート (YAML)

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Simple S3 bucket template'

Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: my-example-bucket-12345
```

### 完全なテンプレート構造

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Complete template example'

# パラメータ: 実行時に値を入力
Parameters:
  EnvironmentName:
    Type: String
    Default: development
    AllowedValues:
      - development
      - staging
      - production
    Description: Environment name

  InstanceType:
    Type: String
    Default: t3.micro
    Description: EC2 instance type

# マッピング: 条件に応じた値の定義
Mappings:
  RegionMap:
    us-east-1:
      AMI: ami-0c55b159cbfafe1f0
    ap-northeast-1:
      AMI: ami-0c3fd0f5d33134a76

# 条件: リソース作成の条件分岐
Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, production]
  CreateBackup: !Equals [!Ref EnvironmentName, production]

# リソース: 作成するAWSリソース
Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${EnvironmentName}-bucket-${AWS::AccountId}'
      VersioningConfiguration:
        Status: !If [IsProduction, Enabled, Suspended]
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

# 出力: スタック作成後に表示する値
Outputs:
  BucketName:
    Description: Name of the S3 bucket
    Value: !Ref MyBucket
    Export:
      Name: !Sub '${AWS::StackName}-BucketName'

  BucketArn:
    Description: ARN of the S3 bucket
    Value: !GetAtt MyBucket.Arn
```

## 組み込み関数

### Ref（参照）

```yaml
Parameters:
  BucketName:
    Type: String

Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName  # パラメータを参照
```

### GetAtt（属性取得）

```yaml
Resources:
  MyBucket:
    Type: AWS::S3::Bucket

  MyBucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref MyBucket
      PolicyDocument:
        Statement:
          - Effect: Allow
            Principal: '*'
            Action: 's3:GetObject'
            Resource: !Sub '${MyBucket.Arn}/*'  # GetAttの代替構文
```

### Sub（文字列置換）

```yaml
Resources:
  MyTopic:
    Type: AWS::SNS::Topic
    Properties:
      DisplayName: !Sub '${EnvironmentName}-notifications'
      TopicName: !Sub 'alerts-${AWS::Region}-${AWS::AccountId}'
```

### Join（文字列結合）

```yaml
Resources:
  MyInstance:
    Type: AWS::EC2::Instance
    Properties:
      UserData:
        Fn::Base64: !Join
          - ''
          - - '#!/bin/bash\n'
            - 'echo "Hello, '
            - !Ref EnvironmentName
            - '"\n'
```

### If（条件分岐）

```yaml
Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, production]

Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      VersioningConfiguration:
        Status: !If [IsProduction, Enabled, Suspended]
```

### Select（リストから選択）

```yaml
Parameters:
  SubnetIds:
    Type: List<AWS::EC2::Subnet::Id>

Resources:
  MyInstance:
    Type: AWS::EC2::Instance
    Properties:
      SubnetId: !Select [0, !Ref SubnetIds]  # 最初のサブネットを選択
```

## AWS CLI でのCloudFormation操作

### インストールと認証

```bash
# AWS CLI インストール
brew install awscli

# 認証設定
aws configure
```

### スタック操作

```bash
# テンプレート検証
aws cloudformation validate-template --template-body file://template.yaml

# スタック作成
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://template.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=production

# パラメータファイルを使用
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://template.yaml \
  --parameters file://parameters.json

# スタック一覧
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE

# スタック詳細
aws cloudformation describe-stacks --stack-name my-stack

# スタック更新
aws cloudformation update-stack \
  --stack-name my-stack \
  --template-body file://template.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=staging

# スタック削除
aws cloudformation delete-stack --stack-name my-stack

# スタック削除待機
aws cloudformation wait stack-delete-complete --stack-name my-stack
```

### 変更セット

```bash
# 変更セット作成
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name my-changes \
  --template-body file://template.yaml

# 変更セット詳細確認
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-changes

# 変更セット実行
aws cloudformation execute-change-set \
  --stack-name my-stack \
  --change-set-name my-changes

# 変更セット削除
aws cloudformation delete-change-set \
  --stack-name my-stack \
  --change-set-name my-changes
```

### ドリフト検出

```bash
# ドリフト検出開始
aws cloudformation detect-stack-drift --stack-name my-stack

# ドリフトステータス確認
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id <detection-id>

# ドリフトした各リソースの詳細
aws cloudformation describe-stack-resource-drifts --stack-name my-stack
```

### スタックイベント監視

```bash
# スタックイベント表示
aws cloudformation describe-stack-events --stack-name my-stack

# リアルタイム監視
watch -n 5 "aws cloudformation describe-stack-events --stack-name my-stack --max-items 10"
```

## AWS SDK (JavaScript/TypeScript)

### インストール

```bash
npm install @aws-sdk/client-cloudformation
```

### 基本設定

```typescript
import { CloudFormationClient } from '@aws-sdk/client-cloudformation'

const cfnClient = new CloudFormationClient({
  region: 'ap-northeast-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})
```

### スタック操作

```typescript
import {
  CreateStackCommand,
  UpdateStackCommand,
  DeleteStackCommand,
  DescribeStacksCommand,
  ListStacksCommand,
  ValidateTemplateCommand,
  type Parameter,
} from '@aws-sdk/client-cloudformation'
import { readFileSync } from 'fs'

// テンプレート検証
async function validateTemplate(templatePath: string) {
  const templateBody = readFileSync(templatePath, 'utf-8')

  const command = new ValidateTemplateCommand({
    TemplateBody: templateBody,
  })

  const response = await cfnClient.send(command)
  return response
}

// スタック作成
async function createStack(
  stackName: string,
  templatePath: string,
  parameters?: Parameter[]
) {
  const templateBody = readFileSync(templatePath, 'utf-8')

  const command = new CreateStackCommand({
    StackName: stackName,
    TemplateBody: templateBody,
    Parameters: parameters,
    Capabilities: ['CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM'],
    Tags: [
      { Key: 'ManagedBy', Value: 'cloudformation' },
      { Key: 'CreatedAt', Value: new Date().toISOString() },
    ],
  })

  const response = await cfnClient.send(command)
  return response.StackId
}

// スタック更新
async function updateStack(
  stackName: string,
  templatePath: string,
  parameters?: Parameter[]
) {
  const templateBody = readFileSync(templatePath, 'utf-8')

  const command = new UpdateStackCommand({
    StackName: stackName,
    TemplateBody: templateBody,
    Parameters: parameters,
    Capabilities: ['CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM'],
  })

  const response = await cfnClient.send(command)
  return response.StackId
}

// スタック削除
async function deleteStack(stackName: string) {
  const command = new DeleteStackCommand({
    StackName: stackName,
  })

  await cfnClient.send(command)
}

// スタック詳細取得
async function describeStack(stackName: string) {
  const command = new DescribeStacksCommand({
    StackName: stackName,
  })

  const response = await cfnClient.send(command)
  return response.Stacks?.[0]
}

// スタック一覧取得
async function listStacks(statusFilter?: string[]) {
  const command = new ListStacksCommand({
    StackStatusFilter: statusFilter,
  })

  const response = await cfnClient.send(command)
  return response.StackSummaries || []
}

// スタック完了まで待機
async function waitForStackComplete(stackName: string) {
  while (true) {
    const stack = await describeStack(stackName)
    const status = stack?.StackStatus

    if (status?.includes('COMPLETE')) {
      return true
    } else if (status?.includes('FAILED') || status?.includes('ROLLBACK')) {
      throw new Error(`Stack operation failed: ${status}`)
    }

    await new Promise((resolve) => setTimeout(resolve, 10000))
  }
}
```

### 変更セット操作

```typescript
import {
  CreateChangeSetCommand,
  DescribeChangeSetCommand,
  ExecuteChangeSetCommand,
  DeleteChangeSetCommand,
} from '@aws-sdk/client-cloudformation'

// 変更セット作成
async function createChangeSet(
  stackName: string,
  changeSetName: string,
  templatePath: string,
  parameters?: Parameter[]
) {
  const templateBody = readFileSync(templatePath, 'utf-8')

  const command = new CreateChangeSetCommand({
    StackName: stackName,
    ChangeSetName: changeSetName,
    TemplateBody: templateBody,
    Parameters: parameters,
    Capabilities: ['CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM'],
  })

  const response = await cfnClient.send(command)
  return response.Id
}

// 変更セット詳細取得
async function describeChangeSet(stackName: string, changeSetName: string) {
  const command = new DescribeChangeSetCommand({
    StackName: stackName,
    ChangeSetName: changeSetName,
  })

  const response = await cfnClient.send(command)
  return response
}

// 変更セット実行
async function executeChangeSet(stackName: string, changeSetName: string) {
  const command = new ExecuteChangeSetCommand({
    StackName: stackName,
    ChangeSetName: changeSetName,
  })

  await cfnClient.send(command)
}

// 変更セット削除
async function deleteChangeSet(stackName: string, changeSetName: string) {
  const command = new DeleteChangeSetCommand({
    StackName: stackName,
    ChangeSetName: changeSetName,
  })

  await cfnClient.send(command)
}
```

### ドリフト検出

```typescript
import {
  DetectStackDriftCommand,
  DescribeStackDriftDetectionStatusCommand,
  DescribeStackResourceDriftsCommand,
} from '@aws-sdk/client-cloudformation'

// ドリフト検出開始
async function detectStackDrift(stackName: string) {
  const command = new DetectStackDriftCommand({
    StackName: stackName,
  })

  const response = await cfnClient.send(command)
  return response.StackDriftDetectionId
}

// ドリフト検出ステータス確認
async function getDriftDetectionStatus(detectionId: string) {
  const command = new DescribeStackDriftDetectionStatusCommand({
    StackDriftDetectionId: detectionId,
  })

  const response = await cfnClient.send(command)
  return response
}

// ドリフトしたリソース一覧
async function getStackResourceDrifts(stackName: string) {
  const command = new DescribeStackResourceDriftsCommand({
    StackName: stackName,
  })

  const response = await cfnClient.send(command)
  return response.StackResourceDrifts || []
}

// ドリフト検出完了待機
async function waitForDriftDetection(detectionId: string) {
  while (true) {
    const status = await getDriftDetectionStatus(detectionId)

    if (status.DetectionStatus === 'DETECTION_COMPLETE') {
      return status.StackDriftStatus
    } else if (status.DetectionStatus === 'DETECTION_FAILED') {
      throw new Error('Drift detection failed')
    }

    await new Promise((resolve) => setTimeout(resolve, 5000))
  }
}
```

## テンプレート例

### VPC + サブネット

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'VPC with public and private subnets'

Parameters:
  VpcCidr:
    Type: String
    Default: 10.0.0.0/16

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${AWS::StackName}-vpc'

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${AWS::StackName}-public-subnet'

  PrivateSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.11.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${AWS::StackName}-private-subnet'

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${AWS::StackName}-igw'

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${AWS::StackName}-public-rt'

  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  SubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet
      RouteTableId: !Ref PublicRouteTable

Outputs:
  VpcId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub '${AWS::StackName}-VpcId'

  PublicSubnetId:
    Description: Public Subnet ID
    Value: !Ref PublicSubnet
    Export:
      Name: !Sub '${AWS::StackName}-PublicSubnetId'
```

### Lambda + API Gateway

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Lambda function with API Gateway'

Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  MyLambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${AWS::StackName}-function'
      Runtime: nodejs20.x
      Handler: index.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          exports.handler = async (event) => {
            return {
              statusCode: 200,
              body: JSON.stringify({ message: 'Hello from Lambda!' })
            }
          }

  ApiGateway:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: !Sub '${AWS::StackName}-api'
      ProtocolType: HTTP

  ApiIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref ApiGateway
      IntegrationType: AWS_PROXY
      IntegrationUri: !GetAtt MyLambdaFunction.Arn
      PayloadFormatVersion: '2.0'

  ApiRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref ApiGateway
      RouteKey: 'GET /hello'
      Target: !Sub 'integrations/${ApiIntegration}'

  ApiStage:
    Type: AWS::ApiGatewayV2::Stage
    Properties:
      ApiId: !Ref ApiGateway
      StageName: '$default'
      AutoDeploy: true

  LambdaPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref MyLambdaFunction
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ApiGateway}/*'

Outputs:
  ApiUrl:
    Description: API Gateway URL
    Value: !Sub 'https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/hello'
```

### S3 + CloudFront

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'S3 bucket with CloudFront distribution'

Resources:
  S3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${AWS::StackName}-bucket-${AWS::AccountId}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

  BucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref S3Bucket
      PolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              Service: cloudfront.amazonaws.com
            Action: s3:GetObject
            Resource: !Sub '${S3Bucket.Arn}/*'
            Condition:
              StringEquals:
                AWS:SourceArn: !Sub 'arn:aws:cloudfront::${AWS::AccountId}:distribution/${CloudFrontDistribution}'

  OriginAccessControl:
    Type: AWS::CloudFront::OriginAccessControl
    Properties:
      OriginAccessControlConfig:
        Name: !Sub '${AWS::StackName}-oac'
        OriginAccessControlOriginType: s3
        SigningBehavior: always
        SigningProtocol: sigv4

  CloudFrontDistribution:
    Type: AWS::CloudFront::Distribution
    Properties:
      DistributionConfig:
        Enabled: true
        DefaultRootObject: index.html
        Origins:
          - Id: S3Origin
            DomainName: !GetAtt S3Bucket.RegionalDomainName
            OriginAccessControlId: !Ref OriginAccessControl
            S3OriginConfig: {}
        DefaultCacheBehavior:
          TargetOriginId: S3Origin
          ViewerProtocolPolicy: redirect-to-https
          AllowedMethods:
            - GET
            - HEAD
            - OPTIONS
          CachedMethods:
            - GET
            - HEAD
          ForwardedValues:
            QueryString: false
            Cookies:
              Forward: none
          MinTTL: 0
          DefaultTTL: 86400
          MaxTTL: 31536000

Outputs:
  BucketName:
    Value: !Ref S3Bucket

  DistributionDomain:
    Value: !GetAtt CloudFrontDistribution.DomainName

  DistributionUrl:
    Value: !Sub 'https://${CloudFrontDistribution.DomainName}'
```

## ネストスタック

### 親スタック

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Parent stack with nested stacks'

Resources:
  NetworkStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: https://s3.amazonaws.com/my-templates/network.yaml
      Parameters:
        VpcCidr: 10.0.0.0/16

  AppStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: NetworkStack
    Properties:
      TemplateURL: https://s3.amazonaws.com/my-templates/app.yaml
      Parameters:
        VpcId: !GetAtt NetworkStack.Outputs.VpcId
        SubnetId: !GetAtt NetworkStack.Outputs.PublicSubnetId

Outputs:
  VpcId:
    Value: !GetAtt NetworkStack.Outputs.VpcId

  AppUrl:
    Value: !GetAtt AppStack.Outputs.ApplicationUrl
```

## ベストプラクティス

### 1. パラメータの活用

```yaml
Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
    Default: dev

  InstanceType:
    Type: String
    Default: t3.micro
    AllowedValues:
      - t3.micro
      - t3.small
      - t3.medium
```

### 2. 条件分岐

```yaml
Conditions:
  IsProduction: !Equals [!Ref Environment, prod]
  CreateBackup: !And
    - !Equals [!Ref Environment, prod]
    - !Equals [!Ref EnableBackup, 'true']

Resources:
  Bucket:
    Type: AWS::S3::Bucket
    Properties:
      VersioningConfiguration:
        Status: !If [IsProduction, Enabled, Suspended]
```

### 3. エクスポート/インポート

```yaml
# スタックA
Outputs:
  VpcId:
    Value: !Ref VPC
    Export:
      Name: !Sub '${AWS::StackName}-VpcId'

# スタックB
Resources:
  SecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      VpcId: !ImportValue NetworkStack-VpcId
```

### 4. DeletionPolicy

```yaml
Resources:
  Database:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Snapshot  # スタック削除時にスナップショット作成
    Properties:
      # ...

  Logs:
    Type: AWS::Logs::LogGroup
    DeletionPolicy: Retain  # スタック削除後も保持
```

### 5. UpdateReplacePolicy

```yaml
Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    UpdateReplacePolicy: Retain  # 更新で置換が必要な場合は保持
    DeletionPolicy: Retain
```

## トラブルシューティング

### スタック作成失敗時のロールバック無効化

```bash
# ロールバックを無効にして作成（デバッグ用）
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://template.yaml \
  --on-failure DO_NOTHING
```

### スタックイベントの確認

```typescript
import { DescribeStackEventsCommand } from '@aws-sdk/client-cloudformation'

async function getStackEvents(stackName: string) {
  const command = new DescribeStackEventsCommand({
    StackName: stackName,
  })

  const response = await cfnClient.send(command)
  return response.StackEvents || []
}

// エラーイベントのみ抽出
const events = await getStackEvents('my-stack')
const errors = events.filter((e) =>
  e.ResourceStatus?.includes('FAILED') ||
  e.ResourceStatus?.includes('ROLLBACK')
)
```

### ドリフト検出と修正

```typescript
// ドリフト検出
const detectionId = await detectStackDrift('my-stack')
await waitForDriftDetection(detectionId)

const drifts = await getStackResourceDrifts('my-stack')
for (const drift of drifts) {
  console.log(`Resource: ${drift.LogicalResourceId}`)
  console.log(`Status: ${drift.StackResourceDriftStatus}`)
  console.log(`Expected:`, drift.ExpectedProperties)
  console.log(`Actual:`, drift.ActualProperties)
}
```

## セキュリティ

### 1. IAMポリシーの最小権限

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks"
      ],
      "Resource": "arn:aws:cloudformation:*:*:stack/my-app-*"
    }
  ]
}
```

### 2. StackPolicy（スタックポリシー）

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "Update:*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "Update:Delete",
      "Resource": "LogicalResourceId/ProductionDatabase"
    }
  ]
}
```

### 3. Secrets ManagerとParameter Storeの統合

```yaml
Parameters:
  DBPassword:
    Type: AWS::SSM::Parameter::Value<String>
    Default: /myapp/prod/db/password
    NoEcho: true

Resources:
  Database:
    Type: AWS::RDS::DBInstance
    Properties:
      MasterUserPassword: !Ref DBPassword
```

## 参考リンク

- [AWS CloudFormation 公式ドキュメント](https://docs.aws.amazon.com/cloudformation/)
- [CloudFormation テンプレートリファレンス](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)
- [CloudFormation SDK](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-cloudformation/)
- [CloudFormation ベストプラクティス](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [CloudFormation サンプルテンプレート](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/sample-templates-services-us-west-2.html)
