require "kemal"
require "../src/kemal-openapi"

# ============================================================
# Model definitions
# ============================================================

class User
  include JSON::Serializable

  property id : Int32
  property name : String
  property email : String
  property role : String
  property created_at : String?

  def initialize(@id, @name, @email, @role = "user", @created_at = nil)
  end
end

# ============================================================
# In-memory data store
# ============================================================

USERS = [
  User.new(1, "Eray", "eray@example.com", "admin", "2024-01-01"),
  User.new(2, "Ahmet", "ahmet@example.com", "user", "2024-02-15"),
  User.new(3, "Ayse", "ayse@example.com", "user", "2024-03-20"),
]

START_TIME = Time.instant

# ============================================================
# Schema definitions
# ============================================================

user_schema = Kemal::OpenAPI::Schema.new(
  type: "object",
  properties: {
    "id"         => Kemal::OpenAPI::Schema.new(type: "integer", format: "int32"),
    "name"       => Kemal::OpenAPI::Schema.new(type: "string"),
    "email"      => Kemal::OpenAPI::Schema.new(type: "string", format: "email"),
    "role"       => Kemal::OpenAPI::Schema.new(type: "string", enum_values: ["admin", "user", "moderator"]),
    "created_at" => Kemal::OpenAPI::Schema.new(type: "string", format: "date-time", nullable: true),
  },
  required: ["id", "name", "email"]
)

create_user_schema = Kemal::OpenAPI::Schema.new(
  type: "object",
  properties: {
    "name"  => Kemal::OpenAPI::Schema.new(type: "string", min_length: 2, max_length: 100),
    "email" => Kemal::OpenAPI::Schema.new(type: "string", format: "email"),
    "role"  => Kemal::OpenAPI::Schema.new(type: "string", enum_values: ["admin", "user", "moderator"]),
  },
  required: ["name", "email"]
)

error_schema = Kemal::OpenAPI::Schema.new(
  type: "object",
  properties: {
    "error"   => Kemal::OpenAPI::Schema.new(type: "string"),
    "message" => Kemal::OpenAPI::Schema.new(type: "string"),
  },
  required: ["error", "message"]
)

# Register schemas (will appear under components/schemas)
Kemal::OpenAPI.register_schema("User", user_schema)
Kemal::OpenAPI.register_schema("CreateUser", create_user_schema)
Kemal::OpenAPI.register_schema("Error", error_schema)

# ============================================================
# Security schemes
# ============================================================

Kemal::OpenAPI.register_security_scheme("bearerAuth", Kemal::OpenAPI.bearer_auth("JWT Bearer token"))
Kemal::OpenAPI.register_security_scheme("apiKey", Kemal::OpenAPI.api_key_auth)

# ============================================================
# Routes and OpenAPI documentation
# ============================================================

# --- GET /api/users ---
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "get",
    path: "/api/users",
    summary: "List all users",
    description: "Returns a list of users with pagination and role filtering support.",
    operation_id: "listUsers",
    tags: ["Users"],
    parameters: [
      Kemal::OpenAPI.param("page", type: "integer", description: "Page number"),
      Kemal::OpenAPI.param("per_page", type: "integer", description: "Items per page"),
      Kemal::OpenAPI.param("role", type: "string", description: "Filter by role"),
    ],
    responses: {
      "200" => Kemal::OpenAPI::Response.new(
        status_code: 200,
        description: "User list",
        schema: Kemal::OpenAPI.array_of("User")
      ),
      "401" => Kemal::OpenAPI::Response.new(
        status_code: 401,
        description: "Unauthorized",
        schema: Kemal::OpenAPI.ref("Error")
      ),
    },
    security: [{"bearerAuth" => [] of String}]
  )
)

get "/api/users" do |env|
  env.response.content_type = "application/json"
  role = env.params.query["role"]?
  users = role ? USERS.select { |u| u.role == role } : USERS
  users.to_json
end

# --- GET /api/users/:id ---
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "get",
    path: "/api/users/:id",
    summary: "Get user by ID",
    description: "Returns a single user by their ID.",
    operation_id: "getUser",
    tags: ["Users"],
    parameters: [
      Kemal::OpenAPI.param("id", location: "path", type: "integer", description: "User ID"),
    ],
    responses: {
      "200" => Kemal::OpenAPI::Response.new(
        status_code: 200,
        description: "User details",
        schema: Kemal::OpenAPI.ref("User")
      ),
      "404" => Kemal::OpenAPI::Response.new(
        status_code: 404,
        description: "User not found",
        schema: Kemal::OpenAPI.ref("Error")
      ),
    }
  )
)

get "/api/users/:id" do |env|
  env.response.content_type = "application/json"
  id = env.params.url["id"].to_i
  user = USERS.find { |u| u.id == id }
  if user
    user.to_json
  else
    env.response.status_code = 404
    {error: "not_found", message: "User not found"}.to_json
  end
end

# --- POST /api/users ---
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "post",
    path: "/api/users",
    summary: "Create a new user",
    description: "Creates a new user and returns the created resource.",
    operation_id: "createUser",
    tags: ["Users"],
    request_body: Kemal::OpenAPI::RequestBody.new(
      description: "User data",
      schema: Kemal::OpenAPI.ref("CreateUser")
    ),
    responses: {
      "201" => Kemal::OpenAPI::Response.new(
        status_code: 201,
        description: "User created",
        schema: Kemal::OpenAPI.ref("User")
      ),
      "422" => Kemal::OpenAPI::Response.new(
        status_code: 422,
        description: "Invalid data",
        schema: Kemal::OpenAPI.ref("Error")
      ),
    },
    security: [{"bearerAuth" => [] of String}]
  )
)

post "/api/users" do |env|
  env.response.content_type = "application/json"
  body = env.request.body.try(&.gets_to_end) || "{}"
  data = JSON.parse(body)

  name = data["name"]?.try(&.as_s)
  email = data["email"]?.try(&.as_s)

  unless name && email
    env.response.status_code = 422
    next {error: "validation_error", message: "name and email are required"}.to_json
  end

  new_id = USERS.max_of(&.id) + 1
  role = data["role"]?.try(&.as_s) || "user"
  user = User.new(new_id, name, email, role)
  USERS << user
  env.response.status_code = 201
  user.to_json
end

# --- DELETE /api/users/:id ---
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "delete",
    path: "/api/users/:id",
    summary: "Delete a user",
    operation_id: "deleteUser",
    tags: ["Users"],
    parameters: [
      Kemal::OpenAPI.param("id", location: "path", type: "integer", description: "User ID"),
    ],
    responses: {
      "204" => Kemal::OpenAPI::Response.new(status_code: 204, description: "Successfully deleted"),
      "404" => Kemal::OpenAPI::Response.new(
        status_code: 404,
        description: "User not found",
        schema: Kemal::OpenAPI.ref("Error")
      ),
    },
    security: [{"bearerAuth" => [] of String}]
  )
)

delete "/api/users/:id" do |env|
  env.response.content_type = "application/json"
  id = env.params.url["id"].to_i
  idx = USERS.index { |u| u.id == id }
  if idx
    USERS.delete_at(idx)
    env.response.status_code = 204
    ""
  else
    env.response.status_code = 404
    {error: "not_found", message: "User not found"}.to_json
  end
end

# --- GET /api/health ---
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "get",
    path: "/api/health",
    summary: "Health check",
    description: "Check if the API is running.",
    operation_id: "healthCheck",
    tags: ["System"],
    responses: {
      "200" => Kemal::OpenAPI::Response.new(
        status_code: 200,
        description: "API is running",
        schema: Kemal::OpenAPI::Schema.new(
          type: "object",
          properties: {
            "status" => Kemal::OpenAPI::Schema.new(type: "string"),
            "uptime" => Kemal::OpenAPI::Schema.new(type: "number"),
          }
        )
      ),
    }
  )
)

get "/api/health" do |env|
  env.response.content_type = "application/json"
  elapsed = Time.instant - START_TIME
  {status: "ok", uptime: elapsed.total_seconds}.to_json
end

# ============================================================
# Configure OpenAPI documentation and start the server
# ============================================================

Kemal::OpenAPI.setup(
  title: "User Management API",
  version: "1.0.0",
  description: "A sample user management API built with Kemal.\n\n" \
               "This API demonstrates how to use the kemal-openapi library.",
  servers: [
    Kemal::OpenAPI::Server.new(url: "http://localhost:3000", description: "Development"),
  ],
  tags: [
    Kemal::OpenAPI::Tag.new(name: "Users", description: "User operations"),
    Kemal::OpenAPI::Tag.new(name: "System", description: "System operations"),
  ],
  global_security: [{"bearerAuth" => [] of String}]
)

puts "==================================="
puts " Swagger UI:   http://localhost:3000/docs"
puts " ReDoc:        http://localhost:3000/redoc"
puts " OpenAPI JSON: http://localhost:3000/openapi.json"
puts "==================================="

Kemal.run
