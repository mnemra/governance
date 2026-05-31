---
title: "G-0021: Monotonic Non-Decreasing Version Policy (Pattern A)"
summary: "Pattern A repos use monotonic non-decreasing versioning; bump:none is honor-system + reviewer-enforced; revert PR bumps track public-API impact, not numeric distance."
primary-audience: agent
---

# G-0021: Monotonic Non-Decreasing Version Policy (Pattern A)

**Status:** Accepted
**Date:** 2026-04-30

## Context

The semver companion doc declared two release patterns per repo:
- **Pattern A:** per-merge bump (bump on each merge to main, version cut at flag activation).
- **Pattern B:** deploy-as-release (bump only at deploy time; merges are dark).

Under Pattern A, the open question is what shape the version sequence on `main` takes between merges. Strictly increasing, monotonic non-decreasing, or unconstrained?

The monotonic-non-decreasing answer (**Pattern A1**) means: after every merge to main, `prev_version <= new_version`. Most merges advance the version. Some merges (say, a docs-only merge or a CHANGELOG-only edit) MAY produce equal versions. Strictly-increasing (**Pattern A2**) requires every merge to produce a strictly higher version.

The discussion locked Pattern A1. The reason is signal quality: forcing a `bump:patch` minimum on every merge inflates patch counts and dilutes the meaning of the patch number.

Pattern B is out of scope for this ADR (architecture decision record). Pattern B repos declare their own bump policy in their repo spec.

## Decision

**For Pattern A repos, the version sequence on `main` MUST be monotonic non-decreasing.** After every merge to main, `prev_version <= new_version`. A merge MAY produce an equal version when:

- The merge is documentation-only (no `src/` or equivalent change)
- The merge is internal (not surfacing to public API), AND
- The repo's release-plz config is set to skip-bump for the affected paths

Concretely: the bump label (per G-0013) declares the bump intent. The workspace template script (G-0018) sets `bump:patch` as default. Explicit `bump:none` is an additional value in the bump-label family for non-bumping merges:

| Bump label | Effect | Use |
|------------|--------|-----|
| `bump:major` | major+1, minor=0, patch=0 | Breaking API change |
| `bump:minor` | minor+1, patch=0 | Feature addition |
| `bump:patch` | patch+1 | Bugfix or behavior change |
| `bump:none` | no version change | Docs-only, internal-only, CHANGELOG-edit-only |

`bump:none` is **honor-system + Stage 4 reviewer responsibility** (Stage 4 is the review stage of a change's life), not tool-enforced. Research verified that release-plz has no path-coverage feature. It operates on commit-message regex (`release_commits`), not labels or paths. Two paths to enforcement were considered:

1. Build a workspace-side gate (workflow step that reads PR labels via `gh api`, runs `git diff --name-only`, exits non-zero on mismatch).
2. Reframe as honor-system: `bump:none` is the dev's declaration of "no surfacing change"; Stage 4 reviewers catch false `bump:none` claims during review.

This ADR adopts path 2, per the simplicity anchor (no new tools) and the principle that Stage 4 review is the place architectural review lands. The PR body MUST include a one-line path-coverage justification ("changed paths: `docs/**`, `README.md` only, no `src/` change") that reviewers cross-check against `git diff --name-only`. Reviewers who suspect a misleading `bump:none` flag the PR with a `blocker` finding citing the false claim.

**Revert PR semantics.** A PR that reverts a prior merge MUST declare its bump label based on **public-API impact, not numeric distance from the reverted version**. Concretely:

- Reverting a `bump:patch` merge with `bump:patch` is correct (patch undoes a bugfix; net public-API effect is patch-level).
- Reverting a `bump:minor` merge requires `bump:major` if the revert removes public-API surface added by the reverted minor. Semver semantics treat surface removal as a breaking change.
- Reverting a `bump:major` merge with `bump:major` is the obvious case.

The revert PR body MUST cite the reverted PR plus the bump-label rationale. Reviewers cross-check that the bump label matches the public-API delta. The monotonic-non-decreasing numeric invariant is preserved by definition (we only ever bump up). The semver contract is preserved by reviewer discipline on revert bump labels.

Pattern A2 (strictly increasing) is **rejected** for Pattern A repos. Pattern B repos may implement strictly-increasing if their spec chooses; this ADR only constrains Pattern A.

## Alternatives Considered

- **Strictly increasing (Pattern A2).** Rejected. Inflates patch count on docs-only and internal-refactor merges; dilutes the signal of patch numbers; forces release-plz CHANGELOG entries for every merge regardless of consumer impact.
- **Unconstrained / arbitrary** (allow same or lower versions). Rejected. Same-version-after-merge is fine. Lower-version-after-merge breaks every downstream tool's assumption (cargo, crates.io, dependents) and offers no benefit.
- **Date-based versioning instead of semver.** Rejected. Out of scope for this ADR; semver is locked at workspace level.
- **No bump-none label; force bump:patch on every merge.** Rejected per the dilution argument.
- **Bump-none allowed unconditionally.** Rejected. Without any path-coverage check, dev convenience erodes the version signal.

## Consequences

- **Bump-label family adds `bump:none`** as a valid value (extension to G-0013's vocabulary). G-0013 is amended to update the cardinality enforcement to recognize four bump-label values; `bump:none` is now in the closed enum.
- **`bump:none` is honor-system + reviewer-enforced.** No tool gate. Stage 4 reviewers (operational-discipline + test-author scope) cross-check the PR's `bump:none` declaration against `git diff --name-only` and flag misleading claims.
- **Mandatory `bump:none` reviewer routing.** Every `bump:none` PR MUST include the operational-discipline reviewer in the Stage 4 reviewer set, regardless of the per-spec routing the chunk would otherwise have called for. The dispatch envelope (the scoped context handed to a specialist when work is routed to them) detects `bump:none` label presence and adds the operational reviewer to the fan-out automatically. If unavailable, the implementing developer serves as backup with the same path-coverage cross-check duty. Stage 4 cannot iterate-to-zero (run fix-and-review rounds until no blocking finding remains) on a `bump:none` PR until at least one operational-discipline reviewer has acknowledged the path-coverage statement.
- **PR body must declare `bump:none` rationale.** A one-line path-coverage statement in the PR body is mandatory when `bump:none` is set (for example, "changed paths: `docs/**`, `*.md` only, no `src/` change"). The workspace template script (G-0018) does not auto-generate this; the operator or agent setting `bump:none` writes the line.
- **Per-repo retrofit:** add the `bump:none` label to the repo's allowed-labels list. A per-repo `release-plz.toml` may declare a `release_commits` regex to suppress release-PR creation for `bump:none`-style commit messages, but this is a CHANGELOG-quality concern, not a gate.
- **CHANGELOG entries for `bump:none` merges:** release-plz emits these into a "Miscellaneous" or "Internal" CHANGELOG section, or omits them per per-repo `release-plz.toml` config.
- **Pattern B unaffected.** Pattern B repos may use any bump policy; this ADR only governs Pattern A.
- **cargo-semver-checks interaction:** release-plz integration catches breaking-API changes that lack `bump:major` at release-PR open time per G-0020. So `bump:none` on a breaking-API change fails at the release-plz step, even though no path-coverage gate runs upstream.
- **Revert PR bump labels are public-API-driven, not numeric.** Reverting a `bump:minor` that added public surface requires `bump:major`. Reviewers cross-check the bump label against the public-API delta of the revert.
- **Audit trail:** the activity_log row from G-0018's step 1 captures the bump label. `bump:none` merges have a clean audit history showing the dev's intent.
- **Release-PR pattern:** when `bump:none` accumulates across multiple merges with no `bump:patch`-or-higher activity, no release PR is opened. Quiet periods are expected and not a bug.

## Changelog

### 2026-04-30: Round 2 review amendments

- **Honor-system collapse prevention (bump:none routing):** without a routing rule, the honor-system has no enforcement when the spec-driven reviewer fan-out happens not to include the operational-discipline reviewer. **Fixed:** added a mandatory operational-reviewer-in-reviewer-set rule for `bump:none` PRs (the workspace template detects the label and adds the reviewer to fan-out automatically).

### 2026-04-30: Round 1 review amendments

- **Path-coverage check unimplemented:** the original ADR claimed release-plz enforced a path-coverage gate for `bump:none`. Verified release-plz has no such feature. It operates on commit-message regex, not labels or paths. **Fixed:** reframed `bump:none` as honor-system + Stage 4 reviewer responsibility. Building a workspace-side gate was the alternative, rejected on simplicity-anchor grounds.
- **Revert PR bump semantics:** reverting a `bump:minor` removes public-API surface; `bump:patch` understates the breakage. **Fixed:** added explicit revert-PR semantics. The bump label tracks public-API impact, not numeric distance. Reviewers verify.

Status remains **Proposed** pending r2 review on the amended Decision + Consequences sections.
