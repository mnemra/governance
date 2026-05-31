---
title: "G-0009: Knowledge-Extraction Skill — R17 Duplicate-Detection Scope"
summary: "Title-only flat grep over 5 destination types, 6 corpora; LLM-driven overlap judgment; field-level UPDATE diff; scope list held as config array for mnemra portability."
primary-audience: agent
---

# G-0009: Knowledge-Extraction Skill — R17 Duplicate-Detection Scope

**Status:** Accepted
**Date:** 2026-04-24

## Context

R17 scans existing destinations for scope-and-topic overlap before emitting a CREATE recommendation; overlap flips to UPDATE with field-level diff. /discover pre-committed to title-only flat grep over memory index one-liners, skill titles, and workspace ADR titles. /architect must resolve exact corpus, performance ceiling, body-scan trigger, and overlap-judgment shape.

## Decision

Title-only flat grep over **5 destination types, 6 corpora** (project-scoped ADRs add a conditional sixth row):

| Destination | Scan target | Extraction |
|---|---|---|
| `feedback_memory` | Memory index | One-liner entries |
| `skill` | Agent-skills library files | Frontmatter `name:` + top-level `#` header |
| `adr` (workspace) | `adrs/G-*.md` | Filename slug + top-level `#` header |
| `adr` (project) — conditional | `<current-project>/decisions/P-*.md` | Filename slug + top-level `#` header |
| `about` | Architecture canon files | Filename + top-level `#` header |
| `research` | Research briefs | Filename + top-level `#` header |

**Scope list is held as a config array** (in the skill file or adjacent config), not hardcoded in skill logic. Mnemra absorption replaces the array with mnemra's equivalent index map; skill logic stays intact.

Overlap judgment is **LLM-driven** (scope-and-topic). Correctness is retro-judged via `skill_runs` retro Q3, not AC-tested. Worked examples in the skill body (per G-0010) calibrate the judgment.

UPDATE diff is **field-level** (scope / example / counter-case side-by-side), not line-diff.

## Alternatives Considered

- **Body scanning in v1** — deferred. Retro-driven trigger: expand to first-20-lines only if `skill_runs` shows ≥2 duplicate-misses in a 10-run window. Not a pre-commit architectural decision.
- **Hardcoded path list** — rejected. F0 mnemra-absorbed posture favors explicit config abstraction for anything path-coupled.
- **Indexed search (tantivy, sqlite-fts)** — deferred. Title-only grep over current corpus (~103 files measured per implementing-developer round-1 verification) is sub-second. Revisit when corpus exceeds ~1000 files or single pass exceeds 500ms.
- **Decision-tree overlap match (regex + rules)** — rejected. /discover explicitly chose LLM judgment over decision-tree lint.

## Consequences

- Sub-second R17 pass at current corpus; no performance concern.
- Mnemra absorption is a single config swap; skill logic stays intact.
- Body-scan trigger is a future retro-driven refinement, not pre-committed.
- Composition integrity: carrier approves UPDATE before application; skill surfaces diff, never auto-writes.
- /spec owns exact CLI (rg vs grep), extraction regexes, config array path, JSON diff structure, cache strategy if needed.
