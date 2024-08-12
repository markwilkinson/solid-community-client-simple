
module SOLID
  class Login
    attr_accessor :json

    def initialize(json:)
      @json = json
    end

    def login_token
      auth_token = json['authorization']
      warn "auth_token #{auth_token}"
      auth_token
    end
  end
end



