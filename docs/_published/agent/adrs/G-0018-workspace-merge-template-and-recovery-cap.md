---
title: "G-0018: Workspace Merge Template + Auto-Merge Recovery Cap"
summary: "Canonical Stage 6–7 sequence in a workspace template script; recovery cap = 3 (count-all); counter in PR description footer; audit via workspace activity log."
primary-audience: agent
---

# G-0018: Workspace Merge Template + Auto-Merge Recovery Cap

**Status:** Accepted
**Date:** 2026-04-30

## Context

Two adjacent decisions converged into one merge-flow contract:

- **Auto-merge invocation sequence:** what's the canonical sequence between Stage 6 approval and `gh pr merge --auto`? The sequence touches activity logging (audit), git mechanics (squash), label setting (gating signal per G-0013), and merge-mode invocation. Stage 7 has multiple steps that must run in order; the question was whether each repo re-implements the sequence or shares it.
- **Auto-merge recovery cap:** how many recovery attempts are allowed before the auto-merge cycle declares defeat and routes to a fresh PR? Candidates were 3 and 5; both are consistent with the simplicity anchor. Count semantics — count-all (any reset counts, regardless of trigger) vs conditional counting — was settled as count-all on the predictable-mental-model principle.

These bundled because the recovery cap is a property of the workspace merge template — the template is what increments the counter and what bails when the cap trips.

## Decision

**Workspace template script** at `workspace/bin/pr-create-with-automerge.sh` (or equivalent path post-mnemra-absorption). Per-repo copy via /spec retrofit; per-repo customization (default branch, body template) lives in the repo copy.

Canonical sequence (post-Stage-6-approval, post-Stage-5-green):

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

**Recovery cap = 3, count-all semantics.** Any reset of the auto-merge cycle — branch update, commit amend, force-push, label re-application, manual `gh pr merge --auto` re-invocation — counts as one recovery attempt regardless of trigger. After 3 attempts, the cycle bails; the PR is closed and a fresh PR is opened with the corrected state.

The recovery counter lives per-PR in the PR description as a parseable footer:

```
<!-- recovery-attempts: <N> -->
```

Workspace template script reads-and-increments at every step-1 invocation that targets an existing open PR; emits to stderr and aborts when N >= 3.

**Recovery counter integrity is accepted-risk (R-pending-1).** The PR description is editable by anyone with PR-edit permission, including via the GitHub web UI; the counter is convention, not enforcement. An actor wanting more than 3 attempts can edit the description to reset the counter. This is accepted as a workspace-private risk.

**Compensating control.** When the workspace template script detects an existing open PR at step 1 (i.e., a recovery cycle is in flight), it emits an additional `recovery-increment` activity row at the new counter value:

```
brain activity log --actor <operator-or-automation> \
  --action "stage7-recovery-attempt N=<count> for PR #<pr#>" \
  --task-id <chunk-task-id>
```

This produces a during-recovery audit trail. Counter-tampering (resetting `<!-- recovery-attempts: N -->` from 2 to 0) leaves the recovery-increment activity rows in the task DB at N=1 and N=2 — the workspace-private audit log preserves the truth even when the GitHub-side substrate is mutated. Retrospective audit reconstruction joins activity_log's recovery-increment rows to the PR's final state to detect tampering.

**Bypass acknowledgment.** Operators who invoke `gh pr merge --auto <pr#>` directly (outside the workspace template script) skip BOTH the step-1 audit row AND the counter increment. This is intentional — the script is the canonical recovery path; bare CLI invocations forfeit both audit and recovery-cap protection. Document this in the per-repo retrofit runbook.

Trip-wire to upgrade the substrate (move the counter to label family `recovery:1/2/3` under G-0024 authorization, or to a workflow-protected GitHub Actions variable): if 3 or more counter-bypass incidents observed in any rolling 6-month window.

**R26b enforcement is delegated to G-0023 (GitHub Merge Queue).** Branch protection alone has no native single-merge-at-a-time gate. G-0023 adopts GitHub Merge Queue as the structural enforcement. The G-0018 template script is unchanged: `gh pr merge --rebase --auto <pr#>` works under merge queue — `--auto` becomes "add to queue when checks pass," and the queue serializes the merges themselves.

**Cardinality and label-set authorization are delegated to G-0024.** G-0024 specifies the `verify-stage6-labeler` workflow and the `verify-stage6-labels` required-status-check. The template's step 4 is unchanged in shape; the gates around it are added by G-0024.

## Alternatives Considered

- **Per-repo bespoke merge scripts.** Rejected. Drift across repos defeats the workflow's predictability. Workspace template + per-repo copies is the canon.
- **No template; document the sequence only.** Rejected. Manual execution invites step-skip mistakes (forgetting the audit, mis-labeling, wrong merge mode).
- **Recovery cap = 5.** Considered. Looser cap; lets work proceed if recovery is small. Rejected for v1: 3 forces a step-back when recovery isn't converging, recovery PRs are cheap, and 5 invites trying-and-trying. Easy to relax later if 3 bites in practice.
- **Conditional counting** (e.g., only count "real" failures, not config-tweak resets). Rejected. Adds judgment-call branches to a mechanical counter; defeats predictability. count-all is the simpler invariant.
- **Counter in task DB `recovery_attempts` column.** Rejected. Same workspace-CLI-in-maintenance argument as G-0013/G-0014. PR description footer is the lean substrate.
- **Auto-merge in squash mode** instead of rebase. Rejected. Discovery locked rebase mode for linear history; squash is disabled at repo settings level.

## Consequences

- **Per-repo retrofit:** copy the workspace script as `bin/pr-create-with-automerge.sh` (or repo equivalent), tailor the body template, commit. Deployment specialist dispatch per repo as part of merge-mode migration runbook.
- **Workspace template re-renders:** when this ADR or the template script changes, /spec retrofit re-renders per-repo copies.
- **Recovery cap trip is loud.** Script aborts to stderr with the PR ref + attempt count; operator sees it immediately. No silent failure modes.
- **Recovery footer is parseable.** `grep -oP '(?<=recovery-attempts: )\d+'` extracts the counter; future tooling can read it.
- **Step 1 audit row precedes step 4 PR creation.** Audit-before-PR ordering means a failed PR creation still leaves an audit trail of intent.
- **Stage 6 approval action ties to chunk task ID.** The `--task-id <chunk-task-id>` argument links the approval to the originating spec chunk; future audit reconstruction joins activity_log to tasks.
- **Squash to single conv-commits commit (step 2)** is the linear-history mechanism. PR body carries detail; commit message is the single source of truth for release-plz CHANGELOG generation (G-0020).
- **Cross-repo:** all in-scope repos share the canonical sequence. Per-repo divergence is a bug, not a feature.
- **Template script language:** bash for v1 (zero-dep, universal). Future revisit if the script grows past ~50 lines or needs richer error handling — bash → Rust binary.
- **Squash + signed-commit attribution.** Step 2's `git reset --soft` to merge-base loses GPG signatures from intra-branch commits when present. If a per-repo signing policy emerges later, the template's squash step will need a separate ADR to address signature handling. Acknowledged as known-future-work.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Compensating control widened:** original control caught creation-time tamper only. **Fixed:** added `recovery-increment` activity row emission at step 1 when the script detects an existing PR (recovery cycle). During-recovery audit trail now preserved in the task DB even when PR-body footer is mutated.
- **Bypass-acknowledgment clarification:** operators who invoke `gh pr merge --auto` directly bypass counter + audit by design. Documented in retrofit runbook + this ADR so the bypass is explicit.

### 2026-04-30 — Round 1 review amendments

- **Recovery counter integrity:** PR-body footer is mutable; cap is convention not enforcement. **Resolved as accepted risk** per maintainer triage; compensating control = step-1 audit row + GitHub event log cross-reference. Trip-wire = 3 bypass incidents in 6mo.
- **R26b mechanism:** **Resolved by cross-reference to G-0023** (GitHub Merge Queue). Template script unchanged; queue is the structural enforcement.
- **Label authorization + cardinality enforcement:** **Resolved by cross-reference to G-0024** (Stage 6 label-set authorization).
- **Bash threshold:** tightened revisit threshold 100 → 50 lines.
- **Squash signed-commit acknowledgment:** added Consequence noting GPG signature loss under `reset --soft`.

Status remains **Proposed** pending r2 review.
