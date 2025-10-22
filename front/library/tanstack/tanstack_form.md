# TanStack Form

## 概要

型安全で高性能な React フォームライブラリ。Zod バリデーション対応。

## インストール

```bash
npm install @tanstack/react-form
npm install @tanstack/zod-form-adapter zod
```

## 基本的な使用例

```tsx
import { useForm } from "@tanstack/react-form";
import { zodValidator } from "@tanstack/zod-form-adapter";
import { z } from "zod";

const userSchema = z.object({
  name: z.string().min(1, "名前は必須です"),
  email: z.string().email("有効なメールアドレスを入力してください"),
});

function UserForm() {
  const form = useForm({
    defaultValues: { name: "", email: "" },
    validatorAdapter: zodValidator,
    validators: { onChange: userSchema },
    onSubmit: async ({ value }) => {
      console.log("送信:", value);
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
            <input
              value={field.state.value}
              onChange={(e) => field.handleChange(e.target.value)}
            />
            {field.state.meta.errors.length > 0 && (
              <em>{field.state.meta.errors[0]}</em>
            )}
          </div>
        )}
      />
      <button type="submit">送信</button>
    </form>
  );
}
```

## 主要機能

- **型安全**: 完全な TypeScript 対応
- **バリデーション**: Zod 等の外部バリデータ統合
- **配列フィールド**: 動的フィールド管理
- **非同期バリデーション**: debounce 対応
- **高性能**: 最適化された再レンダリング

## 参考リンク

- 公式ドキュメント: https://tanstack.com/form/latest
