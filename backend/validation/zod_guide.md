# Zod バリデーションガイド

Zodは、TypeScriptファーストなスキーマ宣言・バリデーションライブラリです。

## インストール

```bash
npm install zod
# or
yarn add zod
# or
pnpm add zod
```

## 基本的な使い方

### スキーマの定義

```typescript
import { z } from 'zod';

// 基本型
const stringSchema = z.string();
const numberSchema = z.number();
const booleanSchema = z.boolean();
const dateSchema = z.date();

// オブジェクト
const userSchema = z.object({
  name: z.string(),
  age: z.number(),
  email: z.string().email(),
});

// 配列
const numbersSchema = z.array(z.number());
const usersSchema = z.array(userSchema);
```

### バリデーション実行

```typescript
// parse: エラー時に例外をスロー
try {
  const user = userSchema.parse({
    name: 'John',
    age: 30,
    email: 'john@example.com',
  });
  console.log(user); // { name: 'John', age: 30, email: 'john@example.com' }
} catch (error) {
  console.error(error);
}

// safeParse: エラー時に結果オブジェクトを返す（推奨）
const result = userSchema.safeParse({
  name: 'John',
  age: 30,
  email: 'invalid-email',
});

if (result.success) {
  console.log(result.data);
} else {
  console.error(result.error.errors);
}
```

## TypeScript型推論

```typescript
const userSchema = z.object({
  id: z.number(),
  name: z.string(),
  email: z.string().email(),
});

// スキーマから型を推論
type User = z.infer<typeof userSchema>;
// 結果: { id: number; name: string; email: string; }

// 関数の引数・戻り値に使用
function createUser(data: User): User {
  return data;
}
```

## バリデーションルール

### 文字列

```typescript
z.string()
  .min(3, '3文字以上必要です')
  .max(20, '20文字以内にしてください')
  .email('有効なメールアドレスを入力してください')
  .url('有効なURLを入力してください')
  .regex(/^[a-z]+$/, '小文字の英字のみ使用できます')
  .trim() // 前後の空白を削除
  .toLowerCase() // 小文字に変換
  .startsWith('prefix_')
  .endsWith('_suffix');
```

### 数値

```typescript
z.number()
  .min(0, '0以上である必要があります')
  .max(100, '100以下である必要があります')
  .int('整数である必要があります')
  .positive('正の数である必要があります')
  .negative('負の数である必要があります')
  .multipleOf(5, '5の倍数である必要があります');
```

### 日付

```typescript
z.date()
  .min(new Date('2020-01-01'), '2020年1月1日以降である必要があります')
  .max(new Date(), '未来の日付は指定できません');
```

## オプショナル・デフォルト値

```typescript
const schema = z.object({
  name: z.string(),
  age: z.number().optional(), // undefined を許可
  email: z.string().nullable(), // null を許可
  role: z.string().default('user'), // デフォルト値を設定
  status: z.string().nullish(), // null と undefined を許可
});

type Data = z.infer<typeof schema>;
// { name: string; age?: number; email: string | null; role: string; status?: string | null }
```

## 複雑なスキーマ

### Union（ユニオン型）

```typescript
const stringOrNumber = z.union([z.string(), z.number()]);
// または
const stringOrNumber2 = z.string().or(z.number());

// Discriminated Union
const result = z.discriminatedUnion('status', [
  z.object({ status: z.literal('success'), data: z.string() }),
  z.object({ status: z.literal('error'), error: z.string() }),
]);
```

### Enum（列挙型）

```typescript
// Zod enum
const roleSchema = z.enum(['admin', 'user', 'guest']);
type Role = z.infer<typeof roleSchema>; // 'admin' | 'user' | 'guest'

// Native enum
enum NativeRole {
  Admin = 'admin',
  User = 'user',
  Guest = 'guest',
}
const nativeRoleSchema = z.nativeEnum(NativeRole);
```

### Tuple（タプル）

```typescript
const tuple = z.tuple([
  z.string(),
  z.number(),
  z.boolean(),
]);

type Tuple = z.infer<typeof tuple>; // [string, number, boolean]
```

### Record（レコード）

```typescript
const stringRecord = z.record(z.string()); // { [key: string]: string }
const numberRecord = z.record(z.string(), z.number()); // { [key: string]: number }
```

## ネストされたオブジェクト

```typescript
const addressSchema = z.object({
  street: z.string(),
  city: z.string(),
  zipCode: z.string(),
});

const userSchema = z.object({
  name: z.string(),
  address: addressSchema,
  contacts: z.array(
    z.object({
      type: z.enum(['email', 'phone']),
      value: z.string(),
    })
  ),
});
```

## カスタムバリデーション

### refine（カスタムルール）

```typescript
const passwordSchema = z.string().refine(
  (password) => password.length >= 8 && /[A-Z]/.test(password) && /[0-9]/.test(password),
  {
    message: 'パスワードは8文字以上で、大文字と数字を含む必要があります',
  }
);

// 複数のrefine
const userSchema = z.object({
  password: z.string(),
  confirmPassword: z.string(),
}).refine((data) => data.password === data.confirmPassword, {
  message: 'パスワードが一致しません',
  path: ['confirmPassword'], // エラーを表示するフィールド
});
```

### superRefine（高度なカスタムバリデーション）

```typescript
const schema = z.object({
  age: z.number(),
  parentConsent: z.boolean().optional(),
}).superRefine((data, ctx) => {
  if (data.age < 18 && !data.parentConsent) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: '18歳未満の場合は保護者の同意が必要です',
      path: ['parentConsent'],
    });
  }
});
```

## 変換（Transform）

```typescript
// 文字列を数値に変換
const stringToNumber = z.string().transform((val) => parseInt(val, 10));

// 日付文字列をDateオブジェクトに変換
const stringToDate = z.string().transform((str) => new Date(str));

// オブジェクトの変換
const userSchema = z.object({
  firstName: z.string(),
  lastName: z.string(),
}).transform((data) => ({
  ...data,
  fullName: `${data.firstName} ${data.lastName}`,
}));
```

## エラーハンドリング

### エラーメッセージのカスタマイズ

```typescript
const schema = z.object({
  email: z.string({
    required_error: 'メールアドレスは必須です',
    invalid_type_error: 'メールアドレスは文字列である必要があります',
  }).email('有効なメールアドレスを入力してください'),
});
```

### エラー情報の取得

```typescript
const result = userSchema.safeParse(data);

if (!result.success) {
  // すべてのエラー
  console.log(result.error.errors);

  // フィールド別のエラー
  const fieldErrors = result.error.flatten().fieldErrors;
  console.log(fieldErrors.email); // ['有効なメールアドレスを入力してください']

  // エラーメッセージの整形
  console.log(result.error.format());
}
```

## 実践例

### API リクエストのバリデーション

```typescript
// Express
import express from 'express';
import { z } from 'zod';

const createUserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  age: z.number().int().positive(),
});

app.post('/users', (req, res) => {
  const result = createUserSchema.safeParse(req.body);

  if (!result.success) {
    return res.status(400).json({
      error: 'バリデーションエラー',
      details: result.error.flatten().fieldErrors,
    });
  }

  // result.data は型安全
  const user = result.data;
  // ... ユーザー作成処理
});
```

### フォームバリデーション（React Hook Form）

```typescript
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const formSchema = z.object({
  username: z.string().min(3, '3文字以上必要です'),
  email: z.string().email('有効なメールアドレスを入力してください'),
  password: z.string().min(8, '8文字以上必要です'),
});

type FormData = z.infer<typeof formSchema>;

function MyForm() {
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(formSchema),
  });

  const onSubmit = (data: FormData) => {
    console.log(data); // 型安全なデータ
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('username')} />
      {errors.username && <p>{errors.username.message}</p>}

      <input {...register('email')} />
      {errors.email && <p>{errors.email.message}</p>}

      <input type="password" {...register('password')} />
      {errors.password && <p>{errors.password.message}</p>}

      <button type="submit">送信</button>
    </form>
  );
}
```

### 環境変数のバリデーション

```typescript
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  PORT: z.string().transform((val) => parseInt(val, 10)),
  DATABASE_URL: z.string().url(),
  API_KEY: z.string().min(1),
});

// アプリケーション起動時にバリデーション
const env = envSchema.parse(process.env);

export default env;
```

### tRPCとの統合

```typescript
import { z } from 'zod';
import { router, publicProcedure } from './trpc';

export const userRouter = router({
  create: publicProcedure
    .input(
      z.object({
        name: z.string(),
        email: z.string().email(),
      })
    )
    .mutation(async ({ input }) => {
      // input は自動的に型推論される
      return createUser(input);
    }),

  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ input }) => {
      return getUserById(input.id);
    }),
});
```

## パフォーマンス最適化

### スキーマの再利用

```typescript
// ❌ 毎回新しいスキーマを作成（非効率）
function validate(data: unknown) {
  return z.object({ name: z.string() }).parse(data);
}

// ✅ スキーマを再利用（効率的）
const schema = z.object({ name: z.string() });
function validate(data: unknown) {
  return schema.parse(data);
}
```

### 部分的なバリデーション

```typescript
const userSchema = z.object({
  id: z.number(),
  name: z.string(),
  email: z.string().email(),
  age: z.number(),
});

// 一部のフィールドのみバリデーション
const partialSchema = userSchema.partial(); // すべてオプショナルに
const pickSchema = userSchema.pick({ name: true, email: true }); // 指定フィールドのみ
const omitSchema = userSchema.omit({ id: true }); // 指定フィールドを除外
```

## ベストプラクティス

1. **safeParse を使用**: `parse()` ではなく `safeParse()` を使用して例外を避ける
2. **型推論を活用**: `z.infer<>` で TypeScript の型を自動生成
3. **スキーマを共有**: フロントエンドとバックエンドで同じスキーマを使用
4. **明確なエラーメッセージ**: ユーザーにわかりやすいエラーメッセージを設定
5. **スキーマの分割**: 複雑なスキーマは小さな部品に分割して再利用

## 参考リンク

- [公式ドキュメント](https://zod.dev/)
- [GitHub リポジトリ](https://github.com/colinhacks/zod)
