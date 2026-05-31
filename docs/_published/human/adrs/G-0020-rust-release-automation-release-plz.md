---
title: "G-0020: Rust Release Automation = release-plz (Versioning + Publish Unified)"
summary: "release-plz is the canonical Rust release tool for CHANGELOG generation and semver bump computation; PAT or GitHub App required (not GITHUB_TOKEN); cocogitto deferred to first polyglot repo."
primary-audience: agent
---

# G-0020: Rust Release Automation = release-plz (Versioning + Publish Unified)

**Status:** Accepted
**Date:** 2026-04-30

## Context

Two release-tooling questions converged on one tool:

- **CHANGELOG generation tooling.** Candidates: git-cliff (CHANGELOG only), release-please (Google, polyglot, requires Node), release-plz (Rust-native, embeds git-cliff), changesets (JS-first, declined Rust polyglot).
- **Semver bump computation tooling.** Candidates: release-plz (Rust-native), release-please (polyglot, Node), cocogitto (polyglot Rust-native).

Research found:
- **release-plz** v0.3.157 (March 2026), 1.4k stars, 96.4% Rust, Apache-2.0/MIT. It compares the local Cargo.toml to crates.io rather than to git tags. First-class Rust workspace support. It embeds git-cliff for CHANGELOG generation. It integrates `cargo-semver-checks` for compiler-level breaking-change detection.
- **release-please** supports Rust via `release-type: "rust"` plus the `cargo-workspace` plugin, but it pulls a Node runtime into CI, which goes against the no-TS/JS preference.
- **cocogitto** is the only Rust-native polyglot tool; it's first-class via per-package hooks. It's useful when a repo adds non-Rust packages.

changesets is excluded. It's JS-first and won't support Rust polyglot. release-plz wins for Rust-only repos. cocogitto is deferred until a first-polyglot signal appears.

## Decision

**release-plz is the canonical Rust release-automation tool for both CHANGELOG generation and semver bump computation.** One tool, one config file, two jobs.

Per-repo `release-plz.toml` shape (workspace template, per-repo overrides):

```toml
[workspace]
changelog_update = true
semver_check = true
git_release_enable = true
git_tag_enable = true

[changelog]
# git-cliff config inherited via release-plz; conventional-commits parsing
```

The CI workflow invokes release-plz via the official GitHub Action (per repo `.github/workflows/release.yml`), gated by:
- Branch: `main` only
- Concurrency: per [G-0019](./G-0019.md) (job-level, on `release-pr` only, not the release job)
- Trigger: push to main (after the [G-0018](./G-0018.md) auto-merge completes)
- Token: per the token strategy below

**Token strategy (mandatory).** The default `GITHUB_TOKEN` does NOT trigger downstream workflow runs from release-plz. PRs created with `GITHUB_TOKEN` won't trigger PR CI checks, which means Mode A's release-PR (the PR that release-plz opens with version bumps and CHANGELOG; see the mode list below) can be merged without the [G-0001](./G-0001.md) 90% coverage gate having run on it. And release-tag pushes won't trigger downstream tag/release-event workflows. release-plz upstream documents this at <https://release-plz.dev/docs/github/token>.

Per-repo spec (the specification the decomposer writes before implementation, which defines what done looks like) MUST adopt one of:

1. **Fine-grained PAT** stored as `secrets.RELEASE_PLZ_TOKEN`, repo-scoped, rotated every 90 days. Permissions: `Contents: Read & Write`, `Pull requests: Read & Write`. Lower setup cost; per-user expiry is the rotation forcing function.
2. **GitHub App** (release-plz/release-plz-action documents this as the recommended path) with installation scoped to in-scope repos. Permissions: `contents: write, pull_requests: write`. Higher setup cost; auditable installation, no per-user dependency, and no per-90-day rotation pressure, since App installation tokens are short-lived and minted per-run.

Both options close the "release PR has no CI" correctness gap that `GITHUB_TOKEN` produces. With G-0001's 90% coverage gate, missing CI on the release PR would let unreviewed coverage regressions ship. So the PAT or App is mandatory, not optional.

release-plz operates in two modes per its design:
1. **Release-PR mode (Mode A repos):** opens a PR titled "chore: release" with version bumps plus CHANGELOG; merging the PR cuts the release.
2. **Direct-release mode (Mode B repos):** computes the version bump on each main push, then tags and creates the GitHub release immediately.

Each repo's spec declares which mode the repo uses; the release-plz config reflects it.

**Polyglot exception:** when a non-Rust package enters a repo (first signal: a repo adds, for example, a Python or TS sub-package), the repo spec evaluates cocogitto as the polyglot bridge. Until that signal, release-plz is the canonical choice. release-plz is NOT removed when cocogitto is added. cocogitto wraps the polyglot orchestration and delegates Rust-side operations to release-plz where it earns its keep.

## Alternatives Considered

- **release-please (Google).** Rejected for Rust-only repos: it pulls a Node runtime into CI, and the `cargo-workspace` plugin's manifest-driven config is verbose next to release-plz's zero-config workspace handling. Its only edge over release-plz is polyglot, and cocogitto is the better polyglot answer for Rust-led repos.
- **changesets (JS-first).** Rejected. Maintainers explicitly declined Rust polyglot support; the documented workaround treats package.json as the version source-of-truth and adds sync scripts. Viable, but it requires a Node toolchain in every devcontainer.
- **git-cliff alone (CHANGELOG only) plus manual semver bumps.** Rejected. It splits the release into two manual steps, which defeats automation. release-plz embeds git-cliff anyway; using release-plz gives both jobs in one tool.
- **cocogitto from day one.** Rejected for Rust-only repos. It adds polyglot machinery before there's a polyglot need; release-plz is leaner for the current single-language case.
- **cargo-release.** Considered briefly. It's active but more imperative (a CLI-driven manual release flow) next to release-plz's PR-driven flow. release-plz's release-PR mode fits the PR-gated discipline.
- **Hand-rolled scripts (git-cliff plus cargo set-version plus tag push).** Rejected. It reinvents what release-plz provides; the workspace doesn't need a custom release tool.

## Consequences

- **Per-repo retrofit:** add `release-plz.toml` and `.github/workflows/release.yml` invoking the release-plz action, plus the GitHub Actions concurrency block per G-0019. The operations engineer is dispatched per repo as part of the merge-mode migration runbook.
- **CHANGELOG format is conventional-commits-driven** (release-plz embeds git-cliff with the default conv-commits config). Commit messages from G-0018's auto-merge template (the squashed conv-commits header) feed directly into CHANGELOG generation.
- **Breaking-change detection via `cargo-semver-checks`** (a release-plz integration). For library crates, breaking API changes are flagged automatically. The bump label (per [G-0013](./G-0013.md)) is cross-checked against the detected breakage. A mismatch (for example, a `bump:patch` label on a breaking API change) fails the release at release-PR open time, so operators see the mismatch immediately when the release-PR is first opened. The failure does NOT happen at tag push.
- **Crates.io publish:** release-plz handles `cargo publish` for repos that publish (a per-repo spec choice). Workspace tool repos that don't publish to crates.io use release-plz only for tagging and the GitHub release.
- **Tag format (single-crate repos):** `v<major>.<minor>.<patch>[-prerelease]` (the release-plz default). Pattern B build-metadata (`+sha.X`) is runtime-introspection only; tags don't carry it.
- **Tag format (workspace repos):** `<package>-v<version>` per the release-plz default for Cargo workspaces (for example, `mnemra-core-v1.2.3`). A per-repo spec may override via `git_tag_name`. Downstream tooling (deploy-on-tag workflows, mirror imports) must account for this difference.
- **Release notes are auto-generated** from the CHANGELOG section for the new version. Editing them in the release-PR (Mode A) before merge is the human gate.
- **Cocogitto trigger:** the first time a non-Rust package lands in a workspace repo, the spec evaluates cocogitto as the polyglot orchestrator. The decision is recorded as a follow-up ADR at that point.
- **release-plz upstream churn:** release-plz is at 0.x. SHA-pinning the GitHub Actions action version plus Dependabot monitoring keeps drift under control.
- **Migration:** existing repos without release automation adopt release-plz on the first release-needing change. Backfill of the historic CHANGELOG is a per-repo spec decision. Starting fresh from current main is acceptable.
- **`CARGO_REGISTRY_TOKEN` provisioning.** The per-repo spec MUST declare: (i) per-repo scope, NOT org-shared, so a compromise's blast radius is limited to one crate; (ii) a rotation cadence (90 days recommended, aligned with PAT rotation); (iii) that only the release.yml workflow has access, declared at the job level, not the workflow level. This keeps the token from being available to feature-PR CI runs.
- **Action SHA-pinning consistency.** Third-party actions in the release workflow (release-plz/action and others) are SHA-pinned with a comment-pin to the version (for example, `release-plz/action@a1b2c3d4 # v0.5.123`), per the supply-chain hygiene posture established by [G-0015](./G-0015.md)'s `FROM`-line SHA-pin discipline. An exception requires explicit rationale documented in the workflow file.
- **Embargo coordination.** For repos in embargo (per [G-0022](./G-0022.md)), Mode A flag-flip merges that would trigger a release-PR are suspended until the embargo lifts. The release-PR mechanism resumes at unembargoed-T0 with the audit-PR pattern G-0022 specifies.

## Changelog

### 2026-04-30 — Round 1 review amendments

- **Added:** Token strategy section: fine-grained PAT (`secrets.RELEASE_PLZ_TOKEN`, repo-scoped, 90-day rotation) OR GitHub App. It's explicitly documented that `GITHUB_TOKEN` does NOT trigger downstream workflow runs. The PAT or App is mandatory. Reference: <https://release-plz.dev/docs/github/token>.
- **Added:** `CARGO_REGISTRY_TOKEN` provisioning: per-repo scope (not org-shared), 90-day rotation, job-level secrets declaration only on release.yml.
- **Updated:** the `cargo-semver-checks` failure point is pinned to release-PR open time, not tag push. The operator sees the mismatch immediately; Stage 6 reviewers (the approval-labelling stage) see it as a gate before approval.
- **Added:** third-party actions in the release workflow are SHA-pinned with a comment-pin to the version, aligning with G-0015's `FROM`-line SHA-pin discipline.
- **Updated:** tag format split between single-crate repos (`v<version>`) and workspace repos (`<package>-v<version>`, the release-plz default).
- **Added:** embargo coordination cross-reference.
