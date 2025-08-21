# JWT 署名検証チートシート（SHA-1 / SHA-256 対応）

## 基本フロー

1. **JWT を受け取る**

   - `HEADER.PAYLOAD.SIGNATURE` の形式
   - URL エンコードされている場合はデコード

2. **構造確認**

   - `.` が 2 つあるか確認
   - Base64 デコードしてヘッダー / ペイロードを JSON 化できるか確認

3. **署名検証**

   - `SIGNATURE` を Base64 デコード
   - 検証対象文字列 = `HEADER.PAYLOAD`
   - 公開鍵で検証 (`openssl dgst -sha256` or `-sha1`)

   ```bash
   # SHA-256検証（標準）
   openssl dgst -sha256 -verify public.pem -signature signature.bin signing_input.txt

   # SHA-1検証（互換）
   openssl dgst -sha1 -verify public.pem -signature signature.bin signing_input.txt
   ```

4. **アルゴリズム確認**

   - JWT ヘッダー `alg` が `RS256` なの
     実際の署名が **SHA-1** の場合あり → 注意 ⚠️

5. **ペイロード処理**

   - JSON ならそのまま表示
   - 暗号化されている場合は秘密鍵で復号化

   ```bash
   openssl pkeyutl -decrypt -inkey private.pem -in payload.bin -out payload.json
   ```

---

## よくある問題

- 公開鍵 / 秘密鍵ペアが不一致
- Base64 エンコード/デコードの揺れ
- JWT ヘッダーの `alg` と実際の署名方式が異なる（RS256 vs SHA-1）

---

---

✅ **まとめ**

- JWT は `HEADER.PAYLOAD.SIGNATURE`
- **署名検証 = 公開鍵 + (sha1 or sha256)**
- ヘッダー宣言と実際のアルゴリズムがズレてないか確認すること！
