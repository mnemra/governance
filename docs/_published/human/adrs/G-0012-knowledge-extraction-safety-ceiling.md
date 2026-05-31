---
title: "G-0012: Knowledge-Extraction Skill — R16b Safety Ceiling Values"
summary: "N=6 rounds per rule, M=20k tokens per rule, M_run=80k tokens per invocation; char-count approximation at runtime; run-level accumulator on skill_runs parent row."
primary-audience: agent
---

# G-0012: Knowledge-Extraction Skill — R16b Safety Ceiling Values

**Status:** Accepted
**Date:** 2026-04-24

## Context

This is a governance ADR (a `G-`-series architecture decision record that applies across the whole ecosystem, not to one project; see the [glossary](../glossary.md)). R16b is the hard abandonment gate. An elicitation attempt for a knowledge-capture rule abandons when its round count or token usage crosses a configured ceiling. The discovery pass (`/discover`, the earlier-generation step that shaped scope before a spec) proposed N=6 rounds and M=20k tokens per rule. The design-framing step (`/architect`) confirms those two and adds a third ceiling at the level of a whole invocation, to catch the case where several linked captures aggregate into a runaway run.

## Decision

| Param | Value | Scope |
|---|---|---|
| **N** | **6** | rounds per rule |
| **M** | **20k** | tokens per rule |
| **M_run** | **80k** | tokens per invocation (all rules aggregate) |

**Measurement:** the safety check approximates token count from the transcript character count, at roughly 4 characters per token, at runtime. Precise LLM-inference token usage is captured later through the `skill_runs` retro, after the fact. The runtime approximation is good enough for the abandonment gate; it doesn't need to match the tokenizer exactly.

**Accumulator field for M_run:** the run-level aggregate is stored on the parent `skill_runs` row, in a new column `run_token_estimate INTEGER` added per the G-0008 addendum. Keeping it there means M_run is observable without re-scanning every child-row transcript. The orchestrator (the role that routes and coordinates work, then integrates the result; it doesn't run the capture itself) updates this field after each capture's probe round.

**On trip:** the skill writes a `skill_run_captures` row with `state=abandoned`, `capture_type=abandoned`, and `event_tallies.ceiling_exceeded=true`, alongside the `round_count` and `token_estimate`. It keeps the trigger context and the full transcript. The R20 redirect message reads: "ceiling hit — filed; reinvoke with fresh framing if you want to take another pass." The tally name uses the underscore form because that's what the `EVENT_TALLY_NAMES` allow-list in the spec workflow (`/spec`) accepts. An earlier draft of this ADR used the hyphenated `ceiling-exceeded`, which the CLI's allow-list validation would reject; it was corrected during the r2 ADR sync.

**Abandoned vs partial distinction (reaffirms G-0008):** abandoned captures are filed, not auto-offered for resume. Partial captures, where the carrier stopped mid-loop, are resumable per G-0008. Abandoned means the prior attempt didn't converge. Fresh framing is usually the right next step rather than picking the stalled attempt back up.

**Data-driven refinement:** after about 20 runs of `skill_runs` data exist, check the average and p95 of both rounds and tokens, and adjust N, M, or M_run if the actual distribution diverges from these values. No pre-tuning before the data is in.

## Alternatives Considered

- **Per-rule ceiling only (no M_run)** — rejected. Linked captures under R3a can involve four or more rules, which could aggregate to 120k+ tokens in a single run. M_run bounds that aggregate runaway.
- **Per-run ceiling only (no per-rule)** — rejected. It loses the per-rule signal. A single stuck rule would burn the whole run budget before anything tripped.
- **Precise LLM tokenizer at runtime** — rejected. That's overkill for a safety check. The character-count approximation runs in real time and is accurate enough, and the retro already has exact counts.
- **Lower N (e.g., 4)** — rejected. The happy path is 3 rounds, and extended cases run to 5. N=4 would abandon legitimate probes. N=6 keeps a two-round buffer above the extended case.
- **Higher M (e.g., 40k)** — rejected. 20k already sits about 30% above the expected worst case, which is roughly 10k to 15k for extended captures. A higher ceiling would dilute the "something's wrong" signal.

## Consequences

- Runaway probe loops are bounded at a modest per-rule granularity.
- Linked-capture aggregates get caught through M_run.
- The runtime check is cheap, since it's a character count. Precise measurement comes from the retro.
- Refinement is retro-driven once data accumulates. Nothing gets pre-tuned.
- Composition integrity holds: the ceiling is a safety gate, not a judgment call, and the R20 redirect surfaces the trip to the carrier with a path back in.
- The spec workflow (`/spec`) owns the config location for the three constants, the measurement implementation, the R20 redirect phrasing, and the post-abandon retrieval experience.
