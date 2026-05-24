---
title: "G-0022: Embargo Flow Architecture — β Default + GHSA Private-Fork"
summary: "No embargo workflow built by default; use GitHub Security Advisories (GHSA) with temporary private fork on first incident; audit-PR re-engages quality gates at T0."
primary-audience: agent
---

# G-0022: Embargo Flow Architecture — β Default + GHSA Private-Fork

**Status:** Accepted
**Date:** 2026-04-30

## Context

The question: what's the workflow's posture toward embargoed security disclosures? Three strawmen:
- **α:** Stage-6 token encodes `embargo_until` metadata; gate logic respects the date and delays merge / release.
- **β:** No embargo workflow built by default; build it ad-hoc on first incident.
- **γ:** Encoded in changeset file (depends on adopting changesets, which G-0020 rejected).

Pre-framing: embargo has never yet occurred, and is not anticipated until the first public package is released. The security/embargo quality attribute was dropped from the locked top-3 quality attributes.

Research found:
- **Dominant ecosystem pattern: GitHub Security Advisories (GHSA) with temporary private fork.** Draft advisory → private fork → fixes merged in private → advisory + fix released together. This is GitHub's documented approach and what the Rust Security Response Working Group uses for compiler/cargo Common Vulnerabilities and Exposures (CVE) reports.
- **RustSec advisory-db explicitly does not handle embargoed advisories** — contributors wait until embargo lifts before filing. RustSec is post-disclosure only.
- **CHANGELOG-staging during embargo is not directly supported by tooling.** Projects publish CHANGELOG and advisory simultaneously at unembargoed-T0, or include a generic "security fix" CHANGELOG line with the advisory link added at publication.

β matches the F2 answer and aligns with how 95%+ of Rust crate maintainers handle CVE-class issues. α is the lowest-lift upgrade path if/when embargo becomes a real workflow — adds metadata only, doesn't require new tooling.

## Decision

**Default posture: no embargo workflow built (β).** When the first embargoed disclosure arrives (e.g., a published crate receives a CVE report), use the **GHSA with temporary private fork** pattern:

1. Reporter / maintainer files a private security advisory via `gh api -X POST .../security-advisories` or the Security tab.
2. Maintainer creates a temporary private fork via the advisory UI ("Start a temporary private fork").
3. Fix work happens in the private fork; PRs merged in private; CI runs in private (advisory metadata gates visibility). **Note the CI gap:** GitHub does not run status checks or third-party Actions integrations on PRs in temporary private forks. This means Stage 4 iterate-to-zero, Stage 5 `just ci`, and G-0014 finding-identity persistence are all **bypassed during embargo prep**. The audit-PR step at T0 (below) is how the workflow re-engages those gates.
4. **Mode A flag-flip merges suspended in affected repo during embargo.** If the affected repo runs Pattern A (per-merge bump + flag-activation release model), no `bump:minor`/`bump:major` merges land on public main during embargo. Reason: a release-PR opened during embargo would carry feature-y CHANGELOG content not aware of the pending embargo fix; on T0 merge, the release-PR's content drifts. The operator holds non-security Mode A merges until embargo lifts. `bump:patch` merges for unrelated bugfixes MAY proceed at operator discretion if the patch is independent of the embargo region.
5. CHANGELOG entry on the public branch uses a generic placeholder (e.g., `### Security: pending advisory disclosure`) with the advisory ID added at publication time. release-plz is configured to allow manual edit of this section per release; not auto-overridden (per-repo `release-plz.toml` git-cliff template config preserves the section under a marker comment).
6. **At unembargoed-T0:** the workflow re-engages quality gates via a single follow-up **audit-PR** step before the GitHub release publishes:

   a. The fix is merged from the private fork to public main (the GHSA-resolution merge).

   b. **Audit-PR opens immediately:** a no-op PR (or trivial CHANGELOG-finalization PR) targets main, carrying the now-public diff in its review surface. Stage 4 (iterate-to-zero) runs in full against the diff; Stage 5 (`just ci` + `verify-secrets` query + `cargo audit` against the now-public dependency state) runs in full. G-0014 finding-identity persistence resumes for this audit-PR.

   c. **Stage 6 approval on the audit-PR** carries the standard label set (`stage6-approved`, `release-mode-A`, `bump:patch` typical for security fixes); G-0024 label-set authorization applies; G-0023 merge queue handles the merge.

   d. **Only after the audit-PR merges** does the GitHub release (via release-plz or manual `gh release create`) publish, with CHANGELOG entry citing the advisory ID.

   The audit-PR is not optional. It re-engages Stage 4/5 review on what the embargo prep skipped; it produces the audit trail that activity_log + GitHub event log expect; it provides the human-review checkpoint the workflow gates the release on. The embargo lift itself is not delayed by the audit-PR — the GHSA-resolution merge in step (a) is the public-disclosure moment; the release publication in step (d) is purely the changelog-and-tag step.

   **Audit-PR vs. already-open Mode A release-PR.** If a `bump:patch` independent bugfix proceeded during embargo (operator discretion per step 4 above), an unrelated Mode A release-PR may already be open and contain the patch's CHANGELOG entry by the time the GHSA-resolution merge lands. Three coordination paths the operator chooses based on context:

   i. **Close-and-reopen the Mode A release-PR.** Cleanest when the patch's CHANGELOG entry is small. release-plz reopens automatically on the next push to main; the new release-PR captures the patch + the embargo fix together.

   ii. **Wait for the Mode A release-PR to merge before the audit-PR.** Cleanest when the Mode A release-PR is approved-and-queueing; the audit-PR then re-runs Stage 4/5 on a clean main.

   iii. **Audit-PR runs alongside the Mode A release-PR.** The audit-PR's bump label is `bump:patch` (security fix); reviewers cross-check that the audit-PR's diff is independent of the Mode A release-PR's bump:minor/major content. If diffs conflict, fall back to (i) or (ii).

   The operator picks the path; the embargo coordinator documents the choice in the workspace activity log action string for the audit-PR (e.g., `embargo-audit-pr-after-mode-A close-and-reopen`). No mechanical rule fits all cases; the contextual choice is preserved as audit metadata.

**Trip-wire to upgrade to α:** if any of the following happens, this ADR is amended to add embargo metadata to the gating signal:

- Two or more embargoes in any rolling 6-month window
- An embargo overlaps with a non-security release such that the overlap can't be cleanly handled in human coordination
- Release cadence settles such that embargoes become a recurring concern

Until trip-wire fires, embargo handling is human-coordinated per-incident, no tooling investment.

The closed-enum bump-label vocabulary (G-0013) deliberately omits embargo labels for v1. Adding them later (e.g., `embargo:until-<date>`, `embargo:resolved`) is the α upgrade.

## Alternatives Considered

- **α (build embargo metadata into Stage 6 token / labels from day one).** Rejected for v1 per F2 + quality attribute drop. Building gating logic for a workflow that has never fired is premature; logic would atrophy without exercise. Trip-wire reserves the option.
- **γ (encode in changeset file).** Rejected. Depends on changesets adoption, which G-0020 rejected. Not viable.
- **Dedicated embargo branch convention** (e.g., `embargo/CVE-2026-XXXX`). Rejected. GitHub Security Advisories' temporary private fork is more secure (private repo, not just private branch), better integrated with advisory metadata, and is what GitHub recommends.
- **No security-disclosure protocol at all** (absorb into general bug flow). Rejected. CVE-class issues need coordinated disclosure; the GHSA private-fork path is documented and ready when needed.
- **Custom in-repo embargo metadata** (PR labels, milestones, custom fields). Rejected. Reinvents what GHSA provides natively; requires per-repo training; doesn't survive mnemra absorption cleanly.

## Consequences

- **Zero v1 implementation work.** No code, no tooling, no workflow YAML. The decision is documented; the GHSA path is ready when needed.
- **Per-repo retrofit:** ensure each in-scope repo has Security tab enabled (default for public repos) and a `SECURITY.md` documenting the disclosure path. Workspace template ships `SECURITY.md`; per-repo /spec adds repo-specific contact.
- **CHANGELOG generic-line convention:** when an embargo is active, the public-side CHANGELOG entry for the fix uses `### Security: pending advisory disclosure` until unembargoed-T0. release-plz is configured to allow manual edit of this section per release; not auto-overridden.
- **Audit trail during embargo:** activity_log entries during embargo work happen in the private fork's clone; on unembargoed-T0 merge, the fork's commit history merges to public main.
- **Mnemra interaction:** if a mnemra plugin publishes and gets a CVE report, the embargo flow above applies to the mnemra repo specifically. The trip-wire metric is per-workspace (rolling 6-month embargoes across all in-scope repos).
- **Trip-wire monitoring:** at retrospectives, count embargoes since last retro. Threshold trip → schedule the α upgrade as a /spec.
- **No GHAS subscription required** for GHSA private-fork on public repos (free tier). Private repos would need GitHub Advanced Security (GHAS); revisit at the point of first private repo entering scope.
- **Documentation:** workspace `SECURITY.md` template + per-repo `SECURITY.md` lives in the workspace template alongside other repo-baseline docs.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Audit-PR T0 + already-open Mode A release-PR interleaving:** if a `bump:patch` independent bugfix proceeded during embargo, an unrelated Mode A release-PR may already be open at T0. **Fixed:** added three explicit coordination paths (close-and-reopen / wait-for-Mode-A-merge / audit-PR-alongside) with operator-choice routing. The choice is preserved as audit metadata in the action string.

### 2026-04-30 — Round 1 review amendments

- **GHSA private-fork CI gap:** status checks and third-party Actions don't run on temporary private forks. The original ADR named the GHSA pattern but didn't address how Stage 4/5 quality gates re-engage at T0. **Fixed:** added a 6-step embargo flow with explicit T0 audit-PR step (steps 6a-6d) that re-engages Stage 4 + Stage 5 against the now-public diff before the GitHub release publishes.
- **Embargo + active Mode A release-PR interleaving:** original ADR didn't address the scenario where an unrelated Mode A release-PR is open during embargo prep. **Fixed:** added explicit suspension rule for `bump:minor`/`bump:major` merges; `bump:patch` independent bugfixes MAY proceed at operator discretion.
- CVE / GHSA acronyms spelled out on first use.

Status remains **Proposed** pending r2 review.
