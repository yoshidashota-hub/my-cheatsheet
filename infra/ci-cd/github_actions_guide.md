# GitHub Actions ガイド

GitHub Actionsは、CI/CDパイプラインを自動化するプラットフォームです。

## 特徴

- **GitHubネイティブ**: リポジトリに統合
- **イベント駆動**: プッシュ、PR、issueなど多様なトリガー
- **マトリックスビルド**: 複数環境での並列テスト
- **豊富なアクション**: Marketplaceから利用可能
- **無料枠**: パブリックリポジトリは無料

## 基本構文

### ワークフローファイル

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test
```

## トリガー

### push

```yaml
on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'src/**'
      - '!src/**/*.test.ts'
    tags:
      - v*
```

### pull_request

```yaml
on:
  pull_request:
    branches: [ main ]
    types:
      - opened
      - synchronize
      - reopened
```

### schedule（定期実行）

```yaml
on:
  schedule:
    # 毎日午前9時（UTC）
    - cron: '0 9 * * *'
    # 毎週月曜日午前0時
    - cron: '0 0 * * 1'
```

### workflow_dispatch（手動実行）

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - development
          - staging
          - production
      version:
        description: 'Version to deploy'
        required: false
        default: 'latest'
```

### 複数トリガー

```yaml
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 9 * * *'
  workflow_dispatch:
```

## Jobs

### 基本的なJob

```yaml
jobs:
  build:
    name: Build Application
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: npm run build
```

### 複数Job

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint

  build:
    needs: [test, lint]  # test と lint が成功したら実行
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
```

### マトリックスビルド

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}

    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node-version: [18, 20, 21]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - run: npm ci
      - run: npm test
```

### 条件付き実行

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying..."

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test

      - name: Upload coverage
        if: success()  # 前のステップが成功した場合のみ
        uses: codecov/codecov-action@v3

      - name: Notify failure
        if: failure()  # 前のステップが失敗した場合のみ
        run: echo "Test failed"
```

## Steps

### アクションの使用

```yaml
steps:
  # 公式アクション
  - uses: actions/checkout@v4

  # バージョン指定
  - uses: actions/setup-node@v4
    with:
      node-version: '20'

  # タグ指定
  - uses: actions/checkout@v4.1.0

  # ブランチ指定
  - uses: actions/checkout@main

  # コミットハッシュ指定（最も安全）
  - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
```

### コマンド実行

```yaml
steps:
  # 単一コマンド
  - run: npm test

  # 複数行コマンド
  - run: |
      npm ci
      npm run build
      npm test

  # 作業ディレクトリ指定
  - run: npm test
    working-directory: ./backend

  # 環境変数
  - run: echo $MY_VAR
    env:
      MY_VAR: 'Hello World'

  # シェル指定
  - run: python script.py
    shell: python
```

### 名前付きステップ

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v4

  - name: Install dependencies
    run: npm ci

  - name: Run tests
    run: npm test
```

## 環境変数とシークレット

### 環境変数

```yaml
env:
  NODE_ENV: production
  API_URL: https://api.example.com

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      BUILD_ENV: staging

    steps:
      - name: Build
        run: npm run build
        env:
          CUSTOM_VAR: value
```

### シークレット

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Deploy
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          aws s3 sync ./build s3://my-bucket
```

### GitHub コンテキスト

```yaml
steps:
  - name: Print context
    run: |
      echo "Repository: ${{ github.repository }}"
      echo "Branch: ${{ github.ref }}"
      echo "Commit: ${{ github.sha }}"
      echo "Actor: ${{ github.actor }}"
      echo "Event: ${{ github.event_name }}"
```

## キャッシュ

### Node.js の依存関係

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Node.js
    uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'

  - run: npm ci
  - run: npm test
```

### カスタムキャッシュ

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Cache dependencies
    uses: actions/cache@v3
    with:
      path: |
        ~/.npm
        node_modules
      key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
      restore-keys: |
        ${{ runner.os }}-node-

  - run: npm ci
```

## Artifacts

### アップロード

```yaml
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-files
          path: dist/
          retention-days: 7
```

### ダウンロード

```yaml
jobs:
  deploy:
    needs: build
    runs-on: ubuntu-latest

    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v3
        with:
          name: build-files
          path: dist/

      - name: Deploy
        run: |
          # デプロイ処理
```

## 実践例

### Node.js CI/CD

```yaml
# .github/workflows/nodejs.yml
name: Node.js CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18, 20, 21]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Upload coverage
        if: matrix.node-version == '20'
        uses: codecov/codecov-action@v3

  build:
    needs: test
    if: github.event_name == 'push'
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci
      - run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: dist
          path: dist/

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest

    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v3
        with:
          name: dist
          path: dist/

      - name: Deploy to production
        env:
          VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
        run: |
          npx vercel --prod --token=$VERCEL_TOKEN
```

### Docker ビルド＆プッシュ

```yaml
# .github/workflows/docker.yml
name: Docker Build and Push

on:
  push:
    branches: [ main ]
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: myusername/myapp
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### AWS へのデプロイ

```yaml
# .github/workflows/aws-deploy.yml
name: Deploy to AWS

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - run: npm ci
      - run: npm run build

      - name: Deploy to S3
        run: |
          aws s3 sync ./dist s3://my-bucket --delete

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
```

### Pull Request チェック

```yaml
# .github/workflows/pr-check.yml
name: PR Check

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  check:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # 全履歴を取得

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Lint
        run: npm run lint

      - name: Type check
        run: npm run type-check

      - name: Test
        run: npm test -- --coverage

      - name: Build
        run: npm run build

      - name: Comment PR
        uses: actions/github-script@v7
        if: always()
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ All checks passed!'
            })
```

### モノレポの並列ビルド

```yaml
# .github/workflows/monorepo.yml
name: Monorepo CI

on: [push, pull_request]

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      frontend: ${{ steps.changes.outputs.frontend }}
      backend: ${{ steps.changes.outputs.backend }}
    steps:
      - uses: actions/checkout@v4

      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            frontend:
              - 'packages/frontend/**'
            backend:
              - 'packages/backend/**'

  frontend:
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test --workspace=packages/frontend

  backend:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test --workspace=packages/backend
```

## 再利用可能なワークフロー

### 呼び出し可能なワークフロー

```yaml
# .github/workflows/reusable-test.yml
name: Reusable Test Workflow

on:
  workflow_call:
    inputs:
      node-version:
        required: true
        type: string
    secrets:
      npm-token:
        required: false

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}

      - run: npm ci
      - run: npm test
```

### ワークフローの呼び出し

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test-18:
    uses: ./.github/workflows/reusable-test.yml
    with:
      node-version: '18'

  test-20:
    uses: ./.github/workflows/reusable-test.yml
    with:
      node-version: '20'
```

## Composite Actions

```yaml
# .github/actions/setup-node-app/action.yml
name: 'Setup Node.js Application'
description: 'Setup Node.js and install dependencies'

inputs:
  node-version:
    description: 'Node.js version'
    required: false
    default: '20'

runs:
  using: 'composite'
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'

    - name: Install dependencies
      run: npm ci
      shell: bash

    - name: Cache node_modules
      uses: actions/cache@v3
      with:
        path: node_modules
        key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

```yaml
# 使用例
steps:
  - uses: actions/checkout@v4

  - name: Setup application
    uses: ./.github/actions/setup-node-app
    with:
      node-version: '20'

  - run: npm test
```

## セルフホストランナー

```yaml
jobs:
  build:
    runs-on: self-hosted  # セルフホストランナーを使用

    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
```

## デバッグ

### デバッグログの有効化

```yaml
steps:
  - name: Enable debug logging
    run: echo "ACTIONS_STEP_DEBUG=true" >> $GITHUB_ENV

  - name: Debug step
    run: |
      echo "::debug::This is a debug message"
      echo "::warning::This is a warning"
      echo "::error::This is an error"
```

### SSH デバッグ

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup tmate session
    uses: mxschmitt/action-tmate@v3
    if: failure()  # 失敗時にSSHセッションを開始
```

## ベストプラクティス

1. **最小権限の原則**: 必要最小限のpermissionsを設定
2. **シークレットの管理**: 環境変数にシークレットを保存
3. **タイムアウトの設定**: 無限ループを防ぐ
4. **キャッシュの活用**: ビルド時間を短縮
5. **マトリックスビルド**: 複数環境でテスト
6. **条件付き実行**: 不要なジョブをスキップ
7. **再利用可能なワークフロー**: DRY原則
8. **コミットハッシュ固定**: アクションのバージョン固定

## トラブルシューティング

### よくあるエラー

```yaml
# ❌ 悪い例
- run: npm test
  if: github.ref = 'refs/heads/main'  # 間違った構文

# ✅ 良い例
- run: npm test
  if: github.ref == 'refs/heads/main'

# ❌ 悪い例
- run: echo $SECRET  # シークレットが展開されない

# ✅ 良い例
- run: echo $SECRET
  env:
    SECRET: ${{ secrets.MY_SECRET }}
```

## 参考リンク

- [GitHub Actions 公式ドキュメント](https://docs.github.com/en/actions)
- [GitHub Actions Marketplace](https://github.com/marketplace?type=actions)
- [Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
