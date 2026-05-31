---
title: "G-0012: Knowledge-Extraction Skill — R16b Safety Ceiling Values"
summary: "N=6 rounds per rule, M=20k tokens per rule, M_run=80k tokens per invocation; char-count approximation at runtime; run-level accumulator on skill_runs parent row."
primary-audience: agent
---

# G-0012: Knowledge-Extraction Skill — R16b Safety Ceiling Values

**Status:** Accepted
**Date:** 2026-04-24

## Context

R16b is the hard abandonment gate — an elicitation attempt abandons when round count or token usage exceeds a configured ceiling. /discover proposed N=6 rounds and M=20k tokens per rule; /architect confirms and adds a run-level ceiling to catch linked-capture aggregate runaway.

## Decision

| Param | Value | Scope |
|---|---|---|
| **N** | **6** | rounds per rule |
| **M** | **20k** | tokens per rule |
| **M_run** | **80k** | tokens per invocation (all rules aggregate) |

**Measurement:** transcript character-count approximation (~4 chars/token) at runtime for the safety check. Precise LLM-inference token usage captured via `skill_runs` retro post-hoc; runtime approximation is adequate for the abandonment gate.

**Accumulator field for M_run:** the run-level aggregate is stored on the parent `skill_runs` row (new column `run_token_estimate INTEGER` per G-0008 addendum) so M_run is observable without re-scanning all child-row transcripts. Updated by the orchestrator after each capture's probe round.

**On trip:** `skill_run_captures` row with `state=abandoned`, `capture_type=abandoned`, `event_tallies.ceiling_exceeded=true` + round_count + token_estimate. Trigger context and full transcript retained. R20 redirect: "ceiling hit — filed; reinvoke with fresh framing if you want to take another pass." (Tally-name uses underscore-form per the EVENT_TALLY_NAMES allow-list in /spec — earlier draft of this ADR used hyphenated `ceiling-exceeded` which would be rejected by the CLI's allow-list validation; corrected during r2 ADR sync.)

**Abandoned vs partial distinction (reaffirms G-0008):** abandoned captures are filed, not auto-offered for resume. Partial captures (carrier-stopped mid-loop) are resumable per G-0008. Abandoned = "prior attempt didn't converge"; fresh framing usually correct next step.

**Data-driven refinement:** after ~20 runs of `skill_runs` data, check avg + p95 of rounds and tokens; adjust N / M / M_run if actual distribution diverges. No pre-tuning.

## Alternatives Considered

- **Per-rule ceiling only (no M_run)** — rejected. R3a linked captures with 4+ rules could aggregate to 120k+ tokens per run. M_run bounds aggregate runaway.
- **Per-run ceiling only (no per-rule)** — rejected. Loses per-rule signal; a single stuck rule would consume the full budget before tripping.
- **Precise LLM tokenizer at runtime** — rejected. Overkill for a safety check; char-count approximation is real-time and accurate enough. Retro has exact counts.
- **Lower N (e.g., 4)** — rejected. Happy path is 3 rounds; extended cases run 5. N=4 would abandon legitimate probes. N=6 preserves two-round buffer.
- **Higher M (e.g., 40k)** — rejected. 20k is already ~30% above expected-worst (~10–15k extended). Higher ceiling dilutes the "something's wrong" signal.

## Consequences

- Bounds runaway probe loops at modest per-rule granularity.
- Linked-capture aggregates caught via M_run.
- Runtime check is cheap (char-count); precise measurement via retro.
- Refinement is retro-driven after data accumulates; no pre-tuning.
- Composition integrity: ceiling is safety gate, not judgment; R20 redirect surfaces the trip to carrier with reinvocation path.
- /spec owns config location for the three constants, measurement implementation, R20 redirect phrasing, post-abandon retrieval UX.
