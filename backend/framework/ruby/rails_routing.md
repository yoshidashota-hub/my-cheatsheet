# Ruby on Rails ルーティング

## 目次
- [ルーティングの基本](#ルーティングの基本)
- [RESTfulルーティング](#restfulルーティング)
- [ルート定義](#ルート定義)
- [ネストしたリソース](#ネストしたリソース)
- [名前空間](#名前空間)
- [カスタムルート](#カスタムルート)
- [制約](#制約)
- [ルーティングヘルパー](#ルーティングヘルパー)

---

## ルーティングの基本

ルーティングは `config/routes.rb` で定義する。

### 基本構文
```ruby
# config/routes.rb
Rails.application.routes.draw do
  # HTTPメソッド 'URL' => 'コントローラー#アクション'
  get '/welcome', to: 'pages#home'
end
```

### 確認方法
```bash
# 全ルート表示
rails routes

# 特定コントローラーのみ
rails routes -c users

# grepで検索
rails routes | grep posts
```

---

## RESTfulルーティング

### resources
単数形のリソース名を複数形で定義すると、7つのRESTfulなルートが自動生成される。

```ruby
resources :posts
```

生成されるルート：

| HTTPメソッド | パス | コントローラー#アクション | 用途 |
|------------|------|----------------------|------|
| GET | /posts | posts#index | 一覧表示 |
| GET | /posts/new | posts#new | 新規作成フォーム |
| POST | /posts | posts#create | 新規作成処理 |
| GET | /posts/:id | posts#show | 詳細表示 |
| GET | /posts/:id/edit | posts#edit | 編集フォーム |
| PATCH/PUT | /posts/:id | posts#update | 更新処理 |
| DELETE | /posts/:id | posts#destroy | 削除処理 |

### 必要なアクションのみ指定

```ruby
# index, show のみ
resources :posts, only: [:index, :show]

# destroy 以外
resources :posts, except: [:destroy]
```

### 単数形リソース
ログイン中のユーザープロフィールなど、IDが不要な場合。

```ruby
resource :profile
```

生成されるルート（index なし、:id なし）：

| HTTPメソッド | パス | コントローラー#アクション |
|------------|------|----------------------|
| GET | /profile/new | profiles#new |
| POST | /profile | profiles#create |
| GET | /profile | profiles#show |
| GET | /profile/edit | profiles#edit |
| PATCH/PUT | /profile | profiles#update |
| DELETE | /profile | profiles#destroy |

---

## ルート定義

### 基本的なルート
```ruby
# GET リクエスト
get '/about', to: 'pages#about'

# POST リクエスト
post '/contact', to: 'pages#contact'

# PATCH/PUT リクエスト
patch '/settings', to: 'users#update'
put '/settings', to: 'users#update'

# DELETE リクエスト
delete '/logout', to: 'sessions#destroy'

# 複数のHTTPメソッドに対応
match '/search', to: 'search#index', via: [:get, :post]

# 全てのHTTPメソッド（非推奨）
match '/wildcard', to: 'pages#wildcard', via: :all
```

### ルートパス
```ruby
# ルートURL（/）
root 'pages#home'
# => http://example.com/ → pages#home
```

### リダイレクト
```ruby
# 別のURLにリダイレクト
get '/old-page', to: redirect('/new-page')

# 外部URL
get '/google', to: redirect('https://www.google.com')

# 動的リダイレクト
get '/posts/:id', to: redirect { |path_params, req|
  "/articles/#{path_params[:id]}"
}
```

---

## ネストしたリソース

親子関係のあるリソースを表現。

### 基本的なネスト
```ruby
resources :posts do
  resources :comments
end
```

生成されるルート例：
```
GET    /posts/:post_id/comments          comments#index
POST   /posts/:post_id/comments          comments#create
GET    /posts/:post_id/comments/new      comments#new
GET    /posts/:post_id/comments/:id      comments#show
GET    /posts/:post_id/comments/:id/edit comments#edit
PATCH  /posts/:post_id/comments/:id      comments#update
DELETE /posts/:post_id/comments/:id      comments#destroy
```

### 浅いネスト（推奨）
ネストは1階層のみが推奨。`shallow: true` で不要なネストを回避。

```ruby
resources :posts do
  resources :comments, shallow: true
end
```

生成されるルート：
```
# ネストが必要（親が必要）
GET    /posts/:post_id/comments/new      comments#new
POST   /posts/:post_id/comments          comments#create

# ネスト不要（子のIDで識別可能）
GET    /comments/:id                     comments#show
GET    /comments/:id/edit                comments#edit
PATCH  /comments/:id                     comments#update
DELETE /comments/:id                     comments#destroy
```

別の書き方：
```ruby
resources :posts do
  resources :comments, only: [:index, :new, :create]
end
resources :comments, only: [:show, :edit, :update, :destroy]
```

### memberとcollection
resourcesに追加のアクションを定義。

```ruby
resources :posts do
  # member: 個別リソース（:id付き）
  member do
    post 'publish'      # POST /posts/:id/publish
    get 'preview'       # GET /posts/:id/preview
  end

  # collection: コレクション（:id不要）
  collection do
    get 'search'        # GET /posts/search
    post 'bulk_delete'  # POST /posts/bulk_delete
  end
end
```

短縮形：
```ruby
resources :posts do
  post 'publish', on: :member
  get 'search', on: :collection
end
```

---

## 名前空間

管理画面など、コントローラーを階層的に整理。

### namespace
URLとコントローラーのパスの両方に名前空間を追加。

```ruby
namespace :admin do
  resources :posts
  resources :users
end
```

生成されるルート：
```
GET /admin/posts     Admin::PostsController#index
GET /admin/users     Admin::UsersController#index
```

コントローラーの配置：
```
app/controllers/admin/posts_controller.rb
app/controllers/admin/users_controller.rb
```

```ruby
# app/controllers/admin/posts_controller.rb
module Admin
  class PostsController < ApplicationController
    def index
      # ...
    end
  end
end
```

### scope module
URLには名前空間を追加せず、コントローラーのみモジュール化。

```ruby
scope module: 'admin' do
  resources :posts
end
```

生成されるルート：
```
GET /posts     Admin::PostsController#index
```

### scope (URLのみ)
コントローラーのパスは変えず、URLのみプレフィックスを追加。

```ruby
scope '/admin' do
  resources :posts  # PostsController（Adminモジュールなし）
end
```

生成されるルート：
```
GET /admin/posts     PostsController#index
```

### as でパス名をカスタマイズ
```ruby
scope '/admin', as: 'admin' do
  resources :posts
end
# => admin_posts_path ヘルパーが生成される
```

---

## カスタムルート

### パス名のカスタマイズ
```ruby
# URLパスを変更
resources :posts, path: 'articles'
# GET /articles     posts#index

# パスヘルパー名を変更
resources :posts, as: 'articles'
# articles_path → /posts
```

### 複数形/単数形のカスタマイズ
```ruby
resources :news, controller: 'news'
# デフォルトでは news_controller を探すが、単数形で指定可能
```

### コントローラー名を明示
```ruby
resources :photos, controller: 'images'
# /photos → ImagesController
```

---

## 制約

### パラメータ制約
```ruby
# 数字のみ
get '/posts/:id', to: 'posts#show', constraints: { id: /\d+/ }

# 複数パラメータ
get '/users/:id/posts/:post_id', to: 'posts#show',
  constraints: { id: /\d+/, post_id: /\d+/ }
```

### リクエストベースの制約
```ruby
# サブドメイン制約
constraints subdomain: 'api' do
  namespace :api do
    resources :posts
  end
end

# カスタム制約クラス
class AdminConstraint
  def matches?(request)
    request.session[:user_type] == 'admin'
  end
end

constraints AdminConstraint.new do
  namespace :admin do
    resources :posts
  end
end

# ラムダで簡易的に
constraints lambda { |req| req.session[:user_type] == 'admin' } do
  namespace :admin do
    resources :posts
  end
end
```

### フォーマット制約
```ruby
# JSONのみ許可
resources :posts, constraints: { format: 'json' }

# デフォルトフォーマット
resources :posts, defaults: { format: 'json' }
```

---

## ルーティングヘルパー

### パスヘルパー
```ruby
resources :posts
```

生成されるヘルパー：

| ヘルパーメソッド | 戻り値 |
|---------------|-------|
| posts_path | /posts |
| new_post_path | /posts/new |
| edit_post_path(@post) | /posts/1/edit |
| post_path(@post) | /posts/1 |

### URLヘルパー
完全なURLを返す（プロトコル、ホスト名含む）。

```ruby
posts_url
# => http://example.com/posts

post_url(@post)
# => http://example.com/posts/1
```

### コントローラーとビューでの使用
```ruby
# app/controllers/posts_controller.rb
def create
  @post = Post.create(post_params)
  redirect_to post_path(@post)  # /posts/1
  # または
  redirect_to @post  # Railsが自動的にpost_pathに変換
end
```

```erb
<!-- app/views/posts/index.html.erb -->
<%= link_to 'New Post', new_post_path %>
<%= link_to post.title, post_path(post) %>
<%= link_to 'Edit', edit_post_path(post) %>
<%= link_to 'Delete', post_path(post), method: :delete, data: { confirm: 'Are you sure?' } %>
```

### パラメータ付きヘルパー
```ruby
# クエリパラメータ
posts_path(page: 2, sort: 'title')
# => /posts?page=2&sort=title

# アンカー
post_path(@post, anchor: 'comments')
# => /posts/1#comments
```

---

## グローバル設定

### デフォルトURL オプション
```ruby
# config/environments/production.rb
Rails.application.routes.default_url_options[:host] = 'example.com'
Rails.application.routes.default_url_options[:protocol] = 'https'
```

### トレイリングスラッシュ
```ruby
# トレイリングスラッシュをリダイレクト
get '/posts/', to: redirect('/posts')
```

---

## Concern（共通ルート）

複数のリソースで共通のルートを定義。

```ruby
# concern定義
concern :commentable do
  resources :comments
end

concern :image_attachable do
  resources :images, only: [:index, :create, :destroy]
end

# 使用
resources :posts, concerns: [:commentable, :image_attachable]
resources :articles, concerns: :commentable

# 展開される
# /posts/1/comments
# /posts/1/images
# /articles/1/comments
```

---

## ルートの検証とデバッグ

### ルート一覧を見やすく
```bash
# 全ルート表示
rails routes

# 特定のコントローラー
rails routes -c posts

# 特定のアクション
rails routes -g new

# 拡張表示（必要なカラムのみ）
rails routes --expanded
```

### ルート確認コマンド
```bash
# 特定URLがどのルートにマッチするか
rails routes | grep "/posts"

# ヘルパーメソッド名から検索
rails routes | grep post_path
```

### Railsコンソールで確認
```ruby
# コンソールで確認
Rails.application.routes.url_helpers.posts_path
# => "/posts"

# 認識できるか確認
Rails.application.routes.recognize_path('/posts/1', method: :get)
# => {:controller=>"posts", :action=>"show", :id=>"1"}
```

---

## よくあるパターン

### APIとWebの分離
```ruby
namespace :api do
  namespace :v1 do
    resources :posts, only: [:index, :show], defaults: { format: :json }
  end
end

# Web版
resources :posts
```

### 複雑なネスト例
```ruby
resources :users do
  resource :profile, only: [:show, :edit, :update]
  resources :posts, shallow: true do
    resources :comments, only: [:create]
  end
end
```

### 管理画面と一般画面
```ruby
# 一般ユーザー
resources :posts, only: [:index, :show]

# 管理者
namespace :admin do
  resources :posts
  resources :users
  resources :categories
end
```

---

## ベストプラクティス

### 1. RESTfulなルート設計
- できるだけ `resources` を使用
- カスタムアクションは最小限に

### 2. 浅いネスト
- ネストは1階層まで
- `shallow: true` を活用

### 3. 明確な命名
- ルート名は一目で用途がわかるように
- `as` オプションで適切な名前を付ける

### 4. 制約の活用
- パラメータは正規表現で検証
- セキュリティを考慮

### 5. concernで共通化
- 重複するルート定義は concern にまとめる

---

## トラブルシューティング

### ルートが見つからない
```bash
# ルート確認
rails routes

# キャッシュクリア
rails tmp:clear
spring stop
```

### ヘルパーメソッドが見つからない
```ruby
# ルート定義を確認
rails routes -c posts

# 正しいヘルパー名を使用
posts_path     # ○
post_index_path  # ✗（存在しない）
```

### 優先順位の問題
```ruby
# ✗ 後ろのルートが優先されない
get '/posts/:id', to: 'posts#show'
get '/posts/search', to: 'posts#search'  # マッチしない

# ○ 具体的なルートを先に定義
get '/posts/search', to: 'posts#search'
get '/posts/:id', to: 'posts#show'
```

---

## 参考リンク

- [Rails Routing from the Outside In](https://guides.rubyonrails.org/routing.html)
- [Railsガイド：ルーティング](https://railsguides.jp/routing.html)
