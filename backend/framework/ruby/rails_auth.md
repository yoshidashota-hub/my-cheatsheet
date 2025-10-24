# Ruby on Rails 認証・認可

## 目次
- [認証とは](#認証とは)
- [基本的な認証実装](#基本的な認証実装)
- [Devise](#devise)
- [Pundit（認可）](#pundit認可)
- [CanCanCan（認可）](#cancancan認可)
- [API認証](#api認証)
- [セキュリティ対策](#セキュリティ対策)

---

## 認証とは

### 認証（Authentication）vs 認可（Authorization）

- **認証（Authentication）**: ユーザーが誰であるかを確認（ログイン）
- **認可（Authorization）**: ユーザーが何をできるかを制御（権限管理）

---

## 基本的な認証実装

### has_secure_password

Railsの標準機能。bcryptを使用してパスワードをハッシュ化。

#### セットアップ

```ruby
# Gemfile
gem 'bcrypt'

# マイグレーション
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end

# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 6 }, if: -> { new_record? || password.present? }
end
```

#### 使用方法

```ruby
# ユーザー作成
user = User.create(
  name: 'John',
  email: 'john@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# 認証
user.authenticate('password123')  # => userオブジェクト
user.authenticate('wrong')        # => false
```

### セッション管理

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  def new
    # ログインフォーム表示
  end

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path, notice: 'ログインしました'
    else
      flash.now[:alert] = 'メールアドレスまたはパスワードが無効です'
      render :new
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: 'ログアウトしました'
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    redirect_to login_path, alert: 'ログインしてください' unless logged_in?
  end
end
```

### ビュー

```erb
<!-- app/views/sessions/new.html.erb -->
<%= form_with url: login_path, local: true do |f| %>
  <div>
    <%= f.label :email %>
    <%= f.email_field :email, required: true %>
  </div>

  <div>
    <%= f.label :password %>
    <%= f.password_field :password, required: true %>
  </div>

  <%= f.submit 'ログイン' %>
<% end %>
```

### ルーティング

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  resources :users, only: [:new, :create]
end
```

---

## Devise

最も人気のある認証gem。多機能で拡張性が高い。

### インストール

```ruby
# Gemfile
gem 'devise'

# セットアップ
rails generate devise:install
rails generate devise User
rails db:migrate
```

### 基本設定

```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  config.mailer_sender = 'no-reply@example.com'
  config.password_length = 6..128
  config.timeout_in = 30.minutes
  config.sign_out_via = :delete
end
```

### モデル

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :timeoutable, :trackable
end
```

#### Deviseモジュール

| モジュール | 機能 |
|----------|------|
| :database_authenticatable | パスワード認証 |
| :registerable | 登録機能 |
| :recoverable | パスワードリセット |
| :rememberable | Remember Me |
| :validatable | バリデーション |
| :confirmable | メール確認 |
| :lockable | ロックアウト（複数回失敗） |
| :timeoutable | タイムアウト |
| :trackable | ログイン追跡 |
| :omniauthable | OAuth認証 |

### コントローラー

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!  # 全コントローラーで認証要求
end

# 特定のアクションをスキップ
class PostsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
end
```

### ビューのカスタマイズ

```bash
# ビューを生成
rails generate devise:views

# 特定のモデルのみカスタマイズ
rails generate devise:views users
```

```ruby
# config/initializers/devise.rb
config.scoped_views = true
```

### ルーティング

```ruby
# config/routes.rb
devise_for :users

# カスタムコントローラー
devise_for :users, controllers: {
  sessions: 'users/sessions',
  registrations: 'users/registrations'
}

# カスタムパス
devise_for :users, path: 'auth', path_names: {
  sign_in: 'login',
  sign_out: 'logout',
  registration: 'register',
  sign_up: 'signup'
}
```

### ヘルパーメソッド

```ruby
# コントローラー/ビュー
current_user          # 現在のユーザー
user_signed_in?       # ログイン中か
authenticate_user!    # 認証を要求
sign_in(@user)        # ログイン
sign_out(@user)       # ログアウト
```

### Strong Parameters

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :age])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :age])
  end
end
```

---

## Pundit（認可）

ポリシーベースの認可gem。

### インストール

```ruby
# Gemfile
gem 'pundit'

# セットアップ
rails generate pundit:install
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = '権限がありません'
    redirect_to(request.referrer || root_path)
  end
end
```

### ポリシー定義

```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def index?
    true  # 誰でも一覧表示可能
  end

  def show?
    true  # 誰でも詳細表示可能
  end

  def create?
    user.present?  # ログイン中のみ作成可能
  end

  def update?
    user.present? && (record.user == user || user.admin?)
  end

  def destroy?
    user.present? && (record.user == user || user.admin?)
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.where(published: true)
      end
    end
  end
end
```

### コントローラーで使用

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def index
    @posts = policy_scope(Post)
  end

  def show
    @post = Post.find(params[:id])
    authorize @post
  end

  def create
    @post = Post.new(post_params)
    authorize @post

    if @post.save
      redirect_to @post
    else
      render :new
    end
  end

  def update
    @post = Post.find(params[:id])
    authorize @post

    if @post.update(post_params)
      redirect_to @post
    else
      render :edit
    end
  end

  def destroy
    @post = Post.find(params[:id])
    authorize @post
    @post.destroy
    redirect_to posts_path
  end
end
```

### ビューで使用

```erb
<% if policy(@post).update? %>
  <%= link_to 'Edit', edit_post_path(@post) %>
<% end %>

<% if policy(@post).destroy? %>
  <%= link_to 'Delete', post_path(@post), method: :delete %>
<% end %>

<% if policy(Post).create? %>
  <%= link_to 'New Post', new_post_path %>
<% end %>
```

---

## CanCanCan（認可）

能力（Ability）ベースの認可gem。

### インストール

```ruby
# Gemfile
gem 'cancancan'

# セットアップ
rails generate cancan:ability
```

### Ability定義

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new  # ゲストユーザー

    if user.admin?
      can :manage, :all  # 全ての操作が可能
    elsif user.persisted?
      can :read, Post
      can [:create, :update, :destroy], Post, user_id: user.id
      can :read, Comment
      can [:create, :destroy], Comment, user_id: user.id
    else
      can :read, Post, published: true
      can :read, Comment
    end
  end
end
```

#### アクション

- `:read` - index, show
- `:create` - new, create
- `:update` - edit, update
- `:destroy` - destroy
- `:manage` - 全てのアクション

### コントローラーで使用

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  load_and_authorize_resource

  def index
    # @posts は自動的にロードされる
  end

  def show
    # @post は自動的にロードされ、認可される
  end

  def create
    # @post は自動的にロードされ、認可される
    if @post.save
      redirect_to @post
    else
      render :new
    end
  end
end
```

### ビューで使用

```erb
<% if can? :create, Post %>
  <%= link_to 'New Post', new_post_path %>
<% end %>

<% if can? :update, @post %>
  <%= link_to 'Edit', edit_post_path(@post) %>
<% end %>

<% if can? :destroy, @post %>
  <%= link_to 'Delete', post_path(@post), method: :delete %>
<% end %>
```

### 例外処理

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, alert: exception.message
  end
end
```

---

## API認証

### JWT（JSON Web Token）

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
  rescue JWT::DecodeError => e
    nil
  end
end
```

```ruby
# app/controllers/authentication_controller.rb
class AuthenticationController < ApplicationController
  def login
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      render json: { token: token }, status: :ok
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
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
  rescue ActiveRecord::RecordNotFound, JWT::DecodeError
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
```

### トークン認証

```ruby
# マイグレーション
class AddAuthTokenToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :auth_token, :string
    add_index :users, :auth_token, unique: true
  end
end

# app/models/user.rb
class User < ApplicationRecord
  before_create :generate_auth_token

  private

  def generate_auth_token
    loop do
      self.auth_token = SecureRandom.urlsafe_base64
      break unless User.exists?(auth_token: auth_token)
    end
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :authenticate_user

  private

  def authenticate_user
    token = request.headers['Authorization']&.split(' ')&.last
    @current_user = User.find_by(auth_token: token)
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
  end
end
```

---

## セキュリティ対策

### CSRF対策

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  # または
  protect_from_forgery with: :null_session  # API mode
end
```

```erb
<!-- ビュー（自動的に追加される） -->
<%= csrf_meta_tags %>
```

### 強制SSL

```ruby
# config/environments/production.rb
config.force_ssl = true
```

### セキュアなパスワード

```ruby
class User < ApplicationRecord
  has_secure_password

  validates :password,
    length: { minimum: 8 },
    format: {
      with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      message: 'must include lowercase, uppercase, and number'
    },
    if: -> { new_record? || password.present? }
end
```

### レート制限

```ruby
# Gemfile
gem 'rack-attack'

# config/initializers/rack_attack.rb
Rack::Attack.throttle('req/ip', limit: 300, period: 5.minutes) do |req|
  req.ip
end

Rack::Attack.throttle('logins/email', limit: 5, period: 20.seconds) do |req|
  req.params['email'] if req.path == '/login' && req.post?
end
```

---

## ベストプラクティス

### 1. パスワードを平文で保存しない

```ruby
# ○ has_secure_password または Devise を使用
```

### 2. セッションの有効期限を設定

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store, expire_after: 2.hours
```

### 3. 機密情報は環境変数で管理

```ruby
# config/credentials.yml.enc を使用
# または dotenv-rails gem
```

### 4. 適切な認可を実装

```ruby
# Pundit または CanCanCan を使用
```

### 5. API は適切な認証を実装

```ruby
# JWT または Token認証
```

---

## 参考リンク

- [Devise](https://github.com/heartcombo/devise)
- [Pundit](https://github.com/varvet/pundit)
- [CanCanCan](https://github.com/CanCanCommunity/cancancan)
- [JWT](https://jwt.io/)
- [Rack Attack](https://github.com/rack/rack-attack)
