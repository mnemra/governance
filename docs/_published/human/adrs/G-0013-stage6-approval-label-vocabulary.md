---
title: "G-0013: Stage 6 Approval — Closed-Enum Label Vocabulary as Canonical Gating Signal"
summary: "PR labels (stage6-approved, release-mode-*, bump:*) form the canonical Stage 6 signal; cardinality-failure = ABORT; audit via workspace activity log; authorization enforcement delegated to G-0024."
primary-audience: agent
---

# G-0013: Stage 6 Approval — Closed-Enum Label Vocabulary as Canonical Gating Signal

**Status:** Accepted
**Date:** 2026-04-30

## Context

The code workflow runs in numbered stages. Stage 6 is the maintainer-approval gate, the point where the person who owns the canon signs off on a change. Stage 7 is the auto-merge step that runs right after. Stage 6 needs a machine-readable signal that Stage 7's auto-merge logic can read directly, without re-deriving intent from prose. Two questions converged here:

- **Q1 (canonical signal):** how does an approved chunk announce itself? A DB-canonical approach (a `stage6_approvals` table in the task DB) was rejected because the workspace CLI is in maintenance mode pending mnemra absorption. Investing in new schemas now is wasted work. The remaining candidates collapsed to PR labels.
- **Q1+ (audit surface):** where does the approval get durably recorded so a future audit can answer "who approved chunk #N, when, in which mode"? The activity log table already exists. The question was whether to extend it with a typed approval row or use the generic surface.

[Discover](../glossary.md#discover), the earlier-generation pass that fixes scope before a spec is written, locked the workflow stages and the principle of "fewer moving parts" (QA3 anchor). Both initial strawmen proposed label-canonical signaling. The open choice was which label vocabulary to use.

## Decision

**Closed-enum PR labels** form the canonical Stage 6 approval signal. There are three label families, each with a fixed set of allowed values:

| Family | Values | Cardinality |
|--------|--------|-------------|
| Approval | `stage6-approved` | 0 or 1 |
| Release mode | `release-mode-A`, `release-mode-B`, `release-mode-A-exception` | exactly 1 (when `stage6-approved` present) |
| Version bump | `bump:patch`, `bump:minor`, `bump:major`, `bump:none` | exactly 1 (when `stage6-approved` present) |

`bump:none` (added per G-0021) is for docs-only, internal-only, or CHANGELOG-edit-only merges where no version change applies. Enforcement is honor-system plus reviewer responsibility at Stage 4, the review stage, per G-0021. There's no tool-side path-coverage gate.

**Cardinality-failure mode = ABORT, never pickapick.** When the cardinality check sees zero or two-plus labels in a required-cardinality family, the gate fails loud with a stderr message identifying the conflicting labels and the rule violated. The PR's check status reads "failure" until labels are corrected. The gate never silently disambiguates. A "last label wins" rule, for instance, would let an actor with label-write permission append `bump:none` after a maintainer's `bump:patch` to suppress a version bump on a security-relevant change.

**Authorization and required-status-check enforcement are specified in G-0024.** G-0024 closes the structural bypasses surfaced in review: any Triage+ collaborator can apply labels by GitHub default, and the GitHub merge UI button bypasses the workspace template scripts. G-0024 layers a label-set authorization workflow (`verify-stage6-labeler`) and a required-status-check (`verify-stage6-labels`, enforced via branch protection) on top, so the cardinality discipline is structural and not merely script-side.

Stage 7 auto-merge logic reads labels via `gh api`. Absence or wrong-cardinality fails the merge. No free-form labels are honored in the gating logic. Teams may add other labels for tracking, but they have no semantic effect on the gate. The cardinality check runs at every relevant moment (PR open, label change, queued via merge_group per G-0023, and at merge attempt) so post-creation cardinality drift cannot escape the gate.

**Audit recording uses the existing workspace activity log surface** with no schema expansion. At approval time, Stage 7 emits:

```
<workspace-cli> activity log --actor <maintainer> \
  --action "stage6-approved chunk #<ref> mode <X> bump <Y>" \
  --task-id <chunk-task-id>
```

The action string carries all three gating-label values (approval, release-mode, bump) so retrieval-time cross-reference (G-0024 Layer C) can verify the full gating signal against the GitHub event log, not just the approval label. The action string is parseable but unstructured. A future audit reconstructs approvals by querying the activity log on the `stage6-approved` action prefix.

## Alternatives Considered

- **DB-canonical (`stage6_approvals` table in task DB).** Rejected. It requires a workspace CLI extension, and the workspace CLI is in maintenance pending mnemra absorption. Schema work that won't migrate cleanly to mnemra's plugin model is wasted.
- **Free-form labels (e.g., an `approved-by-maintainer` text label).** Rejected. It defeats the gate's purpose; downstream logic would need to fuzzy-match. The closed enum is the abstraction.
- **PR description prose with a marker phrase (`<!-- stage6: approved mode A -->`).** Rejected. Higher parsing surface, harder to enforce cardinality, harder to filter via `gh api`. Labels are the GitHub-native primitive.
- **Typed activity log row (`event_type=stage6_approval`, structured fields).** Rejected for v1 because it adds schema before there's a need; the current generic action surface satisfies audit reconstruction. Revisit if audit volume grows or mnemra brings a richer activity model.

## Consequences

- **Stage 7 auto-merge logic depends on label cardinality.** The Stage 7 implementation (a per-repo workflow file) MUST validate exactly-one-of in each family before invoking `gh pr merge --auto`. A missing or duplicate label fails the gate.
- **Stage 6 approval flow is constrained to label setting.** Maintainer approval means adding the three labels. The workspace template script (G-0018) bundles label-set-then-merge so the operator doesn't manage the cardinality manually.
- **Audit retrievability is deferred to query.** No dashboard exists. Operators query the workspace activity log for `stage6-approved` actions when an audit is needed.
- **Migration to mnemra is bounded.** When mnemra's metrics plugin lands, this ADR's audit-action-string convention can be replayed into a richer mnemra schema. The closed-enum labels remain the GitHub-side signal; only the audit substrate changes.
- **Embargo seam:** the closed-enum vocabulary deliberately omits any embargo-related label. Per F2 plus G-0022, no embargo flow exists in v1. If and when the first embargo arrives, this ADR is amended to add the relevant label family (e.g., `embargo:until-<date>`) rather than re-architecting the signal mechanism.
- **Per-repo retrofit:** each in-scope repo's CLAUDE.md cites this ADR via the `follows code-workflow` marker. The Stage 7 workflow YAML adopts the cardinality check as part of the repo retrofit spec, the specification that defines what done looks like for the retrofit. G-0024's `verify-stage6-labels` workflow and its branch-protection required-status-check are part of the same retrofit step.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Audit-row action string widened** to carry the bump value (`stage6-approved chunk #<ref> mode <X> bump <Y>`). Round 2 security review flagged that G-0024 Layer C's compensating control could only verify the approval label. Widening the action string lets Layer C cover bump and release-mode too.

### 2026-04-30 — Round 1 review amendments

Round 1 review (security plus test-author review) surfaced authorization and cardinality-enforcement gaps:

- **Label authorization gap:** by GitHub default, any Triage+ collaborator can apply labels, and the GitHub merge UI bypasses the workspace template script. **Fixed via cross-reference to G-0024.** A new ADR was drafted in r2 covering label-set authorization plus required-status-check enforcement. G-0013 itself is unchanged on the *what* (the closed enum); G-0024 covers the *who* and the *how-enforced*.
- **Cardinality-failure mode unspecified:** the original ADR said "wrong-cardinality fails the merge" but didn't pin abort versus pickapick. **Fixed:** an explicit ABORT-fail-loud rule. Pickapick semantics are ruled out.
- **Cardinality drift post-PR-creation, label removed mid-merge:** the original ADR didn't specify when the cardinality check runs. **Fixed:** the check runs at every relevant moment (PR open, label change, queued via merge_group per G-0023, merge attempt). Post-creation drift is detected.
- **G-0021 cross-coupling:** `bump:none` was added to the bump-label family enum per G-0021. Honor-system enforcement (no path-coverage gate) follows G-0021's amendment.

Status remains **Proposed** pending r2 review.
