# ESLint + Prettier 完全ガイド

## 目次
- [概要](#概要)
- [ESLint](#eslint)
- [Prettier](#prettier)
- [統合設定](#統合設定)
- [VS Code統合](#vs-code統合)
- [Git Hooks](#git-hooks)
- [CI/CD統合](#cicd統合)

---

## 概要

コード品質とフォーマットを自動化するツール。

### 役割分担
- **ESLint**: コード品質チェック（バグ検出、ベストプラクティス）
- **Prettier**: コードフォーマット（見た目、スタイル統一）

---

## ESLint

JavaScriptのリンター。コードの問題を検出。

### インストール

```bash
npm install --save-dev eslint
npx eslint --init
```

### 基本設定

```javascript
// .eslintrc.js
module.exports = {
  env: {
    browser: true,
    es2021: true,
    node: true
  },
  extends: [
    'eslint:recommended'
  ],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  rules: {
    'no-unused-vars': 'error',
    'no-console': 'warn',
    'prefer-const': 'error'
  }
}
```

### TypeScript対応

```bash
npm install --save-dev @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

```javascript
// .eslintrc.js
module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended'
  ],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    project: './tsconfig.json'
  },
  rules: {
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/no-explicit-any': 'warn'
  }
}
```

### React設定

```bash
npm install --save-dev eslint-plugin-react eslint-plugin-react-hooks
```

```javascript
// .eslintrc.js
module.exports = {
  extends: [
    'eslint:recommended',
    'plugin:react/recommended',
    'plugin:react-hooks/recommended'
  ],
  plugins: ['react', 'react-hooks'],
  settings: {
    react: {
      version: 'detect'
    }
  },
  rules: {
    'react/react-in-jsx-scope': 'off', // React 17+
    'react/prop-types': 'off', // TypeScript使用時
    'react-hooks/rules-of-hooks': 'error',
    'react-hooks/exhaustive-deps': 'warn'
  }
}
```

### Next.js設定

```bash
npm install --save-dev eslint-config-next
```

```javascript
// .eslintrc.js
module.exports = {
  extends: ['next/core-web-vitals']
}
```

### Vue設定

```bash
npm install --save-dev eslint-plugin-vue
```

```javascript
// .eslintrc.js
module.exports = {
  extends: [
    'eslint:recommended',
    'plugin:vue/vue3-recommended'
  ],
  parser: 'vue-eslint-parser',
  parserOptions: {
    parser: '@typescript-eslint/parser',
    ecmaVersion: 'latest',
    sourceType: 'module'
  }
}
```

### よく使うルール

```javascript
module.exports = {
  rules: {
    // エラー検出
    'no-unused-vars': 'error',
    'no-undef': 'error',
    'no-console': 'warn',

    // ベストプラクティス
    'prefer-const': 'error',
    'no-var': 'error',
    'eqeqeq': ['error', 'always'],
    'no-eval': 'error',

    // コードスタイル
    'quotes': ['error', 'single'],
    'semi': ['error', 'never'],
    'indent': ['error', 2],
    'comma-dangle': ['error', 'never'],

    // ES6+
    'arrow-body-style': ['error', 'as-needed'],
    'prefer-arrow-callback': 'error',
    'prefer-template': 'error'
  }
}
```

### 無効化

```javascript
// ファイル全体
/* eslint-disable */

// 特定のルール
/* eslint-disable no-console */

// 次の1行のみ
// eslint-disable-next-line no-console
console.log('Debug')

// 行末
const x = 1 // eslint-disable-line no-unused-vars
```

### コマンド

```bash
# チェック
npx eslint .

# 自動修正
npx eslint . --fix

# 特定ファイル
npx eslint src/**/*.ts

# キャッシュ利用（高速化）
npx eslint . --cache
```

---

## Prettier

コードフォーマッター。一貫したスタイルを強制。

### インストール

```bash
npm install --save-dev prettier
```

### 基本設定

```json
// .prettierrc
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "none",
  "printWidth": 80,
  "tabWidth": 2,
  "arrowParens": "always"
}
```

### 設定オプション

```json
{
  // セミコロン
  "semi": false,

  // シングルクォート
  "singleQuote": true,

  // 末尾カンマ
  "trailingComma": "es5",

  // 1行の最大文字数
  "printWidth": 100,

  // タブ幅
  "tabWidth": 2,

  // スペース vs タブ
  "useTabs": false,

  // アロー関数の括弧
  "arrowParens": "always",

  // JSXでシングルクォート
  "jsxSingleQuote": false,

  // オブジェクトのスペース
  "bracketSpacing": true,

  // JSXの閉じ括弧の位置
  "jsxBracketSameLine": false,

  // 改行コード
  "endOfLine": "lf"
}
```

### 無視設定

```
# .prettierignore
node_modules
dist
build
.next
coverage
*.min.js
package-lock.json
```

### コマンド

```bash
# チェック
npx prettier --check .

# フォーマット
npx prettier --write .

# 特定ファイル
npx prettier --write "src/**/*.{js,ts,tsx}"
```

---

## 統合設定

ESLintとPrettierを競合なく使用。

### インストール

```bash
npm install --save-dev eslint-config-prettier eslint-plugin-prettier
```

### 設定

```javascript
// .eslintrc.js
module.exports = {
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react/recommended',
    'prettier' // 必ず最後
  ],
  plugins: ['prettier'],
  rules: {
    'prettier/prettier': 'error'
  }
}
```

---

## VS Code統合

エディタ上で自動チェック・修正。

### 拡張機能

```
- ESLint (dbaeumer.vscode-eslint)
- Prettier (esbenp.prettier-vscode)
```

### 設定

```json
// .vscode/settings.json
{
  // デフォルトフォーマッター
  "editor.defaultFormatter": "esbenp.prettier-vscode",

  // 保存時フォーマット
  "editor.formatOnSave": true,

  // 保存時ESLint修正
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },

  // ESLint対象言語
  "eslint.validate": [
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact"
  ]
}
```

### ワークスペース設定

```json
// .vscode/extensions.json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode"
  ]
}
```

---

## Git Hooks

コミット前に自動チェック・フォーマット。

### Husky + lint-staged

```bash
npm install --save-dev husky lint-staged
npx husky init
```

```json
// package.json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "*.{js,jsx,ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md,yml,yaml}": [
      "prettier --write"
    ]
  }
}
```

```bash
# .husky/pre-commit
npx lint-staged
```

### コミットメッセージチェック

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional
```

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore']
    ]
  }
}
```

```bash
# .husky/commit-msg
npx --no -- commitlint --edit $1
```

---

## CI/CD統合

### GitHub Actions

```yaml
# .github/workflows/lint.yml
name: Lint

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Run Prettier
        run: npm run format:check
```

```json
// package.json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  }
}
```

### GitLab CI

```yaml
# .gitlab-ci.yml
lint:
  stage: test
  image: node:18
  script:
    - npm ci
    - npm run lint
    - npm run format:check
  only:
    - merge_requests
    - main
```

---

## 推奨プリセット

### TypeScript + React

```javascript
// .eslintrc.js
module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react/recommended',
    'plugin:react-hooks/recommended',
    'prettier'
  ],
  plugins: ['@typescript-eslint', 'react', 'react-hooks', 'prettier'],
  settings: {
    react: { version: 'detect' }
  },
  rules: {
    'prettier/prettier': 'error',
    'react/react-in-jsx-scope': 'off',
    '@typescript-eslint/no-unused-vars': 'error'
  }
}
```

```json
// .prettierrc
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100,
  "tabWidth": 2
}
```

### Node.js + TypeScript

```javascript
// .eslintrc.js
module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'prettier'
  ],
  plugins: ['@typescript-eslint', 'prettier'],
  env: {
    node: true,
    es2021: true
  },
  rules: {
    'prettier/prettier': 'error',
    '@typescript-eslint/no-unused-vars': 'error',
    'no-console': 'off'
  }
}
```

---

## トラブルシューティング

### ESLintとPrettierが競合

```bash
# 競合ルールを確認
npx eslint-config-prettier "src/**/*.ts"
```

### キャッシュクリア

```bash
# ESLint
rm -rf .eslintcache

# Prettier
rm -rf node_modules/.cache/prettier
```

### パフォーマンス改善

```javascript
// .eslintrc.js
module.exports = {
  // キャッシュ有効化
  cache: true,
  cacheLocation: '.eslintcache',

  // 不要なファイルを除外
  ignorePatterns: ['dist', 'build', 'node_modules']
}
```

---

## 参考リンク

- [ESLint Documentation](https://eslint.org/)
- [Prettier Documentation](https://prettier.io/)
- [eslint-config-prettier](https://github.com/prettier/eslint-config-prettier)
