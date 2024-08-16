module SOLID
  class CommunityClient

    VERSION = "0.0.5"

    require_relative './config'

    attr_accessor :username, :password, :server, :account_meta, :login_meta, :credentials_url, :webid_url, :webids,
                  :css_account_token, :tokenid, :secret, :auth_string, :encoded_auth, :current_access_token

    #
    # Initialize the SOLID Community Client Object
    #
    # @param [String] server The URL of the SOLID Pod you want to interact with
    # @param [String] username Your SOLID Pod username (defaults to ENV['SOLIDUSER'])
    # @param [String] password Your SOLID Pod password (default to ENV['SOLIDPASSWORD'])
    # @param [webid] webid Your WebID that you use for authentication against that POD (default nil)
    #
    # @return [SOLID::CommunityClient]
    def initialize(server:, username: ENV['SOLIDUSER'], password: ENV['SOLIDPASSWORD'], webid: nil)
      @username = username
      @password = password
      @server = server
      abort "can't proceed without usernme password" unless @username && @password
      @webid = webid
    end

    #
    # Login to the POD. This creates additional accessors in the SOLID::CommunityClient
    # Including:  
    #    #account_meta - this contains the parsed JSON from a GET on the PODs ./accout endpoint
    #    #login_meta - this contains the parsed JSON from a GET on the PODs login_url (part of the #account_meta)
    #    #credentials_url - the URL to be used to get credentials for the POD
    #    #webid_url - the URL to call to get the list of WebIDs that have access to this POD
    #
    #
    # @return [Boolean] Was login successful? (if not, this method will crash, for the moment!  No error tolerance at all!)
    #
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

    #
    # Retrieve the list of WebIDs that have access to this POD
    #
    # @return [Array[String]] an array of URL strings that are the webids of all legitimate POD users
    #
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

    #
    # Create the access token for this POD based in your WebID
    #
    # @param [String] webid The URL of your WebID
    # @param [String] name some arbigtrary name to give your token (no sanity checking on the characters right now...)
    #
    # @return [String] The access token (this also sets the value of the SOLID::CommunityClient#current_access_token instance method)
    #
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

    #
    # Either retrieve or create a valid access token.  This should be used in preference to create_access_token, because it has logic to test the validity of the current token, and renew if it has a remaining lifespan of less than 30 seconds.
    #
    # @param [String] webid Your WebID URL
    # @param [String] name arbitrary string to call your token
    #
    # @return [String] The string of a valid token
    #
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

    #
    # Get the CommunityClient ready to do a specific DPoP interaction.  DPoP requires the URL that you will interact with, adn the HTEP method you will use.  You have to call this method prior to every new kind of interaction with the POD 
    #
    # @param [String] url The URL you will interact with
    # @param [String] method The HTTP Method (e.g. GET)
    #
    # @return [SOLID::DPOP] a SOLID::DPOP object
    #
    def prepare_dpop(url:, method:)
      SOLID::DPOP.new(url: url, method: method)
    end


    #
    # Execute an interaction with a POD (e.g. read or create a resource or container)
    #
    # @param [SOLID::DPOP] dpop The appropriate DPOP object (created by #prepare_dpop)
    # @param [String] data The data in your payload (can be "" but MUST be set, even for a GET!)
    # @param [String] content_type the MIME Content-type for the data
    # @param [String] current_access_token Your current access token (from #get_current_access_token)
    #
    # @return [RestClient::Response] This has no error checking at all... a failed request will cause a crash
    #
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
