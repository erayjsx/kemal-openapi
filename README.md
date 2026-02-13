
# kemal-openapi

OpenAPI 3.1 documentation generator for [Kemal](https://kemalcr.com). Automatically generates Swagger/OpenAPI specs, validates requests at runtime, and serves Swagger UI & ReDoc.

## Features

- **OpenAPI 3.1.0** spec generation
- **Annotation-based** route definitions (`@[OpenAPI(...)]`)
- **Runtime Request Validation** (automatically validates request body against schema)
- Built-in **Swagger UI** at `/docs`
- Built-in **ReDoc** at `/redoc`
- JSON spec endpoint at `/openapi.json`
- Schema components & `$ref` support
- Security schemes (Bearer, API Key, OAuth2)
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

### 1. Define your models

```crystal
require "json"
require "kemal-openapi"

class User
  include JSON::Serializable
  property id : Int32
  property name : String
  property email : String
end

# Register the schema for reuse
Kemal::OpenAPI.register_schema("User", Kemal::OpenAPI.schema_for(User))
```

### 2. Annotate your routes

```crystal
require "kemal"

@[OpenAPI(
  summary: "Create user",
  tags: ["Users"],
  request_body: {
    description: "User data",
    schema: "User", # References the registered "User" schema
    required: true
  },
  responses: {
    201: {description: "User created", schema: "User"},
    422: {description: "Validation error"}
  }
)]
post "/users" do |env|
  # If execution reaches here, the request body is GUARANTEED to be valid
  # according to the "User" schema.
  
  user = User.from_json(env.request.body.not_nil!)
  env.response.status_code = 201
  user.to_json
end

@[OpenAPI(
  summary: "List users",
  tags: ["Users"],
  responses: {
    200: {description: "List of users", schema: Kemal::OpenAPI.array_of("User")}
  }
)]
get "/users" do |env|
  [{id: 1, name: "Alice", email: "alice@example.com"}].to_json
end
```

### 3. Setup and Run

```crystal
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

## Automatic Validation

When you define a `request_body` with a schema in your annotation, `kemal-openapi` automatically validates incoming requests **before** your route handler is executed.

If the validation fails (e.g. missing required fields, wrong data types), the server automatically responds with:
- **Status**: `400 Bad Request` (invalid JSON) or `422 Unprocessable Entity` (schema validation failure)
- **Body**: `{"error": "validation_error", "message": "..."}`

You don't need to write manual validation code for your schemas!

## Manual Usage (DSL)

If you prefer not to use annotations, you can still use the manual registration API:

```crystal
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "get",
    path: "/api/users",
    summary: "List all users",
    tags: ["Users"],
    responses: {
      "200" => Kemal::OpenAPI::Response.new(status_code: 200, description: "User list"),
    }
  )
)
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


## Acknowledgments

Thanks to the Crystal and Kemal communities for their support.

MIT
