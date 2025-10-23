# PostgreSQL ガイド

PostgreSQLは、高機能なオープンソースのリレーショナルデータベース管理システムです。

## 特徴

- **ACID準拠**: トランザクションの信頼性が高い
- **拡張性**: カスタム関数、データ型の定義が可能
- **高機能**: JSON、配列、全文検索などをサポート
- **パフォーマンス**: 大規模データの処理に優れる
- **オープンソース**: 無料で商用利用可能

## インストール

### macOS

```bash
# Homebrew
brew install postgresql@15
brew services start postgresql@15

# または
brew install --cask postgres
```

### Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib

# サービスの起動
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Docker

```bash
docker run --name postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  -d postgres:15
```

## 基本操作

### psqlへの接続

```bash
# ローカルのデフォルトユーザーで接続
psql

# 特定のデータベースに接続
psql -d mydb

# ユーザー指定で接続
psql -U username -d mydb

# リモートホストに接続
psql -h localhost -p 5432 -U username -d mydb
```

### psql基本コマンド

```sql
-- データベース一覧
\l

-- データベースに接続
\c mydb

-- テーブル一覧
\dt

-- テーブル構造を表示
\d users

-- スキーマ一覧
\dn

-- ユーザー一覧
\du

-- SQL履歴
\s

-- ヘルプ
\?

-- 終了
\q
```

## データベース操作

### データベースの作成・削除

```sql
-- データベース作成
CREATE DATABASE mydb;

-- 所有者を指定して作成
CREATE DATABASE mydb OWNER username;

-- エンコーディングを指定
CREATE DATABASE mydb
  ENCODING 'UTF8'
  LC_COLLATE 'ja_JP.UTF-8'
  LC_CTYPE 'ja_JP.UTF-8'
  TEMPLATE template0;

-- データベース削除
DROP DATABASE mydb;
```

### ユーザー管理

```sql
-- ユーザー作成
CREATE USER username WITH PASSWORD 'password';

-- ロール作成（ログイン権限あり）
CREATE ROLE username WITH LOGIN PASSWORD 'password';

-- 権限付与
GRANT ALL PRIVILEGES ON DATABASE mydb TO username;

-- 特定のテーブルへの権限
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO username;

-- スキーマへの権限
GRANT ALL ON SCHEMA public TO username;

-- ユーザー削除
DROP USER username;

-- パスワード変更
ALTER USER username WITH PASSWORD 'newpassword';
```

## テーブル操作

### テーブル作成

```sql
-- 基本的なテーブル作成
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  age INTEGER,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 外部キー制約
CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT,
  user_id INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 複合主キー
CREATE TABLE user_roles (
  user_id INTEGER,
  role_id INTEGER,
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (role_id) REFERENCES roles(id)
);

-- CHECK制約
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  price DECIMAL(10, 2) CHECK (price > 0),
  stock INTEGER CHECK (stock >= 0)
);
```

### テーブル変更

```sql
-- カラム追加
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- カラム削除
ALTER TABLE users DROP COLUMN phone;

-- カラム名変更
ALTER TABLE users RENAME COLUMN name TO full_name;

-- カラム型変更
ALTER TABLE users ALTER COLUMN age TYPE SMALLINT;

-- NOT NULL制約追加
ALTER TABLE users ALTER COLUMN email SET NOT NULL;

-- NOT NULL制約削除
ALTER TABLE users ALTER COLUMN age DROP NOT NULL;

-- デフォルト値設定
ALTER TABLE users ALTER COLUMN is_active SET DEFAULT true;

-- テーブル名変更
ALTER TABLE users RENAME TO members;
```

### テーブル削除

```sql
-- テーブル削除
DROP TABLE users;

-- 存在する場合のみ削除
DROP TABLE IF EXISTS users;

-- 関連テーブルも削除
DROP TABLE users CASCADE;
```

## データ型

### 数値型

```sql
-- 整数
SMALLINT        -- 2バイト (-32768 ~ 32767)
INTEGER / INT   -- 4バイト (-2147483648 ~ 2147483647)
BIGINT          -- 8バイト
SERIAL          -- 自動インクリメント整数
BIGSERIAL       -- 自動インクリメント大整数

-- 浮動小数点
REAL            -- 4バイト
DOUBLE PRECISION -- 8バイト
NUMERIC(p, s)   -- 任意精度（p: 全体桁数, s: 小数点以下桁数）
DECIMAL(p, s)   -- NUMERICと同じ
```

### 文字列型

```sql
VARCHAR(n)      -- 可変長（最大n文字）
CHAR(n)         -- 固定長（n文字）
TEXT            -- 無制限の可変長
```

### 日付・時刻型

```sql
DATE            -- 日付のみ
TIME            -- 時刻のみ
TIMESTAMP       -- 日時
TIMESTAMPTZ     -- タイムゾーン付き日時
INTERVAL        -- 時間間隔
```

### 論理型

```sql
BOOLEAN         -- true, false, null
```

### JSON型

```sql
JSON            -- JSONテキスト
JSONB           -- バイナリJSON（推奨）
```

### 配列型

```sql
INTEGER[]       -- 整数配列
TEXT[]          -- 文字列配列
```

### その他

```sql
UUID            -- UUID
BYTEA           -- バイナリデータ
INET            -- IPアドレス
MACADDR         -- MACアドレス
```

## CRUD操作

### INSERT（挿入）

```sql
-- 単一行挿入
INSERT INTO users (email, name, age)
VALUES ('user@example.com', 'John Doe', 30);

-- 複数行挿入
INSERT INTO users (email, name, age)
VALUES
  ('user1@example.com', 'Alice', 25),
  ('user2@example.com', 'Bob', 28),
  ('user3@example.com', 'Carol', 32);

-- 挿入して値を返す
INSERT INTO users (email, name, age)
VALUES ('user@example.com', 'John', 30)
RETURNING id, email;

-- サブクエリから挿入
INSERT INTO archived_users
SELECT * FROM users WHERE created_at < '2020-01-01';

-- 重複時は何もしない
INSERT INTO users (email, name)
VALUES ('user@example.com', 'John')
ON CONFLICT (email) DO NOTHING;

-- 重複時は更新
INSERT INTO users (email, name, age)
VALUES ('user@example.com', 'John', 30)
ON CONFLICT (email)
DO UPDATE SET
  name = EXCLUDED.name,
  age = EXCLUDED.age,
  updated_at = CURRENT_TIMESTAMP;
```

### SELECT（選択）

```sql
-- 全件取得
SELECT * FROM users;

-- 特定カラムのみ
SELECT id, email, name FROM users;

-- WHERE条件
SELECT * FROM users WHERE age >= 18;

-- 複数条件（AND）
SELECT * FROM users WHERE age >= 18 AND is_active = true;

-- 複数条件（OR）
SELECT * FROM users WHERE age < 18 OR age > 60;

-- IN句
SELECT * FROM users WHERE id IN (1, 2, 3);

-- LIKE（部分一致）
SELECT * FROM users WHERE email LIKE '%@gmail.com';

-- BETWEEN
SELECT * FROM users WHERE age BETWEEN 20 AND 30;

-- IS NULL / IS NOT NULL
SELECT * FROM users WHERE phone IS NULL;

-- ORDER BY（並び替え）
SELECT * FROM users ORDER BY created_at DESC;

-- 複数カラムでソート
SELECT * FROM users ORDER BY age DESC, name ASC;

-- LIMIT / OFFSET（ページネーション）
SELECT * FROM users ORDER BY id LIMIT 10 OFFSET 20;

-- DISTINCT（重複除外）
SELECT DISTINCT age FROM users;

-- COUNT（件数）
SELECT COUNT(*) FROM users;
SELECT COUNT(DISTINCT age) FROM users;

-- GROUP BY（集計）
SELECT age, COUNT(*) as count
FROM users
GROUP BY age
ORDER BY count DESC;

-- HAVING（集計結果の絞り込み）
SELECT age, COUNT(*) as count
FROM users
GROUP BY age
HAVING COUNT(*) > 5;
```

### UPDATE（更新）

```sql
-- 単一カラム更新
UPDATE users SET age = 31 WHERE id = 1;

-- 複数カラム更新
UPDATE users
SET
  name = 'John Smith',
  age = 31,
  updated_at = CURRENT_TIMESTAMP
WHERE id = 1;

-- 全件更新
UPDATE users SET is_active = true;

-- 計算して更新
UPDATE products SET price = price * 1.1;

-- サブクエリで更新
UPDATE users
SET email = (SELECT email FROM temp_users WHERE temp_users.id = users.id)
WHERE id IN (SELECT id FROM temp_users);

-- 更新して値を返す
UPDATE users
SET age = 31
WHERE id = 1
RETURNING *;
```

### DELETE（削除）

```sql
-- 条件付き削除
DELETE FROM users WHERE id = 1;

-- 複数条件
DELETE FROM users WHERE age < 18 AND is_active = false;

-- 全件削除
DELETE FROM users;

-- サブクエリで削除
DELETE FROM users
WHERE id IN (SELECT user_id FROM inactive_users);

-- 削除して値を返す
DELETE FROM users WHERE id = 1 RETURNING *;
```

## JOIN（結合）

```sql
-- INNER JOIN（内部結合）
SELECT users.name, posts.title
FROM users
INNER JOIN posts ON users.id = posts.user_id;

-- LEFT JOIN（左外部結合）
SELECT users.name, posts.title
FROM users
LEFT JOIN posts ON users.id = posts.user_id;

-- RIGHT JOIN（右外部結合）
SELECT users.name, posts.title
FROM users
RIGHT JOIN posts ON users.id = posts.user_id;

-- FULL OUTER JOIN（完全外部結合）
SELECT users.name, posts.title
FROM users
FULL OUTER JOIN posts ON users.id = posts.user_id;

-- 複数テーブルの結合
SELECT
  users.name,
  posts.title,
  comments.content
FROM users
INNER JOIN posts ON users.id = posts.user_id
INNER JOIN comments ON posts.id = comments.post_id;

-- エイリアス使用
SELECT
  u.name,
  p.title,
  COUNT(c.id) as comment_count
FROM users u
INNER JOIN posts p ON u.id = p.user_id
LEFT JOIN comments c ON p.id = c.post_id
GROUP BY u.id, u.name, p.id, p.title;
```

## インデックス

### インデックス作成

```sql
-- 単一カラムのインデックス
CREATE INDEX idx_users_email ON users(email);

-- 複合インデックス
CREATE INDEX idx_users_name_age ON users(name, age);

-- ユニークインデックス
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);

-- 部分インデックス
CREATE INDEX idx_active_users ON users(email)
WHERE is_active = true;

-- 式インデックス
CREATE INDEX idx_users_lower_email ON users(LOWER(email));

-- B-treeインデックス（デフォルト）
CREATE INDEX idx_users_age ON users USING btree(age);

-- GINインデックス（JSON、配列用）
CREATE INDEX idx_users_tags ON users USING gin(tags);

-- GiSTインデックス（地理空間データ用）
CREATE INDEX idx_locations ON locations USING gist(coordinates);
```

### インデックス削除

```sql
DROP INDEX idx_users_email;
```

### インデックスの確認

```sql
-- テーブルのインデックス一覧
SELECT * FROM pg_indexes WHERE tablename = 'users';

-- インデックスのサイズ
SELECT
  indexname,
  pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_indexes
WHERE tablename = 'users';
```

## トランザクション

```sql
-- トランザクション開始
BEGIN;

-- 処理
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;

-- コミット
COMMIT;

-- ロールバック
ROLLBACK;

-- セーブポイント
BEGIN;
UPDATE users SET name = 'Alice' WHERE id = 1;
SAVEPOINT sp1;
UPDATE users SET name = 'Bob' WHERE id = 2;
ROLLBACK TO sp1; -- sp1までロールバック
COMMIT;
```

## ビュー

```sql
-- ビュー作成
CREATE VIEW active_users AS
SELECT id, email, name
FROM users
WHERE is_active = true;

-- ビューの使用
SELECT * FROM active_users;

-- ビュー削除
DROP VIEW active_users;

-- マテリアライズドビュー（結果をキャッシュ）
CREATE MATERIALIZED VIEW user_stats AS
SELECT
  DATE(created_at) as date,
  COUNT(*) as count
FROM users
GROUP BY DATE(created_at);

-- マテリアライズドビューの更新
REFRESH MATERIALIZED VIEW user_stats;
```

## 関数

### 集計関数

```sql
SELECT
  COUNT(*) as total,
  AVG(age) as average_age,
  MIN(age) as min_age,
  MAX(age) as max_age,
  SUM(age) as sum_age
FROM users;
```

### 文字列関数

```sql
-- 連結
SELECT CONCAT(first_name, ' ', last_name) FROM users;
SELECT first_name || ' ' || last_name FROM users;

-- 大文字・小文字変換
SELECT UPPER(name), LOWER(email) FROM users;

-- 文字列長
SELECT LENGTH(name) FROM users;

-- 部分文字列
SELECT SUBSTRING(email FROM 1 FOR 5) FROM users;

-- 置換
SELECT REPLACE(email, '@gmail.com', '@example.com') FROM users;

-- トリム
SELECT TRIM(name) FROM users;
```

### 日付関数

```sql
-- 現在日時
SELECT NOW();
SELECT CURRENT_TIMESTAMP;
SELECT CURRENT_DATE;
SELECT CURRENT_TIME;

-- 日付演算
SELECT NOW() + INTERVAL '1 day';
SELECT NOW() - INTERVAL '1 week';
SELECT NOW() + INTERVAL '1 month';

-- 日付の抽出
SELECT EXTRACT(YEAR FROM created_at) FROM users;
SELECT EXTRACT(MONTH FROM created_at) FROM users;
SELECT DATE_PART('year', created_at) FROM users;

-- 日付フォーマット
SELECT TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') FROM users;

-- 年齢計算
SELECT AGE(birth_date) FROM users;
```

### 条件式

```sql
-- CASE
SELECT
  name,
  CASE
    WHEN age < 18 THEN '未成年'
    WHEN age >= 18 AND age < 65 THEN '成人'
    ELSE '高齢者'
  END as age_group
FROM users;

-- COALESCE（最初のNULL以外の値）
SELECT COALESCE(phone, email, 'No contact') FROM users;

-- NULLIF（同じ場合はNULL）
SELECT NULLIF(status, 'deleted') FROM posts;
```

## JSON操作

```sql
-- JSONBカラム作成
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  metadata JSONB
);

-- JSON挿入
INSERT INTO products (name, metadata)
VALUES (
  'Product 1',
  '{"color": "red", "size": "L", "tags": ["new", "sale"]}'
);

-- JSON取得
SELECT metadata->>'color' as color FROM products;
SELECT metadata->'tags' as tags FROM products;

-- JSON配列の要素
SELECT metadata->'tags'->0 as first_tag FROM products;

-- JSONパス
SELECT metadata #> '{tags, 0}' FROM products;

-- JSON検索
SELECT * FROM products WHERE metadata->>'color' = 'red';
SELECT * FROM products WHERE metadata @> '{"color": "red"}';

-- JSON配列に含まれる
SELECT * FROM products WHERE metadata->'tags' @> '["new"]';

-- JSON更新
UPDATE products
SET metadata = metadata || '{"stock": 100}'
WHERE id = 1;

-- JSONキー削除
UPDATE products
SET metadata = metadata - 'color'
WHERE id = 1;
```

## フルテキスト検索

```sql
-- tsVectorカラム作成
ALTER TABLE posts ADD COLUMN search_vector tsvector;

-- 検索ベクトル生成
UPDATE posts
SET search_vector =
  to_tsvector('english', title) ||
  to_tsvector('english', content);

-- インデックス作成
CREATE INDEX idx_posts_search ON posts USING gin(search_vector);

-- 検索
SELECT * FROM posts
WHERE search_vector @@ to_tsquery('english', 'postgresql & database');

-- ランキング付き検索
SELECT
  title,
  ts_rank(search_vector, query) as rank
FROM posts,
  to_tsquery('english', 'postgresql') query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

## パフォーマンスチューニング

### EXPLAIN（実行計画）

```sql
-- 実行計画を表示
EXPLAIN SELECT * FROM users WHERE age > 30;

-- 実際に実行して表示
EXPLAIN ANALYZE SELECT * FROM users WHERE age > 30;

-- 詳細表示
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM users WHERE age > 30;
```

### VACUUM（メンテナンス）

```sql
-- テーブルのメンテナンス
VACUUM users;

-- 完全VACUUM
VACUUM FULL users;

-- 統計情報更新
ANALYZE users;

-- VACUUMと統計情報更新
VACUUM ANALYZE users;

-- 自動VACUUM設定確認
SHOW autovacuum;
```

### インデックスの最適化

```sql
-- 使われていないインデックスを確認
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY schemaname, tablename;

-- インデックスの再構築
REINDEX TABLE users;
REINDEX INDEX idx_users_email;
```

## バックアップとリストア

### pg_dump（バックアップ）

```bash
# データベース全体をバックアップ
pg_dump mydb > backup.sql

# 圧縮バックアップ
pg_dump mydb | gzip > backup.sql.gz

# カスタム形式（並列リストア可能）
pg_dump -Fc mydb > backup.dump

# 特定テーブルのみ
pg_dump -t users mydb > users_backup.sql

# スキーマのみ
pg_dump --schema-only mydb > schema.sql

# データのみ
pg_dump --data-only mydb > data.sql
```

### リストア

```bash
# SQLファイルからリストア
psql mydb < backup.sql

# 圧縮ファイルからリストア
gunzip -c backup.sql.gz | psql mydb

# カスタム形式からリストア
pg_restore -d mydb backup.dump

# 並列リストア
pg_restore -j 4 -d mydb backup.dump
```

## 接続情報

### 環境変数

```bash
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=mydb
export PGUSER=username
export PGPASSWORD=password
```

### 接続URL

```bash
postgresql://username:password@localhost:5432/mydb
```

## Node.jsからの接続

### pg（PostgreSQLクライアント）

```bash
npm install pg
```

```typescript
import { Pool } from 'pg'

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'mydb',
  user: 'username',
  password: 'password',
  max: 20, // 最大接続数
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
})

// クエリ実行
async function getUsers() {
  const result = await pool.query('SELECT * FROM users')
  return result.rows
}

// パラメータ付きクエリ
async function getUserById(id: number) {
  const result = await pool.query(
    'SELECT * FROM users WHERE id = $1',
    [id]
  )
  return result.rows[0]
}

// トランザクション
async function transferMoney(fromId: number, toId: number, amount: number) {
  const client = await pool.connect()
  try {
    await client.query('BEGIN')
    await client.query(
      'UPDATE accounts SET balance = balance - $1 WHERE id = $2',
      [amount, fromId]
    )
    await client.query(
      'UPDATE accounts SET balance = balance + $1 WHERE id = $2',
      [amount, toId]
    )
    await client.query('COMMIT')
  } catch (error) {
    await client.query('ROLLBACK')
    throw error
  } finally {
    client.release()
  }
}
```

## ベストプラクティス

1. **プリペアドステートメントを使用**: SQLインジェクション対策
2. **適切なインデックス作成**: 頻繁に検索するカラムにインデックス
3. **接続プールを使用**: 接続のオーバーヘッド削減
4. **トランザクションを適切に使用**: データ整合性の保証
5. **定期的なVACUUM**: パフォーマンス維持
6. **EXPLAINで実行計画確認**: クエリの最適化
7. **適切なデータ型選択**: ストレージ効率化
8. **バックアップを定期的に実行**: データ損失対策

## 参考リンク

- [PostgreSQL 公式ドキュメント](https://www.postgresql.org/docs/)
- [PostgreSQL Tutorial](https://www.postgresqltutorial.com/)
- [node-postgres Documentation](https://node-postgres.com/)
- [Prisma with PostgreSQL](https://www.prisma.io/docs/concepts/database-connectors/postgresql)
