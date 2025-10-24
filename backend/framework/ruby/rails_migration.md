# Ruby on Rails マイグレーション

## 目次
- [マイグレーションとは](#マイグレーションとは)
- [マイグレーション生成](#マイグレーション生成)
- [マイグレーション実行](#マイグレーション実行)
- [テーブル操作](#テーブル操作)
- [カラム操作](#カラム操作)
- [インデックス](#インデックス)
- [外部キー](#外部キー)
- [ロールバック](#ロールバック)

---

## マイグレーションとは

データベーススキーマの変更を管理する仕組み。バージョン管理可能で、チーム開発に適している。

### 特徴
- SQL を直接書かずにRubyでスキーマ変更
- 変更履歴を管理
- up/down (または change) で変更と取り消しを定義
- データベース非依存（PostgreSQL、MySQL、SQLiteなど）

### マイグレーションファイル
```ruby
# db/migrate/20231201120000_create_posts.rb
class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :body

      t.timestamps
    end
  end
end
```

---

## マイグレーション生成

### generate コマンド

```bash
# テーブル作成
rails generate migration CreatePosts title:string body:text
rails g migration CreatePosts title:string body:text  # 短縮形

# カラム追加
rails g migration AddEmailToUsers email:string

# カラム削除
rails g migration RemoveEmailFromUsers email:string

# 参照追加
rails g migration AddUserToPosts user:references

# 複数カラム
rails g migration AddDetailsToUsers age:integer city:string

# インデックス付き
rails g migration AddEmailToUsers email:string:index
rails g migration AddEmailToUsers email:string:uniq  # ユニークインデックス
```

### モデル生成時の自動作成
```bash
rails g model Post title:string body:text published:boolean

# 以下のマイグレーションが自動生成される
# db/migrate/YYYYMMDDHHMMSS_create_posts.rb
```

---

## マイグレーション実行

### 基本コマンド

```bash
# マイグレーション実行（未実行のものをすべて実行）
rails db:migrate

# 特定のバージョンまで実行
rails db:migrate VERSION=20231201120000

# 環境指定
rails db:migrate RAILS_ENV=production

# マイグレーション状態確認
rails db:migrate:status
```

### ロールバック

```bash
# 直前のマイグレーションを取り消し
rails db:rollback

# 3つ前まで取り消し
rails db:rollback STEP=3

# 特定バージョンまで戻す
rails db:migrate VERSION=20231201120000

# 全てリセット
rails db:migrate:reset  # drop → create → migrate
rails db:reset          # drop → create → migrate → seed
```

### やり直し

```bash
# 直前のマイグレーションをrollback→migrateで再実行
rails db:migrate:redo

# 3つ分やり直し
rails db:migrate:redo STEP=3
```

---

## テーブル操作

### テーブル作成

```ruby
class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      # カラム定義
      t.string :title
      t.text :body
      t.boolean :published, default: false, null: false
      t.integer :view_count, default: 0

      # created_at, updated_at を自動追加
      t.timestamps
    end
  end
end
```

### オプション

```ruby
create_table :posts do |t|
  # null制約
  t.string :title, null: false

  # デフォルト値
  t.boolean :published, default: false
  t.integer :view_count, default: 0

  # 文字数制限
  t.string :name, limit: 100

  # 精度指定（decimal）
  t.decimal :price, precision: 10, scale: 2

  # コメント（PostgreSQLなど）
  t.string :status, comment: 'Publication status'

  t.timestamps
end
```

### カスタムID

```ruby
# UUID を主キーに
create_table :posts, id: :uuid do |t|
  t.string :title
  t.timestamps
end

# 主キーなし
create_table :posts_categories, id: false do |t|
  t.references :post, foreign_key: true
  t.references :category, foreign_key: true
end

# 複合主キー（カスタム実装）
create_table :posts, primary_key: [:user_id, :post_id] do |t|
  t.integer :user_id
  t.integer :post_id
  t.string :title
end
```

### テーブル削除

```ruby
class DropPosts < ActiveRecord::Migration[7.0]
  def change
    drop_table :posts
  end
end

# カラム情報も保持（rollback可能に）
class DropPosts < ActiveRecord::Migration[7.0]
  def change
    drop_table :posts do |t|
      t.string :title
      t.text :body
      t.timestamps
    end
  end
end
```

### テーブル名変更

```ruby
class RenamePostsToArticles < ActiveRecord::Migration[7.0]
  def change
    rename_table :posts, :articles
  end
end
```

---

## カラム操作

### カラム追加

```ruby
class AddEmailToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email, :string
    add_column :users, :age, :integer, default: 0
    add_column :users, :bio, :text, null: false
  end
end
```

### カラム削除

```ruby
class RemoveEmailFromUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :email, :string
  end
end
```

### カラム名変更

```ruby
class RenameEmailToEmailAddress < ActiveRecord::Migration[7.0]
  def change
    rename_column :users, :email, :email_address
  end
end
```

### カラム型変更

```ruby
class ChangeBodyTypeInPosts < ActiveRecord::Migration[7.0]
  def change
    change_column :posts, :body, :text
    change_column :posts, :view_count, :bigint
  end
end
```

### カラム属性変更

```ruby
class ChangePostsPublishedDefault < ActiveRecord::Migration[7.0]
  def change
    # null制約を変更
    change_column_null :posts, :title, false

    # デフォルト値を変更
    change_column_default :posts, :published, from: false, to: true

    # デフォルト値を削除
    change_column_default :posts, :view_count, from: 0, to: nil
  end
end
```

### 複数カラム一括追加

```ruby
class AddDetailsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :age, :integer
    add_column :users, :city, :string
    add_column :users, :country, :string
  end
end

# または

class AddDetailsToUsers < ActiveRecord::Migration[7.0]
  def change
    change_table :users do |t|
      t.integer :age
      t.string :city
      t.string :country
    end
  end
end
```

---

## インデックス

### インデックス追加

```ruby
class AddIndexToUsersEmail < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :email
  end
end
```

### ユニークインデックス

```ruby
class AddUniqueIndexToUsersEmail < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :email, unique: true
  end
end
```

### 複合インデックス

```ruby
class AddIndexToPostsUserIdAndCreatedAt < ActiveRecord::Migration[7.0]
  def change
    add_index :posts, [:user_id, :created_at]
  end
end
```

### インデックス削除

```ruby
class RemoveIndexFromUsersEmail < ActiveRecord::Migration[7.0]
  def change
    remove_index :users, :email
  end
end

# カラム名ではなくインデックス名で削除
remove_index :users, name: :index_users_on_email
```

### インデックス名指定

```ruby
class AddIndexToUsersEmail < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :email, name: :users_email_idx
  end
end
```

---

## 外部キー

### references（推奨）

```ruby
class AddUserRefToPosts < ActiveRecord::Migration[7.0]
  def change
    add_reference :posts, :user, foreign_key: true
  end
end

# 生成されるカラム: user_id
# 外部キー制約も自動追加
```

### 外部キーのみ追加

```ruby
class AddForeignKeyToPostsUserId < ActiveRecord::Migration[7.0]
  def change
    add_foreign_key :posts, :users
  end
end
```

### ON DELETE オプション

```ruby
class AddUserRefToPosts < ActiveRecord::Migration[7.0]
  def change
    add_reference :posts, :user, foreign_key: { on_delete: :cascade }
  end
end

# オプション:
# :cascade   - 親レコード削除時に子レコードも削除
# :nullify   - 親レコード削除時に外部キーをNULLに
# :restrict  - 子レコードが存在する場合は削除不可
```

### 外部キー削除

```ruby
class RemoveForeignKeyFromPosts < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :posts, :users
  end
end
```

---

## データ操作

マイグレーション内でデータ操作も可能（非推奨、seedsを使う方が良い）。

```ruby
class AddAdminUser < ActiveRecord::Migration[7.0]
  def up
    User.create(name: 'Admin', email: 'admin@example.com', role: 'admin')
  end

  def down
    User.find_by(email: 'admin@example.com')&.destroy
  end
end
```

### reversibleブロック

```ruby
class ChangeProductsPrice < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        # マイグレーション時の処理
        change_column :products, :price, :decimal, precision: 10, scale: 2
      end

      dir.down do
        # ロールバック時の処理
        change_column :products, :price, :integer
      end
    end
  end
end
```

---

## 可逆的でないマイグレーション

`change` メソッドで自動的に戻せない操作は、`up` と `down` を使う。

```ruby
class RemoveEmailFromUsers < ActiveRecord::Migration[7.0]
  def up
    remove_column :users, :email
  end

  def down
    add_column :users, :email, :string
  end
end
```

### 可逆的な操作

`change` で自動的にロールバック可能:

- `add_column`
- `add_foreign_key`
- `add_index`
- `add_reference`
- `add_timestamps`
- `create_table`
- `enable_extension`
- `rename_column`
- `rename_table`

### 可逆的でない操作

`up`/`down` が必要:

- `remove_column`（型情報がないため）
- `change_column`
- `change_column_default`
- `execute`（生SQL実行）

---

## 生SQL実行

```ruby
class AddCheckConstraint < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      ALTER TABLE products
      ADD CONSTRAINT price_check CHECK (price > 0);
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE products
      DROP CONSTRAINT price_check;
    SQL
  end
end
```

---

## データ型一覧

| Rails型 | 説明 | 例 |
|---------|------|-----|
| :string | 可変長文字列（255文字まで） | 名前、メール |
| :text | 長文テキスト | 本文、説明 |
| :integer | 整数 | 年齢、カウント |
| :bigint | 大きな整数 | ID（多数のレコード） |
| :float | 浮動小数点 | 評価スコア |
| :decimal | 固定小数点 | 価格、金額 |
| :boolean | 真偽値 | フラグ |
| :date | 日付 | 誕生日 |
| :time | 時刻 | 営業時間 |
| :datetime | 日時 | 投稿日時 |
| :timestamp | タイムスタンプ | 作成日時、更新日時 |
| :binary | バイナリデータ | 画像、ファイル |
| :json | JSON（PostgreSQL、MySQL 5.7+） | 設定、メタデータ |
| :jsonb | JSONB（PostgreSQL） | インデックス可能なJSON |

---

## ベストプラクティス

### 1. マイグレーションは小さく保つ

```ruby
# ✗ 悪い例（一つのマイグレーションで複数の変更）
class UpdateUsersAndPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email, :string
    add_column :posts, :published, :boolean
    create_table :comments do |t|
      t.text :body
      t.timestamps
    end
  end
end

# ○ 良い例（変更ごとに分ける）
# migration 1
class AddEmailToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email, :string
  end
end

# migration 2
class AddPublishedToPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :published, :boolean
  end
end

# migration 3
class CreateComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.text :body
      t.timestamps
    end
  end
end
```

### 2. 本番環境でのマイグレーション

```ruby
# ✗ 悪い例（ダウンタイムが発生）
class ChangeEmailTypeInUsers < ActiveRecord::Migration[7.0]
  def change
    change_column :users, :email, :text
  end
end

# ○ 良い例（新カラム追加→データ移行→旧カラム削除）
# Step 1
class AddNewEmailToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :new_email, :text
  end
end

# Step 2（データ移行はアプリケーションコードで）
# User.find_each { |u| u.update(new_email: u.email) }

# Step 3
class RemoveOldEmailFromUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :email
    rename_column :users, :new_email, :email
  end
end
```

### 3. NOT NULL制約は慎重に

```ruby
# ✗ 悪い例（既存レコードがあるとエラー）
class AddEmailToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email, :string, null: false
  end
end

# ○ 良い例（デフォルト値を設定）
class AddEmailToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email, :string, default: '', null: false
  end
end

# または段階的に
# 1. null: true でカラム追加
# 2. データ移行
# 3. null: false に変更
```

### 4. インデックスを忘れずに

```ruby
# 外部キーには必ずインデックス
class AddUserToPosts < ActiveRecord::Migration[7.0]
  def change
    add_reference :posts, :user, foreign_key: true, index: true
  end
end

# 検索に使うカラムにもインデックス
class AddIndexToUsersEmail < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :email, unique: true
  end
end
```

### 5. マイグレーションファイルは編集しない

一度実行したマイグレーションファイルは編集せず、新しいマイグレーションで修正する。

---

## トラブルシューティング

### マイグレーションが失敗した

```bash
# 状態確認
rails db:migrate:status

# 失敗したマイグレーションを修正してリトライ
rails db:migrate

# それでもダメならロールバック
rails db:rollback
```

### 特定のマイグレーションをスキップ

```bash
# バージョンを手動で記録（非推奨）
rails runner "ActiveRecord::SchemaMigration.create(version: '20231201120000')"
```

### スキーマのリセット

```bash
# schema.rbから再構築（マイグレーション履歴無視）
rails db:schema:load

# 完全リセット
rails db:drop db:create db:migrate
```

---

## 参考リンク

- [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- [Railsガイド：マイグレーション](https://railsguides.jp/active_record_migrations.html)
