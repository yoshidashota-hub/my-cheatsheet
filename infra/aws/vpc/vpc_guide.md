# AWS VPC ガイド

Amazon VPC（Virtual Private Cloud）は、AWSクラウド内に論理的に分離されたプライベートネットワーク空間を作成できるサービスです。

## 特徴

- **完全な制御**: IPアドレス範囲、サブネット、ルートテーブル、ゲートウェイを自由に設定
- **セキュリティ**: セキュリティグループとネットワークACLによる多層防御
- **柔軟性**: パブリック/プライベートサブネットの混在、複数のVPC接続
- **スケーラビリティ**: 必要に応じてサブネットやリソースを追加
- **ハイブリッド接続**: VPN、Direct Connectでオンプレミスと接続可能

## 基本概念

### VPC (Virtual Private Cloud)

- AWS上に作成する仮想ネットワーク
- CIDR形式でIPアドレス範囲を指定（例: 10.0.0.0/16）
- リージョンごとに作成

### サブネット (Subnet)

- VPC内のIPアドレス範囲をさらに分割
- アベイラビリティゾーン（AZ）ごとに配置
- パブリックサブネット: インターネットゲートウェイ経由で外部通信可能
- プライベートサブネット: 外部から直接アクセス不可

### CIDR (Classless Inter-Domain Routing)

| CIDR | IPアドレス数 | 用途例 |
|------|------------|--------|
| /16 | 65,536 | 大規模VPC（10.0.0.0/16） |
| /20 | 4,096 | 中規模VPC |
| /24 | 256 | 小規模サブネット（10.0.1.0/24） |
| /28 | 16 | 最小サブネット |

### ルートテーブル (Route Table)

- ネットワークトラフィックの転送先を定義
- 各サブネットに1つのルートテーブルを関連付け
- デフォルトでローカルルート（VPC内通信）が含まれる

### インターネットゲートウェイ (Internet Gateway)

- VPCとインターネット間の通信を可能にする
- パブリックサブネットのルートテーブルに追加
- 水平スケール、冗長性、高可用性を持つ

### NAT ゲートウェイ (NAT Gateway)

- プライベートサブネットからインターネットへの送信トラフィックを許可
- インターネットからの受信トラフィックは遮断
- 高可用性のため各AZに配置推奨

### セキュリティグループ (Security Group)

- インスタンスレベルのファイアウォール（ステートフル）
- インバウンド/アウトバウンドルールを定義
- デフォルトで全インバウンドを拒否、全アウトバウンドを許可
- 複数のセキュリティグループをインスタンスに適用可能

### ネットワークACL (Network ACL)

- サブネットレベルのファイアウォール（ステートレス）
- 番号順にルールを評価
- デフォルトで全トラフィックを許可
- セキュリティグループの追加防御層として機能

## AWS CLI でのVPC操作

### インストールと認証

```bash
# AWS CLI v2 のインストール
brew install awscli

# 認証設定
aws configure
```

### VPC作成

```bash
# VPC作成
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=MyVPC}]'

# VPC一覧
aws ec2 describe-vpcs

# 特定のVPC詳細
aws ec2 describe-vpcs --vpc-ids vpc-12345678

# VPC削除
aws ec2 delete-vpc --vpc-id vpc-12345678
```

### サブネット作成

```bash
# パブリックサブネット作成
aws ec2 create-subnet \
  --vpc-id vpc-12345678 \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-northeast-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Public-Subnet-1a}]'

# プライベートサブネット作成
aws ec2 create-subnet \
  --vpc-id vpc-12345678 \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ap-northeast-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private-Subnet-1a}]'

# サブネット一覧
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-12345678"

# サブネット削除
aws ec2 delete-subnet --subnet-id subnet-12345678
```

### インターネットゲートウェイ

```bash
# インターネットゲートウェイ作成
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=MyIGW}]'

# VPCにアタッチ
aws ec2 attach-internet-gateway \
  --vpc-id vpc-12345678 \
  --internet-gateway-id igw-12345678

# デタッチ
aws ec2 detach-internet-gateway \
  --vpc-id vpc-12345678 \
  --internet-gateway-id igw-12345678

# 削除
aws ec2 delete-internet-gateway --internet-gateway-id igw-12345678
```

### NATゲートウェイ

```bash
# Elastic IP割り当て
aws ec2 allocate-address --domain vpc

# NATゲートウェイ作成
aws ec2 create-nat-gateway \
  --subnet-id subnet-12345678 \
  --allocation-id eipalloc-12345678 \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=MyNAT}]'

# NATゲートウェイ一覧
aws ec2 describe-nat-gateways

# NATゲートウェイ削除
aws ec2 delete-nat-gateway --nat-gateway-id nat-12345678

# Elastic IP解放
aws ec2 release-address --allocation-id eipalloc-12345678
```

### ルートテーブル

```bash
# ルートテーブル作成
aws ec2 create-route-table \
  --vpc-id vpc-12345678 \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Public-RT}]'

# インターネットゲートウェイへのルート追加
aws ec2 create-route \
  --route-table-id rtb-12345678 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-12345678

# NATゲートウェイへのルート追加
aws ec2 create-route \
  --route-table-id rtb-87654321 \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-12345678

# サブネットにルートテーブルを関連付け
aws ec2 associate-route-table \
  --subnet-id subnet-12345678 \
  --route-table-id rtb-12345678

# ルートテーブル一覧
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-12345678"
```

### セキュリティグループ

```bash
# セキュリティグループ作成
aws ec2 create-security-group \
  --group-name web-sg \
  --description "Security group for web servers" \
  --vpc-id vpc-12345678

# インバウンドルール追加（HTTP）
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# インバウンドルール追加（HTTPS）
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# インバウンドルール追加（SSH - 特定IPのみ）
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 22 \
  --cidr 203.0.113.0/24

# セキュリティグループからのアクセス許可
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 3306 \
  --source-group sg-87654321

# ルール削除
aws ec2 revoke-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 22 \
  --cidr 203.0.113.0/24

# セキュリティグループ一覧
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-12345678"
```

## AWS SDK (JavaScript/TypeScript)

### インストール

```bash
npm install @aws-sdk/client-ec2
```

### 基本設定

```typescript
import { EC2Client } from '@aws-sdk/client-ec2'

const ec2Client = new EC2Client({
  region: 'ap-northeast-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})
```

### VPC操作

```typescript
import {
  CreateVpcCommand,
  DescribeVpcsCommand,
  DeleteVpcCommand,
  ModifyVpcAttributeCommand,
} from '@aws-sdk/client-ec2'

// VPC作成
async function createVPC(cidrBlock: string, name: string) {
  const command = new CreateVpcCommand({
    CidrBlock: cidrBlock,
    TagSpecifications: [
      {
        ResourceType: 'vpc',
        Tags: [{ Key: 'Name', Value: name }],
      },
    ],
  })

  const response = await ec2Client.send(command)
  return response.Vpc
}

// VPC一覧取得
async function listVPCs() {
  const command = new DescribeVpcsCommand({})
  const response = await ec2Client.send(command)
  return response.Vpcs || []
}

// DNS解決を有効化
async function enableDnsSupport(vpcId: string) {
  const command = new ModifyVpcAttributeCommand({
    VpcId: vpcId,
    EnableDnsSupport: { Value: true },
  })

  await ec2Client.send(command)
}

// DNSホスト名を有効化
async function enableDnsHostnames(vpcId: string) {
  const command = new ModifyVpcAttributeCommand({
    VpcId: vpcId,
    EnableDnsHostnames: { Value: true },
  })

  await ec2Client.send(command)
}

// VPC削除
async function deleteVPC(vpcId: string) {
  const command = new DeleteVpcCommand({ VpcId: vpcId })
  await ec2Client.send(command)
}
```

### サブネット操作

```typescript
import {
  CreateSubnetCommand,
  DescribeSubnetsCommand,
  DeleteSubnetCommand,
  ModifySubnetAttributeCommand,
} from '@aws-sdk/client-ec2'

// サブネット作成
async function createSubnet(
  vpcId: string,
  cidrBlock: string,
  availabilityZone: string,
  name: string
) {
  const command = new CreateSubnetCommand({
    VpcId: vpcId,
    CidrBlock: cidrBlock,
    AvailabilityZone: availabilityZone,
    TagSpecifications: [
      {
        ResourceType: 'subnet',
        Tags: [{ Key: 'Name', Value: name }],
      },
    ],
  })

  const response = await ec2Client.send(command)
  return response.Subnet
}

// サブネット一覧取得
async function listSubnets(vpcId: string) {
  const command = new DescribeSubnetsCommand({
    Filters: [{ Name: 'vpc-id', Values: [vpcId] }],
  })

  const response = await ec2Client.send(command)
  return response.Subnets || []
}

// パブリックIPを自動割り当て
async function enableAutoAssignPublicIp(subnetId: string) {
  const command = new ModifySubnetAttributeCommand({
    SubnetId: subnetId,
    MapPublicIpOnLaunch: { Value: true },
  })

  await ec2Client.send(command)
}

// サブネット削除
async function deleteSubnet(subnetId: string) {
  const command = new DeleteSubnetCommand({ SubnetId: subnetId })
  await ec2Client.send(command)
}
```

### インターネットゲートウェイ

```typescript
import {
  CreateInternetGatewayCommand,
  AttachInternetGatewayCommand,
  DetachInternetGatewayCommand,
  DeleteInternetGatewayCommand,
} from '@aws-sdk/client-ec2'

// インターネットゲートウェイ作成
async function createInternetGateway(name: string) {
  const command = new CreateInternetGatewayCommand({
    TagSpecifications: [
      {
        ResourceType: 'internet-gateway',
        Tags: [{ Key: 'Name', Value: name }],
      },
    ],
  })

  const response = await ec2Client.send(command)
  return response.InternetGateway
}

// VPCにアタッチ
async function attachInternetGateway(vpcId: string, igwId: string) {
  const command = new AttachInternetGatewayCommand({
    VpcId: vpcId,
    InternetGatewayId: igwId,
  })

  await ec2Client.send(command)
}

// デタッチ
async function detachInternetGateway(vpcId: string, igwId: string) {
  const command = new DetachInternetGatewayCommand({
    VpcId: vpcId,
    InternetGatewayId: igwId,
  })

  await ec2Client.send(command)
}

// 削除
async function deleteInternetGateway(igwId: string) {
  const command = new DeleteInternetGatewayCommand({
    InternetGatewayId: igwId,
  })

  await ec2Client.send(command)
}
```

### NATゲートウェイ

```typescript
import {
  AllocateAddressCommand,
  CreateNatGatewayCommand,
  DescribeNatGatewaysCommand,
  DeleteNatGatewayCommand,
  ReleaseAddressCommand,
} from '@aws-sdk/client-ec2'

// Elastic IP割り当て
async function allocateElasticIP() {
  const command = new AllocateAddressCommand({ Domain: 'vpc' })
  const response = await ec2Client.send(command)
  return response.AllocationId
}

// NATゲートウェイ作成
async function createNATGateway(
  subnetId: string,
  allocationId: string,
  name: string
) {
  const command = new CreateNatGatewayCommand({
    SubnetId: subnetId,
    AllocationId: allocationId,
    TagSpecifications: [
      {
        ResourceType: 'natgateway',
        Tags: [{ Key: 'Name', Value: name }],
      },
    ],
  })

  const response = await ec2Client.send(command)
  return response.NatGateway
}

// NATゲートウェイのステータス確認
async function waitForNATGateway(natGatewayId: string) {
  let available = false

  while (!available) {
    const command = new DescribeNatGatewaysCommand({
      NatGatewayIds: [natGatewayId],
    })

    const response = await ec2Client.send(command)
    const state = response.NatGateways?.[0]?.State

    if (state === 'available') {
      available = true
    } else if (state === 'failed') {
      throw new Error('NAT Gateway creation failed')
    }

    await new Promise((resolve) => setTimeout(resolve, 5000))
  }
}

// NATゲートウェイ削除
async function deleteNATGateway(natGatewayId: string) {
  const command = new DeleteNatGatewayCommand({
    NatGatewayId: natGatewayId,
  })

  await ec2Client.send(command)
}

// Elastic IP解放
async function releaseElasticIP(allocationId: string) {
  const command = new ReleaseAddressCommand({ AllocationId: allocationId })
  await ec2Client.send(command)
}
```

### ルートテーブル

```typescript
import {
  CreateRouteTableCommand,
  CreateRouteCommand,
  AssociateRouteTableCommand,
  DescribeRouteTablesCommand,
  DeleteRouteCommand,
  DeleteRouteTableCommand,
} from '@aws-sdk/client-ec2'

// ルートテーブル作成
async function createRouteTable(vpcId: string, name: string) {
  const command = new CreateRouteTableCommand({
    VpcId: vpcId,
    TagSpecifications: [
      {
        ResourceType: 'route-table',
        Tags: [{ Key: 'Name', Value: name }],
      },
    ],
  })

  const response = await ec2Client.send(command)
  return response.RouteTable
}

// インターネットゲートウェイへのルート追加
async function createInternetRoute(routeTableId: string, igwId: string) {
  const command = new CreateRouteCommand({
    RouteTableId: routeTableId,
    DestinationCidrBlock: '0.0.0.0/0',
    GatewayId: igwId,
  })

  await ec2Client.send(command)
}

// NATゲートウェイへのルート追加
async function createNATRoute(routeTableId: string, natGatewayId: string) {
  const command = new CreateRouteCommand({
    RouteTableId: routeTableId,
    DestinationCidrBlock: '0.0.0.0/0',
    NatGatewayId: natGatewayId,
  })

  await ec2Client.send(command)
}

// サブネットに関連付け
async function associateRouteTable(subnetId: string, routeTableId: string) {
  const command = new AssociateRouteTableCommand({
    SubnetId: subnetId,
    RouteTableId: routeTableId,
  })

  const response = await ec2Client.send(command)
  return response.AssociationId
}

// ルートテーブル一覧取得
async function listRouteTables(vpcId: string) {
  const command = new DescribeRouteTablesCommand({
    Filters: [{ Name: 'vpc-id', Values: [vpcId] }],
  })

  const response = await ec2Client.send(command)
  return response.RouteTables || []
}
```

### セキュリティグループ

```typescript
import {
  CreateSecurityGroupCommand,
  AuthorizeSecurityGroupIngressCommand,
  AuthorizeSecurityGroupEgressCommand,
  RevokeSecurityGroupIngressCommand,
  DescribeSecurityGroupsCommand,
  DeleteSecurityGroupCommand,
  type IpPermission,
} from '@aws-sdk/client-ec2'

// セキュリティグループ作成
async function createSecurityGroup(
  vpcId: string,
  groupName: string,
  description: string
) {
  const command = new CreateSecurityGroupCommand({
    VpcId: vpcId,
    GroupName: groupName,
    Description: description,
    TagSpecifications: [
      {
        ResourceType: 'security-group',
        Tags: [{ Key: 'Name', Value: groupName }],
      },
    ],
  })

  const response = await ec2Client.send(command)
  return response.GroupId
}

// HTTPアクセス許可
async function allowHTTP(securityGroupId: string) {
  const command = new AuthorizeSecurityGroupIngressCommand({
    GroupId: securityGroupId,
    IpPermissions: [
      {
        IpProtocol: 'tcp',
        FromPort: 80,
        ToPort: 80,
        IpRanges: [{ CidrIp: '0.0.0.0/0', Description: 'Allow HTTP' }],
      },
    ],
  })

  await ec2Client.send(command)
}

// HTTPSアクセス許可
async function allowHTTPS(securityGroupId: string) {
  const command = new AuthorizeSecurityGroupIngressCommand({
    GroupId: securityGroupId,
    IpPermissions: [
      {
        IpProtocol: 'tcp',
        FromPort: 443,
        ToPort: 443,
        IpRanges: [{ CidrIp: '0.0.0.0/0', Description: 'Allow HTTPS' }],
      },
    ],
  })

  await ec2Client.send(command)
}

// SSHアクセス許可（特定IPのみ）
async function allowSSH(securityGroupId: string, cidr: string) {
  const command = new AuthorizeSecurityGroupIngressCommand({
    GroupId: securityGroupId,
    IpPermissions: [
      {
        IpProtocol: 'tcp',
        FromPort: 22,
        ToPort: 22,
        IpRanges: [{ CidrIp: cidr, Description: 'Allow SSH' }],
      },
    ],
  })

  await ec2Client.send(command)
}

// セキュリティグループ間の通信許可
async function allowFromSecurityGroup(
  securityGroupId: string,
  sourceSecurityGroupId: string,
  port: number
) {
  const command = new AuthorizeSecurityGroupIngressCommand({
    GroupId: securityGroupId,
    IpPermissions: [
      {
        IpProtocol: 'tcp',
        FromPort: port,
        ToPort: port,
        UserIdGroupPairs: [{ GroupId: sourceSecurityGroupId }],
      },
    ],
  })

  await ec2Client.send(command)
}

// ルール削除
async function revokeIngress(
  securityGroupId: string,
  ipPermissions: IpPermission[]
) {
  const command = new RevokeSecurityGroupIngressCommand({
    GroupId: securityGroupId,
    IpPermissions: ipPermissions,
  })

  await ec2Client.send(command)
}

// セキュリティグループ一覧取得
async function listSecurityGroups(vpcId: string) {
  const command = new DescribeSecurityGroupsCommand({
    Filters: [{ Name: 'vpc-id', Values: [vpcId] }],
  })

  const response = await ec2Client.send(command)
  return response.SecurityGroups || []
}

// セキュリティグループ削除
async function deleteSecurityGroup(securityGroupId: string) {
  const command = new DeleteSecurityGroupCommand({
    GroupId: securityGroupId,
  })

  await ec2Client.send(command)
}
```

## VPC構築の実践例

### 基本的な3層アーキテクチャ

```typescript
// VPC作成
const vpc = await createVPC('10.0.0.0/16', 'MyVPC')
const vpcId = vpc?.VpcId!

await enableDnsSupport(vpcId)
await enableDnsHostnames(vpcId)

// パブリックサブネット作成（2つのAZ）
const publicSubnet1 = await createSubnet(
  vpcId,
  '10.0.1.0/24',
  'ap-northeast-1a',
  'Public-Subnet-1a'
)
const publicSubnet2 = await createSubnet(
  vpcId,
  '10.0.2.0/24',
  'ap-northeast-1c',
  'Public-Subnet-1c'
)

await enableAutoAssignPublicIp(publicSubnet1?.SubnetId!)
await enableAutoAssignPublicIp(publicSubnet2?.SubnetId!)

// プライベートサブネット作成（2つのAZ）
const privateSubnet1 = await createSubnet(
  vpcId,
  '10.0.11.0/24',
  'ap-northeast-1a',
  'Private-Subnet-1a'
)
const privateSubnet2 = await createSubnet(
  vpcId,
  '10.0.12.0/24',
  'ap-northeast-1c',
  'Private-Subnet-1c'
)

// インターネットゲートウェイ作成とアタッチ
const igw = await createInternetGateway('MyIGW')
await attachInternetGateway(vpcId, igw?.InternetGatewayId!)

// NATゲートウェイ作成（1つのAZ）
const eipAllocation = await allocateElasticIP()
const natGateway = await createNATGateway(
  publicSubnet1?.SubnetId!,
  eipAllocation!,
  'MyNAT'
)
await waitForNATGateway(natGateway?.NatGatewayId!)

// パブリックルートテーブル作成
const publicRT = await createRouteTable(vpcId, 'Public-RT')
await createInternetRoute(publicRT?.RouteTableId!, igw?.InternetGatewayId!)
await associateRouteTable(publicSubnet1?.SubnetId!, publicRT?.RouteTableId!)
await associateRouteTable(publicSubnet2?.SubnetId!, publicRT?.RouteTableId!)

// プライベートルートテーブル作成
const privateRT = await createRouteTable(vpcId, 'Private-RT')
await createNATRoute(privateRT?.RouteTableId!, natGateway?.NatGatewayId!)
await associateRouteTable(privateSubnet1?.SubnetId!, privateRT?.RouteTableId!)
await associateRouteTable(privateSubnet2?.SubnetId!, privateRT?.RouteTableId!)

// セキュリティグループ作成
// ALB用
const albSG = await createSecurityGroup(vpcId, 'alb-sg', 'Security group for ALB')
await allowHTTP(albSG!)
await allowHTTPS(albSG!)

// Webサーバー用
const webSG = await createSecurityGroup(
  vpcId,
  'web-sg',
  'Security group for web servers'
)
await allowFromSecurityGroup(webSG!, albSG!, 80)

// データベース用
const dbSG = await createSecurityGroup(
  vpcId,
  'db-sg',
  'Security group for database'
)
await allowFromSecurityGroup(dbSG!, webSG!, 3306)

console.log('VPC setup completed!')
```

## VPCピアリング

### ピアリング接続の作成

```typescript
import {
  CreateVpcPeeringConnectionCommand,
  AcceptVpcPeeringConnectionCommand,
  DescribeVpcPeeringConnectionsCommand,
  DeleteVpcPeeringConnectionCommand,
} from '@aws-sdk/client-ec2'

// ピアリング接続リクエスト作成
async function createVPCPeering(vpcId: string, peerVpcId: string) {
  const command = new CreateVpcPeeringConnectionCommand({
    VpcId: vpcId,
    PeerVpcId: peerVpcId,
    TagSpecifications: [
      {
        ResourceType: 'vpc-peering-connection',
        Tags: [{ Key: 'Name', Value: 'VPC-Peering' }],
      },
    ],
  })

  const response = await ec2Client.send(command)
  return response.VpcPeeringConnection
}

// ピアリング接続を承認
async function acceptVPCPeering(peeringConnectionId: string) {
  const command = new AcceptVpcPeeringConnectionCommand({
    VpcPeeringConnectionId: peeringConnectionId,
  })

  await ec2Client.send(command)
}

// ピアリング接続のルートを追加
async function addPeeringRoute(
  routeTableId: string,
  peeringConnectionId: string,
  destinationCidr: string
) {
  const command = new CreateRouteCommand({
    RouteTableId: routeTableId,
    DestinationCidrBlock: destinationCidr,
    VpcPeeringConnectionId: peeringConnectionId,
  })

  await ec2Client.send(command)
}
```

## VPCエンドポイント

### S3エンドポイント作成（Gateway型）

```typescript
import {
  CreateVpcEndpointCommand,
  DescribeVpcEndpointsCommand,
  DeleteVpcEndpointsCommand,
} from '@aws-sdk/client-ec2'

// S3 Gateway Endpoint作成
async function createS3Endpoint(vpcId: string, routeTableIds: string[]) {
  const command = new CreateVpcEndpointCommand({
    VpcId: vpcId,
    ServiceName: 'com.amazonaws.ap-northeast-1.s3',
    VpcEndpointType: 'Gateway',
    RouteTableIds: routeTableIds,
  })

  const response = await ec2Client.send(command)
  return response.VpcEndpoint
}

// Interface Endpoint作成（例: Secrets Manager）
async function createInterfaceEndpoint(
  vpcId: string,
  subnetIds: string[],
  securityGroupIds: string[]
) {
  const command = new CreateVpcEndpointCommand({
    VpcId: vpcId,
    ServiceName: 'com.amazonaws.ap-northeast-1.secretsmanager',
    VpcEndpointType: 'Interface',
    SubnetIds: subnetIds,
    SecurityGroupIds: securityGroupIds,
    PrivateDnsEnabled: true,
  })

  const response = await ec2Client.send(command)
  return response.VpcEndpoint
}
```

## Terraform での管理

### VPCの基本構成

```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# パブリックサブネット
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1c"
  }
}

# プライベートサブネット
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "private-subnet-1a"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "private-subnet-1c"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1a.id

  tags = {
    Name = "main-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# パブリックルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# プライベートルートテーブル
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-rt"
  }
}

# ルートテーブル関連付け
resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_1c" {
  subnet_id      = aws_subnet.private_1c.id
  route_table_id = aws_route_table.private.id
}

# セキュリティグループ - ALB
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# セキュリティグループ - Webサーバー
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# セキュリティグループ - RDS
resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# VPCエンドポイント - S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-northeast-1.s3"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "s3-endpoint"
  }
}
```

## ベストプラクティス

### 1. 適切なCIDR設計

```typescript
// 将来の拡張を考慮した設計
const vpcCidr = '10.0.0.0/16' // 65,536 IPアドレス

// サブネットは/24で分割（256アドレス）
const subnets = [
  '10.0.1.0/24', // パブリック 1a
  '10.0.2.0/24', // パブリック 1c
  '10.0.11.0/24', // プライベート（App）1a
  '10.0.12.0/24', // プライベート（App）1c
  '10.0.21.0/24', // プライベート（DB）1a
  '10.0.22.0/24', // プライベート（DB）1c
]

// 予約: 10.0.100.0/22 - 将来の拡張用
```

### 2. マルチAZ構成

```typescript
// 高可用性のため複数AZにリソースを配置
const availabilityZones = ['ap-northeast-1a', 'ap-northeast-1c']

for (const az of availabilityZones) {
  // 各AZにサブネット作成
  await createSubnet(vpcId, `10.0.${azIndex}.0/24`, az, `Public-${az}`)
  await createSubnet(vpcId, `10.0.${azIndex + 10}.0/24`, az, `Private-${az}`)
}
```

### 3. セキュリティグループの最小権限

```typescript
// 悪い例: 全てのポートを開放
// await allowAllPorts(sgId) // ❌

// 良い例: 必要なポートのみ開放
await allowHTTPS(sgId) // ✓
await allowFromSecurityGroup(dbSgId, webSgId, 3306) // ✓
```

### 4. NATゲートウェイの冗長化

```typescript
// コスト重視: 1つのNATゲートウェイ（単一障害点あり）
const natGateway1 = await createNATGateway(publicSubnet1Id, eip1, 'NAT-1a')

// 高可用性重視: 各AZにNATゲートウェイ
const natGateway1a = await createNATGateway(publicSubnet1aId, eip1, 'NAT-1a')
const natGateway1c = await createNATGateway(publicSubnet1cId, eip2, 'NAT-1c')
```

### 5. VPCフローログの有効化

```typescript
import { CreateFlowLogsCommand } from '@aws-sdk/client-ec2'

async function enableFlowLogs(vpcId: string, logGroupArn: string, roleArn: string) {
  const command = new CreateFlowLogsCommand({
    ResourceType: 'VPC',
    ResourceIds: [vpcId],
    TrafficType: 'ALL',
    LogDestinationType: 'cloud-watch-logs',
    LogGroupName: logGroupArn,
    DeliverLogsPermissionArn: roleArn,
  })

  await ec2Client.send(command)
}
```

## トラブルシューティング

### インターネット接続できない

```text
チェックリスト:
1. インターネットゲートウェイがVPCにアタッチされているか
2. ルートテーブルに0.0.0.0/0 -> IGWのルートがあるか
3. サブネットがそのルートテーブルに関連付けられているか
4. インスタンスにパブリックIPが割り当てられているか
5. セキュリティグループで通信が許可されているか
6. ネットワークACLでブロックされていないか
```

### プライベートサブネットから外部接続できない

```text
チェックリスト:
1. NATゲートウェイがパブリックサブネットにあるか
2. NATゲートウェイにElastic IPが関連付けられているか
3. ルートテーブルに0.0.0.0/0 -> NAT Gatewayのルートがあるか
4. セキュリティグループでアウトバウンド通信が許可されているか
```

### VPC間で通信できない

```text
チェックリスト:
1. VPCピアリング接続がActiveになっているか
2. 両方のVPCのルートテーブルにピアリングルートがあるか
3. セキュリティグループで対向VPCのCIDRからの通信を許可しているか
4. ネットワークACLでブロックされていないか
```

### CLI/SDKでのデバッグ

```typescript
// VPC設定の確認
async function debugVPC(vpcId: string) {
  const vpc = await listVPCs()
  console.log('VPC:', vpc.find((v) => v.VpcId === vpcId))

  const subnets = await listSubnets(vpcId)
  console.log('Subnets:', subnets)

  const routeTables = await listRouteTables(vpcId)
  console.log('Route Tables:', routeTables)

  const securityGroups = await listSecurityGroups(vpcId)
  console.log('Security Groups:', securityGroups)
}
```

## コスト最適化

### 料金体系

- **VPC**: 無料
- **サブネット**: 無料
- **インターネットゲートウェイ**: 無料
- **ルートテーブル**: 無料
- **セキュリティグループ**: 無料
- **NAT Gateway**: $0.045/時間 + データ処理料金 $0.045/GB
- **VPCエンドポイント（Interface）**: $0.01/時間 + データ処理料金
- **VPCエンドポイント（Gateway）**: 無料

### コスト削減のヒント

1. **NATゲートウェイの最適化**

```typescript
// 開発環境: NAT Instanceを使用（より安価）
// 本番環境: NAT Gateway（マネージド、高可用性）

// または、VPCエンドポイントを使用してNAT不要にする
await createS3Endpoint(vpcId, [privateRouteTableId])
```

2. **VPCエンドポイントの活用**

```typescript
// NATゲートウェイ経由でS3アクセス（コスト高）
// NAT料金 + データ転送料金

// VPCエンドポイント経由でS3アクセス（無料）
await createS3Endpoint(vpcId, [privateRouteTableId])
```

3. **不要なElastic IPの解放**

```bash
# 未使用のElastic IPは課金対象
aws ec2 describe-addresses --filters "Name=domain,Values=vpc"
aws ec2 release-address --allocation-id eipalloc-xxxxx
```

## セキュリティ

### 1. 最小権限の原則

```typescript
// セキュリティグループは必要最小限のアクセスのみ許可
await allowFromSecurityGroup(dbSgId, webSgId, 3306) // DBはWebからのみ
```

### 2. ネットワークACLによる追加防御

```typescript
import {
  CreateNetworkAclCommand,
  CreateNetworkAclEntryCommand,
} from '@aws-sdk/client-ec2'

async function createNetworkACL(vpcId: string) {
  const command = new CreateNetworkAclCommand({
    VpcId: vpcId,
    TagSpecifications: [
      {
        ResourceType: 'network-acl',
        Tags: [{ Key: 'Name', Value: 'Custom-NACL' }],
      },
    ],
  })

  const response = await ec2Client.send(command)
  return response.NetworkAcl
}

// インバウンドルール追加
async function addNACLInboundRule(
  naclId: string,
  ruleNumber: number,
  protocol: string,
  port: number,
  cidr: string
) {
  const command = new CreateNetworkAclEntryCommand({
    NetworkAclId: naclId,
    RuleNumber: ruleNumber,
    Protocol: protocol,
    RuleAction: 'allow',
    Egress: false,
    CidrBlock: cidr,
    PortRange: {
      From: port,
      To: port,
    },
  })

  await ec2Client.send(command)
}
```

### 3. VPCフローログの監視

```typescript
// CloudWatch Logsでフローログを分析
// 異常なトラフィックパターンを検出
```

## 参考リンク

- [AWS VPC 公式ドキュメント](https://docs.aws.amazon.com/vpc/)
- [AWS SDK for JavaScript v3 - EC2](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-ec2/)
- [VPC 料金](https://aws.amazon.com/vpc/pricing/)
- [VPC設計のベストプラクティス](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
