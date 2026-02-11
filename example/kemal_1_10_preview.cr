
# This is a preview of Kemal 1.10.0 features (TBD)
# This file is for reference and future implementation planning.
# It requires Kemal 1.10.0+ which is not yet released.

# Feature 1: Modular Router
# require "kemal"
#
# api = Kemal::Router.new
#
# api.namespace "/users" do
#   get "/" do |env|
#     env.json({users: ["alice", "bob"]})
#   end
#
#   get "/:id" do |env|
#     env.text "user #{env.params.url["id"]}"
#   end
# end
#
# mount "/api/v1", api
#
# Kemal.run

# Feature 2: Middleware 'use' keyword
# require "kemal"
#
# # Path-specific middlewares for /api routes
# use "/api", [CORSHandler.new, AuthHandler.new]
#
# get "/" do
#   "Public home"
# end
#
# get "/api/users" do |env|
#   env.json({users: ["alice", "bob"]})
# end
#
# Kemal.run

# Feature 3: Enhanced Response Helpers
# require "kemal"
#
# get "/users" do |env|
#   # Default JSON response
#   env.json({users: ["alice", "bob"]})
# end
#
# post "/users" do |env|
#   # Symbol-based HTTP::Status and chained JSON
#   env.status(:created).json({id: 1, created: true})
# end
#
# get "/admin" do |env|
#   # Halt immediately with HTML response
#   halt env.status(403).html("<h1>Forbidden</h1>")
# end
#
# get "/api/users" do |env|
#   # Custom content type (JSON:API)
#   env.json({data: ["alice", "bob"]}, content_type: "application/vnd.api+json")
# end
#
# Kemal.run
