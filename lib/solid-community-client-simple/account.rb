module SOLID
  class Account
    attr_accessor :json

    def initialize(json:)
      @json = json
    end

    def login_url
      login = json['controls']['password']['login']
      warn "login #{login}"
      login
    end

    def credentials_url
      json['controls']['account']['clientCredentials']
    end

    def webid_url
      json['controls']['account']['webId']
    end

  end
end

