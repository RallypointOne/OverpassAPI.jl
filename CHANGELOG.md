## Unreleased

## v0.1.1 (2026-09-08)

### Fixes

- `query` merges `[out:json]` and the `bbox` keyword into an existing settings statement instead of emitting a second one, which Overpass rejects.
- `query` sends a URL-encoded form body instead of multipart, which the Overpass server rejected with HTTP 400.
- Requests now send a `User-Agent` header identifying the package.
- `query(::QLStatement)` docstring no longer lists `out=:count`.

### Tests / CI

- Added an opt-in live-service test suite (`test/test_service.jl`), enabled via `OVERPASS_LIVE_TESTS=true` with an optional `OVERPASS_ENDPOINT` mirror override, plus a `LiveTests` workflow.
- Synced with `JuliaPackageTemplate`: docs moved to an `assets/` + `pages/` layout, Docs workflows updated, `TagBot.yml` permissions block dropped to match the template.
- Bumped GitHub Actions: `actions/checkout` to v7, `julia-actions/setup-julia` to v3, `actions/cache` to v3; added a Dependabot auto-merge workflow.

### Dependencies

- Widened the `HTTP` compat bound to allow `2.0`.
