---
title: "G-0005: SQL File-Based Migrations for Embedded SQLite"
summary: "Migrations live as SQL files embedded at compile time via include_str!; a generic migration runner tracks schema version; forward-only migrations."
primary-audience: agent
---

# G-0005: SQL File-Based Migrations for Embedded SQLite

**Status:** Accepted
**Date:** 2026-04-10

## Context

When each schema version is an inline SQL string inside a `migrate()` function, every migration adds more Rust code. That code piles up. It drives churn, it makes merge conflicts more likely, and it tangles schema definition together with application logic. The goal is a migration runner that stays generic, so adding a schema change means writing one new `.sql` file and nothing else.

## Decision

Use SQL file-based migrations embedded at compile time for all Rust projects with embedded SQLite.

- Migrations live in `migrations/NNNN_<description>.sql` (e.g., `migrations/0001_initial.sql`)
- SQL files are embedded into the binary via `include_str!()`, so there's no runtime file dependency
- A generic migration runner reads `schema_version`, determines which migrations haven't been applied, and runs them in order
- Migrations should be written in idempotent style where SQL supports it (`CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`). For operations that aren't inherently idempotent (`ALTER TABLE ADD COLUMN`), the version-tracking table is the guard
- The migration runner is shared code, extracted to a common crate or pattern rather than reimplemented per project
- Forward-only migrations. There are no down migrations. They add complexity and rarely get used in practice with embedded databases

## Alternatives Considered

**Inline SQL in Rust (status quo):** Works, but doesn't scale. Each migration adds Rust code, grows the function's complexity, and mixes schema with logic. Rejected because it creates unnecessary code churn.

**External SQL files loaded at runtime:** Migrations as separate files read from disk at startup. Rejected because it introduces a runtime dependency on file paths. The embedded binary should be self-contained.

**Full migration framework (refinery, sqlx-migrate):** Purpose-built migration tools exist in the Rust ecosystem. Not rejected outright. They're worth evaluating if the hand-rolled runner proves insufficient. But for the current scope, simple embedded SQLite, a lightweight `include_str!()` approach avoids a new dependency.

**Embedded scripting (Rhai/Lua) for migrations:** There's some interest in embedded scripting as a way to minimize code churn. Deferred. SQL files are the right level of abstraction for schema changes. Scripting may earn its place later for more complex data transformations.

## Consequences

- A new schema change is a new `.sql` file, with no Rust code changes to the migration runner
- Existing projects should move to this pattern the next time someone touches their database layer
- The `migrations/` directory becomes part of the standard project template
- Developers can read the migration history as plain SQL without understanding Rust
