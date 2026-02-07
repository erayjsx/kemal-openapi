# kemal-openapi

OpenAPI 3.0 documentation generator for [Kemal](https://kemalcr.com). Automatically generates Swagger/OpenAPI specs and serves Swagger UI & ReDoc.

## Features

- OpenAPI 3.0.3 spec generation
- Built-in Swagger UI at `/docs`
- Built-in ReDoc at `/redoc`
- JSON spec endpoint at `/openapi.json`
- Schema components & `$ref` support
- Security schemes (Bearer, API Key, OAuth2)
- Path parameter auto-detection (`:id` -> `{id}`)
- Spec caching with manual invalidation
- DSL helpers for rapid development
- Compile-time schema generation from `JSON::Serializable` types

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  kemal-openapi:
    github: erayjsx/kemal-openapi
```

```sh
shards install
```

## Quick Start

```crystal
require "kemal"
require "kemal-openapi"

# Register an operation
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "get",
    path: "/api/users",
    summary: "List all users",
    tags: ["Users"],
    responses: {
      "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "User list"),
      "401" => Kemal::OpenAPI::Response.new(status_code: 401, description: "Unauthorized"),
    }
  )
)

get "/api/users" do |env|
  env.response.content_type = "application/json"
  [{ "id": 1, "name": "Eray" }].to_json
end

# Enable OpenAPI docs
Kemal::OpenAPI.setup(
  title: "My API",
  version: "1.0.0"
)

Kemal.run
```

Then visit:
- **Swagger UI**: http://localhost:3000/docs
- **ReDoc**: http://localhost:3000/redoc
- **JSON Spec**: http://localhost:3000/openapi.json

## Usage

### Defining Schemas

```crystal
# Manual schema
user_schema = Kemal::OpenAPI::Schema.new(
  type: "object",
  properties: {
    "id"    => Kemal::OpenAPI::Schema.new(type: "integer", format: "int32"),
    "name"  => Kemal::OpenAPI::Schema.new(type: "string"),
    "email" => Kemal::OpenAPI::Schema.new(type: "string", format: "email"),
    "role"  => Kemal::OpenAPI::Schema.new(type: "string", enum_values: ["admin", "user"]),
  },
  required: ["id", "name", "email"]
)

# Register as a reusable component
Kemal::OpenAPI.register_schema("User", user_schema)
```

#### Auto-generate from JSON::Serializable

```crystal
class User
  include JSON::Serializable
  property id : Int32
  property name : String
  property email : String
  property bio : String?
end

# Macro generates schema from type info
schema = Kemal::OpenAPI.schema_for(User)
Kemal::OpenAPI.register_schema("User", schema)
```

### DSL Helpers

```crystal
# $ref shortcuts
Kemal::OpenAPI.ref("User")           # => {"$ref": "#/components/schemas/User"}
Kemal::OpenAPI.array_of("User")      # => {"type": "array", "items": {"$ref": "..."}}

# Quick parameter creation
Kemal::OpenAPI.param("page", type: "integer", description: "Page number")
Kemal::OpenAPI.param("id", location: "path", type: "integer")  # auto-required

# Quick response map
Kemal::OpenAPI.responses({200 => "OK", 404 => "Not Found"})

# Security scheme helpers
Kemal::OpenAPI.bearer_auth("JWT token")
Kemal::OpenAPI.api_key_auth(name: "X-API-Key", location: "header")
```

### Request Body

```crystal
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "post",
    path: "/api/users",
    summary: "Create user",
    tags: ["Users"],
    request_body: Kemal::OpenAPI::RequestBody.new(
      description: "User data",
      schema: Kemal::OpenAPI.ref("CreateUser")
    ),
    responses: {
      "201" => Kemal::OpenAPI::Response.new(
        status_code: 201,
        description: "Created",
        schema: Kemal::OpenAPI.ref("User")
      ),
    }
  )
)
```

### Security

```crystal
# Register security scheme
Kemal::OpenAPI.register_security_scheme("bearerAuth",
  Kemal::OpenAPI.bearer_auth
)

# Apply globally
Kemal::OpenAPI.setup(
  title: "My API",
  version: "1.0.0",
  global_security: [{"bearerAuth" => [] of String}]
)

# Or per-operation
Kemal::OpenAPI::Operation.new(
  # ...
  security: [{"bearerAuth" => [] of String}]
)
```

### Advanced Configuration

```crystal
Kemal::OpenAPI.configure do |config|
  config.info = Kemal::OpenAPI::Info.new(
    title: "My API",
    version: "2.0.0",
    description: "Full API documentation",
    contact: Kemal::OpenAPI::Contact.new(
      name: "Dev Team",
      email: "dev@example.com"
    ),
    license: Kemal::OpenAPI::License.new(name: "MIT")
  )

  config.servers = [
    Kemal::OpenAPI::Server.new(url: "https://api.example.com", description: "Production"),
    Kemal::OpenAPI::Server.new(url: "http://localhost:3000", description: "Development"),
  ]

  config.tags = [
    Kemal::OpenAPI::Tag.new(name: "Users", description: "User operations"),
    Kemal::OpenAPI::Tag.new(name: "Auth", description: "Authentication"),
  ]
end
```

### Custom Paths

```crystal
Kemal::OpenAPI.setup(
  title: "My API",
  version: "1.0.0",
  spec_path: "/api/v1/openapi.json",
  docs_path: "/api/v1/docs",
  redoc_path: "/api/v1/redoc"
)
```

## Example

See [example/app.cr](example/app.cr) for a full working example with CRUD operations, schemas, and security.

```sh
crystal run example/app.cr
```

## Development

```sh
shards install
crystal spec
```

## Contributing

1. Fork it (<https://github.com/erayjsx/kemal-openapi/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Eray can Topcu](https://github.com/erayjsx) - creator and maintainer

## License

MIT
