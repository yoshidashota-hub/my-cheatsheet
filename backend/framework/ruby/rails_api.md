# Ruby on Rails API モード

## 目次
- [API モードとは](#apiモードとは)
- [API プロジェクト作成](#apiプロジェクト作成)
- [JSON レスポンス](#jsonレスポンス)
- [シリアライザー](#シリアライザー)
- [バージョニング](#バージョニング)
- [CORS設定](#cors設定)
- [ページネーション](#ページネーション)
- [エラーハンドリング](#エラーハンドリング)

---

## API モードとは

Webアプリケーション向けの機能（ビュー、セッション、Cookie等）を除外し、APIに特化したRailsアプリケーション。

### 通常モードとの違い

| 機能 | 通常モード | API モード |
|------|----------|-----------|
| ビューテンプレート | ○ | ✗ |
| セッション | ○ | ✗（オプション） |
| Cookie | ○ | ✗（オプション） |
| CSRF保護 | ○ | ✗ |
| ActionController::Base | ○ | ✗ |
| ActionController::API | ✗ | ○ |

---

## API プロジェクト作成

### 新規作成

```bash
# API専用モード
rails new myapp --api

# データベース指定
rails new myapp --api --database=postgresql

# 既存プロジェクトをAPIモードに変更する場合
# config/application.rb
config.api_only = true
```

### ディレクトリ構造

```
myapp/
├── app/
│   ├── controllers/
│   │   └── application_controller.rb  # ActionController::API を継承
│   ├── models/
│   ├── serializers/  # シリアライザー（手動作成）
│   └── (views/ なし)
├── config/
│   └── routes.rb
└── Gemfile
```

---

## JSON レスポンス

### 基本的なレスポンス

```ruby
# app/controllers/api/v1/posts_controller.rb
class Api::V1::PostsController < ApplicationController
  def index
    @posts = Post.all
    render json: @posts
  end

  def show
    @post = Post.find(params[:id])
    render json: @post
  end

  def create
    @post = Post.new(post_params)
    if @post.save
      render json: @post, status: :created
    else
      render json: { errors: @post.errors }, status: :unprocessable_entity
    end
  end

  def update
    @post = Post.find(params[:id])
    if @post.update(post_params)
      render json: @post
    else
      render json: { errors: @post.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @post = Post.find(params[:id])
    @post.destroy
    head :no_content
  end

  private

  def post_params
    params.require(:post).permit(:title, :body, :published)
  end
end
```

### ステータスコード

```ruby
# シンボルで指定
render json: @post, status: :ok                        # 200
render json: @post, status: :created                   # 201
render json: { errors: errors }, status: :unprocessable_entity  # 422
render json: { error: 'Not Found' }, status: :not_found         # 404
head :no_content                                       # 204

# 数値で指定
render json: @post, status: 200
render json: @post, status: 201
```

### 特定のカラムのみ返す

```ruby
def index
  @posts = Post.all
  render json: @posts, only: [:id, :title, :created_at]
end

# 除外
render json: @posts, except: [:created_at, :updated_at]
```

### 関連を含める

```ruby
def show
  @post = Post.find(params[:id])
  render json: @post, include: :author
  # または
  render json: @post, include: [:author, :comments]
end
```

### ルートノードを追加

```ruby
render json: @posts, root: :posts
# => { "posts": [...] }
```

---

## シリアライザー

レスポンスのJSON構造を制御。

### Jbuilder（Rails標準）

```ruby
# Gemfile（API modeではデフォルトで無効）
gem 'jbuilder'
```

```ruby
# app/views/api/v1/posts/index.json.jbuilder
json.array! @posts do |post|
  json.id post.id
  json.title post.title
  json.body post.body
  json.author do
    json.id post.author.id
    json.name post.author.name
  end
  json.created_at post.created_at
end
```

```ruby
# app/views/api/v1/posts/show.json.jbuilder
json.id @post.id
json.title @post.title
json.body @post.body
json.author do
  json.id @post.author.id
  json.name @post.author.name
  json.email @post.author.email
end
json.comments @post.comments do |comment|
  json.id comment.id
  json.body comment.body
  json.user_id comment.user_id
end
json.created_at @post.created_at
json.updated_at @post.updated_at
```

### active_model_serializers

```ruby
# Gemfile
gem 'active_model_serializers'
```

```bash
# シリアライザー生成
rails generate serializer Post
```

```ruby
# app/serializers/post_serializer.rb
class PostSerializer < ActiveModel::Serializer
  attributes :id, :title, :body, :created_at

  belongs_to :author
  has_many :comments

  # カスタム属性
  attribute :formatted_date

  def formatted_date
    object.created_at.strftime('%Y/%m/%d')
  end

  # 条件付き属性
  attribute :email, if: :show_email?

  def show_email?
    current_user&.admin?
  end
end
```

```ruby
# app/serializers/author_serializer.rb
class AuthorSerializer < ActiveModel::Serializer
  attributes :id, :name, :email
end
```

```ruby
# コントローラー
def index
  @posts = Post.all
  render json: @posts
  # PostSerializerが自動的に使われる
end

# 特定のシリアライザーを指定
render json: @posts, each_serializer: PostSerializer
```

### jsonapi-serializer（高速）

```ruby
# Gemfile
gem 'jsonapi-serializer'
```

```ruby
# app/serializers/post_serializer.rb
class PostSerializer
  include JSONAPI::Serializer

  attributes :id, :title, :body, :created_at

  belongs_to :author
  has_many :comments

  attribute :formatted_date do |post|
    post.created_at.strftime('%Y/%m/%d')
  end
end
```

```ruby
# コントローラー
def index
  @posts = Post.all
  render json: PostSerializer.new(@posts).serializable_hash
end
```

---

## バージョニング

APIのバージョン管理。

### URLベース（推奨）

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :posts
      resources :users
    end

    namespace :v2 do
      resources :posts
      resources :users
    end
  end
end

# /api/v1/posts
# /api/v2/posts
```

```
app/
└── controllers/
    └── api/
        ├── v1/
        │   ├── posts_controller.rb
        │   └── users_controller.rb
        └── v2/
            ├── posts_controller.rb
            └── users_controller.rb
```

### ヘッダーベース

```ruby
# config/routes.rb
Rails.application.routes.draw do
  scope module: :api do
    scope module: :v1, constraints: ApiVersion.new('v1', true) do
      resources :posts
    end

    scope module: :v2, constraints: ApiVersion.new('v2') do
      resources :posts
    end
  end
end

# lib/api_version.rb
class ApiVersion
  def initialize(version, default = false)
    @version = version
    @default = default
  end

  def matches?(request)
    @default || check_headers(request.headers)
  end

  private

  def check_headers(headers)
    accept = headers['Accept']
    accept && accept.include?("application/vnd.myapp.#{@version}+json")
  end
end
```

---

## CORS設定

クロスオリジンリクエストを許可。

### rack-cors

```ruby
# Gemfile
gem 'rack-cors'
```

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # または 'localhost:3000', 'example.com'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

### 本番環境では特定のオリジンのみ許可

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://example.com', 'https://www.example.com'

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete],
      credentials: true,
      max_age: 86400
  end
end
```

---

## ページネーション

大量のデータを分割して返す。

### kaminari

```ruby
# Gemfile
gem 'kaminari'
```

```ruby
# app/controllers/api/v1/posts_controller.rb
def index
  @posts = Post.page(params[:page]).per(params[:per_page] || 20)

  render json: @posts, meta: {
    current_page: @posts.current_page,
    total_pages: @posts.total_pages,
    total_count: @posts.total_count
  }
end
```

### pagy（高速・軽量）

```ruby
# Gemfile
gem 'pagy'
```

```ruby
# app/controllers/application_controller.rb
include Pagy::Backend

# app/controllers/api/v1/posts_controller.rb
def index
  pagy, posts = pagy(Post.all, items: params[:per_page] || 20)

  render json: {
    posts: posts,
    pagy: {
      count: pagy.count,
      page: pagy.page,
      items: pagy.items,
      pages: pagy.pages,
      last: pagy.last,
      prev: pagy.prev,
      next: pagy.next
    }
  }
end
```

### カスタム実装

```ruby
def index
  page = params[:page]&.to_i || 1
  per_page = params[:per_page]&.to_i || 20

  @posts = Post.limit(per_page).offset((page - 1) * per_page)
  total_count = Post.count

  render json: {
    posts: @posts,
    meta: {
      current_page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: (total_count.to_f / per_page).ceil
    }
  }
end
```

---

## エラーハンドリング

統一されたエラーレスポンス。

### 基本的なエラーハンドリング

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  private

  def record_not_found(exception)
    render json: {
      error: {
        message: 'Record not found',
        details: exception.message
      }
    }, status: :not_found
  end

  def record_invalid(exception)
    render json: {
      error: {
        message: 'Validation failed',
        details: exception.record.errors.full_messages
      }
    }, status: :unprocessable_entity
  end

  def parameter_missing(exception)
    render json: {
      error: {
        message: 'Parameter missing',
        details: exception.message
      }
    }, status: :bad_request
  end
end
```

### 統一されたエラーフォーマット

```ruby
# app/controllers/concerns/error_handler.rb
module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record
  end

  private

  def handle_standard_error(exception)
    Rails.logger.error exception.message
    Rails.logger.error exception.backtrace.join("\n")

    render json: error_response('Internal server error'), status: :internal_server_error
  end

  def handle_not_found(exception)
    render json: error_response(exception.message), status: :not_found
  end

  def handle_invalid_record(exception)
    render json: error_response(exception.message, exception.record.errors), status: :unprocessable_entity
  end

  def error_response(message, errors = nil)
    {
      error: {
        message: message,
        errors: errors
      }
    }
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include ErrorHandler
end
```

---

## 認証

API認証の実装。

### JWT認証

```ruby
# Gemfile
gem 'jwt'

# app/lib/json_web_token.rb
class JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError
    nil
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :authenticate_request

  private

  def authenticate_request
    header = request.headers['Authorization']
    token = header.split(' ').last if header
    decoded = JsonWebToken.decode(token)
    @current_user = User.find(decoded[:user_id]) if decoded
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def current_user
    @current_user
  end
end

# app/controllers/authentication_controller.rb
class AuthenticationController < ApplicationController
  skip_before_action :authenticate_request, only: [:login]

  def login
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      render json: { token: token, user: user }, status: :ok
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end
end
```

---

## ベストプラクティス

### 1. バージョニングを行う

```ruby
# URLベースのバージョニング
namespace :api do
  namespace :v1 do
    resources :posts
  end
end
```

### 2. 統一されたレスポンス形式

```ruby
# 成功
{
  "data": { ... },
  "meta": { ... }
}

# エラー
{
  "error": {
    "message": "...",
    "details": [...]
  }
}
```

### 3. ページネーション

```ruby
# 大量データには必ずページネーション
@posts = Post.page(params[:page]).per(20)
```

### 4. レート制限

```ruby
# Gemfile
gem 'rack-attack'
```

### 5. ドキュメント

```ruby
# Gemfile
gem 'rswag'  # OpenAPI/Swagger
# または
gem 'apipie-rails'
```

---

## 参考リンク

- [Rails API documentation](https://api.rubyonrails.org/)
- [Active Model Serializers](https://github.com/rails-api/active_model_serializers)
- [Jbuilder](https://github.com/rails/jbuilder)
- [jsonapi-serializer](https://github.com/jsonapi-serializer/jsonapi-serializer)
- [rack-cors](https://github.com/cyu/rack-cors)
- [kaminari](https://github.com/kaminari/kaminari)
- [pagy](https://github.com/ddnexus/pagy)
