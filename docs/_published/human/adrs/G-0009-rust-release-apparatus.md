---
title: "G-0009: Rust Release Apparatus — release-plz Automation + Monotonic Non-Decreasing Version Policy"
summary: "release-plz is the canonical Rust release-automation tool (CHANGELOG generation + semver-bump computation in one config, minted with a non-default token so downstream CI fires); the version sequence on main is monotonic non-decreasing, with a reviewer-enforced bump:none for docs/internal merges. Consolidates the tool choice and the version policy."
primary-audience: agent
---

# G-0009: Rust Release Apparatus — release-plz Automation + Monotonic Non-Decreasing Version Policy

**Status:** Accepted
**Date:** 2026-04-30

> **Consolidated ADR.** This is the single decision for Rust release automation and the version-sequence policy that governs it. It consolidates two prior ADRs, the release-automation tool choice and the monotonic non-decreasing version policy (Pattern A), into one apparatus: the tool that cuts releases, plus the rule for how the version number is allowed to move.
>
> **Embargo is NOT here.** The embargo flow is a security flow applicable to any repo, not Rust-specific; it is standalone [G-0010](G-0010-embargo-flow-architecture.md). Where this apparatus interacts with an embargo, it points to G-0010.
>
> **Scope split with merge governance and the merge apparatus.** The *bump-label vocabulary and cardinality* are owned by [G-0003](G-0003-merge-governance.md) (this ADR adds the `bump:none` value to that closed enum but does not restate the full label table). The *merge mechanics* (squash, recovery cap, tag-race concurrency, merge queue) are owned by [G-0008](G-0008-pr-merge-apparatus.md); this apparatus consumes the squashed conventional-commits commit G-0008 produces.

## Context and Problem Statement

Two surfaces compose into the release apparatus:

- **Release tooling.** What tool generates CHANGELOGs and computes semver bumps for the Rust repos? Candidates spanned git-cliff (CHANGELOG only), release-please (polyglot, requires a Node runtime), release-plz (Rust-native, embeds git-cliff), changesets (JS-first), and cocogitto (Rust-native polyglot). The two questions (CHANGELOG generation and semver-bump computation) converged on one tool.
- **Version-sequence policy.** Under Pattern A (per-merge bump; version cut at flag activation), does the version sequence on `main` need to be strictly increasing, monotonic non-decreasing, or unconstrained between merges? Forcing a `bump:patch` minimum on every merge inflates patch counts and dilutes the signal of the patch number.

Research found release-plz (v0.3.157, March 2026; ~1.4k stars; 96.4% Rust; Apache-2.0/MIT): it compares the local `Cargo.toml` to the package registry rather than to git tags, has first-class Rust workspace support, embeds git-cliff for CHANGELOG generation, and integrates `cargo-semver-checks` for compiler-level breaking-change detection. release-please supports Rust but pulls a Node runtime into CI (against the no-TS/JS posture). cocogitto is the only Rust-native polyglot tool, deferred to a first-polyglot signal.

## Decision Drivers

- **Rust-native, zero extra runtime.** No Node toolchain in CI (the no-TS/JS posture).
- **One tool, one config, two jobs.** CHANGELOG generation and semver-bump computation in a single tool, not a split manual flow.
- **The version number is a signal.** Patch inflation on docs-only / internal-refactor merges dilutes it; the policy preserves the signal.
- **Reviewer-enforced over tool-enforced where the tool can't see it.** release-plz reads commit-message regex, not labels or paths; honesty about what the tool actually enforces.
- **Supply-chain hygiene.** SHA-pinned third-party actions; per-repo, job-scoped, rotated tokens.

## Decision Outcome

### Layer 1 — release-plz as the canonical Rust release-automation tool

**release-plz is the canonical Rust release-automation tool for both CHANGELOG generation and semver-bump computation.** One tool, one config file, two jobs.

Per-repo `release-plz.toml` shape (a shared template, with per-repo overrides):

```toml
[workspace]
changelog_update = true
semver_check = true
git_release_enable = true
git_tag_enable = true

[changelog]
# git-cliff config inherited via release-plz; conventional-commits parsing
```

The CI workflow invokes release-plz via its official Action (`.github/workflows/release.yml`), gated by: branch `main` only; concurrency per [G-0008](G-0008-pr-merge-apparatus.md) (job-level, on `release-pr` only, not the release job); trigger = push to `main` (after G-0008's auto-merge completes); token per the strategy below.

release-plz operates in two modes:

1. **Release-PR mode (Mode A repos):** opens a PR titled "chore: release" with version bumps + CHANGELOG; merging the PR cuts the release.
2. **Direct-release mode (Mode B repos):** computes the version bump on each `main` push; tags and creates the release immediately.

The per-repo spec declares the mode; the release-plz config reflects it.

**Token strategy (mandatory).** The default CI token does NOT trigger downstream workflow runs from release-plz: PRs created with the default token will not trigger PR CI checks (Mode A's release-PR could be merged without the coverage gate having run on it, see the testing standard `P-TDDPairs`), and release-tag pushes will not trigger downstream tag/release-event workflows. The per-repo spec MUST adopt one of:

1. **A fine-grained token** stored as a repo secret, repo-scoped, rotated every 90 days. Permissions: `Contents: Read & Write`, `Pull requests: Read & Write`. Lower setup cost; per-user expiry is the rotation forcing function.
2. **A GitHub App** (the recommended path) scoped to in-scope repos. Permissions: `contents: write, pull_requests: write`. Higher setup cost; auditable installation, no per-user dependency, no 90-day rotation pressure (App installation tokens are short-lived, minted per-run).

Both options close the "release PR has no CI" correctness gap the default token produces. Against the coverage gate (`P-TDDPairs`), missing CI on the release PR would let unreviewed coverage regressions ship; the token/App is mandatory, not optional.

**Polyglot exception:** when a non-Rust package enters a repo (first signal: a repo adds e.g. a Python or TS sub-package), the repo spec evaluates cocogitto as the polyglot bridge. Until that signal, release-plz is the canonical choice. release-plz is NOT removed when cocogitto is added; cocogitto wraps the polyglot orchestration and delegates Rust-side operations to release-plz where it earns its keep. The cocogitto decision is recorded as a follow-up ADR at that point.

### Layer 2 — Monotonic non-decreasing version policy (Pattern A)

A companion versioning decision declares two release patterns per repo: **Pattern A** (per-merge bump; version cut at flag activation) and **Pattern B** (deploy-as-release; merges are dark, bump only at deploy time). This layer constrains Pattern A only; Pattern B repos declare their own bump policy in their spec.

**For Pattern A repos, the version sequence on `main` MUST be monotonic non-decreasing.** After every merge to `main`, `prev_version <= new_version`. Most merges advance the version; a merge MAY produce an equal version when it is documentation-only (no `src/` or equivalent change), or internal (not surfacing to public API) AND the repo's release-plz config is set to skip-bump for the affected paths. Strictly-increasing is **rejected** for Pattern A repos: it inflates patch counts on docs-only / internal-refactor merges and dilutes the patch-number signal. Pattern B repos may implement strictly-increasing if their spec chooses.

The bump label (vocabulary + cardinality per [G-0003](G-0003-merge-governance.md)) declares the bump intent. The merge template script (G-0008) sets `bump:patch` as default; this layer adds an explicit `bump:none` value to G-0003's closed bump-label enum for non-bumping merges:

| Bump label | Effect | Use |
|------------|--------|-----|
| `bump:major` | major+1, minor=0, patch=0 | Breaking API change |
| `bump:minor` | minor+1, patch=0 | Feature addition |
| `bump:patch` | patch+1 | Bugfix or behavior change |
| `bump:none` | no version change | Docs-only, internal-only, CHANGELOG-edit-only |

**`bump:none` is honor-system + reviewer-enforced, NOT tool-enforced.** release-plz reads neither labels nor paths; it operates on commit-message regex. There is no path-coverage gate. A gate reading PR labels, running `git diff --name-only`, and exiting non-zero on mismatch was considered and rejected on simplicity grounds. Instead, `bump:none` is the developer's declaration of "no surfacing change," backed by reviewer responsibility:

- The PR body MUST include a one-line path-coverage justification when `bump:none` is set (e.g., "changed paths: `docs/**`, `*.md` only, no `src/` change"). The merge template script does not auto-generate this; the actor setting `bump:none` writes the line.
- Stage-4 reviewers cross-check the declaration against `git diff --name-only` and flag misleading claims with a `blocker` finding; iterate-to-zero discipline routes the fix.
- **Mandatory reviewer routing:** every `bump:none` PR MUST include the operational-discipline reviewer in the Stage-4 reviewer set, regardless of the per-spec routing the chunk would otherwise have called for. The dispatch envelope detects `bump:none` and adds that reviewer to the fan-out automatically; if the operational-discipline reviewer is unavailable, the implementer serves as backup with the same path-coverage cross-check duty. Stage 4 cannot iterate-to-zero on a `bump:none` PR until at least one operational-discipline reviewer (or the implementer as backup) has acknowledged the path-coverage statement.

**Revert PR semantics.** A PR that reverts a prior merge MUST declare its bump label based on **public-API impact, not numeric distance from the reverted version**:

- Reverting a `bump:patch` merge with `bump:patch` is correct (the patch undoes a bugfix; the net public-API effect is patch-level).
- Reverting a `bump:minor` merge requires `bump:major` if the revert removes public-API surface added by the reverted minor; semver treats surface removal as breaking. The version sequence stays monotonic non-decreasing numerically (`1.3.0 → 1.4.0` revert merge); the major bump signals the consumer-visible breakage.
- Reverting a `bump:major` merge with `bump:major` is the obvious case; consumers already adjusted to the major's breakage, and the revert is itself a breaking change.

The revert PR body MUST cite the reverted PR plus the bump-label rationale. Reviewers cross-check the bump label against the public-API delta. The monotonic-non-decreasing numeric invariant is preserved by definition (the version only ever bumps up); the semver contract is preserved by reviewer discipline on revert-bump labels.

## Alternatives Considered

- **release-please** (Layer 1). Rejected for Rust-only repos. It pulls a Node runtime into CI (against the no-TS/JS posture); its workspace plugin's manifest-driven config is verbose versus release-plz's zero-config workspace handling. Its only edge is polyglot, and cocogitto is the better polyglot answer for Rust-led repos.
- **changesets (JS-first)** (Layer 1). Rejected. Its maintainers explicitly declined Rust polyglot support; the documented workaround treats `package.json` as the version source-of-truth and adds sync scripts, requiring a Node toolchain in every devcontainer.
- **git-cliff alone + manual semver bumps** (Layer 1). Rejected. It splits the release into two manual steps and defeats automation. release-plz embeds git-cliff anyway, giving both jobs in one tool.
- **cocogitto from day one** (Layer 1). Rejected for Rust-only repos. It adds polyglot machinery before polyglot need; release-plz is leaner for the current single-language case. cocogitto enters when the first polyglot repo lands.
- **cargo-release** (Layer 1). Considered; active but more imperative (a CLI-driven manual flow) versus release-plz's PR-driven flow, which fits the PR-gated discipline better.
- **Hand-rolled scripts** (git-cliff + a version setter + tag push) (Layer 1). Rejected. It reinvents what release-plz provides.
- **Strictly increasing** (Layer 2). Rejected. It inflates patch count on docs-only / internal-refactor merges, dilutes the patch-number signal, and forces a CHANGELOG entry for every merge regardless of consumer impact.
- **Unconstrained / arbitrary** (Layer 2: allow same or lower versions). Rejected. Same-version-after-merge is fine; lower-version-after-merge breaks every downstream tool's assumption and offers no benefit.
- **No `bump:none` label; force `bump:patch` on every merge** (Layer 2). Rejected per the dilution argument.
- **`bump:none` allowed unconditionally** (Layer 2). Rejected. Without reviewer responsibility, developer convenience erodes the version signal (every merge could be `bump:none` if claimed).
- **Date-based versioning instead of semver** (Layer 2). Rejected. Out of scope; semver is locked ecosystem-wide.

## Consequences

- **Per-repo retrofit:** add `release-plz.toml` + `.github/workflows/release.yml` invoking the release-plz action + the CI concurrency block per [G-0008](G-0008-pr-merge-apparatus.md); add the `bump:none` label to the repo's allowed-labels list. A per-repo `release-plz.toml` may declare a `release_commits` regex to suppress release-PR creation for `bump:none`-style commit messages, but this is a CHANGELOG-quality concern, not a gate.
- **CHANGELOG format is conventional-commits-driven** (release-plz embeds git-cliff with the default conventional-commits config). The squashed conventional-commits header from [G-0008](G-0008-pr-merge-apparatus.md)'s merge template feeds directly into CHANGELOG generation.
- **Breaking-change detection via `cargo-semver-checks`** (a release-plz integration). For library crates, breaking API changes are flagged automatically; the bump label cross-checks against the detected breakage. A mismatch (e.g., `bump:patch` or `bump:none` on a breaking API change) fails the release **at release-PR open time**. release-plz runs semver-checks during the open/update step, so the operator sees the mismatch immediately, and Stage-6 reviewers see it as a gate before approving the release-PR. Failure does NOT wait for tag push (which would be too late; the release-PR would already be merged to `main`). The label declares intent; `cargo-semver-checks` verifies API-level reality.
- **Tag format (single-crate repos):** `v<major>.<minor>.<patch>[-prerelease]` (the release-plz default). Build-metadata (`+sha.X`) is runtime-introspection only; tags do not carry it.
- **Tag format (workspace repos):** `<package>-v<version>` (the release-plz default for Cargo workspaces, e.g., `<package>-v1.2.3`). A per-repo spec may override via `git_tag_name`. Single-crate and workspace repos thus tag differently by default; downstream tooling (deploy-on-tag workflows, mirror imports) must account for this.
- **Package publish:** release-plz handles `cargo publish` for repos that publish (a per-repo spec choice). Tool repos that do not publish use release-plz only for tagging + the release.
- **Registry-token provisioning.** A per-repo spec MUST declare: (i) per-repo scope, NOT org-shared (compromise blast radius limited to one crate); (ii) a rotation cadence (recommend 90 days, aligned with token rotation); (iii) access only from the `release.yml` workflow, declared at job level (`secrets:` on the publish job), not workflow level, so the token is not available to feature-PR CI runs that execute untrusted PR code.
- **Action SHA-pinning consistency.** Third-party actions in the release workflow are SHA-pinned with a comment-pin to version (e.g., `release-plz/action@a1b2c3d4 # v0.5.123`), per the SHA-pin supply-chain discipline established by [G-0005](G-0005-devcontainer-per-repo-upstream-base.md). An exception requires explicit rationale documented in the workflow file. The shared template ships SHA-pinned actions by default. release-plz is at 0.x; SHA-pinning the action version plus dependency-scanner monitoring keeps drift under control.
- **The bump-label family adds `bump:none`** as a valid value (an extension to G-0003's closed bump-label enum). G-0003's cardinality enforcement recognizes the four bump-label values; `bump:none` is in the closed enum.
- **CHANGELOG entries for `bump:none` merges:** release-plz emits these into a "Miscellaneous" / "Internal" CHANGELOG section, or omits them per a per-repo config. A per-repo spec choice.
- **Release-PR pattern:** when `bump:none` accumulates across multiple merges with no `bump:patch`+ activity, no release PR is opened; quiet periods are expected, not a bug.
- **Audit trail:** the activity-log row from [G-0008](G-0008-pr-merge-apparatus.md)'s step 1 captures the bump label; `bump:none` merges have a clean audit history showing the developer's intent.
- **Embargo coordination.** For repos in embargo (per [G-0010](G-0010-embargo-flow-architecture.md)), Mode A flag-flip merges that would trigger a release-PR are suspended until the embargo lifts. The release-PR mechanism resumes at unembargo time with the audit-PR pattern G-0010 specifies.
- **Release notes are auto-generated** from the CHANGELOG section for the new version. Editing in the release-PR (Mode A) before merge is the human gate.
- **Migration:** existing repos without release automation adopt release-plz on the first release-needing change. Backfill of a historic CHANGELOG is a per-repo spec choice; starting fresh from current `main` is acceptable.

## More Information

- **Consolidation provenance:** folded from the final-state mechanics of two prior ADRs: the release-plz automation choice and the monotonic non-decreasing version policy. The sources' round-by-round review history remains in version control; only the final-state mechanism is carried here. Embargo coordination, which both sources cross-referenced, is now standalone [G-0010](G-0010-embargo-flow-architecture.md).
