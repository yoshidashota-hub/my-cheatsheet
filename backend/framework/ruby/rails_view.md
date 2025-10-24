# Ruby on Rails ビュー

## 目次
- [ビューの基本](#ビューの基本)
- [ERB](#erb)
- [ヘルパーメソッド](#ヘルパーメソッド)
- [パーシャル](#パーシャル)
- [レイアウト](#レイアウト)
- [フォームヘルパー](#フォームヘルパー)
- [Slim](#slim)
- [Haml](#haml)

---

## ビューの基本

ビューは `app/views/` に配置。コントローラーとアクション名に対応。

### ファイル配置
```
app/views/
├── layouts/
│   └── application.html.erb    # 全ページ共通レイアウト
├── posts/
│   ├── index.html.erb          # posts#index
│   ├── show.html.erb           # posts#show
│   ├── new.html.erb            # posts#new
│   ├── edit.html.erb           # posts#edit
│   └── _form.html.erb          # パーシャル
└── shared/
    ├── _header.html.erb
    └── _footer.html.erb
```

### 命名規則
- `アクション名.フォーマット.テンプレートエンジン`
- 例: `index.html.erb`, `show.json.jbuilder`

---

## ERB

Embedded Ruby。Railsのデフォルトテンプレートエンジン。

### 基本構文

```erb
<!-- 式の埋め込み（出力あり） -->
<%= @post.title %>
<%= Time.current %>

<!-- 式の埋め込み（出力なし） -->
<% @posts.each do |post| %>
  <h2><%= post.title %></h2>
<% end %>

<!-- コメント -->
<%# これはERBコメント（HTMLに出力されない） %>
<!-- これはHTMLコメント（HTMLに出力される） -->
```

### 条件分岐

```erb
<% if @user.admin? %>
  <p>管理者</p>
<% elsif @user.moderator? %>
  <p>モデレーター</p>
<% else %>
  <p>一般ユーザー</p>
<% end %>

<!-- unless -->
<% unless @posts.empty? %>
  <ul>
    <% @posts.each do |post| %>
      <li><%= post.title %></li>
    <% end %>
  </ul>
<% end %>
```

### ループ

```erb
<!-- each -->
<ul>
  <% @posts.each do |post| %>
    <li><%= post.title %></li>
  <% end %>
</ul>

<!-- インデックス付き -->
<% @posts.each_with_index do |post, index| %>
  <%= index + 1 %>. <%= post.title %>
<% end %>

<!-- for -->
<% for post in @posts %>
  <p><%= post.title %></p>
<% end %>
```

---

## ヘルパーメソッド

### リンク・URL

```erb
<!-- リンク -->
<%= link_to 'Home', root_path %>
<%= link_to 'Posts', posts_path %>
<%= link_to @post.title, post_path(@post) %>
<%= link_to @post.title, @post %>  <!-- 短縮形 -->

<!-- クラス・id 指定 -->
<%= link_to 'Home', root_path, class: 'btn btn-primary', id: 'home-link' %>

<!-- data属性 -->
<%= link_to 'Delete', @post, method: :delete, data: { confirm: 'Are you sure?' } %>

<!-- target="_blank" -->
<%= link_to 'Google', 'https://google.com', target: '_blank', rel: 'noopener' %>

<!-- ブロック形式 -->
<%= link_to post_path(@post) do %>
  <h2><%= @post.title %></h2>
  <p><%= @post.excerpt %></p>
<% end %>
```

### 画像

```erb
<!-- 画像 -->
<%= image_tag 'logo.png' %>
<%= image_tag 'logo.png', alt: 'Logo', class: 'img-fluid' %>
<%= image_tag 'logo.png', size: '300x200' %>
<%= image_tag 'logo.png', width: 300, height: 200 %>

<!-- Active Storageの画像 -->
<%= image_tag @user.avatar %>
<%= image_tag @user.avatar.variant(resize_to_limit: [100, 100]) %>
```

### テキスト

```erb
<!-- HTML エスケープ -->
<%= @post.body %>  <!-- 自動的にエスケープ -->

<!-- HTMLをそのまま出力（XSS注意） -->
<%= raw @post.body %>
<%= @post.body.html_safe %>

<!-- 改行をbrに変換 -->
<%= simple_format @post.body %>

<!-- 文字数制限 -->
<%= truncate @post.body, length: 100 %>
<%= truncate @post.body, length: 100, separator: ' ' %>

<!-- ハイライト -->
<%= highlight @post.body, 'Rails' %>

<!-- 複数形/単数形 -->
<%= pluralize @posts.count, 'post' %>
<!-- 1 post, 2 posts -->
```

### 数値・日時

```erb
<!-- 数値フォーマット -->
<%= number_with_delimiter 1000000 %>
<!-- 1,000,000 -->

<%= number_to_currency 1234.56 %>
<!-- $1,234.56 -->

<%= number_to_percentage 85.5 %>
<!-- 85.5% -->

<!-- 日時フォーマット -->
<%= @post.created_at.strftime('%Y/%m/%d %H:%M') %>
<!-- 2023/12/01 15:30 -->

<%= time_ago_in_words @post.created_at %>
<!-- about 2 hours ago -->

<%= distance_of_time_in_words @post.created_at, Time.current %>
<!-- about 2 hours -->
```

### その他

```erb
<!-- HTMLタグ生成 -->
<%= content_tag :div, 'Hello', class: 'box' %>
<!-- <div class="box">Hello</div> -->

<%= content_tag :p do %>
  This is a paragraph.
<% end %>

<!-- CSS/JSアセット -->
<%= stylesheet_link_tag 'application' %>
<%= javascript_include_tag 'application' %>

<!-- CSRF トークン -->
<%= csrf_meta_tags %>
```

---

## パーシャル

再利用可能なビューの部品。ファイル名は `_` で始まる。

### 基本

```erb
<!-- app/views/posts/_post.html.erb -->
<div class="post">
  <h2><%= post.title %></h2>
  <p><%= post.body %></p>
</div>
```

```erb
<!-- app/views/posts/index.html.erb -->
<% @posts.each do |post| %>
  <%= render 'post', post: post %>
<% end %>

<!-- 短縮形（変数名がパーシャル名と同じ場合） -->
<%= render partial: 'post', locals: { post: @post } %>

<!-- コレクション -->
<%= render @posts %>
<!-- 各postに対してapp/views/posts/_post.html.erbをレンダリング -->

<%= render partial: 'post', collection: @posts %>
```

### オプション

```erb
<!-- 区切り -->
<%= render partial: 'post', collection: @posts, spacer_template: 'spacer' %>

<!-- as で変数名変更 -->
<%= render partial: 'item', collection: @posts, as: :post %>
<!-- パーシャル内で post 変数として利用 -->

<!-- レイアウト付き -->
<%= render layout: 'box' do %>
  <p>Content</p>
<% end %>
```

### 別ディレクトリのパーシャル

```erb
<!-- app/views/shared/_header.html.erb -->
<%= render 'shared/header' %>
<%= render partial: 'shared/header' %>
```

---

## レイアウト

全ページで共通のHTMLテンプレート。

### application.html.erb

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for?(:title) ? yield(:title) : 'MyApp' %></title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag 'application', 'data-turbo-track': 'reload' %>
    <%= javascript_include_tag 'application', 'data-turbo-track': 'reload' %>
  </head>

  <body>
    <%= render 'shared/header' %>

    <% if flash[:notice] %>
      <div class="alert alert-success"><%= flash[:notice] %></div>
    <% end %>

    <% if flash[:alert] %>
      <div class="alert alert-danger"><%= flash[:alert] %></div>
    <% end %>

    <%= yield %>

    <%= render 'shared/footer' %>
  </body>
</html>
```

### content_for

特定のセクションにコンテンツを挿入。

```erb
<!-- app/views/posts/show.html.erb -->
<% content_for :title do %>
  <%= @post.title %> | MyApp
<% end %>

<% content_for :meta_description do %>
  <%= @post.excerpt %>
<% end %>

<% content_for :sidebar do %>
  <div class="sidebar">関連記事</div>
<% end %>

<h1><%= @post.title %></h1>
<p><%= @post.body %></p>
```

```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <title><%= yield(:title) %></title>
  <meta name="description" content="<%= yield(:meta_description) %>">
</head>

<body>
  <main><%= yield %></main>
  <aside><%= yield(:sidebar) %></aside>
</body>
```

### カスタムレイアウト

```ruby
# app/controllers/admin/posts_controller.rb
class Admin::PostsController < ApplicationController
  layout 'admin'
end
```

```erb
<!-- app/views/layouts/admin.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title>Admin - MyApp</title>
  </head>
  <body class="admin">
    <%= yield %>
  </body>
</html>
```

---

## フォームヘルパー

### form_with

Rails 5.1以降の推奨フォームヘルパー。

#### モデルベース

```erb
<!-- app/views/posts/new.html.erb -->
<%= form_with model: @post do |f| %>
  <div class="field">
    <%= f.label :title %>
    <%= f.text_field :title, class: 'form-control' %>
  </div>

  <div class="field">
    <%= f.label :body %>
    <%= f.text_area :body, rows: 10, class: 'form-control' %>
  </div>

  <div class="field">
    <%= f.label :published %>
    <%= f.check_box :published %>
  </div>

  <div class="actions">
    <%= f.submit 'Save', class: 'btn btn-primary' %>
  </div>
<% end %>
```

生成されるHTML（新規作成時）:
```html
<form action="/posts" method="post">
  <input type="hidden" name="authenticity_token" value="...">
  <!-- フォームフィールド -->
</form>
```

生成されるHTML（更新時）:
```html
<form action="/posts/1" method="post">
  <input type="hidden" name="_method" value="patch">
  <input type="hidden" name="authenticity_token" value="...">
  <!-- フォームフィールド -->
</form>
```

#### URLベース

```erb
<%= form_with url: search_path, method: :get do |f| %>
  <%= f.text_field :query %>
  <%= f.submit 'Search' %>
<% end %>
```

### フォームフィールド

```erb
<%= form_with model: @user do |f| %>
  <!-- テキスト -->
  <%= f.text_field :name %>
  <%= f.email_field :email %>
  <%= f.password_field :password %>
  <%= f.tel_field :phone %>
  <%= f.url_field :website %>

  <!-- テキストエリア -->
  <%= f.text_area :bio, rows: 5 %>

  <!-- 数値 -->
  <%= f.number_field :age, in: 1..100 %>

  <!-- チェックボックス -->
  <%= f.check_box :agree %>

  <!-- ラジオボタン -->
  <%= f.radio_button :gender, 'male' %>
  <%= f.label :gender_male, 'Male' %>
  <%= f.radio_button :gender, 'female' %>
  <%= f.label :gender_female, 'Female' %>

  <!-- セレクトボックス -->
  <%= f.select :role, ['Admin', 'User', 'Guest'] %>
  <%= f.select :role, [['Admin', 'admin'], ['User', 'user']] %>
  <%= f.select :country_id, options_for_select(Country.all.map { |c| [c.name, c.id] }) %>

  <!-- collection_select -->
  <%= f.collection_select :category_id, Category.all, :id, :name %>

  <!-- 日付・時刻 -->
  <%= f.date_field :birthday %>
  <%= f.datetime_field :published_at %>
  <%= f.time_field :start_time %>

  <!-- ファイル -->
  <%= f.file_field :avatar %>

  <!-- 隠しフィールド -->
  <%= f.hidden_field :user_id, value: current_user.id %>

  <!-- 送信ボタン -->
  <%= f.submit %>
  <%= f.submit 'Save' %>
  <%= f.submit 'Create Post', class: 'btn btn-primary' %>
<% end %>
```

### エラー表示

```erb
<%= form_with model: @post do |f| %>
  <% if @post.errors.any? %>
    <div id="error_explanation">
      <h2><%= pluralize(@post.errors.count, "error") %> prohibited this post from being saved:</h2>
      <ul>
        <% @post.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="field">
    <%= f.label :title %>
    <%= f.text_field :title, class: @post.errors[:title].any? ? 'error' : '' %>
    <% if @post.errors[:title].any? %>
      <span class="error-message"><%= @post.errors[:title].first %></span>
    <% end %>
  </div>

  <%= f.submit %>
<% end %>
```

### ネストした属性

```erb
<%= form_with model: @post do |f| %>
  <%= f.text_field :title %>

  <%= f.fields_for :comments do |comment_form| %>
    <%= comment_form.text_area :body %>
    <%= comment_form.check_box :_destroy %>
    <%= comment_form.label :_destroy, 'Remove' %>
  <% end %>

  <%= f.submit %>
<% end %>
```

---

## Slim

簡潔なテンプレートエンジン。インデントでHTML構造を表現。

### インストール

```ruby
# Gemfile
gem 'slim-rails'
```

### 基本構文

```slim
/ コメント

doctype html
html
  head
    title My App
    = stylesheet_link_tag 'application'
    = javascript_include_tag 'application'

  body
    / 式の埋め込み
    h1 = @post.title
    p = @post.body

    / 属性
    a href=post_path(@post) class="link" = @post.title

    / ショートハンド
    a.btn.btn-primary href=root_path Home
    #main.container
      p Content

    / 条件分岐
    - if @user.admin?
      p 管理者
    - else
      p 一般ユーザー

    / ループ
    ul
      - @posts.each do |post|
        li = post.title

    / インライン HTML
    p
      | This is
      strong bold
      |  text.

    / ヘルパー
    = link_to 'Home', root_path, class: 'nav-link'
```

### フォーム

```slim
= form_with model: @post do |f|
  .field
    = f.label :title
    = f.text_field :title, class: 'form-control'

  .field
    = f.label :body
    = f.text_area :body, rows: 10

  .actions
    = f.submit 'Save', class: 'btn btn-primary'
```

---

## Haml

HTMLを簡潔に書けるテンプレートエンジン。

### インストール

```ruby
# Gemfile
gem 'haml-rails'
```

### 基本構文

```haml
-# コメント

!!!
%html
  %head
    %title My App
    = stylesheet_link_tag 'application'

  %body
    -# 式の埋め込み
    %h1= @post.title
    %p= @post.body

    -# 属性
    %a{href: post_path(@post), class: 'link'}= @post.title

    -# ショートハンド
    %a.btn.btn-primary{href: root_path} Home
    #main.container
      %p Content

    -# 条件分岐
    - if @user.admin?
      %p 管理者
    - else
      %p 一般ユーザー

    -# ループ
    %ul
      - @posts.each do |post|
        %li= post.title

    -# ヘルパー
    = link_to 'Home', root_path, class: 'nav-link'
```

---

## ベストプラクティス

### 1. ロジックはコントローラー/ヘルパーへ

```erb
<!-- ✗ ビューにロジック -->
<% if @user.role == 'admin' || @user.role == 'moderator' %>
  管理機能
<% end %>

<!-- ○ ヘルパーメソッド -->
<% if admin_or_moderator?(@user) %>
  管理機能
<% end %>
```

### 2. パーシャルで再利用

```erb
<!-- ○ パーシャル化 -->
<%= render @posts %>

<!-- ✗ 重複コード -->
<% @posts.each do |post| %>
  <div class="post">...</div>
<% end %>
```

### 3. HTMLエスケープ

```erb
<!-- ○ 自動エスケープ -->
<%= @post.body %>

<!-- ✗ XSSリスク -->
<%= raw @post.body %>
<%== @post.body %>
<%= @post.body.html_safe %>
```

---

## 参考リンク

- [Layouts and Rendering in Rails](https://guides.rubyonrails.org/layouts_and_rendering.html)
- [Railsガイド：レイアウトとレンダリング](https://railsguides.jp/layouts_and_rendering.html)
- [Slim](http://slim-lang.com/)
- [Haml](https://haml.info/)
