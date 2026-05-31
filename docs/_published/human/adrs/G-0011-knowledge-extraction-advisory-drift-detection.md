---
title: "G-0011: Knowledge-Extraction Skill — R7 Advisory-Drift Detection"
summary: "New operational-form skill: advisory phrase list + LLM self-check protocol for operational-form detection; reusable across /spec, /discover."
primary-audience: agent
---

# G-0011: Knowledge-Extraction Skill — R7 Advisory-Drift Detection (new operational-form skill)

**Status:** Accepted
**Date:** 2026-04-24

## Context

R7 is the requirement that rejects any candidate rule text that isn't in operational form: an observable actor, an observable action, and an observable outcome. The discovery pass ([/discover](../glossary.md#discover), the earlier-generation scope pass the brief workflow now absorbs) committed to a two-pass algorithm for catching advisory drift: a deterministic phrase list first, then an LLM self-check for paraphrases the list misses. This ADR decides where the phrase list and the self-check protocol live.

## Decision

Create a new dedicated **operational-form skill** in the agent-skills library, scoped to operational-form detection alone. The knowledge-extraction skill references it. Future consumers like [/spec](../glossary.md#spec) (a specification stage that defines what done looks like) and /discover can adopt it the same way.

File contents (seed):

- **Advisory phrase list** (~12 to 15 for v1, growable): "ensure appropriate", "use best judgment", "consider", "where possible", "as needed", "if necessary", "where applicable", "if appropriate", "when reasonable", "try to", "should ideally", "would benefit from", "as required", "if feasible", "gauge whether"
- **Positive pattern definition:** operational form = observable actor + observable action + observable outcome
- **Worked examples (~5 pairs):** advisory → operational rewrites that calibrate LLM judgment

**LLM self-check protocol** (the fallback for paraphrases the phrase list won't catch): this surfaces a probe rather than rejecting silently. If nothing in the phrase list matches and the LLM judges the candidate to be missing an actor, action, or outcome, the skill emits an **R20 redirect**. R20 is the surfacing form: instead of dropping the candidate, it asks "candidate reads as advisory: which element (actor / action / outcome) needs specifying?"

**Update cadence (retro-driven):** during retros the maintainer (the person who owns the canon) flags paraphrases to add to the phrase list, or flags false positives to add as a counter-example pair. The orchestrator (the role that routes and coordinates work, see [the orchestrator](../glossary.md#the-orchestrator)) edits the file inline. Soft cap: 30 phrases.

## Alternatives Considered

- **Reuse the no-ai-writing skill.** Rejected. It's a different domain entirely. The no-ai-writing skill governs external-writing style: marketing buzzwords and AI-detection signals. Operational-form detection governs advisory drift in requirements language. The two share almost no vocabulary, and merging them would dilute both.
- **Embed the phrase list in the knowledge-extraction skill.** Rejected. The knowledge-extraction skill is the first concrete consumer, but operational-form is a reusable concern. Embedding it there forces duplication the moment a second consumer lands.
- **Put it in a config file at a separate path.** Rejected. The phrase list isn't pure data. The self-check protocol and the worked examples belong with the list, and a skill file is the right container for all three.

## Consequences

- A new reusable skill concern. Consumers load it by reference.
- /spec and /discover can adopt it for requirements drift checking with zero duplication.
- Mnemra-portable: it's a markdown skill file with the list inline.
- Model-neutrality holds. The phrase list is natural English, the self-check protocol is model-neutral, and any model-specific flagging stays isolated at inference time.
- Composition integrity holds. The list is data, the self-check probes rather than rejecting silently, and every update is carrier-sanctioned.
- /spec owns the file skeleton, the phrase-list format (flat versus categorized), the self-check prompt template, and the consumer-load idiom.
