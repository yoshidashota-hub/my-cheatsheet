# Ruby 版 SSO JWT 生成・検証チートシート

## 🔑 鍵ファイル

- `sso_jwt_private.key` : JWT 署名用秘密鍵
- `sso_jwt_public.key` : JWT 署名用公開鍵
- `payload_public.key` : ペイロード暗号化用公開鍵
- `payload_private.key` : ペイロード復号化用秘密鍵

\*\*💡 ベストプラクティス

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

1. ヘッダー生成 → Base64 エンコード
2. ペイロード生成 → 公開鍵で暗号化 → Base64 エンコード
3. 署名対象文字列 = `header.payload`
4. 秘密鍵で署名（SHA-256 使用）
5. JWT = `header.payload.signature`

```ruby
# 署名生成
signature = private_key.sign(OpenSSL::Digest::SHA256.new, signing_input)
```

---

## 🔍 検証方法（Ruby）

```ruby
result = public_key.verify(OpenSSL::Digest::SHA256.new, signature_decoded, signing_input)
```

---

## 🔓 ペイロード復号化

```ruby
decrypted = private_key.private_decrypt(Base64.decode64(payload_base64))
```

---

## ⚠️ 注意事項

- JWT ヘッダーは `RS256` と宣言 → 実際は **SHA-1** 署名
- JWT 標準に非準拠（互換性維持のため）
- ヘッダー宣言と実際のアルゴリズムがズレてないか確認すること！

---

## ベストプラクティス

- 秘密鍵は安全に管理
- 署名アルゴリズムは SHA-256
- Base64 は URL セーフ形式
- ペイロードは必要最小限 & 暗号化
- 有効期限を必ず確認
- 署名検証に失敗した JWT は破棄
- JWT 標準に準拠し、互換性維持とセキュリティ向上のバランスを考慮

---
