---
title: "G-0006: Justfile as CI Contract"
summary: "CI YAML invokes `just ci` and nothing else; gate logic lives in the justfile; fixed verify-* recipe vocabulary shared across all projects."
primary-audience: agent
---

# G-0006: Justfile as CI Contract

**Status:** Accepted
**Date:** 2026-04-21

## Context

Prior CI work set gate logic in `.github/workflows/*.yml` per project, with some projects using justfiles for dev-only tasks in parallel. That produced three problems: (1) local-vs-CI drift because the two paths ran different commands, (2) runner lock-in because swapping GitHub Actions for self-hosted or `act` meant rewriting gate logic, (3) coverage and lint behavior that varied silently across projects.

A single contract — CI YAML becomes a launcher; gate logic lives in a build tool invoked the same way locally and remotely — collapses the runner-choice question (any runner is equivalent once it calls the contract) and closes the docker-compose gap (docker-compose handles service dependencies inside the contract, not as CI service definitions).

## Decision

1. **CI YAML invokes `just ci` and nothing else.** Any gate logic in `.github/workflows/*.yml` beyond `checkout → devcontainer → just ci` is a contract violation. A ten-line workflow is the target shape.

2. **One justfile per project.** No `ci.justfile` split. At current scale the split is premature — solves a problem that doesn't exist yet.

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

   Projects omit recipes that don't apply (e.g., a pure-Rust project may have no `verify-type` distinct from `verify-build`). Omitted recipes are absent, not stubbed.

4. **Gate-line stdout format.** Each `verify-*` recipe SHALL emit, as the last line of stdout: `GATE <name> <PASS|FAIL> <detail>`. Human legibility only — the exit code is the source of truth. Tooling that scrapes gate lines does so as a convenience, never as authority.

5. **No `--fix` side effects under verify-*.** `verify-lint` checks; it does not mutate. Auto-fix recipes live under `fix-*` (e.g., `fix-lint`). This keeps CI deterministic and read-only.

6. **Idempotent from any cwd.** A `verify-*` or `ci` invocation SHALL produce the same result whether run from the repo root, a subdirectory, or a worktree. No implicit `cd` to a specific path.

## Alternatives Considered

- **GNU Make for `ci` + justfile for dev tasks** (two-tool split). Rejected: two tools to maintain, boundary becomes ambiguous as recipes grow.
- **Separate `ci.justfile` in each project.** Rejected: premature split. If a single justfile becomes unwieldy, revisit then.
- **Leave gate logic in `.github/workflows/*.yml`.** Rejected — that's the status quo that created the drift.
- **Project-by-project recipe names.** Rejected: a fixed vocabulary is the abstraction. Custom names per project reintroduce the drift the contract exists to remove.

## Consequences

- **Runner swap is a one-file rewrite.** GitHub Actions → self-hosted → `act` → Gitea Actions all become substitutable because `just ci` is the contract.
- **Per-project retrofits required.** Each project needs to adopt the contract.
- **Coverage threshold enforcement moves into `verify-coverage`.** G-0001's 90% coverage default lives inside each project's `verify-coverage` recipe, not in CI config. Threshold deviations still require documented exception per G-0001.
- **`fix-*` recipes are a separate convention.** Not mandated by this ADR, but the `verify-*` / `fix-*` split is implied by the no-side-effects rule. Projects MAY add `fix-*` recipes; they are not required.
- **Devcontainer integration is adjacent, not in this ADR.** The `devcontainer → just ci` wiring is stage-2 work. This ADR defines the contract; devcontainer + image-publication decisions are per-project or a follow-up ADR.
- **Gate-line scraping is a "for future tooling" hook.** Nothing today consumes `GATE <name> <PASS|FAIL> <detail>`. Specifying the format now means dashboards, completion reports, or retry logic can parse it later without a second standardization pass.
