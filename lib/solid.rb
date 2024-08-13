module SOLID
  class CommunityClient
    require_relative './config'

    attr_accessor :username, :password, :server, :account_meta, :login_meta, :credentials_url, :webid_url, :webids,
                  :css_account_token, :tokenid, :secret, :auth_string, :encoded_auth, :current_access_token

    def initialize(server:, username: ENV['SOLIDUSER'], password: ENV['SOLIDPASSWORD'], webid: nil)
      @username = username
      @password = password
      @server = server
      abort "can't proceed without usernme password" unless @username && @password
      @webid = webid
    end

    def login
      account = server + '.account/'

      resp = RestClient::Request.new({
                                       method: :get,
                                       url: account,
                                       headers: { accept: 'application/json' }
                                     }).execute

      @account_meta = SOLID::Account.new(json: JSON.parse(resp.body))
      login_url = account_meta.login_url

      # I take my username and password from the environment
      payload = { "email": username, "password": password }.to_json
      resp = RestClient::Request.new({
                                       method: :post,
                                       url: login_url,
                                       headers: {
                                         content_type: 'application/json',
                                         accept: 'application/json'
                                       },
                                       payload: payload
                                     }).execute

      @login_meta = SOLID::Login.new(json: JSON.parse(resp.body))
      @css_account_token = login_meta.login_token

      # with the authoization, the return message for the /.account GET call is richer
      resp = RestClient::Request.new({
                                       method: :get,
                                       url: 'http://localhost:3000/.account/',
                                       headers: {
                                         accept: 'application/json',
                                         authorization: "CSS-Account-Token #{css_account_token}"
                                       }
                                     }).execute

      @account_meta = SOLID::Account.new(json: JSON.parse(resp.body))
      @credentials_url = account_meta.credentials_url
      @webid_url = account_meta.webid_url
      true
    end

    def get_webids
      resp = RestClient::Request.new({
                                       method: :get,
                                       url: webid_url,
                                       headers: {
                                         accept: 'application/json',
                                         authorization: "CSS-Account-Token #{css_account_token}"
                                       }
                                     }).execute

      j = JSON.parse(resp.body)
      @webids = j['webIdLinks'].keys
      webids
    end

    def create_access_token(webid:, name: 'my-token')
      payload = { "name": name, "webId": webid }.to_json
      warn "", "", credentials_url, css_account_token, payload, "", ""
      resp = RestClient::Request.new({
                                       method: :post,
                                       url: credentials_url,
                                       headers: { content_type: 'application/json', accept: 'application/json',
                                                  authorization: "CSS-Account-Token #{css_account_token}" },
                                       payload: payload
                                     }).execute
      # puts resp.body
      j = JSON.parse(resp.body)
      @tokenid = j['id'] # this is the ID that you see on the localhost:3000/yourpod Web page....
      @secret = j['secret']
      # concatenate tokenid and secret with a ":"
      @auth_string = "#{tokenid}:#{secret}"

      # BE CAREFUL!  Base64 encoders may add newline characters
      # pick an encoding method that does NOT do this!
      @encoded_auth = Base64.strict_encode64(auth_string)

      # where do I get a token?
      tokenurl = "#{server}.well-known/openid-configuration"
      resp = RestClient.get(tokenurl)
      j = JSON.parse(resp.body)
      token_endpoint = j['token_endpoint']
      warn "token endpoint #{token_endpoint}"

      payload = 'grant_type=client_credentials&scope=webid'
      resp = RestClient::Request.new({
                                       method: :post,
                                       url: token_endpoint,
                                       headers: {
                                         content_type: 'application/x-www-form-urlencoded',
                                         accept: 'application/json',
                                         authorization: "Basic #{encoded_auth}" # BASIC Auth
                                         #  'dpop': proof
                                       },
                                       payload: payload
                                     }).execute
      # puts resp.body
      j = JSON.parse(resp.body)
      @current_access_token = j['access_token']
    end

    def get_current_access_token(webid:, name: "my-token")
      create_access_token(webid: webid, name: name) unless current_access_token && !(current_access_token.empty?)

      # by default, I find the community server to make tokens that last for 10 minutes
      decoded_token = JWT.decode(current_access_token, nil, false)
      # Access the payload (claims)
      payload = decoded_token[0]
      # Print the entire payload
      puts "Token Payload: #{payload}"\
      # Check the expiry time
      if payload['exp']
        expiry_time = Time.at(payload['exp'])
        warn "Token Expiry Time: #{expiry_time} (#{expiry_time.utc})"
        if (expiry_time - Time.now) < 30
          puts "token will expire. Getting new one."
          create_access_token(webid: webid, name: name)
        else
          puts "The access token is still valid."
        end
      else
        puts "No expiration time (exp) claim found."
      end
      current_access_token
    end

    def prepare_dpop(url:, method:)
      SOLID::DPOP.new(url: url, method: method)
    end


    def execute_with_proof(dpop:, data:, content_type:, current_access_token:)

      req = RestClient::Request.new({
                                 method: dpop.method.downcase.to_sym,  #   htm: 'POST',    
                                 url: dpop.url, #  htu: 'http://localhost:3000/markw/'
                                 headers: {
                                  # "Link": "<http://www.w3.org/ns/ldp/BasicContainer>; rel='type'",
                                  content_type: content_type, # if you're sending turtle
                                  # content_type: 'application/json',
                                  accept: 'text/turtle',
                                  #  slug: "container8",  # I am allowed to select my preferred resource name
                                   authorization: "Bearer #{current_access_token}", # Note switch to Bearer auth!
                                   'DPoP': dpop.proof
                                 },
                                 payload: data
                                })
      req.execute
    end
  end
end
