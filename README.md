# SOLID Client for the SOLID Community Server

Talk to SOLID Pods

# This is not guaranteed to be useful for any purpose whatsoever

If you want an idea of what's happening behind the scenes, have a look at this Gist:  
https://gist.github.com/markwilkinson/c5e819ae08d3753b1ee63edb2a504401


Note that this was created for a specific project, with a short timeline.  It currently does only the things
I need it to do!  It is not, in any way a full-featured SOLID POD library!  Having said that, it does get you through all of the stages of login and to the point of having a DPOP proof that allows you to interact in an LDP-style manner with the POD (e.g. creating/updating/deleting Resources and/or Containers)

Future iterations will be much more powerful, as my requirements grow through the life of my project.

Example Interaction

```
# this assumes you are running the SOLID Community Client docker image exposing port 3000
# you must have already set-up a login and have a POD on that server to talk to!

require "solid-community-client-simple"
s = SOLID::CommunityClient.new(server: "http://localhost:3000/", username: "mark.wilkinson@upm.es", password: "markw")
s.login
at = s.get_current_access_token(webid: "http://localhost:3000/markw/profile/card#me", name: "codetest")
dpop = s.prepare_dpop(url: "http://localhost:3000/markw/", method: "get")
res = s.execute_with_proof(dpop: dpop, data: "", content_type: "text/turtle", current_access_token: at)
puts res.body

```

Please share bug reports via the Issues, but please also be aware that this is not (yet!) intended for widespread use.  I simply found the documentation for interacting with the Community Server to be... extremely frustrating!  (documentation should not be via software snippets!).  Anyway, to avoid anyone else having to figure out what the javascript in that documentation is doing, I have captured it in this code, and in the Gist linked above.

Enjoy!