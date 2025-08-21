<?php
class GenerateSsoCookie {
    const JWT_PRIVATE_KEY = 'sso_jwt_private.key';
    const PAYLOAD_PUBLIC_KEY = 'payload_public.key';
    const PAYLOAD_PRIVATE_KEY = 'payload_private.key';

    const USER_ID = 'DS123456';
    const EMAIL = 'test9@example.com';
    const PASSWORD_SHA1 = '5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8';
    const EXPIRES_AT = '2025-08-30 09:41:36';

    // JWT生成
    public function call() {
        $header_base64 = base64_encode(json_encode(['alg'=>'RS256','typ'=>'JWT']));
        $payload_json = json_encode([
            'ds_user_id_cg'=>self::USER_ID,
            'email'=>self::EMAIL,
            'password_sha1'=>self::PASSWORD_SHA1,
            'expires_at'=>self::EXPIRES_AT
        ]);
        openssl_public_encrypt($payload_json, $enc, openssl_pkey_get_public("file://".self::PAYLOAD_PUBLIC_KEY));
        $payload_base64 = base64_encode($enc);

        $signing_input = $header_base64.'.'.$payload_base64;
        openssl_sign($signing_input, $sig, openssl_pkey_get_private("file://".self::JWT_PRIVATE_KEY), OPENSSL_ALGO_SHA256);
        return $header_base64.'.'.$payload_base64.'.'.base64_encode($sig);
    }

    // ペイロード復号化
    public function decryptPayload($payload_base64) {
        openssl_private_decrypt(base64_decode($payload_base64), $dec, openssl_pkey_get_private("file://".self::PAYLOAD_PRIVATE_KEY));
        return json_decode($dec,true);
    }
}

// 使用例
$gen = new GenerateSsoCookie();
$jwt = $gen->call();
echo "JWT: $jwt\n";
$payload = $gen->decryptPayload(explode('.', $jwt)[1]);
echo "復号化ペイロード: ".json_encode($payload, JSON_UNESCAPED_UNICODE)."\n";
?>
