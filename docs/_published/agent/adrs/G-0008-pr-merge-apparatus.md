---
title: "G-0008: PR-Merge Apparatus — Merge Template, Recovery Cap, Tag-Race Serialization, Merge Queue"
summary: "The mechanics by which a PR safely lands on main: a shared merge-template script with a bounded recovery cap, per-job CI concurrency that serializes the release sub-flow without dropping runs, and the host's native merge queue for single-merge-at-a-time enforcement with intermediate-state CI. Consolidates three prior mechanism ADRs; the governance layered on top lives in G-0003."
primary-audience: agent
---

# G-0008: PR-Merge Apparatus — Merge Template, Recovery Cap, Tag-Race Serialization, Merge Queue

**Status:** Accepted
**Date:** 2026-04-30

> **Consolidated ADR.** This is the single decision for the mechanics by which a PR safely lands on `main`. It consolidates three prior ADRs that each owned one mechanism of the same pipeline — a merge template + auto-merge recovery cap, tag-race serialization, and a host merge queue for single-merge-at-a-time enforcement — into one coherent apparatus.
>
> **Scope split with merge governance.** This ADR owns the *mechanics* — template, recovery cap, tag-race concurrency, queue. The *governance* layered on top (the closed-enum approval-label vocabulary, label-set authorization, the autonomous merge loop) lives in [G-0003](G-0003-merge-governance.md). Where this ADR's mechanics reference an approval label, the label's vocabulary and cardinality are G-0003's; this ADR points there rather than restating the enum. G-0003 cites *this* ADR as "the unchanged mechanics the governance model rides on."

## Context and Problem Statement

A PR-to-`main` pipeline has three distinct mechanical surfaces that were originally specified as three separate ADRs and have now stabilized:

- **The merge template + recovery cap.** What is the canonical post-approval sequence (audit → squash → push → PR → auto-merge), and how many recovery attempts are allowed before the cycle bails to a fresh PR? Per-repo bespoke scripts drift; a shared template plus a bounded recovery counter is the contract.
- **Tag-race serialization.** Release sub-flows (especially deploy-as-release / Mode B) introduce a race between merge completion and a release run's tag push — two adjacent merges could each compute the same next tag or orphan commits between tags.
- **Single-merge-at-a-time enforcement.** "At most one PR may merge to `main` at a time." Host branch protection alone has no native single-merger gate (`required_linear_history` enforces rebase/squash, not serialization); the mechanism needed an explicit substrate.

These compose into one apparatus: the merge queue serializes merges and validates intermediate state; the template script drives the per-PR sequence and bounds recovery; CI concurrency serializes the release sub-flow that fires after merge.

## Decision Drivers

- **Predictability over per-repo cleverness** — one shared sequence; per-repo divergence is a bug, not a feature.
- **Loud failure, never silent** — recovery-cap trips, queue stalls, and dropped release runs must surface to an operator, not fail quietly.
- **Framework-native over bolt-on** — use the host's merge queue and CI `concurrency:` rather than external locks/mutexes for a problem the platform solves.
- **Linear history is locked** — rebase mode; squash disabled at repo level; no merge commits.
- **Auditable mechanics** — the merge sequence leaves an activity-log trail joinable to the originating task.

## Decision Outcome

The apparatus is three interlocking mechanisms. Each is described below at its final state.

### Layer 1 — Shared merge template + recovery cap

A **shared template script** (e.g., `bin/pr-create-with-automerge.sh`). Per-repo copy via a spec retrofit; per-repo customization (default branch, body template) lives in the repo copy. Per-repo bespoke merge scripts are rejected — drift across repos defeats the workflow's predictability.

Canonical sequence (post-approval, post-green):

```bash
# 1. Durable approval audit (the approval signal is governed by G-0003; actor: the maintainer)
activity-log --actor <maintainer> \
  --action "stage6-approved chunk #<ref> mode <X>" \
  --task-id <chunk-task-id>

# 2. Squash intra-branch commits to one conventional-commits commit
git -C <wt> reset --soft $(git -C <wt> merge-base HEAD main)
git -C <wt> commit -m "<conv-commits header>" \
  -m "<body with release-mode + flag-id + chunk-ref>"

# 3. Push squashed branch
git -C <wt> push origin <branch>

# 4. Create PR with the locked approval label set (vocabulary + cardinality per G-0003)
gh pr create --base main \
  --title "<conv-commits header>" --body "<body>" \
  --label "bump:<level>" \
  --label "release-mode-<X>" \
  --label "stage6-approved"

# 5. Enable auto-merge in rebase mode (adds to the merge queue when checks pass — see Layer 3)
gh pr merge --rebase --auto <pr#>
```

**Recovery cap = 3, count-all semantics.** Any reset of the auto-merge cycle — branch update, commit amend, force-push, label re-application, manual `gh pr merge --auto` re-invocation — counts as one recovery attempt regardless of trigger. After three attempts the cycle bails: the PR is closed and a fresh PR is opened with the corrected state. Count-all is the simplicity-anchor invariant; conditional counting (only "real" failures) was rejected because it adds judgment-call branches to a mechanical counter and defeats predictability.

The recovery counter lives per-PR in the PR description as a parseable footer:

```
<!-- recovery-attempts: <N> -->
```

The template script reads-and-increments at every step-1 invocation that targets an existing open PR; it emits to stderr and aborts when N ≥ 3. The footer is extractable for downstream tooling.

**Recovery-counter integrity is accepted-risk.** The PR description is editable by anyone with PR-edit permission (including via the host's web UI); the counter is convention, not enforcement. This is accepted as an internal-only risk.

**Compensating control.** When the template script detects an existing open PR at step 1 (a recovery cycle is in flight), it emits an additional `recovery-increment` activity row at the new counter value:

```
activity-log --actor <operator-or-automation> \
  --action "stage7-recovery-attempt N=<count> for PR #<pr#>" \
  --task-id <chunk-task-id>
```

This produces a during-recovery audit trail the creation-time audit row alone did not. Counter-tampering (resetting the footer from 2 to 0) leaves the recovery-increment rows in the task DB at N=1 and N=2 — the internal audit log preserves the truth even when the host-side substrate is mutated. Retrospective audit reconstruction joins the recovery-increment rows to the PR's final state to detect tampering.

**Bypass acknowledgment.** Operators who invoke `gh pr merge --auto <pr#>` directly (outside the template script) skip BOTH the step-1 audit row AND the counter increment. This is intentional — the script is the canonical recovery path; bare CLI invocations forfeit both audit and recovery-cap protection. The per-repo retrofit runbook documents this so operators know "I'll just re-add to the queue myself" loses safety properties.

**Trip-wire to upgrade the counter substrate** (move it to a label family under G-0003's label-set authorization, or to a workflow-protected CI variable): if three or more counter-bypass incidents are observed in any rolling six-month window. Until the trip-wire fires, the audit row + recovery-increment rows + host event log together provide after-the-fact reconstruction.

**Squash + signed-commit attribution.** Step 2's `git reset --soft` to merge-base loses commit signatures from intra-branch commits when present. There is no signing policy locked today; if a per-repo signing policy emerges later, the squash step needs a separate ADR to address signature handling. Acknowledged as known-future-work, not an active risk.

**Template script language:** bash for v1 (zero-dep, universal). Revisit threshold: if the script grows past roughly 50 lines or needs richer error handling, migrate bash → a Rust binary in a shared `bin/` (or a future `workflow merge` subcommand).

### Layer 2 — Tag-race serialization

**The per-repo release sub-flow uses a CI `concurrency:` directive scoped to the `release-pr` job (Mode A), NOT the release job, with `cancel-in-progress: false`.** Combined with single-merge-at-a-time enforcement (Layer 3), this provides two-layer serialization: the merge queue at the merge gate, CI concurrency at the release-PR-update path.

Per-repo workflow pattern (Mode A — release-PR mode):

```yaml
name: Release
on:
  push:
    branches: [main]

# NO workflow-level concurrency. Concurrency is scoped per-job below.

jobs:
  release-pr:
    # "open/update release-PR" invocation per G-0009.
    # Concurrency on this job: serialise release-PR updates so feature-PR
    # merges don't race release-PR updates against the eventual release-PR merge.
    concurrency:
      group: release-pr-${{ github.repository }}
      cancel-in-progress: false
    # ... release-tool invocation (Mode A)

  release:
    # "tag + publish on release-PR merge" invocation per G-0009.
    # NO concurrency block here — see note below. The release tool's upstream
    # quickstart explicitly advises against concurrency on the release job
    # because CI concurrency cancels the *pending* run when a third trigger
    # arrives, which under rapid Mode B merges drops releases on the floor.
    needs: release-pr
    # ... release-tool invocation (release/publish step)
```

**Why concurrency lives only on `release-pr`.** The release tool's quickstart advises against concurrency on the release job: the host's concurrency semantic is "one running + one pending; a third arrival cancels the pending one." Three rapid Mode B merges would cause the middle run to be cancelled, NOT queued — the opposite of "queue, don't cancel." The release-PR-update path is where concurrency genuinely helps: feature-PR merges trigger the release tool to update an open release-PR, and serialising those updates prevents racey CHANGELOG state. The release job itself runs after the merge has already been serialised by the merge queue (Layer 3), so it inherits serialisation upstream and does not need its own.

The `cancel-in-progress: false` on the release-pr job is mandatory: a release-PR update writing CHANGELOG / Cargo.toml MUST NOT be cancelled mid-flight by a newer trigger; the newer trigger queues until the in-flight update completes.

**Mode B (deploy-as-release): serialization comes from the merge queue (Layer 3), with a known rapid-merge limitation.** Mode B repos have no release-PR; the release fires on each `main` push. The merge queue serialises the merges themselves, but does NOT space out the resulting `push: main` events, and adding `concurrency:` to the release job introduces the cancellation pathology above.

A verification spike confirmed against primary host-CI and merge-queue documentation that:

- Host-CI docs, verbatim: *"Any existing pending job or workflow in the same concurrency group, if it exists, will be canceled and the new queued job or workflow will take its place."* `cancel-in-progress: false` does NOT change this — it only protects the running slot.
- The merge queue admits PRs FIFO but does not space the resulting `push: main` events; three rapid Mode B merges produce three rapid release triggers in close succession.
- Under those conditions, `concurrency:` on the release job would still drop the middle run (cancellation of pending), the exact pathology the release tool's quickstart warns about. Merge-queue-fed triggers do not change this.

**v1 posture: accept as a known limitation + fail-loud monitoring.** No `concurrency:` block on the release job. Operators monitor for missing release runs:

- **Per-release expected-tag check:** after each merge expected to bump the version, verify the expected tag ref landed. Missing tag → investigate workflow history.
- **Release workflow-history audit:** list workflow runs periodically; a count of expected-vs-actual runs flags drops.
- Documented in the per-repo retrofit runbook.

**v2 hardening path (deferred).** Merge-queue batching with a squash merge method and queue limits ≥ 2 collapses N successive PRs into one merge group / one `push: main` event / one release run, eliminating the race structurally. Adoption requires a separate spike on the release tool's multi-version-bump-per-push tolerance (it expects one bump per push by default). **Trip-wire to v2:** any rapid-merge race incident observed in production, OR Mode B repo volume increases such that the race becomes likely.

For Mode A, the release-pr-job concurrency above remains the correct mechanism — Mode A's "release event = release-PR merge" is itself a single-PR-at-a-time event under the merge queue, which composes cleanly with concurrency on the release-pr job.

**Workflow permissions stanza.** The release workflow declares minimum required permissions explicitly: `permissions: { contents: write, id-token: write, packages: write }` (`contents: write` for tag push + release notes; `id-token: write` for OIDC provenance / registry auth; `packages: write` for any package publish). No workflow-level `permissions: write-all`.

**Manual-cancel escape hatch.** When a hung release run blocks the queue (e.g., a publish step times out on registry slowness), operators may cancel via the host-CI UI or a run-cancel command. The per-repo retrofit runbook documents the manual-cancel path; "let in-flight finish" is the locked steady-state behavior, not a guarantee against operational hangs. Alternative trigger paths (manual dispatch, scheduled releases) for the release-pr job MUST share the same concurrency group regardless of trigger source.

**Cross-namespace concurrency edge (acknowledged limitation, no fix).** The group name includes the repo owner; if a repo is transferred or renamed, in-flight queued runs reference the old repository value while new runs reference the new. Very low probability for current state; worth noting for any future repo transfer. **Trip-wire:** if two crates ever share a release cadence via a cross-crate dependency, a top-level concurrency group becomes necessary — surfaced so a future operator does not re-derive the conclusion.

### Layer 3 — The host merge queue for single-merge enforcement + intermediate-state CI

The host's merge queue is the framework-native answer to single-merge-at-a-time: structural single-merge semantics, intermediate-state CI validation, and an admin-configured merge method per repo.

**1. The merge queue is enabled per in-scope repo as the enforcement mechanism.** The branch-protection setting "Require merge queue" on the default branch (`main`) makes queueing structural — direct merges without queue passage are rejected. Under the queue, `gh pr merge --rebase --auto` (Layer 1's step 5) becomes "add to queue when required checks pass" rather than "merge immediately." No template-script change is required: the queue is configured at branch-protection level, not at the merge-command level.

**2. Required checks run against the queue's intermediate-state branch.** When a PR is queued, the host creates a temporary branch (`main` + earlier queued PRs + this PR) and runs required checks against it. Required checks split into two categories:

| Category | Recipes (per G-0002 vocabulary) | Triggers needed |
|----------|-------------------------------|-----------------|
| Required against intermediate state | `verify-test`, `verify-build`, `verify-coverage` | `pull_request` AND `merge_group` |
| Branch-only (not required against intermediate state) | `verify-lint`, `verify-type`, `verify-secrets` | `pull_request` (sufficient) |

Rationale: integration-sensitive checks (tests, build, coverage) need to validate the merged state, because conflicts and integration failures only appear there. Static checks (lint, type, secret scan) are determined by the PR's own diff and are not affected by other queued PRs landing first.

The approval-label cardinality check defined by [G-0003](G-0003-merge-governance.md)'s label-set authorization is part of the intermediate-state required set: the queue evicts a PR whose label cardinality drifted between auto-merge enablement and queue head. The label vocabulary and cardinality rules themselves are G-0003's; this layer only records that the check participates in queue eviction.

**3. Maximum queue depth defaults to the host's repo-level setting.** Volume is low (a single sequencer in v1; in-flight PR count bounded by a circuit-breaker at ≤3 active worktrees). The default is sufficient. Trip-wire: if the queue regularly hits the configured cap, raise the limit and revisit the worktree bound — but the more likely cause is upstream throughput, not queue depth.

**4. Admin queue bypass requires audit (accepted-risk).** The host permits admin override (an admin can merge directly, bypassing the queue) at the branch-protection level; this cannot be cleanly disabled without breaking emergency response. For v1, admin bypass requires an activity-log entry justifying the deviation, with an action string naming the repo, PR, and reason. The audit row is self-attested; the compensating control is the host's own audit log, which records the bypass at the platform level (cryptographically attributed), so retrieval-time cross-reference detects forged or missing internal audit rows.

**5. Trigger model under the merge queue.** Queued PRs trigger `merge_group` workflow events, not `pull_request` events. Required-status-check workflows that must run against intermediate state MUST listen for `merge_group`:

```yaml
on:
  pull_request:
  merge_group:
```

Workflows triggered only by `pull_request` will not fire for queued PRs and will never report required-check status against the intermediate state. Updating workflow triggers is the most concrete retrofit work and the most likely failure mode if missed.

**Silent queue-stall detection.** If a required-status-check workflow is missing the `merge_group:` trigger, queued PRs sit indefinitely waiting for a check that never reports — the queue does not time out on its own. Two detection mechanisms guard against this:

1. **Per-repo retrofit verification.** As part of the merge-mode migration runbook, after enabling the merge queue and adding required checks, the operator opens a test PR, adds it to the queue, and verifies it merges within expected latency (minutes for normal CI). A stuck queue → a required check is missing its trigger.
2. **Stuck-queue alert.** A periodic query for PRs sitting in the queue beyond N minutes (recommend 30) fires an alert on stuck PRs. The per-repo spec configures the threshold.

**6. The `--rebase` flag is advisory under the queue.** The queue's branch-protection-configured merge method governs the actual merge mechanic. To preserve linear history (rebase mode locked), per-repo retrofit MUST set the queue's merge method to **rebase** in branch protection. If the queue's method is set differently, the `--rebase` flag silently no-ops and linear history is broken.

**7. Failure semantics tie to the recovery cap (Layer 1).** When intermediate-state CI fails for a queued PR, the host evicts the PR from the queue and resets the auto-merge enablement. The operator MUST re-invoke the full template script — not bare `gh pr merge --auto <pr#>`. The script's step 1 detects the existing open PR, emits a `recovery-increment` activity row, and increments the recovery footer; step 5 re-enables auto-merge, re-adding the PR to the queue. After three evictions (count-all), the script aborts and routes to a fresh PR. Queue-eviction → template-re-invocation → counter increment is the integration path; deviation (bare CLI re-invocation) forfeits the protection.

**8. Per-repo opt-in / opt-out.** All in-scope repos (those that declare they follow the code workflow) enable the merge queue as part of the workflow retrofit. Local-only repos not yet migrated to a host are not subject to this layer until migration. Reference-only repos (explicitly excluded) remain unaffected.

## Alternatives Considered

- **Per-repo bespoke merge scripts** (Layer 1). Rejected — drift across repos defeats predictability. A shared template plus per-repo copies (re-rendered on spec retrofit) is the canon.
- **No template; document the sequence in the repo's agent-instructions file** (Layer 1). Rejected — manual execution invites step-skip mistakes (forgetting the audit, mis-labeling, wrong merge mode).
- **Recovery cap = 5** (Layer 1). Considered; a looser cap lets work proceed when recovery is small. Rejected for v1: 3 forces a step-back when recovery is not converging, recovery PRs are cheap, and 5 invites trying-and-trying. Easy to relax later if 3 bites.
- **Conditional counting** (Layer 1). Rejected — it adds judgment-call branches to a mechanical counter; count-all is the simpler invariant.
- **A task-DB counter column** (Layer 1). Rejected — the same lean-substrate argument as the review-finding-identity ADR ([G-0004](G-0004-review-finding-identity-and-persistence.md)); the PR-description footer is the lean substrate.
- **A release-tool lock / tool-level mutex** (Layer 2). Rejected — the release tool provides no native lock; bolting one on is custom work outside the tool's surface. CI concurrency is the framework-native answer.
- **`cancel-in-progress: true`** (Layer 2). Rejected — cancelling an in-flight release at tag-push time produces partial state (tag pushed, release notes not generated, or vice versa). The serialization point is "let the in-flight run finish, queue the next one."
- **External queue / mutex** (Layers 2 & 3: a Redis lock, etcd, a CI-based mutex, a Bors-style bot). Rejected — it adds infrastructure for a problem the host solves natively. The merge queue's intermediate-state CI validation is non-trivial to replicate; Bors predates merge queues and is largely superseded by them.
- **`required_linear_history: true` alone** (Layer 3). Rejected — it forces rebase/squash but does not serialize merges; two PRs can rebase to non-conflicting linear ancestors and both land in close succession. Single-merge-at-a-time is a stricter constraint.
- **Auto-merge with required CI but no queue** (the Layer 1-only status quo). Rejected — without an explicit serializer, two PRs passing checks simultaneously both attempt to merge; the second's rebase fails and the dev re-rebases. "Rebase-failure as implicit serializer" is slow under volume, silent when it serializes, and fragile when CI flakes interact with rebase races. The queue replaces silent failure with explicit queueing.
- **Merge commits with a linear-history exception** (Layer 3). Rejected — rebase mode is locked.

## Consequences

- **Per-repo retrofit (one-time, per spec migration):**
  - Copy the template script as `bin/pr-create-with-automerge.sh` (or repo equivalent); tailor the body template; commit.
  - Branch protection: enable "Require merge queue" on the default branch; set the queue merge method to **rebase**; configure the intermediate-state required-status-checks list. Validate the change against the live branch-protection settings after applying it.
  - Workflow config: add the `release-pr`-job `concurrency:` block (Layer 2); add `merge_group:` to triggers on every workflow producing an intermediate-state required check (Layer 3). Branch-only checks remain `pull_request`-triggered.
  - Verify via a PR walk-through: open a PR, observe the `merge_group` workflow run after auto-merge enables queueing, and confirm it merges within expected latency.
- **Two-layer serialization across the workflow:** the merge queue serializes PR-to-`main` merges with intermediate-state CI; CI `concurrency:` on the release-pr job serializes release-PR creation/update across rapid `main` pushes. The layers are independent and compose — the queue holds even if `concurrency:` is misconfigured downstream, and vice versa.
- **Recovery-cap trip is loud.** The script aborts to stderr with the PR ref and attempt count; the operator sees it immediately. No silent failure modes.
- **Squash to a single conventional-commits commit (step 2)** is the linear-history mechanism. The PR body carries detail; the commit message is the single source of truth for CHANGELOG generation (see [G-0009](G-0009-rust-release-apparatus.md)).
- **Branch-only check redundancy.** A branch-only check fixed after queueing (e.g., a lint failure noticed post-queue) does not block the queue head — the queue only watches the intermediate-state required checks. The PR stays in queue; the lint fix lands as a follow-up. A deliberate trade for queueing throughput.
- **Queueing latency:** end-to-end PR-to-merged latency is `(queue position) × (intermediate-state CI duration) + (merge time)`. For low volume (≤3 in-flight PRs, a single sequencer), worst-case is bounded at roughly 3× the CI cycle. Acceptable. Under serial release-pr-update flows, two near-simultaneous feature-PR merges produce two queued release-pr-job runs; the second starts after the first completes. Acceptable.
- **The embargo flow ([G-0010](G-0010-embargo-flow-architecture.md)) interacts cleanly.** Queued PRs respect existing release sub-flow concurrency; embargo coordination is human-driven per G-0010 and the queue does not change that model.
- **Per-repo scope** of the concurrency group means cross-repo releases run in parallel — the goal is to serialize within a repo, not across all repos. Cross-repo coordination, if ever needed, is a separate concern.
- **Cross-repo merge serialization is out of scope** — the queue is per-repo by host design.
- **Host-portability:** queue configuration is host-native (branch-protection settings + `merge_group` triggers) and survives tooling consolidation unchanged. If a non-host forge is ever introduced, this ADR needs a forge-specific successor; for the current host-hosted lifetime it is stable. The concurrency-group naming may shift if the repo identity model changes.
- **In-flight verification items** (verify before per-repo retrofit): the exact settings shape for "Require merge queue" + the queue merge method (validate against a non-production repo first); the exact auto-merge interaction under the queue (a test PR); the default queue depth + merge-limits for the account's host plan tier.

## More Information

- **Consolidation provenance:** folded from the final-state mechanics of three prior mechanism ADRs — a merge template + recovery cap, tag-race serialization, and the merge queue. The sources' round-by-round review history remains in version control; only the final-state mechanics are carried here.
- **Governance rides on this apparatus:** the merge-governance model ([G-0003](G-0003-merge-governance.md)) cites this ADR as the unchanged mechanics it rides on, and owns everything about *who approves and how the approval signal is verified* — the closed-enum label vocabulary, label-set authorization, and the autonomous merge loop.
