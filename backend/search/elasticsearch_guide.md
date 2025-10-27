# Elasticsearch 完全ガイド

## 目次
1. [Elasticsearchとは](#elasticsearchとは)
2. [セットアップ](#セットアップ)
3. [インデックス管理](#インデックス管理)
4. [ドキュメント操作](#ドキュメント操作)
5. [検索クエリ](#検索クエリ)
6. [集計（Aggregations）](#集計aggregations)
7. [フルテキスト検索](#フルテキスト検索)
8. [ベストプラクティス](#ベストプラクティス)

---

## Elasticsearchとは

Elasticsearchは分散型のRESTful検索・分析エンジンです。

### 主な特徴

- **フルテキスト検索**: 高速な全文検索
- **リアルタイム**: ほぼリアルタイムでの検索
- **スケーラブル**: 水平スケーリング対応
- **RESTful API**: 簡単な統合

---

## セットアップ

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - es_data:/usr/share/elasticsearch/data

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  es_data:
```

### Node.js クライアント

```bash
npm install @elastic/elasticsearch
```

```typescript
import { Client } from '@elastic/elasticsearch';

const client = new Client({
  node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
  auth: {
    username: process.env.ELASTICSEARCH_USERNAME || 'elastic',
    password: process.env.ELASTICSEARCH_PASSWORD || 'changeme',
  },
});

// 接続確認
const info = await client.info();
console.log('Elasticsearch version:', info.version.number);
```

---

## インデックス管理

### インデックス作成

```typescript
await client.indices.create({
  index: 'products',
  body: {
    settings: {
      number_of_shards: 1,
      number_of_replicas: 0,
      analysis: {
        analyzer: {
          japanese_analyzer: {
            type: 'custom',
            tokenizer: 'kuromoji_tokenizer',
            filter: ['kuromoji_baseform', 'ja_stop', 'cjk_width'],
          },
        },
      },
    },
    mappings: {
      properties: {
        name: {
          type: 'text',
          analyzer: 'japanese_analyzer',
        },
        description: {
          type: 'text',
          analyzer: 'japanese_analyzer',
        },
        price: {
          type: 'integer',
        },
        category: {
          type: 'keyword',
        },
        tags: {
          type: 'keyword',
        },
        createdAt: {
          type: 'date',
        },
      },
    },
  },
});
```

### インデックス削除

```typescript
await client.indices.delete({
  index: 'products',
});
```

### マッピング更新

```typescript
await client.indices.putMapping({
  index: 'products',
  body: {
    properties: {
      rating: {
        type: 'float',
      },
      inStock: {
        type: 'boolean',
      },
    },
  },
});
```

### テンプレート作成

```typescript
await client.indices.putIndexTemplate({
  name: 'logs_template',
  body: {
    index_patterns: ['logs-*'],
    template: {
      settings: {
        number_of_shards: 1,
      },
      mappings: {
        properties: {
          timestamp: { type: 'date' },
          level: { type: 'keyword' },
          message: { type: 'text' },
        },
      },
    },
  },
});
```

---

## ドキュメント操作

### ドキュメント追加

```typescript
// 単一ドキュメント
await client.index({
  index: 'products',
  id: '1',
  body: {
    name: 'ワイヤレスマウス',
    description: '高性能なワイヤレスマウス',
    price: 3000,
    category: 'electronics',
    tags: ['wireless', 'mouse', 'computer'],
    createdAt: new Date(),
  },
});

// ドキュメントIDを自動生成
await client.index({
  index: 'products',
  body: {
    name: 'キーボード',
    price: 5000,
  },
});
```

### バルク操作

```typescript
const body = [
  { index: { _index: 'products', _id: '1' } },
  {
    name: 'ワイヤレスマウス',
    price: 3000,
    category: 'electronics',
  },
  { index: { _index: 'products', _id: '2' } },
  {
    name: 'キーボード',
    price: 5000,
    category: 'electronics',
  },
  { index: { _index: 'products', _id: '3' } },
  {
    name: 'モニター',
    price: 20000,
    category: 'electronics',
  },
];

await client.bulk({ body });
```

### ドキュメント取得

```typescript
const result = await client.get({
  index: 'products',
  id: '1',
});

console.log(result._source);
```

### ドキュメント更新

```typescript
// 部分更新
await client.update({
  index: 'products',
  id: '1',
  body: {
    doc: {
      price: 2500,
      inStock: true,
    },
  },
});

// スクリプトによる更新
await client.update({
  index: 'products',
  id: '1',
  body: {
    script: {
      source: 'ctx._source.price -= params.discount',
      params: {
        discount: 500,
      },
    },
  },
});
```

### ドキュメント削除

```typescript
await client.delete({
  index: 'products',
  id: '1',
});
```

---

## 検索クエリ

### 基本的な検索

```typescript
const result = await client.search({
  index: 'products',
  body: {
    query: {
      match_all: {},
    },
  },
});

const hits = result.hits.hits.map((hit: any) => ({
  id: hit._id,
  ...hit._source,
}));
```

### Match Query

```typescript
// 全文検索
const result = await client.search({
  index: 'products',
  body: {
    query: {
      match: {
        name: 'ワイヤレス マウス',
      },
    },
  },
});
```

### Multi-Match Query

```typescript
// 複数フィールドを検索
const result = await client.search({
  index: 'products',
  body: {
    query: {
      multi_match: {
        query: 'ワイヤレス',
        fields: ['name', 'description'],
      },
    },
  },
});
```

### Term Query

```typescript
// 完全一致
const result = await client.search({
  index: 'products',
  body: {
    query: {
      term: {
        category: 'electronics',
      },
    },
  },
});
```

### Range Query

```typescript
// 範囲検索
const result = await client.search({
  index: 'products',
  body: {
    query: {
      range: {
        price: {
          gte: 1000,
          lte: 5000,
        },
      },
    },
  },
});
```

### Bool Query

```typescript
// 複合クエリ
const result = await client.search({
  index: 'products',
  body: {
    query: {
      bool: {
        must: [
          { match: { name: 'マウス' } },
        ],
        filter: [
          { term: { category: 'electronics' } },
          { range: { price: { lte: 5000 } } },
        ],
        should: [
          { term: { tags: 'wireless' } },
        ],
        must_not: [
          { term: { inStock: false } },
        ],
      },
    },
  },
});
```

### ページネーション

```typescript
const result = await client.search({
  index: 'products',
  body: {
    from: 0,
    size: 10,
    query: {
      match_all: {},
    },
    sort: [
      { price: { order: 'asc' } },
    ],
  },
});
```

### Scroll API（大量データ）

```typescript
// 初回検索
let result = await client.search({
  index: 'products',
  scroll: '1m',
  body: {
    size: 100,
    query: { match_all: {} },
  },
});

let scrollId = result._scroll_id;
let hits = result.hits.hits;

// 全データ取得
while (hits.length > 0) {
  result = await client.scroll({
    scroll_id: scrollId,
    scroll: '1m',
  });

  scrollId = result._scroll_id;
  hits = result.hits.hits;

  // 処理...
}

// スクロールクリア
await client.clearScroll({ scroll_id: scrollId });
```

---

## 集計（Aggregations）

### Terms Aggregation

```typescript
// カテゴリ別の集計
const result = await client.search({
  index: 'products',
  body: {
    size: 0,
    aggs: {
      categories: {
        terms: {
          field: 'category',
          size: 10,
        },
      },
    },
  },
});

const buckets = result.aggregations.categories.buckets;
// [{ key: 'electronics', doc_count: 50 }, ...]
```

### Stats Aggregation

```typescript
// 統計情報
const result = await client.search({
  index: 'products',
  body: {
    size: 0,
    aggs: {
      price_stats: {
        stats: {
          field: 'price',
        },
      },
    },
  },
});

console.log(result.aggregations.price_stats);
// { count, min, max, avg, sum }
```

### Histogram Aggregation

```typescript
// 価格帯別の分布
const result = await client.search({
  index: 'products',
  body: {
    size: 0,
    aggs: {
      price_histogram: {
        histogram: {
          field: 'price',
          interval: 1000,
        },
      },
    },
  },
});
```

### Date Histogram

```typescript
// 時系列集計
const result = await client.search({
  index: 'logs',
  body: {
    size: 0,
    aggs: {
      logs_over_time: {
        date_histogram: {
          field: 'timestamp',
          calendar_interval: 'day',
        },
      },
    },
  },
});
```

---

## フルテキスト検索

### ファジー検索

```typescript
// タイポ許容
const result = await client.search({
  index: 'products',
  body: {
    query: {
      match: {
        name: {
          query: 'マウス',
          fuzziness: 'AUTO',
        },
      },
    },
  },
});
```

### Phrase検索

```typescript
// フレーズ一致
const result = await client.search({
  index: 'products',
  body: {
    query: {
      match_phrase: {
        description: 'ワイヤレス マウス',
      },
    },
  },
});
```

### ハイライト

```typescript
const result = await client.search({
  index: 'products',
  body: {
    query: {
      match: { name: 'マウス' },
    },
    highlight: {
      fields: {
        name: {},
        description: {},
      },
    },
  },
});

const hits = result.hits.hits.map((hit: any) => ({
  ...hit._source,
  highlights: hit.highlight,
}));
```

### 提案（Suggester）

```typescript
const result = await client.search({
  index: 'products',
  body: {
    suggest: {
      product_suggestion: {
        text: 'マース',
        term: {
          field: 'name',
        },
      },
    },
  },
});

const suggestions = result.suggest.product_suggestion[0].options;
```

---

## ベストプラクティス

### 1. Express統合

```typescript
import express from 'express';
import { Client } from '@elastic/elasticsearch';

const app = express();
const client = new Client({ node: 'http://localhost:9200' });

app.get('/api/search', async (req, res) => {
  try {
    const { q, category, minPrice, maxPrice, page = 1, size = 10 } = req.query;

    const must: any[] = [];
    const filter: any[] = [];

    if (q) {
      must.push({
        multi_match: {
          query: q,
          fields: ['name^2', 'description'],
        },
      });
    }

    if (category) {
      filter.push({ term: { category } });
    }

    if (minPrice || maxPrice) {
      filter.push({
        range: {
          price: {
            ...(minPrice && { gte: parseInt(minPrice as string) }),
            ...(maxPrice && { lte: parseInt(maxPrice as string) }),
          },
        },
      });
    }

    const result = await client.search({
      index: 'products',
      body: {
        from: (parseInt(page as string) - 1) * parseInt(size as string),
        size: parseInt(size as string),
        query: {
          bool: {
            must,
            filter,
          },
        },
        highlight: {
          fields: { name: {}, description: {} },
        },
      },
    });

    res.json({
      total: result.hits.total,
      hits: result.hits.hits.map((hit: any) => ({
        id: hit._id,
        ...hit._source,
        highlights: hit.highlight,
      })),
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Search failed' });
  }
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

### 2. データ同期

```typescript
// PostgreSQL → Elasticsearch
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function syncProductToElasticsearch(productId: string) {
  const product = await prisma.product.findUnique({
    where: { id: productId },
  });

  if (!product) {
    // 削除された場合
    await client.delete({
      index: 'products',
      id: productId,
    });
    return;
  }

  // Elasticsearchに追加/更新
  await client.index({
    index: 'products',
    id: product.id,
    body: {
      name: product.name,
      description: product.description,
      price: product.price,
      category: product.category,
      createdAt: product.createdAt,
    },
  });
}

// Prisma Middleware
prisma.$use(async (params, next) => {
  const result = await next(params);

  if (params.model === 'Product') {
    if (['create', 'update', 'delete'].includes(params.action)) {
      await syncProductToElasticsearch(params.args.where?.id || result.id);
    }
  }

  return result;
});
```

### 3. 全文検索の最適化

```typescript
// カスタムアナライザー
await client.indices.create({
  index: 'articles',
  body: {
    settings: {
      analysis: {
        analyzer: {
          my_analyzer: {
            type: 'custom',
            tokenizer: 'standard',
            filter: [
              'lowercase',
              'asciifolding',
              'my_stop',
              'my_stemmer',
            ],
          },
        },
        filter: {
          my_stop: {
            type: 'stop',
            stopwords: '_english_',
          },
          my_stemmer: {
            type: 'stemmer',
            language: 'english',
          },
        },
      },
    },
    mappings: {
      properties: {
        title: {
          type: 'text',
          analyzer: 'my_analyzer',
        },
        content: {
          type: 'text',
          analyzer: 'my_analyzer',
        },
      },
    },
  },
});
```

### 4. パフォーマンス最適化

```typescript
// 必要なフィールドのみ取得
const result = await client.search({
  index: 'products',
  body: {
    _source: ['name', 'price'],
    query: { match_all: {} },
  },
});

// キャッシュ活用
const result = await client.search({
  index: 'products',
  body: {
    query: {
      bool: {
        filter: [
          { term: { category: 'electronics' } },
        ],
      },
    },
  },
});
```

### 5. エラーハンドリング

```typescript
async function safeSearch(query: any) {
  try {
    return await client.search(query);
  } catch (error: any) {
    if (error.meta?.statusCode === 404) {
      console.error('Index not found');
    } else if (error.meta?.statusCode === 400) {
      console.error('Invalid query:', error.meta.body.error);
    } else {
      console.error('Search error:', error);
    }

    throw error;
  }
}
```

### 6. ヘルスチェック

```typescript
async function checkElasticsearchHealth() {
  try {
    const health = await client.cluster.health();

    return {
      status: health.status,
      nodes: health.number_of_nodes,
      activeShards: health.active_shards,
    };
  } catch (error) {
    return { status: 'unavailable' };
  }
}
```

---

## 参考リンク

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Elasticsearch Node.js Client](https://www.elastic.co/guide/en/elasticsearch/client/javascript-api/current/index.html)
- [Query DSL](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html)
