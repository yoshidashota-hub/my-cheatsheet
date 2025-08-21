# TypeScript 版 SSO JWT 生成・検証チートシート

## 🔑 鍵ファイル

- `sso_jwt_private.key` : JWT 署名用秘密鍵
- `sso_jwt_public.key` : JWT 署名用公開鍵
- `payload_public.key` : ペイロード暗号化用公開鍵
- `payload_private.key` : ペイロード復号化用秘密鍵

**💡 ベストプラクティス**

- 秘密鍵は厳重に管理（アクセス制限）
- 公開鍵は検証側に配布、秘密鍵は生成側のみ保持
- 定期的に鍵ローテーション

---

## ⚙️ JWT 設定

- ヘッダー: `{ "alg": "RS256", "typ": "JWT" }`
- 実際の署名アルゴリズム: **RSA + SHA-256**
- ペイロード項目:
  - 'user_data'

---

## 🛠️ JWT 生成フロー

1. ヘッダー生成 → JSON.stringify → Base64 エンコード
2. ペイロード生成 → 公開鍵で暗号化 → Base64 エンコード
3. 署名対象文字列 = `header.payload`
4. 秘密鍵で署名（SHA-256 使用）
5. JWT = `header.payload.signature`

```ts
import * as crypto from "crypto";
import * as fs from "fs";

const privateKey = fs.readFileSync("sso_jwt_private.key", "utf-8");
const signingInput = `${headerBase64}.${payloadBase64}`;
const signature = crypto.sign("sha256", Buffer.from(signingInput), {
  key: privateKey,
  padding: crypto.constants.RSA_PKCS1_PADDING,
});
const signatureBase64 = signature.toString("base64");

const jwt = `${headerBase64}.${payloadBase64}.${signatureBase64}`;
```
