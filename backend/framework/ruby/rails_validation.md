# Ruby on Rails バリデーション

## 目次
- [バリデーションの基本](#バリデーションの基本)
- [標準バリデーション](#標準バリデーション)
- [カスタムバリデーション](#カスタムバリデーション)
- [条件付きバリデーション](#条件付きバリデーション)
- [エラーメッセージ](#エラーメッセージ)
- [バリデーションのスキップ](#バリデーションのスキップ)
- [バリデーションヘルパー](#バリデーションヘルパー)

---

## バリデーションの基本

モデルに保存する前にデータの妥当性を検証する仕組み。

### バリデーションが実行されるタイミング

```ruby
user = User.new(name: '', email: 'test@example.com')
user.valid?  # => false（バリデーション実行）
user.invalid?  # => true

user.save   # => false（バリデーション失敗）
user.save!  # => ActiveRecord::RecordInvalid例外

user.create   # => バリデーション実行
user.update   # => バリデーション実行
```

### バリデーションをスキップするメソッド

```ruby
# これらのメソッドはバリデーションをスキップ（注意）
user.update_attribute(:name, 'John')
user.update_columns(name: 'John', email: 'john@example.com')
user.delete
User.update_all(active: true)
User.delete_all
```

---

## 標準バリデーション

### presence（存在確認）

```ruby
class User < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true
end

user = User.new
user.valid?  # => false
user.errors[:name]  # => ["can't be blank"]
```

### absence（空白確認）

```ruby
class User < ApplicationRecord
  validates :deleted_at, absence: true
end
```

### length（長さ）

```ruby
class User < ApplicationRecord
  # 最小値
  validates :name, length: { minimum: 2 }

  # 最大値
  validates :name, length: { maximum: 50 }

  # 範囲
  validates :password, length: { in: 6..20 }
  validates :password, length: { within: 6..20 }  # エイリアス

  # 完全一致
  validates :phone, length: { is: 10 }

  # カスタムメッセージ
  validates :name, length: {
    minimum: 2,
    maximum: 50,
    too_short: 'は%{count}文字以上で入力してください',
    too_long: 'は%{count}文字以内で入力してください'
  }
end
```

### format（フォーマット）

```ruby
class User < ApplicationRecord
  # 正規表現でチェック
  validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }

  # マッチしない場合のチェック
  validates :subdomain, format: { without: /www|admin|root/ }

  # メッセージ
  validates :email, format: {
    with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i,
    message: 'は有効なメールアドレスではありません'
  }
end

# よく使う正規表現
# メール: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
# URL: /\Ahttps?:\/\/[\S]+\z/
# 電話番号（日本）: /\A0\d{9,10}\z/
# 郵便番号（日本）: /\A\d{3}-?\d{4}\z/
```

### uniqueness（一意性）

```ruby
class User < ApplicationRecord
  # 一意性チェック
  validates :email, uniqueness: true

  # 大文字小文字を区別しない
  validates :email, uniqueness: { case_sensitive: false }

  # スコープ付き（特定のカラムの組み合わせで一意）
  validates :name, uniqueness: { scope: :year }
  validates :email, uniqueness: { scope: [:organization_id, :department_id] }

  # メッセージ
  validates :email, uniqueness: {
    message: 'はすでに使用されています'
  }
end

# 注意: データベースレベルでもユニークインデックスを追加推奨
# add_index :users, :email, unique: true
```

### numericality（数値）

```ruby
class Product < ApplicationRecord
  # 数値であることを確認
  validates :price, numericality: true

  # 整数のみ
  validates :quantity, numericality: { only_integer: true }

  # 大小比較
  validates :price, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :discount, numericality: { less_than: 100 }
  validates :discount, numericality: { less_than_or_equal_to: 100 }
  validates :rating, numericality: { equal_to: 5 }

  # 偶数・奇数
  validates :quantity, numericality: { even: true }
  validates :quantity, numericality: { odd: true }

  # 範囲
  validates :age, numericality: { in: 18..100 }

  # 組み合わせ
  validates :price, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 1_000_000
  }
end
```

### inclusion（含まれるか）

```ruby
class User < ApplicationRecord
  # 配列に含まれるか
  validates :role, inclusion: { in: %w[admin user guest] }

  # 範囲
  validates :age, inclusion: { in: 18..100 }

  # メッセージ
  validates :role, inclusion: {
    in: %w[admin user guest],
    message: '%{value} は有効な役割ではありません'
  }
end
```

### exclusion（含まれないか）

```ruby
class User < ApplicationRecord
  # 配列に含まれない
  validates :subdomain, exclusion: { in: %w[www admin root] }
end
```

### confirmation（確認）

```ruby
class User < ApplicationRecord
  # password_confirmation 属性が必要
  validates :password, confirmation: true
  validates :password_confirmation, presence: true

  # email_confirmation も同様
  validates :email, confirmation: true
end

# ビューで使用
# <%= f.password_field :password %>
# <%= f.password_field :password_confirmation %>
```

### acceptance（同意）

```ruby
class User < ApplicationRecord
  # チェックボックスで同意を確認
  validates :terms_of_service, acceptance: true

  # 特定の値を要求
  validates :privacy_policy, acceptance: { accept: 'yes' }
end

# ビューで使用
# <%= f.check_box :terms_of_service %>
```

### validates_associated（関連の検証）

```ruby
class Post < ApplicationRecord
  has_many :comments
  validates_associated :comments
end

# 注意: 両方のモデルで validates_associated を使うと無限ループ
```

### comparison（比較） - Rails 7.0+

```ruby
class Event < ApplicationRecord
  validates :end_date, comparison: { greater_than: :start_date }
  validates :discount, comparison: { less_than: :price }
  validates :quantity, comparison: { greater_than_or_equal_to: 0 }
end
```

---

## カスタムバリデーション

### カスタムメソッド

```ruby
class User < ApplicationRecord
  validate :email_must_be_company_domain
  validate :birth_date_cannot_be_future

  private

  def email_must_be_company_domain
    unless email.ends_with?('@company.com')
      errors.add(:email, 'は会社のメールアドレスである必要があります')
    end
  end

  def birth_date_cannot_be_future
    if birth_date.present? && birth_date > Date.today
      errors.add(:birth_date, 'は未来の日付にできません')
    end
  end
end
```

### カスタムバリデータークラス

```ruby
# app/validators/email_validator.rb
class EmailValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value =~ /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
      record.errors.add(attribute, options[:message] || 'は有効なメールアドレスではありません')
    end
  end
end

class User < ApplicationRecord
  validates :email, email: true
end
```

### カスタムバリデータークラス（複数属性）

```ruby
# app/validators/date_range_validator.rb
class DateRangeValidator < ActiveModel::Validator
  def validate(record)
    if record.start_date && record.end_date
      if record.end_date < record.start_date
        record.errors.add(:end_date, '開始日より後である必要があります')
      end
    end
  end
end

class Event < ApplicationRecord
  validates_with DateRangeValidator
end
```

---

## 条件付きバリデーション

### if / unless

```ruby
class User < ApplicationRecord
  # シンボル（メソッド名）
  validates :password, presence: true, if: :password_required?

  # Proc
  validates :email, presence: true, if: -> { self.role == 'admin' }

  # 文字列（eval）
  validates :age, numericality: true, if: 'birth_date.present?'

  # unless
  validates :bio, presence: true, unless: :guest?

  # 複数条件
  validates :name, presence: true, if: [:admin?, :active?]

  private

  def password_required?
    new_record? || password.present?
  end

  def guest?
    role == 'guest'
  end

  def admin?
    role == 'admin'
  end

  def active?
    active == true
  end
end
```

### on（作成・更新時のみ）

```ruby
class User < ApplicationRecord
  # 作成時のみ
  validates :password, presence: true, on: :create

  # 更新時のみ
  validates :email, presence: true, on: :update

  # カスタムコンテキスト
  validates :admin_notes, presence: true, on: :admin_update
end

# 使用例
user.save(context: :admin_update)
```

---

## エラーメッセージ

### エラー情報の取得

```ruby
user = User.new
user.valid?

# 全エラー
user.errors.full_messages
# => ["Name can't be blank", "Email can't be blank"]

# 特定の属性
user.errors[:name]
# => ["can't be blank"]

# エラーの有無
user.errors.any?  # => true
user.errors.empty?  # => false

# 特定の属性にエラーがあるか
user.errors[:name].any?  # => true

# エラー件数
user.errors.count  # => 2
```

### カスタムエラーメッセージ

```ruby
class User < ApplicationRecord
  validates :name, presence: { message: 'を入力してください' }
  validates :age, numericality: { message: 'は数値で入力してください' }

  # 動的メッセージ
  validates :age, numericality: {
    greater_than: 18,
    message: 'は%{count}歳より大きい必要があります'
  }
end
```

### 国際化（i18n）

```yaml
# config/locales/ja.yml
ja:
  activerecord:
    models:
      user: ユーザー
    attributes:
      user:
        name: 名前
        email: メールアドレス
        age: 年齢
    errors:
      models:
        user:
          attributes:
            email:
              blank: を入力してください
              invalid: は有効なメールアドレスではありません
```

```ruby
# config/application.rb
config.i18n.default_locale = :ja
```

### 手動でエラー追加

```ruby
user = User.new
user.errors.add(:name, 'は予約語です')
user.errors.add(:base, 'このユーザーは無効です')

# エラーをクリア
user.errors.clear
```

---

## バリデーションのスキップ

### save(validate: false)

```ruby
user = User.new
user.save(validate: false)  # バリデーションをスキップ
```

### update_attribute

```ruby
user.update_attribute(:name, '')  # バリデーションスキップ
```

---

## バリデーションヘルパー

### 複数属性に同じバリデーション

```ruby
class User < ApplicationRecord
  validates :name, :email, :phone, presence: true
  validates :password, :password_confirmation, length: { minimum: 6 }
end
```

### with_options

```ruby
class User < ApplicationRecord
  with_options presence: true do
    validates :name
    validates :email
    validates :phone
  end

  with_options if: :admin? do
    validates :admin_code, presence: true
    validates :admin_level, numericality: { only_integer: true }
  end
end
```

---

## ベストプラクティス

### 1. データベース制約と併用

```ruby
# モデル
class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
end

# マイグレーション
class AddIndexToUsersEmail < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :email, unique: true
    change_column_null :users, :email, false
  end
end
```

### 2. バリデーションはモデルに集約

```ruby
# ✗ コントローラーでバリデーション
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    if @user.email.blank?
      flash[:error] = 'メールを入力してください'
      render :new
      return
    end
    @user.save
  end
end

# ○ モデルでバリデーション
class User < ApplicationRecord
  validates :email, presence: true
end
```

### 3. カスタムバリデーションは再利用可能に

```ruby
# ✗ 各モデルに同じコード
class User < ApplicationRecord
  validate :email_format

  def email_format
    unless email =~ /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
      errors.add(:email, 'は無効です')
    end
  end
end

# ○ カスタムバリデータークラス
class EmailValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value =~ /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
      record.errors.add(attribute, 'は無効です')
    end
  end
end

class User < ApplicationRecord
  validates :email, email: true
end
```

---

## 参考リンク

- [Active Record Validations](https://guides.rubyonrails.org/active_record_validations.html)
- [Railsガイド：バリデーション](https://railsguides.jp/active_record_validations.html)
