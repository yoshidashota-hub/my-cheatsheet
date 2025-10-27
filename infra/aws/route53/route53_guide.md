# AWS Route53 ガイド

Amazon Route 53は、可用性と拡張性に優れたクラウドDNS（Domain Name System）Webサービスです。

## 特徴

- **高可用性**: 複数のエッジロケーションで分散稼働
- **スケーラブル**: トラフィック量に応じて自動スケール
- **低レイテンシ**: グローバルなエニーキャストネットワーク
- **ヘルスチェック**: エンドポイントの監視とフェイルオーバー
- **ドメイン登録**: ドメインの購入・管理が可能
- **100% SLA**: 高い可用性を保証

## 基本概念

### ホストゾーン（Hosted Zone）

- ドメインのDNSレコードを管理するコンテナ
- パブリックホストゾーン: インターネット上のドメイン
- プライベートホストゾーン: VPC内のドメイン

### レコードタイプ

| タイプ | 用途 | 例 |
|--------|------|-----|
| A | IPv4アドレスへのマッピング | example.com → 192.0.2.1 |
| AAAA | IPv6アドレスへのマッピング | example.com → 2001:0db8::1 |
| CNAME | 別のドメイン名へのエイリアス | www.example.com → example.com |
| MX | メールサーバーの指定 | example.com → mail.example.com |
| TXT | テキスト情報（SPF, DKIM等） | example.com → "v=spf1 ..." |
| NS | ネームサーバーの指定 | example.com → ns-123.awsdns-12.com |
| SOA | ゾーンの管理情報 | 自動生成 |
| SRV | サービスの場所を指定 | _service._proto.name |
| PTR | 逆引きDNS | 1.2.0.192.in-addr.arpa → example.com |
| CAA | 証明書発行を許可するCA | example.com → "0 issue \"letsencrypt.org\"" |
| Alias | AWSリソースへのエイリアス | example.com → CloudFront, ELB等 |

### ルーティングポリシー

1. **Simple（シンプル）**: 単一のリソースへのルーティング
2. **Weighted（加重）**: 複数のリソースに重み付けで振り分け
3. **Latency（レイテンシ）**: 最も低レイテンシのリージョンへルーティング
4. **Failover（フェイルオーバー）**: プライマリが障害時にセカンダリへ切り替え
5. **Geolocation（地理的位置）**: ユーザーの地理的位置に基づいてルーティング
6. **Geoproximity（地理的近接）**: リソースの位置とユーザーの位置に基づいてルーティング
7. **Multivalue Answer（複数値回答）**: 最大8つのIPアドレスをランダムに返す

## AWS CLI でのRoute53操作

### インストール

```bash
# AWS CLI v2 のインストール
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 確認
aws --version
```

### 認証設定

```bash
# AWS認証情報の設定
aws configure

# 入力内容:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: ap-northeast-1
# Default output format: json
```

### ホストゾーンの操作

```bash
# ホストゾーン一覧
aws route53 list-hosted-zones

# ホストゾーン作成（パブリック）
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# ホストゾーン作成（プライベート）
aws route53 create-hosted-zone \
  --name internal.example.com \
  --caller-reference $(date +%s) \
  --hosted-zone-config PrivateZone=true \
  --vpc VPCRegion=ap-northeast-1,VPCId=vpc-12345678

# ホストゾーンの詳細取得
aws route53 get-hosted-zone --id Z1234567890ABC

# ホストゾーン削除
aws route53 delete-hosted-zone --id Z1234567890ABC
```

### レコードセットの操作

```bash
# レコードセット一覧
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC

# レコードセット作成/更新/削除（JSON形式）
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://changes.json
```

#### changes.json の例

```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "www.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "192.0.2.1"
          }
        ]
      }
    }
  ]
}
```

#### Aレコード作成

```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "203.0.113.1"
          }
        ]
      }
    }
  ]
}
```

#### CNAMEレコード作成

```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "www.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "example.com"
          }
        ]
      }
    }
  ]
}
```

#### Aliasレコード作成（CloudFront）

```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "d123456789.cloudfront.net",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
```

#### Aliasレコード作成（ALB）

```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z14GRHDCWA56QT",
          "DNSName": "my-alb-123456789.ap-northeast-1.elb.amazonaws.com",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
```

#### レコード更新

```json
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "www.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "192.0.2.2"
          }
        ]
      }
    }
  ]
}
```

#### レコード削除

```json
{
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "old.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "192.0.2.1"
          }
        ]
      }
    }
  ]
}
```

### 変更ステータスの確認

```bash
# 変更のステータス確認
aws route53 get-change --id /change/C1234567890ABC
```

## AWS SDK (JavaScript/TypeScript)

### インストール

```bash
npm install @aws-sdk/client-route-53
```

### 基本設定

```typescript
import { Route53Client } from '@aws-sdk/client-route-53'

const route53Client = new Route53Client({
  region: 'us-east-1', // Route53はグローバルサービスだがus-east-1を指定
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})
```

### ホストゾーンの操作

```typescript
import {
  ListHostedZonesCommand,
  CreateHostedZoneCommand,
  GetHostedZoneCommand,
  DeleteHostedZoneCommand,
} from '@aws-sdk/client-route-53'

// ホストゾーン一覧取得
async function listHostedZones() {
  const command = new ListHostedZonesCommand({})
  const response = await route53Client.send(command)
  return response.HostedZones || []
}

// ホストゾーン作成
async function createHostedZone(domainName: string) {
  const command = new CreateHostedZoneCommand({
    Name: domainName,
    CallerReference: Date.now().toString(),
    HostedZoneConfig: {
      Comment: `Hosted zone for ${domainName}`,
      PrivateZone: false,
    },
  })

  const response = await route53Client.send(command)
  return response.HostedZone
}

// プライベートホストゾーン作成
async function createPrivateHostedZone(
  domainName: string,
  vpcId: string,
  vpcRegion: string
) {
  const command = new CreateHostedZoneCommand({
    Name: domainName,
    CallerReference: Date.now().toString(),
    HostedZoneConfig: {
      Comment: `Private hosted zone for ${domainName}`,
      PrivateZone: true,
    },
    VPC: {
      VPCRegion: vpcRegion,
      VPCId: vpcId,
    },
  })

  const response = await route53Client.send(command)
  return response.HostedZone
}

// ホストゾーン詳細取得
async function getHostedZone(hostedZoneId: string) {
  const command = new GetHostedZoneCommand({
    Id: hostedZoneId,
  })

  const response = await route53Client.send(command)
  return response.HostedZone
}

// ホストゾーン削除
async function deleteHostedZone(hostedZoneId: string) {
  const command = new DeleteHostedZoneCommand({
    Id: hostedZoneId,
  })

  await route53Client.send(command)
}
```

### レコードセットの操作

```typescript
import {
  ListResourceRecordSetsCommand,
  ChangeResourceRecordSetsCommand,
  type Change,
  type ResourceRecordSet,
} from '@aws-sdk/client-route-53'

// レコードセット一覧取得
async function listRecordSets(hostedZoneId: string) {
  const command = new ListResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
  })

  const response = await route53Client.send(command)
  return response.ResourceRecordSets || []
}

// 特定のレコードを検索
async function findRecordSet(
  hostedZoneId: string,
  name: string,
  type: string
) {
  const recordSets = await listRecordSets(hostedZoneId)
  return recordSets.find((rs) => rs.Name === name && rs.Type === type)
}

// Aレコード作成
async function createARecord(
  hostedZoneId: string,
  name: string,
  ipAddress: string,
  ttl = 300
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: name,
            Type: 'A',
            TTL: ttl,
            ResourceRecords: [{ Value: ipAddress }],
          },
        },
      ],
    },
  })

  const response = await route53Client.send(command)
  return response.ChangeInfo
}

// CNAMEレコード作成
async function createCNAMERecord(
  hostedZoneId: string,
  name: string,
  target: string,
  ttl = 300
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: name,
            Type: 'CNAME',
            TTL: ttl,
            ResourceRecords: [{ Value: target }],
          },
        },
      ],
    },
  })

  const response = await route53Client.send(command)
  return response.ChangeInfo
}

// Aliasレコード作成（CloudFront）
async function createAliasRecord(
  hostedZoneId: string,
  name: string,
  targetDNSName: string,
  targetHostedZoneId: string
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: name,
            Type: 'A',
            AliasTarget: {
              HostedZoneId: targetHostedZoneId,
              DNSName: targetDNSName,
              EvaluateTargetHealth: false,
            },
          },
        },
      ],
    },
  })

  const response = await route53Client.send(command)
  return response.ChangeInfo
}

// レコード更新（UPSERT）
async function updateRecord(
  hostedZoneId: string,
  name: string,
  type: string,
  value: string,
  ttl = 300
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'UPSERT',
          ResourceRecordSet: {
            Name: name,
            Type: type,
            TTL: ttl,
            ResourceRecords: [{ Value: value }],
          },
        },
      ],
    },
  })

  const response = await route53Client.send(command)
  return response.ChangeInfo
}

// レコード削除
async function deleteRecord(
  hostedZoneId: string,
  recordSet: ResourceRecordSet
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'DELETE',
          ResourceRecordSet: recordSet,
        },
      ],
    },
  })

  const response = await route53Client.send(command)
  return response.ChangeInfo
}

// 複数のレコードを一括変更
async function batchChangeRecords(
  hostedZoneId: string,
  changes: Change[]
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Comment: 'Batch record changes',
      Changes: changes,
    },
  })

  const response = await route53Client.send(command)
  return response.ChangeInfo
}
```

### 変更ステータスの確認

```typescript
import { GetChangeCommand } from '@aws-sdk/client-route-53'

async function getChangeStatus(changeId: string) {
  const command = new GetChangeCommand({
    Id: changeId,
  })

  const response = await route53Client.send(command)
  return response.ChangeInfo
}

// 変更が完了するまで待機
async function waitForChange(changeId: string, maxWaitTime = 60000) {
  const startTime = Date.now()

  while (Date.now() - startTime < maxWaitTime) {
    const changeInfo = await getChangeStatus(changeId)

    if (changeInfo?.Status === 'INSYNC') {
      return true
    }

    await new Promise((resolve) => setTimeout(resolve, 5000))
  }

  return false
}
```

## ヘルスチェック

### ヘルスチェックの作成

```typescript
import {
  CreateHealthCheckCommand,
  GetHealthCheckStatusCommand,
  DeleteHealthCheckCommand,
} from '@aws-sdk/client-route-53'

// HTTPヘルスチェック作成
async function createHealthCheck(
  ipAddress: string,
  port: number,
  path: string
) {
  const command = new CreateHealthCheckCommand({
    CallerReference: Date.now().toString(),
    HealthCheckConfig: {
      Type: 'HTTP',
      ResourcePath: path,
      FullyQualifiedDomainName: ipAddress,
      Port: port,
      RequestInterval: 30,
      FailureThreshold: 3,
    },
    HealthCheckTags: [
      {
        Key: 'Name',
        Value: 'API Health Check',
      },
    ],
  })

  const response = await route53Client.send(command)
  return response.HealthCheck
}

// HTTPSヘルスチェック作成
async function createHTTPSHealthCheck(domain: string, path: string) {
  const command = new CreateHealthCheckCommand({
    CallerReference: Date.now().toString(),
    HealthCheckConfig: {
      Type: 'HTTPS',
      ResourcePath: path,
      FullyQualifiedDomainName: domain,
      Port: 443,
      RequestInterval: 30,
      FailureThreshold: 3,
    },
  })

  const response = await route53Client.send(command)
  return response.HealthCheck
}

// ヘルスチェックのステータス取得
async function getHealthCheckStatus(healthCheckId: string) {
  const command = new GetHealthCheckStatusCommand({
    HealthCheckId: healthCheckId,
  })

  const response = await route53Client.send(command)
  return response.HealthCheckObservations
}

// ヘルスチェック削除
async function deleteHealthCheck(healthCheckId: string) {
  const command = new DeleteHealthCheckCommand({
    HealthCheckId: healthCheckId,
  })

  await route53Client.send(command)
}
```

### フェイルオーバーレコードの作成

```typescript
// プライマリレコード作成
async function createFailoverPrimary(
  hostedZoneId: string,
  name: string,
  ipAddress: string,
  healthCheckId: string
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: name,
            Type: 'A',
            SetIdentifier: 'Primary',
            Failover: 'PRIMARY',
            TTL: 60,
            ResourceRecords: [{ Value: ipAddress }],
            HealthCheckId: healthCheckId,
          },
        },
      ],
    },
  })

  await route53Client.send(command)
}

// セカンダリレコード作成
async function createFailoverSecondary(
  hostedZoneId: string,
  name: string,
  ipAddress: string
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: name,
            Type: 'A',
            SetIdentifier: 'Secondary',
            Failover: 'SECONDARY',
            TTL: 60,
            ResourceRecords: [{ Value: ipAddress }],
          },
        },
      ],
    },
  })

  await route53Client.send(command)
}
```

## 加重ルーティング

```typescript
// 加重ルーティングレコード作成
async function createWeightedRecord(
  hostedZoneId: string,
  name: string,
  ipAddress: string,
  weight: number,
  identifier: string
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: name,
            Type: 'A',
            SetIdentifier: identifier,
            Weight: weight,
            TTL: 60,
            ResourceRecords: [{ Value: ipAddress }],
          },
        },
      ],
    },
  })

  await route53Client.send(command)
}

// A/Bテストの例
async function setupABTest(hostedZoneId: string, name: string) {
  // 90%のトラフィックを現行版へ
  await createWeightedRecord(
    hostedZoneId,
    name,
    '192.0.2.1',
    90,
    'Current-Version'
  )

  // 10%のトラフィックを新版へ
  await createWeightedRecord(
    hostedZoneId,
    name,
    '192.0.2.2',
    10,
    'New-Version'
  )
}
```

## レイテンシベースルーティング

```typescript
// レイテンシベースルーティングレコード作成
async function createLatencyRecord(
  hostedZoneId: string,
  name: string,
  ipAddress: string,
  region: string,
  identifier: string
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: name,
            Type: 'A',
            SetIdentifier: identifier,
            Region: region,
            TTL: 60,
            ResourceRecords: [{ Value: ipAddress }],
          },
        },
      ],
    },
  })

  await route53Client.send(command)
}

// マルチリージョン構成の例
async function setupMultiRegion(hostedZoneId: string, name: string) {
  // 東京リージョン
  await createLatencyRecord(
    hostedZoneId,
    name,
    '203.0.113.1',
    'ap-northeast-1',
    'Tokyo-Server'
  )

  // 米国リージョン
  await createLatencyRecord(
    hostedZoneId,
    name,
    '198.51.100.1',
    'us-east-1',
    'Virginia-Server'
  )

  // 欧州リージョン
  await createLatencyRecord(
    hostedZoneId,
    name,
    '192.0.2.1',
    'eu-west-1',
    'Ireland-Server'
  )
}
```

## 地理的位置ルーティング

```typescript
// 地理的位置ルーティングレコード作成
async function createGeolocationRecord(
  hostedZoneId: string,
  name: string,
  ipAddress: string,
  continent?: string,
  country?: string,
  subdivision?: string,
  identifier?: string
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: name,
            Type: 'A',
            SetIdentifier: identifier || 'Geo-' + (country || continent),
            GeoLocation: {
              ContinentCode: continent,
              CountryCode: country,
              SubdivisionCode: subdivision,
            },
            TTL: 60,
            ResourceRecords: [{ Value: ipAddress }],
          },
        },
      ],
    },
  })

  await route53Client.send(command)
}

// 地域別ルーティングの例
async function setupGeolocationRouting(hostedZoneId: string, name: string) {
  // 日本向け
  await createGeolocationRecord(
    hostedZoneId,
    name,
    '203.0.113.1',
    undefined,
    'JP',
    undefined,
    'Japan-Server'
  )

  // 米国向け
  await createGeolocationRecord(
    hostedZoneId,
    name,
    '198.51.100.1',
    undefined,
    'US',
    undefined,
    'US-Server'
  )

  // デフォルト（その他の地域）
  await createGeolocationRecord(
    hostedZoneId,
    name,
    '192.0.2.1',
    undefined,
    undefined,
    undefined,
    'Default-Server'
  )
}
```

## ドメイン登録

```typescript
import {
  CheckDomainAvailabilityCommand,
  RegisterDomainCommand,
  GetDomainDetailCommand,
} from '@aws-sdk/client-route-53'

// ドメインの空き状況確認
async function checkDomainAvailability(domainName: string) {
  const command = new CheckDomainAvailabilityCommand({
    DomainName: domainName,
  })

  const response = await route53Client.send(command)
  return response.Availability === 'AVAILABLE'
}

// ドメイン登録
async function registerDomain(
  domainName: string,
  durationInYears: number,
  contactInfo: any
) {
  const command = new RegisterDomainCommand({
    DomainName: domainName,
    DurationInYears: durationInYears,
    AutoRenew: true,
    AdminContact: contactInfo,
    RegistrantContact: contactInfo,
    TechContact: contactInfo,
    PrivacyProtectAdminContact: true,
    PrivacyProtectRegistrantContact: true,
    PrivacyProtectTechContact: true,
  })

  const response = await route53Client.send(command)
  return response.OperationId
}

// ドメイン詳細取得
async function getDomainDetail(domainName: string) {
  const command = new GetDomainDetailCommand({
    DomainName: domainName,
  })

  const response = await route53Client.send(command)
  return response
}
```

## 実践例

### Next.js アプリケーションのデプロイ

```typescript
// CloudFrontディストリビューションへのエイリアスレコード作成
async function setupNextJsDomain(
  hostedZoneId: string,
  domainName: string,
  cloudFrontDomain: string
) {
  const changes: Change[] = [
    // Apex domain (example.com)
    {
      Action: 'UPSERT',
      ResourceRecordSet: {
        Name: domainName,
        Type: 'A',
        AliasTarget: {
          HostedZoneId: 'Z2FDTNDATAQYW2', // CloudFrontのホストゾーンID
          DNSName: cloudFrontDomain,
          EvaluateTargetHealth: false,
        },
      },
    },
    // WWW subdomain
    {
      Action: 'UPSERT',
      ResourceRecordSet: {
        Name: `www.${domainName}`,
        Type: 'A',
        AliasTarget: {
          HostedZoneId: 'Z2FDTNDATAQYW2',
          DNSName: cloudFrontDomain,
          EvaluateTargetHealth: false,
        },
      },
    },
  ]

  await batchChangeRecords(hostedZoneId, changes)
}
```

### カスタムドメインのメール設定

```typescript
// MXレコードとTXTレコード（SPF）の設定
async function setupEmailRecords(hostedZoneId: string, domainName: string) {
  const changes: Change[] = [
    // MXレコード
    {
      Action: 'UPSERT',
      ResourceRecordSet: {
        Name: domainName,
        Type: 'MX',
        TTL: 300,
        ResourceRecords: [
          { Value: '10 mail1.example.com' },
          { Value: '20 mail2.example.com' },
        ],
      },
    },
    // SPFレコード
    {
      Action: 'UPSERT',
      ResourceRecordSet: {
        Name: domainName,
        Type: 'TXT',
        TTL: 300,
        ResourceRecords: [
          { Value: '"v=spf1 include:_spf.google.com ~all"' },
        ],
      },
    },
    // DKIMレコード
    {
      Action: 'UPSERT',
      ResourceRecordSet: {
        Name: `_dkim.${domainName}`,
        Type: 'TXT',
        TTL: 300,
        ResourceRecords: [
          { Value: '"v=DKIM1; k=rsa; p=MIGfMA0GCS..."' },
        ],
      },
    },
  ]

  await batchChangeRecords(hostedZoneId, changes)
}
```

### ACM証明書の検証レコード作成

```typescript
// ACM証明書のDNS検証レコード作成
async function createACMValidationRecord(
  hostedZoneId: string,
  validationName: string,
  validationValue: string
) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: validationName,
            Type: 'CNAME',
            TTL: 300,
            ResourceRecords: [{ Value: validationValue }],
          },
        },
      ],
    },
  })

  await route53Client.send(command)
}
```

## Terraform での管理

### ホストゾーン作成

```hcl
resource "aws_route53_zone" "main" {
  name = "example.com"

  tags = {
    Environment = "production"
  }
}
```

### Aレコード作成

```hcl
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.example.com"
  type    = "A"
  ttl     = 300
  records = ["192.0.2.1"]
}
```

### Aliasレコード作成

```hcl
resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "example.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
```

### ヘルスチェックとフェイルオーバー

```hcl
resource "aws_route53_health_check" "primary" {
  fqdn              = "primary.example.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "Primary Health Check"
  }
}

resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"
  ttl     = 60

  set_identifier  = "Primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id
  records         = ["192.0.2.1"]
}

resource "aws_route53_record" "secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"
  ttl     = 60

  set_identifier  = "Secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

  records = ["192.0.2.2"]
}
```

## AWSリソースのホストゾーンID一覧

| サービス | リージョン | ホストゾーンID |
|---------|----------|---------------|
| CloudFront | グローバル | Z2FDTNDATAQYW2 |
| ALB | ap-northeast-1 (東京) | Z14GRHDCWA56QT |
| ALB | us-east-1 (バージニア北部) | Z35SXDOTRQ7X7K |
| ALB | us-west-2 (オレゴン) | Z1H1FL5HABSF5 |
| ALB | eu-west-1 (アイルランド) | Z32O12XQLNTSW2 |
| S3 Website | ap-northeast-1 | Z2M4EHUR26P7ZW |
| S3 Website | us-east-1 | Z3AQBSTGFYJSTF |

完全なリストは [AWS公式ドキュメント](https://docs.aws.amazon.com/general/latest/gr/elb.html) を参照してください。

## ベストプラクティス

### 1. TTLの適切な設定

```typescript
// 本番環境への切り替え前は短いTTLを設定
const preMigrationTTL = 60 // 1分

// 安定稼働後は長めのTTLでキャッシュを活用
const stableTTL = 3600 // 1時間
```

### 2. ヘルスチェックの活用

- 重要なエンドポイントには必ずヘルスチェックを設定
- 適切なしきい値とチェック間隔を設定
- CloudWatch Alarmと連携して通知

### 3. エイリアスレコードの使用

```typescript
// CNAMEではなくAliasレコードを使用（追加料金なし）
// ○ Alias
await createAliasRecord(
  hostedZoneId,
  'example.com',
  'xxxxx.cloudfront.net',
  'Z2FDTNDATAQYW2'
)

// × CNAME（Apexドメインには使用不可）
// await createCNAMERecord(hostedZoneId, 'example.com', 'xxxxx.cloudfront.net')
```

### 4. タグ付けによる管理

```typescript
import { ChangeTagsForResourceCommand } from '@aws-sdk/client-route-53'

async function tagHostedZone(hostedZoneId: string) {
  const command = new ChangeTagsForResourceCommand({
    ResourceType: 'hostedzone',
    ResourceId: hostedZoneId,
    AddTags: [
      { Key: 'Environment', Value: 'production' },
      { Key: 'Project', Value: 'my-app' },
      { Key: 'ManagedBy', Value: 'terraform' },
    ],
  })

  await route53Client.send(command)
}
```

### 5. 変更前のバックアップ

```typescript
// レコード変更前に現在の設定をバックアップ
async function backupRecordSets(hostedZoneId: string) {
  const recordSets = await listRecordSets(hostedZoneId)
  const backup = {
    timestamp: new Date().toISOString(),
    hostedZoneId,
    recordSets,
  }

  // JSONファイルとして保存
  const fs = require('fs')
  fs.writeFileSync(
    `route53-backup-${Date.now()}.json`,
    JSON.stringify(backup, null, 2)
  )

  return backup
}
```

## トラブルシューティング

### DNSの伝播確認

```bash
# 特定のネームサーバーに問い合わせ
dig @8.8.8.8 example.com

# Route53のネームサーバーに直接問い合わせ
dig @ns-123.awsdns-12.com example.com

# 詳細情報の取得
dig example.com +trace

# 特定のレコードタイプを確認
dig example.com MX
dig example.com TXT
```

### Node.jsでのDNSルックアップ

```typescript
import { promises as dns } from 'dns'

async function checkDNS(domain: string) {
  try {
    const addresses = await dns.resolve4(domain)
    console.log('A records:', addresses)

    const mxRecords = await dns.resolveMx(domain)
    console.log('MX records:', mxRecords)

    const txtRecords = await dns.resolveTxt(domain)
    console.log('TXT records:', txtRecords)
  } catch (error) {
    console.error('DNS lookup failed:', error)
  }
}
```

### よくあるエラーと対処法

#### 1. InvalidChangeBatch

```text
原因: レコードの形式が不正、または矛盾する変更
対処: 既存レコードの正確な情報を取得してから削除・更新
```

#### 2. HostedZoneNotEmpty

```text
原因: ホストゾーンにレコードが残っている
対処: NS/SOAレコード以外を全て削除してから削除
```

#### 3. PriorRequestNotComplete

```text
原因: 前回の変更がまだ処理中
対処: 変更完了を待ってから次の変更を実行
```

## コスト最適化

### 料金体系

- **ホストゾーン**: $0.50/月（最初の25個）
- **標準クエリ**: 100万クエリあたり $0.40
- **レイテンシベースクエリ**: 100万クエリあたり $0.60
- **地理的位置クエリ**: 100万クエリあたり $0.70
- **ヘルスチェック**: $0.50/月（AWSエンドポイント以外）

### コスト削減のヒント

1. **不要なホストゾーンを削除**: 使っていないホストゾーンは削除
2. **ヘルスチェックの最適化**: 必要最小限のヘルスチェックのみ設定
3. **TTLの最適化**: 適切なTTLでクエリ数を削減
4. **Aliasレコードの活用**: Aliasレコードへのクエリは無料

## セキュリティ

### 1. DNSSEC の有効化

```bash
# DNSSEC を有効化
aws route53 enable-hosted-zone-dnssec \
  --hosted-zone-id Z1234567890ABC
```

### 2. CAA レコードの設定

```typescript
// 証明書発行を特定のCAに制限
async function createCAARecord(hostedZoneId: string, domain: string) {
  const command = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'CREATE',
          ResourceRecordSet: {
            Name: domain,
            Type: 'CAA',
            TTL: 300,
            ResourceRecords: [
              { Value: '0 issue "letsencrypt.org"' },
              { Value: '0 issuewild "letsencrypt.org"' },
            ],
          },
        },
      ],
    },
  })

  await route53Client.send(command)
}
```

### 3. アクセス制御

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetHostedZone",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/Z1234567890ABC"
    }
  ]
}
```

## 参考リンク

- [AWS Route53 公式ドキュメント](https://docs.aws.amazon.com/route53/)
- [AWS SDK for JavaScript v3 - Route53](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-route-53/)
- [Route53 料金](https://aws.amazon.com/route53/pricing/)
- [Route53 サービスクォータ](https://docs.aws.amazon.com/route53/latest/DeveloperGuide/DNSLimitations.html)
- [DNS仕様 (RFC 1035)](https://www.ietf.org/rfc/rfc1035.txt)
