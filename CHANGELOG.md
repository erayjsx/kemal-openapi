# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.5.0] - 2026-10-14

### Added

- Request validation now enforces `enum`, `minLength`, `maxLength`, `pattern`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf`, `minItems`, `maxItems`, `uniqueItems`, `additionalProperties`, `oneOf`, `anyOf` and `allOf`.
- Validation errors list every failure with a JSON Pointer in a new `errors` array; `message` still holds the first one.
- `Kemal::OpenAPI::Validator.errors_for(json, schema)` for validating data outside a route.
- `413` when the body exceeds `Kemal.config.max_request_body_size`, and `415` when the request `Content-Type` is not JSON.
- `parameters` and `security` keys in `@[OpenAPI]`; `security` also accepts a list of scheme names.
- `"default"` and range (`"5XX"`) response keys in `@[OpenAPI]`.
- Undocumented path parameters (`:id`, `*glob`) are added to the spec as required strings.
- New `Schema` properties: `exclusive_minimum`, `exclusive_maximum`, `multiple_of`, `min_items`, `max_items`, `unique_items`, `title`, `read_only`, `write_only`, `deprecated`.
- `schema_for` supports `Int64`/`UInt*`/`Float32`, `Time`, `UUID`, enums, typed arrays, sets and hashes, nested `JSON::Serializable` types, multi-type unions (`anyOf`), `JSON::Any` and fields with default values.
- GitHub Actions CI running specs on Crystal 1.19.1 and the latest release.

### Changed

- `Schema#type` is now nilable. When it is not set, `"object"` is still emitted unless the schema is a `$ref`, `enum` or pure `oneOf`/`anyOf`/`allOf`.
- `Response#status_code` is now `Int32?` (`nil` for `default` and range responses).
- The docs handler only answers `GET` and `HEAD` requests, and Swagger UI and ReDoc use the configured `title`.
- ReDoc is pinned to 2.5.4 instead of `latest`.
- Annotated routes are validated even when `setup`/`configure` is never called.
- The spec cache is refreshed whenever an operation, schema or security scheme is registered.

### Fixed

- `schema_for` failed to compile when called at the top level, as shown in the README.
- Schemas with only `oneOf`/`anyOf` rejected valid values because they were treated as objects.
- JSON parsing was attempted for `multipart/form-data` and other non-JSON request bodies, returning `400`.
- A non-string `schema:` in `request_body` (for example `array_of("User")`) did not compile.
- The `"default"` response key was emitted with extra quotes and status 200.
- Route blocks whose argument was not named `env` did not compile.

## [0.4.0]

- Kemal 1.11 support, idempotent `setup`/`configure`, failing validation for missing `$ref` schemas.

## [0.3.0]

- Kemal 1.10 support and stricter validation and macros.

## [0.2.0]

- Annotation support, runtime validation and OpenAPI 3.1.

## [0.1.0]

- Initial release.

[0.5.0]: https://github.com/erayjsx/kemal-openapi/compare/dc3c0bf...v0.5.0
