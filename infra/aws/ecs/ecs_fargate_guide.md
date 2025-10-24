# AWS ECS & Fargate 完全ガイド

## 目次
- [ECS/Fargateとは](#ecsfargateとは)
- [基本概念](#基本概念)
- [タスク定義](#タスク定義)
- [サービス](#サービス)
- [デプロイ](#デプロイ)
- [ロードバランサー](#ロードバランサー)

---

## ECS/Fargateとは

AWSのコンテナオーケストレーションサービス。

### 特徴
- 🚀 サーバーレスコンテナ
- 📈 自動スケーリング
- 🔒 VPC統合
- 💰 秒単位課金

### ECS vs Fargate
- **ECS (EC2)**: EC2インスタンス管理が必要
- **Fargate**: サーバーレス、インフラ管理不要

---

## 基本概念

### コンポーネント
- **Cluster**: ECSリソースの論理的なグループ
- **Task Definition**: コンテナ定義
- **Task**: 実行中のコンテナ
- **Service**: タスクの管理と維持

---

## タスク定義

### JSON形式

```json
{
  "family": "my-app",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "nginx:latest",
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-app",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### CLI登録

```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json
```

---

## サービス

### サービス作成

```bash
aws ecs create-service \
  --cluster my-cluster \
  --service-name my-service \
  --task-definition my-app:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

### Auto Scaling

```bash
# ターゲット追跡スケーリング
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/my-cluster/my-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 10
```

---

## デプロイ

### Blue/Green デプロイ

```bash
aws ecs update-service \
  --cluster my-cluster \
  --service my-service \
  --task-definition my-app:2 \
  --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true}"
```

---

## ロードバランサー

### ALB統合

```json
{
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:...",
      "containerName": "app",
      "containerPort": 80
    }
  ]
}
```

---

## 参考リンク

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Fargate](https://aws.amazon.com/fargate/)
