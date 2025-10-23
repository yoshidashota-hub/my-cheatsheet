# Docker & Docker Compose ガイド

Dockerを使用したコンテナ化アプリケーションの開発・デプロイガイドです。

## Dockerのインストール

### macOS / Windows

[Docker Desktop](https://www.docker.com/products/docker-desktop/) をインストール

### Linux

```bash
# Ubuntu
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# ユーザーをdockerグループに追加
sudo usermod -aG docker $USER
```

インストール確認:

```bash
docker --version
docker compose version
```

## Docker基本コマンド

### イメージ操作

```bash
# イメージの検索
docker search nginx

# イメージのダウンロード
docker pull nginx:latest
docker pull node:20-alpine

# イメージの一覧表示
docker images

# イメージの削除
docker rmi nginx:latest
docker rmi $(docker images -q)  # 全てのイメージを削除

# 未使用イメージの削除
docker image prune
docker image prune -a  # 全ての未使用イメージ
```

### コンテナ操作

```bash
# コンテナの起動
docker run nginx
docker run -d nginx                    # バックグラウンド実行
docker run -d -p 8080:80 nginx        # ポートマッピング
docker run -d --name my-nginx nginx   # コンテナ名を指定
docker run -it ubuntu bash            # 対話モード

# コンテナの一覧表示
docker ps           # 実行中のコンテナ
docker ps -a        # 全てのコンテナ

# コンテナの停止・開始・再起動
docker stop my-nginx
docker start my-nginx
docker restart my-nginx

# コンテナの削除
docker rm my-nginx
docker rm -f my-nginx        # 強制削除
docker rm $(docker ps -aq)   # 全てのコンテナを削除

# コンテナに入る
docker exec -it my-nginx bash
docker exec -it my-nginx sh  # Alpine系

# コンテナのログ表示
docker logs my-nginx
docker logs -f my-nginx      # リアルタイム表示

# コンテナの情報表示
docker inspect my-nginx
docker stats my-nginx        # リソース使用状況
```

### クリーンアップ

```bash
# 停止中のコンテナを削除
docker container prune

# 未使用のイメージを削除
docker image prune -a

# 未使用のボリュームを削除
docker volume prune

# 未使用のネットワークを削除
docker network prune

# 全てをクリーンアップ
docker system prune -a --volumes
```

## Dockerfile

### 基本構文

```dockerfile
# ベースイメージの指定
FROM node:20-alpine

# メタデータ
LABEL maintainer="your-email@example.com"
LABEL version="1.0"

# 作業ディレクトリの設定
WORKDIR /app

# ファイルのコピー
COPY package*.json ./

# コマンドの実行
RUN npm install

# ファイルのコピー（再度）
COPY . .

# 環境変数の設定
ENV NODE_ENV=production
ENV PORT=3000

# ポートの公開
EXPOSE 3000

# ユーザーの切り替え（セキュリティ）
USER node

# コンテナ起動時のコマンド
CMD ["node", "index.js"]
```

### マルチステージビルド

```dockerfile
# ビルドステージ
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# 実行ステージ
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

# ビルドステージから成果物をコピー
COPY --from=builder /app/dist ./dist

EXPOSE 3000

CMD ["node", "dist/index.js"]
```

### Node.js アプリケーション例

```dockerfile
FROM node:20-alpine

WORKDIR /app

# 依存関係のインストール（キャッシュ活用）
COPY package*.json ./
RUN npm ci

# ソースコードのコピー
COPY . .

# TypeScriptのビルド
RUN npm run build

# 不要な開発依存をクリーンアップ
RUN npm prune --production

EXPOSE 3000

# 本番環境で実行
ENV NODE_ENV=production
CMD ["node", "dist/index.js"]
```

### Python アプリケーション例

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 依存関係のインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ソースコードのコピー
COPY . .

EXPOSE 8000

CMD ["python", "app.py"]
```

### Go アプリケーション例

```dockerfile
# ビルドステージ
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# 実行ステージ
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

### イメージのビルドと実行

```bash
# イメージのビルド
docker build -t my-app:latest .
docker build -t my-app:v1.0.0 .
docker build -f Dockerfile.dev -t my-app:dev .

# ビルドキャッシュを無効化
docker build --no-cache -t my-app:latest .

# 特定のステージまでビルド
docker build --target builder -t my-app:builder .

# イメージの実行
docker run -d -p 3000:3000 my-app:latest
```

## Docker Compose

### 基本構成

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://user:password@db:5432/mydb
    volumes:
      - .:/app
      - /app/node_modules
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### Docker Composeコマンド

```bash
# サービスの起動
docker compose up
docker compose up -d              # バックグラウンド実行
docker compose up --build         # イメージを再ビルドして起動

# 特定のサービスのみ起動
docker compose up app

# サービスの停止
docker compose down
docker compose down -v            # ボリュームも削除
docker compose down --rmi all     # イメージも削除

# サービスの再起動
docker compose restart
docker compose restart app

# ログの表示
docker compose logs
docker compose logs -f            # リアルタイム表示
docker compose logs app           # 特定のサービス

# 実行中のサービス一覧
docker compose ps

# コンテナに入る
docker compose exec app bash
docker compose exec db psql -U user -d mydb

# コマンドの実行
docker compose run app npm install
docker compose run app npm test
```

## 実践例

### Next.js + PostgreSQL + Redis

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/nextapp
      - REDIS_URL=redis://redis:6379
      - NEXT_PUBLIC_API_URL=http://localhost:3000
    volumes:
      - .:/app
      - /app/node_modules
      - /app/.next
    depends_on:
      - db
      - redis
    command: npm run dev

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=nextapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"

  adminer:
    image: adminer
    ports:
      - "8080:8080"
    depends_on:
      - db

volumes:
  postgres_data:
  redis_data:
```

```dockerfile
# Dockerfile.dev
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev"]
```

### Express + MongoDB + Nginx

```yaml
# docker-compose.yml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app

  app:
    build: .
    environment:
      - MONGODB_URL=mongodb://mongo:27017/myapp
      - NODE_ENV=production
    depends_on:
      - mongo

  mongo:
    image: mongo:7
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=password
    volumes:
      - mongo_data:/data/db
    ports:
      - "27017:27017"

volumes:
  mongo_data:
```

```nginx
# nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:3000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
```

### フルスタックアプリケーション

```yaml
# docker-compose.yml
version: '3.8'

services:
  # フロントエンド
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:4000
    depends_on:
      - backend

  # バックエンド
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/app
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=your-secret-key
    depends_on:
      - db
      - redis

  # データベース
  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=app
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  # キャッシュ
  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"

  # メール送信（開発用）
  mailhog:
    image: mailhog/mailhog
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI

volumes:
  postgres_data:
  redis_data:
```

## 環境変数管理

### .env ファイル

```bash
# .env
POSTGRES_USER=user
POSTGRES_PASSWORD=password
POSTGRES_DB=mydb
REDIS_PASSWORD=redispassword
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    env_file:
      - .env
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
```

### 複数の環境ファイル

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    env_file:
      - .env
      - .env.local
```

## ボリューム

### 名前付きボリューム

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### バインドマウント

```yaml
version: '3.8'

services:
  app:
    build: .
    volumes:
      - .:/app                    # カレントディレクトリをマウント
      - /app/node_modules         # node_modulesは除外
      - ./logs:/app/logs          # ログディレクトリ
```

### 読み取り専用マウント

```yaml
version: '3.8'

services:
  app:
    build: .
    volumes:
      - ./config:/app/config:ro   # 読み取り専用
```

## ネットワーク

### カスタムネットワーク

```yaml
version: '3.8'

services:
  frontend:
    build: ./frontend
    networks:
      - frontend-network

  backend:
    build: ./backend
    networks:
      - frontend-network
      - backend-network

  db:
    image: postgres:15-alpine
    networks:
      - backend-network

networks:
  frontend-network:
  backend-network:
```

### ホストネットワーク

```yaml
version: '3.8'

services:
  app:
    build: .
    network_mode: "host"
```

## ヘルスチェック

```yaml
version: '3.8'

services:
  app:
    build: .
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  db:
    image: postgres:15-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

## ベストプラクティス

### Dockerfile

1. **軽量なベースイメージを使用**: `alpine` 版を優先
2. **レイヤーキャッシュを活用**: 変更頻度の低いものを先に配置
3. **マルチステージビルド**: 本番イメージを小さく保つ
4. **.dockerignore を使用**: 不要なファイルを除外
5. **非rootユーザーで実行**: セキュリティ向上
6. **環境変数で設定を外部化**: ハードコードしない

### .dockerignore

```bash
# .dockerignore
node_modules
npm-debug.log
.git
.gitignore
.env
.env.local
dist
build
*.md
.vscode
.idea
coverage
```

### Docker Compose

1. **環境ごとにファイルを分割**: `docker-compose.dev.yml`, `docker-compose.prod.yml`
2. **secrets を使用**: パスワードなどの機密情報
3. **ヘルスチェックを設定**: サービスの健全性を監視
4. **depends_on + healthcheck**: 依存サービスの準備完了を待つ
5. **リソース制限**: メモリ・CPUの制限を設定

### 環境分割

```bash
# 開発環境
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# 本番環境
docker compose -f docker-compose.yml -f docker-compose.prod.yml up
```

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  app:
    build:
      target: development
    volumes:
      - .:/app
    command: npm run dev

# docker-compose.prod.yml
version: '3.8'

services:
  app:
    build:
      target: production
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

## トラブルシューティング

### ログの確認

```bash
# コンテナのログ
docker logs <container-id>
docker compose logs app

# リアルタイムでログを表示
docker logs -f <container-id>
docker compose logs -f
```

### コンテナに入ってデバッグ

```bash
# 実行中のコンテナに入る
docker exec -it <container-id> sh

# 停止したコンテナを起動してデバッグ
docker run -it --entrypoint sh my-app:latest
```

### ネットワークの確認

```bash
# ネットワーク一覧
docker network ls

# ネットワークの詳細
docker network inspect bridge
```

### ポート競合の解決

```bash
# ポートを使用しているプロセスを確認
lsof -i :3000        # macOS/Linux
netstat -ano | findstr :3000  # Windows

# 別のポートを使用
docker run -p 3001:3000 my-app
```

## 参考リンク

- [Docker 公式ドキュメント](https://docs.docker.com/)
- [Docker Compose 公式ドキュメント](https://docs.docker.com/compose/)
- [Dockerfile ベストプラクティス](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker Hub](https://hub.docker.com/)
