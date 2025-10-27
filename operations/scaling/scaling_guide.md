# スケーリングガイド

> 最終更新: 2025-10-27
> 難易度: 中級〜上級

## 概要

スケーリングは、増加するトラフィックや負荷に対応するためにシステムの能力を拡張することです。適切なスケーリング戦略により、コストを最適化しながらパフォーマンスを維持できます。

---

## スケーリングの種類

### 垂直スケーリング（Vertical Scaling / Scale Up）

**定義**: サーバーのスペックを向上させる

**メリット**:
- 実装がシンプル
- アプリケーション変更不要
- データ整合性の問題なし

**デメリット**:
- スケールの上限がある
- ダウンタイムが発生する場合がある
- コストが非線形に増加
- 単一障害点（SPOF）

**実装例（AWS EC2）**:

```bash
# インスタンスタイプを変更
# t3.medium → t3.xlarge

# 1. インスタンスを停止
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# 2. インスタンスタイプを変更
aws ec2 modify-instance-attribute \
  --instance-id i-1234567890abcdef0 \
  --instance-type "{\"Value\": \"t3.xlarge\"}"

# 3. インスタンスを起動
aws ec2 start-instances --instance-ids i-1234567890abcdef0
```

**適用シーン**:
- レガシーアプリケーション（分散非対応）
- データベース（初期段階）
- 開発・テスト環境

---

### 水平スケーリング（Horizontal Scaling / Scale Out）

**定義**: サーバーの台数を増やす

**メリット**:
- 理論上無限にスケール可能
- 冗長性・可用性の向上
- ダウンタイムなし
- コストが線形に増加

**デメリット**:
- アプリケーション設計が複雑
- ステートレス化が必要
- ロードバランサーが必要
- データ整合性の考慮が必要

**実装例（Kubernetes HPA）**:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 3
  maxReplicas: 20
  metrics:
    # CPU使用率が70%を超えたらスケールアウト
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    # メモリ使用率が80%を超えたらスケールアウト
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    # カスタムメトリクス: リクエスト数
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5分間安定してから縮小
      policies:
      - type: Percent
        value: 50  # 一度に50%まで縮小
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0  # 即座にスケールアップ
      policies:
      - type: Percent
        value: 100  # 一度に2倍までスケールアップ
        periodSeconds: 60
      - type: Pods
        value: 4  # または最大4台追加
        periodSeconds: 60
      selectPolicy: Max  # より積極的な方を選択
```

**適用シーン**:
- Webアプリケーション
- APIサーバー
- マイクロサービス
- コンテナ化されたアプリケーション

---

## オートスケーリング戦略

### 1. スケジュールベース（Scheduled Scaling）

**定義**: 予測可能な負荷パターンに基づいて事前にスケール

**実装例（AWS Auto Scaling）**:

```hcl
# 平日の営業時間に自動でスケールアップ
resource "aws_autoscaling_schedule" "scale_up_morning" {
  scheduled_action_name  = "scale-up-morning"
  min_size               = 5
  max_size               = 20
  desired_capacity       = 10
  recurrence            = "0 8 * * MON-FRI"  # 平日 8:00
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# 夜間は縮小
resource "aws_autoscaling_schedule" "scale_down_night" {
  scheduled_action_name  = "scale-down-night"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 3
  recurrence            = "0 22 * * *"  # 毎日 22:00
  autoscaling_group_name = aws_autoscaling_group.web.name
}
```

**適用シーン**:
- 営業時間が明確なビジネスアプリケーション
- バッチ処理の前にスケールアップ
- イベント（セール、キャンペーン）の事前準備

---

### 2. メトリクスベース（Metric-based Scaling）

**定義**: リアルタイムのメトリクスに基づいて動的にスケール

**AWS Auto Scaling Policy**:

```hcl
resource "aws_autoscaling_policy" "cpu_scaling" {
  name                   = "cpu-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0  # CPU 70%を目標値に維持
  }
}

# カスタムメトリクス（SQS キューの長さ）
resource "aws_autoscaling_policy" "sqs_scaling" {
  name                   = "sqs-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    customized_metric_specification {
      metric_dimension {
        name  = "QueueName"
        value = "processing-queue"
      }
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"
    }
    target_value = 100  # キュー内のメッセージ数を100件程度に維持
  }
}
```

**適用シーン**:
- 予測不可能なトラフィック変動
- リアルタイムでの負荷対応
- ワーカープロセス（キュー処理）

---

### 3. 予測スケーリング（Predictive Scaling）

**定義**: 機械学習で負荷を予測し、事前にスケール

**AWS Predictive Scaling**:

```hcl
resource "aws_autoscaling_policy" "predictive" {
  name                   = "predictive-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "PredictiveScaling"

  predictive_scaling_configuration {
    metric_specification {
      target_value = 70
      predefined_scaling_metric_specification {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
    }
    mode                         = "ForecastAndScale"
    scheduling_buffer_time       = 600  # 10分前にスケール開始
  }
}
```

**適用シーン**:
- 定期的なトラフィックパターンがあるサービス
- 急激な負荷増加が予想されるイベント
- コスト最適化が重要なシステム

---

## データベーススケーリング

### リードレプリカ（Read Replica）

**目的**: 読み取りクエリを分散

**実装例（PostgreSQL on RDS）**:

```hcl
# プライマリDB
resource "aws_db_instance" "primary" {
  identifier          = "mydb-primary"
  engine              = "postgres"
  engine_version      = "14.7"
  instance_class      = "db.r6g.xlarge"
  allocated_storage   = 100
  multi_az            = true  # 高可用性

  backup_retention_period = 7
}

# リードレプリカ (東京リージョン)
resource "aws_db_instance" "read_replica_1" {
  identifier             = "mydb-replica-1"
  replicate_source_db    = aws_db_instance.primary.identifier
  instance_class         = "db.r6g.large"
  publicly_accessible    = false
}

# リードレプリカ (大阪リージョン)
resource "aws_db_instance" "read_replica_2" {
  provider               = aws.osaka
  identifier             = "mydb-replica-2"
  replicate_source_db    = aws_db_instance.primary.arn
  instance_class         = "db.r6g.large"
}
```

**アプリケーション実装**:

```typescript
import { Pool } from 'pg'

// プライマリ（書き込み用）
const primaryPool = new Pool({
  host: 'mydb-primary.abc123.ap-northeast-1.rds.amazonaws.com',
  database: 'myapp',
  max: 20,
})

// リードレプリカ（読み取り用）
const replicaPools = [
  new Pool({
    host: 'mydb-replica-1.abc123.ap-northeast-1.rds.amazonaws.com',
    database: 'myapp',
    max: 20,
  }),
  new Pool({
    host: 'mydb-replica-2.abc123.ap-northeast-3.rds.amazonaws.com',
    database: 'myapp',
    max: 20,
  }),
]

// ラウンドロビンでリードレプリカを選択
let replicaIndex = 0
function getReadPool(): Pool {
  const pool = replicaPools[replicaIndex]
  replicaIndex = (replicaIndex + 1) % replicaPools.length
  return pool
}

// 読み取りクエリ
export async function findUser(id: string) {
  const pool = getReadPool()
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [id])
  return result.rows[0]
}

// 書き込みクエリ
export async function createUser(user: User) {
  const result = await primaryPool.query(
    'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
    [user.name, user.email]
  )
  return result.rows[0]
}
```

---

### シャーディング（Sharding）

**定義**: データを複数のデータベースに分割

**シャーディング戦略**:

#### 1. ハッシュベース

```typescript
function getShardId(userId: string, numShards: number): number {
  // ユーザーIDのハッシュ値でシャードを決定
  let hash = 0
  for (let i = 0; i < userId.length; i++) {
    hash = (hash << 5) - hash + userId.charCodeAt(i)
    hash = hash & hash  // 32bit整数に変換
  }
  return Math.abs(hash) % numShards
}

const SHARDS = [
  new Pool({ host: 'shard-0.example.com', database: 'myapp' }),
  new Pool({ host: 'shard-1.example.com', database: 'myapp' }),
  new Pool({ host: 'shard-2.example.com', database: 'myapp' }),
  new Pool({ host: 'shard-3.example.com', database: 'myapp' }),
]

export async function getUserOrders(userId: string) {
  const shardId = getShardId(userId, SHARDS.length)
  const pool = SHARDS[shardId]
  const result = await pool.query(
    'SELECT * FROM orders WHERE user_id = $1',
    [userId]
  )
  return result.rows
}
```

#### 2. 範囲ベース

```typescript
// ユーザーIDの範囲でシャードを決定
// 0-999999   → shard-0
// 1000000-1999999 → shard-1
// ...

function getShardIdByRange(userId: number): number {
  const RANGE_SIZE = 1_000_000
  return Math.floor(userId / RANGE_SIZE)
}
```

---

## キャッシング戦略

### 1. アプリケーションレベルキャッシュ

**Redis を使用した実装**:

```typescript
import Redis from 'ioredis'

const redis = new Redis({
  host: 'cache.example.com',
  port: 6379,
  maxRetriesPerRequest: 3,
})

// キャッシュ aside パターン
export async function getUser(id: string): Promise<User> {
  // 1. キャッシュを確認
  const cached = await redis.get(`user:${id}`)
  if (cached) {
    return JSON.parse(cached)
  }

  // 2. キャッシュミス時はDBから取得
  const user = await db.query('SELECT * FROM users WHERE id = $1', [id])

  // 3. キャッシュに保存（TTL: 1時間）
  await redis.setex(`user:${id}`, 3600, JSON.stringify(user))

  return user
}

// 書き込み時はキャッシュを無効化
export async function updateUser(id: string, data: Partial<User>) {
  await db.query('UPDATE users SET ... WHERE id = $1', [id])

  // キャッシュを削除
  await redis.del(`user:${id}`)
}
```

**キャッシュ戦略の比較**:

| 戦略 | 説明 | メリット | デメリット |
|------|------|---------|-----------|
| **Cache Aside** | アプリがキャッシュを直接管理 | 柔軟性が高い | 実装が複雑 |
| **Read Through** | キャッシュがDBへの読み取りを代行 | 実装がシンプル | キャッシュミス時の遅延 |
| **Write Through** | 書き込み時にキャッシュも更新 | データ整合性が高い | 書き込みが遅い |
| **Write Behind** | 非同期でDBに書き込み | 書き込みが速い | データ損失リスク |

---

### 2. CDN（Content Delivery Network）

**CloudFront 設定例**:

```hcl
resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "My application CDN"

  origin {
    domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id   = "S3-Assets"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }
  }

  # 動的コンテンツ（API）のオリジン
  origin {
    domain_name = "api.example.com"
    origin_id   = "API"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # 静的ファイルのキャッシュ動作
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-Assets"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400   # 1日
    max_ttl     = 31536000  # 1年
  }

  # API のキャッシュ動作
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "API"

    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "https-only"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 60  # 1分
    max_ttl     = 300  # 5分
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.main.arn
    ssl_support_method  = "sni-only"
  }
}
```

---

## ロードバランシング

### Application Load Balancer（ALB）

```hcl
resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = true
  enable_http2              = true
}

resource "aws_lb_target_group" "api" {
  name     = "api-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  # スティッキーセッション（必要に応じて）
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 1日
    enabled         = false
  }

  # Connection Draining
  deregistration_delay = 30
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# パスベースルーティング
resource "aws_lb_listener_rule" "api_v2" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_v2.arn
  }

  condition {
    path_pattern {
      values = ["/api/v2/*"]
    }
  }
}
```

---

## キャパシティプランニング

### トラフィック予測

```python
# 過去のトラフィックデータから予測

import pandas as pd
from sklearn.linear_model import LinearRegression
import numpy as np

# 過去30日間のリクエスト数
data = pd.read_csv('traffic.csv')  # columns: date, requests
data['date'] = pd.to_datetime(data['date'])
data['days'] = (data['date'] - data['date'].min()).dt.days

# 線形回帰モデルで予測
X = data[['days']].values
y = data['requests'].values

model = LinearRegression()
model.fit(X, y)

# 90日後の予測
future_day = data['days'].max() + 90
predicted_requests = model.predict([[future_day]])[0]

print(f"90日後の予測リクエスト数: {predicted_requests:,.0f}")

# 必要なサーバー台数を計算
requests_per_server = 10000  # 1サーバーあたり10,000 req/day
required_servers = np.ceil(predicted_requests / requests_per_server)

print(f"必要なサーバー台数: {required_servers:.0f}")
```

### 負荷テスト

**Apache Bench**:

```bash
# 100並列で10,000リクエスト
ab -n 10000 -c 100 https://api.example.com/users

# 結果分析
# Requests per second:    1000.0 [#/sec] (mean)
# Time per request:       100.0 [ms] (mean, across all concurrent requests)
# Transfer rate:          200.0 [Kbytes/sec]
```

**k6 (より詳細な負荷テスト)**:

```javascript
// load-test.js
import http from 'k6/http'
import { check, sleep } from 'k6'

export let options = {
  stages: [
    { duration: '2m', target: 100 },   // 2分かけて100ユーザーまで増加
    { duration: '5m', target: 100 },   // 5分間100ユーザーを維持
    { duration: '2m', target: 200 },   // 2分かけて200ユーザーまで増加
    { duration: '5m', target: 200 },   // 5分間200ユーザーを維持
    { duration: '2m', target: 0 },     // 2分かけて0まで減少
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95%のリクエストが500ms以内
    http_req_failed: ['rate<0.01'],    // エラー率1%未満
  },
}

export default function () {
  let response = http.get('https://api.example.com/users')

  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  })

  sleep(1)
}
```

```bash
# 実行
k6 run load-test.js

# 結果をInfluxDBに保存
k6 run --out influxdb=http://localhost:8086/k6 load-test.js
```

---

## ベストプラクティス

### 1. ステートレス設計

```typescript
// ❌ 悪い例: サーバーにセッションを保存
const sessions = new Map<string, Session>()

app.post('/login', (req, res) => {
  const sessionId = generateSessionId()
  sessions.set(sessionId, { userId: req.body.userId })
  res.cookie('sessionId', sessionId)
})

// ✅ 良い例: Redisにセッションを保存
import Redis from 'ioredis'
const redis = new Redis()

app.post('/login', async (req, res) => {
  const sessionId = generateSessionId()
  await redis.setex(
    `session:${sessionId}`,
    3600,
    JSON.stringify({ userId: req.body.userId })
  )
  res.cookie('sessionId', sessionId)
})
```

### 2. グレースフルシャットダウン

```typescript
import express from 'express'
import http from 'http'

const app = express()
const server = http.createServer(app)

// グレースフルシャットダウン
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server')

  server.close(() => {
    console.log('HTTP server closed')

    // データベース接続をクローズ
    db.close(() => {
      console.log('Database connection closed')
      process.exit(0)
    })
  })

  // 30秒以内に終了しない場合は強制終了
  setTimeout(() => {
    console.error('Forced shutdown after 30 seconds')
    process.exit(1)
  }, 30000)
})
```

### 3. ヘルスチェックエンドポイント

```typescript
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks: {
      database: 'unknown',
      redis: 'unknown',
    },
  }

  try {
    // データベース接続チェック
    await db.query('SELECT 1')
    health.checks.database = 'ok'
  } catch (error) {
    health.status = 'error'
    health.checks.database = 'error'
  }

  try {
    // Redis 接続チェック
    await redis.ping()
    health.checks.redis = 'ok'
  } catch (error) {
    health.status = 'error'
    health.checks.redis = 'error'
  }

  const statusCode = health.status === 'ok' ? 200 : 503
  res.status(statusCode).json(health)
})
```

---

## 関連ガイド

### インフラストラクチャ
- [Kubernetes ガイド](../../infra/kubernetes/kubernetes_guide.md) - コンテナオーケストレーション
- [AWS ECS ガイド](../../infra/aws/ecs/ecs_fargate_guide.md) - コンテナサービス
- [AWS Lambda ガイド](../../infra/aws/lambda/lambda_guide.md) - サーバーレススケーリング

### データベース
- [PostgreSQL ガイド](../../database/postgresql/postgresql_guide.md) - データベース最適化
- [Redis ガイド](../../database/redis/redis_guide.md) - キャッシング

### パフォーマンス
- [パフォーマンス最適化ガイド](../../performance/optimization_guide.md) - アプリケーション最適化

### モニタリング
- [モニタリングガイド](../monitoring/monitoring_guide.md) - スケーリングメトリクスの監視

### デプロイ
- [デプロイ戦略ガイド](../deployment/deployment_strategies.md) - スケール時のデプロイ
