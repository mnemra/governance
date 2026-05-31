---
title: "G-0023: GitHub Merge Queue for R26b Enforcement and Intermediate-State CI"
summary: "GitHub Merge Queue is the R26b enforcement mechanism; intermediate-state CI splits into two check categories; admin bypass requires workspace activity log audit row."
primary-audience: agent
---

# G-0023: GitHub Merge Queue for R26b Enforcement and Intermediate-State CI

**Status:** Accepted
**Date:** 2026-04-30

## Context

Discovery, the earlier-generation pass that fixes scope before a spec is written, produced a numbered list of requirements. Requirement R26b states: "at most one PR may merge to main at a time." The mechanism that would enforce it was deferred to the architecture stage. Round 1 review surfaced that it stayed unspecified across the locked ADR set.

- Round 1 review of G-0019 flagged that R26b's "single PR merging at a time" claim is not natively enforceable through GitHub branch protection alone. `required_linear_history` enforces rebase/squash, not single-merger semantics. The candidate mechanisms named were (a) GitHub Merge Queue, (b) auto-merge with rebase + required CI, where a failed rebase acts as an implicit serializer, and (c) a custom GitHub Actions per-repo lock.
- G-0018 (the auto-merge template plus recovery cap) assumes R26b is in effect but does not specify the substrate. Without an explicit mechanism, option (b) is the de facto behavior: rebase-failure as serializer. That's slow under volume, fragile under concurrent activity, and silent when it serializes by way of a merge conflict.

GitHub Merge Queue (generally available since 2024) is the framework-native answer. It gives three things. Single-merge-at-a-time semantics are structural. Intermediate-state CI validation builds a temporary branch (main + earlier queued PRs + this PR), runs required checks against it, and evicts on failure. And the merge method is admin-configured per repo. It composes with G-0018's auto-merge template and operates orthogonally to G-0019's release-sub-flow concurrency.

## Decision

**1. GitHub Merge Queue is enabled per in-scope repo as the R26b enforcement mechanism.** The branch protection setting "Require merge queue" on the default branch (main) makes queueing structural. Direct merges without queue passage are rejected. Auto-merge (`gh pr merge --rebase --auto`) becomes "add to queue when required checks pass" rather than "merge immediately."

**2. Required checks run against the queue's intermediate-state branch.** When a PR is queued, GitHub creates a temporary branch (main + earlier queued PRs + this PR) and runs required status checks against it. Required checks split into two categories:

| Category | Recipes (per G-0006 vocabulary) | Triggers needed |
|----------|-------------------------------|-----------------|
| Required against intermediate state | `verify-test`, `verify-build`, `verify-coverage` | `pull_request` AND `merge_group` |
| Branch-only (not required against intermediate state) | `verify-lint`, `verify-type`, `verify-secrets` | `pull_request` (sufficient) |

Rationale: integration-sensitive checks (tests, build, coverage) need to validate the merged state because conflicts and integration failures only appear there. Static checks (lint, type, secret scan) are determined by the PR's own diff and are not affected by other queued PRs landing first.

The per-repo spec retrofit (the spec being the specification that defines what done looks like) decides which workflows listen for `merge_group` based on this split.

**3. Maximum queue depth defaults to GitHub's repo-level setting.** Workspace volume is low. In-flight PR count is bounded by the active-worktrees circuit-breaker, so the default is sufficient. Trip-wire: if the queue regularly hits the configured cap, raise the limit and revisit the bound.

**4. Admin queue bypass requires audit (R-pending-4 accepted-risk).** GitHub permits admin override at the branch-protection level, so an admin can merge directly and skip the queue. Admin bypass requires a workspace activity log entry justifying the deviation, aligned with G-0013's audit trail discipline. The activity action string is `merge-queue-bypass repo <repo> pr #<n> reason <text>`. Branch-protection setting: admin override stays permitted, and the audit row is the deterrent.

The audit row itself is self-attested. It's accepted as **R-pending-4** in the constraints summary's accepted-risks table. Compensating control: GitHub's own audit log records the merge-queue-bypass at the platform level, cryptographically attributed by way of `actor.login`, so a retrieval-time cross-reference detects forged or missing workspace-side audit rows. Same pattern as G-0024 Layer C for label-set actions. It's documented separately here because the action surface differs.

**5. Interaction with G-0018 auto-merge template, no template change required.** `gh pr merge --rebase --auto` works with merge queue: when required checks pass, `--auto` adds the PR to the queue rather than merging directly. The merge queue is configured at the branch-protection level, not at the merge-command level.

The `--rebase` flag becomes advisory under merge queue. The queue's branch-protection-configured merge method governs the actual merge mechanic. To preserve Discovery requirements R16a/R16c (rebase mode locked for linear history), the per-repo retrofit MUST set the queue's merge method to **rebase** in branch protection.

**6. Trigger model under merge queue.** PRs in the queue trigger `merge_group` workflow events, not `pull_request` events. Required-status-check workflows that must run against the intermediate state MUST listen for `merge_group`:

```yaml
on:
  pull_request:
  merge_group:
```

Workflows triggered only by `pull_request` won't fire for queued PRs and so will never report required-check status against the intermediate state. Per-repo retrofit must update workflow triggers as part of the migration.

**Silent queue stall detection.** If a required-status-check workflow is missing the `merge_group:` trigger, queued PRs will sit in the queue indefinitely waiting for a check that never reports. The queue does not time out on its own. Two detection mechanisms guard against this:

1. **Per-repo retrofit verification.** After enabling merge queue and adding required checks, the operator opens a test PR, adds it to the queue, and verifies it merges within expected latency. A stuck queue means a trigger is missing on a required check.
2. **Stuck-queue alert via `gh api`.** A workspace-level cron or hook periodically queries the queue for PRs sitting beyond N minutes (30 is the recommendation). The alert fires on stuck PRs. The per-repo spec configures the threshold.

**7. Failure semantics tie to G-0018's recovery counter.** When intermediate-state CI fails for a queued PR, GitHub evicts the PR from the queue. The `gh pr merge --auto` enablement is reset.

**Recovery path:** the operator MUST re-invoke the full workspace template script (`bin/pr-create-with-automerge.sh`), not bare `gh pr merge --auto <pr#>`. The script's step 1 detects the existing open PR, emits a `recovery-increment` activity row (per G-0018), and increments the `<!-- recovery-attempts: N -->` PR-description footer. Step 5 re-enables auto-merge, which re-adds the PR to the queue.

Bare `gh pr merge --auto <pr#>` outside the workspace template skips both the audit and the counter increment. See G-0018's "Bypass acknowledgment" for the explicit deferred-protection note.

After 3 evictions (G-0018's cap, count-all semantics), the workspace template script aborts and routes to a fresh PR.

**8. Per-repo opt-in / opt-out.** All in-scope repos, meaning those declaring `follows code-workflow` in their CLAUDE.md, enable merge queue as part of the workflow retrofit. Local-only repos that have not migrated to GitHub yet are not subject to this ADR until migration.

## Alternatives Considered

- **Auto-merge with required CI but no queue (G-0018 status quo).** Rejected. Without an explicit serializer, two PRs that pass required checks at the same time can both attempt to merge. The second's rebase fails and the developer re-rebases. This is rebase-failure as implicit serializer: slow under volume, silent when it serializes, and fragile when CI flakes interact with rebase races.
- **External lock service / GitHub Actions mutex (custom workflow).** Rejected. It reinvents what merge queue provides natively. Merge queue's intermediate-state CI validation is also non-trivial to replicate.
- **`required_linear_history: true` alone.** Rejected. It forces rebase/squash but does not serialize merges. Two PRs can rebase to non-conflicting linear ancestors and both land in close succession.
- **Bors-style external bot (e.g., bors-ng, homu).** Rejected. It's an external dependency with its own auth, infrastructure, and operational surface. Merge queue provides equivalent intermediate-state-CI semantics natively.
- **Merge-commits with a required-linear-history exception.** Rejected per Discovery requirements R16a/R16c. Rebase mode is locked.

## Consequences

- **Per-repo retrofit work** (one-time, per spec migration):
  - Branch protection: enable "Require merge queue" on the default branch; set the queue merge method to **rebase**; configure the required status checks list (the intermediate-state set per Decision 2).
  - Workflow YAML: add `merge_group:` to triggers on every workflow that produces a required status check listed in the intermediate-state set.
  - Verify by way of a PR walk-through: open a PR, observe the `merge_group` workflow run after `gh pr merge --auto` enables queueing.

- **Two-layer serialization across the workflow:**
  - **Merge gate (this ADR):** merge queue serializes PR-to-main merges with intermediate-state CI validation.
  - **Release sub-flow (G-0019 amended):** GitHub Actions `concurrency:` on the release-pr job serializes release-PR creation and update across rapid main pushes.
  The two layers are independent and compose.

- **G-0018 template script unchanged.** `gh pr merge --rebase --auto` works with merge queue; the queue is configured upstream at the branch-protection level. Per-repo retrofit MUST set the queue method to rebase to preserve R16a/R16c.

- **G-0024 interaction.** G-0024 specifies a required status check that validates Stage 6 label cardinality at merge time. That check is part of the intermediate-state set. The queue evicts PRs whose label cardinality drifted between auto-merge enablement and queue head.

- **Embargo flow (G-0022) interacts cleanly.** Queued PRs respect existing release sub-flow concurrency, and embargo coordination is human-driven per G-0022.

- **Recovery semantics:** queue eviction, then the developer rebases, then re-invokes the workspace template script, then G-0018's recovery counter increments (count-all). After 3 evictions, G-0018's cap trips and the cycle bails to a fresh PR.

- **Mnemra migration:** queue configuration is GitHub-native (branch-protection settings plus `merge_group` workflow triggers). It survives mnemra absorption unchanged.

- **Queueing latency:** under serialized merges with intermediate-state CI, end-to-end PR-to-merged latency is `(queue position) × (intermediate-state CI duration) + (merge time)`. For workspace volume, worst-case latency is bounded at ~3× the CI cycle. Acceptable.

- **Branch-only check redundancy.** A branch-only check that the developer fixes after queueing does not block the queue head, because the queue only watches required intermediate-state checks. The PR stays in queue and the fix lands as a follow-up.

- **Admin bypass auditability:** an admin merge directly to main without the queue is structurally permitted. The compensating control is the workspace activity log `merge-queue-bypass` audit row required at bypass time.

- **In-flight verification items at lock time** (verify before per-repo retrofit spec):
  - Exact `gh api -X PATCH` shape for "Require merge queue" plus the queue merge method.
  - Exact `gh pr merge --auto` interaction under the queue: verify by way of a test PR.
  - Default queue depth and merge-limits values for the workspace's GitHub plan tier.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Queue-eviction, bare `gh pr merge --auto` skips the counter:** the original draft said queue-eviction increments the counter, but the counter is incremented at G-0018's step 1, not step 5. **Fixed:** clarified that the canonical recovery path is re-invocation of the full workspace template script, which detects existing-PR state and increments.
- **Admin bypass audit row self-attestation (R-pending-4):** the original ADR named the audit row as a deterrent without addressing self-attestation. **Fixed:** added the R-pending-4 acknowledgment with the compensating-control pattern (GitHub's own audit log cross-reference).
- **Silent queue stall on a missing `merge_group:` trigger:** added two detection mechanisms, per-repo retrofit verification plus a workspace-level stuck-queue alert via `gh api`.

Status remains **Proposed** pending lock.
