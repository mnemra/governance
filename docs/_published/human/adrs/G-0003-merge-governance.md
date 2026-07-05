---
title: "G-0003: Merge Governance — Shift-Left Review on the Governing Artifact, Verified at Merge; the Orchestrator Lands Every PR"
summary: "Review belongs on the governing artifact (spec / plan / ADR), shift-left, where substance is decided. The merge pipeline verifies a durable review-marker rather than re-reviewing the PR; the orchestrator performs the mechanical push + PR + merge for every PR. A single conditional gate fires only when the marker is absent, stale, or the PR deviates. Consolidates the approval-label vocabulary, label-set authorization, and the autonomous merge loop."
primary-audience: agent
---

# G-0003: Merge Governance — Shift-Left Review on the Governing Artifact, Verified at Merge; the Orchestrator Lands Every PR

**Status:** Accepted
**Date:** 2026-06-22

> **Consolidated ADR.** This is the single merge-governance decision. It consolidates what was previously a chain of separate ADRs (an approval-label vocabulary, label-set authorization, a post-plan-approval autonomous loop, and a "merge-is-mechanics" statement) by promoting the self-contained model and folding in the operative mechanics of the earlier layers.

- **Rides on, does not restate:** the **PR-merge apparatus** ([G-0008](G-0008-pr-merge-apparatus.md): merge template, recovery cap, tag-race serialization, merge queue) and the **Rust release apparatus** ([G-0009](G-0009-rust-release-apparatus.md)). These are the unchanged mechanics this governance model rides on.
- **Builds on** the agent-first workflow ([G-0013](G-0013-agent-first-workflow-shape.md)). The brief workflow's spec-exit gate is where a spec's review-marker is stamped.
- **Reconciles** the durability-tier rule (`P-CompositionBridge`, the principle governing composition across durability tiers): a verified-met acceptance-criterion (AC) flip is mechanics (a free orchestrator edit); changing an AC's *claim* is substance (routes to the maintainer's review surface).

## Context and Problem Statement

Merge authority had drifted to gating on the maintainer **re-reviewing the PR**, at the point where the PR is pure mechanics. The trigger was a three-file documentation-deletion PR executing an already-locked decision, routed to the maintainer for merge. Nothing in that diff needed his eyes; the substance was his decision, made when he locked the governing artifact. The merge was mechanical execution of an approved decision, yet it waited on a human merge action.

This exposed a conflation between **reviewing substance** and **landing mechanics**, sitting on an unreconciled trajectory the chain had built up layer by layer:

- **Label vocabulary + authorization:** Stage 6 (the approval-labelling step) = the maintainer approves *each PR* by applying closed-enum labels; Stage 7 (auto-merge) merges on those labels. Approval happened *at the PR*.
- **Autonomous loop:** for *plan-tasks under an in-force plan*, the approval signal **shifted upstream**, from per-PR labeling to plan-ratification; automation applies the label after the gate stack passes; the orchestrator merges (review-by-exception). Off-plan work still required per-PR maintainer labeling.

The maintainer's framing closes the gap: **the PR + merge is mechanics by definition; the only review question is whether the *substance* was already reviewed, and that is decided upstream, at the artifact, not at PR time.** This ADR generalizes the autonomous-loop move from plan-tasks to every PR.

## Decision Drivers

- **Review belongs where substance is decided**, the spec / plan / ADR, not at PR mechanics.
- **The maintainer must not be a per-PR bottleneck** for changes whose substance he already approved.
- **The approval signal must be verifiable**: a durable marker, not an assumption that "it was probably reviewed."
- **Reversibility sets the gate timing.** A public push of sensitive code is irreversible → review precedes the push. A merge of revertable work is not → announce-and-land, with a hold lever.
- **One coherent rule**, not a fourth thin diff against three prior ADRs.

## Considered Options

1. **Status-quo split.** Plan-tasks autonomous; everything else per-PR maintainer labeling.
2. **The orchestrator lands every PR; review is shift-left on the governing artifact, verified by a marker at merge.**
3. **Retire human approval entirely.** A CI-only merge gate.

## Decision Outcome

**Chosen: Option 2.**

**The rule.** The **governing artifact** (spec / plan / ADR / decision) carries the maintainer's review. The merge pipeline **verifies that marker; it does not re-review.** The orchestrator performs the mechanical **push + PR + merge** for every PR.

**The pipeline** (one flow, the orchestrator drives it, a single conditional gate):

```
create branch → squash → [ governing-artifact review-marker present + PR conforms? ] → create PR → merge (CI validates as it lands)
                              │
                  no/stale/deviation/security → gate fires → maintainer reviews the ARTIFACT or DEVIATION (never the PR mechanics)
                  yes ────────────────────────────────────────────────────────────────→ orchestrator merges
```

- **Gate skips** (mechanics → the orchestrator merges): the governing artifact carries the maintainer's review-marker, the PR conforms to it, and CI is green. It also skips for changes with no governing artifact that are themselves mechanical (docs, bookkeeping, generated code, sub-threshold fixes).
- **Gate fires** (the maintainer reviews): the marker is **absent or stale**, or the PR **deviates** from the artifact (a novel decision, or scope beyond it). What the maintainer reviews is the **artifact or the deviation, never the PR mechanics.** *(Security surfaces no longer fire the gate routinely; the pre-push security review carries it, see Amendment.)*
- **Timing by reversibility:** the pre-push review of a security-sensitive diff is mandatory, before the push reaches any remote (exposure is irreversible); findings are fixed in-loop, and only a finding the loop **can't resolve** (or a deliberate **won't-fix**) escalates to the maintainer pre-push (stop-condition 6). Every other gate firing is pre-merge.
- **Announce-no-hold:** every PR is announced before it merges; a hold instruction opts a PR into the maintainer's review after announcement. This is the safety net that makes "the orchestrator always merges" safe: the window to catch substance that leaked into a PR its artifact did not cover.

**The review-marker.** Where it lives depends on the carrier:

| Carrier | Marker home | Fields |
|---|---|---|
| **Spec** | frontmatter (document-status convention) | `status` (e.g. `approved`) · `reviewed_by` · `reviewed_date` |
| **Spec — git provenance** | the bill-of-materials (`.bom.toml`) sidecar's audit chain | the approved-state commit, stamped **post-commit** by tooling |
| **Plan** | plan-ratification | per the autonomous-loop gate stack below |
| **Decision** | the accepted ADR itself | status `accepted` + decision-maker |

The commit SHA is **not** in frontmatter (hash-circularity: a file cannot carry the hash of the commit that contains it). Git provenance lives in the sidecar audit chain (stamped after the commit exists), which is also what lets the merge tooling detect a **stale marker**: if the spec's substantive content changed since the approved-state commit, the marker is no longer valid and the gate re-fires.

### Incorporated layer — closed-enum label vocabulary

The Stage-6 approval signal is carried by **closed-enum PR labels** across three families: approval, release-mode, version-bump (`bump:major|minor|patch|none`). Cardinality is enforced **ABORT-on-violation** (exactly one label per family where the family is required); violations halt the merge queue rather than guessing. Label application is audited in the activity log. A separate "staged" merge mode no longer exists; it is simply "the gate fired" (a pre-PR/pre-push review of the squashed diff); a plain merge is "the gate skipped." The classification, not a mode flag, decides.

**The closed-enum label table.** Three families, each a fixed value set:

| Family | Values | Cardinality |
|--------|--------|-------------|
| Approval | `stage6-approved` | 0 or 1 |
| Release mode | `release-mode-A`, `release-mode-B`, `release-mode-A-exception` | exactly 1 (when `stage6-approved` present) |
| Version bump | `bump:patch`, `bump:minor`, `bump:major`, `bump:none` | exactly 1 (when `stage6-approved` present) |

`bump:none` is for docs-only / internal-only / CHANGELOG-edit-only merges where no version change applies (honor-system plus Stage-4 reviewer responsibility per [G-0009](G-0009-rust-release-apparatus.md); no tool-side path-coverage gate).

**Cardinality-failure mode = ABORT, never "last label wins."** When the cardinality check sees zero or two-plus labels in a required-cardinality family, the gate fails loud with a message identifying the conflicting labels and the rule violated; the PR's check status reads "failure" until the labels are corrected. The gate never silently disambiguates. That would let an actor with label-write permission append `bump:none` after an approved `bump:patch` to suppress a version bump on a security-relevant change. The cardinality check runs at every relevant moment (PR open, label change, merge-queue entry per [G-0008](G-0008-pr-merge-apparatus.md), and merge attempt) so post-creation drift cannot escape the gate. No free-form labels are honored in the gating logic; teams may add other labels for tracking, but they have no semantic effect on the gate.

### Incorporated layer — label-set authorization

Three enforcement layers sit under the label signal: **Layer A**, label-set permission (a ruleset or a labeler-allowlist check controls *who/what* may apply the approval labels); **Layer B**, a required-status-check (the labels are a merge-blocking check); **Layer C**, audit cross-reference (the applied labels reconcile against the activity log). Under this consolidated model, Layer A authorization **derives from the governing-artifact review-marker** (automation applies the approval label after verifying the marker); Layer B cardinality is unchanged.

**Layer A: restrict label-set permission.** For each in-scope repo, a repository ruleset (or, where the platform tier does not expose label rules, a labeler-verification workflow on label add/remove) restricts who may apply or remove the gating-family labels:

| Label family | Permitted actors |
|---|---|
| `stage6-approved` (presence) | the maintainer (single-actor allowlist; a multi-collaborator future state uses an explicit approver allowlist) |
| `release-mode-*` | the maintainer; automation accounts MAY apply during the merge-template invocation, never independently |
| `bump:*` | the maintainer; automation accounts MAY apply during the merge-template invocation |

Under the consolidated model, Layer A authorization **derives from the governing-artifact review-marker**: automation applies the `stage6-approved` label after verifying the marker (the merge gate above), rather than the maintainer applying it per-PR. The allowlist still bounds *who/what* may apply the label; the marker is *when* it is authorized.

**Layer B: a required-status-check tying cardinality to branch protection.** Branch protection on `main` includes a required status check that validates exactly-one-of in each required family. **Both** the labeler-authorization check (Layer A) AND the cardinality check (Layer B) sit in the required-status-check set. Listing Layer A as a required check is what makes it **preventive**, not merely detective (a spoofed-labeler PR with valid cardinality would otherwise still merge). With both required, the host's merge-UI button respects the same gate as the merge template. **Fail-closed under CI out-of-quota:** a missing required check reads as "blocked," so quota exhaustion blocks merges rather than letting them slip. The cardinality-failure mode is ABORT-fail-loud across all families (same rule as the vocabulary section above).

**Layer C: audit cross-reference at retrieval time.** The activity-log approval row carries the actor as self-attestation (which cannot, on its own, survive a token compromise). Mitigation: the audit action string captures all three gating-label values; audit reconstruction queries both the activity log and the host's event log (cryptographically attributed) and cross-checks the actor across all three label families. A mismatch flags inconsistency, catching a forged audit row whose host-side labeler differs. Query the event log only after the merge time plus a small margin (eventual-consistency hygiene), and only as a human-initiated retrieval, never a hot path.

> **Scoping note.** The per-repo implementation workflows (label-authorization and label-cardinality checks) are retrofit detail. They live with each repo's CI, not in this governance ADR. This section captures the locked mechanism and rules. Two recorded risks carry forward: allowlist-by-name token compromise (mitigated by fine-grained scoped tokens, 90-day rotation, and app tokens where feasible) and external-PR contributors (out of scope for single-maintainer repos; amend with a fork-PR policy if forks enter scope).

### Incorporated layer — autonomous merge loop: gate stack + stop conditions

For a work item under an **in-force plan** (a locked and verified spec AND a maintainer-approved plan, standing policy for any repo with an in-force plan), the plan-task pipeline (branch push → PR open → rebase-and-merge once the gate stack is green) is pre-approved as one workflow. Discipline: **announce-no-hold** (every PR announced before merging; a hold instruction opts it into review); a **push gate** (a new PR pushes only after the previous PR merged and main built green, with the branch rebased onto that main); **one PR in flight**; and a **verify-signal guard** (a degraded or false-negative verify signal blocks autonomous merge rather than merging on an unreliable green). Force-push, direct-push-to-main, releases/tags/deploys, and PR comments/closes/reopens remain separately gated.

**Per-merge gate stack: ALL green before an autonomous merge:**

1. **Dispatch-verify:** scope clean (no scope violation), declared verify recipes green. *(When the hook-recorded row from the multi-agent fleet is unreliable, this gate is established by independent verification: the orchestrator runs the declared verify recipe (`just ci`) in the task worktree and reads the exit directly, and diffs the worktree against the dispatch envelope's `touch_scope` / `forbid_scope`. If the orchestrator cannot independently establish both, the merge is a stop, never an auto-merge on an unverified green.)*
2. **Plan-mandated review gates** at their sequence points: code+security review and operational review dispatches run where the plan places them; routine findings are fixed under the quality-gate carve-out (up to three rounds); test-integrity re-review passes where the plan mandates red/green pairing.
3. **CI green** on the PR: remediation commits go on the branch; never merge on pending or red.
4. **Dependencies:** permissively-licensed only (MIT/Apache/BSD/ISC auto-proceed).
5. **Completion report:** `success`, or `done_with_concerns` whose concerns the dispatcher can close under the runtime-verify-gap rule; any concern that survives closure attempts is a stop.
6. **Main is green.** The previous merge's own main-branch build completed green before the next PR merges (a PR passing CI does not imply main is green); a red main freezes the merge line for **all** PRs until restored.

**Stop conditions: escalate to the maintainer even under trust-then-retro** (trust-then-retro is the pattern where the maintainer sets direction, the team executes, and the batch is reviewed afterward; these compose with [G-0013](G-0013-agent-first-workflow-shape.md)'s pause-and-escalate triggers, principle conflict, intent ambiguity, novel decision, substrate pivot, restated for the execution phase):

1. **Spec gap surfaced mid-implementation.** Returns to the spec author/maintainer; never patched in plan or code by inference.
2. **Architectural deviation from plan or spec.** A library swap beyond a mechanical permissive-license addition, a change to an interface/layout/naming the spec fixed, or a design deviation a completion report enumerates.
3. **Test-integrity signal.** Test deletion, suppression, or assertion relaxation (a stuck-detector trip); never re-dispatch past this without maintainer review.
4. **Iteration cap hit.** Iterate-to-zero (the fix-and-review loop that runs until no blocking finding remains) or revision caps; the cap is a design-signal, not a budget to exhaust.
5. **A restrictively-licensed dependency.** A license-tier escalation.
6. **Unresolved security finding.** A Critical/High security finding the quality-gate fix loop cannot resolve (or a deliberate won't-fix) blocks merge pending maintainer disposition; routine Critical/High findings are fixed in-loop like any other finding (see Amendment).
7. **Scope violation at finalize.** A dispatch finalized with a scope violation does not merge.
8. **Plan-structure change.** Re-sequencing, task split/merge, or a new task; plan amendments loop back through the maintainer like spec amendments.
9. **Anything beyond the merge.** Releases, tags, deploys, force-push, direct-push-to-main, closes/re-opens of others' PRs, external announcements: all remain separately maintainer-gated. The autonomous loop adds no action class beyond the merge itself; the merge it performs is governed by the merge gate above.
10. **Novel decision.** Any judgment call without precedent in spec, plan, ADRs, or the skills canon.

Every autonomous merge is logged (an activity row plus dispatch events carry the gate evidence: verify results, review outcomes, PR link); mid-run judgment calls go to a live decisions log per the strong-autonomy discipline. The retro half of trust-then-retro: at each plan-named review gate the maintainer receives the batch of autonomously merged PRs since the last gate (links, deviations enumerated, gate evidence). Trust without the retro is not this model.

**Unchanged, still separately gated:** force-push, direct-push-to-main, releases / tags / deploys, PR comments / closes / reopens, and non-code external publishing (blog, social, registries). This ADR generalizes the **PR pipeline** only.

### Consequences

**Good:** the maintainer reviews substance **once**, at the artifact, shift-left; mechanical PRs land without a per-PR gate; the approval signal is **verifiable** (marker present + conformance), not assumed; one coherent rule replaces per-PR-vs-plan-task bucketing and a multi-ADR read.

**Bad / trade-offs:** it requires the marker mechanism end-to-end (spec-template frontmatter fields, a spec-exit stamp, a provenance stamp, a verify-marker-and-conformance merge step). Until those land, the gate falls back to maintainer judgment; it removes the old off-plan per-PR-labeling fallback (an off-plan change with no reviewed artifact and non-mechanical substance fires the gate, the intended forcing function toward shift-left review).

## Pros and Cons of the Options

- **Option 1 (status-quo split).** Pro: no change; the autonomous loop already works for plan-tasks. Con: it leaves the conflation that routed a mechanical PR to a human merge; two rules where one suffices; the off-plan path re-reviews mechanics.
- **Option 2 (chosen).** Pro: review where substance is; no per-PR bottleneck; a verifiable signal; one rule; it completes the label-vocabulary → autonomous-loop trajectory. Con: it needs the marker mechanism; a one-time reconciliation of the ADR cluster (this consolidation).
- **Option 3 (CI-only).** Pro: maximal automation. Con: it discards the maintainer's substance review; CI cannot attest a change matches intent, only that it builds and passes. The shift-left review is the point, not a cost to remove.

## Amendment — security surfaces no longer fire the maintainer gate

Extends review-by-exception to security-sensitive surfaces, completing full PR-merge autonomy.

**Change.** A diff touching a security-sensitive surface (auth, crypto, secrets, tenancy) **no longer fires the maintainer gate by default.** Security *substance* is decided shift-left at the spec/plan; the maintainer's routine code-level review between spec and merge added little.

**The relocated net** (security assurance after the change; the net relocates, it does not vanish):

1. **Shift-left.** Security design is reviewed at spec/plan time (the governing artifact), where the maintainer's review already happens.
2. **Mandatory pre-push security review.** A security-surface diff requires a code+security review on the worktree *before* push, regardless of whether the plan explicitly named it; the security surface itself triggers it. Findings are addressed in the reviewer→implementer fix loop (quality-gate carve-out, up to three rounds) like any other review finding; once the review is clean, the orchestrator merges autonomously. This is the per-PR code-level net that replaces the maintainer's eyes.
3. **Escalate the exception, not the severity (refines stop-condition 6).** A Critical/High finding is *first addressed* in the fix loop; severity alone is **not** an escalation trigger. It reaches the maintainer pre-push only when the loop **can't resolve it** within the cap, or the team makes a deliberate **decide-not-to-fix** judgment (a false-positive call, or a fix needing a design tradeoff). A Critical/High the loop clears merges autonomously and surfaces in the trust-then-retro batch: visibility without a pre-merge gate.
4. **Announce-no-hold plus the hold lever.** Unchanged.

**Scope: all repos, public and private, identically.** The irreversible-exposure concern for public repos is carried by the pre-push security review plus stop-condition 6, not by the maintainer's routine review. **Tripwire:** revisit this uniformity if a public-repo security miss ever occurs.

**Net:** the maintainer's *routine* per-security-PR review is retired; the security reviewer runs the pre-push review and only Critical/High reaches the maintainer, the same review-by-exception model the rest of this ADR applies, now extended to security surfaces.

## More Information

- **Marker convention shared with the document-editor project.** That project homes document *status* in frontmatter with a state-vs-schema split. A spec is a reviewable document; "approved by the maintainer" is a status value, so the spec review-marker is an instance of document-approval-via-frontmatter, and conforms to that concrete status schema when it locks. (Convergence tripwire.)
- **Origin:** an over-ceremonious merge (a doc deletion executing a locked decision) surfaced the merge-vs-review conflation; the maintainer's reconciliation: "the orchestrator always does the mechanical merge + PR; my review is before the PR, on the items already classified as needing it, or a hold."
