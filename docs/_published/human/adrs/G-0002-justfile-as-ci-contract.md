---
title: "G-0002: Justfile as CI Contract"
summary: "CI YAML becomes a thin launcher that invokes `just ci` and nothing else; gate logic lives in a per-project justfile with a fixed verify-* recipe vocabulary, run identically locally and in CI."
primary-audience: agent
---

# G-0002: Justfile as CI Contract

**Status:** Accepted
**Date:** 2026-04-21

## Context

Earlier CI work put gate logic in `.github/workflows/*.yml` per project, with some projects using justfiles for dev-only tasks in parallel. That produced three problems. First, local-vs-CI drift, because the two paths ran different commands. Second, runner lock-in, because swapping GitHub Actions for a self-hosted runner or `act` meant rewriting gate logic. Third, coverage and lint behavior that varied silently across projects.

A research synthesis argued for a single contract: CI YAML becomes a launcher, and gate logic lives in a build tool invoked the same way locally and remotely. That collapses the runner-choice question, since any runner is equivalent once it calls the contract. It also closes the service-dependency gap, because a `docker-compose` step handles Postgres and pgvector inside the contract rather than as runner-specific `services:` config.

## Decision

1. **CI YAML invokes `just ci` and nothing else.** Any gate logic in `.github/workflows/*.yml` beyond `checkout → devcontainer → just ci` is a contract violation. A ten-line workflow is the target shape.

2. **One justfile per project.** No `ci.justfile` split. At current scale the split is premature. It solves a problem that doesn't exist yet.

3. **Fixed verify-* recipe names.** Every project implements the same vocabulary:

   | Recipe | Purpose |
   |--------|---------|
   | `verify-test` | Unit + integration tests |
   | `verify-lint` | Static lint checks (no `--fix`) |
   | `verify-type` | Type checks |
   | `verify-coverage` | Coverage threshold check |
   | `verify-build` | Production build produces artifacts |
   | `verify-smoke` | Fast smoke checks |
   | `ci` | Composite — runs all applicable verify-* in order |

   Projects omit recipes that don't apply. A pure-Rust project may have no `verify-type` distinct from `verify-build`. Omitted recipes are absent, not stubbed.

4. **Gate-line stdout format.** Each `verify-*` recipe SHALL emit, as the last line of stdout: `GATE <name> <PASS|FAIL> <detail>`. This is for human legibility only. The exit code is the source of truth. Tooling that scrapes gate lines does so as a convenience, never as authority.

5. **No `--fix` side effects under verify-*.** `verify-lint` checks; it doesn't mutate. Auto-fix recipes live under `fix-*` (for example, `fix-lint`). This keeps CI deterministic and read-only.

6. **Idempotent from any working directory.** A `verify-*` or `ci` invocation SHALL produce the same result whether run from the repo root, a subdirectory, or a worktree. No implicit `cd` to a specific path.

## Alternatives Considered

- **GNU Make for `ci` + justfile for dev tasks** (two-tool split). Rejected: two tools to maintain, an ambiguous boundary as recipes grow, and `just` is already in use. The universality argument for Make is negligible at current project count.
- **Separate `ci.justfile` in each project.** Rejected: premature split. If a single justfile becomes unwieldy, revisit then. Splitting preemptively solves problems that don't exist.
- **Leave gate logic in `.github/workflows/*.yml`.** Rejected. That's the status quo that created the drift. It defeats the contract.
- **Project-by-project recipe names.** Rejected: a fixed vocabulary is the abstraction. Custom names per project reintroduce the drift the contract exists to remove.

## Consequences

- **Runner swap is a one-file rewrite.** GitHub Actions, self-hosted, `act`, and other CI runners all become substitutable because `just ci` is the contract. Runner choice collapses to convenience.
- **Per-project retrofits required.** Each existing project adopts the contract; one project serves as the pilot.
- **Coverage threshold enforcement moves into `verify-coverage`.** The coverage-floor default (see P-TDDPairs, the principle that pairs tests with implementation and sets the coverage floor) lives inside each project's `verify-coverage` recipe, not in CI config. Threshold deviations still require a documented exception per that principle.
- **`fix-*` recipes are a separate convention.** Not mandated by this ADR, but the `verify-*` / `fix-*` split is implied by the no-side-effects rule. Projects MAY add `fix-*` recipes; they aren't required.
- **Devcontainer integration is adjacent, not in this ADR.** The `devcontainer → just ci` wiring is a separate stage of the CI-parity work. This ADR defines the contract; devcontainer and image-publication decisions are per-project or a follow-up ADR.
- **Gate-line scraping is a hook for future tooling.** Nothing consumes `GATE <name> <PASS|FAIL> <detail>` today. Specifying the format now means dashboards, completion reports, or retry logic can parse it later without a second standardization pass.
