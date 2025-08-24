# Aceternity UI - コンポーネント導入ガイド

## インストール方法

**コンポーネントの使用は非常に簡単で、誰でも行うことができます。**

### 前提条件

- Next.js プロジェクトがセットアップ済みであること
- Tailwind CSS がインストール済みであること

## 手動インストールの手順

### 1. コンポーネントを選択

プレビューでコンポーネントを確認し、気に入ったものを見つけたら、Code タブに移動します。

### 2. 依存関係をインストール

コンポーネントは外部ライブラリを使用する場合があるため、それらのインストールを忘れずに行ってください。

例：アニメーション効果があるコンポーネントは Framer Motion を必要とします。

```bash
npm install framer-motion
npm install clsx tailwind-merge
```

### 3. コードをコピー

Code タブには必要なコードがすべて含まれています。タブ下部のコントロールを使用して、異なる技術間を切り替えることができます。

### 4. コンポーネントを使用

すべてのコンポーネントに基本的な使用例が提供されています。詳細を確認したい場合は、Preview タブで利用可能な props を確認できます。

```tsx
import { HeroHighlight, Highlight } from "./components/ui/hero-highlight";

export function HeroHighlightDemo() {
  return (
    <HeroHighlight>
      <motion.h1
        initial={{
          opacity: 0,
          y: 20,
        }}
        animate={{
          opacity: 1,
          y: [20, -5, 0],
        }}
        transition={{
          duration: 0.5,
          ease: [0.4, 0.0, 0.2, 1],
        }}
        className="text-2xl px-4 md:text-4xl lg:text-5xl font-bold text-neutral-700 dark:text-white max-w-4xl leading-relaxed lg:leading-snug text-center mx-auto "
      >
        With insomnia, nothing's real. Everything's a copy of a copy of a{" "}
        <Highlight className="text-black dark:text-white">copy.</Highlight>
      </motion.h1>
    </HeroHighlight>
  );
}
```

**これで完了です！**

あとは、コンポーネントをプロジェクトにどのように統合するかです。コードはあなたのものなので、スタイリングや機能など、自由に修正してください。

## リンク

- **サイト URL**: https://ui.aceternity.com/
