require 'openssl'
require 'base64'

module ScRelayConnect
  class AES

    def aes_encrypt(data)
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.encrypt
      cipher.key = Settings.aes.key
      cipher.iv = Settings.aes.iv
      encrypted = cipher.update(data) + cipher.final
      encrypted_base64 = Base64.strict_encode64(encrypted)

      return encrypted_base64
    end

    def aes_decrypt(encrypted_base64)
      encrypted = Base64.decode64(encrypted_base64)
      decipher = OpenSSL::Cipher.new('aes-256-cbc')
      decipher.decrypt
      decipher.key = Settings.aes.key
      decipher.iv  = Settings.aes.iv
      data = decipher.update(encrypted) + decipher.final
      return data
    end

  end
end
