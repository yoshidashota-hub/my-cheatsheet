# Ruby on Rails モデル（ActiveRecord基礎）

## 目次
- [モデルの基本](#モデルの基本)
- [CRUD操作](#crud操作)
- [スコープ](#スコープ)
- [コールバック](#コールバック)
- [バリデーション基礎](#バリデーション基礎)
- [属性操作](#属性操作)
- [データ型](#データ型)

---

## モデルの基本

ActiveRecordはRailsのORM（Object-Relational Mapping）。データベースのテーブルとRubyのクラスを対応付ける。

### モデル生成
```bash
# 基本
rails generate model Post title:string body:text

# 複数カラム
rails generate model User name:string email:string age:integer

# 参照
rails generate model Comment post:references user:references body:text
```

### モデルファイル
```ruby
# app/models/post.rb
class Post < ApplicationRecord
  # ApplicationRecordを継承
end
```

### 命名規則（CoC）

| Rubyクラス | テーブル名 |
|-----------|---------|
| User | users |
| Post | posts |
| BlogPost | blog_posts |
| Person | people (不規則変化) |
| Datum | data (不規則変化) |

---

## CRUD操作

### Create（作成）

#### new + save
```ruby
# インスタンス作成
user = User.new
user.name = 'John'
user.email = 'john@example.com'
user.save  # => true/false

# ハッシュで初期化
user = User.new(name: 'John', email: 'john@example.com')
user.save
```

#### create（newとsaveを同時実行）
```ruby
# 成功/失敗で true/false
user = User.create(name: 'John', email: 'john@example.com')

# 失敗時に例外
user = User.create!(name: 'John', email: 'john@example.com')

# 複数作成
User.create([
  { name: 'John', email: 'john@example.com' },
  { name: 'Jane', email: 'jane@example.com' }
])
```

#### find_or_create_by
```ruby
# 存在すれば取得、なければ作成
user = User.find_or_create_by(email: 'john@example.com') do |u|
  u.name = 'John'
end
```

#### find_or_initialize_by
```ruby
# 存在すれば取得、なければnewのみ（保存しない）
user = User.find_or_initialize_by(email: 'john@example.com')
user.new_record?  # => true（新規レコードの場合）
```

---

### Read（読み取り）

#### 単一レコード取得

```ruby
# IDで検索（見つからない場合は例外）
user = User.find(1)
user = User.find(params[:id])

# 複数ID
users = User.find([1, 2, 3])
users = User.find(1, 2, 3)

# 条件で最初の1件（見つからない場合は例外）
user = User.find_by!(email: 'john@example.com')

# 条件で最初の1件（見つからない場合はnil）
user = User.find_by(email: 'john@example.com')

# 最初/最後のレコード
user = User.first
user = User.last

# 並び順付き
user = User.order(:created_at).first
user = User.order(created_at: :desc).first

# 2番目、3番目...
user = User.second
user = User.third
user = User.fourth
user = User.fifth
```

#### 複数レコード取得

```ruby
# 全件取得
users = User.all

# 条件付き
users = User.where(active: true)
users = User.where('age > ?', 18)
users = User.where('name LIKE ?', '%John%')

# 複数条件（AND）
users = User.where(active: true, role: 'admin')
users = User.where(active: true).where(role: 'admin')

# OR条件
users = User.where(role: 'admin').or(User.where(role: 'moderator'))

# NOT条件
users = User.where.not(role: 'guest')

# IN条件
users = User.where(id: [1, 2, 3])
users = User.where(role: ['admin', 'moderator'])

# BETWEEN
users = User.where(age: 18..65)
users = User.where(created_at: 1.week.ago..Time.now)

# NULL判定
users = User.where(deleted_at: nil)
users = User.where.not(deleted_at: nil)
```

#### 並び替え

```ruby
# 昇順
users = User.order(:name)
users = User.order(name: :asc)

# 降順
users = User.order(name: :desc)

# 複数カラム
users = User.order(role: :asc, name: :asc)
users = User.order('role ASC, name ASC')

# ランダム
users = User.order('RANDOM()')  # PostgreSQL/SQLite
users = User.order('RAND()')    # MySQL
```

#### 件数制限

```ruby
# 最初のN件
users = User.limit(10)

# N件スキップしてM件取得（ページネーション）
users = User.limit(10).offset(20)

# 組み合わせ
users = User.where(active: true).order(:name).limit(10)
```

#### その他

```ruby
# 特定カラムのみ取得
users = User.select(:id, :name, :email)

# 重複を除外
emails = User.select(:email).distinct

# グループ化
User.group(:role).count
# => {"admin"=>5, "user"=>20}
```

---

### Update（更新）

#### インスタンスメソッド

```ruby
# 個別に代入して保存
user = User.find(1)
user.name = 'Jane'
user.email = 'jane@example.com'
user.save  # => true/false

# update（ハッシュで一括更新）
user.update(name: 'Jane', email: 'jane@example.com')
# => true/false

# update!（失敗時に例外）
user.update!(name: 'Jane')

# 属性のみ更新（バリデーション・コールバックスキップ）
user.update_attribute(:name, 'Jane')

# 複数属性更新（バリデーション・コールバックスキップ）
user.update_columns(name: 'Jane', updated_at: Time.current)
```

#### クラスメソッド（一括更新）

```ruby
# 条件に合う全てのレコードを更新
User.where(active: false).update_all(deleted: true)

# 全レコード更新（危険）
User.update_all(active: true)

# SQL式も使用可能
Post.update_all('views = views + 1')
```

#### increment / decrement

```ruby
# カウントアップ
user = User.find(1)
user.increment(:login_count)     # メモリ上のみ
user.increment!(:login_count)    # DB保存

# カウントダウン
user.decrement(:points)
user.decrement!(:points)

# 任意の値
user.increment!(:points, 10)
```

#### toggle

```ruby
# 真偽値を反転
user.toggle(:active)     # メモリ上のみ
user.toggle!(:active)    # DB保存
```

---

### Delete（削除）

```ruby
# destroy: コールバック実行、関連レコードも削除
user = User.find(1)
user.destroy  # => frozen object（削除済み）

# delete: コールバックなし、高速
user.delete

# 複数削除
User.where(active: false).destroy_all  # コールバック実行
User.where(active: false).delete_all   # コールバックなし

# 全削除
User.destroy_all  # コールバック実行（遅い）
User.delete_all   # コールバックなし（速い）
```

---

## スコープ

再利用可能なクエリを定義。

### 基本
```ruby
class Post < ApplicationRecord
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { where('views > ?', 100) }
end

# 使用例
Post.published
Post.published.recent
Post.published.recent.limit(10)
```

### パラメータ付きスコープ
```ruby
class Post < ApplicationRecord
  scope :created_after, ->(date) { where('created_at > ?', date) }
  scope :by_author, ->(author_id) { where(author_id: author_id) }
  scope :search, ->(keyword) { where('title LIKE ?', "%#{keyword}%") }
end

# 使用例
Post.created_after(1.week.ago)
Post.by_author(current_user.id)
Post.search('rails')
```

### デフォルトスコープ
```ruby
class Post < ApplicationRecord
  default_scope { where(deleted: false) }
end

# 全クエリに自動適用
Post.all  # => WHERE deleted = false

# デフォルトスコープを解除
Post.unscoped.all
```

### クラスメソッドでの実装
スコープの代わりにクラスメソッドでも可（柔軟性が高い）。

```ruby
class Post < ApplicationRecord
  def self.published
    where(published: true)
  end

  def self.by_author(author_id)
    where(author_id: author_id) if author_id.present?
  end
end
```

---

## コールバック

レコードのライフサイクルで自動実行されるメソッド。

### コールバックの種類

```ruby
class User < ApplicationRecord
  # 作成前
  before_validation :normalize_email
  after_validation :log_validation

  # 保存前後
  before_save :encrypt_password
  around_save :log_save
  after_save :send_welcome_email

  # 作成時のみ
  before_create :set_default_role
  after_create :notify_admin

  # 更新時のみ
  before_update :check_changes
  after_update :log_changes

  # 削除前後
  before_destroy :check_dependencies
  after_destroy :cleanup_files

  # コミット後（トランザクション完了後）
  after_commit :update_search_index
  after_rollback :notify_error

  private

  def normalize_email
    self.email = email.downcase.strip
  end

  def set_default_role
    self.role ||= 'user'
  end

  def send_welcome_email
    UserMailer.welcome(self).deliver_later
  end
end
```

### コールバックの実行順序

**作成時**:
1. before_validation
2. after_validation
3. before_save
4. before_create
5. (データベースINSERT)
6. after_create
7. after_save
8. after_commit

**更新時**:
1. before_validation
2. after_validation
3. before_save
4. before_update
5. (データベースUPDATE)
6. after_update
7. after_save
8. after_commit

### コールバックのスキップ

```ruby
# これらのメソッドはコールバックをスキップ
user.update_attribute(:name, 'Jane')
user.update_columns(name: 'Jane')
user.delete
User.update_all(active: true)
User.delete_all
```

### 条件付きコールバック

```ruby
class User < ApplicationRecord
  before_save :encrypt_password, if: :password_changed?
  after_create :send_welcome_email, unless: :guest?

  # メソッド名（シンボル）
  before_save :log_changes, if: :admin?

  # Proc
  before_save :log_changes, if: -> { self.role == 'admin' }

  # 文字列（eval）
  before_save :log_changes, if: 'role == "admin"'

  private

  def admin?
    role == 'admin'
  end

  def guest?
    role == 'guest'
  end
end
```

---

## バリデーション基礎

詳細は `rails_validation.md` を参照。

### よく使うバリデーション

```ruby
class User < ApplicationRecord
  # 必須
  validates :name, presence: true
  validates :email, presence: true

  # 一意性
  validates :email, uniqueness: true
  validates :username, uniqueness: { case_sensitive: false }

  # 長さ
  validates :name, length: { minimum: 2, maximum: 50 }
  validates :password, length: { in: 6..20 }

  # フォーマット（正規表現）
  validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }

  # 数値
  validates :age, numericality: { only_integer: true, greater_than: 0 }

  # 含まれるか
  validates :role, inclusion: { in: %w[admin user guest] }

  # 確認
  validates :email, confirmation: true
  validates :password, confirmation: true
end
```

### カスタムバリデーション

```ruby
class User < ApplicationRecord
  validate :email_must_be_company_domain

  private

  def email_must_be_company_domain
    unless email.ends_with?('@company.com')
      errors.add(:email, 'must be a company email')
    end
  end
end
```

---

## 属性操作

### 属性の読み書き

```ruby
user = User.new

# 読み取り
user.name
user[:name]
user.read_attribute(:name)

# 書き込み
user.name = 'John'
user[:name] = 'John'
user.write_attribute(:name, 'John')

# 全属性を取得
user.attributes
# => {"id"=>1, "name"=>"John", "email"=>"john@example.com", ...}
```

### 属性の検証

```ruby
user = User.new(name: 'John')

user.new_record?      # => true（新規レコード）
user.persisted?       # => false（保存済みか）

user.save

user.new_record?      # => false
user.persisted?       # => true

# 変更検知
user.name = 'Jane'
user.name_changed?    # => true
user.name_was         # => "John"（変更前の値）
user.name_change      # => ["John", "Jane"]

user.changed?         # => true（何か変更があるか）
user.changes          # => {"name"=>["John", "Jane"]}

# 変更をリセット
user.restore_attributes
user.name             # => "John"
```

### 仮想属性

データベースに存在しないカラムを定義。

```ruby
class User < ApplicationRecord
  # getter
  def full_name
    "#{first_name} #{last_name}"
  end

  # setter
  def full_name=(name)
    parts = name.split(' ', 2)
    self.first_name = parts.first
    self.last_name = parts.last
  end
end

user = User.new
user.full_name = 'John Doe'
user.first_name  # => "John"
user.last_name   # => "Doe"
user.full_name   # => "John Doe"
```

---

## データ型

### マイグレーションでの型

| Rails型 | PostgreSQL | MySQL | SQLite |
|---------|-----------|-------|--------|
| :string | varchar(255) | varchar(255) | varchar(255) |
| :text | text | text | text |
| :integer | integer | int | integer |
| :bigint | bigint | bigint | bigint |
| :float | double precision | double | float |
| :decimal | decimal | decimal | decimal |
| :boolean | boolean | tinyint(1) | boolean |
| :date | date | date | date |
| :time | time | time | time |
| :datetime | timestamp | datetime | datetime |
| :timestamp | timestamp | timestamp | timestamp |
| :binary | bytea | blob | blob |
| :json | json | json | text |
| :jsonb | jsonb | - | - |

### 使用例

```ruby
# マイグレーション
class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.integer :quantity, default: 0
      t.decimal :price, precision: 10, scale: 2
      t.boolean :available, default: true
      t.date :release_date
      t.datetime :published_at
      t.json :metadata

      t.timestamps
    end
  end
end
```

### 属性の自動変換

```ruby
# boolean
user.active = '1'
user.active  # => true

user.active = '0'
user.active  # => false

# date/datetime
post.published_at = '2023-12-01'
post.published_at  # => Fri, 01 Dec 2023 00:00:00 UTC +00:00

# json/jsonb
product.metadata = { color: 'red', size: 'L' }
product.metadata  # => {"color"=>"red", "size"=>"L"}
```

---

## enum

列挙型の定義。

```ruby
class User < ApplicationRecord
  enum role: { guest: 0, user: 1, admin: 2 }
  enum status: { inactive: 0, active: 1, suspended: 2 }
end

# 使用例
user = User.new
user.guest!        # role = 0
user.guest?        # => true
user.admin?        # => false

user.role = :admin
user.admin?        # => true

# スコープ自動生成
User.admin         # WHERE role = 2
User.guest         # WHERE role = 0

# 全値を取得
User.roles         # => {"guest"=>0, "user"=>1, "admin"=>2}
```

---

## ベストプラクティス

### 1. Fat Model, Skinny Controller
```ruby
# ✗ コントローラーにロジック
class PostsController < ApplicationController
  def publish
    @post.published = true
    @post.published_at = Time.current
    @post.save
  end
end

# ○ モデルにロジック
class Post < ApplicationRecord
  def publish!
    update(published: true, published_at: Time.current)
  end
end
```

### 2. スコープで可読性向上
```ruby
# ✗ 直接whereを書く
Post.where(published: true).where('views > ?', 100).order(created_at: :desc)

# ○ スコープで名前を付ける
class Post < ApplicationRecord
  scope :published, -> { where(published: true) }
  scope :popular, -> { where('views > ?', 100) }
  scope :recent, -> { order(created_at: :desc) }
end

Post.published.popular.recent
```

### 3. コールバックは最小限に
- 副作用の多いコールバックは避ける
- 複雑な処理はサービスオブジェクトへ

---

## 参考リンク

- [Active Record Basics](https://guides.rubyonrails.org/active_record_basics.html)
- [Railsガイド：Active Record の基礎](https://railsguides.jp/active_record_basics.html)
