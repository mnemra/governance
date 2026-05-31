---
title: "G-0024: Stage 6 Approval — Label-Set Authorization + Required-Status-Check Enforcement"
summary: "Two GitHub-native enforcement layers: Layer A restricts who may apply gating labels; Layer B wraps cardinality validation as a required-status-check; Layer C audit cross-reference at retrieval time."
primary-audience: agent
---

# G-0024: Stage 6 Approval — Label-Set Authorization + Required-Status-Check Enforcement

**Status:** Accepted
**Date:** 2026-04-30

## Context

[G-0013](G-0013.md) (a governance ADR, a decision that applies across the ecosystem rather than to one project) locked the closed-enum label vocabulary as the canonical signal for Stage 6 approval. Stage 6 is the approval-labelling step in a change's numbered lifecycle, the point where a reviewer marks a change ready to merge. The first round of security review found a structural authorization gap. G-0013 says *what* the labels are and *what* the gate logic does. It doesn't say *who* may apply them, or *what* stops the GitHub merge UI from skipping the gate logic entirely.

By GitHub default, any collaborator with the **Triage** role or higher can apply labels through the web UI or `gh api`. The protected branch has no required status check that depends on label cardinality validation. Put those two facts together and the workflow's Stage 6 gate is mechanically bypassable in two ways:

1. **Label spoofing.** Any Triage+ collaborator applies `stage6-approved` + `release-mode-A` + `bump:patch`. The auto-merge cycle (the final lifecycle step that lands an approved change) proceeds. The audit row records the maintainer's name as actor, because per G-0013 that row is self-attestation, but the actual approver was someone else. (The maintainer is the role that owns the canon and sets direction.)
2. **UI merge bypass.** A repo admin clicks GitHub's "Merge pull request" button directly, skipping the workspace template script ([G-0018](G-0018.md)). The cardinality check the script carries never runs. The merge lands.

In v1 with a single sequencer, both paths are theoretical. Move to a multi-collaborator future state ("workflow IS what mnemra adopts" with non-maintainer contributors and automation accounts) and both paths become real attack surfaces.

This ADR closes both gaps with GitHub-native primitives.

## Decision

**Two GitHub-native enforcement layers, both required per in-scope repo:**

### Layer A — Restrict label-set permission via repository ruleset

For each in-scope repo, configure a repository ruleset (via `gh api -X POST /repos/{owner}/{repo}/rulesets` or repo Settings → Rules) that restricts who may apply or remove labels in the gating families:

| Label family | Permitted actors |
|--------------|------------------|
| `stage6-approved` (presence) | Named maintainer (single-actor allowlist in v1); F1: explicit allowlist of approver identities |
| `release-mode-A`, `release-mode-B`, `release-mode-A-exception` | Named maintainer; automation accounts MAY apply during the workspace template script invocation, never independently |
| `bump:patch`, `bump:minor`, `bump:major`, `bump:none` | Named maintainer; automation accounts MAY apply during the workspace template script invocation |
| `recovery:1`, `recovery:2`, `recovery:3` (if adopted per G-0018 amendment) | Same as `bump:*` family |

Other labels (informational, project-tracking) stay unrestricted.

**Ruleset enforcement mechanism:** GitHub's ruleset API supports an `actor_id` allowlist on the `pull_request` and `repository` rule types via custom labels rules where available. When the platform tier doesn't expose that, the fallback is a GitHub Actions workflow, `verify-stage6-labeler`, triggered on the `pull_request.labeled` event:

```yaml
# .github/workflows/verify-stage6-labeler.yml
on:
  pull_request:
    types: [labeled, unlabeled]
jobs:
  verify-labeler:
    if: contains(fromJson('["stage6-approved","release-mode-A","release-mode-B","release-mode-A-exception","bump:patch","bump:minor","bump:major","bump:none"]'), github.event.label.name)
    runs-on: ubuntu-latest
    steps:
      - name: Verify labeler is in allowlist
        run: |
          if [[ "${{ github.event.sender.login }}" != "<maintainer-github-handle>" \
             && "${{ github.event.sender.login }}" != "<ci-bot-handle>" \
             && "${{ github.event.sender.login }}" != "<release-bot-handle>" ]]; then
            echo "::error::Label ${{ github.event.label.name }} applied by unauthorized actor ${{ github.event.sender.login }}"
            exit 1
          fi
```

The per-repo retrofit spec (a specification that defines what done looks like, written before implementation) picks one of these based on plan tier. Verify availability via `gh api repos/{owner}/{repo}` plus the ruleset endpoint.

### Layer B — Required-status-check tying cardinality to branch protection

Per in-scope repo, branch protection on `main` includes a required status check that depends on a `verify-stage6-labels` workflow:

```yaml
# .github/workflows/verify-stage6-labels.yml
on:
  pull_request:
    types: [opened, edited, synchronize, labeled, unlabeled]
  merge_group:  # also runs in queue per G-0023
jobs:
  verify-labels:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: read
    steps:
      - name: Verify Stage 6 label cardinality
        run: |
          # Read current labels via gh api
          # Validate exactly-one of release-mode-* family when stage6-approved present
          # Validate exactly-one of bump:* family when stage6-approved present
          # Fail loudly on cardinality violation; never pick-rather-than-fail
```

Branch-protection settings list **both** `verify-stage6-labels` AND `verify-stage6-labeler` in `required_status_checks.contexts`. Both are required-status-checks. A failing labeler check (Layer A) and a failing cardinality check (Layer B) each block the merge on their own. Listing Layer A in `required_status_checks` is what makes it preventive instead of detective. A spoofed-labeler PR with valid cardinality would still merge if Layer A were only a status check not named in required-status-checks. Naming Layer A as a required-status-check closes that gap.

**Layer A fail-open behavior under Actions out-of-quota:** if the GitHub Actions quota is exhausted, `verify-stage6-labeler` won't run, and `required_status_checks` treats a missing required check as "blocked." The PR can't merge. That's fail-closed, not fail-open. Document it in the per-repo retrofit runbook so operators don't mistake quota-exhaustion for a workflow bug.

**Cardinality-failure mode:** ABORT, never pick. The check fails loudly. Its stderr message names the conflicting labels and the cardinality rule violated. The PR's check status reads "failure" until the labels are corrected.

### Layer C — Audit cross-reference at retrieval time (R-pending-2 mitigation)

The audit row in the workspace activity log carries the actor as a CLI argument. That's self-attestation, and it can't survive a credential compromise. The mitigation tracks against accepted-risk R-pending-2 (a known, accepted security gap held open for a later fix).

The audit-row action string captures every gating-label value:

```
brain activity log --actor <maintainer> \
  --action "stage6-approved chunk #<ref> mode <X> bump <Y>" \
  --task-id <chunk-task-id>
```

When reconstructing approval audit, query both surfaces and cross-check across all three label families (approval, release-mode, bump):

```bash
# 1. activity_log query — extract approval, mode, and bump values
brain activity log --filter 'action LIKE "stage6-approved%"' --task-id <chunk>

# 2. GitHub event log query — query all three label families
gh api /repos/{owner}/{repo}/issues/<pr#>/events \
  --jq '[.[] | select(.event=="labeled" and (
    .label.name=="stage6-approved" or
    (.label.name | startswith("release-mode-")) or
    (.label.name | startswith("bump:"))
  ))]'
```

If the activity_log row's `actor` doesn't match the GitHub event log's `actor.login` for any of the three label families' labeled events, audit reconstruction flags the inconsistency. This catches credential-compromise scenarios where the audit row was forged but the GitHub event log, which is cryptographically attributed, shows a different labeler.

**Eventual-consistency note.** GitHub's `/issues/<pr#>/events` endpoint reflects label changes within a few seconds of the underlying event. Audit reconstruction MUST query the event log only after the PR's `merged_at` timestamp plus a small safety margin (recommend 60 seconds), so it doesn't catch a mid-flight inconsistency.

## Alternatives Considered

- **Status quo (G-0013 unchanged).** Rejected. Security review showed the gate is mechanically bypassable in two ways. Multi-collaborator state makes both paths real.
- **Cryptographic actor binding via OIDC subject in audit row.** Rejected for v1. It's real implementation work, it doesn't fit the "no new tools" simplicity anchor, and mnemra-content-plugin can do it later. The Layer C cross-reference is the lean substitute.
- **Branch protection alone (no Layer A label-permission restriction).** Rejected. Layer B catches the merge-time cardinality, but Layer A prevents the upstream label-spoofing event. Defense-in-depth needs both.
- **Pull request review approvals as the gate signal** (drop labels entirely; use GitHub's native review-approvals UI). Rejected. G-0013's alternatives locked the closed-enum label vocabulary as the canonical signal for downstream tooling. Reverting to review-approvals re-opens settled architecture.
- **Workspace-side check via webhook → external service.** Rejected. It adds infrastructure. GitHub-native rulesets plus Actions cover the gate with no external dependencies.

## Consequences

- **Per-repo retrofit:** add the two workflows (`verify-stage6-labeler.yml` + `verify-stage6-labels.yml`); update branch protection to require **both** `verify-stage6-labeler` AND `verify-stage6-labels` in `required_status_checks.contexts`; configure the repository ruleset for label-set permission. This goes out as a deployment-specialist dispatch per repo (a scoped task handed to the operations specialist) inside the merge-mode migration runbook.
- **G-0013 references G-0024 for enforcement mechanism.** The G-0013 amendment adds: "Cardinality enforcement and label-set authorization are specified in G-0024."
- **G-0018 references G-0024 for label-set authority.** The workspace template script sets the labels under the automation account's identity. The labels propagate through Layer A's check, since automation accounts are in the allowlist.
- **G-0023 (merge queue) interacts with Layer B.** `verify-stage6-labels` is required against intermediate state because label cardinality is a property of the PR's metadata. G-0023 lists `verify-stage6-labels` in its required-checks set.
- **R-pending-2 mitigation in place via Layer C.** The accepted-risk note in G-0018 for the audit-row self-attestation gap points to G-0024 Layer C as the compensating control.
- **Cardinality-failure semantics locked.** ABORT and fail loud, never pick a value. The `verify-stage6-labels` workflow's exit code is the authority. Conflicting-label state never silently resolves to a chosen value.
- **GitHub plan tier dependency:** Layer A's repository ruleset mechanism varies by plan tier. The Actions-based fallback (a workflow checking `github.event.sender.login` against an allowlist) works on all tiers and is the v1 default.
- **Allowlist maintenance:** the v1 allowlist is the named maintainer plus designated automation accounts. Multi-collaborator state extends the allowlist via a separate spec.
- **External-PR contributors:** out of scope for v1. In-scope repos restrict PR creation to collaborators. If and when external PRs enter scope, this ADR gets amended with a `pull_request_target` policy and fork-PR label-handling.
- **Mnemra migration:** the GitHub-native primitives (rulesets, branch protection, Actions workflows) survive mnemra absorption unchanged. The allowlist's substrate may shift if mnemra introduces a richer identity model, but the pattern holds: named approvers gate the labels, and cardinality is a required-status-check.
- **Audit cross-reference cost at retrieval time:** one extra `gh api` call per audit reconstruction. That cost is acceptable. Audit retrieval is human-initiated, not a hot path.
- **Bot allowlist by-name caveat (R-pending-5).** The Actions-based Layer A fallback enforces by `github.event.sender.login`, which is sender identity, not authentication context. A compromised credential for an automation account can apply gating labels through Layer A's allowlist. Mitigations: fine-grained credentials scoped to label-write permission only, 90-day rotation, and GitHub App tokens (preferred when feasible, per the G-0020 token strategy). Captured as R-pending-5 in the constraints summary's accepted-risks table.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Layer A detective-only gap:** the original draft listed only `verify-stage6-labels` in `required_status_checks.contexts`. Spoofed-labeler PRs with valid cardinality would still merge under Layer B alone. **Fixed:** both `verify-stage6-labeler` AND `verify-stage6-labels` are now required-status-checks.
- **Layer C narrow:** the Layer C cross-reference covered `stage6-approved` only. The bump and release-mode label values weren't queried, and the audit-row action string didn't carry the bump value. **Fixed:** widened the action-string format to include `bump <Y>` and widened the GitHub event log query to all three label families.
- **Layer A out-of-quota fail-open concern:** verified fail-closed. `required_status_checks` treats a missing required check as blocked, so quota exhaustion blocks merges, it doesn't unblock them. Added the explanatory paragraph and a retrofit-runbook note.
- **Eventual-consistency note added** to Layer C.
- **R-pending-5 added:** the bot allowlist by-name credential-compromise risk, with named compensating controls.

Status remains **Proposed** pending lock.
