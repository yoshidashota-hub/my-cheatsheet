# Ruby on Rails アソシエーション

## 目次
- [アソシエーションとは](#アソシエーションとは)
- [has_many / belongs_to](#has_many--belongs_to)
- [has_one](#has_one)
- [has_many :through](#has_many-through)
- [has_and_belongs_to_many](#has_and_belongs_to_many)
- [ポリモーフィック関連](#ポリモーフィック関連)
- [自己結合](#自己結合)
- [アソシエーションのオプション](#アソシエーションのオプション)

---

## アソシエーションとは

モデル間の関連を定義する機能。データベースの外部キーを利用して、関連するレコードを簡単に操作できる。

### アソシエーションの種類

| 種類 | 説明 | 例 |
|------|------|-----|
| belongs_to | 所属（N:1の N 側） | 記事 → 著者 |
| has_one | 1対1の所有 | ユーザー → プロフィール |
| has_many | 1対多の所有 | 著者 → 記事 |
| has_many :through | 多対多（中間テーブル経由） | 学生 ← 登録 → コース |
| has_and_belongs_to_many | 多対多（単純） | 記事 ↔ タグ |

---

## has_many / belongs_to

最も一般的な1対多の関連。

### 基本

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :posts
end

# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :user
end
```

### マイグレーション

```ruby
# postsテーブルに user_id を追加
class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :body
      t.references :user, foreign_key: true  # user_id カラム追加
      t.timestamps
    end
  end
end
```

### 使用例

```ruby
user = User.find(1)

# 関連するpostを取得
user.posts
# SELECT * FROM posts WHERE user_id = 1

user.posts.count
user.posts.first
user.posts.last

# 新規作成
post = user.posts.create(title: 'Hello', body: 'World')
post = user.posts.build(title: 'Hello')  # 保存しない
user.posts << Post.new(title: 'Test')

# 削除
user.posts.destroy(post)
user.posts.clear  # 全削除
user.posts = []   # 全削除
```

```ruby
post = Post.find(1)

# 親を取得
post.user
# SELECT * FROM users WHERE id = ?

# 親を変更
post.user = User.find(2)
post.save
```

---

## has_one

1対1の関連。

### 基本

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_one :profile
end

# app/models/profile.rb
class Profile < ApplicationRecord
  belongs_to :user
end
```

### マイグレーション

```ruby
class CreateProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :profiles do |t|
      t.string :bio
      t.string :website
      t.references :user, foreign_key: true
      t.timestamps
    end
  end
end
```

### 使用例

```ruby
user = User.find(1)

# 関連レコード取得
user.profile

# 作成
user.create_profile(bio: 'Hello', website: 'https://example.com')
user.build_profile(bio: 'Hello')  # 保存しない

# 削除
user.profile.destroy
```

---

## has_many :through

中間テーブルを経由した多対多の関連。

### 基本（学生とコース）

```ruby
# app/models/student.rb
class Student < ApplicationRecord
  has_many :enrollments
  has_many :courses, through: :enrollments
end

# app/models/course.rb
class Course < ApplicationRecord
  has_many :enrollments
  has_many :students, through: :enrollments
end

# app/models/enrollment.rb（中間テーブル）
class Enrollment < ApplicationRecord
  belongs_to :student
  belongs_to :course
end
```

### マイグレーション

```ruby
# 中間テーブル
class CreateEnrollments < ActiveRecord::Migration[7.0]
  def change
    create_table :enrollments do |t|
      t.references :student, foreign_key: true
      t.references :course, foreign_key: true
      t.date :enrolled_at
      t.string :grade
      t.timestamps
    end
  end
end
```

### 使用例

```ruby
student = Student.find(1)

# 関連するcourseを取得
student.courses

# 追加
course = Course.find(1)
student.courses << course

# 中間テーブル経由で作成（追加情報も保存）
student.enrollments.create(course: course, enrolled_at: Date.today)

# 中間テーブルの情報取得
student.enrollments.each do |enrollment|
  puts "#{enrollment.course.name} - Grade: #{enrollment.grade}"
end
```

---

## has_and_belongs_to_many

シンプルな多対多の関連（中間モデルが不要な場合）。

### 基本

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  has_and_belongs_to_many :tags
end

# app/models/tag.rb
class Tag < ApplicationRecord
  has_and_belongs_to_many :posts
end
```

### マイグレーション

```ruby
# 中間テーブル（モデルなし、アルファベット順の命名）
class CreatePostsTagsJoinTable < ActiveRecord::Migration[7.0]
  def change
    create_table :posts_tags, id: false do |t|
      t.references :post, foreign_key: true
      t.references :tag, foreign_key: true
    end

    add_index :posts_tags, [:post_id, :tag_id], unique: true
  end
end
```

### 使用例

```ruby
post = Post.find(1)

# タグ取得
post.tags

# 追加
tag = Tag.find(1)
post.tags << tag

# 削除
post.tags.delete(tag)
post.tags.clear
```

### has_many :through との使い分け

- **has_and_belongs_to_many**: 中間テーブルに追加情報が不要な場合
- **has_many :through**: 中間テーブルに日時、ステータス等の追加情報が必要な場合

---

## ポリモーフィック関連

複数のモデルに属することができる関連。

### 基本（コメント機能）

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

# app/models/post.rb
class Post < ApplicationRecord
  has_many :comments, as: :commentable
end

# app/models/photo.rb
class Photo < ApplicationRecord
  has_many :comments, as: :commentable
end
```

### マイグレーション

```ruby
class CreateComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.text :body
      t.references :commentable, polymorphic: true
      # 上記は以下と同等:
      # t.integer :commentable_id
      # t.string :commentable_type

      t.timestamps
    end

    add_index :comments, [:commentable_type, :commentable_id]
  end
end
```

### 使用例

```ruby
post = Post.find(1)
photo = Photo.find(1)

# コメント追加
post.comments.create(body: 'Great post!')
photo.comments.create(body: 'Nice photo!')

# コメントから親を取得
comment = Comment.first
comment.commentable  # Post または Photo インスタンス
comment.commentable_type  # => "Post" または "Photo"
comment.commentable_id    # => 1
```

---

## 自己結合

同じテーブル内で関連を持つ。

### 基本（フォロー機能）

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # フォローしているユーザー
  has_many :active_relationships,
    class_name: 'Relationship',
    foreign_key: 'follower_id',
    dependent: :destroy
  has_many :following, through: :active_relationships, source: :followed

  # フォロワー
  has_many :passive_relationships,
    class_name: 'Relationship',
    foreign_key: 'followed_id',
    dependent: :destroy
  has_many :followers, through: :passive_relationships, source: :follower

  # フォロー/アンフォロー
  def follow(other_user)
    following << other_user
  end

  def unfollow(other_user)
    following.delete(other_user)
  end

  def following?(other_user)
    following.include?(other_user)
  end
end

# app/models/relationship.rb
class Relationship < ApplicationRecord
  belongs_to :follower, class_name: 'User'
  belongs_to :followed, class_name: 'User'

  validates :follower_id, presence: true
  validates :followed_id, presence: true
end
```

### マイグレーション

```ruby
class CreateRelationships < ActiveRecord::Migration[7.0]
  def change
    create_table :relationships do |t|
      t.integer :follower_id
      t.integer :followed_id
      t.timestamps
    end

    add_index :relationships, :follower_id
    add_index :relationships, :followed_id
    add_index :relationships, [:follower_id, :followed_id], unique: true
  end
end
```

### 使用例

```ruby
user = User.find(1)
other_user = User.find(2)

# フォロー
user.follow(other_user)

# フォローしているユーザー一覧
user.following

# フォロワー一覧
user.followers

# フォローしているか確認
user.following?(other_user)  # => true

# アンフォロー
user.unfollow(other_user)
```

---

## アソシエーションのオプション

### dependent

親レコード削除時の子レコードの扱い。

```ruby
class User < ApplicationRecord
  # 親削除時に子も削除（コールバック実行）
  has_many :posts, dependent: :destroy

  # 親削除時に子も削除（コールバックなし、高速）
  has_many :comments, dependent: :delete_all

  # 親削除時に子の外部キーをNULLに
  has_many :likes, dependent: :nullify

  # 親削除時に子があればエラー
  has_many :orders, dependent: :restrict_with_error

  # 親削除時に子があれば例外
  has_many :products, dependent: :restrict_with_exception
end
```

### foreign_key

外部キーのカラム名を指定。

```ruby
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User', foreign_key: 'user_id'
end
```

### class_name

関連するモデル名を明示的に指定。

```ruby
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'
  has_many :comments, class_name: 'Feedback'
end
```

### primary_key

主キーのカラム名を指定（デフォルトは id）。

```ruby
class User < ApplicationRecord
  has_many :posts, primary_key: 'user_uid', foreign_key: 'author_uid'
end
```

### inverse_of

逆方向の関連を明示的に指定（パフォーマンス向上）。

```ruby
class User < ApplicationRecord
  has_many :posts, inverse_of: :author
end

class Post < ApplicationRecord
  belongs_to :author, class_name: 'User', inverse_of: :posts
end
```

### source

`has_many :through` で中間テーブルの関連名を指定。

```ruby
class User < ApplicationRecord
  has_many :active_relationships, class_name: 'Relationship', foreign_key: 'follower_id'
  has_many :following, through: :active_relationships, source: :followed
end
```

### counter_cache

関連レコードの件数をキャッシュ（パフォーマンス向上）。

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :user, counter_cache: true
  # または
  belongs_to :user, counter_cache: :posts_count
end

# マイグレーション
class AddPostsCountToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :posts_count, :integer, default: 0, null: false
  end
end

# 使用例
user.posts_count  # SELECT なしでカウント取得
```

### touch

子レコード更新時に親の updated_at も更新。

```ruby
class Post < ApplicationRecord
  belongs_to :user, touch: true
  # または
  belongs_to :user, touch: :posts_updated_at
end
```

### optional

Rails 5以降、`belongs_to` はデフォルトで必須。任意にする場合。

```ruby
class Post < ApplicationRecord
  belongs_to :user, optional: true
end
```

### autosave

親保存時に関連レコードも自動保存。

```ruby
class User < ApplicationRecord
  has_one :profile, autosave: true
end

user = User.new(name: 'John')
user.build_profile(bio: 'Hello')
user.save  # user と profile の両方を保存
```

---

## N+1問題の解決

### includes（Eager Loading）

```ruby
# ✗ N+1問題（1 + N 回のクエリ）
posts = Post.all
posts.each do |post|
  puts post.user.name  # 各postごとにクエリ実行
end

# ○ Eager Loading（2回のクエリ）
posts = Post.includes(:user).all
posts.each do |post|
  puts post.user.name  # メモリから取得
end

# 複数の関連
posts = Post.includes(:user, :comments)

# ネストした関連
posts = Post.includes(user: :profile, comments: :author)
```

### preload / eager_load / joins

```ruby
# preload: 別々のクエリで取得（LEFT OUTER JOIN不要な場合）
Post.preload(:user)

# eager_load: LEFT OUTER JOIN で取得
Post.eager_load(:user)

# joins: INNER JOIN（条件に使う場合）
Post.joins(:user).where(users: { active: true })
```

---

## ネストした属性

親モデルから子モデルを一括操作。

### accepts_nested_attributes_for

```ruby
class User < ApplicationRecord
  has_one :profile
  accepts_nested_attributes_for :profile
end

class Post < ApplicationRecord
  has_many :comments
  accepts_nested_attributes_for :comments, allow_destroy: true
end
```

### Strong Parameters

```ruby
# app/controllers/users_controller.rb
def user_params
  params.require(:user).permit(
    :name,
    :email,
    profile_attributes: [:id, :bio, :website],
    posts_attributes: [:id, :title, :body, :_destroy]
  )
end
```

### ビュー

```erb
<%= form_with model: @user do |f| %>
  <%= f.text_field :name %>

  <%= f.fields_for :profile do |profile_form| %>
    <%= profile_form.text_area :bio %>
    <%= profile_form.text_field :website %>
  <% end %>

  <%= f.submit %>
<% end %>
```

---

## ベストプラクティス

### 1. dependent を忘れずに

```ruby
# ○ 親削除時の挙動を明示
class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
end
```

### 2. N+1問題に注意

```ruby
# ✗ N+1
@posts = Post.all

# ○ includes を使用
@posts = Post.includes(:user, :comments)
```

### 3. counter_cache でパフォーマンス向上

```ruby
class Post < ApplicationRecord
  belongs_to :user, counter_cache: true
end
```

### 4. 複雑な関連は has_many :through

```ruby
# ○ 中間テーブルに追加情報を持つ
class Student < ApplicationRecord
  has_many :enrollments
  has_many :courses, through: :enrollments
end
```

---

## 参考リンク

- [Active Record Associations](https://guides.rubyonrails.org/association_basics.html)
- [Railsガイド：アソシエーション](https://railsguides.jp/association_basics.html)
