module SOLID

  class DPOP
    attr_accessor :public_key, :private_key, :header, :current_payload, :method, :url, :proof

    def initialize (public_key: nil, private_key: nil, method:, url:)
      private_key ||= OpenSSL::PKey::RSA.generate 2048
      public_key ||= private_key.public_key
      @public_key = public_key
      @private_key = private_key
      @method = method
      @url = url
      
      @header = {
        alg: 'RS256',       # Signing algorithm
        typ: 'dpop+jwt',    # Token type
        jwk: {
          kty: 'RSA',
          e: Base64.urlsafe_encode64(public_key.e.to_s(2)), # see above for explanation
          n: Base64.urlsafe_encode64(public_key.n.to_s(2))
        }
        }

      @current_payload = {
        htu: @url,  # Target URI
        htm: @method.upcase,                          # HTTP method
        jti: SecureRandom.uuid,               # Unique token ID
        iat: Time.now.to_i                    # Issued at time
      }
    end

    def get_proof
      proof = JWT.encode(self.current_payload, self.private_key, 'RS256', self.header)  # PRIVATE key!!
      warn "DPoP Proof: #{proof}"
      @proof = proof
      @proof
    end


  end
end

