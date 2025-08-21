# PHP 版 SSO JWT 生成・検証チートシート

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

1. ヘッダー生成 → JSON エンコード → Base64 エンコード
2. ペイロード生成 → 公開鍵で暗号化 → Base64 エンコード
3. 署名対象文字列 = `header.payload`
4. 秘密鍵で署名（SHA-256 使用）
5. JWT = `header.payload.signature`

```php
$privateKey = file_get_contents('sso_jwt_private.key');
$header_base64 = base64_encode(json_encode($header));
$payload_base64 = base64_encode(openssl_public_encrypt(json_encode($payload), $encrypted_payload, file_get_contents('payload_public.key')));

$signing_input = $header_base64 . '.' . $payload_base64;
openssl_sign($signing_input, $signature, $privateKey, OPENSSL_ALGO_SHA256);
$signature_base64 = base64_encode($signature);

$jwt = $header_base64 . '.' . $payload_base64 . '.' . $signature_base64;
```
