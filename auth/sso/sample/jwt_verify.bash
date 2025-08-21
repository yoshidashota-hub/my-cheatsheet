#!/bin/bash
# JWT署名検証＋ペイロード復号化（簡易チートシート版）
# 使い方: ./verify_jwt.sh 'JWT_TOKEN'

JWT="$1"
PUB_KEY="sso_jws_pub.key"
PRI_KEY="sso_payload.key"

[ -z "$JWT" ] && echo "Usage: $0 'JWT_TOKEN'" && exit 1
[ ! -f "$PUB_KEY" ] && echo "公開鍵 $PUB_KEY がありません" && exit 1

# JWT分割・デコード
IFS='.' read -r H P S <<< "$JWT"
HEADER_JSON=$(echo "$H" | base64 -d 2>/dev/null)
PAYLOAD_BIN=$(echo "$P" | base64 -d 2>/dev/null)
SIGNATURE_BIN=$(echo "$S" | base64 -d 2>/dev/null)

# 署名検証
printf '%s' "$H.$P" > signing_input.txt
openssl dgst -sha256 -verify "$PUB_KEY" -signature <(printf '%s' "$SIGNATURE_BIN") signing_input.txt >/dev/null 2>&1 && {
    echo "✅ 署名検証成功 (SHA-256)"; VERIFIED=1
} || {
    openssl dgst -sha1 -verify "$PUB_KEY" -signature <(printf '%s' "$SIGNATURE_BIN") signing_input.txt >/dev/null 2>&1 && {
        echo "✅ 署名検証成功 (SHA-1)"; VERIFIED=1
    } || {
        echo "❌ 署名検証失敗"; VERIFIED=0
    }
}

# ペイロード復号化
if [ -f "$PRI_KEY" ]; then
    echo "$PAYLOAD_BIN" > payload.enc
    openssl pkeyutl -decrypt -inkey "$PRI_KEY" -in payload.enc -out payload.txt 2>/dev/null
    [ $? -eq 0 ] && echo "✅ ペイロード復号化:" && cat payload.txt || echo "⚠️ ペイロード復号化失敗"
fi

# ヘッダーとペイロード表示（JSONの場合）
echo ""
echo "ヘッダー:"; echo "$HEADER_JSON" | python3 -m json.tool 2>/dev/null
[ $VERIFIED -eq 1 ] && echo "署名: 有効" || echo "署名: 無効"
