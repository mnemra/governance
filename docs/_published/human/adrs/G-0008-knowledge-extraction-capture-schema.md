---
title: "G-0008: Knowledge-Extraction Skill — Capture Table Schema and Partial-State Recovery"
summary: "Child table skill_run_captures (FK to skill_runs) holds per-capture observability; writer-ownership, partial-state resume, and /clear orphan semantics specified."
primary-audience: agent
---

# G-0008: Knowledge-Extraction Skill — Capture Table Schema and Partial-State Recovery

**Status:** Accepted
**Date:** 2026-04-24

## Context

Several requirements drive this decision. R15 and R16a want per-capture observability: capture_type, destination, convergence rounds, event tallies, and round summaries. R3a adds linked captures, which need more than one row per skill run. Q7 wants partial-state recovery, which means keeping the trigger context and transcript around so a capture can resume on the next invocation.

The existing `skill_runs` table is already live, and it's orchestration-generic. It isn't tied to any one skill. This ADR decides where the knowledge-extraction-specific capture data should live instead.

## Decision

Add a child table **`skill_run_captures`**, with a foreign key to `skill_runs(id)` and `ON DELETE CASCADE`. The migration target is the task DB. A future mnemra metrics layer will inherit this schema when it copy-and-freezes from the current implementation. That layer doesn't exist yet at /architect time, so its sequencing is TBD per the project plan.

Columns:

- `state` CHECK-constrained to `partial | complete | abandoned`
- `capture_type` CHECK-constrained to `rule | pattern | preference | heuristic-transformed | underspecified-revisit | linked-capture | abandoned | no-context`
- `destination_type` CHECK-constrained to the five G-0009 destination types (`feedback_memory | skill | adr | about | research`)
- `destination_path` TEXT
- `trigger_context` TEXT. The full text that triggered this capture, kept for resume lookup.
- `trigger_summary` TEXT. A one-line digestible preview, used in the resume-list UX so the carrier gets a recall cue without reading the whole trigger.
- `transcript` TEXT. The elicitation turns so far, as markdown or JSON; the exact format is settled in /spec.
- `event_tallies` TEXT. JSON, with `CHECK (json_valid(event_tallies))`. It has 10 named fields: `heuristic_transformed`, `split_proposed`, `linked_capture`, `underspecified_revisit`, `advisory_rejected`, `nudge_declined`, `ceiling_exceeded`, `r17_scanned`, `r17_overlap_detected`, `no_context`. The last two boolean R17 fields give R17 observability regardless of how the overlap judgment comes out (per test-author review round 1). `no_context` was added in spec r2; it's set when the carrier invokes the skill without trigger context and can't supply one when prompted. It stays distinct from `nudge_declined` so analytics queries can separate the two abandon reasons.
- `round_summary_log` TEXT. JSON array, with `CHECK (json_valid(round_summary_log))`. Per-round fields: `fields_populated`, `counter_cases_added`, `advisory_phrases_removed` (the R16a convergence observable).
- Standard `summary`, `convergence_rounds`, `created_at`, `updated_at`

**Invariant:** `state = 'abandoned' IFF capture_type = 'abandoned'`. This is biconditional: one holds exactly when the other does. The `abandoned` value in `capture_type` is reserved for ceiling-exceeded or underspecified-revisit failures, and those are the only paths that set `state='abandoned'`. Non-abandoned `state` values (`partial`, `complete`) pair with the other `capture_type` values (`rule`, `pattern`, and so on). /spec (the specification that defines what done looks like) enforces this invariant through a CHECK constraint or trigger, with the exact mechanism settled in /spec.

**Run-level token accumulator:** add a column `run_token_estimate INTEGER` (or an equivalent counter) to the parent `skill_runs` table to hold the aggregated char-count-estimate across every capture in the run. This is the field G-0012's M_run ceiling reads from. /spec picks between "column on parent" and "computed-on-demand from children." The architecture commitment is only this: the value is observable without scanning transcripts.

**Writer ownership:** the orchestrator (the role that routes and coordinates work, dispatching to specialists and integrating results) is the only writer to `skill_run_captures`. Rows are inserted at capture start (`state='partial'`), updated after each elicitation round (which updates `transcript`, `round_summary_log`, and `convergence_rounds`), and transitioned to `state='complete'` or `state='abandoned'` at exit. A session-drop produces a natural `state='partial'` row via the last successful per-round write. Hooks never write to this table. That follows from composition integrity: hooks detect and deliver, they don't capture.

**Partial-state resume (carrier-picks):** at invocation, the skill lists every `state='partial'` row. These rows are DB-resident and session-independent, so partials from prior `session_id` values are still visible. The list shows `trigger_summary` previews, timestamps, and probe counts, and the carrier picks one to resume or starts fresh. Abandoned captures, whether from a ceiling hit or an underspecified-revisit, are filed with their full transcript but are not auto-offered for resume. This is a deliberate shift away from /discover's Failure Modes row, which implied auto-match. See the constraints-summary Feedback to Requirements for the reconciliation.

**/clear mid-capture orphan path:** partials live in `skill_run_captures`, not in the state file. So a `/clear` that resets `session_id` doesn't orphan the partial, because the next invocation's resume-list query is session-independent. The carrier sees the partial in the list even though the new session's `session_id` differs from the one that created the partial row.

Cleanup of partials is manual via the workspace CLI's skill-run capture commands (`list-partials` plus `abandon <id>`) for v1.

## Alternatives Considered

- **Add columns to `skill_runs`.** Rejected. It pollutes the generic orchestration table with domain-specific fields that stay sparse for other skills. Composition with future skill domains only gets worse as more columns accrete.
- **Generic `skill_run_artifacts` with a JSON blob.** Rejected. Blob-schema queries turn into JSON-path soup. Mnemra absorption (the F0 posture) favors clean domain tables over blobs.
- **Resume by trigger-context hash match.** Rejected. It's brittle, since a slight rewording fails the match. It also creates a magic-matching path that violates composition integrity; the carrier should choose explicitly.
- **Resume via a UUID resume-token.** Rejected. Carrier-picks from a list is simpler and avoids token management.
- **Transcript in a file (`.claude/hooks/state/...md`).** Rejected. In-DB TEXT keeps all state in one migratable place, and SQLite handles multi-KB text fine.

## Consequences

- A full capture query needs a join. That's acceptable; the `skill_run_retros` precedent already established it.
- The migration is forward-only: a new table, no changes to existing columns.
- Mnemra absorption exports three tables cleanly: `skill_runs`, `skill_run_retros`, and `skill_run_captures`.
- Partial and abandoned semantics are meaningfully distinct. Partial means the carrier intends to continue. Abandoned means a prior attempt didn't converge, so fresh framing is usually the right next step.
- Composition integrity holds: the carrier picks the resume target, and the agent never auto-matches.
