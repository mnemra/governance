---
title: "G-0003: Two-Tier Architecture Decision Records"
summary: "Workspace ADRs (G-prefix) for general standards; project ADRs (P-prefix) for project-specific decisions; projection pattern for public-safe summaries."
primary-audience: agent
---

# G-0003: Two-Tier Architecture Decision Records

**Status:** Accepted
**Date:** 2026-04-05

## Context

Design decisions were scattered across various notes, task descriptions, and conversation history. General standards (testing philosophy, build patterns) apply across projects but were being rediscovered per-project. Projects going to public repositories need self-contained decision records that don't reference internal workspace structure.

## Decision

Two tiers of ADRs:

1. **General standards** (`G-NNNN-<slug>.md`) — full ADRs with context, alternatives, and consequences. These are the canonical source of reasoning.
2. **Project projection** (`docs/src/adrs/DEFAULTS.md` or equivalent) — a one-time concise snapshot of general standards applied to the project. Contains only the decision statement (1-3 sentences), no rationale chain. Public-safe, self-contained, no references back to workspace-internal structure.
3. **Project-specific ADRs** (`docs/src/adrs/P-NNNN-<slug>.md`) — full ADRs for decisions scoped to one project. Include full context and rationale since they're meaningful to external readers.

Key rules:
- DEFAULTS.md is a snapshot. Once projected, it belongs to the project. General ADR updates don't auto-sync.
- Overrides are explicit. A project-specific ADR states "Overrides G-NNNN" in its status field.

## Alternatives Considered

- **Symlinks from project to general ADR location**: Rejected because symlinks break across git clones and agents may not follow them. Not self-contained.
- **Full ADR copies in every project**: Rejected because it duplicates rationale that's only relevant internally, and creates sync overhead across projects.
- **Reference file pointing back to workspace-internal location**: Rejected because projects need to be self-contained for public repositories. External references leak internal structure.

## Consequences

- General decisions are recorded once, with full reasoning, in a single location.
- Projects get concise, self-contained summaries that work on public repositories without exposing internal workspace.
- Projection is a one-time operation per project — no ongoing sync maintenance.
- Project-specific overrides are visible and traceable.
