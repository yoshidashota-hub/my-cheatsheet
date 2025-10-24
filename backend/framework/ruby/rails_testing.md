# Ruby on Rails テスト

## 目次
- [テストの種類](#テストの種類)
- [Minitest](#minitest)
- [RSpec](#rspec)
- [FactoryBot](#factorybot)
- [Fixtures](#fixtures)
- [統合テスト](#統合テスト)
- [テストカバレッジ](#テストカバレッジ)
- [モックとスタブ](#モックとスタブ)

---

## テストの種類

### Railsのテスト分類

| テスト種類 | 対象 | 説明 |
|----------|------|------|
| Unit Test | モデル | モデルのロジック、バリデーション |
| Controller Test | コントローラー | リクエスト処理、レスポンス |
| Integration Test | 複数コントローラー | ユーザーフロー全体 |
| System Test | ブラウザ操作 | E2E（End-to-End）テスト |
| Mailer Test | メーラー | メール送信 |
| Job Test | バックグラウンドジョブ | 非同期処理 |

---

## Minitest

Railsのデフォルトテストフレームワーク。

### セットアップ

```ruby
# test/test_helper.rb（自動生成）
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  fixtures :all
end
```

### モデルテスト

```ruby
# test/models/user_test.rb
require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'should be valid' do
    user = User.new(name: 'John', email: 'john@example.com', password: 'password')
    assert user.valid?
  end

  test 'should require name' do
    user = User.new(email: 'john@example.com', password: 'password')
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test 'should require unique email' do
    user1 = User.create(name: 'John', email: 'test@example.com', password: 'password')
    user2 = User.new(name: 'Jane', email: 'test@example.com', password: 'password')
    assert_not user2.valid?
    assert_includes user2.errors[:email], 'has already been taken'
  end

  test 'should authenticate with correct password' do
    user = User.create(name: 'John', email: 'john@example.com', password: 'password')
    assert user.authenticate('password')
    assert_not user.authenticate('wrong')
  end
end
```

### コントローラーテスト

```ruby
# test/controllers/posts_controller_test.rb
require 'test_helper'

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @post = posts(:one)  # fixture
    @user = users(:one)
  end

  test 'should get index' do
    get posts_url
    assert_response :success
    assert_not_nil assigns(:posts)
  end

  test 'should show post' do
    get post_url(@post)
    assert_response :success
  end

  test 'should create post' do
    assert_difference('Post.count') do
      post posts_url, params: {
        post: {
          title: 'New Post',
          body: 'Body',
          user_id: @user.id
        }
      }
    end
    assert_redirected_to post_url(Post.last)
  end

  test 'should update post' do
    patch post_url(@post), params: {
      post: { title: 'Updated Title' }
    }
    assert_redirected_to post_url(@post)
    @post.reload
    assert_equal 'Updated Title', @post.title
  end

  test 'should destroy post' do
    assert_difference('Post.count', -1) do
      delete post_url(@post)
    end
    assert_redirected_to posts_url
  end
end
```

### アサーション

```ruby
# 等価性
assert_equal expected, actual
assert_not_equal expected, actual

# 真偽
assert condition
assert_not condition
refute condition

# nil チェック
assert_nil object
assert_not_nil object

# 含まれるか
assert_includes collection, object

# マッチ
assert_match /pattern/, string

# 空
assert_empty collection

# レスポンス
assert_response :success        # 200
assert_response :redirect       # 30x
assert_response :not_found      # 404
assert_response :error          # 500

# リダイレクト
assert_redirected_to posts_path

# 差分
assert_difference 'Post.count', 1 do
  Post.create(title: 'Test')
end

assert_no_difference 'Post.count' do
  Post.create(title: '')  # バリデーションエラー
end

# 例外
assert_raises ActiveRecord::RecordNotFound do
  Post.find(9999)
end
```

### テスト実行

```bash
# 全テスト実行
rails test

# 特定のファイル
rails test test/models/user_test.rb

# 特定のテスト
rails test test/models/user_test.rb:10

# モデルテストのみ
rails test test/models

# コントローラーテストのみ
rails test test/controllers

# 失敗したテストのみ再実行
rails test --fail-fast
```

---

## RSpec

BDD（振る舞い駆動開発）スタイルのテストフレームワーク。

### セットアップ

```ruby
# Gemfile
group :development, :test do
  gem 'rspec-rails'
end

# インストール
bundle install
rails generate rspec:install
```

```ruby
# spec/rails_helper.rb（自動生成）
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rspec/rails'

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
end
```

### モデルテスト

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = User.new(name: 'John', email: 'john@example.com', password: 'password')
      expect(user).to be_valid
    end

    it 'is not valid without a name' do
      user = User.new(email: 'john@example.com', password: 'password')
      expect(user).to_not be_valid
    end

    it 'is not valid with a duplicate email' do
      User.create(name: 'John', email: 'test@example.com', password: 'password')
      user = User.new(name: 'Jane', email: 'test@example.com', password: 'password')
      expect(user).to_not be_valid
    end
  end

  describe '#full_name' do
    it 'returns the full name' do
      user = User.new(first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe 'associations' do
    it { should have_many(:posts) }
    it { should have_one(:profile) }
  end
end
```

### コントローラーテスト

```ruby
# spec/controllers/posts_controller_spec.rb
require 'rails_helper'

RSpec.describe PostsController, type: :controller do
  let(:user) { create(:user) }
  let(:post_params) { { title: 'Test', body: 'Body', user_id: user.id } }

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @posts' do
      post = create(:post)
      get :index
      expect(assigns(:posts)).to include(post)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new Post' do
        expect {
          post :create, params: { post: post_params }
        }.to change(Post, :count).by(1)
      end

      it 'redirects to the created post' do
        post :create, params: { post: post_params }
        expect(response).to redirect_to(Post.last)
      end
    end

    context 'with invalid params' do
      it 'does not create a new Post' do
        expect {
          post :create, params: { post: { title: '' } }
        }.to_not change(Post, :count)
      end
    end
  end
end
```

### リクエストテスト（推奨）

```ruby
# spec/requests/posts_spec.rb
require 'rails_helper'

RSpec.describe 'Posts', type: :request do
  describe 'GET /posts' do
    it 'returns http success' do
      get '/posts'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /posts' do
    let(:valid_params) do
      { post: { title: 'Test', body: 'Body' } }
    end

    it 'creates a new post' do
      expect {
        post '/posts', params: valid_params
      }.to change(Post, :count).by(1)
    end

    it 'returns created status' do
      post '/posts', params: valid_params
      expect(response).to have_http_status(:created)
    end
  end
end
```

### マッチャー

```ruby
# 等価性
expect(actual).to eq(expected)
expect(actual).to_not eq(expected)

# 真偽
expect(condition).to be true
expect(condition).to be false
expect(condition).to be_truthy
expect(condition).to be_falsy

# nil
expect(object).to be_nil
expect(object).to_not be_nil

# 含まれるか
expect(array).to include(item)
expect(string).to include('substring')

# マッチ
expect(string).to match(/pattern/)

# 型
expect(object).to be_a(Class)
expect(object).to be_kind_of(Class)

# 変更
expect { action }.to change(Post, :count).by(1)
expect { action }.to change { object.attribute }.from(old).to(new)

# 例外
expect { action }.to raise_error(StandardError)
expect { action }.to raise_error(ActiveRecord::RecordNotFound)

# レスポンス
expect(response).to have_http_status(:success)
expect(response).to have_http_status(200)
expect(response).to redirect_to(posts_path)

# shoulda-matchers（追加gem）
it { should validate_presence_of(:name) }
it { should validate_uniqueness_of(:email) }
it { should have_many(:posts) }
```

### テスト実行

```bash
# 全テスト実行
rspec

# 特定のファイル
rspec spec/models/user_spec.rb

# 特定のテスト
rspec spec/models/user_spec.rb:10

# フォーマット指定
rspec --format documentation

# 失敗したテストのみ
rspec --only-failures
```

---

## FactoryBot

テストデータを簡単に作成。

### セットアップ

```ruby
# Gemfile
group :development, :test do
  gem 'factory_bot_rails'
end

# spec/rails_helper.rb または test/test_helper.rb
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

### ファクトリー定義

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    name { 'John Doe' }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password' }

    trait :admin do
      role { 'admin' }
    end

    trait :with_posts do
      after(:create) do |user|
        create_list(:post, 3, user: user)
      end
    end
  end
end

# spec/factories/posts.rb
FactoryBot.define do
  factory :post do
    title { 'Sample Post' }
    body { 'This is a sample post body' }
    association :user

    trait :published do
      published { true }
      published_at { Time.current }
    end
  end
end
```

### 使用方法

```ruby
# 作成（保存しない）
user = build(:user)

# 作成（保存する）
user = create(:user)

# 属性のみ取得
attributes = attributes_for(:user)

# 上書き
user = create(:user, name: 'Jane', email: 'jane@example.com')

# Trait使用
admin = create(:user, :admin)
user_with_posts = create(:user, :with_posts)

# 複数作成
users = create_list(:user, 5)
users = create_list(:user, 3, :admin)

# スタブ
user = build_stubbed(:user)  # DBに保存せず、idを持つ
```

---

## Fixtures

静的なテストデータ。

### Fixture定義

```yaml
# test/fixtures/users.yml
one:
  name: John Doe
  email: john@example.com
  password_digest: <%= BCrypt::Password.create('password') %>

two:
  name: Jane Doe
  email: jane@example.com
  password_digest: <%= BCrypt::Password.create('password') %>
```

```yaml
# test/fixtures/posts.yml
first_post:
  title: First Post
  body: This is the first post
  user: one

second_post:
  title: Second Post
  body: This is the second post
  user: two
```

### 使用方法

```ruby
# test/models/user_test.rb
class UserTest < ActiveSupport::TestCase
  test 'should have posts' do
    user = users(:one)
    assert user.posts.any?
  end
end
```

---

## 統合テスト

複数のコントローラーにまたがるフロー。

### システムテスト（Capybara）

```ruby
# Gemfile
group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
end
```

```ruby
# spec/system/posts_spec.rb
require 'rails_helper'

RSpec.describe 'Posts', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'creates a new post' do
    visit new_post_path

    fill_in 'Title', with: 'New Post'
    fill_in 'Body', with: 'This is a new post'
    click_button 'Create Post'

    expect(page).to have_content('Post was successfully created')
    expect(page).to have_content('New Post')
  end

  it 'shows all posts' do
    create(:post, title: 'First Post')
    create(:post, title: 'Second Post')

    visit posts_path

    expect(page).to have_content('First Post')
    expect(page).to have_content('Second Post')
  end
end
```

### Capybara メソッド

```ruby
# ページ訪問
visit posts_path

# リンククリック
click_link 'Show'
click_link 'Edit'

# ボタンクリック
click_button 'Submit'

# フォーム入力
fill_in 'Email', with: 'test@example.com'
fill_in 'user_email', with: 'test@example.com'  # id指定

# チェックボックス
check 'Accept terms'
uncheck 'Subscribe'

# ラジオボタン
choose 'Male'

# セレクトボックス
select 'Admin', from: 'Role'

# アサーション
expect(page).to have_content('Success')
expect(page).to have_selector('h1', text: 'Title')
expect(page).to have_link('Show')
expect(page).to have_button('Submit')
expect(page).to have_field('Email')
expect(page).to have_checked_field('Accept terms')
expect(page).to have_current_path(posts_path)
```

---

## テストカバレッジ

### SimpleCov

```ruby
# Gemfile
group :test do
  gem 'simplecov', require: false
end
```

```ruby
# spec/spec_helper.rb または test/test_helper.rb（最上部）
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/spec/'
  add_filter '/test/'
end
```

```bash
# テスト実行後、coverage/index.html を確認
open coverage/index.html
```

---

## モックとスタブ

### RSpec モック

```ruby
# スタブ
allow(user).to receive(:admin?).and_return(true)

# スタブ（引数指定）
allow(Post).to receive(:find).with(1).and_return(post)

# モック（呼び出し確認）
expect(user).to receive(:save).and_return(true)

# 呼び出し回数
expect(mailer).to receive(:deliver).once
expect(mailer).to receive(:deliver).exactly(3).times

# チェーン
allow(Post).to receive_message_chain(:where, :order).and_return([post])

# 部分的なスタブ
user = User.new
allow(user).to receive(:full_name).and_return('John Doe')

# インスタンスダブル
user = instance_double(User, name: 'John', email: 'john@example.com')
```

---

## ベストプラクティス

### 1. テストは読みやすく

```ruby
# ○ わかりやすい説明
it 'returns posts in descending order by creation date' do
  # ...
end

# ✗ 曖昧な説明
it 'works' do
  # ...
end
```

### 2. 1つのテストで1つの事を検証

```ruby
# ○ 単一の検証
it 'validates presence of name' do
  user = User.new(email: 'test@example.com')
  expect(user).to_not be_valid
end

# ✗ 複数の検証
it 'validates user' do
  user = User.new
  expect(user).to_not be_valid
  expect(user.errors[:name]).to be_present
  expect(user.errors[:email]).to be_present
end
```

### 3. FactoryBotを活用

```ruby
# ○ FactoryBotで簡潔に
user = create(:user, :admin)

# ✗ 冗長
user = User.create(
  name: 'Admin',
  email: 'admin@example.com',
  password: 'password',
  role: 'admin'
)
```

---

## 参考リンク

- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- [RSpec](https://rspec.info/)
- [FactoryBot](https://github.com/thoughtbot/factory_bot)
- [Capybara](https://github.com/teamcapybara/capybara)
- [SimpleCov](https://github.com/simplecov-ruby/simplecov)
- [shoulda-matchers](https://github.com/thoughtbot/shoulda-matchers)
