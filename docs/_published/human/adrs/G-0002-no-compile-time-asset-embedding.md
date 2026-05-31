---
title: "G-0002: No Compile-Time Asset Embedding in Containerized Projects"
summary: "Serve static files at runtime via ServeDir rather than baking them into the binary at compile time; use Docker multi-stage builds for deployment."
primary-audience: agent
---

# G-0002: No Compile-Time Asset Embedding in Containerized Projects

**Status:** Accepted
**Date:** 2026-04-05

G-0002 is a governance ADR, a decision that applies across the whole ecosystem rather than to a single project.

## Context

Compile-time asset embedding (e.g., `rust_embed`) bakes frontend assets into the Rust binary when the binary is compiled. That causes two problems. First, every `cargo test`, `cargo clippy`, and coverage run has to do a full frontend build first. Second, `cargo-llvm-cov` needs the `--no-cfg-coverage` flag because the proc macro breaks under `cfg(coverage)`. Both problems block fast iteration, and the second one complicates the coverage toolchain.

## Decision

Don't use `rust_embed` or similar compile-time asset embedding in Rust projects deployed via Docker containers. Instead:

1. **Serve static files at runtime** using `tower_http::services::ServeDir` (or equivalent).
2. **Startup validation.** Verify the static directory exists on boot, and fail fast with a clear error if it's missing.
3. **Configurable static path** via TOML config with a sensible default.
4. **Docker multi-stage build** copies both the binary and the frontend build artifacts into the final image.
5. **Justfile** chains `frontend-build` before `run`/`release` for local dev convenience. Test and coverage recipes have no frontend dependency.

## Alternatives Considered

- **Keep `rust_embed` with workarounds** (`--no-cfg-coverage`, mandatory `frontend-build` dependency): Rejected because it adds permanent friction to every test and coverage cycle and creates a non-standard toolchain requirement.
- **Conditional compilation** (`#[cfg(not(coverage))]` to stub out embedding during coverage): Rejected because `--no-cfg-coverage` is required anyway, which makes this moot. Conditional compilation for testing is also a code smell. Proper dependency injection is cleaner.

## Consequences

- The binary is no longer fully self-contained. It requires the static directory at runtime. The Docker container provides that guarantee at the image layer instead of the binary layer.
- Running the binary outside Docker without the static directory gives 404s. Startup validation mitigates this.
- Backend builds, tests, and coverage runs are fully independent of the frontend build.
- The `--no-cfg-coverage` hack is eliminated.
- Applies to all Rust + frontend + Docker projects.
