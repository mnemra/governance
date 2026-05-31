---
title: mnemra-governance
summary: "Governance canon for the mnemra ecosystem: architecture values, principles, constraint edges, and the G-series of architecture decision records."
primary-audience: human
---

# mnemra-governance

Governance canon for the mnemra ecosystem. The canon is the standing description of how mnemra projects are built: the required architecture, how decisions are made, and which decisions are already made and why. Read by agents and people. When a rule is invoked during design or review, the prose here carries the meaning.

## What the canon is

Four document kinds, ordered belief to mechanism.

- **Architecture values** — beliefs that shape every architecture decision. Eight core values plus supporting method values. Defines what the ecosystem weighs and why. Lives in `architecture-values.md`.
- **Architecture principles** — values operationalized as named rules. Each carries a `P-` label tracing back to the values it serves. Lives in `architecture-principles.md`.
- **Constraint edges** — typed relationships between values, principles, and decision records (specializes, depends-on, conflicts-with, refines): which principle specializes which value, which decision refines which principle, where two values trade off. Graph view over the rest of the canon. Lives in `constraint-edges.md`.
- **Architecture decision records** — specific decisions. The `G-` series records ecosystem-wide governance decisions in MADR form (Context, Decision, Alternatives Considered, Consequences).

The [glossary](glossary.md) defines terms and conventions, including role labels and the `G-`-versus-`P-` prefix convention.

## How the canon is written and published

Source documents are agent-primary: authored for an agent reader as first consumer, with the human-facing site generated from the same sources rather than maintained separately (per [G-0027](adrs/G-0027-agent-primary-source-artifacts.md)). Every page declares a `primary-audience` value in its frontmatter; the publish pipeline treats the page per that value.

Publishing is dual-audience. Sources under `docs/src/` render two ways:

- a human-facing site, built with [mdBook](https://rust-lang.github.io/mdBook/), for browser reading;
- an agent-facing set used to generate `llms.txt` and `llms-full.txt`, for loading into an agent's context.

Render mechanism and reasoning: [G-0029](adrs/G-0029-publish-time-human-render.md). Agent-primary stance: [G-0027](adrs/G-0027-agent-primary-source-artifacts.md).

## Repository

Source: [https://github.com/mnemra/governance](https://github.com/mnemra/governance).
