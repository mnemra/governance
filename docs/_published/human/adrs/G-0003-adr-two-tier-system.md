---
title: "G-0003: Two-Tier Architecture Decision Records"
summary: "Workspace ADRs (G-prefix) for general standards; project ADRs (P-prefix) for project-specific decisions; projection pattern for public-safe summaries."
primary-audience: agent
---

# G-0003: Two-Tier Architecture Decision Records

**Status:** Accepted
**Date:** 2026-04-05

## Context

Design decisions used to live wherever they happened to land: scattered notes, task descriptions, conversation history. That made them hard to find and easy to lose. Some of those decisions are general standards, things like a testing philosophy or a build pattern that hold across every project. Because nothing recorded them in one place, each new project rediscovered them from scratch.

There's a second pressure. Projects that ship to public repositories need decision records that stand on their own. A public record can't point back at internal workspace structure, and it can't assume a reader who already knows that structure.

## Decision

Architecture decision records split into two tiers. (The canon writes these as MADR documents: Markdown Any Decision Record, the lightweight template with Context, Decision, Alternatives Considered, and Consequences.)

1. **General standards** (`G-NNNN-<slug>.md`) — full ADRs with context, alternatives, and consequences. These carry the `G-` prefix, the [governance](../glossary.md#g-adr) marker for decisions that apply across the ecosystem rather than to one project. They are the canonical source of reasoning.
2. **Project projection** (`docs/src/adrs/DEFAULTS.md` or equivalent) — a one-time concise snapshot of general standards applied to the project. Contains only the decision statement (1-3 sentences), no rationale chain. Public-safe, self-contained, no references back to workspace-internal structure.
3. **Project-specific ADRs** (`docs/src/adrs/P-NNNN-<slug>.md`) — full ADRs for decisions scoped to one project. These carry the `P-` prefix in its ADR sense: a project-level decision record that lives in the project's own repo, not in the governance repo. They include full context and rationale, since those are meaningful to external readers.

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
