# Amazon CloudFront 完全ガイド

## 目次
1. [CloudFrontとは](#cloudfrontとは)
2. [基本概念](#基本概念)
3. [セットアップ](#セットアップ)
4. [ディストリビューション設定](#ディストリビューション設定)
5. [キャッシュ戦略](#キャッシュ戦略)
6. [オリジン設定](#オリジン設定)
7. [セキュリティ](#セキュリティ)
8. [Lambda@Edge と CloudFront Functions](#lambdaedge-と-cloudfront-functions)
9. [実装例](#実装例)
10. [パフォーマンス最適化](#パフォーマンス最適化)
11. [モニタリング](#モニタリング)
12. [ベストプラクティス](#ベストプラクティス)

---

## CloudFrontとは

Amazon CloudFrontは、AWSが提供するグローバルCDN（Content Delivery Network）サービスです。

### 主な機能

- **グローバル配信**: 世界450以上のエッジロケーション
- **低レイテンシ**: ユーザーに最も近いエッジからコンテンツ配信
- **DDoS保護**: AWS Shield Standardが自動的に有効
- **HTTPS対応**: SSL/TLS証明書の無料提供（ACM）
- **カスタマイズ**: Lambda@EdgeやCloudFront Functionsでリクエスト/レスポンス処理
- **圧縮**: Gzip/Brotli圧縮対応

### ユースケース

- 静的Webサイトの配信
- 動的コンテンツの高速化
- ビデオストリーミング
- API アクセラレーション
- セキュリティ強化

---

## 基本概念

### CloudFrontの仕組み

```
┌──────────┐
│  User    │
└────┬─────┘
     │ 1. Request
     ▼
┌─────────────────┐
│  CloudFront     │
│  Edge Location  │
└────┬────────────┘
     │ 2. Cache Miss → Origin Request
     ▼
┌─────────────────┐
│   Origin        │
│  (S3/ALB/EC2)   │
└─────────────────┘

Cache Hit → 即座にレスポンス
Cache Miss → オリジンから取得 → キャッシュ → レスポンス
```

### 主要コンポーネント

- **Distribution**: CloudFrontの配信設定
- **Origin**: コンテンツの配信元（S3、ALB、EC2など）
- **Behavior**: URLパスパターンごとの動作設定
- **Cache Policy**: キャッシュの動作を定義
- **Origin Request Policy**: オリジンへのリクエスト設定
- **Edge Function**: リクエスト/レスポンスの処理

---

## セットアップ

### AWS CLIでの作成

```bash
# S3バケットの作成
aws s3 mb s3://my-cloudfront-origin

# ディストリビューションの作成
aws cloudfront create-distribution \
  --origin-domain-name my-cloudfront-origin.s3.amazonaws.com \
  --default-root-object index.html
```

### AWS CDKでの作成

```typescript
import * as cdk from 'aws-cdk-lib';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';
import * as acm from 'aws-cdk-lib/aws-certificatemanager';

export class CloudFrontStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // S3バケット（オリジン）
    const websiteBucket = new s3.Bucket(this, 'WebsiteBucket', {
      bucketName: 'my-cloudfront-origin',
      publicReadAccess: false, // OAIを使用するため非公開
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // Origin Access Identity（OAI）
    const oai = new cloudfront.OriginAccessIdentity(this, 'OAI', {
      comment: 'OAI for CloudFront to access S3',
    });

    // S3バケットポリシー（CloudFrontからのアクセスのみ許可）
    websiteBucket.grantRead(oai);

    // SSL証明書（us-east-1リージョンで作成）
    const certificate = acm.Certificate.fromCertificateArn(
      this,
      'Certificate',
      'arn:aws:acm:us-east-1:123456789012:certificate/xxxxx'
    );

    // CloudFront Distribution
    const distribution = new cloudfront.Distribution(this, 'Distribution', {
      defaultBehavior: {
        origin: new origins.S3Origin(websiteBucket, {
          originAccessIdentity: oai,
        }),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
        cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD_OPTIONS,
        compress: true,
        cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
      },
      domainNames: ['example.com', 'www.example.com'],
      certificate: certificate,
      defaultRootObject: 'index.html',
      errorResponses: [
        {
          httpStatus: 404,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: cdk.Duration.minutes(5),
        },
        {
          httpStatus: 403,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: cdk.Duration.minutes(5),
        },
      ],
      enableLogging: true,
      logBucket: new s3.Bucket(this, 'LogBucket', {
        removalPolicy: cdk.RemovalPolicy.DESTROY,
        autoDeleteObjects: true,
      }),
      priceClass: cloudfront.PriceClass.PRICE_CLASS_100,
    });

    // S3へのデプロイ
    new s3deploy.BucketDeployment(this, 'DeployWebsite', {
      sources: [s3deploy.Source.asset('./website')],
      destinationBucket: websiteBucket,
      distribution,
      distributionPaths: ['/*'],
    });

    // 出力
    new cdk.CfnOutput(this, 'DistributionDomainName', {
      value: distribution.distributionDomainName,
    });

    new cdk.CfnOutput(this, 'DistributionId', {
      value: distribution.distributionId,
    });
  }
}
```

---

## ディストリビューション設定

### マルチオリジン構成

```typescript
const distribution = new cloudfront.Distribution(this, 'Distribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(websiteBucket, {
      originAccessIdentity: oai,
    }),
    viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
  },
  additionalBehaviors: {
    // APIリクエストは ALB へ
    '/api/*': {
      origin: new origins.LoadBalancerV2Origin(alb, {
        protocolPolicy: cloudfront.OriginProtocolPolicy.HTTPS_ONLY,
        customHeaders: {
          'X-Custom-Header': 'value',
        },
      }),
      allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
      cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
      originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
    },
    // 画像は別のS3バケットから
    '/images/*': {
      origin: new origins.S3Origin(imageBucket),
      compress: true,
      cachePolicy: new cloudfront.CachePolicy(this, 'ImageCachePolicy', {
        cachePolicyName: 'ImageCachePolicy',
        defaultTtl: cdk.Duration.days(30),
        maxTtl: cdk.Duration.days(365),
        minTtl: cdk.Duration.days(1),
        enableAcceptEncodingGzip: true,
        enableAcceptEncodingBrotli: true,
      }),
    },
  },
});
```

### カスタムドメイン設定

```typescript
import * as route53 from 'aws-cdk-lib/aws-route53';
import * as targets from 'aws-cdk-lib/aws-route53-targets';

// Route53ホストゾーン
const hostedZone = route53.HostedZone.fromLookup(this, 'HostedZone', {
  domainName: 'example.com',
});

// Aレコード（Alias）
new route53.ARecord(this, 'AliasRecord', {
  zone: hostedZone,
  recordName: 'www',
  target: route53.RecordTarget.fromAlias(
    new targets.CloudFrontTarget(distribution)
  ),
});

// AAAAレコード（IPv6）
new route53.AaaaRecord(this, 'AliasRecordIPv6', {
  zone: hostedZone,
  recordName: 'www',
  target: route53.RecordTarget.fromAlias(
    new targets.CloudFrontTarget(distribution)
  ),
});
```

---

## キャッシュ戦略

### Cache Policy

```typescript
// カスタムキャッシュポリシー
const customCachePolicy = new cloudfront.CachePolicy(this, 'CustomCachePolicy', {
  cachePolicyName: 'CustomCachePolicy',
  comment: 'Custom cache policy for dynamic content',
  defaultTtl: cdk.Duration.minutes(5),
  maxTtl: cdk.Duration.hours(1),
  minTtl: cdk.Duration.seconds(1),
  enableAcceptEncodingGzip: true,
  enableAcceptEncodingBrotli: true,
  headerBehavior: cloudfront.CacheHeaderBehavior.allowList(
    'Authorization',
    'CloudFront-Viewer-Country'
  ),
  queryStringBehavior: cloudfront.CacheQueryStringBehavior.allowList(
    'page',
    'limit',
    'sort'
  ),
  cookieBehavior: cloudfront.CacheCookieBehavior.allowList(
    'session-id',
    'user-preferences'
  ),
});
```

### Cache Key の設定

```typescript
// クエリパラメータでキャッシュ分ける
const cachePolicy = new cloudfront.CachePolicy(this, 'QueryStringCachePolicy', {
  queryStringBehavior: cloudfront.CacheQueryStringBehavior.all(), // 全て含める
  // または特定のパラメータのみ
  // queryStringBehavior: cloudfront.CacheQueryStringBehavior.allowList('id', 'lang'),
});

// Cookieでキャッシュを分ける
const cookieCachePolicy = new cloudfront.CachePolicy(this, 'CookieCachePolicy', {
  cookieBehavior: cloudfront.CacheCookieBehavior.allowList('session-id'),
});

// ヘッダーでキャッシュを分ける
const headerCachePolicy = new cloudfront.CachePolicy(this, 'HeaderCachePolicy', {
  headerBehavior: cloudfront.CacheHeaderBehavior.allowList(
    'Accept-Language',
    'Accept-Encoding'
  ),
});
```

### キャッシュ無効化（Invalidation）

```bash
# AWS CLI
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/*"

# 特定のパスのみ
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/images/*" "/css/*"
```

```typescript
// CDK
import * as cr from 'aws-cdk-lib/custom-resources';

new cr.AwsCustomResource(this, 'InvalidateCache', {
  onUpdate: {
    service: 'CloudFront',
    action: 'createInvalidation',
    parameters: {
      DistributionId: distribution.distributionId,
      InvalidationBatch: {
        CallerReference: Date.now().toString(),
        Paths: {
          Quantity: 1,
          Items: ['/*'],
        },
      },
    },
    physicalResourceId: cr.PhysicalResourceId.of(Date.now().toString()),
  },
  policy: cr.AwsCustomResourcePolicy.fromSdkCalls({
    resources: cr.AwsCustomResourcePolicy.ANY_RESOURCE,
  }),
});
```

---

## オリジン設定

### S3オリジン

```typescript
const s3Origin = new origins.S3Origin(bucket, {
  originAccessIdentity: oai,
  originPath: '/production', // S3内のパス
  customHeaders: {
    'X-Custom-Header': 'value',
  },
  connectionAttempts: 3,
  connectionTimeout: cdk.Duration.seconds(10),
});
```

### ALB/NLBオリジン

```typescript
const albOrigin = new origins.LoadBalancerV2Origin(alb, {
  protocolPolicy: cloudfront.OriginProtocolPolicy.HTTPS_ONLY,
  httpsPort: 443,
  customHeaders: {
    'X-Forwarded-From': 'CloudFront',
  },
  originShieldRegion: 'us-east-1', // Origin Shield有効化
  connectionAttempts: 3,
  connectionTimeout: cdk.Duration.seconds(10),
  readTimeout: cdk.Duration.seconds(60),
  keepaliveTimeout: cdk.Duration.seconds(5),
});
```

### カスタムオリジン

```typescript
const customOrigin = new origins.HttpOrigin('api.example.com', {
  protocolPolicy: cloudfront.OriginProtocolPolicy.HTTPS_ONLY,
  httpsPort: 443,
  customHeaders: {
    'X-API-Key': 'secret-key',
  },
  originSslProtocols: [cloudfront.OriginSslPolicy.TLS_V1_2],
});
```

### フェイルオーバー構成

```typescript
const originGroup = new origins.OriginGroup({
  primaryOrigin: new origins.S3Origin(primaryBucket),
  fallbackOrigin: new origins.S3Origin(fallbackBucket),
  fallbackStatusCodes: [500, 502, 503, 504],
});

const distribution = new cloudfront.Distribution(this, 'Distribution', {
  defaultBehavior: {
    origin: originGroup,
  },
});
```

---

## セキュリティ

### WAF統合

```typescript
import * as wafv2 from 'aws-cdk-lib/aws-wafv2';

// WAF Web ACL
const webAcl = new wafv2.CfnWebACL(this, 'WebAcl', {
  scope: 'CLOUDFRONT',
  defaultAction: { allow: {} },
  rules: [
    {
      name: 'RateLimitRule',
      priority: 1,
      statement: {
        rateBasedStatement: {
          limit: 2000,
          aggregateKeyType: 'IP',
        },
      },
      action: { block: {} },
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: 'RateLimitRule',
      },
    },
    {
      name: 'AWSManagedRulesCommonRuleSet',
      priority: 2,
      statement: {
        managedRuleGroupStatement: {
          vendorName: 'AWS',
          name: 'AWSManagedRulesCommonRuleSet',
        },
      },
      overrideAction: { none: {} },
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: 'AWSManagedRulesCommonRuleSet',
      },
    },
  ],
  visibilityConfig: {
    sampledRequestsEnabled: true,
    cloudWatchMetricsEnabled: true,
    metricName: 'WebAcl',
  },
});

// CloudFrontにWAFを適用
const distribution = new cloudfront.Distribution(this, 'Distribution', {
  webAclId: webAcl.attrArn,
  // ...
});
```

### Signed URL / Signed Cookie

```typescript
import * as iam from 'aws-cdk-lib/aws-iam';

// CloudFront Key Group（推奨）
const publicKey = new cloudfront.PublicKey(this, 'PublicKey', {
  encodedKey: `-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----`,
});

const keyGroup = new cloudfront.KeyGroup(this, 'KeyGroup', {
  items: [publicKey],
});

const distribution = new cloudfront.Distribution(this, 'Distribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(bucket),
    trustedKeyGroups: [keyGroup],
  },
});
```

#### Signed URLの生成（Node.js）

```typescript
import { getSignedUrl } from '@aws-sdk/cloudfront-signer';
import { readFileSync } from 'fs';

function generateSignedUrl(url: string, expirationMinutes: number = 60) {
  const privateKey = readFileSync('./private-key.pem', 'utf8');
  const keyPairId = 'APKAXXXXXXXXXXXXXXXX';

  const dateLessThan = new Date();
  dateLessThan.setMinutes(dateLessThan.getMinutes() + expirationMinutes);

  const signedUrl = getSignedUrl({
    url,
    keyPairId,
    dateLessThan: dateLessThan.toISOString(),
    privateKey,
  });

  return signedUrl;
}

// 使用例
const url = 'https://d123456789.cloudfront.net/private/video.mp4';
const signedUrl = generateSignedUrl(url, 60);
console.log(signedUrl);
```

### OAC（Origin Access Control）

```typescript
// S3へのアクセスをCloudFrontのみに制限（OACを使用）
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';

const oac = new cloudfront.CfnOriginAccessControl(this, 'OAC', {
  originAccessControlConfig: {
    name: 'OAC for S3',
    originAccessControlOriginType: 's3',
    signingBehavior: 'always',
    signingProtocol: 'sigv4',
  },
});

const cfnDistribution = distribution.node.defaultChild as cloudfront.CfnDistribution;
cfnDistribution.addPropertyOverride(
  'DistributionConfig.Origins.0.S3OriginConfig.OriginAccessIdentity',
  ''
);
cfnDistribution.addPropertyOverride(
  'DistributionConfig.Origins.0.OriginAccessControlId',
  oac.attrId
);
```

### Geo Restriction

```typescript
const distribution = new cloudfront.Distribution(this, 'Distribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(bucket),
  },
  geoRestriction: cloudfront.GeoRestriction.allowlist('US', 'CA', 'JP'),
  // またはブロックリスト
  // geoRestriction: cloudfront.GeoRestriction.denylist('CN', 'RU'),
});
```

---

## Lambda@Edge と CloudFront Functions

### CloudFront Functions

```typescript
// CloudFront Function（軽量・高速）
const cfFunction = new cloudfront.Function(this, 'Function', {
  code: cloudfront.FunctionCode.fromInline(`
    function handler(event) {
      var request = event.request;
      var uri = request.uri;

      // URIを正規化（末尾スラッシュを追加）
      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      } else if (!uri.includes('.')) {
        request.uri += '/index.html';
      }

      // セキュリティヘッダーを追加
      request.headers['x-frame-options'] = { value: 'DENY' };
      request.headers['x-content-type-options'] = { value: 'nosniff' };
      request.headers['x-xss-protection'] = { value: '1; mode=block' };

      return request;
    }
  `),
});

const distribution = new cloudfront.Distribution(this, 'Distribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(bucket),
    functionAssociations: [
      {
        function: cfFunction,
        eventType: cloudfront.FunctionEventType.VIEWER_REQUEST,
      },
    ],
  },
});
```

### Lambda@Edge

```typescript
import * as lambda from 'aws-cdk-lib/aws-lambda';

// Lambda@Edge（重い処理向け）
const edgeLambda = new cloudfront.experimental.EdgeFunction(this, 'EdgeFunction', {
  runtime: lambda.Runtime.NODEJS_18_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset('lambda/edge'),
});

const distribution = new cloudfront.Distribution(this, 'Distribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(bucket),
    edgeLambdas: [
      {
        functionVersion: edgeLambda.currentVersion,
        eventType: cloudfront.LambdaEdgeEventType.VIEWER_REQUEST,
      },
    ],
  },
});
```

#### Lambda@Edge 実装例

```typescript
// lambda/edge/index.ts
import { CloudFrontRequestEvent, CloudFrontRequestResult } from 'aws-lambda';

// A/Bテスト
export const handler = async (
  event: CloudFrontRequestEvent
): Promise<CloudFrontRequestResult> => {
  const request = event.Records[0].cf.request;
  const headers = request.headers;

  // Cookieチェック
  const cookie = headers.cookie?.[0]?.value || '';
  let variant = 'A';

  if (cookie.includes('variant=B')) {
    variant = 'B';
  } else if (!cookie.includes('variant=')) {
    // ランダムに割り振り
    variant = Math.random() < 0.5 ? 'A' : 'B';
    headers.cookie = [
      {
        key: 'Cookie',
        value: `variant=${variant}`,
      },
    ];
  }

  // URIを書き換え
  request.uri = `/variants/${variant}${request.uri}`;

  return request;
};

// 認証チェック
export const authHandler = async (
  event: CloudFrontRequestEvent
): Promise<CloudFrontRequestResult> => {
  const request = event.Records[0].cf.request;
  const headers = request.headers;

  // Authorizationヘッダーチェック
  const authHeader = headers.authorization?.[0]?.value;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return {
      status: '401',
      statusDescription: 'Unauthorized',
      headers: {
        'www-authenticate': [{ key: 'WWW-Authenticate', value: 'Bearer' }],
      },
    };
  }

  // JWTトークン検証（実際にはライブラリを使用）
  const token = authHeader.substring(7);
  const isValid = await verifyToken(token);

  if (!isValid) {
    return {
      status: '403',
      statusDescription: 'Forbidden',
    };
  }

  return request;
};

async function verifyToken(token: string): Promise<boolean> {
  // JWT検証ロジック
  return true;
}

// 画像リサイズ
import sharp from 'sharp';

export const imageHandler = async (
  event: CloudFrontRequestEvent
): Promise<CloudFrontRequestResult> => {
  const request = event.Records[0].cf.request;
  const querystring = request.querystring;

  // クエリパラメータから幅・高さを取得
  const params = new URLSearchParams(querystring);
  const width = parseInt(params.get('w') || '0');
  const height = parseInt(params.get('h') || '0');

  if (!width && !height) {
    return request;
  }

  // オリジンから画像取得（実装省略）
  // const originalImage = await fetchFromOrigin(request.uri);

  // リサイズ
  // const resizedImage = await sharp(originalImage)
  //   .resize(width, height)
  //   .toBuffer();

  // レスポンスを返す
  return {
    status: '200',
    headers: {
      'content-type': [{ key: 'Content-Type', value: 'image/jpeg' }],
    },
    // body: resizedImage.toString('base64'),
    // bodyEncoding: 'base64',
  };
};
```

---

## 実装例

### Next.js + CloudFront

```typescript
// Next.jsアプリ用のCloudFront設定
const distribution = new cloudfront.Distribution(this, 'NextJsDistribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(bucket, { originAccessIdentity: oai }),
    viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
    allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
    compress: true,
    cachePolicy: new cloudfront.CachePolicy(this, 'NextJsCachePolicy', {
      queryStringBehavior: cloudfront.CacheQueryStringBehavior.all(),
      headerBehavior: cloudfront.CacheHeaderBehavior.allowList(
        'Accept',
        'Accept-Language'
      ),
      cookieBehavior: cloudfront.CacheCookieBehavior.none(),
      defaultTtl: cdk.Duration.seconds(0),
      maxTtl: cdk.Duration.days(365),
      minTtl: cdk.Duration.seconds(0),
      enableAcceptEncodingGzip: true,
      enableAcceptEncodingBrotli: true,
    }),
  },
  additionalBehaviors: {
    // 静的アセット（長期キャッシュ）
    '/_next/static/*': {
      origin: new origins.S3Origin(bucket, { originAccessIdentity: oai }),
      compress: true,
      cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
    },
    // API Routes（キャッシュなし）
    '/api/*': {
      origin: new origins.HttpOrigin('api.example.com'),
      allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
      cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
      originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
    },
  },
  errorResponses: [
    {
      httpStatus: 404,
      responseHttpStatus: 404,
      responsePagePath: '/404.html',
    },
    {
      httpStatus: 500,
      responseHttpStatus: 500,
      responsePagePath: '/500.html',
    },
  ],
});
```

### SPA（React/Vue）+ CloudFront

```typescript
const distribution = new cloudfront.Distribution(this, 'SpaDistribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(bucket, { originAccessIdentity: oai }),
    viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
    compress: true,
  },
  defaultRootObject: 'index.html',
  errorResponses: [
    // SPAルーティングのため、全て index.html にリダイレクト
    {
      httpStatus: 403,
      responseHttpStatus: 200,
      responsePagePath: '/index.html',
      ttl: cdk.Duration.minutes(5),
    },
    {
      httpStatus: 404,
      responseHttpStatus: 200,
      responsePagePath: '/index.html',
      ttl: cdk.Duration.minutes(5),
    },
  ],
});
```

---

## パフォーマンス最適化

### 圧縮の有効化

```typescript
const distribution = new cloudfront.Distribution(this, 'Distribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(bucket),
    compress: true, // Gzip/Brotli圧縮を有効化
  },
});
```

### HTTP/2 と HTTP/3

```typescript
// HTTP/2は自動的に有効
// HTTP/3の有効化
const cfnDistribution = distribution.node.defaultChild as cloudfront.CfnDistribution;
cfnDistribution.addPropertyOverride('DistributionConfig.HttpVersion', 'http2and3');
```

### Origin Shield

```typescript
const origin = new origins.LoadBalancerV2Origin(alb, {
  originShieldRegion: 'us-east-1', // Origin Shieldを有効化
});
```

### Cache Hit Ratio の向上

```typescript
// クエリパラメータを制限
const cachePolicy = new cloudfront.CachePolicy(this, 'OptimizedCachePolicy', {
  queryStringBehavior: cloudfront.CacheQueryStringBehavior.allowList(
    'page', 'id' // 必要なパラメータのみ
  ),
  // 不要なヘッダーを除外
  headerBehavior: cloudfront.CacheHeaderBehavior.none(),
  // Cookieは含めない
  cookieBehavior: cloudfront.CacheCookieBehavior.none(),
});
```

---

## モニタリング

### CloudWatch メトリクス

```typescript
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';

// CloudFrontメトリクス
const requestsMetric = new cloudwatch.Metric({
  namespace: 'AWS/CloudFront',
  metricName: 'Requests',
  dimensionsMap: {
    DistributionId: distribution.distributionId,
  },
  statistic: 'Sum',
  period: cdk.Duration.minutes(5),
});

const errorRateMetric = new cloudwatch.MathExpression({
  expression: '(m1 / m2) * 100',
  usingMetrics: {
    m1: new cloudwatch.Metric({
      namespace: 'AWS/CloudFront',
      metricName: '4xxErrorRate',
      dimensionsMap: {
        DistributionId: distribution.distributionId,
      },
      statistic: 'Average',
    }),
    m2: requestsMetric,
  },
});

// アラーム
new cloudwatch.Alarm(this, 'HighErrorRateAlarm', {
  metric: errorRateMetric,
  threshold: 5,
  evaluationPeriods: 2,
  alarmDescription: 'Alert when error rate exceeds 5%',
});
```

### アクセスログ

```typescript
const logBucket = new s3.Bucket(this, 'LogBucket', {
  bucketName: 'cloudfront-logs',
  removalPolicy: cdk.RemovalPolicy.DESTROY,
  autoDeleteObjects: true,
  lifecycleRules: [
    {
      expiration: cdk.Duration.days(90), // 90日後に削除
      transitions: [
        {
          storageClass: s3.StorageClass.GLACIER,
          transitionAfter: cdk.Duration.days(30),
        },
      ],
    },
  ],
});

const distribution = new cloudfront.Distribution(this, 'Distribution', {
  enableLogging: true,
  logBucket: logBucket,
  logFilePrefix: 'cloudfront/',
  logIncludesCookies: true,
});
```

---

## ベストプラクティス

### 1. セキュリティ

```typescript
// 推奨設定
const distribution = new cloudfront.Distribution(this, 'SecureDistribution', {
  defaultBehavior: {
    origin: new origins.S3Origin(bucket, { originAccessIdentity: oai }),
    // HTTPSのみ
    viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
    // TLS 1.2以上
  },
  // 最小TLSバージョン
  minimumProtocolVersion: cloudfront.SecurityPolicyProtocol.TLS_V1_2_2021,
  // WAF統合
  webAclId: webAcl.attrArn,
  // Geo制限
  geoRestriction: cloudfront.GeoRestriction.allowlist('US', 'JP'),
});
```

### 2. コスト最適化

```typescript
// Price Class の選択
const distribution = new cloudfront.Distribution(this, 'Distribution', {
  // 米国・カナダ・欧州のみ（最安）
  priceClass: cloudfront.PriceClass.PRICE_CLASS_100,
  // または全世界（最高パフォーマンス）
  // priceClass: cloudfront.PriceClass.PRICE_CLASS_ALL,
});
```

### 3. キャッシュ戦略

```typescript
// 静的コンテンツ: 長期キャッシュ
{
  '/static/*': {
    origin: new origins.S3Origin(bucket),
    cachePolicy: new cloudfront.CachePolicy(this, 'StaticCachePolicy', {
      defaultTtl: cdk.Duration.days(30),
      maxTtl: cdk.Duration.days(365),
    }),
  },
  // 動的コンテンツ: 短期キャッシュ
  '/api/*': {
    origin: new origins.HttpOrigin('api.example.com'),
    cachePolicy: new cloudfront.CachePolicy(this, 'ApiCachePolicy', {
      defaultTtl: cdk.Duration.minutes(5),
      maxTtl: cdk.Duration.hours(1),
    }),
  },
}
```

### 4. エラーハンドリング

```typescript
errorResponses: [
  {
    httpStatus: 403,
    responseHttpStatus: 200,
    responsePagePath: '/index.html',
    ttl: cdk.Duration.minutes(5),
  },
  {
    httpStatus: 404,
    responseHttpStatus: 404,
    responsePagePath: '/404.html',
    ttl: cdk.Duration.minutes(10),
  },
  {
    httpStatus: 500,
    responseHttpStatus: 500,
    responsePagePath: '/500.html',
    ttl: cdk.Duration.seconds(10),
  },
  {
    httpStatus: 503,
    responseHttpStatus: 503,
    responsePagePath: '/503.html',
    ttl: cdk.Duration.seconds(10),
  },
]
```

---

## 参考リンク

- [Amazon CloudFront 公式ドキュメント](https://docs.aws.amazon.com/cloudfront/)
- [CloudFront Developer Guide](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
- [Lambda@Edge](https://docs.aws.amazon.com/lambda/latest/dg/lambda-edge.html)
- [CloudFront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html)
