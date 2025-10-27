# デプロイ戦略ガイド

> 最終更新: 2025-10-27
> 難易度: 中級

## 概要

本番環境へのデプロイは、サービスの可用性とユーザー体験に直接影響します。適切なデプロイ戦略を選択することで、ダウンタイムを最小化し、問題が発生した際の迅速なロールバックを可能にします。

## 主要なデプロイ戦略

### 1. Rolling Deployment（ローリングデプロイ）

**概要**: インスタンスを段階的に更新していく方式

**メリット**:
- ダウンタイムなし
- リソース効率が良い
- 実装がシンプル

**デメリット**:
- ロールバックに時間がかかる
- 旧バージョンと新バージョンが混在する期間がある
- データベーススキーマ変更時に互換性問題が発生しやすい

**実装例（Kubernetes）**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # 最大2つまで追加インスタンスを許可
      maxUnavailable: 1  # 最大1つまで利用不可を許可
  template:
    spec:
      containers:
      - name: app
        image: my-app:v2.0
```

**ベストプラクティス**:
- `maxUnavailable` を小さく保ち、段階的にロールアウト
- ヘルスチェックを必ず実装
- データベーススキーマは後方互換性を保つ

---

### 2. Blue/Green Deployment

**概要**: 新旧2つの環境を用意し、切り替える方式

**メリット**:
- 瞬時に切り替え可能
- 簡単にロールバック可能
- 新旧バージョンが混在しない
- 本番環境での事前テストが可能

**デメリット**:
- 2倍のリソースが必要
- データベース同期が課題
- コストが高い

**実装例（AWS ECS + ALB）**:

```bash
# 1. Blueタスク定義（現行）
aws ecs register-task-definition \
  --cli-input-json file://blue-task-def.json

# 2. Greenタスク定義（新バージョン）
aws ecs register-task-definition \
  --cli-input-json file://green-task-def.json

# 3. Greenサービスを起動
aws ecs create-service \
  --cluster production \
  --service-name my-app-green \
  --task-definition my-app:2

# 4. ヘルスチェック確認後、ALBのターゲットグループを切り替え
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:... \
  --default-actions Type=forward,TargetGroupArn=arn:aws:green-tg

# 5. Blueサービスを停止（問題なければ）
aws ecs delete-service \
  --cluster production \
  --service my-app-blue
```

**ベストプラクティス**:
- データベースはリードレプリカで共有
- 切り替え前に Green 環境で十分なテストを実施
- 切り替え後も一定期間 Blue 環境を保持

---

### 3. Canary Deployment（カナリアデプロイ）

**概要**: 新バージョンを一部のユーザーにのみ公開し、段階的に拡大

**メリット**:
- リスクを最小化
- 実際のユーザーフィードバックを得られる
- 問題の早期発見
- A/Bテストとしても活用可能

**デメリット**:
- 実装が複雑
- モニタリングが必須
- トラフィック制御の仕組みが必要

**実装例（Kubernetes + Istio）**:

```yaml
# 1. 新バージョンのDeployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-v2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
      version: v2
  template:
    metadata:
      labels:
        app: my-app
        version: v2
    spec:
      containers:
      - name: app
        image: my-app:v2.0

---
# 2. VirtualService（トラフィック分割）
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
spec:
  hosts:
  - my-app
  http:
  - match:
    - headers:
        x-user-group:
          exact: beta  # ベータユーザーのみv2へ
    route:
    - destination:
        host: my-app
        subset: v2
  - route:
    - destination:
        host: my-app
        subset: v1
      weight: 90  # 90%のトラフィックをv1へ
    - destination:
        host: my-app
        subset: v2
      weight: 10  # 10%のトラフィックをv2へ
```

**段階的ロールアウトプラン**:

1. **フェーズ1** (1-2時間): 5% のトラフィック
2. **フェーズ2** (2-4時間): 25% のトラフィック
3. **フェーズ3** (4-8時間): 50% のトラフィック
4. **フェーズ4** (8-24時間): 75% のトラフィック
5. **フェーズ5**: 100% のトラフィック（完全移行）

**ベストプラクティス**:
- メトリクスを常時監視（エラー率、レイテンシ等）
- 各フェーズで十分な観察期間を設ける
- 自動ロールバック条件を設定

---

### 4. Feature Flags（機能フラグ）

**概要**: コードはデプロイ済みだが、機能を動的にON/OFF制御

**メリット**:
- デプロイと機能リリースを分離
- 特定ユーザーのみに機能を公開可能
- 問題発生時に即座に無効化可能
- A/Bテストが容易

**デメリット**:
- コードが複雑になる
- フラグ管理が必要
- 技術的負債になりやすい

**実装例（LaunchDarkly風）**:

```typescript
import { initializeFeatureFlags } from './feature-flags'

const featureFlags = initializeFeatureFlags({
  apiKey: process.env.FEATURE_FLAG_API_KEY,
})

// アプリケーションコード
async function handleRequest(userId: string) {
  // 新機能が有効かチェック
  const isNewCheckoutEnabled = await featureFlags.isEnabled(
    'new-checkout-flow',
    { userId }
  )

  if (isNewCheckoutEnabled) {
    return newCheckoutFlow()
  } else {
    return oldCheckoutFlow()
  }
}

// 段階的ロールアウト設定例
featureFlags.updateRule('new-checkout-flow', {
  percentage: 10, // 10%のユーザーに有効化
  targeting: {
    include: ['beta-users'], // ベータユーザーグループは常に有効
  },
})
```

**ベストプラクティス**:
- フラグには有効期限を設定
- 使用されなくなったフラグは削除
- フラグの状態をモニタリング
- 重要なフラグには監査ログを記録

---

## デプロイ戦略の選択基準

| 戦略 | ダウンタイム | リソース使用量 | ロールバック速度 | 実装難易度 | 適用シーン |
|------|------------|--------------|----------------|-----------|----------|
| Rolling | なし | 低 | 遅い | 低 | 通常のアプリケーション更新 |
| Blue/Green | なし | 高（2倍） | 非常に速い | 中 | クリティカルなシステム |
| Canary | なし | 中 | 速い | 高 | 大規模サービス、リスク軽減 |
| Feature Flags | なし | 低 | 即座 | 中 | 機能の段階的リリース |

## デプロイチェックリスト

### デプロイ前

- [ ] すべてのテストがパスしている
- [ ] ステージング環境で動作確認済み
- [ ] データベースマイグレーションの後方互換性を確認
- [ ] ロールバック手順を準備
- [ ] モニタリング・アラートが設定済み
- [ ] デプロイ計画を関係者に共有
- [ ] ピーク時間を避ける

### デプロイ中

- [ ] デプロイの進捗を監視
- [ ] エラーログを確認
- [ ] メトリクス（CPU、メモリ、レスポンスタイム）を監視
- [ ] ヘルスチェックの状態を確認

### デプロイ後

- [ ] すべてのインスタンスが正常稼働
- [ ] エラー率が正常範囲内
- [ ] レスポンスタイムが正常範囲内
- [ ] ユーザーからのフィードバック確認
- [ ] 旧バージョンの削除（Blue/Greenの場合）
- [ ] ポストモーテム（問題があった場合）

## トラブルシューティング

### デプロイ失敗時の対処

```bash
# 1. 即座にロールバック
kubectl rollout undo deployment/my-app

# 2. ログを確認
kubectl logs -l app=my-app --tail=100

# 3. イベントを確認
kubectl describe deployment my-app

# 4. ヘルスチェック状態を確認
kubectl get pods -l app=my-app
```

### データベースマイグレーション失敗時

```bash
# 1. マイグレーションステータス確認
npm run migration:status

# 2. ロールバック
npm run migration:rollback

# 3. データ整合性チェック
npm run db:check-integrity
```

## 関連ガイド

### インフラ・デプロイ
- [Kubernetes ガイド](../../infra/kubernetes/kubernetes_guide.md) - Kubernetesでのデプロイ
- [Docker ガイド](../../infra/docker/docker_guide.md) - コンテナイメージ作成
- [Terraform ガイド](../../infra/iac/terraform_guide.md) - インフラのコード化

### CI/CD
- [GitHub Actions ガイド](../../infra/ci-cd/github_actions_guide.md) - 自動デプロイ

### モニタリング
- [モニタリングガイド](../monitoring/monitoring_guide.md) - デプロイ後の監視
- [Prometheus/Grafana ガイド](../../infra/observability/prometheus_grafana_guide.md) - メトリクス監視

### AWS サービス
- [Lambda ガイド](../../infra/aws/lambda/lambda_guide.md) - サーバーレスデプロイ
- [ECS ガイド](../../infra/aws/ecs/ecs_fargate_guide.md) - コンテナデプロイ
