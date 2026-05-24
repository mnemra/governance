---
title: "G-0008: Knowledge-Extraction Skill — Capture Table Schema and Partial-State Recovery"
summary: "Child table skill_run_captures (FK to skill_runs) holds per-capture observability; writer-ownership, partial-state resume, and /clear orphan semantics specified."
primary-audience: agent
---

# G-0008: Knowledge-Extraction Skill — Capture Table Schema and Partial-State Recovery

**Status:** Accepted
**Date:** 2026-04-24

## Context

R15 and R16a require per-capture observability (capture_type, destination, convergence rounds, event tallies, round summaries). R3a linked captures require multiple rows per skill run. Q7 partial-state recovery requires retained trigger context and transcript for resume on next invocation.

The existing `skill_runs` table (schema live) is orchestration-generic. This ADR decides where knowledge-extraction-specific capture data lives.

## Decision

Add a child table **`skill_run_captures`** (FK to `skill_runs(id)` with `ON DELETE CASCADE`). **Migration target: the task DB.** A future mnemra metrics layer inherits the schema when it copy-and-freezes from the current implementation (mnemra metrics layer does not exist yet at /architect time; sequencing TBD per project plan).

Columns:

- `state` CHECK-constrained to `partial | complete | abandoned`
- `capture_type` CHECK-constrained to `rule | pattern | preference | heuristic-transformed | underspecified-revisit | linked-capture | abandoned | no-context`
- `destination_type` CHECK-constrained to the five G-0009 destination types (`feedback_memory | skill | adr | about | research`)
- `destination_path` TEXT
- `trigger_context` TEXT — full text that triggered this capture (for resume lookup)
- `trigger_summary` TEXT — one-line digestible preview, used in the resume-list UX so the carrier has a recall cue without reading the whole trigger
- `transcript` TEXT — elicitation turns so far (markdown or JSON; exact format in /spec)
- `event_tallies` TEXT — JSON, with `CHECK (json_valid(event_tallies))`. Named fields (10 total): `heuristic_transformed`, `split_proposed`, `linked_capture`, `underspecified_revisit`, `advisory_rejected`, `nudge_declined`, `ceiling_exceeded`, `r17_scanned`, `r17_overlap_detected`, `no_context`. The last two boolean R17 fields give R17 observability regardless of overlap judgment outcome (per test-author review round 1). `no_context` (added in spec r2) is set when the carrier invokes the skill without trigger context AND cannot supply one when prompted; it is distinct from `nudge_declined` so analytics queries can separate the two abandon reasons.
- `round_summary_log` TEXT — JSON array, with `CHECK (json_valid(round_summary_log))`. Per-round fields: `fields_populated`, `counter_cases_added`, `advisory_phrases_removed` (R16a convergence observable)
- Standard `summary`, `convergence_rounds`, `created_at`, `updated_at`

**Invariant:** `state = 'abandoned' IFF capture_type = 'abandoned'`. The `abandoned` value in `capture_type` is reserved for ceiling-exceeded OR underspecified-revisit failures; those are the only paths that set `state='abandoned'`. Non-abandoned `state` values (`partial`, `complete`) pair with the other `capture_type` values (`rule`, `pattern`, etc.). /spec enforces this invariant via a CHECK constraint or trigger (exact mechanism in /spec).

**Run-level token accumulator:** add a column `run_token_estimate INTEGER` (or equivalent counter) to the parent `skill_runs` table to hold the aggregated char-count-estimate across all captures in the run. This is the field G-0012's M_run ceiling reads from. /spec picks between "column on parent" vs "computed-on-demand from children"; the architecture commitment is only that the value is observable without scanning transcripts.

**Writer ownership:** the orchestrator is the only writer to `skill_run_captures`. Rows are inserted at capture start (`state='partial'`), updated after each elicitation round (updates `transcript`, `round_summary_log`, `convergence_rounds`), and transitioned to `state='complete'` or `state='abandoned'` at exit. Session-drop produces a natural `state='partial'` row via the last successful per-round write. Hooks never write to this table (per composition integrity — hooks detect and deliver, they do not capture).

**Partial-state resume (carrier-picks):** at invocation, skill lists all `state='partial'` rows (DB-resident, **session-independent** — partials from prior `session_id` values are still visible) with `trigger_summary` previews, timestamps, and probe counts; **carrier picks** one to resume or starts fresh. Abandoned captures (ceiling hit or underspecified-revisit) are filed with full transcript but **not** auto-offered for resume. This is a deliberate shift from /discover's Failure Modes row implying auto-match (see constraints-summary Feedback to Requirements for the reconciliation).

**/clear mid-capture orphan path:** because partials live in `skill_run_captures` (not in the state file), a `/clear` that resets `session_id` does not orphan the partial — the next invocation's resume-list query is session-independent. The carrier sees the partial in the list even though the new session's `session_id` differs from the one that created the partial row.

Cleanup of partials is manual via the workspace CLI's skill-run capture commands (`list-partials` + `abandon <id>`) for v1.

## Alternatives Considered

- **Add columns to `skill_runs`** — rejected. Pollutes generic orchestration table with domain-specific fields. Sparse for other skills. Composition with future skill domains gets worse the more columns accrete.
- **Generic `skill_run_artifacts` with JSON blob** — rejected. Blob-schema queries become JSON-path soup. Mnemra absorption (F0 posture) favors clean domain tables over blobs.
- **Resume by trigger-context hash match** — rejected. Brittle — slight rewording fails; also creates a magic-matching path that violates composition integrity (carrier should choose explicitly).
- **Resume via UUID resume-token** — rejected. Carrier-picks from list is simpler and avoids token management.
- **Transcript in a file (`.claude/hooks/state/...md`)** — rejected. In-DB TEXT keeps all state in one migratable place; SQLite handles multi-KB text fine.

## Consequences

- Join required for full capture query — acceptable, `skill_run_retros` precedent already established.
- Forward-only migration (new table, no existing-column changes).
- Mnemra absorption exports three tables cleanly: `skill_runs`, `skill_run_retros`, `skill_run_captures`.
- Partial vs abandoned semantics are meaningfully distinct: partial = carrier intent to continue; abandoned = prior attempt didn't converge, fresh framing is usually correct next step.
- Composition integrity: carrier picks resume target; agent never auto-matches.
