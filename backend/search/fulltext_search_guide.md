# 全文検索実装 完全ガイド

## 目次
1. [全文検索とは](#全文検索とは)
2. [PostgreSQL Full-text Search](#postgresql-full-text-search)
3. [MySQL Full-text Search](#mysql-full-text-search)
4. [Prisma統合](#prisma統合)
5. [検索スコアリング](#検索スコアリング)
6. [オートコンプリート](#オートコンプリート)
7. [ファセット検索](#ファセット検索)
8. [ベストプラクティス](#ベストプラクティス)

---

## 全文検索とは

全文検索は、大量のテキストデータから関連するドキュメントを高速に検索する技術です。

### 主な機能

- **キーワード検索**: 複数キーワードでの検索
- **部分一致**: 前方一致・部分一致・後方一致
- **ランキング**: 関連度によるスコアリング
- **ファジー検索**: タイポ許容

### 実装方法の比較

| 方法 | 利点 | 欠点 |
|------|------|------|
| PostgreSQL | 既存DBで実装可能 | 大規模データで性能低下 |
| MySQL | シンプルな実装 | 機能が限定的 |
| Elasticsearch | 高性能、機能豊富 | 別途インフラ必要 |

---

## PostgreSQL Full-text Search

### セットアップ

```sql
-- 拡張機能を有効化
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- テーブル作成
CREATE TABLE articles (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  author VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

-- 全文検索用のカラム追加
ALTER TABLE articles ADD COLUMN search_vector tsvector;

-- トリガーで自動更新
CREATE OR REPLACE FUNCTION articles_search_update() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.content, '')), 'B');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER articles_search_update_trigger
BEFORE INSERT OR UPDATE ON articles
FOR EACH ROW
EXECUTE FUNCTION articles_search_update();

-- インデックス作成
CREATE INDEX articles_search_idx ON articles USING GIN(search_vector);
```

### 基本的な検索

```sql
-- 単一キーワード
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'javascript');

-- 複数キーワード（AND）
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'javascript & typescript');

-- 複数キーワード（OR）
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'javascript | typescript');

-- NOT
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'javascript & !python');
```

### ランキング

```sql
SELECT
  id,
  title,
  ts_rank(search_vector, query) AS rank
FROM articles,
  to_tsquery('english', 'javascript') query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 10;
```

### Node.js統合

```typescript
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

interface SearchResult {
  id: number;
  title: string;
  content: string;
  rank: number;
}

async function searchArticles(query: string): Promise<SearchResult[]> {
  const result = await pool.query<SearchResult>(
    `
    SELECT
      id,
      title,
      content,
      ts_rank(search_vector, to_tsquery('english', $1)) AS rank
    FROM articles
    WHERE search_vector @@ to_tsquery('english', $1)
    ORDER BY rank DESC
    LIMIT 20
    `,
    [query.trim().split(/\s+/).join(' & ')]
  );

  return result.rows;
}

// 使用例
const results = await searchArticles('javascript react');
console.log(results);
```

### ハイライト

```sql
SELECT
  id,
  title,
  ts_headline('english', content, query, 'MaxWords=50, MinWords=25') AS snippet
FROM articles,
  to_tsquery('english', 'javascript') query
WHERE search_vector @@ query;
```

---

## MySQL Full-text Search

### セットアップ

```sql
-- テーブル作成
CREATE TABLE articles (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  author VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FULLTEXT INDEX ft_search (title, content)
) ENGINE=InnoDB;
```

### 自然言語検索

```sql
SELECT
  id,
  title,
  MATCH(title, content) AGAINST('javascript' IN NATURAL LANGUAGE MODE) AS score
FROM articles
WHERE MATCH(title, content) AGAINST('javascript' IN NATURAL LANGUAGE MODE)
ORDER BY score DESC
LIMIT 10;
```

### Boolean検索

```sql
-- AND
SELECT * FROM articles
WHERE MATCH(title, content) AGAINST('+javascript +react' IN BOOLEAN MODE);

-- OR
SELECT * FROM articles
WHERE MATCH(title, content) AGAINST('javascript react' IN BOOLEAN MODE);

-- NOT
SELECT * FROM articles
WHERE MATCH(title, content) AGAINST('+javascript -python' IN BOOLEAN MODE);

-- ワイルドカード
SELECT * FROM articles
WHERE MATCH(title, content) AGAINST('java*' IN BOOLEAN MODE);
```

### Node.js統合

```typescript
import mysql from 'mysql2/promise';

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

async function searchArticles(query: string) {
  const [rows] = await pool.query(
    `
    SELECT
      id,
      title,
      content,
      MATCH(title, content) AGAINST(? IN NATURAL LANGUAGE MODE) AS score
    FROM articles
    WHERE MATCH(title, content) AGAINST(? IN NATURAL LANGUAGE MODE)
    ORDER BY score DESC
    LIMIT 20
    `,
    [query, query]
  );

  return rows;
}
```

---

## Prisma統合

### スキーマ定義

```prisma
model Article {
  id        Int      @id @default(autoincrement())
  title     String
  content   String   @db.Text
  author    String?
  createdAt DateTime @default(now())

  @@index([title, content], type: Fulltext)
}
```

### Raw Query

```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// PostgreSQL
async function searchArticlesPostgres(query: string) {
  return await prisma.$queryRaw`
    SELECT
      id,
      title,
      content,
      ts_rank(search_vector, to_tsquery('english', ${query})) AS rank
    FROM articles
    WHERE search_vector @@ to_tsquery('english', ${query})
    ORDER BY rank DESC
    LIMIT 20
  `;
}

// MySQL
async function searchArticlesMySQL(query: string) {
  return await prisma.$queryRaw`
    SELECT
      id,
      title,
      content,
      MATCH(title, content) AGAINST(${query} IN NATURAL LANGUAGE MODE) AS score
    FROM articles
    WHERE MATCH(title, content) AGAINST(${query} IN NATURAL LANGUAGE MODE)
    ORDER BY score DESC
    LIMIT 20
  `;
}
```

---

## 検索スコアリング

### 重み付け

```sql
-- PostgreSQL: タイトルを重視
SELECT
  id,
  title,
  ts_rank_cd(
    setweight(to_tsvector('english', title), 'A') ||
    setweight(to_tsvector('english', content), 'B'),
    query,
    32 /* タイトルの重み */
  ) AS rank
FROM articles,
  to_tsquery('english', 'javascript') query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

### カスタムランキング

```typescript
interface ArticleWithScore {
  id: number;
  title: string;
  content: string;
  score: number;
}

function calculateCustomScore(
  article: ArticleWithScore,
  query: string
): number {
  let score = article.score;

  // タイトルに完全一致
  if (article.title.toLowerCase().includes(query.toLowerCase())) {
    score *= 2;
  }

  // 最近の記事を優遇
  const daysOld = 30;
  const recencyBoost = Math.max(0, 1 - daysOld / 365);
  score *= 1 + recencyBoost;

  return score;
}

async function searchWithCustomScoring(query: string) {
  const results = await searchArticles(query);

  return results
    .map((article) => ({
      ...article,
      customScore: calculateCustomScore(article, query),
    }))
    .sort((a, b) => b.customScore - a.customScore);
}
```

---

## オートコンプリート

### Trigram検索（PostgreSQL）

```sql
-- トライグラムインデックス
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX articles_title_trgm_idx ON articles
USING gin (title gin_trgm_ops);

-- オートコンプリート
SELECT title
FROM articles
WHERE title ILIKE $1 || '%'
ORDER BY similarity(title, $1) DESC
LIMIT 10;
```

### Node.js実装

```typescript
async function autocomplete(prefix: string): Promise<string[]> {
  const result = await pool.query<{ title: string }>(
    `
    SELECT DISTINCT title
    FROM articles
    WHERE title ILIKE $1
    ORDER BY similarity(title, $2) DESC
    LIMIT 10
    `,
    [`${prefix}%`, prefix]
  );

  return result.rows.map((row) => row.title);
}

// Express統合
app.get('/api/autocomplete', async (req, res) => {
  const { q } = req.query;

  if (!q || typeof q !== 'string' || q.length < 2) {
    return res.json([]);
  }

  const suggestions = await autocomplete(q);
  res.json(suggestions);
});
```

### デバウンス実装（フロントエンド）

```typescript
import { useState, useEffect } from 'react';

function useAutocomplete(query: string, delay = 300) {
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (query.length < 2) {
      setSuggestions([]);
      return;
    }

    const timer = setTimeout(async () => {
      setLoading(true);

      try {
        const response = await fetch(`/api/autocomplete?q=${encodeURIComponent(query)}`);
        const data = await response.json();
        setSuggestions(data);
      } catch (error) {
        console.error('Autocomplete error:', error);
      } finally {
        setLoading(false);
      }
    }, delay);

    return () => clearTimeout(timer);
  }, [query, delay]);

  return { suggestions, loading };
}

// 使用例
export function SearchInput() {
  const [query, setQuery] = useState('');
  const { suggestions, loading } = useAutocomplete(query);

  return (
    <div>
      <input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="検索..."
      />
      {loading && <div>読み込み中...</div>}
      {suggestions.length > 0 && (
        <ul>
          {suggestions.map((suggestion, index) => (
            <li key={index}>{suggestion}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

---

## ファセット検索

### カテゴリ別フィルター

```typescript
interface SearchFilters {
  category?: string;
  author?: string;
  dateFrom?: Date;
  dateTo?: Date;
}

async function searchWithFilters(query: string, filters: SearchFilters) {
  let sql = `
    SELECT
      id,
      title,
      content,
      category,
      author,
      created_at,
      ts_rank(search_vector, to_tsquery('english', $1)) AS rank
    FROM articles
    WHERE search_vector @@ to_tsquery('english', $1)
  `;

  const params: any[] = [query];
  let paramIndex = 2;

  if (filters.category) {
    sql += ` AND category = $${paramIndex}`;
    params.push(filters.category);
    paramIndex++;
  }

  if (filters.author) {
    sql += ` AND author = $${paramIndex}`;
    params.push(filters.author);
    paramIndex++;
  }

  if (filters.dateFrom) {
    sql += ` AND created_at >= $${paramIndex}`;
    params.push(filters.dateFrom);
    paramIndex++;
  }

  if (filters.dateTo) {
    sql += ` AND created_at <= $${paramIndex}`;
    params.push(filters.dateTo);
    paramIndex++;
  }

  sql += ' ORDER BY rank DESC LIMIT 20';

  const result = await pool.query(sql, params);
  return result.rows;
}
```

### ファセットカウント

```typescript
async function getFacets(query: string) {
  const categoriesResult = await pool.query(
    `
    SELECT category, COUNT(*) as count
    FROM articles
    WHERE search_vector @@ to_tsquery('english', $1)
    GROUP BY category
    ORDER BY count DESC
    `,
    [query]
  );

  const authorsResult = await pool.query(
    `
    SELECT author, COUNT(*) as count
    FROM articles
    WHERE search_vector @@ to_tsquery('english', $1)
    GROUP BY author
    ORDER BY count DESC
    LIMIT 10
    `,
    [query]
  );

  return {
    categories: categoriesResult.rows,
    authors: authorsResult.rows,
  };
}

// Express統合
app.get('/api/search/facets', async (req, res) => {
  const { q } = req.query;

  const facets = await getFacets(q as string);
  res.json(facets);
});
```

---

## ベストプラクティス

### 1. Express全文検索API

```typescript
import express from 'express';
import { z } from 'zod';

const app = express();

const searchSchema = z.object({
  q: z.string().min(1),
  category: z.string().optional(),
  author: z.string().optional(),
  page: z.string().default('1'),
  size: z.string().default('20'),
});

app.get('/api/search', async (req, res) => {
  try {
    const validated = searchSchema.parse(req.query);
    const page = parseInt(validated.page);
    const size = parseInt(validated.size);
    const offset = (page - 1) * size;

    const results = await pool.query(
      `
      SELECT
        id,
        title,
        content,
        category,
        author,
        ts_rank(search_vector, to_tsquery('english', $1)) AS rank,
        ts_headline('english', content, to_tsquery('english', $1)) AS snippet
      FROM articles
      WHERE search_vector @@ to_tsquery('english', $1)
        ${validated.category ? 'AND category = $2' : ''}
        ${validated.author ? 'AND author = $3' : ''}
      ORDER BY rank DESC
      LIMIT $${validated.category ? 4 : 2}
      OFFSET $${validated.category ? 5 : 3}
      `,
      [
        validated.q.trim().split(/\s+/).join(' & '),
        ...(validated.category ? [validated.category] : []),
        ...(validated.author ? [validated.author] : []),
        size,
        offset,
      ]
    );

    const total = await pool.query(
      `
      SELECT COUNT(*) FROM articles
      WHERE search_vector @@ to_tsquery('english', $1)
      `,
      [validated.q.trim().split(/\s+/).join(' & ')]
    );

    res.json({
      results: results.rows,
      total: parseInt(total.rows[0].count),
      page,
      size,
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Search failed' });
  }
});
```

### 2. キャッシング

```typescript
import Redis from 'ioredis';

const redis = new Redis();

async function cachedSearch(query: string) {
  const cacheKey = `search:${query}`;

  // キャッシュチェック
  const cached = await redis.get(cacheKey);
  if (cached) {
    return JSON.parse(cached);
  }

  // 検索実行
  const results = await searchArticles(query);

  // キャッシュ保存（5分）
  await redis.setex(cacheKey, 300, JSON.stringify(results));

  return results;
}
```

### 3. 検索ログ

```typescript
interface SearchLog {
  query: string;
  resultsCount: number;
  executionTime: number;
  userId?: string;
  timestamp: Date;
}

async function logSearch(log: SearchLog) {
  await prisma.searchLog.create({
    data: log,
  });
}

// ミドルウェア
app.use('/api/search', async (req, res, next) => {
  const start = Date.now();

  res.on('finish', async () => {
    const executionTime = Date.now() - start;

    await logSearch({
      query: req.query.q as string,
      resultsCount: res.locals.resultsCount || 0,
      executionTime,
      userId: req.user?.id,
      timestamp: new Date(),
    });
  });

  next();
});
```

### 4. 人気検索ワード

```typescript
async function getPopularSearches(limit = 10) {
  const result = await prisma.$queryRaw`
    SELECT query, COUNT(*) as count
    FROM search_logs
    WHERE timestamp > NOW() - INTERVAL '7 days'
    GROUP BY query
    ORDER BY count DESC
    LIMIT ${limit}
  `;

  return result;
}

app.get('/api/search/popular', async (req, res) => {
  const popular = await getPopularSearches();
  res.json(popular);
});
```

### 5. 検索パフォーマンス最適化

```typescript
// インデックスの最適化
async function optimizeSearchIndex() {
  // VACUUM ANALYZE
  await pool.query('VACUUM ANALYZE articles');

  // インデックス再構築
  await pool.query('REINDEX INDEX articles_search_idx');
}

// 定期実行（週1回）
import cron from 'node-cron';

cron.schedule('0 2 * * 0', async () => {
  console.log('Optimizing search index...');
  await optimizeSearchIndex();
});
```

---

## 参考リンク

- [PostgreSQL Full Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [MySQL Full-Text Search](https://dev.mysql.com/doc/refman/8.0/en/fulltext-search.html)
- [pg_trgm Extension](https://www.postgresql.org/docs/current/pgtrgm.html)
