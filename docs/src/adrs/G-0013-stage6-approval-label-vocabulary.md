---
title: "G-0013: Stage 6 Approval — Closed-Enum Label Vocabulary as Canonical Gating Signal"
summary: "PR labels (stage6-approved, release-mode-*, bump:*) form the canonical Stage 6 signal; cardinality-failure = ABORT; audit via workspace activity log; authorization enforcement delegated to G-0024."
primary-audience: agent
---

# G-0013: Stage 6 Approval — Closed-Enum Label Vocabulary as Canonical Gating Signal

**Status:** Accepted
**Date:** 2026-04-30

## Context

The code workflow's Stage 6 (maintainer approval gate) needs a machine-readable signal that downstream Stage 7 auto-merge logic can read without re-deriving intent from prose. Two questions converged here:

- **Q1 (canonical signal):** how does an approved chunk announce itself? A DB-canonical approach (`stage6_approvals` table in the task DB) was rejected because the workspace CLI is in maintenance mode pending mnemra absorption; investing in new schemas now is wasted work. The remaining candidates collapsed to PR labels.
- **Q1+ (audit surface):** where does the approval get durably recorded so a future audit can answer "who approved chunk #N, when, in which mode"? The activity log table already exists; the question was whether to extend it with a typed approval row or use the generic surface.

Discovery locked the workflow stages and the principle of "fewer moving parts" (QA3 anchor). Initial strawmen both proposed label-canonical signaling; the choice was which label vocabulary.

## Decision

**Closed-enum PR labels** form the canonical Stage 6 approval signal. Three label families, each with a fixed value set:

| Family | Values | Cardinality |
|--------|--------|-------------|
| Approval | `stage6-approved` | 0 or 1 |
| Release mode | `release-mode-A`, `release-mode-B`, `release-mode-A-exception` | exactly 1 (when `stage6-approved` present) |
| Version bump | `bump:patch`, `bump:minor`, `bump:major`, `bump:none` | exactly 1 (when `stage6-approved` present) |

`bump:none` (added per G-0021) is for docs-only / internal-only / CHANGELOG-edit-only merges where no version change applies. Honor-system + Stage 4 reviewer responsibility per G-0021; no tool-side path-coverage gate.

**Cardinality-failure mode = ABORT, never pickapick.** When the cardinality check sees zero or two-plus labels in a required-cardinality family, the gate fails loud with a stderr message identifying the conflicting labels and the rule violated. The PR's check status reads "failure" until labels are corrected. The gate never silently disambiguates (e.g., "last label wins") — that would let an actor with label-write permission append `bump:none` after a maintainer's `bump:patch` to suppress a version bump on a security-relevant change.

**Authorization and required-status-check enforcement are specified in G-0024.** G-0024 closes the structural bypasses surfaced in review: any Triage+ collaborator can apply labels by GitHub default, and the GitHub merge UI button bypasses workspace template scripts. G-0024 layers a label-set authorization workflow (`verify-stage6-labeler`) and a required-status-check (`verify-stage6-labels` enforced via branch protection) so the cardinality discipline is structural, not just script-side.

Stage 7 auto-merge logic reads labels via `gh api`; absence or wrong-cardinality fails the merge. No free-form labels are honored in the gating logic; teams may add other labels for tracking but they have no semantic effect on the gate. The cardinality check runs at every relevant moment (PR open, label change, queued via merge_group per G-0023, and at merge attempt) so post-creation cardinality drift cannot escape the gate.

**Audit recording uses the existing workspace activity log surface** with no schema expansion. At approval time, Stage 7 emits:

```
brain activity log --actor <maintainer> \
  --action "stage6-approved chunk #<ref> mode <X> bump <Y>" \
  --task-id <chunk-task-id>
```

The action string carries all three gating-label values (approval, release-mode, bump) so retrieval-time cross-reference (G-0024 Layer C) can verify the full gating signal against the GitHub event log, not just the approval label. The action string is parseable but unstructured. A future audit reconstructs approvals by querying the activity log on the `stage6-approved` action prefix.

## Alternatives Considered

- **DB-canonical (`stage6_approvals` table in task DB).** Rejected. Requires workspace CLI extension; workspace CLI is in maintenance pending mnemra absorption. Schema work that won't migrate cleanly to mnemra's plugin model is wasted.
- **Free-form labels (e.g., `approved-by-maintainer` text).** Rejected. Defeats the gate's purpose; downstream logic would need to fuzzy-match. Closed enum is the abstraction.
- **PR description prose with marker phrase (`<!-- stage6: approved mode A -->`).** Rejected. Higher parsing surface; harder to enforce cardinality; harder to filter via `gh api`. Labels are the GitHub-native primitive.
- **Typed activity log row (`event_type=stage6_approval`, structured fields).** Rejected for v1 — adds schema before need; current generic action surface satisfies audit reconstruction. Revisit if audit volume grows or mnemra brings a richer activity model.

## Consequences

- **Stage 7 auto-merge logic depends on label cardinality.** Stage 7 implementation (per-repo workflow file) MUST validate exactly-one-of in each family before invoking `gh pr merge --auto`. A missing or duplicate label fails the gate.
- **Stage 6 approval flow is constrained to label setting.** Maintainer approval = adding the three labels. The workspace template script (G-0018) bundles label-set-then-merge so the operator doesn't manage the cardinality manually.
- **Audit retrievability is deferred to query.** No dashboard exists; operators query the workspace activity log for "stage6-approved" actions when an audit is needed.
- **Migration to mnemra is bounded.** When mnemra's metrics plugin lands, this ADR's audit-action-string convention can be replayed into a richer mnemra schema. Closed-enum labels remain the GitHub-side signal; only the audit substrate changes.
- **Embargo seam:** the closed-enum vocabulary deliberately omits any embargo-related label. Per F2 + G-0022, no embargo flow exists in v1; if/when the first embargo arrives, this ADR is amended to add the relevant label family (e.g., `embargo:until-<date>`) rather than re-architecting the signal mechanism.
- **Per-repo retrofit:** each in-scope repo's CLAUDE.md cites this ADR via the `follows code-workflow` marker. Stage 7 workflow YAML adopts the cardinality check as part of the repo retrofit /spec. G-0024's `verify-stage6-labels` workflow + branch-protection required-status-check are part of the same retrofit step.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Audit-row action string widened** to carry bump value (`stage6-approved chunk #<ref> mode <X> bump <Y>`). Round 2 security review flagged that G-0024 Layer C's compensating control could only verify the approval label; widening the action string lets Layer C cover bump + release-mode too.

### 2026-04-30 — Round 1 review amendments

Round 1 review (security + test-author review) surfaced authorization and cardinality-enforcement gaps:

- **Label authorization gap:** by GitHub default, any Triage+ collaborator can apply labels; GitHub merge UI bypasses workspace template script. **Fixed via cross-reference to G-0024** — new ADR drafted in r2 covering label-set authorization + required-status-check enforcement. G-0013 itself unchanged on the *what* (closed enum); G-0024 covers *who* + *how-enforced*.
- **Cardinality-failure mode unspecified:** original ADR said "wrong-cardinality fails the merge" but didn't pin abort-vs-pickapick. **Fixed:** explicit ABORT-fail-loud rule. Pickapick semantics ruled out.
- **Cardinality drift post-PR-creation, label removed mid-merge:** original ADR didn't specify when the cardinality check runs. **Fixed:** check runs at every relevant moment (PR open, label change, queued via merge_group per G-0023, merge attempt). Post-creation drift detected.
- **G-0021 cross-coupling:** `bump:none` added to the bump-label family enum per G-0021. Honor-system enforcement (no path-coverage gate) per G-0021's amendment.

Status remains **Proposed** pending r2 review.
