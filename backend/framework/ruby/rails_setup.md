# Ruby on Rails セットアップ & 基本概念

## 目次
- [Railsとは](#railsとは)
- [基本哲学](#基本哲学)
- [インストール](#インストール)
- [新規プロジェクト作成](#新規プロジェクト作成)
- [ディレクトリ構造](#ディレクトリ構造)
- [開発サーバー起動](#開発サーバー起動)
- [Railsコマンド](#railsコマンド)

---

## Railsとは

Ruby on Railsは、Rubyで書かれたWebアプリケーションフレームワーク。MVCアーキテクチャを採用し、高速な開発を可能にする。

### 主な特徴
- フルスタックフレームワーク
- MVCアーキテクチャ
- RESTfulな設計
- ActiveRecordによるORM
- Gemによる豊富なプラグイン

---

## 基本哲学

### CoC (Convention over Configuration)
設定より規約。命名規則に従えば設定ファイルを書く必要がない。

```ruby
# モデル名: User → テーブル名: users (自動的に複数形)
class User < ApplicationRecord
end
```

### DRY (Don't Repeat Yourself)
同じコードを繰り返さない。再利用性を重視。

### RESTful設計
リソース指向のURL設計を推奨。

---

## インストール

### Ruby環境のセットアップ
```bash
# rbenvでRubyをインストール (推奨)
rbenv install 3.2.2
rbenv global 3.2.2

# バージョン確認
ruby -v
```

### Railsのインストール
```bash
# 最新版をインストール
gem install rails

# バージョン指定
gem install rails -v 7.1.0

# バージョン確認
rails -v
```

---

## 新規プロジェクト作成

### 基本的な作成
```bash
# 通常のWebアプリケーション
rails new myapp

# PostgreSQLを使用
rails new myapp --database=postgresql

# MySQL を使用
rails new myapp --database=mysql

# API専用モード
rails new myapp --api

# JavaScriptフレームワーク指定
rails new myapp --javascript=esbuild

# CSS フレームワーク指定
rails new myapp --css=tailwind
```

### 主要オプション
```bash
rails new myapp [OPTIONS]

# データベース指定
--database=postgresql  # または mysql, sqlite3

# API モード
--api                  # API専用（ビュー不要）

# スキップ系
--skip-test           # テストフレームワークをスキップ
--skip-bundle         # bundle install をスキップ
--skip-git            # Git 初期化をスキップ
--skip-javascript     # JavaScript をスキップ

# JavaScript ビルドツール
--javascript=esbuild  # または webpack, importmap

# CSS フレームワーク
--css=tailwind        # または bootstrap, bulma, postcss, sass
```

---

## ディレクトリ構造

```
myapp/
├── app/                    # アプリケーションコア
│   ├── controllers/       # コントローラー
│   ├── models/            # モデル
│   ├── views/             # ビュー
│   ├── helpers/           # ビューヘルパー
│   ├── mailers/           # メーラー
│   ├── jobs/              # バックグラウンドジョブ
│   └── assets/            # 静的ファイル（CSS、JS、画像）
│
├── bin/                    # 実行ファイル
│   ├── rails              # Railsコマンド
│   └── setup              # セットアップスクリプト
│
├── config/                 # 設定ファイル
│   ├── routes.rb          # ルーティング定義
│   ├── database.yml       # DB接続設定
│   ├── environments/      # 環境別設定
│   └── initializers/      # 初期化処理
│
├── db/                     # データベース関連
│   ├── migrate/           # マイグレーションファイル
│   ├── schema.rb          # DBスキーマ
│   └── seeds.rb           # 初期データ
│
├── lib/                    # 独自ライブラリ
│   ├── tasks/             # Rakeタスク
│   └── assets/            # ライブラリのアセット
│
├── log/                    # ログファイル
│
├── public/                 # 公開ディレクトリ
│   ├── 404.html           # エラーページ
│   └── robots.txt         # クローラー設定
│
├── storage/                # Active Storage用
│
├── test/                   # テストコード（Minitest）
│   ├── controllers/
│   ├── models/
│   └── fixtures/
│
├── tmp/                    # 一時ファイル
│
├── vendor/                 # サードパーティコード
│
├── Gemfile                 # Gem依存関係
├── Gemfile.lock            # Gemバージョン固定
├── Rakefile                # Rakeタスク定義
└── config.ru               # Rackサーバー設定
```

---

## 開発サーバー起動

### サーバー起動
```bash
# デフォルト（localhost:3000）
rails server
# または
rails s

# ポート指定
rails s -p 4000

# 外部からアクセス可能に
rails s -b 0.0.0.0

# 環境指定
rails s -e production
```

### コンソール起動
```bash
# Railsコンソール（対話型Ruby環境）
rails console
# または
rails c

# サンドボックスモード（変更をロールバック）
rails c --sandbox

# 本番環境
rails c -e production
```

---

## Railsコマンド

### ジェネレーター
```bash
# モデル生成
rails generate model User name:string email:string
rails g model User name:string email:string  # 短縮形

# コントローラー生成
rails g controller Users index show

# スキャフォールド（CRUD全自動生成）
rails g scaffold Post title:string body:text

# マイグレーション生成
rails g migration AddAgeToUsers age:integer

# ジェネレーターの取り消し
rails destroy model User
rails d model User  # 短縮形
```

### データベース操作
```bash
# データベース作成
rails db:create

# マイグレーション実行
rails db:migrate

# ロールバック（1つ戻す）
rails db:rollback

# 特定バージョンまでロールバック
rails db:migrate VERSION=20230101000000

# データベースリセット（削除→作成→マイグレーション）
rails db:reset

# データベース削除
rails db:drop

# シードデータ投入
rails db:seed

# スキーマのリセット（マイグレーション履歴無視）
rails db:schema:load
```

### ルーティング確認
```bash
# ルーティング一覧表示
rails routes

# 特定コントローラーのみ
rails routes -c users

# 検索
rails routes | grep user
```

### その他コマンド
```bash
# Rakeタスク一覧
rails -T

# アプリケーション情報
rails about

# 依存関係インストール
bundle install

# アセットプリコンパイル
rails assets:precompile

# キャッシュクリア
rails tmp:clear
```

---

## 環境設定

### 環境の種類
Rails には3つのデフォルト環境がある：

1. **development** - 開発環境（デフォルト）
2. **test** - テスト環境
3. **production** - 本番環境

### 環境別設定ファイル
```
config/environments/
├── development.rb   # 開発環境設定
├── test.rb          # テスト環境設定
└── production.rb    # 本番環境設定
```

### 環境変数の使用
```ruby
# config/database.yml
production:
  adapter: postgresql
  database: <%= ENV['DATABASE_NAME'] %>
  username: <%= ENV['DATABASE_USER'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
```

### .env ファイル（dotenv-rails gem）
```bash
# Gemfile
gem 'dotenv-rails', groups: [:development, :test]

# .env
DATABASE_NAME=myapp_production
DATABASE_USER=postgres
DATABASE_PASSWORD=secret
```

---

## Gemfile管理

### Gemfile基本構造
```ruby
source 'https://rubygems.org'

ruby '3.2.2'

# Rails本体
gem 'rails', '~> 7.1.0'

# データベース
gem 'pg', '~> 1.5'

# Webサーバー
gem 'puma', '~> 6.0'

# 環境別Gem
group :development, :test do
  gem 'byebug'
  gem 'rspec-rails'
end

group :development do
  gem 'web-console'
  gem 'listen'
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
end

group :production do
  gem 'rack-timeout'
end
```

### Bundle コマンド
```bash
# Gem インストール
bundle install
bundle  # 短縮形

# 本番環境用（development/test グループを除外）
bundle install --without development test

# Gem 更新
bundle update

# 特定Gemのみ更新
bundle update rails

# Gemパス確認
bundle show [gem名]

# 古いGemのクリーンアップ
bundle clean
```

---

## 設定ファイル

### config/application.rb
```ruby
module Myapp
  class Application < Rails::Application
    # Rails バージョン
    config.load_defaults 7.1

    # タイムゾーン
    config.time_zone = 'Tokyo'
    config.active_record.default_timezone = :local

    # 言語
    config.i18n.default_locale = :ja

    # 自動読み込みパス追加
    config.autoload_paths += %W(#{config.root}/lib)

    # ジェネレーター設定
    config.generators do |g|
      g.test_framework :rspec
      g.template_engine :slim
    end
  end
end
```

### config/database.yml
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: myapp_development

test:
  <<: *default
  database: myapp_test

production:
  <<: *default
  database: myapp_production
  username: <%= ENV['DATABASE_USER'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
```

---

## よく使うGem

### 認証・認可
```ruby
gem 'devise'           # ユーザー認証
gem 'pundit'           # 認可（権限管理）
gem 'cancancan'        # 認可（代替）
```

### ページネーション
```ruby
gem 'kaminari'         # ページネーション
gem 'pagy'             # 軽量ページネーション
```

### ファイルアップロード
```ruby
gem 'carrierwave'      # ファイルアップロード
gem 'shrine'           # ファイルアップロード（現代的）
# Active Storage（Rails標準、Gem不要）
```

### バックグラウンドジョブ
```ruby
gem 'sidekiq'          # バックグラウンドジョブ
gem 'delayed_job'      # バックグラウンドジョブ（代替）
```

### API開発
```ruby
gem 'jbuilder'         # JSON ビルダー（Rails標準）
gem 'active_model_serializers'  # シリアライザー
gem 'grape'            # API専用フレームワーク
```

### デバッグ・開発支援
```ruby
gem 'pry-rails'        # 強化版コンソール
gem 'better_errors'    # エラー画面改善
gem 'bullet'           # N+1クエリ検出
gem 'rails-erd'        # ER図自動生成
```

---

## ベストプラクティス

### 1. バージョン管理
- Gemfile.lock をコミット
- .gitignore に機密情報を追加

```bash
# .gitignore
/config/master.key
/config/credentials/*.key
.env
/storage/*
/tmp/*
/log/*
```

### 2. 環境変数の管理
- 機密情報は環境変数で管理
- dotenv-rails または Rails credentials を使用

### 3. データベース設定
- development環境でもPostgreSQLを推奨（本番と同じ環境）
- マイグレーションファイルは編集せず、新しいマイグレーションで修正

### 4. コーディング規約
- Rubocop で静的解析
- RSpec/Minitest でテスト

### 5. パフォーマンス
- N+1クエリを避ける（eager loading）
- キャッシュの活用
- Bullet gem でクエリ監視

---

## トラブルシューティング

### bundle install エラー
```bash
# Bundler バージョン更新
gem update bundler

# Gemfile.lock 削除して再インストール
rm Gemfile.lock
bundle install
```

### データベース接続エラー
```bash
# データベースが存在しない
rails db:create

# マイグレーション未実行
rails db:migrate

# 設定確認
rails db:migrate:status
```

### サーバーが起動しない
```bash
# PIDファイル削除
rm tmp/pids/server.pid

# ポート確認
lsof -i :3000
kill -9 [PID]
```

### キャッシュ問題
```bash
# Spring停止（開発環境の自動リロード機能）
spring stop

# 一時ファイルクリア
rails tmp:clear
```

---

## 参考リンク

- [Ruby on Rails公式ガイド](https://railsguides.jp/)
- [Rails API Documentation](https://api.rubyonrails.org/)
- [RubyGems](https://rubygems.org/)
- [Rails Girls Guide](https://railsgirls.jp/)
