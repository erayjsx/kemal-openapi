# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.6.0] - Unreleased

### Added

- Query, path, header and cookie parameters are validated against their schemas. String values are converted to the schema type first; failures return `422` with `in` set to the parameter location.
- `validate_responses` (`Kemal::OpenAPI.validate_responses = true` or `setup(validate_responses: true)`) logs routes whose JSON responses do not match the documented schema.
- `operationId`s are generated for operations that lack one (`getUsersById`); turn off with `setup(auto_operation_ids: false)`.
- `register_schema_for(Type)` registers a type and its nested types as components linked by `$ref`; `schema_for` takes `refs: true` for the same behaviour.
- Spec export: `KEMAL_OPENAPI_EXPORT=openapi.json crystal run src/app.cr`, `Kemal::OpenAPI.write_spec` and `Kemal::OpenAPI.spec_json`.
- `Kemal::OpenAPI::Registry` for serving several independent API descriptions; `Builder.new(registry:)` and `Validator.validate(..., registry:)` accept one.
- Nullable `$ref` schemas are emitted as `anyOf: [$ref, {type: null}]`.
- Ameba linting, Dependabot for GitHub Actions, issue and pull request templates, CONTRIBUTING.md and SECURITY.md.

### Changed

- The handler's spec cache follows the registry's version instead of being invalidated by the module helpers.
- Validation error objects include an `in` field.

### Fixed

- Route blocks whose argument is `_` did not compile.

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

- Requires Kemal `~> 1.14` (was `~> 1.11`).
- Swagger UI updated from 5.18.2 to 5.33.1.
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

[0.6.0]: https://github.com/erayjsx/kemal-openapi/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/erayjsx/kemal-openapi/compare/v0.4.0...v0.5.0
