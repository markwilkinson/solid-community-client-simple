require 'base64'
gem "activesupport", '7.0.3.1'  # the activesupport required for dpop v 1.3
require "dpop"
require 'openssl'
require 'rest-client'
require 'json'

# curl -v -H "Accept: application/json" http://localhost:3000/.account/

resp = RestClient::Request.new({
                                 method: :get,
                                 url: 'http://localhost:3000/.account/',
                                 headers: { accept: 'application/json' }
                               }).execute

j = JSON.parse(resp.body)
login = j['controls']['password']['login']
warn "login #{login}"

payload = { "email": "#{ENV['SOLIDUSER']}", "password": "#{ENV['SOLIDPASS']}" }.to_json
resp = RestClient::Request.new({
                                 method: :post,
                                 url: login,
                                 headers: { content_type: 'application/json', accept: 'application/json' },
                                 payload: payload
                               }).execute

# puts resp.body


j = JSON.parse(resp.body)
auth_token = j['authorization']
warn "auth_token #{auth_token}"

# with the authoization, the return messaghe for the .account call is richer
resp = RestClient::Request.new({
                                 method: :get,
                                 url: 'http://localhost:3000/.account/',
                                 headers: { accept: 'application/json', authorization: "CSS-Account-Token #{auth_token}" }
                               }).execute
# puts resp.body

j = JSON.parse(resp.body)
credurl = j['controls']['account']["clientCredentials"]
warn "credurl #{credurl}"
webidurl = j['controls']['account']["webId"]
warn "webIdurl #{webidurl}"


resp = RestClient::Request.new({
                                 method: :get,
                                 url: webidurl,
                                 headers: { accept: 'application/json', authorization: "CSS-Account-Token #{auth_token}" }
                               }).execute
# puts resp.body

j = JSON.parse(resp.body)
webid = j['webIdLinks'].keys.first
warn "webid #{webid}"

payload = { "name": "my-token", "webId": "#{webid}" }.to_json
resp = RestClient::Request.new({
                                 method: :post,
                                 url: credurl,
                                 headers: { content_type: 'application/json', accept: 'application/json', authorization: "CSS-Account-Token #{auth_token}" },
                                 payload: payload
                               }).execute
# puts resp.body
j = JSON.parse(resp.body)
mytoken = j['id']
secret = j['secret']
authstring = "#{mytoken}:#{secret}"
warn "mytoken #{mytoken} secret #{secret} authstring #{authstring}"

resp = RestClient.get("http://localhost:3000/.well-known/openid-configuration")
j = JSON.parse(resp.body)
token_endpoint = j['token_endpoint']
warn "token endpoint #{token_endpoint}"

encoded_auth = Base64.strict_encode64(authstring)
private_key = OpenSSL::PKey::RSA.new(2048)
public_key = private_key.public_key

# public.to_pem = "-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDWW2CHr4l2TtJ9/T0TxsSwkZ9b\nzUK1BuS7sXC6MqdTbVK+Z0ltOs3I5wBD6qvcGoCfOe3p5GrAFTik7e14ip1f29pO\nF7lOI/Op8QR3awgtlYvAZdrXWcDvfNPQ0+I54clCpsOjC+ah1xfR+zA+q6aNSXqk\nn+Q2pX/4H3/Kw1xomQIDAQAB\n-----END PUBLIC KEY-----\n"
# private.to_pem =  "-----BEGIN RSA PRIVATE KEY-----\nMIICXgIBAAKBgQDWW2CHr4l2TtJ9/T0TxsSwkZ9bzUK1BuS7sXC6MqdTbVK+Z0lt\nOs3I5wBD6qvcGoCfOe3p5GrAFTik7e14ip1f29pOF7lOI/Op8QR3awgtlYvAZdrX\nWcDvfNPQ0+I54clCpsOjC+ah1xfR+zA+q6aNSXqkn+Q2pX/4H3/Kw1xomQIDAQAB\nAoGANQTxAV6nr32bjtIeU0/swoeiVQCWKVSFKu+epE93F6mIt9OwU7YhxDlu1V2s\nGIrtmXSopht7U/trwU+gVxpiBink8gEIazdWXiB+Wb+4o3GGoAJw49jxAjvFOMsR\nwC0RSzhftIYS/unNICw6HwSMjw8/jCjqtR2/NY5lPrt9dqECQQDs4afUu4tTOv6X\nV2ZbIcDMRISjnlIw+/sOkxYSzh5zDiqFiCH+LI23dqEDSTYBdsoFCu/wo9d02+pH\nISWswt1tAkEA56hUTD02U76NfQtQU5z4bEIPjcpVkApMQepdsutv4QwC+QqIUl6f\nh3NMTMysA5yUro3I1ClAMo/6DCAmq/bYXQJBAJomXqk5QnlvMq4Z2ioD1QsYq5gu\nNx5ZXA8n+H1UVMxas6Eh7b0SEUcKk80nn1VkkCKn82yNsnABjHutPm8mgCECQQC4\nWEN8x9lLmv+M2kv5vZgSzh8CfljIXumAKriVgLVvKNfUxoTkx1e7ugylsNnRpfDL\nVxjRfGIR2nDo5Uzg23YhAkEAj58bKTTFwqXjKzvFkfZFpb5Y0SbLRK+WKIPcdjRv\nmjIib/XmkUFAZF88rGKIbWMikTeY3SoPsMMAVWiDFmmk/w==\n-----END RSA PRIVATE KEY-----\n"

proof = Dpop.get_proof_with_key(private_key.to_pem, htu: token_endpoint, htm: "POST")
warn "proof #{proof}"


payload = 'grant_type=client_credentials&scope=webid'
resp = RestClient::Request.new({
                                 method: :post,
                                 url: token_endpoint,
                                 headers: { 
                                  content_type: 'application/x-www-form-urlencoded', 
                                  accept: 'application/json', 
                                  authorization: "Basic #{encoded_auth}",
                                  'dpop': proof  
                                },
                                payload: payload
                               }).execute
# puts resp.body
j = JSON.parse(resp.body)
access_token = j["access_token"]
warn "access_token #{access_token}"

resp = RestClient::Request.new({
                                 method: :get,
                                 url: "http://localhost:3000/markw/",
                                 headers: { 
                                  #accept: 'application/json', 
                                  authorization: "Bearer #{access_token}" }
                               }).execute
puts resp.body


#  resp2 = RestClient::Request.new({
#     method: :post,
#      url: 'http://localhost:3000/.account/account/4b6de802-29e1-498b-94cd-87092cca3166/pod/',
#     payload: 'this is a test',
#     headers: {content_type: 'text/plain', 'dpop' => proof, Authorization:"Bearer #{token}"}
#      }).execute

#      resp2 = RestClient::Request.new({
#     method: :get,
#    url: 'http://localhost:3000/markw/',
#  payload: 'this is a test',
#   headers: {content_type: 'text/plain', 'dpop' => proof, Authorization:"Bearer #{token}"}
#  }).execute
