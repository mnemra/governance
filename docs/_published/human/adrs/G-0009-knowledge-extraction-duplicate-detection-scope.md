---
title: "G-0009: Knowledge-Extraction Skill — R17 Duplicate-Detection Scope"
summary: "Title-only flat grep over 5 destination types, 6 corpora; LLM-driven overlap judgment; field-level UPDATE diff; scope list held as config array for mnemra portability."
primary-audience: agent
---

# G-0009: Knowledge-Extraction Skill — R17 Duplicate-Detection Scope

**Status:** Accepted
**Date:** 2026-04-24

## Context

The knowledge-extraction skill has a requirement, R17, that checks for duplicates before it recommends creating a new knowledge artifact. R17 scans existing destinations for scope-and-topic overlap. When it finds overlap, the recommendation flips from CREATE to UPDATE, and the skill produces a field-level diff instead.

An earlier discovery pass ([discover](../glossary.md#discover)) already committed to one part of the design: title-only flat grep over three things, the memory-index one-liners, the skill titles, and the workspace ADR titles. What that pass left open is the rest. The forward-direction design work (the [decomposer](../glossary.md#the-decomposer)'s job) has to settle four questions. Which corpora get scanned. What the performance ceiling is. What triggers a scan of an artifact's body rather than just its title. And what shape the overlap judgment takes.

## Decision

Title-only flat grep over **5 destination types, 6 corpora**. Project-scoped ADRs add a conditional sixth row, present only when a current project is in scope.

| Destination | Scan target | Extraction |
|---|---|---|
| `feedback_memory` | Memory index | One-liner entries |
| `skill` | Agent-skills library files | Frontmatter `name:` + top-level `#` header |
| `adr` (workspace) | `adrs/G-*.md` | Filename slug + top-level `#` header |
| `adr` (project) — conditional | `<current-project>/decisions/P-*.md` | Filename slug + top-level `#` header |
| `about` | Architecture canon files | Filename + top-level `#` header |
| `research` | Research briefs | Filename + top-level `#` header |

**Scope list is held as a config array**, in the skill file or in adjacent config, not hardcoded inside the skill's logic. This keeps a later migration cheap. When the skill is absorbed into mnemra, the array gets replaced by mnemra's equivalent index map and the skill logic stays intact.

Overlap judgment is **LLM-driven**, on scope and topic. There's no acceptance-criteria test for it. Correctness is judged after the fact through the `skill_runs` retro, question 3. Worked examples in the skill body, per [G-0010](../adrs/G-0010.md), calibrate that judgment so it stays consistent across runs.

UPDATE diff is **field-level**, showing scope, example, and counter-case side by side. It's not a line diff.

## Alternatives Considered

- **Body scanning in v1** — deferred. The trigger to add it is retro-driven, not a guess made up front: expand the scan to the first 20 lines only if `skill_runs` shows two or more duplicate-misses inside a 10-run window. This isn't a decision to pre-commit.
- **Hardcoded path list** — rejected. The mnemra-absorbed posture this skill is built for favors an explicit config abstraction for anything coupled to a path, since those paths change on absorption.
- **Indexed search (tantivy, sqlite-fts)** — deferred. Title-only grep over the current corpus runs in under a second. The implementer's round-1 verification measured about 103 files. Revisit indexed search when the corpus passes roughly 1000 files, or when a single pass runs longer than 500ms.
- **Decision-tree overlap match (regex + rules)** — rejected. The discovery pass chose LLM judgment over a decision-tree lint on purpose.

## Consequences

- R17 runs in under a second at the current corpus size. No performance concern.
- Absorption into mnemra is a single config swap. The skill logic doesn't change.
- The body-scan trigger is a future retro-driven refinement, held open rather than pre-committed.
- Composition integrity holds: the human who carries the work approves an UPDATE before it's applied. The skill surfaces the diff and never writes on its own.
- The [spec](../glossary.md#spec) stage owns the remaining specifics. The exact CLI (`rg` vs `grep`), the extraction regexes, the config-array path, the JSON diff structure, and a cache strategy if one turns out to be needed.
