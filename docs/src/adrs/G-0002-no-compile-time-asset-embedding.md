---
title: "G-0002: No Compile-Time Asset Embedding in Containerized Projects"
summary: "Serve static files at runtime via ServeDir rather than baking them into the binary at compile time; use Docker multi-stage builds for deployment."
primary-audience: agent
---

# G-0002: No Compile-Time Asset Embedding in Containerized Projects

**Status:** Accepted
**Date:** 2026-04-05

## Context

Compile-time asset embedding (e.g., `rust_embed`) bakes frontend assets into the Rust binary at compile time. This creates two problems: (1) every `cargo test`, `cargo clippy`, and coverage run requires a full frontend build first, and (2) `cargo-llvm-cov` needs the `--no-cfg-coverage` flag because the proc macro breaks under `cfg(coverage)`. Both problems block fast iteration and complicate the coverage toolchain.

## Decision

Do not use `rust_embed` or similar compile-time asset embedding in Rust projects deployed via Docker containers. Instead:

1. **Serve static files at runtime** using `tower_http::services::ServeDir` (or equivalent).
2. **Startup validation** — verify the static directory exists on boot, fail fast with a clear error if missing.
3. **Configurable static path** via TOML config with a sensible default.
4. **Docker multi-stage build** copies both the binary and frontend build artifacts into the final image.
5. **Justfile** chains `frontend-build` before `run`/`release` for local dev convenience, but test/coverage recipes have no frontend dependency.

## Alternatives Considered

- **Keep `rust_embed` with workarounds** (`--no-cfg-coverage`, mandatory `frontend-build` dependency): Rejected because it adds permanent friction to every test/coverage cycle and creates a non-standard toolchain requirement.
- **Conditional compilation** (`#[cfg(not(coverage))]` to stub out embedding during coverage): Rejected because `--no-cfg-coverage` is required anyway, making this moot. Also, conditional compilation for testing is a code smell — proper dependency injection is cleaner.

## Consequences

- Binary is no longer fully self-contained — requires the static directory at runtime. Docker container provides this guarantee at the image layer instead of the binary layer.
- Running the binary outside Docker without the static directory gives 404s. Startup validation mitigates this.
- Backend builds, tests, and coverage runs are fully independent of the frontend build.
- `--no-cfg-coverage` hack is eliminated.
- Applies to all Rust + frontend + Docker projects.
