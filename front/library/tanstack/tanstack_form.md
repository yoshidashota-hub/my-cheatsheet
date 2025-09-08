# TanStack Form

## 概要

型安全で高性能な React フォームライブラリ。バリデーション、最適化、フレームワーク非依存

## インストール

```bash
npm install @tanstack/react-form
npm install @tanstack/zod-form-adapter zod  # Zodバリデーション用
```

## 基本セットアップ

### 1. シンプルなフォーム

```tsx
import { useForm } from "@tanstack/react-form";
import { zodValidator } from "@tanstack/zod-form-adapter";
import { z } from "zod";

const userSchema = z.object({
  name: z.string().min(1, "名前は必須です"),
  email: z.string().email("有効なメールアドレスを入力してください"),
  age: z.number().min(0, "年齢は0以上である必要があります"),
});

export function UserForm() {
  const form = useForm({
    defaultValues: {
      name: "",
      email: "",
      age: 0,
    },
    validatorAdapter: zodValidator,
    validators: {
      onChange: userSchema,
    },
    onSubmit: async ({ value }) => {
      console.log("送信データ:", value);
      // API呼び出し
    },
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        form.handleSubmit();
      }}
    >
      <form.Field
        name="name"
        children={(field) => (
          <div>
            <label htmlFor={field.name}>名前:</label>
            <input
              id={field.name}
              name={field.name}
              value={field.state.value}
              onBlur={field.handleBlur}
              onChange={(e) => field.handleChange(e.target.value)}
            />
            {field.state.meta.errors.length > 0 && (
              <em role="alert">{field.state.meta.errors[0]}</em>
            )}
          </div>
        )}
      />

      <form.Field
        name="email"
        children={(field) => (
          <div>
            <label htmlFor={field.name}>メール:</label>
            <input
              id={field.name}
              name={field.name}
              type="email"
              value={field.state.value}
              onBlur={field.handleBlur}
              onChange={(e) => field.handleChange(e.target.value)}
            />
            {field.state.meta.errors.length > 0 && (
              <em role="alert">{field.state.meta.errors[0]}</em>
            )}
          </div>
        )}
      />

      <form.Subscribe
        selector={(state) => [state.canSubmit, state.isSubmitting]}
        children={([canSubmit, isSubmitting]) => (
          <button type="submit" disabled={!canSubmit}>
            {isSubmitting ? "送信中..." : "送信"}
          </button>
        )}
      />
    </form>
  );
}
```

## 実務レベルの機能

### 2. カスタムフィールドコンポーネント

```tsx
// components/FormField.tsx
interface FormFieldProps {
  form: any;
  name: string;
  label: string;
  type?: string;
  placeholder?: string;
}

export function FormField({
  form,
  name,
  label,
  type = "text",
  placeholder,
}: FormFieldProps) {
  return (
    <form.Field
      name={name}
      children={(field) => (
        <div className="mb-4">
          <label
            htmlFor={field.name}
            className="block text-sm font-medium text-gray-700 mb-1"
          >
            {label}
          </label>
          <input
            id={field.name}
            name={field.name}
            type={type}
            placeholder={placeholder}
            value={field.state.value}
            onBlur={field.handleBlur}
            onChange={(e) => field.handleChange(e.target.value)}
            className={`
              w-full px-3 py-2 border rounded-md shadow-sm
              ${
                field.state.meta.errors.length > 0
                  ? "border-red-500 focus:border-red-500"
                  : "border-gray-300 focus:border-blue-500"
              }
            `}
          />
          {field.state.meta.errors.length > 0 && (
            <p className="mt-1 text-sm text-red-600">
              {field.state.meta.errors[0]}
            </p>
          )}
        </div>
      )}
    />
  );
}
```

### 3. 複雑なバリデーション

```tsx
const registrationSchema = z
  .object({
    username: z
      .string()
      .min(3, "ユーザー名は3文字以上である必要があります")
      .max(20, "ユーザー名は20文字以下である必要があります")
      .regex(/^[a-zA-Z0-9_]+$/, "英数字とアンダースコアのみ使用可能です"),
    email: z.string().email("有効なメールアドレスを入力してください"),
    password: z
      .string()
      .min(8, "パスワードは8文字以上である必要があります")
      .regex(
        /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
        "大文字、小文字、数字を含める必要があります"
      ),
    confirmPassword: z.string(),
    terms: z
      .boolean()
      .refine((val) => val === true, "利用規約に同意してください"),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "パスワードが一致しません",
    path: ["confirmPassword"],
  });

export function RegistrationForm() {
  const form = useForm({
    defaultValues: {
      username: "",
      email: "",
      password: "",
      confirmPassword: "",
      terms: false,
    },
    validatorAdapter: zodValidator,
    validators: {
      onChange: registrationSchema,
    },
    onSubmit: async ({ value }) => {
      try {
        await registerUser(value);
        // 成功処理
      } catch (error) {
        form.setErrorMap({
          onSubmit: "アカウント作成に失敗しました",
        });
      }
    },
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        form.handleSubmit();
      }}
    >
      <FormField form={form} name="username" label="ユーザー名" />
      <FormField form={form} name="email" label="メールアドレス" type="email" />
      <FormField
        form={form}
        name="password"
        label="パスワード"
        type="password"
      />
      <FormField
        form={form}
        name="confirmPassword"
        label="パスワード確認"
        type="password"
      />

      <form.Field
        name="terms"
        children={(field) => (
          <div className="mb-4">
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={field.state.value}
                onChange={(e) => field.handleChange(e.target.checked)}
                className="mr-2"
              />
              利用規約に同意します
            </label>
            {field.state.meta.errors.length > 0 && (
              <p className="text-red-600 text-sm mt-1">
                {field.state.meta.errors[0]}
              </p>
            )}
          </div>
        )}
      />

      <form.Subscribe
        selector={(state) => [
          state.canSubmit,
          state.isSubmitting,
          state.errorMap,
        ]}
        children={([canSubmit, isSubmitting, errorMap]) => (
          <div>
            {errorMap.onSubmit && (
              <div className="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded">
                {errorMap.onSubmit}
              </div>
            )}
            <button
              type="submit"
              disabled={!canSubmit}
              className={`
                w-full py-2 px-4 rounded-md font-medium
                ${
                  canSubmit
                    ? "bg-blue-600 hover:bg-blue-700 text-white"
                    : "bg-gray-300 text-gray-500 cursor-not-allowed"
                }
              `}
            >
              {isSubmitting ? "アカウント作成中..." : "アカウント作成"}
            </button>
          </div>
        )}
      />
    </form>
  );
}
```

### 4. 非同期バリデーション

```tsx
// フィールドレベルの非同期バリデーション
<form.Field
  name="username"
  validators={{
    onChangeAsync: async ({ value }) => {
      if (!value) return undefined;

      // ユーザー名の重複チェック
      const isAvailable = await checkUsernameAvailability(value);
      if (!isAvailable) {
        return "このユーザー名は既に使用されています";
      }
      return undefined;
    },
    onChangeAsyncDebounceMs: 500, // 500ms後にチェック
  }}
  children={(field) => (
    <div>
      <input
        value={field.state.value}
        onChange={(e) => field.handleChange(e.target.value)}
        className={field.state.meta.isValidating ? "validating" : ""}
      />
      {field.state.meta.isValidating && <span>確認中...</span>}
      {field.state.meta.errors.length > 0 && (
        <em>{field.state.meta.errors[0]}</em>
      )}
    </div>
  )}
/>
```

### 5. 配列フィールド

```tsx
const skillsSchema = z.object({
  skills: z
    .array(
      z.object({
        name: z.string().min(1, "スキル名は必須です"),
        level: z.enum(["beginner", "intermediate", "advanced"]),
      })
    )
    .min(1, "少なくとも1つのスキルを追加してください"),
});

export function SkillsForm() {
  const form = useForm({
    defaultValues: {
      skills: [{ name: "", level: "beginner" }],
    },
    validatorAdapter: zodValidator,
    validators: {
      onChange: skillsSchema,
    },
  });

  return (
    <form.Field
      name="skills"
      mode="array"
      children={(field) => (
        <div>
          <label>スキル:</label>
          {field.state.value.map((_, i) => (
            <div key={i} className="flex gap-2 mb-2">
              <form.Field
                name={`skills[${i}].name`}
                children={(subField) => (
                  <input
                    placeholder="スキル名"
                    value={subField.state.value}
                    onChange={(e) => subField.handleChange(e.target.value)}
                  />
                )}
              />
              <form.Field
                name={`skills[${i}].level`}
                children={(subField) => (
                  <select
                    value={subField.state.value}
                    onChange={(e) => subField.handleChange(e.target.value)}
                  >
                    <option value="beginner">初級</option>
                    <option value="intermediate">中級</option>
                    <option value="advanced">上級</option>
                  </select>
                )}
              />
              <button
                type="button"
                onClick={() => field.removeValue(i)}
                disabled={field.state.value.length <= 1}
              >
                削除
              </button>
            </div>
          ))}
          <button
            type="button"
            onClick={() => field.pushValue({ name: "", level: "beginner" })}
          >
            スキル追加
          </button>
          {field.state.meta.errors.length > 0 && (
            <em>{field.state.meta.errors[0]}</em>
          )}
        </div>
      )}
    />
  );
}
```

### 6. フォーム状態管理と TanStack Query 統合

```tsx
import { useUpdateUser } from "../hooks/useUser";

export function EditUserForm({ user }: { user: User }) {
  const updateUser = useUpdateUser();

  const form = useForm({
    defaultValues: {
      name: user.name,
      email: user.email,
      bio: user.bio || "",
    },
    validatorAdapter: zodValidator,
    validators: {
      onChange: userSchema,
    },
    onSubmit: async ({ value }) => {
      try {
        await updateUser.mutateAsync({
          id: user.id,
          ...value,
        });
        // 成功通知
        toast.success("ユーザー情報を更新しました");
      } catch (error) {
        form.setErrorMap({
          onSubmit: "更新に失敗しました",
        });
      }
    },
  });

  // フォームが変更されているかチェック
  const isDirty = form.useStore((state) => state.isDirty);

  return (
    <div>
      {isDirty && (
        <div className="mb-4 p-3 bg-yellow-100 border border-yellow-400 text-yellow-700 rounded">
          未保存の変更があります
        </div>
      )}

      <form
        onSubmit={(e) => {
          e.preventDefault();
          form.handleSubmit();
        }}
      >
        <FormField form={form} name="name" label="名前" />
        <FormField
          form={form}
          name="email"
          label="メールアドレス"
          type="email"
        />

        <form.Field
          name="bio"
          children={(field) => (
            <div className="mb-4">
              <label htmlFor={field.name}>自己紹介:</label>
              <textarea
                id={field.name}
                value={field.state.value}
                onChange={(e) => field.handleChange(e.target.value)}
                rows={4}
                className="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
          )}
        />

        <div className="flex gap-2">
          <button
            type="submit"
            disabled={!form.state.canSubmit || updateUser.isPending}
            className="bg-blue-600 text-white px-4 py-2 rounded-md"
          >
            {updateUser.isPending ? "更新中..." : "更新"}
          </button>

          <button
            type="button"
            onClick={() => form.reset()}
            disabled={!isDirty}
            className="bg-gray-300 text-gray-700 px-4 py-2 rounded-md"
          >
            リセット
          </button>
        </div>
      </form>
    </div>
  );
}
```

### 7. カスタムフック

```tsx
// hooks/useFormWithToast.ts
export function useFormWithToast<T>(options: {
  defaultValues: T;
  schema: z.ZodSchema<T>;
  onSubmit: (values: T) => Promise<void>;
  successMessage?: string;
}) {
  return useForm({
    defaultValues: options.defaultValues,
    validatorAdapter: zodValidator,
    validators: {
      onChange: options.schema,
    },
    onSubmit: async ({ value }) => {
      try {
        await options.onSubmit(value);
        toast.success(options.successMessage || "正常に処理されました");
      } catch (error) {
        toast.error("エラーが発生しました");
        throw error;
      }
    },
  });
}

// 使用例
export function ContactForm() {
  const form = useFormWithToast({
    defaultValues: { name: "", email: "", message: "" },
    schema: contactSchema,
    onSubmit: async (values) => {
      await submitContact(values);
    },
    successMessage: "お問い合わせを送信しました",
  });

  return <form>{/* フォーム要素 */}</form>;
}
```

### 8. フォームの永続化

```tsx
// localStorage への自動保存
export function DraftForm() {
  const form = useForm({
    defaultValues: {
      title: "",
      content: "",
    },
    onSubmit: async ({ value }) => {
      await saveDraft(value);
      localStorage.removeItem("draft-form");
    },
  });

  // フォーム値の変更を監視して自動保存
  useEffect(() => {
    const unsubscribe = form.store.subscribe((state) => {
      if (state.isDirty) {
        localStorage.setItem("draft-form", JSON.stringify(state.values));
      }
    });
    return unsubscribe;
  }, [form.store]);

  // 初期化時にローカルストレージから復元
  useEffect(() => {
    const saved = localStorage.getItem("draft-form");
    if (saved) {
      const values = JSON.parse(saved);
      form.setFieldValue("title", values.title);
      form.setFieldValue("content", values.content);
    }
  }, []);

  return <form>{/* フォーム要素 */}</form>;
}
```

## 主要機能

- **型安全**: 完全な TypeScript 対応
- **パフォーマンス**: 最適化された再レンダリング
- **バリデーション**: 同期・非同期・カスタムバリデーション
- **配列フィールド**: 動的なフィールド管理
- **状態管理**: 詳細なフォーム状態トラッキング
- **フレームワーク非依存**: React 以外でも使用可能

## メリット・デメリット

**メリット**: 型安全、高性能、柔軟なバリデーション、優れた DX  
**デメリット**: 学習コスト、セットアップが複雑、エコシステムが発展途上
