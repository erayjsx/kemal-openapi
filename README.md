# kemal-openapi

[![CI](https://github.com/erayjsx/kemal-openapi/actions/workflows/ci.yml/badge.svg)](https://github.com/erayjsx/kemal-openapi/actions/workflows/ci.yml)

OpenAPI 3.1 documentation generator for [Kemal](https://kemalcr.com). Describe your routes with an annotation, and kemal-openapi generates the OpenAPI spec, validates request bodies against it, and serves Swagger UI and ReDoc.

## Features

- **OpenAPI 3.1.0** spec generation
- **Annotation-based** route definitions (`@[OpenAPI(...)]`)
- **Runtime request validation** of JSON bodies: types, `required`, `enum`, string length and `pattern`, numeric bounds, array size and uniqueness, `additionalProperties`, `oneOf` / `anyOf` / `allOf`, and `$ref`
- **Schemas from your types**: `schema_for(User)` builds a schema from any `JSON::Serializable` class
- Path parameters (`:id`, `*glob`) are documented automatically
- Built-in **Swagger UI** at `/docs`, **ReDoc** at `/redoc`, and the JSON spec at `/openapi.json`
- Reusable schema components and security schemes (Bearer, API key, OAuth2)

## Installation

Requirements: Crystal `>= 1.19.1` and Kemal `~> 1.11`.

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  kemal-openapi:
    github: erayjsx/kemal-openapi
    version: ~> 0.5.0
```

Then run `shards install`.

## Quick start

```crystal
require "kemal"
require "kemal-openapi"

class User
  include JSON::Serializable

  property id : Int64
  property name : String
  property email : String
  property nickname : String? # nilable, so optional
end

# Register the schema so it appears under components/schemas
Kemal::OpenAPI.register_schema("User", Kemal::OpenAPI.schema_for(User))
Kemal::OpenAPI.register_security_scheme("bearerAuth", Kemal::OpenAPI.bearer_auth)

@[OpenAPI(
  summary: "Create user",
  tags: ["Users"],
  request_body: {description: "User data", schema: "User"},
  responses: {
    201       => {description: "User created", schema: "User"},
    422       => "Validation error",
    "default" => "Unexpected error",
  },
  security: ["bearerAuth"]
)]
post "/users" do |env|
  # The body has already been validated against the "User" schema here.
  user = User.from_json(env.request.body.not_nil!)
  env.response.status_code = 201
  user.to_json
end

@[OpenAPI(
  summary: "Get user",
  tags: ["Users"],
  parameters: [Kemal::OpenAPI.param("fields", description: "Comma separated field list")],
  responses: {200 => {description: "User", schema: "User"}, 404 => "Not found"}
)]
get "/users/:id" do |env|
  # `id` is documented as a required path parameter automatically.
  # ...
end

Kemal::OpenAPI.setup(title: "My API", version: "1.0.0")
Kemal.run
```

Then visit:

- **Swagger UI**: http://localhost:3000/docs
- **ReDoc**: http://localhost:3000/redoc
- **JSON spec**: http://localhost:3000/openapi.json

## The `@[OpenAPI]` annotation

Put the annotation directly above a `get`, `post`, `put`, `patch`, `delete` or `options` route. The path must be a string literal.

| Key | Value |
| --- | --- |
| `summary`, `description`, `operation_id` | Strings |
| `tags` | `["Users"]` |
| `deprecated` | `true` |
| `parameters` | An array of `Kemal::OpenAPI::Parameter`, usually built with `Kemal::OpenAPI.param(...)`. Path parameters you leave out are added as required strings. |
| `security` | Scheme names (`["bearerAuth"]`) or full requirements (`[{"oauth" => ["write"]}]`) |
| `request_body` | A schema (see below), or `{schema:, description:, required:, content_type:}`. `required` defaults to `true` and `content_type` to `"application/json"`. |
| `responses` | `{200 => "OK", 404 => {description: "Not found", schema: "Error"}, "default" => "Error"}`. Keys can be numbers, `"default"` or ranges like `"5XX"`. |

Wherever a schema is expected you can pass:

- a string, which becomes a `$ref` to a registered schema (`"User"`)
- a named tuple of `Schema` properties (`{type: "string", min_length: 3}`)
- any expression returning a `Schema` (`Kemal::OpenAPI.array_of("User")`, `Kemal::OpenAPI.schema_for(User)`)

## Request validation

When a route documents a JSON request body, the body is validated **before** your route block runs. Validation works even if you never call `setup`.

| Situation | Status |
| --- | --- |
| Body missing but required, or not valid JSON | `400 Bad Request` |
| Body larger than `Kemal.config.max_request_body_size` | `413 Payload Too Large` |
| `Content-Type` header present but not JSON | `415 Unsupported Media Type` |
| Body does not match the schema | `422 Unprocessable Entity` |

Every failure is reported, each with a [JSON Pointer](https://www.rfc-editor.org/rfc/rfc6901) to the offending value:

```json
{
  "error": "validation_error",
  "message": "Missing required field: email",
  "errors": [
    {"pointer": "", "message": "Missing required field: email"},
    {"pointer": "/age", "message": "Must be greater than or equal to 18"}
  ]
}
```

Properties marked `read_only: true` are not required in requests. Request bodies with other media types (for example `multipart/form-data`) are documented but not validated, so Kemal parses them as usual.

You can also validate data yourself:

```crystal
errors = Kemal::OpenAPI::Validator.errors_for(JSON.parse(payload), schema)
errors.each { |e| puts "#{e.pointer}: #{e.message}" }
```

## Schemas from Crystal types

`Kemal::OpenAPI.schema_for(Type)` reads the instance variables of a `JSON::Serializable` type:

| Crystal type | Schema |
| --- | --- |
| `String`, `Char` | `string` |
| `Int32` (and smaller), `Int64`, `UInt*` | `integer` with `int32` / `int64` format; unsigned types get `minimum: 0` |
| `Float32`, `Float64` | `number` with `float` / `double` format |
| `Bool` | `boolean` |
| `Time` | `string`, `date-time` |
| `UUID` | `string`, `uuid` |
| `Array(T)`, `Set(T)`, `Deque(T)` | `array` with typed `items` (`uniqueItems` for `Set`) |
| `Hash(String, V)` | `object` with typed `additionalProperties` |
| Enums | `string` with the serialized member names as `enum` |
| Other `JSON::Serializable` types | Inlined object schema |
| `T?` | Nullable `T`, not required |
| `A \| B` | `anyOf` |
| `JSON::Any` | Any value |

`@[JSON::Field(key: ...)]` and `@[JSON::Field(ignore: true)]` are respected, and fields with a default value are optional. Nested types are inlined up to four levels deep; to share a nested type, register it with `register_schema` and reference it by name instead.

## Configuration

```crystal
Kemal::OpenAPI.setup(
  title: "My API",
  version: "1.0.0",
  description: "Everything about my API",
  spec_path: "/openapi.json",
  docs_path: "/docs",
  redoc_path: "/redoc", # nil disables ReDoc
  servers: [Kemal::OpenAPI::Server.new(url: "https://api.example.com")],
  tags: [Kemal::OpenAPI::Tag.new(name: "Users", description: "User operations")],
  global_security: [{"bearerAuth" => [] of String}],
  # Kemal settings, passed through when given:
  max_request_body_size: 1024 * 1024,
  shutdown_timeout: 10.seconds,
  max_multipart_form_field_size: 16 * 1024 * 1024,
  websocket_allowed_origins: ["https://myapp.com"]
)
```

Or use the block form for full control over the builder:

```crystal
Kemal::OpenAPI.configure do |builder|
  builder.info = Kemal::OpenAPI::Info.new(title: "My API", version: "1.0.0")
end
```

`setup` and `configure` are idempotent, and the generated spec is cached and refreshed whenever an operation, schema or security scheme is registered.

## Manual registration

If you prefer not to use annotations, register operations directly:

```crystal
Kemal::OpenAPI.register(
  Kemal::OpenAPI::Operation.new(
    method: "get",
    path: "/api/users",
    summary: "List all users",
    tags: ["Users"],
    responses: Kemal::OpenAPI.responses({200 => "User list"})
  )
)
```

Request bodies of manually registered operations are validated as well. See [`example/app.cr`](example/app.cr) for a complete application.

## Development

```sh
shards install
crystal spec
crystal tool format --check
```

## Contributing

1. Fork it (<https://github.com/erayjsx/kemal-openapi/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Eray can Topcu](https://github.com/erayjsx) - creator and maintainer

## Acknowledgments

Thanks to the Crystal and Kemal communities for their support.

## License

MIT. See [LICENSE](LICENSE).
