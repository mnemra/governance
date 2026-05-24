---
title: "G-0010: Knowledge-Extraction Skill — R10 Worked-Example Encoding"
summary: "13 initial worked examples in a skill-file appendix; retro-driven refinement cadence; soft cap at 20 examples before trim decision."
primary-audience: agent
---

# G-0010: Knowledge-Extraction Skill — R10 Worked-Example Encoding

**Status:** Accepted
**Date:** 2026-04-24

## Context

R10 is LLM-judgment routing (not decision-tree lint per /discover). Worked examples in the skill file body calibrate the judgment. This ADR decides initial count, example-set shape, storage location, and refinement cadence.

## Decision

**13 initial worked examples:**

- 5 canonical — one per R10 destination type (`feedback_memory`, `skill`, `adr`, `about`, `research`)
- 5 contrasting — one per destination that could plausibly be confused with an adjacent destination (e.g., behavioral rule vs team-wide practice; profile fact vs research note)
- 3 cross-cutting — one linked-capture (R3a), one transformed-heuristic (R14), one same-scope conflict resolution (R5a)

**Storage:** `Worked Examples` appendix at the bottom of the skill file. Routing section stays short and rule-focused. LLM loads the full file, so in-context calibration is identical.

**Refinement cadence:**

| Trigger | Action | Who |
|---|---|---|
| Retro Q3 flags a routing miscall | Add one example targeting that pattern | Orchestrator direct edit during retro |
| Soft cap (20) reached | Surface to maintainer for trim decision | Maintainer picks; orchestrator executes |
| No miscall in 10 runs for a category | Example retirement candidate | Deferred to v2 |

No CLI tooling for v1 (skill-examples add/trim commands deferred until cap pressure is monthly).

## Alternatives Considered

- **Fewer examples (5–8)** — rejected. Thin calibration signal; more misclassifications on edge cases.
- **More examples (20+ at v1)** — rejected. Skill file bloat degrades loadability and reader scan.
- **External examples file** — rejected. LLM loads identical context either way; no loading benefit; adds file hop.
- **Decision-tree routing (categorize by regex rules)** — rejected by /discover; judgment with examples preferred.

## Consequences

- Skill file gains ~150–200 lines of worked examples in a clearly bounded appendix.
- Refinement via retros maintains composition (carrier teaches agent); no auto-inference loop.
- Soft cap forces eventual curation — acceptable cost of calibration accuracy.
- /spec owns appendix section naming, per-example field schema, cap enforcement mechanism.
