# Ruby on Rails コントローラー

## 目次
- [コントローラーの基本](#コントローラーの基本)
- [アクション](#アクション)
- [パラメータ](#パラメータ)
- [レスポンス](#レスポンス)
- [フィルター](#フィルター)
- [Strong Parameters](#strong-parameters)
- [セッション・Cookie](#セッションcookie)
- [フラッシュメッセージ](#フラッシュメッセージ)

---

## コントローラーの基本

コントローラーは `app/controllers/` に配置し、`ApplicationController` を継承する。

### コントローラー生成
```bash
# 基本
rails generate controller Posts index show

# 名前空間付き
rails generate controller Admin::Posts index
```

### 基本構造
```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def index
    @posts = Post.all
  end

  def show
    @post = Post.find(params[:id])
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)
    if @post.save
      redirect_to @post, notice: 'Post was successfully created.'
    else
      render :new
    end
  end

  def edit
    @post = Post.find(params[:id])
  end

  def update
    @post = Post.find(params[:id])
    if @post.update(post_params)
      redirect_to @post, notice: 'Post was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @post = Post.find(params[:id])
    @post.destroy
    redirect_to posts_url, notice: 'Post was successfully destroyed.'
  end

  private

  def post_params
    params.require(:post).permit(:title, :body)
  end
end
```

---

## アクション

### RESTfulな7つのアクション

| アクション | 用途 | HTTPメソッド | URL |
|----------|------|------------|-----|
| index | 一覧表示 | GET | /posts |
| show | 詳細表示 | GET | /posts/:id |
| new | 新規作成フォーム | GET | /posts/new |
| create | 新規作成処理 | POST | /posts |
| edit | 編集フォーム | GET | /posts/:id/edit |
| update | 更新処理 | PATCH/PUT | /posts/:id |
| destroy | 削除処理 | DELETE | /posts/:id |

### カスタムアクション
```ruby
class PostsController < ApplicationController
  # member（個別リソース用）
  def publish
    @post = Post.find(params[:id])
    @post.update(published: true)
    redirect_to @post
  end

  # collection（コレクション用）
  def search
    @posts = Post.where('title LIKE ?', "%#{params[:q]}%")
    render :index
  end
end
```

```ruby
# config/routes.rb
resources :posts do
  member do
    post :publish
  end
  collection do
    get :search
  end
end
```

---

## パラメータ

### params ハッシュ
```ruby
# URL: /posts?search=rails&page=2
params[:search]  # => "rails"
params[:page]    # => "2"

# URL: /posts/1
params[:id]      # => "1"

# フォーム送信
# { post: { title: "Hello", body: "World" } }
params[:post][:title]  # => "Hello"
```

### パラメータの種類

#### 1. クエリパラメータ
```ruby
# GET /posts?page=2&sort=title
params[:page]  # => "2"
params[:sort]  # => "title"
```

#### 2. URLパラメータ
```ruby
# GET /posts/123
params[:id]  # => "123"

# ルート定義: get '/posts/:year/:month', to: 'posts#archive'
# GET /posts/2023/12
params[:year]   # => "2023"
params[:month]  # => "12"
```

#### 3. フォームパラメータ（POST/PATCH）
```ruby
# POST /posts
# { post: { title: "Title", body: "Body" } }
params[:post]
# => { "title" => "Title", "body" => "Body" }
```

### パラメータへのアクセス
```ruby
# ハッシュ形式
params[:id]
params['id']  # 文字列キーでも可

# requireとpermit（Strong Parameters）
params.require(:post).permit(:title, :body)
```

---

## レスポンス

### render（ビューを表示）
```ruby
# デフォルト（アクション名と同じビューを表示）
def index
  @posts = Post.all
  # 自動的に app/views/posts/index.html.erb をレンダリング
end

# 明示的に指定
render :index
render 'index'
render 'posts/index'

# 別コントローラーのビュー
render 'admin/posts/index'

# テンプレートなし（インラインテキスト）
render plain: 'Hello World'
render html: '<h1>Hello</h1>'.html_safe
render json: @post
render xml: @post
render js: "alert('Hello');"

# ステータスコード指定
render :new, status: :unprocessable_entity
render json: { error: 'Not Found' }, status: :not_found
render :show, status: 201

# レイアウト指定
render layout: 'admin'
render layout: false  # レイアウトなし
```

### redirect_to（リダイレクト）
```ruby
# モデルオブジェクトへ
redirect_to @post  # post_path(@post) と同じ

# 名前付きルート
redirect_to posts_path
redirect_to post_path(@post)
redirect_to edit_post_path(@post)

# URL文字列
redirect_to '/posts'
redirect_to 'https://example.com'

# back（前のページへ）
redirect_to :back
redirect_back(fallback_location: root_path)

# ステータスコード指定
redirect_to @post, status: :moved_permanently
redirect_to @post, status: 301

# フラッシュメッセージ付き
redirect_to @post, notice: 'Post was successfully created.'
redirect_to @post, alert: 'Something went wrong.'
```

### head（ヘッダーのみ）
```ruby
# 204 No Content
head :no_content

# 404 Not Found
head :not_found

# 403 Forbidden
head :forbidden
```

### send_file / send_data（ファイル送信）
```ruby
# ファイル送信
def download
  send_file '/path/to/file.pdf',
    filename: 'document.pdf',
    type: 'application/pdf',
    disposition: 'attachment'  # または 'inline'
end

# データ送信
def export
  csv_data = generate_csv(@posts)
  send_data csv_data,
    filename: 'posts.csv',
    type: 'text/csv',
    disposition: 'attachment'
end
```

---

## フィルター

アクション実行の前後に処理を挟む。

### before_action
```ruby
class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]
  before_action :check_admin, only: [:destroy]

  def show
    # @post はすでにセットされている
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def authenticate_user!
    redirect_to login_path unless logged_in?
  end

  def check_admin
    head :forbidden unless current_user.admin?
  end
end
```

### after_action
```ruby
class PostsController < ApplicationController
  after_action :log_access, only: [:show]

  def show
    @post = Post.find(params[:id])
  end

  private

  def log_access
    Rails.logger.info "Post #{@post.id} was accessed"
  end
end
```

### around_action
```ruby
class PostsController < ApplicationController
  around_action :measure_time

  def index
    @posts = Post.all
  end

  private

  def measure_time
    start_time = Time.current
    yield  # アクション実行
    end_time = Time.current
    Rails.logger.info "Time: #{end_time - start_time}s"
  end
end
```

### skip_before_action
親クラスのフィルターをスキップ。

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end

class PublicController < ApplicationController
  skip_before_action :authenticate_user!
end
```

### フィルターオプション
```ruby
# 特定アクションのみ
before_action :authenticate, only: [:edit, :update, :destroy]

# 特定アクション以外
before_action :authenticate, except: [:index, :show]

# if/unless条件
before_action :check_admin, if: :admin_required?
before_action :redirect_mobile, unless: :desktop?

private

def admin_required?
  params[:admin].present?
end
```

---

## Strong Parameters

セキュリティのため、許可されたパラメータのみを受け取る。

### 基本
```ruby
class PostsController < ApplicationController
  def create
    @post = Post.new(post_params)
    # ...
  end

  private

  def post_params
    params.require(:post).permit(:title, :body, :published)
  end
end
```

### ネストした属性
```ruby
# 配列を許可
params.require(:post).permit(:title, tag_ids: [])

# ネストしたハッシュ
params.require(:post).permit(
  :title,
  :body,
  author_attributes: [:name, :email]
)

# 配列内のハッシュ
params.require(:post).permit(
  :title,
  comments_attributes: [:id, :body, :_destroy]
)
```

### 複雑な例
```ruby
def post_params
  params.require(:post).permit(
    :title,
    :body,
    :published,
    :category_id,
    tag_ids: [],
    author_attributes: [:name, :email],
    comments_attributes: [:id, :body, :user_id, :_destroy],
    images: []
  )
end
```

### すべてのパラメータを許可（非推奨）
```ruby
# セキュリティリスクあり
params.require(:post).permit!
```

---

## セッション・Cookie

### セッション
```ruby
# 保存
session[:user_id] = @user.id
session[:cart] = { items: [1, 2, 3] }

# 読み込み
current_user_id = session[:user_id]

# 削除
session.delete(:user_id)
session[:user_id] = nil

# 全削除
reset_session
```

### Cookie
```ruby
# 保存（シンプル）
cookies[:username] = 'john'

# オプション付き
cookies[:username] = {
  value: 'john',
  expires: 1.year.from_now,
  domain: '.example.com',
  secure: true,      # HTTPSのみ
  httponly: true     # JavaScriptからアクセス不可
}

# 署名付きCookie（改ざん防止）
cookies.signed[:user_id] = @user.id

# 暗号化Cookie
cookies.encrypted[:ssn] = '123-45-6789'

# 読み込み
username = cookies[:username]
user_id = cookies.signed[:user_id]

# 削除
cookies.delete(:username)
```

---

## フラッシュメッセージ

一時的なメッセージを次のリクエストで表示。

### 基本
```ruby
# 設定
flash[:notice] = 'Post was successfully created.'
flash[:alert] = 'Something went wrong.'

# redirect_to と同時に
redirect_to @post, notice: 'Post was successfully created.'
redirect_to @post, alert: 'Error occurred.'

# 現在のリクエストで表示（リダイレクトなし）
flash.now[:notice] = 'Validation failed.'
render :new
```

### ビューで表示
```erb
<!-- app/views/layouts/application.html.erb -->
<% if flash[:notice] %>
  <div class="alert alert-success"><%= flash[:notice] %></div>
<% end %>

<% if flash[:alert] %>
  <div class="alert alert-danger"><%= flash[:alert] %></div>
<% end %>

<!-- または -->
<% flash.each do |type, message| %>
  <div class="alert alert-<%= type %>"><%= message %></div>
<% end %>
```

### カスタムキー
```ruby
flash[:success] = 'Operation successful!'
flash[:error] = 'An error occurred.'
flash[:warning] = 'Please be careful.'
```

---

## その他の機能

### request オブジェクト
```ruby
# HTTPメソッド
request.get?
request.post?
request.patch?
request.put?
request.delete?

# リクエスト情報
request.url              # 完全なURL
request.path             # パス部分
request.query_string     # クエリ文字列
request.remote_ip        # クライアントIP
request.user_agent       # ユーザーエージェント

# リファラー
request.referer
request.referrer  # エイリアス

# フォーマット
request.format           # :html, :json など
request.content_type     # Content-Type ヘッダー

# AJAX判定
request.xhr?
```

### response オブジェクト
```ruby
# ヘッダー設定
response.headers['X-Custom-Header'] = 'value'

# Content-Type設定
response.content_type = 'application/json'

# ステータスコード
response.status = 404
```

### logger
```ruby
# ログ出力
logger.debug 'Debug message'
logger.info 'Info message'
logger.warn 'Warning message'
logger.error 'Error message'
logger.fatal 'Fatal message'

# 変数をログ
logger.info "User ID: #{@user.id}"
```

### rescue_from（例外処理）
```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

  private

  def record_not_found
    render plain: '404 Not Found', status: :not_found
  end

  def record_invalid(exception)
    render json: { errors: exception.record.errors }, status: :unprocessable_entity
  end
end
```

---

## 継承とモジュール

### ApplicationController
全コントローラーの親クラス。共通処理を定義。

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    redirect_to login_path unless logged_in?
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
  end
end
```

### Concerns
共通機能をモジュール化。

```ruby
# app/controllers/concerns/authenticatable.rb
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    helper_method :current_user
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def authenticate_user!
    redirect_to login_path unless current_user
  end
end
```

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  include Authenticatable

  def index
    # current_user が使える
  end
end
```

---

## ベストプラクティス

### 1. Fat Model, Skinny Controller
ビジネスロジックはモデルに配置。

```ruby
# ✗ 悪い例
class PostsController < ApplicationController
  def publish
    @post = Post.find(params[:id])
    @post.published = true
    @post.published_at = Time.current
    @post.save
    NotificationMailer.published(@post).deliver_later
  end
end

# ○ 良い例
class PostsController < ApplicationController
  def publish
    @post = Post.find(params[:id])
    @post.publish!
  end
end

class Post < ApplicationRecord
  def publish!
    update(published: true, published_at: Time.current)
    NotificationMailer.published(self).deliver_later
  end
end
```

### 2. before_action で重複を排除
```ruby
# ○ 良い例
class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  private

  def set_post
    @post = Post.find(params[:id])
  end
end
```

### 3. Strong Parameters を徹底
```ruby
# 必ず private メソッドに
private

def post_params
  params.require(:post).permit(:title, :body)
end
```

### 4. RESTful設計を守る
- カスタムアクションは最小限に
- 7つのRESTfulアクションで表現できないか検討

---

## 参考リンク

- [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html)
- [Railsガイド：コントローラー](https://railsguides.jp/action_controller_overview.html)
