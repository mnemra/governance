---
title: "G-0010: Embargo Flow Architecture — Default No-Build + Security-Advisory Private Fork"
summary: "No embargo workflow is built by default; when the first embargoed disclosure arrives, use the host's Security Advisory temporary-private-fork pattern, re-engaging the skipped review and CI gates via a mandatory audit-PR at unembargo time. A trip-wire upgrades to metadata-in-the-gate only if embargoes recur."
primary-audience: agent
---

# G-0010: Embargo Flow Architecture — Default No-Build + Security-Advisory Private Fork

**Status:** Accepted
**Date:** 2026-04-30

> **Provisional standalone:** kept separate from the release apparatus because it is a security flow applicable to any repo, not Rust-specific. It may consolidate with the security ADRs later.

## Context

The question was the workflow's posture toward embargoed security disclosures. Three options were on the table:

- **Metadata-in-the-gate:** the approval token encodes an `embargo_until` value; gate logic respects the date and delays merge / release.
- **No embargo workflow by default:** build it ad-hoc on the first incident.
- **Changeset-encoded:** carried in a changeset file, which depends on adopting changesets (rejected elsewhere).

The stated posture was: no embargo has ever occurred, and none is anticipated until the product publishes (which may bring CVE reports). Security/embargo was not among the locked top-three quality attributes.

Research found:

- **The dominant ecosystem pattern is the host's Security Advisory with a temporary private fork.** Draft advisory → private fork → fixes merged in private → advisory and fix released together. This is the host's documented approach and what the Rust language's Security Response working group uses for compiler and package-manager CVEs.
- **The Rust advisory database explicitly does not handle embargoed advisories.** Contributors wait until the embargo lifts before filing. It is post-disclosure only.
- **CHANGELOG-staging during embargo is not directly supported by tooling.** Projects publish the CHANGELOG and advisory simultaneously at unembargo time, or include a generic "security fix" line with the advisory link added at publication.

The no-build default matches the stated posture and aligns with how the large majority of package maintainers handle CVE-class issues. Metadata-in-the-gate is the lowest-lift upgrade path if and when embargo becomes a real workflow; it adds metadata only, and requires no new tooling.

## Decision

**Default posture: no embargo workflow built.** When the first embargoed disclosure arrives (e.g., the product publishes and receives a Common Vulnerabilities and Exposures (CVE) report), use the **Security Advisory with temporary private fork** pattern:

1. The reporter or maintainer files a private security advisory (via the host API or the Security tab).
2. The maintainer creates a temporary private fork via the advisory UI ("Start a temporary private fork").
3. Fix work happens in the private fork; PRs merge in private; CI runs in private (advisory metadata gates visibility). **Note the CI gap:** the host does not run status checks or third-party integrations on PRs in temporary private forks. This means Stage 4 iterate-to-zero, Stage 5 `just ci`, and the G-0004 finding-identity persistence are all **bypassed during embargo prep**. The audit-PR step at unembargo time (below) is how the workflow re-engages those gates.
4. **Flag-flip release merges are suspended in the affected repo during embargo.** If the affected repo runs the per-merge-bump + flag-activation release model, no `bump:minor` / `bump:major` merges land on public main during embargo; a release-PR opened during embargo would carry feature CHANGELOG content unaware of the pending embargo fix, and would drift on unembargo merge. The operator holds non-security release merges until the embargo lifts. Independent `bump:patch` merges for unrelated bugfixes MAY proceed at operator discretion if the patch is independent of the embargo region.
5. The CHANGELOG entry on the public branch uses a generic placeholder (e.g., `### Security: pending advisory disclosure`) with the advisory ID added at publication time. The release tool is configured to allow manual edit of this section per release, not auto-overridden (a per-repo config preserves the section under a marker comment).
6. **At unembargo time:** the workflow re-engages the quality gates via a single follow-up **audit-PR** before the release publishes:

   a. The fix is merged from the private fork to public main (the advisory-resolution merge).

   b. **The audit-PR opens immediately:** a no-op or trivial CHANGELOG-finalization PR targets main, carrying the now-public diff in its review surface. Stage 4 (iterate-to-zero) runs in full against the diff; Stage 5 (`just ci` + the secret-scanning query + a dependency audit against the now-public dependency state) runs in full. G-0004 finding-identity persistence resumes for this audit-PR.

   c. **Stage 6 approval on the audit-PR** carries the standard label set (`stage6-approved`, the release-mode label, `bump:patch`, typical for security fixes); G-0003 label-set authorization applies; the G-0008 merge apparatus handles the merge.

   d. **Only after the audit-PR merges** does the release publish, with the CHANGELOG entry citing the advisory ID.

   The audit-PR is not optional. It re-engages Stage 4/5 review on what embargo prep skipped, produces the audit trail the activity log and host event log expect, and provides the human-review checkpoint the workflow gates the release on. The embargo lift itself is not delayed by the audit-PR; the advisory-resolution merge in step (a) is the public-disclosure moment; the release publication in step (d) is purely the changelog-and-tag step.

   **Audit-PR vs. an already-open release-PR.** If an independent `bump:patch` bugfix proceeded during embargo (operator discretion per step 4), an unrelated release-PR may already be open and contain the patch's CHANGELOG entry by the time the advisory-resolution merge lands. Three coordination paths, chosen by context:

   i. **Close-and-reopen the release-PR.** Cleanest when the patch's CHANGELOG entry is small. The release tool reopens automatically on the next push to main; the new release-PR captures the patch and the embargo fix together.

   ii. **Wait for the release-PR to merge before the audit-PR.** Cleanest when the release-PR is approved and queueing; the audit-PR then re-runs Stage 4/5 on a clean main. The release containing the embargo fix lands as a follow-up release.

   iii. **Run the audit-PR alongside the release-PR.** The audit-PR's bump label is `bump:patch` (security fix); semver checks and Stage 4 reviewers cross-check that the audit-PR's diff is independent of the release-PR's minor/major content. If the diffs conflict, fall back to (i) or (ii).

   The operator picks the path; the embargo coordinator documents the choice in the audit-PR's activity-log entry. No mechanical rule fits all cases; the contextual choice is preserved as audit metadata.

**Trip-wire to upgrade to metadata-in-the-gate:** if any of the following happens, this ADR is amended to add embargo metadata to the gating signal:

- Two or more embargoes in any rolling six-month window;
- An embargo overlaps with a non-security release such that the overlap cannot be cleanly handled in human coordination;
- The product's publish cadence settles such that embargoes become a recurring concern.

Until the trip-wire fires, embargo handling is human-coordinated per-incident, with no tooling investment.

The closed-enum bump-label vocabulary (G-0003) deliberately omits embargo labels for v1. Adding them later (e.g., `embargo:until-<date>`, `embargo:resolved`) is the upgrade.

## Alternatives Considered

- **Build embargo metadata into the approval token and labels from day one.** Rejected for v1: building gating logic for a workflow that has never fired is premature; the logic would atrophy without exercise. The trip-wire reserves the option.
- **Encode embargo state in a changeset file.** Rejected. It depends on changeset adoption, which the release apparatus (G-0009) rejected. Not viable.
- **A dedicated embargo branch convention** (e.g., `embargo/CVE-2026-XXXX`). Rejected. The host's temporary private fork is more secure (a private repo, not just a private branch), better integrated with advisory metadata, and is the host's recommendation.
- **No security-disclosure protocol at all** (absorb into the general bug flow). Rejected. CVE-class issues need coordinated disclosure; the private-fork path is documented and ready when needed.
- **Custom in-repo embargo metadata** (PR labels, milestones, custom fields). Rejected. It reinvents what the host's Security Advisory provides natively, requires per-repo training, and does not survive tooling consolidation cleanly.

## Consequences

- **Zero v1 implementation work.** No code, no tooling, no workflow config. The decision is documented; the private-fork path is ready when needed.
- **Per-repo retrofit:** ensure each in-scope repo has the Security tab enabled (default for public repos) and a `SECURITY.md` documenting the disclosure path. A workspace template ships `SECURITY.md`; the per-repo spec adds a repo-specific contact.
- **CHANGELOG generic-line convention:** while an embargo is active, the public-side CHANGELOG entry for the fix uses a placeholder until unembargo time. The release tool is configured to allow manual edit of this section per release.
- **Audit trail during embargo:** activity-log entries during embargo work happen in the private fork's clone; on unembargo merge, the fork's commit history merges to public main. The Stage 6 audit (per G-0003) runs on the private-fork PR; the corresponding activity row stays internal.
- **Product interaction:** if the product publishes and a bug in a shipped component becomes a CVE, the embargo flow above applies to that repo specifically. The trip-wire metric is measured across all in-scope repos (rolling six-month embargo count).
- **Trip-wire monitoring:** at retrospectives, count embargoes since the last retro. A threshold trip schedules the upgrade as its own spec.
- **No paid advanced-security subscription required** for the private-fork flow on public repos (free tier). Private repos would need the paid tier; revisit at the point a private repo first enters scope.
- **Documentation:** a `SECURITY.md` template plus a per-repo `SECURITY.md` lives alongside other repo-baseline docs.
- **Substrate nuance:** the Rust advisory database is post-disclosure only, but mirrors published advisories roughly 72 hours after disclosure, so the workflow's reliance on the host's Security Advisory as canon during embargo (rather than the advisory database) is the right substrate.
