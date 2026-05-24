---
title: "G-0005: SQL File-Based Migrations for Embedded SQLite"
summary: "Migrations live as SQL files embedded at compile time via include_str!; a generic migration runner tracks schema version; forward-only migrations."
primary-audience: agent
---

# G-0005: SQL File-Based Migrations for Embedded SQLite

**Status:** Accepted
**Date:** 2026-04-10

## Context

Inline SQL strings for each schema version in a `migrate()` function accumulate Rust code per migration — increasing code churn, merge conflicts, and mixing schema definition with application logic. The migration runner should be generic; new schema changes should require only a new `.sql` file.

## Decision

Use SQL file-based migrations embedded at compile time for all Rust projects with embedded SQLite.

- Migrations live in `migrations/NNNN_<description>.sql` (e.g., `migrations/0001_initial.sql`)
- SQL files are embedded into the binary via `include_str!()` — no runtime file dependency
- A generic migration runner reads `schema_version`, determines which migrations haven't been applied, and runs them in order
- Migrations should be written in idempotent style where SQL supports it (`CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`). For operations that aren't inherently idempotent (`ALTER TABLE ADD COLUMN`), the version-tracking table serves as the guard
- The migration runner is shared code — extracted to a common crate or pattern, not reimplemented per project
- Forward-only migrations. No down migrations — they add complexity and are rarely used in practice with embedded databases

## Alternatives Considered

**Inline SQL in Rust (status quo):** Works but doesn't scale. Each migration adds Rust code, increases the function's complexity, and mixes schema with logic. Rejected because it creates unnecessary code churn.

**External SQL files loaded at runtime:** Migrations as separate files read from disk at startup. Rejected because it introduces a runtime dependency on file paths — the embedded binary should be self-contained.

**Full migration framework (refinery, sqlx-migrate):** Purpose-built migration tools exist in the Rust ecosystem. Not rejected outright — worth evaluating if the hand-rolled runner proves insufficient. But for the current scope (simple embedded SQLite), a lightweight `include_str!()` approach avoids a new dependency.

**Embedded scripting (Rhai/Lua) for migrations:** Interest in embedded scripting for minimizing code churn. Deferred — SQL files are the right level of abstraction for schema changes. Scripting may have value for more complex data transformations in future.

## Consequences

- New schema changes are a new `.sql` file — no Rust code changes to the migration runner
- Existing projects should be migrated to this pattern when next touching their database layer
- The `migrations/` directory becomes part of the standard project template
- Developers can read the migration history as plain SQL without understanding Rust
