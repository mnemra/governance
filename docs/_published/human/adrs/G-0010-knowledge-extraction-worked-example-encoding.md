---
title: "G-0010: Knowledge-Extraction Skill — R10 Worked-Example Encoding"
summary: "13 initial worked examples in a skill-file appendix; retro-driven refinement cadence; soft cap at 20 examples before trim decision."
primary-audience: agent
---

# G-0010: Knowledge-Extraction Skill — R10 Worked-Example Encoding

**Status:** Accepted
**Date:** 2026-04-24

## Context

R10 is a rule in the knowledge-extraction skill. It routes by LLM judgment, not by a decision-tree lint, a choice made earlier in the discovery pass (`/discover`, the discovery pass the brief workflow now absorbs). Judgment-based routing needs calibration. Worked examples placed in the body of the skill file supply it: the model reads them as it routes and learns the call from the cases shown. This decision settles four things: how many examples to start with, what the set should cover, where the examples live, and how the set gets refined over time.

## Decision

**13 initial worked examples:**

- 5 canonical — one per R10 destination type (`feedback_memory`, `skill`, `adr`, `about`, `research`)
- 5 contrasting — one per destination that could plausibly be confused with an adjacent destination (e.g., behavioral rule vs team-wide practice; profile fact vs research note)
- 3 cross-cutting — one linked-capture (R3a), one transformed-heuristic (R14), one same-scope conflict resolution (R5a)

The canonical five anchor the common case. The contrasting five sit on the boundaries where two destinations look alike and the model is most likely to miscall. The cross-cutting three cover routing rules that span destinations (R3a, R14, and R5a are other rules in the same skill).

**Storage:** a `Worked Examples` appendix at the bottom of the skill file. The routing section above it stays short and rule-focused. The model loads the whole file either way, so in-context calibration is identical no matter where the examples sit. The appendix split is for the human reader's scan, not the model's.

**Refinement cadence:**

| Trigger | Action | Who |
|---|---|---|
| Retro Q3 flags a routing miscall | Add one example targeting that pattern | Orchestrator direct edit during retro |
| Soft cap (20) reached | Surface to maintainer for trim decision | Maintainer picks; orchestrator executes |
| No miscall in 10 runs for a category | Example retirement candidate | Deferred to v2 |

No CLI tooling ships in v1. The skill-examples add and trim commands wait until cap pressure shows up monthly. Building them before then is work ahead of need.

## Alternatives Considered

- **Fewer examples (5–8)** — rejected. The calibration signal is too thin, and edge cases get misclassified more often.
- **More examples (20+ at v1)** — rejected. The skill file bloats. Loadability and reader scan both degrade.
- **External examples file** — rejected. The model loads the same context either way, so there's no loading benefit, and a separate file adds a hop.
- **Decision-tree routing (categorize by regex rules)** — rejected in the discovery pass. Judgment backed by examples wins over rule-matching here.

## Consequences

- The skill file grows by roughly 150–200 lines of worked examples, fenced off in a clearly bounded appendix.
- Refinement runs through retros, which keeps composition intact: the human carrier teaches the agent rather than the agent inferring its own rules in a loop. No auto-inference.
- The soft cap forces curation eventually. That's the accepted price of holding calibration accuracy.
- The spec stage (`/spec`) owns the rest: how the appendix section is named, the field schema each example follows, and the mechanism that enforces the cap.
