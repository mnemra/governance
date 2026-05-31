---
title: "G-0018: Workspace Merge Template + Auto-Merge Recovery Cap"
summary: "Canonical Stage 6–7 sequence in a workspace template script; recovery cap = 3 (count-all); counter in PR description footer; audit via workspace activity log."
primary-audience: agent
---

# G-0018: Workspace Merge Template + Auto-Merge Recovery Cap

**Status:** Accepted
**Date:** 2026-04-30

## Context

Two adjacent decisions converged into one merge-flow contract. They share a substrate, so they're recorded together.

- **Auto-merge invocation sequence:** what is the canonical sequence between Stage 6 (the change-lifecycle step where a human approves and labels the change) and `gh pr merge --auto`? The sequence touches four things: activity logging for audit, git mechanics for the squash, label setting as the gating signal defined in [G-0013](G-0013.md), and the merge-mode invocation itself. Stage 7 (auto-merge) has multiple steps that must run in order. The open question was whether each repo re-implements that sequence or whether they all share one.
- **Auto-merge recovery cap:** how many recovery attempts are allowed before the auto-merge cycle gives up and routes the work to a fresh PR? The candidates were 3 and 5. Both fit the simplicity preference. The other open point was counting semantics: count-all, where any reset counts regardless of what triggered it, versus conditional counting, where only some resets count. That was settled as count-all, because a counter you can predict beats one whose value depends on judgment calls.

These bundled because the recovery cap is a property of the workspace merge template. The template is the thing that increments the counter, and it's the thing that bails when the cap trips.

## Decision

A single **workspace template script** lives at `workspace/bin/pr-create-with-automerge.sh` (or the equivalent path once the workspace is absorbed into mnemra). Each repo gets its own copy through a `/spec`-driven retrofit. Anything repo-specific (the default branch name, the PR body template) lives in that repo's copy, not in the shared template.

Canonical sequence, run after Stage 6 approval and after Stage 5 (review) is green:

```bash
# 1. Durable approval audit (per G-0013)
brain activity log --actor <maintainer> \
  --action "stage6-approved chunk #<ref> mode <X>" \
  --task-id <chunk-task-id>

# 2. Squash intra-branch commits to one conventional-commits commit
git -C <wt> reset --soft $(git -C <wt> merge-base HEAD main)
git -C <wt> commit -m "<conv-commits header>" \
  -m "<body with release-mode + flag-id + chunk-ref>"

# 3. Push squashed branch
git -C <wt> push origin <branch>

# 4. Create PR with locked label set (per G-0013 cardinality)
gh pr create --base main \
  --title "<conv-commits header>" --body "<body>" \
  --label "bump:<level>" \
  --label "release-mode-<X>" \
  --label "stage6-approved"

# 5. Enable auto-merge in rebase mode
gh pr merge --rebase --auto <pr#>
```

**Recovery cap = 3, count-all semantics.** Any reset of the auto-merge cycle counts as one recovery attempt, whatever triggered it: a branch update, a commit amend, a force-push, a label re-application, a manual `gh pr merge --auto` re-invocation. After 3 attempts the cycle bails. The PR is closed and a fresh PR is opened carrying the corrected state.

The recovery counter lives per-PR in the PR description, as a parseable footer:

```
<!-- recovery-attempts: <N> -->
```

The workspace template script reads-and-increments this footer at every step-1 invocation that targets an existing open PR. When N reaches 3 or more, it emits to stderr and aborts.

**Recovery counter integrity is accepted-risk (R-pending-1).** The PR description is editable by anyone with PR-edit permission, including through the GitHub web UI. The counter is convention, not enforcement. An actor who wants more than 3 attempts can edit the description to reset the counter. This is accepted as a workspace-private risk.

**Compensating control.** When the template script detects an existing open PR at step 1, that means a recovery cycle is already in flight. In that case it writes an additional `recovery-increment` activity row at the new counter value:

```
brain activity log --actor <operator-or-automation> \
  --action "stage7-recovery-attempt N=<count> for PR #<pr#>" \
  --task-id <chunk-task-id>
```

This produces a during-recovery audit trail. Suppose someone tampers with the counter, resetting `<!-- recovery-attempts: N -->` from 2 back to 0. The recovery-increment activity rows still sit in the task DB at N=1 and N=2. The workspace-private audit log keeps the truth even when the GitHub-side substrate is mutated. A retrospective audit reconstruction joins the activity log's recovery-increment rows to the PR's final state to detect the tampering.

**Bypass acknowledgment.** An operator who invokes `gh pr merge --auto <pr#>` directly, outside the template script, skips both the step-1 audit row and the counter increment. That's intentional. The script is the canonical recovery path; a bare CLI invocation forfeits both the audit and the recovery-cap protection. The per-repo retrofit runbook documents this.

There's a trip-wire to upgrade the substrate, either by moving the counter into a label family `recovery:1/2/3` under [G-0024](G-0024.md) authorization, or to a workflow-protected GitHub Actions variable. The trip-wire fires if 3 or more counter-bypass incidents are observed in any rolling 6-month window.

**R26b enforcement is delegated to [G-0023](G-0023.md) (GitHub Merge Queue).** Branch protection on its own has no native single-merge-at-a-time gate. G-0023 adopts GitHub Merge Queue as the structural enforcement. The G-0018 template script doesn't change for this: `gh pr merge --rebase --auto <pr#>` still works under a merge queue. `--auto` becomes "add to queue when checks pass," and the queue serializes the merges itself.

**Cardinality and label-set authorization are delegated to [G-0024](G-0024.md).** G-0024 specifies the `verify-stage6-labeler` workflow and the `verify-stage6-labels` required-status-check. The template's step 4 keeps its shape; G-0024 adds the gates around it.

## Alternatives Considered

- **Per-repo bespoke merge scripts.** Rejected. Drift across repos defeats the predictability the workflow depends on. A workspace template plus per-repo copies is the canon.
- **No template; document the sequence only.** Rejected. Manual execution invites step-skip mistakes: forgetting the audit, mis-labeling, picking the wrong merge mode.
- **Recovery cap = 5.** Considered. A looser cap lets work proceed when recovery is small. Rejected for v1. A cap of 3 forces a step-back when recovery isn't converging, recovery PRs are cheap, and 5 invites trying and trying. Easy to relax later if 3 bites in practice.
- **Conditional counting** (for example, only counting "real" failures, not config-tweak resets). Rejected. It adds judgment-call branches to a mechanical counter and so defeats predictability. count-all is the simpler invariant.
- **Counter in a task-DB `recovery_attempts` column.** Rejected. Same workspace-CLI-in-maintenance argument made in G-0013 and [G-0014](G-0014.md). The PR description footer is the lean substrate.
- **Auto-merge in squash mode** instead of rebase. Rejected. Discovery locked rebase mode for linear history, and squash is disabled at the repo-settings level.

## Consequences

- **Per-repo retrofit:** copy the workspace script as `bin/pr-create-with-automerge.sh` (or the repo's equivalent), tailor the body template, commit. This runs as a deployment-specialist dispatch per repo, as part of the merge-mode migration runbook.
- **Workspace template re-renders:** when this ADR or the template script changes, a `/spec` retrofit re-renders the per-repo copies.
- **Recovery-cap trip is loud.** The script aborts to stderr with the PR ref and the attempt count. The operator sees it immediately. No silent failure modes.
- **Recovery footer is parseable.** `grep -oP '(?<=recovery-attempts: )\d+'` extracts the counter, so future tooling can read it.
- **Step 1 audit row precedes step 4 PR creation.** Auditing before the PR is created means a failed PR creation still leaves an audit trail of intent.
- **Stage 6 approval action ties to the chunk task ID.** The `--task-id <chunk-task-id>` argument links the approval to the originating spec chunk. A future audit reconstruction joins the activity log to tasks.
- **Squash to a single conventional-commits commit (step 2)** is the linear-history mechanism. The PR body carries the detail; the commit message is the single source of truth for release-plz CHANGELOG generation under [G-0020](G-0020.md).
- **Cross-repo:** every in-scope repo shares the canonical sequence. Per-repo divergence is a bug, not a feature.
- **Template script language:** bash for v1, since it's zero-dependency and universal. Revisit later if the script grows past roughly 50 lines or needs richer error handling, at which point bash gives way to a Rust binary.
- **Squash and signed-commit attribution.** Step 2's `git reset --soft` to merge-base drops the GPG signatures from intra-branch commits when they're present. If a per-repo signing policy shows up later, the template's squash step will need its own ADR to handle signatures. Acknowledged as known-future-work.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Compensating control widened:** the original control caught creation-time tampering only. **Fixed:** the script now emits a `recovery-increment` activity row at step 1 when it detects an existing PR (a recovery cycle). The during-recovery audit trail is now preserved in the task DB even when the PR-body footer is mutated.
- **Bypass-acknowledgment clarification:** operators who invoke `gh pr merge --auto` directly bypass the counter and the audit by design. Documented in the retrofit runbook and in this ADR so the bypass is explicit.

### 2026-04-30 — Round 1 review amendments

- **Recovery counter integrity:** the PR-body footer is mutable, so the cap is convention, not enforcement. **Resolved as accepted risk** per maintainer triage. Compensating control = the step-1 audit row plus a GitHub event-log cross-reference. Trip-wire = 3 bypass incidents in 6 months.
- **R26b mechanism:** **Resolved by cross-reference to G-0023** (GitHub Merge Queue). The template script is unchanged; the queue is the structural enforcement.
- **Label authorization and cardinality enforcement:** **Resolved by cross-reference to G-0024** (Stage 6 label-set authorization).
- **Bash threshold:** tightened the revisit threshold from 100 to 50 lines.
- **Squash signed-commit acknowledgment:** added a Consequence noting GPG signature loss under `reset --soft`.

Status remains **Proposed** pending r2 review.
