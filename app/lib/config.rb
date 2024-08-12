module SOLID
  class CommunityClientConfig

    require 'base64'
    require 'openssl'
    require 'rest-client'
    require 'json'
    require 'jwt'
    require 'securerandom'

    require_relative './account'
    require_relative './dpop'
    require_relative './login'

  end
end
