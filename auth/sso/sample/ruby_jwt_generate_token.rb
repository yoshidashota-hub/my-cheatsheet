require 'openssl'
require 'base64'
require 'json'

class GenerateSsoCookie
  JWT_PRIVATE_KEY = "sso_jwt_private.key"
  PAYLOAD_PUBLIC_KEY = "payload_public.key"
  PAYLOAD_PRIVATE_KEY = "payload_private.key"

  USER_ID = "DS123456"
  EMAIL = "test9@example.com"
  PASSWORD_SHA1 = "5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8"
  EXPIRES_AT = "2025-08-30 09:41:36"

  # JWT生成
  def call
    header_base64 = Base64.strict_encode64({ alg: "RS256", typ: "JWT" }.to_json)
    payload_json = {
      ds_user_id_cg: USER_ID,
      email: EMAIL,
      password_sha1: PASSWORD_SHA1,
      expires_at: EXPIRES_AT
    }.to_json

    public_key = OpenSSL::PKey::RSA.new(File.read(PAYLOAD_PUBLIC_KEY))
    encrypt_payload = public_key.public_encrypt(payload_json)
    payload_base64 = Base64.strict_encode64(encrypt_payload)

    signing_input = "#{header_base64}.#{payload_base64}"
    private_key = OpenSSL::PKey::RSA.new(File.read(JWT_PRIVATE_KEY))
    signature = private_key.sign(OpenSSL::Digest::SHA256.new, signing_input)
    signature_base64 = Base64.strict_encode64(signature)

    "#{header_base64}.#{payload_base64}.#{signature_base64}"
  end

  # ペイロード復号化
  def decrypt_payload(payload_base64)
    private_key = OpenSSL::PKey::RSA.new(File.read(PAYLOAD_PRIVATE_KEY))
    decrypted = private_key.private_decrypt(Base64.decode64(payload_base64))
    JSON.parse(decrypted)
  end
end

# 使用例
gen = GenerateSsoCookie.new
jwt = gen.call
puts "JWT: #{jwt}"
payload = gen.decrypt_payload(jwt.split('.')[1])
puts "復号化ペイロード: #{payload}"
