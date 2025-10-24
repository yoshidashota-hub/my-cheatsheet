# Ruby on Rails クエリ & ActiveRecord詳細

## 目次
- [クエリの基本](#クエリの基本)
- [条件指定](#条件指定)
- [並び替え・制限](#並び替え制限)
- [集計](#集計)
- [結合](#結合)
- [サブクエリ](#サブクエリ)
- [生SQL](#生sql)
- [パフォーマンス最適化](#パフォーマンス最適化)

---

## クエリの基本

### レコード取得

```ruby
# 全件取得
User.all

# 最初/最後
User.first
User.last
User.first(3)  # 最初の3件

# IDで検索
User.find(1)
User.find([1, 2, 3])
User.find_by(id: 1)  # nilを返す（例外なし）

# 条件で検索
User.find_by(email: 'test@example.com')
User.find_by!(email: 'test@example.com')  # 見つからなければ例外

# 存在確認
User.exists?(1)
User.exists?(email: 'test@example.com')
User.where(active: true).exists?
```

---

## 条件指定

### where

```ruby
# ハッシュ形式
User.where(active: true)
User.where(role: 'admin', active: true)  # AND条件

# 配列
User.where(id: [1, 2, 3])
User.where(role: ['admin', 'moderator'])

# 範囲
User.where(age: 18..65)
User.where(created_at: 1.week.ago..Time.current)

# NULL判定
User.where(deleted_at: nil)
User.where.not(deleted_at: nil)

# 文字列（プレースホルダー）
User.where('age > ?', 18)
User.where('age > ? AND active = ?', 18, true)

# 名前付きプレースホルダー
User.where('age > :age AND role = :role', age: 18, role: 'admin')

# LIKE検索
User.where('name LIKE ?', '%John%')
User.where('email LIKE ?', '%@example.com')

# 複雑な条件
User.where('age > ? OR role = ?', 18, 'admin')
```

### where.not

```ruby
# 否定
User.where.not(role: 'guest')
User.where.not(id: [1, 2, 3])
```

### or

```ruby
# OR条件
User.where(role: 'admin').or(User.where(role: 'moderator'))
User.where(active: true).or(User.where(role: 'admin'))
```

### and

```ruby
# AND条件（チェーン可能）
User.where(active: true).where(role: 'admin')

# 明示的に
User.where(active: true).and(User.where(role: 'admin'))
```

---

## 並び替え・制限

### order

```ruby
# 昇順
User.order(:name)
User.order(name: :asc)

# 降順
User.order(name: :desc)
User.order(created_at: :desc)

# 複数カラム
User.order(role: :asc, name: :asc)
User.order('role ASC, name ASC')

# NULL の扱い（PostgreSQL）
User.order('name ASC NULLS LAST')
User.order('name DESC NULLS FIRST')

# ランダム
User.order('RANDOM()')  # PostgreSQL/SQLite
User.order('RAND()')    # MySQL

# 既存のorderを上書き
User.order(:name).reorder(:email)

# orderを削除
User.order(:name).unscope(:order)
```

### limit / offset

```ruby
# 件数制限
User.limit(10)

# オフセット（スキップ）
User.offset(20)

# ページネーション
User.limit(10).offset(20)  # 21〜30件目

# first/last と組み合わせ
User.order(:name).limit(5).first
```

---

## 集計

### count

```ruby
# 件数
User.count
User.where(active: true).count

# 特定カラムをカウント（NULLを除外）
User.count(:email)

# DISTINCT
User.distinct.count(:role)
```

### average / sum / minimum / maximum

```ruby
# 平均
Product.average(:price)
Product.where(category: 'electronics').average(:price)

# 合計
Order.sum(:total_price)

# 最小値
Product.minimum(:price)

# 最大値
Product.maximum(:price)
```

### group

```ruby
# グループ化
User.group(:role).count
# => {"admin"=>5, "user"=>20, "guest"=>10}

Order.group(:status).sum(:total_price)
# => {"pending"=>10000, "completed"=>50000}

# 複数カラムでグループ化
Order.group(:user_id, :status).count

# having（グループ化後の条件）
User.group(:role).having('COUNT(*) > ?', 10)
```

### pluck / pick

```ruby
# 特定カラムの値を配列で取得
User.pluck(:email)
# => ["user1@example.com", "user2@example.com"]

User.pluck(:id, :name)
# => [[1, "Alice"], [2, "Bob"]]

# 最初の1件のカラム値を取得
User.pick(:email)
# => "user1@example.com"

# IDs（id カラムのみ）
User.ids
# => [1, 2, 3, 4, 5]
```

---

## 結合

### joins（INNER JOIN）

```ruby
# 単純な結合
Post.joins(:user)
# SELECT posts.* FROM posts INNER JOIN users ON users.id = posts.user_id

# 複数の関連
Post.joins(:user, :comments)

# ネストした関連
Post.joins(user: :profile)
Post.joins(comments: :author)

# 条件付き
Post.joins(:user).where(users: { active: true })

# 複数テーブルの条件
Post.joins(:user, :comments)
    .where(users: { role: 'admin' })
    .where(comments: { approved: true })
```

### left_joins（LEFT OUTER JOIN）

```ruby
# LEFT OUTER JOIN
User.left_joins(:posts)

# 投稿がないユーザーも含める
User.left_joins(:posts).where(posts: { id: nil })

# 投稿数をカウント
User.left_joins(:posts).group('users.id').count('posts.id')
```

### includes（Eager Loading）

```ruby
# N+1問題を解決
posts = Post.includes(:user)
posts.each { |post| post.user.name }  # 追加クエリなし

# 複数の関連
Post.includes(:user, :comments)

# ネスト
Post.includes(user: :profile, comments: :author)

# 条件付き（references必要）
Post.includes(:user).where('users.active = ?', true).references(:user)
```

### preload / eager_load

```ruby
# preload: 別々のクエリで取得
Post.preload(:user)
# SELECT * FROM posts
# SELECT * FROM users WHERE id IN (...)

# eager_load: LEFT OUTER JOINで取得
Post.eager_load(:user)
# SELECT * FROM posts LEFT OUTER JOIN users ON ...
```

---

## サブクエリ

### where サブクエリ

```ruby
# サブクエリ
User.where(id: Post.select(:user_id))

# EXISTS
User.where('EXISTS (?)', Post.select(1).where('posts.user_id = users.id'))

# IN
expensive_products = Product.where('price > 1000')
Order.where(product_id: expensive_products.select(:id))
```

### from サブクエリ

```ruby
# サブクエリをFROMに
subquery = Post.select(:user_id).where(published: true)
User.from(subquery, :posts).distinct
```

---

## 生SQL

### find_by_sql

```ruby
# 生SQLでクエリ
users = User.find_by_sql('SELECT * FROM users WHERE age > 18')

# プレースホルダー
users = User.find_by_sql(['SELECT * FROM users WHERE age > ?', 18])
```

### select（カラム指定）

```ruby
# 特定カラムのみ選択
User.select(:id, :name, :email)
User.select('id, name, UPPER(email) as email')

# 計算フィールド
User.select('*, (price * quantity) as total')
```

### distinct

```ruby
# 重複排除
User.select(:role).distinct
User.distinct.pluck(:role)
```

### raw SQL

```ruby
# 完全な生SQL
sql = 'SELECT * FROM users WHERE age > 18'
records = ActiveRecord::Base.connection.execute(sql)

# トランザクション内で
ActiveRecord::Base.transaction do
  ActiveRecord::Base.connection.execute('UPDATE users SET active = false')
end
```

---

## スコープ活用

### スコープチェーン

```ruby
class Post < ApplicationRecord
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { where('views > ?', 100) }
  scope :by_author, ->(author_id) { where(author_id: author_id) }
end

# チェーン可能
Post.published.recent.popular
Post.published.by_author(current_user.id).limit(10)
```

### デフォルトスコープ

```ruby
class Post < ApplicationRecord
  default_scope { where(deleted: false) }
end

# デフォルトスコープを解除
Post.unscoped.all
Post.unscoped.where(deleted: true)
```

---

## パフォーマンス最適化

### N+1問題の解決

```ruby
# ✗ N+1問題
posts = Post.all
posts.each do |post|
  puts post.user.name       # Nクエリ
  puts post.comments.count  # Nクエリ
end

# ○ includes で解決
posts = Post.includes(:user, :comments)
posts.each do |post|
  puts post.user.name       # メモリから取得
  puts post.comments.count  # メモリから取得
end
```

### select で不要なカラムを取得しない

```ruby
# ✗ 全カラム取得
User.all

# ○ 必要なカラムのみ
User.select(:id, :name, :email)
```

### pluck で軽量化

```ruby
# ✗ ActiveRecordオブジェクト生成
User.all.map(&:email)

# ○ pluck で配列取得
User.pluck(:email)
```

### find_each でバッチ処理

```ruby
# ✗ 全件メモリに読み込み
User.all.each do |user|
  # 処理
end

# ○ バッチごとに読み込み（デフォルト1000件ずつ）
User.find_each do |user|
  # 処理
end

User.find_each(batch_size: 500) do |user|
  # 処理
end

# find_in_batches（配列で渡される）
User.find_in_batches do |users|
  users.each { |user| # 処理 }
end
```

### counter_cache

```ruby
# ✗ 毎回COUNT
@user.posts.count  # SELECT COUNT(*) ...

# ○ counter_cache
class Post < ApplicationRecord
  belongs_to :user, counter_cache: true
end

@user.posts_count  # カラムから取得（クエリなし）
```

### 一括更新

```ruby
# ✗ 1件ずつ更新
users.each { |user| user.update(active: true) }

# ○ 一括更新
User.where(role: 'admin').update_all(active: true)
```

### インデックス活用

```ruby
# WHERE句、JOIN、ORDER BY に使うカラムにインデックス
# マイグレーション
add_index :users, :email
add_index :posts, :user_id
add_index :posts, [:user_id, :created_at]
```

---

## トランザクション

### 基本

```ruby
ActiveRecord::Base.transaction do
  user = User.create!(name: 'John')
  profile = Profile.create!(user: user, bio: 'Hello')
  # エラーが発生すればロールバック
end
```

### 例外処理

```ruby
begin
  ActiveRecord::Base.transaction do
    user.update!(balance: user.balance - 100)
    other_user.update!(balance: other_user.balance + 100)
  end
rescue ActiveRecord::RecordInvalid => e
  # ロールバックされた後の処理
  Rails.logger.error e.message
end
```

### ネストしたトランザクション

```ruby
User.transaction do
  user.save!
  Post.transaction do
    post.save!
  end
end

# requires_new: true で独立したトランザクション
User.transaction do
  user.save!
  Post.transaction(requires_new: true) do
    post.save!
  end
end
```

---

## ロック

### 楽観的ロック（Optimistic Locking）

```ruby
# マイグレーション
add_column :products, :lock_version, :integer, default: 0

# 使用例
product = Product.find(1)
product.update(price: 100)
# lock_version が変わっていれば ActiveRecord::StaleObjectError
```

### 悲観的ロック（Pessimistic Locking）

```ruby
# 行ロック
product = Product.lock.find(1)
product.update(stock: product.stock - 1)

# with_lock ブロック
product = Product.find(1)
product.with_lock do
  product.stock -= 1
  product.save!
end

# 共有ロック（読み取り専用）
Product.lock('LOCK IN SHARE MODE').find(1)
```

---

## クエリログ

### ログ出力

```ruby
# 開発環境では自動的にログ出力
User.where(active: true).to_sql
# => "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"active\" = 't'"

# explainでクエリプラン確認
User.where(active: true).explain
```

### クエリ実行時間の計測

```ruby
# ベンチマーク
result = Benchmark.measure do
  User.includes(:posts).limit(100).to_a
end
puts result
```

---

## ベストプラクティス

### 1. N+1問題を避ける

```ruby
# Bullet gem で検出
# https://github.com/flyerhzm/bullet
```

### 2. 必要なデータのみ取得

```ruby
# select で必要なカラムのみ
# limit で件数制限
# pluck で配列取得
```

### 3. インデックスを適切に設定

```ruby
# WHERE, JOIN, ORDER BY に使うカラム
```

### 4. バッチ処理には find_each

```ruby
User.find_each do |user|
  # 大量データを処理
end
```

### 5. スコープで可読性向上

```ruby
class Post < ApplicationRecord
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
end

Post.published.recent.limit(10)
```

---

## 参考リンク

- [Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)
- [Railsガイド：クエリインターフェース](https://railsguides.jp/active_record_querying.html)
- [Bullet gem](https://github.com/flyerhzm/bullet)
