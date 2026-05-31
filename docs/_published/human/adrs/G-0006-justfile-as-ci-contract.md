---
title: "G-0006: Justfile as CI Contract"
summary: "CI YAML invokes `just ci` and nothing else; gate logic lives in the justfile; fixed verify-* recipe vocabulary shared across all projects."
primary-audience: agent
---

# G-0006: Justfile as CI Contract

**Status:** Accepted
**Date:** 2026-04-21

## Context

Earlier CI work put the gate logic (the checks that decide whether a change passes) directly in each project's `.github/workflows/*.yml`, and some projects ran a justfile alongside it for dev-only tasks. That arrangement caused three problems. First, local-vs-CI drift: the two paths ran different commands, so a green local run didn't guarantee a green CI run. Second, runner lock-in: swapping GitHub Actions for a self-hosted runner or `act` meant rewriting the gate logic itself. Third, coverage and lint behavior that drifted quietly from one project to the next.

A single contract fixes all three. The CI YAML becomes a launcher, and the gate logic lives in a build tool that's invoked the same way locally and remotely. Once that holds, the runner-choice question collapses, because every runner is equivalent once it just calls the contract. It also closes the docker-compose gap: service dependencies are handled by docker-compose inside the contract, not declared as CI service definitions outside it.

## Decision

1. **CI YAML invokes `just ci` and nothing else.** Any gate logic in `.github/workflows/*.yml` beyond `checkout → devcontainer → just ci` is a contract violation. A ten-line workflow is the target shape.

2. **One justfile per project.** No `ci.justfile` split. At current scale the split is premature, solving a problem that doesn't exist yet.

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

   Projects omit recipes that don't apply. A pure-Rust project, for instance, may have no `verify-type` distinct from `verify-build`. Omitted recipes are absent, not stubbed.

4. **Gate-line stdout format.** Each `verify-*` recipe SHALL emit, as the last line of stdout: `GATE <name> <PASS|FAIL> <detail>`. This is for human legibility only. The exit code is the source of truth. Tooling that scrapes gate lines does so as a convenience, never as authority.

5. **No `--fix` side effects under verify-*.** `verify-lint` checks; it doesn't mutate. Auto-fix recipes live under `fix-*`, for example `fix-lint`. This keeps CI deterministic and read-only.

6. **Idempotent from any cwd.** A `verify-*` or `ci` invocation SHALL produce the same result whether it runs from the repo root, a subdirectory, or a [worktree](../glossary.md#worktree) (a separate working tree off the main branch, opened per code-modifying dispatch). No implicit `cd` to a specific path.

## Alternatives Considered

- **GNU Make for `ci` + justfile for dev tasks** (two-tool split). Rejected: two tools to maintain, and the boundary between them gets ambiguous as recipes grow.
- **Separate `ci.justfile` in each project.** Rejected: premature split. If a single justfile becomes unwieldy, revisit then.
- **Leave gate logic in `.github/workflows/*.yml`.** Rejected. That's the status quo that created the drift.
- **Project-by-project recipe names.** Rejected: a fixed vocabulary is the abstraction. Custom names per project reintroduce the drift the contract exists to remove.

## Consequences

- **Runner swap is a one-file rewrite.** GitHub Actions, self-hosted, `act`, Gitea Actions all become substitutable, because `just ci` is the contract.
- **Per-project retrofits required.** Each project needs to adopt the contract.
- **Coverage threshold enforcement moves into `verify-coverage`.** The 90% coverage default set by [G-0001](../adrs/G-0001.md) lives inside each project's `verify-coverage` recipe, not in CI config. Threshold deviations still require a documented exception per G-0001.
- **`fix-*` recipes are a separate convention.** This ADR doesn't mandate them, but the `verify-*` / `fix-*` split follows from the no-side-effects rule. Projects MAY add `fix-*` recipes. They aren't required.
- **Devcontainer integration is adjacent, not in this ADR.** The `devcontainer → just ci` wiring is stage-2 work. This ADR defines the contract; devcontainer and image-publication decisions are per-project or a follow-up ADR.
- **Gate-line scraping is a "for future tooling" hook.** Nothing today consumes `GATE <name> <PASS|FAIL> <detail>`. Specifying the format now means dashboards, completion reports, or retry logic can parse it later without a second standardization pass.
