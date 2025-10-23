# React Hook Form ガイド

React Hook Formは、パフォーマンスと開発体験に優れたReactフォームライブラリです。再レンダリングを最小限に抑え、Zodとの統合で型安全なバリデーションを実現します。

## 特徴

- **高パフォーマンス**: 非制御コンポーネントベースで再レンダリングを最小化
- **型安全**: TypeScriptとZodの完全サポート
- **軽量**: 依存関係が少なく、バンドルサイズが小さい
- **柔軟なバリデーション**: Zod、Yup、Joi、カスタムバリデーションに対応
- **優れたDX**: シンプルなAPI、使いやすいエラーハンドリング
- **フォーム配列**: 動的なフィールド追加・削除に対応
- **統合性**: UI ライブラリとの統合が容易

## インストール

```bash
npm install react-hook-form
npm install @hookform/resolvers zod
```

## 基本的な使い方

### シンプルなフォーム

```tsx
import { useForm } from 'react-hook-form'

type FormData = {
  email: string
  password: string
}

export default function LoginForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>()

  const onSubmit = async (data: FormData) => {
    console.log(data)
    // API call
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label>Email</label>
        <input
          type="email"
          {...register('email', {
            required: 'メールアドレスは必須です',
            pattern: {
              value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
              message: '無効なメールアドレスです',
            },
          })}
        />
        {errors.email && <span>{errors.email.message}</span>}
      </div>

      <div>
        <label>パスワード</label>
        <input
          type="password"
          {...register('password', {
            required: 'パスワードは必須です',
            minLength: {
              value: 8,
              message: 'パスワードは8文字以上必要です',
            },
          })}
        />
        {errors.password && <span>{errors.password.message}</span>}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? '送信中...' : 'ログイン'}
      </button>
    </form>
  )
}
```

## Zodとの統合

### 基本的なZodスキーマ統合

```tsx
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const schema = z.object({
  email: z.string().email('無効なメールアドレスです'),
  password: z.string().min(8, 'パスワードは8文字以上必要です'),
  age: z.number().min(18, '18歳以上である必要があります'),
})

type FormData = z.infer<typeof schema>

export default function RegisterForm() {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
  })

  const onSubmit = (data: FormData) => {
    console.log(data)
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('email')} />
      {errors.email && <span>{errors.email.message}</span>}

      <input type="password" {...register('password')} />
      {errors.password && <span>{errors.password.message}</span>}

      <input
        type="number"
        {...register('age', { valueAsNumber: true })}
      />
      {errors.age && <span>{errors.age.message}</span>}

      <button type="submit">登録</button>
    </form>
  )
}
```

### 複雑なZodスキーマ

```tsx
import { z } from 'zod'

const profileSchema = z
  .object({
    username: z
      .string()
      .min(3, 'ユーザー名は3文字以上必要です')
      .max(20, 'ユーザー名は20文字以下である必要があります')
      .regex(/^[a-zA-Z0-9_]+$/, '英数字とアンダースコアのみ使用できます'),
    email: z.string().email('無効なメールアドレスです'),
    password: z
      .string()
      .min(8, 'パスワードは8文字以上必要です')
      .regex(/[A-Z]/, '大文字を1文字以上含める必要があります')
      .regex(/[0-9]/, '数字を1文字以上含める必要があります'),
    confirmPassword: z.string(),
    birthDate: z.string().refine(
      (date) => {
        const age = new Date().getFullYear() - new Date(date).getFullYear()
        return age >= 18
      },
      { message: '18歳以上である必要があります' }
    ),
    agreeToTerms: z.boolean().refine((val) => val === true, {
      message: '利用規約に同意する必要があります',
    }),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: 'パスワードが一致しません',
    path: ['confirmPassword'],
  })

type ProfileFormData = z.infer<typeof profileSchema>
```

## shadcn/uiとの統合

### Formコンポーネントとの統合

```tsx
'use client'

import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'

const formSchema = z.object({
  username: z.string().min(2, '2文字以上入力してください'),
  email: z.string().email('無効なメールアドレスです'),
})

type FormValues = z.infer<typeof formSchema>

export function ProfileForm() {
  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      username: '',
      email: '',
    },
  })

  const onSubmit = (data: FormValues) => {
    console.log(data)
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
        <FormField
          control={form.control}
          name="username"
          render={({ field }) => (
            <FormItem>
              <FormLabel>ユーザー名</FormLabel>
              <FormControl>
                <Input placeholder="shadcn" {...field} />
              </FormControl>
              <FormDescription>
                公開表示されるユーザー名です
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>メールアドレス</FormLabel>
              <FormControl>
                <Input type="email" placeholder="you@example.com" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit">送信</Button>
      </form>
    </Form>
  )
}
```

### Select、Checkbox、Radioとの統合

```tsx
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Checkbox } from '@/components/ui/checkbox'
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group'

const formSchema = z.object({
  country: z.string().min(1, '国を選択してください'),
  notifications: z.boolean(),
  plan: z.enum(['free', 'pro', 'enterprise']),
})

type FormValues = z.infer<typeof formSchema>

export function AdvancedForm() {
  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      notifications: false,
      plan: 'free',
    },
  })

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(console.log)}>
        <FormField
          control={form.control}
          name="country"
          render={({ field }) => (
            <FormItem>
              <FormLabel>国</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="国を選択" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="jp">日本</SelectItem>
                  <SelectItem value="us">アメリカ</SelectItem>
                  <SelectItem value="uk">イギリス</SelectItem>
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="notifications"
          render={({ field }) => (
            <FormItem className="flex items-center space-x-2">
              <FormControl>
                <Checkbox
                  checked={field.value}
                  onCheckedChange={field.onChange}
                />
              </FormControl>
              <FormLabel>通知を受け取る</FormLabel>
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="plan"
          render={({ field }) => (
            <FormItem>
              <FormLabel>プラン</FormLabel>
              <FormControl>
                <RadioGroup
                  onValueChange={field.onChange}
                  defaultValue={field.value}
                >
                  <FormItem className="flex items-center space-x-2">
                    <FormControl>
                      <RadioGroupItem value="free" />
                    </FormControl>
                    <FormLabel>Free</FormLabel>
                  </FormItem>
                  <FormItem className="flex items-center space-x-2">
                    <FormControl>
                      <RadioGroupItem value="pro" />
                    </FormControl>
                    <FormLabel>Pro</FormLabel>
                  </FormItem>
                </RadioGroup>
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
      </form>
    </Form>
  )
}
```

## 動的フォーム（Field Arrays）

### 基本的なフィールド配列

```tsx
import { useForm, useFieldArray } from 'react-hook-form'
import { z } from 'zod'
import { zodResolver } from '@hookform/resolvers/zod'

const schema = z.object({
  items: z.array(
    z.object({
      name: z.string().min(1, '名前は必須です'),
      quantity: z.number().min(1, '1以上の数値を入力してください'),
    })
  ).min(1, '最低1つのアイテムが必要です'),
})

type FormValues = z.infer<typeof schema>

export function DynamicForm() {
  const { register, control, handleSubmit, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      items: [{ name: '', quantity: 1 }],
    },
  })

  const { fields, append, remove } = useFieldArray({
    control,
    name: 'items',
  })

  return (
    <form onSubmit={handleSubmit(console.log)}>
      {fields.map((field, index) => (
        <div key={field.id}>
          <input
            {...register(`items.${index}.name`)}
            placeholder="商品名"
          />
          {errors.items?.[index]?.name && (
            <span>{errors.items[index]?.name?.message}</span>
          )}

          <input
            type="number"
            {...register(`items.${index}.quantity`, { valueAsNumber: true })}
            placeholder="数量"
          />
          {errors.items?.[index]?.quantity && (
            <span>{errors.items[index]?.quantity?.message}</span>
          )}

          <button type="button" onClick={() => remove(index)}>
            削除
          </button>
        </div>
      ))}

      <button
        type="button"
        onClick={() => append({ name: '', quantity: 1 })}
      >
        アイテム追加
      </button>

      <button type="submit">送信</button>
    </form>
  )
}
```

## Next.js App Routerとの統合

### Server Actionsとの連携

```tsx
'use client'

import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { createUser } from './actions'
import { useTransition } from 'react'

const schema = z.object({
  name: z.string().min(2, '名前は2文字以上必要です'),
  email: z.string().email('無効なメールアドレスです'),
})

type FormValues = z.infer<typeof schema>

export function UserForm() {
  const [isPending, startTransition] = useTransition()
  const {
    register,
    handleSubmit,
    formState: { errors },
    setError,
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
  })

  const onSubmit = async (data: FormValues) => {
    startTransition(async () => {
      const result = await createUser(data)

      if (!result.success) {
        // サーバーサイドのエラーをフォームに反映
        setError('email', {
          message: result.error,
        })
      }
    })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('name')} />
      {errors.name && <span>{errors.name.message}</span>}

      <input type="email" {...register('email')} />
      {errors.email && <span>{errors.email.message}</span>}

      <button type="submit" disabled={isPending}>
        {isPending ? '送信中...' : '送信'}
      </button>
    </form>
  )
}
```

```ts
// app/actions.ts
'use server'

import { z } from 'zod'

const schema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
})

export async function createUser(data: z.infer<typeof schema>) {
  try {
    // バリデーション
    const validated = schema.parse(data)

    // データベース操作
    // await db.user.create({ data: validated })

    return { success: true }
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { success: false, error: 'バリデーションエラー' }
    }
    return { success: false, error: 'ユーザーの作成に失敗しました' }
  }
}
```

### useFormStateとの統合（Next.js 14+）

```tsx
'use client'

import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useFormState } from 'react-dom'
import { submitForm } from './actions'

const schema = z.object({
  email: z.string().email(),
  message: z.string().min(10),
})

type FormValues = z.infer<typeof schema>

export function ContactForm() {
  const [state, formAction] = useFormState(submitForm, null)
  const {
    register,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
  })

  return (
    <form action={formAction}>
      <input {...register('email')} name="email" />
      {errors.email && <span>{errors.email.message}</span>}

      <textarea {...register('message')} name="message" />
      {errors.message && <span>{errors.message.message}</span>}

      {state?.error && <div>{state.error}</div>}
      {state?.success && <div>送信完了しました！</div>}

      <button type="submit">送信</button>
    </form>
  )
}
```

## 高度な機能

### カスタムバリデーション

```tsx
const schema = z.object({
  username: z.string().refine(
    async (username) => {
      // API呼び出しで重複チェック
      const response = await fetch(`/api/check-username?username=${username}`)
      const data = await response.json()
      return data.available
    },
    { message: 'このユーザー名は既に使用されています' }
  ),
})
```

### 依存フィールドのバリデーション

```tsx
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { zodResolver } from '@hookform/resolvers/zod'

const schema = z.object({
  hasAddress: z.boolean(),
  address: z.string().optional(),
}).refine(
  (data) => {
    if (data.hasAddress) {
      return data.address && data.address.length > 0
    }
    return true
  },
  {
    message: '住所を入力してください',
    path: ['address'],
  }
)

type FormValues = z.infer<typeof schema>

export function ConditionalForm() {
  const { register, watch, handleSubmit, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
  })

  const hasAddress = watch('hasAddress')

  return (
    <form onSubmit={handleSubmit(console.log)}>
      <label>
        <input type="checkbox" {...register('hasAddress')} />
        住所を入力する
      </label>

      {hasAddress && (
        <div>
          <input {...register('address')} placeholder="住所" />
          {errors.address && <span>{errors.address.message}</span>}
        </div>
      )}

      <button type="submit">送信</button>
    </form>
  )
}
```

### フォームのリセット

```tsx
import { useForm } from 'react-hook-form'

export function ResetForm() {
  const { register, handleSubmit, reset, formState: { isSubmitSuccessful } } = useForm()

  const onSubmit = async (data) => {
    await fetch('/api/submit', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  // 送信成功後にリセット
  if (isSubmitSuccessful) {
    reset()
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('name')} />
      <button type="submit">送信</button>
      <button type="button" onClick={() => reset()}>
        リセット
      </button>
    </form>
  )
}
```

### デフォルト値の設定

```tsx
import { useForm } from 'react-hook-form'
import { useEffect } from 'react'

export function EditUserForm({ userId }: { userId: string }) {
  const { register, handleSubmit, reset } = useForm()

  useEffect(() => {
    // APIからデータを取得
    fetch(`/api/users/${userId}`)
      .then((res) => res.json())
      .then((data) => {
        // フォームのデフォルト値を設定
        reset(data)
      })
  }, [userId, reset])

  return (
    <form onSubmit={handleSubmit(console.log)}>
      <input {...register('name')} />
      <input {...register('email')} />
      <button type="submit">更新</button>
    </form>
  )
}
```

## パフォーマンス最適化

### 制御コンポーネントと非制御コンポーネント

```tsx
import { useForm, Controller } from 'react-hook-form'

// 非制御コンポーネント（推奨、高速）
export function UncontrolledForm() {
  const { register, handleSubmit } = useForm()

  return (
    <form onSubmit={handleSubmit(console.log)}>
      <input {...register('name')} />
    </form>
  )
}

// 制御コンポーネント（カスタムコンポーネント用）
export function ControlledForm() {
  const { control, handleSubmit } = useForm()

  return (
    <form onSubmit={handleSubmit(console.log)}>
      <Controller
        name="customInput"
        control={control}
        render={({ field }) => <CustomInput {...field} />}
      />
    </form>
  )
}
```

### リレンダリングの最適化

```tsx
import { useForm } from 'react-hook-form'

export function OptimizedForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isDirty, isValid },
  } = useForm({
    mode: 'onChange', // リアルタイムバリデーション
    reValidateMode: 'onChange',
    criteriaMode: 'all', // 全てのエラーを表示
  })

  return (
    <form onSubmit={handleSubmit(console.log)}>
      <input {...register('email')} />
      {errors.email && <span>{errors.email.message}</span>}

      <button type="submit" disabled={!isDirty || !isValid}>
        送信
      </button>
    </form>
  )
}
```

## エラーハンドリング

### カスタムエラーメッセージ

```tsx
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const schema = z.object({
  password: z.string().min(8, 'パスワードは8文字以上です'),
})

export function ErrorHandlingForm() {
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(schema),
  })

  const onSubmit = async (data) => {
    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        body: JSON.stringify(data),
      })

      if (!response.ok) {
        // サーバーエラーをフォームに設定
        setError('root', {
          message: 'ログインに失敗しました',
        })
      }
    } catch (error) {
      setError('root', {
        message: 'ネットワークエラーが発生しました',
      })
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input type="password" {...register('password')} />
      {errors.password && <span>{errors.password.message}</span>}
      {errors.root && <span>{errors.root.message}</span>}
      <button type="submit">ログイン</button>
    </form>
  )
}
```

## ベストプラクティス

### 1. Zodスキーマを再利用する

```tsx
// schemas/user.ts
export const userSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
})

export type UserFormData = z.infer<typeof userSchema>

// components/LoginForm.tsx
import { userSchema, type UserFormData } from '@/schemas/user'

export function LoginForm() {
  const form = useForm<UserFormData>({
    resolver: zodResolver(userSchema),
  })
  // ...
}
```

### 2. フォームステートを適切に管理する

```tsx
const {
  formState: {
    errors,        // エラー
    isDirty,       // フォームが変更されたか
    isValid,       // バリデーションが通っているか
    isSubmitting,  // 送信中か
    isSubmitted,   // 送信済みか
    touchedFields, // タッチされたフィールド
  },
} = useForm()
```

### 3. エラーメッセージをユーザーフレンドリーにする

```tsx
const schema = z.object({
  email: z
    .string()
    .min(1, 'メールアドレスを入力してください')
    .email('有効なメールアドレスを入力してください'),
  password: z
    .string()
    .min(1, 'パスワードを入力してください')
    .min(8, 'パスワードは8文字以上で入力してください')
    .regex(/[A-Z]/, 'パスワードには大文字を含めてください')
    .regex(/[0-9]/, 'パスワードには数字を含めてください'),
})
```

### 4. デバウンスで API 呼び出しを最適化する

```tsx
import { useForm } from 'react-hook-form'
import { useDebounce } from 'use-debounce'
import { useEffect } from 'react'

export function SearchForm() {
  const { register, watch } = useForm()
  const query = watch('query')
  const [debouncedQuery] = useDebounce(query, 500)

  useEffect(() => {
    if (debouncedQuery) {
      // API呼び出し
      fetch(`/api/search?q=${debouncedQuery}`)
    }
  }, [debouncedQuery])

  return <input {...register('query')} />
}
```

## まとめ

React Hook Formは、以下の理由で推奨されます：

- **パフォーマンス**: 非制御コンポーネントで再レンダリングを最小化
- **型安全性**: TypeScript + Zodで完全な型安全性
- **開発体験**: シンプルなAPI、優れたドキュメント
- **柔軟性**: あらゆるUIライブラリと統合可能
- **機能性**: 動的フォーム、条件付きバリデーション、エラーハンドリングが容易

Next.js App Router + shadcn/ui + Zod の組み合わせで、型安全で高パフォーマンスなフォームを簡単に構築できます。

## 参考リンク

- [公式ドキュメント](https://react-hook-form.com/)
- [API Reference](https://react-hook-form.com/api)
- [Examples](https://github.com/react-hook-form/react-hook-form/tree/master/examples)
- [Zod Integration](https://react-hook-form.com/get-started#SchemaValidation)
- [shadcn/ui Form](https://ui.shadcn.com/docs/components/form)
