# This is written in the Ruby language, but it tries to avoid using 
# too many libraries that will obfuscate what is happening.  
# The REST calls are explicit so you can see all of the required 
# parameters at each point.  Nothing is assumed #(including your own WebID!) 
# though of course, you will already know that.  
# You will possibly also already have a token
#
# In this example, you are assumed to be running the Community Server
# on port 3000 (e.g. via the docker image).  You have already created an account
# your username and password are in the environemnt variables
# ENV['SOLIDUSER'] and ENV['SOLIDPASS']

require 'base64'
require 'openssl'
require 'rest-client'
require 'json'
require 'jwt'
require 'securerandom'

# get login address
resp = RestClient::Request.new({
                                 method: :get,
                                 url: 'http://localhost:3000/.account/',
                                 headers: { accept: 'application/json' }
                               }).execute

j = JSON.parse(resp.body)
login = j['controls']['password']['login']
warn "login #{login}"

# I take my username and password from the environment
payload = { "email": ENV['SOLIDUSER'].to_s, "password": ENV['SOLIDPASS'].to_s }.to_json
resp = RestClient::Request.new({
                                 method: :post,
                                 url: login,
                                 headers: { content_type: 'application/json', accept: 'application/json' },
                                 payload: payload
                               }).execute

# puts resp.body

# get the authorization token from response message
j = JSON.parse(resp.body)
auth_token = j['authorization']
warn "auth_token #{auth_token}"

# with the authoization, the return message for the /.account GET call is richer
resp = RestClient::Request.new({
                                 method: :get,
                                 url: 'http://localhost:3000/.account/',
                                 headers: { accept: 'application/json',
                                            authorization: "CSS-Account-Token #{auth_token}" }
                               }).execute
# puts resp.body

# get credentialsURL and WebID URL
j = JSON.parse(resp.body)
credurl = j['controls']['account']['clientCredentials']
warn "credurl #{credurl}"
webidurl = j['controls']['account']['webId']
warn "webIdurl #{webidurl}"

resp = RestClient::Request.new({
                                 method: :get,
                                 url: webidurl,
                                 headers: { accept: 'application/json',
                                            authorization: "CSS-Account-Token #{auth_token}" }
                               }).execute
# puts resp.body

# get your WebID (I am selecting the first WebID in the possible list, because I have only one)
j = JSON.parse(resp.body)
webid = j['webIdLinks'].keys.first
warn "webid #{webid}"

# Prepare to create an access token. you can name it whatever you wish
payload = { "name": 'my-token', "webId": "#{webid}" }.to_json
resp = RestClient::Request.new({
                                 method: :post,
                                 url: credurl,
                                 headers: { content_type: 'application/json', accept: 'application/json',
                                            authorization: "CSS-Account-Token #{auth_token}" },
                                 payload: payload
                               }).execute
# puts resp.body
j = JSON.parse(resp.body)
tokenid = j['id']  # this is the ID that you see on the localhost:3000/yourpod Web page....
secret = j['secret']
# concatenate tokenid and secret with a ":"
authstring = "#{tokenid}:#{secret}"

# BE CAREFUL!  Base64 encoders may add newline characters
# pick an encoding method that does NOT do this!
encoded_auth = Base64.strict_encode64(authstring)

# where do I get a token?
resp = RestClient.get('http://localhost:3000/.well-known/openid-configuration')
j = JSON.parse(resp.body)
token_endpoint = j['token_endpoint']
warn "token endpoint #{token_endpoint}"

# prepare to request an access token
# note switch to "Basic" auth
payload = 'grant_type=client_credentials&scope=webid'
resp = RestClient::Request.new({
                                 method: :post,
                                 url: token_endpoint,
                                 headers: {
                                   content_type: 'application/x-www-form-urlencoded',
                                   accept: 'application/json',
                                   authorization: "Basic #{encoded_auth}",  # BASIC Auth
                                  #  'dpop': proof
                                 },
                                 payload: payload
                               }).execute
# puts resp.body
j = JSON.parse(resp.body)
access_token = j['access_token']
warn "access_token #{access_token}"


############################  BEGIN DPOP   #################################################################

private_key = OpenSSL::PKey::RSA.generate 2048
  
# this is what you are creating here...
# warn private_key.to_s
# -----BEGIN RSA PRIVATE KEY-----
# MIIEpgIBAAKCAQEA3Tef264buPI0FjIOnb4MxYLJn+E0C57MXzLT7A6C+D04/YSR
# +nmiqAls+5PS7po0oYggLQ9HXAKvduE2f6PDGp0pjMWkmJKE8xQ9Jx6Ue1FzClSt
# vVzcvN6+GjVYk64DqeVWm5N4eBHTgoFkYLBq1tUyfjo6iNUU0gBLfDfBYejVqH5f
# ...
# zfjMIvzM439RqE5jTOQYI0mFv1tumwFiIEZfcm2oh9CPeDoXB26WlSbe
# -----END RSA PRIVATE KEY-----

public_key = private_key.public_key

# warn public_key.to_s
# -----BEGIN PUBLIC KEY-----
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5RCfc+IdrVBNTnmO7gla
# LhitaX0Ikahyt4+wDk+c3nClhUiRB+oR9M0ga+2gZ8oqkMAul1D18EegaHS0lx7t
# ...
# HwIDAQAB
# -----END PUBLIC KEY-----


# two things are happening in the next section:
# The public key needs to be represented in bigendian base 2
# it then needs to be URL-base64 encoded
# You have to figure out how to make your code do this!
# Note that you are using the PUBLIC KEY here!!!!
warn "key e" , Base64.urlsafe_encode64(public_key.e.to_s(2)) # AQAB
warn "key n", Base64.urlsafe_encode64(public_key.n.to_s(2)) # wPIlffH...h61J3w==

# the final result is like this:
# "jwk": {
#   "kty": "RSA",
#   "e": "AQAB",
#   "n": "wPIlffH...h61J3w=="
# }

# DPoP Header
header = {
alg: 'RS256',       # Signing algorithm
typ: 'dpop+jwt',    # Token type
jwk: {
  kty: 'RSA',
  e: Base64.urlsafe_encode64(public_key.e.to_s(2)), # see above for explanation
  n: Base64.urlsafe_encode64(public_key.n.to_s(2))
}
}


# Create DPoP Payload
# you need to do this FOR EVERY CALL!
# what is the URL you will call, and with what HTTP method
# then you get a "proof" for that call, and you can execute it.
payload = {
  htu: 'http://localhost:3000/markw/container8/',  # Target URI
  htm: 'POST',                          # HTTP method
  jti: SecureRandom.uuid,               # Unique token ID
  iat: Time.now.to_i                    # Issued at time
}

# Generate the DPoP proof
proof = JWT.encode(payload, private_key, 'RS256', header)  # PRIVATE key!!

puts "DPoP Proof: #{proof}"
puts "Access Token: #{access_token}"


# JUST FYI - you can inspect the token, especially to see if it is still valid
# by default, I find the community server to make tokens that last for 10 minutes
# decoded_token = JWT.decode(access_token, nil, false)
# # Access the payload (claims)
# payload = decoded_token[0]
# # Print the entire payload
# puts "Token Payload: #{payload}"\
# # Check the expiry time
# if payload['exp']
#   expiry_time = Time.at(payload['exp'])
#   puts "Token Expiry Time: #{expiry_time} (#{expiry_time.utc})"
#   if expiry_time < Time.now
#     puts "The access token has expired."
#   else
#     puts "The access token is still valid."
#   end
# else
#   puts "No expiration time (exp) claim found."
# end
# # Check the scope
# if payload['scope']
#   scopes = payload['scope'].split(' ')
#   puts "Token Scopes: #{scopes.join(', ')}"
# else
#   puts "No scope claim found."
# end


# Data to be posted to the Solid POD
# data = {
#   name: 'Mark',
#   age: 30,
#   occupation: 'Software Developer'
# }

# json_data = data.to_json


data = "@prefix ldp: <http://www.w3.org/ns/ldp#>. <> a ldp:Container, ldp:BasicContainer ."

# this request matches my proof:
# it is to the same URL using the same HTTP Method

req = RestClient::Request.new({
                                 method: :put,  #   htm: 'POST',    
                                 url: 'http://localhost:3000/markw/container8/', #  htu: 'http://localhost:3000/markw/'
                                 headers: {
                                  "Link": "<http://www.w3.org/ns/ldp/BasicContainer>; rel='type'",
                                  content_type: 'text/turtle', # if you're sending turtle
                                  # content_type: 'application/json',
                                  accept: 'text/turtle',
                                  #  slug: "container8",  # I am allowed to select my preferred resource name
                                   authorization: "Bearer #{access_token}", # Note switch to Bearer auth!
                                   'DPoP': proof
                                 },
                                 payload: data
                                })
_resp = req.execute

payload = {
  htu: 'http://localhost:3000/markw/container8/',  # Target URI
  htm: 'GET',                          # HTTP method
  jti: SecureRandom.uuid,               # Unique token ID
  iat: Time.now.to_i                    # Issued at time
}

# Generate the DPoP proof
proof = JWT.encode(payload, private_key, 'RS256', header)  # PRIVATE key!!

req = RestClient::Request.new({
                                 method: :get,  
                                 url: 'http://localhost:3000/markw/container8/', #  htu: 'http://localhost:3000/markw/'
                                 headers: {
                                  content_type: 'text/turtle', # if you're sending turtle
                                  # content_type: 'application/json',
                                  accept: 'text/turtle',
                                   authorization: "Bearer #{access_token}", # Note switch to Bearer auth!
                                   'DPoP': proof
                                 },
                                 payload: data
                                })
resp = req.execute
puts resp.inspect
puts resp.headers
puts resp.body




