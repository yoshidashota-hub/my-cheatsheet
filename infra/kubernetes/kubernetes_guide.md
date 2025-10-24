# Kubernetes 完全ガイド

## 目次
- [Kubernetesとは](#kubernetesとは)
- [基本概念](#基本概念)
- [kubectl コマンド](#kubectlコマンド)
- [Pod](#pod)
- [Deployment](#deployment)
- [Service](#service)
- [ConfigMap & Secret](#configmap--secret)

---

## Kubernetesとは

コンテナオーケストレーションプラットフォーム。

### 特徴
- 🚀 自動デプロイ
- ⚖️ 負荷分散
- 🔄 自動修復
- 📈 自動スケーリング

---

## 基本概念

### クラスター構成
- **Node**: サーバー
- **Pod**: コンテナの実行単位
- **Service**: ネットワーク公開
- **Deployment**: Pod管理

---

## kubectl コマンド

### 基本コマンド

```bash
# クラスター情報
kubectl cluster-info

# ノード一覧
kubectl get nodes

# Pod一覧
kubectl get pods
kubectl get pods -A # 全Namespace

# 詳細表示
kubectl describe pod <pod-name>

# ログ
kubectl logs <pod-name>

# 実行
kubectl exec -it <pod-name> -- /bin/bash

# 削除
kubectl delete pod <pod-name>
```

---

## Pod

### Pod定義

```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

```bash
kubectl apply -f pod.yaml
```

---

## Deployment

### Deployment定義

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl scale deployment nginx-deployment --replicas=5
```

---

## Service

### Service定義

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: LoadBalancer
```

---

## ConfigMap & Secret

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: production
  LOG_LEVEL: info
```

### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  password: cGFzc3dvcmQ= # base64
```

---

## 参考リンク

- [Kubernetes Documentation](https://kubernetes.io/docs/)
