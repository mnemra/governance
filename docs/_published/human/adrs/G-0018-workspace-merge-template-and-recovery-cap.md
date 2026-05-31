---
title: "G-0018: Workspace Merge Template + Auto-Merge Recovery Cap"
summary: "Canonical Stage 6–7 sequence in a workspace template script; recovery cap = 3 (count-all); counter in PR description footer; audit via workspace activity log."
primary-audience: agent
---

# G-0018: Workspace Merge Template + Auto-Merge Recovery Cap

**Status:** Accepted
**Date:** 2026-04-30

## Context

Two adjacent decisions converged into a single merge-flow contract. This is a governance ADR (a decision record that applies across the whole ecosystem, not to one project), and it covers the late lifecycle stages of a change: Stage 6 is the approval-labelling step, and Stage 7 is the auto-merge step.

- **Auto-merge invocation sequence:** what's the canonical sequence between Stage 6 approval and `gh pr merge --auto`? The sequence touches four things. It writes an activity-log row for audit, runs the git mechanics for a squash, sets the labels that act as the gating signal under G-0013, and invokes the merge mode. Stage 7 has multiple steps that must run in order. The open question was whether each repo re-implements that sequence or they all share one.
- **Auto-merge recovery cap:** how many recovery attempts are allowed before the auto-merge cycle declares defeat and routes to a fresh PR? The candidates were 3 and 5. Both fit the simplicity anchor. The remaining question was count semantics, meaning count-all (any reset counts, whatever triggered it) versus conditional counting. That was settled as count-all on the predictable-mental-model principle.

These two bundled together because the recovery cap is a property of the workspace merge template. The template is what increments the counter and what bails when the cap trips.

## Decision

A **workspace template script** lives at `<workspace-root>/bin/pr-create-with-automerge.sh` (or the equivalent path after the post-mnemra absorption). Each repo gets a copy through a `/spec` retrofit, where `/spec` is the workflow stage that produces the specification a change is built against. Per-repo customization (default branch, body template) lives in the repo's own copy.

Canonical sequence (post-Stage-6-approval, post-Stage-5-green, where Stage 5 is the review stage and "green" means it passed):

```bash
# 1. Durable approval audit (per G-0013)
<workspace-cli> activity log --actor <maintainer> \
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

The `<wt>` placeholder above is the worktree, a separate working tree off the main branch that's opened per code-modifying task so main stays stable.

**Recovery cap = 3, count-all semantics.** Any reset of the auto-merge cycle counts as one recovery attempt regardless of trigger. That includes a branch update, a commit amend, a force-push, a label re-application, or a manual `gh pr merge --auto` re-invocation. After 3 attempts the cycle bails: the PR is closed, and a fresh PR is opened with the corrected state.

The recovery counter lives per-PR in the PR description as a parseable footer:

```
<!-- recovery-attempts: <N> -->
```

The workspace template script reads-and-increments at every step-1 invocation that targets an existing open PR. It emits to stderr and aborts when N >= 3.

**Recovery counter integrity is accepted-risk (R-pending-1).** The PR description is editable by anyone with PR-edit permission, including through the GitHub web UI. The counter is convention, not enforcement. An actor who wants more than 3 attempts can edit the description to reset the counter. This is accepted as a workspace-private risk.

**Compensating control.** When the workspace template script detects an existing open PR at step 1, meaning a recovery cycle is in flight, it emits an additional `recovery-increment` activity row at the new counter value:

```
<workspace-cli> activity log --actor <operator-or-automation> \
  --action "stage7-recovery-attempt N=<count> for PR #<pr#>" \
  --task-id <chunk-task-id>
```

This produces a during-recovery audit trail. Suppose someone tampers with the counter, resetting `<!-- recovery-attempts: N -->` from 2 to 0. The recovery-increment activity rows still sit in the task DB at N=1 and N=2. The workspace-private audit log preserves the truth even when the GitHub-side substrate is mutated. A retrospective audit reconstruction joins the activity log's recovery-increment rows to the PR's final state to detect that tampering.

**Bypass acknowledgment.** An operator who invokes `gh pr merge --auto <pr#>` directly, outside the workspace template script, skips BOTH the step-1 audit row AND the counter increment. That's intentional. The script is the canonical recovery path; bare CLI invocations forfeit both the audit and the recovery-cap protection. Document this in the per-repo retrofit runbook.

There's a trip-wire to upgrade the substrate. The options are moving the counter to a label family `recovery:1/2/3` under G-0024 authorization, or moving it to a workflow-protected GitHub Actions variable. The trip-wire fires if 3 or more counter-bypass incidents are observed in any rolling 6-month window.

**R26b enforcement is delegated to G-0023 (GitHub Merge Queue).** Branch protection alone has no native single-merge-at-a-time gate. G-0023 adopts GitHub Merge Queue as the structural enforcement. The G-0018 template script is unchanged. `gh pr merge --rebase --auto <pr#>` works under a merge queue: `--auto` becomes "add to queue when checks pass," and the queue serializes the merges themselves.

**Cardinality and label-set authorization are delegated to G-0024.** G-0024 specifies the `verify-stage6-labeler` workflow and the `verify-stage6-labels` required-status-check. The template's step 4 is unchanged in shape. The gates around it are added by G-0024.

## Alternatives Considered

- **Per-repo bespoke merge scripts.** Rejected. Drift across repos defeats the workflow's predictability. A workspace template plus per-repo copies is the canon.
- **No template; document the sequence only.** Rejected. Manual execution invites step-skip mistakes: forgetting the audit, mis-labeling, or picking the wrong merge mode.
- **Recovery cap = 5.** Considered. A looser cap lets work proceed when recovery is small. Rejected for v1. A cap of 3 forces a step-back when recovery isn't converging, recovery PRs are cheap, and 5 invites trying-and-trying. Easy to relax later if 3 bites in practice.
- **Conditional counting** (for example, only counting "real" failures and not config-tweak resets). Rejected. It adds judgment-call branches to a mechanical counter and defeats predictability. count-all is the simpler invariant.
- **Counter in task DB `recovery_attempts` column.** Rejected. Same workspace-CLI-in-maintenance argument as G-0013 and G-0014. The PR description footer is the lean substrate.
- **Auto-merge in squash mode** instead of rebase. Rejected. Discovery, the earlier scoping pass, locked rebase mode for linear history. Squash is disabled at the repo settings level.

## Consequences

- **Per-repo retrofit:** copy the workspace script as `bin/pr-create-with-automerge.sh` (or the repo equivalent), tailor the body template, commit. The operations engineer is dispatched per repo as part of the merge-mode migration runbook.
- **Workspace template re-renders:** when this ADR or the template script changes, the `/spec` retrofit re-renders the per-repo copies.
- **Recovery cap trip is loud.** The script aborts to stderr with the PR ref and the attempt count, so the operator sees it immediately. No silent failure modes.
- **Recovery footer is parseable.** `grep -oP '(?<=recovery-attempts: )\d+'` extracts the counter. Future tooling can read it.
- **Step 1 audit row precedes step 4 PR creation.** Audit-before-PR ordering means a failed PR creation still leaves an audit trail of intent.
- **Stage 6 approval action ties to chunk task ID.** The `--task-id <chunk-task-id>` argument links the approval to the originating spec chunk. Future audit reconstruction joins the activity log to tasks.
- **Squash to single conv-commits commit (step 2)** is the linear-history mechanism. The PR body carries the detail, and the commit message is the single source of truth for release-plz CHANGELOG generation under G-0020.
- **Cross-repo:** all in-scope repos share the canonical sequence. Per-repo divergence is a bug, not a feature.
- **Template script language:** bash for v1, since it's zero-dependency and universal. Revisit later if the script grows past roughly 50 lines or needs richer error handling, at which point bash moves to a Rust binary.
- **Squash + signed-commit attribution.** Step 2's `git reset --soft` to merge-base loses GPG signatures from intra-branch commits when those are present. If a per-repo signing policy emerges later, the template's squash step will need a separate ADR to address signature handling. Acknowledged as known-future-work.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Compensating control widened:** the original control caught creation-time tamper only. **Fixed:** added `recovery-increment` activity row emission at step 1 when the script detects an existing PR (a recovery cycle). The during-recovery audit trail is now preserved in the task DB even when the PR-body footer is mutated.
- **Bypass-acknowledgment clarification:** operators who invoke `gh pr merge --auto` directly bypass the counter and the audit by design. Documented in the retrofit runbook and this ADR so the bypass is explicit.

### 2026-04-30 — Round 1 review amendments

- **Recovery counter integrity:** the PR-body footer is mutable, so the cap is convention and not enforcement. **Resolved as accepted risk** per maintainer triage. The compensating control is the step-1 audit row plus a GitHub event log cross-reference. The trip-wire is 3 bypass incidents in 6 months.
- **R26b mechanism:** **Resolved by cross-reference to G-0023** (GitHub Merge Queue). The template script is unchanged; the queue is the structural enforcement.
- **Label authorization + cardinality enforcement:** **Resolved by cross-reference to G-0024** (Stage 6 label-set authorization).
- **Bash threshold:** tightened the revisit threshold from 100 to 50 lines.
- **Squash signed-commit acknowledgment:** added a Consequence noting GPG signature loss under `reset --soft`.

Status remains **Proposed** pending r2 review.
