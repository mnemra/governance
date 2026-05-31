---
title: "G-0022: Embargo Flow Architecture — β Default + GHSA Private-Fork"
summary: "No embargo workflow built by default; use GitHub Security Advisories (GHSA) with temporary private fork on first incident; audit-PR re-engages quality gates at T0."
primary-audience: agent
---

# G-0022: Embargo Flow Architecture — β Default + GHSA Private-Fork

**Status:** Accepted
**Date:** 2026-04-30

## Context

The question is what posture the workflow should take toward embargoed security disclosures. Three strawman options were on the table:

- **α:** the Stage 6 approval token (the gate that labels a change for release) encodes `embargo_until` metadata; gate logic respects the date and delays merge or release.
- **β:** no embargo workflow built by default; build it ad-hoc on the first incident.
- **γ:** encode the embargo in a changeset file. This depends on adopting changesets, which [G-0020](G-0020.md) rejected.

Some framing before the decision. An embargo has never happened, and none is expected until the first public package ships. The security/embargo quality attribute (a non-functional property that applies to every project) was dropped from the locked top-three quality attributes, so it isn't driving v1 work.

Research turned up three findings:

- **The dominant ecosystem pattern is GitHub Security Advisories (GHSA) with a temporary private fork.** Draft the advisory, open a private fork, merge fixes in private, then release the advisory and the fix together. This is GitHub's documented approach and what the Rust Security Response Working Group uses for compiler and cargo Common Vulnerabilities and Exposures (CVE) reports.
- **RustSec advisory-db explicitly does not handle embargoed advisories.** Contributors wait until the embargo lifts before filing. RustSec is post-disclosure only.
- **CHANGELOG-staging during an embargo isn't supported by tooling.** Projects publish the CHANGELOG and the advisory at the same moment, at unembargoed-T0, or they ship a generic "security fix" CHANGELOG line and add the advisory link at publication.

β matches the F2 answer and lines up with how 95% or more of Rust crate maintainers handle CVE-class issues. α is the lowest-lift upgrade path if embargo ever becomes a real workflow, since it adds metadata only and needs no new tooling.

## Decision

**Default posture: no embargo workflow built (β).** When the first embargoed disclosure arrives (for example, a published crate gets a CVE report), use the **GHSA with temporary private fork** pattern:

1. The reporter or maintainer files a private security advisory via `gh api -X POST .../security-advisories` or the Security tab.
2. The maintainer creates a temporary private fork through the advisory UI ("Start a temporary private fork").
3. Fix work happens in the private fork; PRs merge in private; CI runs in private (advisory metadata gates visibility). **Note the CI gap.** GitHub doesn't run status checks or third-party Actions integrations on PRs in temporary private forks. So Stage 4 iterate-to-zero (the review loop that runs fix-and-review rounds until no blocking finding remains), Stage 5 `just ci`, and [G-0014](G-0014.md) finding-identity persistence (the rule that decides whether two findings across rounds are the same defect) are all **bypassed during embargo prep**. The audit-PR step at T0 (below) is how the workflow re-engages those gates.
4. **Mode A flag-flip merges are suspended in the affected repo during the embargo.** If the affected repo runs Pattern A (the per-merge bump and flag-activation release model), no `bump:minor` or `bump:major` merges land on public main during the embargo. The reason: a release-PR opened during the embargo would carry feature-y CHANGELOG content that doesn't know about the pending embargo fix, and on the T0 merge that release-PR's content drifts. The operator holds non-security Mode A merges until the embargo lifts. `bump:patch` merges for unrelated bugfixes MAY proceed at operator discretion if the patch is independent of the embargo region.
5. The CHANGELOG entry on the public branch uses a generic placeholder (for example, `### Security: pending advisory disclosure`), with the advisory ID added at publication time. release-plz is configured to allow a manual edit of this section per release; it isn't auto-overridden (the per-repo `release-plz.toml` git-cliff template config preserves the section under a marker comment).
6. **At unembargoed-T0:** the workflow re-engages quality gates through a single follow-up **audit-PR** step, before the GitHub release publishes:

   a. The fix merges from the private fork to public main (the GHSA-resolution merge).

   b. **The audit-PR opens immediately:** a no-op PR (or a trivial CHANGELOG-finalization PR) targets main, carrying the now-public diff in its review surface. Stage 4 (iterate-to-zero) runs in full against the diff. Stage 5 (`just ci`, the `verify-secrets` query, and `cargo audit` against the now-public dependency state) runs in full. G-0014 finding-identity persistence resumes for this audit-PR.

   c. **Stage 6 approval on the audit-PR** carries the standard label set (`stage6-approved`, `release-mode-A`, and `bump:patch`, which is typical for security fixes). [G-0024](G-0024.md) label-set authorization applies. [G-0023](G-0023.md) merge queue handles the merge.

   d. **Only after the audit-PR merges** does the GitHub release (via release-plz or a manual `gh release create`) publish, with the CHANGELOG entry citing the advisory ID.

   The audit-PR isn't optional. It re-engages Stage 4 and Stage 5 review on what the embargo prep skipped. It produces the audit trail that activity_log and the GitHub event log expect. And it provides the human-review checkpoint the workflow gates the release on. The embargo lift itself isn't delayed by the audit-PR: the GHSA-resolution merge in step (a) is the public-disclosure moment, and the release publication in step (d) is purely the changelog-and-tag step.

   **Audit-PR vs. an already-open Mode A release-PR.** If a `bump:patch` independent bugfix proceeded during the embargo (operator discretion, per step 4 above), an unrelated Mode A release-PR may already be open and contain the patch's CHANGELOG entry by the time the GHSA-resolution merge lands. The operator chooses among three coordination paths based on context:

   i. **Close and reopen the Mode A release-PR.** Cleanest when the patch's CHANGELOG entry is small. release-plz reopens automatically on the next push to main, and the new release-PR captures the patch and the embargo fix together.

   ii. **Wait for the Mode A release-PR to merge before the audit-PR.** Cleanest when the Mode A release-PR is approved and queueing. The audit-PR then re-runs Stage 4 and Stage 5 on a clean main.

   iii. **Run the audit-PR alongside the Mode A release-PR.** The audit-PR's bump label is `bump:patch` (security fix); reviewers cross-check that the audit-PR's diff is independent of the Mode A release-PR's `bump:minor`/`bump:major` content. If the diffs conflict, fall back to (i) or (ii).

   The operator picks the path. The embargo coordinator documents the choice in the workspace activity log action string for the audit-PR (for example, `embargo-audit-pr-after-mode-A close-and-reopen`). No mechanical rule fits all cases, so the contextual choice is preserved as audit metadata.

**Trip-wire to upgrade to α:** if any of the following happens, this ADR is amended to add embargo metadata to the gating signal:

- Two or more embargoes in any rolling six-month window.
- An embargo overlaps with a non-security release such that the overlap can't be handled cleanly in human coordination.
- Release cadence settles such that embargoes become a recurring concern.

Until the trip-wire fires, embargo handling is human-coordinated per-incident, with no tooling investment.

The closed-enum bump-label vocabulary ([G-0013](G-0013.md)) deliberately omits embargo labels for v1. Adding them later (for example, `embargo:until-<date>`, `embargo:resolved`) is the α upgrade.

## Alternatives Considered

- **α (build embargo metadata into the Stage 6 token and labels from day one).** Rejected for v1, per F2 and the quality-attribute drop. Building gating logic for a workflow that has never fired is premature; the logic would atrophy without exercise. The trip-wire reserves the option.
- **γ (encode in a changeset file).** Rejected. It depends on changesets adoption, which G-0020 rejected. Not viable.
- **A dedicated embargo branch convention** (for example, `embargo/CVE-2026-XXXX`). Rejected. GitHub Security Advisories' temporary private fork is more secure (a private repo, not just a private branch), better integrated with advisory metadata, and is what GitHub recommends.
- **No security-disclosure protocol at all** (absorb it into the general bug flow). Rejected. CVE-class issues need coordinated disclosure, and the GHSA private-fork path is documented and ready when needed.
- **Custom in-repo embargo metadata** (PR labels, milestones, custom fields). Rejected. It reinvents what GHSA provides natively, requires per-repo training, and doesn't survive mnemra absorption cleanly.

## Consequences

- **Zero v1 implementation work.** No code, no tooling, no workflow YAML. The decision is documented; the GHSA path is ready when needed.
- **Per-repo retrofit:** make sure each in-scope repo has the Security tab enabled (the default for public repos) and a `SECURITY.md` documenting the disclosure path. The workspace template ships `SECURITY.md`; the per-repo spec (the specification that defines what done looks like) adds a repo-specific contact.
- **CHANGELOG generic-line convention:** while an embargo is active, the public-side CHANGELOG entry for the fix uses `### Security: pending advisory disclosure` until unembargoed-T0. release-plz is configured to allow a manual edit of this section per release; it isn't auto-overridden.
- **Audit trail during the embargo:** activity_log entries during embargo work happen in the private fork's clone. On the unembargoed-T0 merge, the fork's commit history merges to public main.
- **Mnemra interaction:** if a mnemra plugin publishes and gets a CVE report, the embargo flow above applies to the mnemra repo specifically. The trip-wire metric is per-workspace (rolling six-month embargoes across all in-scope repos).
- **Trip-wire monitoring:** at retrospectives, count the embargoes since the last retro. A threshold trip schedules the α upgrade as a spec.
- **No GHAS subscription required** for the GHSA private-fork on public repos (free tier). Private repos would need GitHub Advanced Security (GHAS); revisit at the point the first private repo enters scope.
- **Documentation:** the workspace `SECURITY.md` template and the per-repo `SECURITY.md` live in the workspace template alongside other repo-baseline docs.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Audit-PR T0 plus an already-open Mode A release-PR interleaving:** if a `bump:patch` independent bugfix proceeded during the embargo, an unrelated Mode A release-PR may already be open at T0. **Fixed:** added three explicit coordination paths (close-and-reopen, wait-for-Mode-A-merge, audit-PR-alongside) with operator-choice routing. The choice is preserved as audit metadata in the action string.

### 2026-04-30 — Round 1 review amendments

- **GHSA private-fork CI gap:** status checks and third-party Actions don't run on temporary private forks. The original ADR named the GHSA pattern but didn't address how the Stage 4 and Stage 5 quality gates re-engage at T0. **Fixed:** added a six-step embargo flow with an explicit T0 audit-PR step (steps 6a through 6d) that re-engages Stage 4 and Stage 5 against the now-public diff before the GitHub release publishes.
- **Embargo plus an active Mode A release-PR interleaving:** the original ADR didn't address the scenario where an unrelated Mode A release-PR is open during embargo prep. **Fixed:** added an explicit suspension rule for `bump:minor` and `bump:major` merges; `bump:patch` independent bugfixes MAY proceed at operator discretion.
- CVE and GHSA acronyms spelled out on first use.

Status remains **Proposed** pending r2 review.
