# Contributing

Thanks for helping improve kemal-openapi.

## Setup

```sh
shards install
crystal build lib/ameba/src/cli.cr -o bin/ameba
```

## Before opening a pull request

```sh
crystal spec
crystal tool format --check
bin/ameba
crystal build --no-codegen example/app.cr
```

CI runs the same checks on the oldest supported Crystal version (see `shard.yml`) and the latest release.

## Guidelines

- Keep pull requests focused on one change and add specs for new behaviour or fixed bugs.
- Annotated routes in specs are global, so give their paths a unique prefix (for example `/__my_feature/...`).
- Add an entry under `Unreleased` in `CHANGELOG.md` for anything users will notice.
- Public API changes need README updates.

## Releasing

1. Move the `Unreleased` entries in `CHANGELOG.md` under a new version heading.
2. Bump `version` in `shard.yml` and `Kemal::OpenAPI::VERSION` (a spec checks they match).
3. Merge, then tag the merge commit as `vX.Y.Z` and publish a GitHub release.
