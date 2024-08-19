require "solid-community-client-simple"
s = SOLID::CommunityClient.new(server: "http://localhost:3000/", username: "mark.wilkinson@upm.es", password: "markw")
s.login
at = s.get_current_access_token(webid: "http://localhost:3000/markw/profile/card#me", name: "codetest")
dpop = s.prepare_dpop(url: "http://localhost:3000/markw/", method: "get")
res = s.execute_with_proof(dpop: dpop, data: "", content_type: "text/turtle", current_access_token: at)
puts res.body
