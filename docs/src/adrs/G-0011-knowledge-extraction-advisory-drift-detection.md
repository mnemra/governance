---
title: "G-0011: Knowledge-Extraction Skill — R7 Advisory-Drift Detection"
summary: "New operational-form skill: advisory phrase list + LLM self-check protocol for operational-form detection; reusable across /spec, /discover."
primary-audience: agent
---

# G-0011: Knowledge-Extraction Skill — R7 Advisory-Drift Detection (new operational-form skill)

**Status:** Accepted
**Date:** 2026-04-24

## Context

R7 rejects candidate rule text that isn't in operational form (observable actor + action + outcome). /discover committed to a two-pass algorithm: deterministic phrase list + LLM self-check for paraphrases. This ADR decides where the phrase list and self-check protocol live.

## Decision

Create a new dedicated **operational-form skill** in the agent-skills library for operational-form detection. The knowledge-extraction skill references it; future consumers (`/spec`, `/discover`, etc.) can adopt it too.

File contents (seed):

- **Advisory phrase list** (~12–15 for v1, growable): "ensure appropriate", "use best judgment", "consider", "where possible", "as needed", "if necessary", "where applicable", "if appropriate", "when reasonable", "try to", "should ideally", "would benefit from", "as required", "if feasible", "gauge whether"
- **Positive pattern definition:** operational form = observable actor + observable action + observable outcome
- **Worked examples (~5 pairs):** advisory → operational rewrites calibrating LLM judgment

**LLM self-check protocol** (fallback for paraphrases): surfacing probe, not silent reject. If no phrase-list match and the LLM judges the candidate missing actor/action/outcome, skill emits an **R20 redirect**: "candidate reads as advisory — which element (actor / action / outcome) needs specifying?"

**Update cadence (retro-driven):** maintainer flags paraphrases (add to phrase list) or false-positives (add counter-example pair) during retros; orchestrator edits inline. Soft cap: 30 phrases.

## Alternatives Considered

- **Reuse the no-ai-writing skill** — rejected. Different domain entirely: no-ai-writing is external-writing style (marketing buzzwords, AI-detection signals); operational-form is requirements-language advisory drift. Near-zero vocabulary overlap. Merging would dilute both.
- **Embed phrase list in knowledge-extraction skill** — rejected. First concrete consumer but operational-form is a reusable concern; embedding forces duplication when a second consumer lands.
- **Config file at a separate path** — rejected. Phrase list is not pure data — the self-check protocol + worked examples belong with the list. Skill file is the right container.

## Consequences

- New reusable skill concern; consumers load by reference.
- `/spec` and `/discover` can adopt for requirements drift checking with zero duplication.
- Mnemra-portable: markdown skill file with inline list.
- Model-neutrality: phrase list is natural English; self-check protocol is model-neutral; model-specific flagging is isolated at inference.
- Composition integrity: list is data, self-check is probing (not silent reject), all updates carrier-sanctioned.
- /spec owns file skeleton, phrase-list format (flat vs categorized), self-check prompt template, consumer-load idiom.
