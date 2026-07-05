---
title: mnemra-governance
summary: "Governance canon for the mnemra ecosystem: architecture values, principles, constraint edges, and the G-series of architecture decision records."
primary-audience: human
---

# mnemra-governance

This repo holds the governance canon for the mnemra ecosystem. The canon is the standing description of how mnemra projects are built: what the architecture must be, how decisions get made, and which decisions have already been made and why. Agents and people both read it. When a rule is invoked during design or review, the prose here is what carries the meaning.

## What the canon is

The canon is four kinds of document, ordered from belief to mechanism.

- **Architecture values** are the beliefs that shape every architecture decision. Eight core values plus a set of supporting method values. Start here to understand what the ecosystem weighs and why.
- **Architecture principles** turn those values into named rules. Each principle carries a `P-` label and traces back to the values it serves.
- **Constraint edges** declare the relationships between values, principles, and decision records: which principle specializes which value, which decision refines which principle, where two values trade off. It's the graph view over the rest of the canon.
- **Architecture decision records** capture specific decisions. The `G-` series records ecosystem-wide governance decisions in MADR form. Each one states its context, the decision, the alternatives that were rejected and why, and the consequences.

The [glossary](glossary.md) defines the terms and conventions used throughout, including the role labels and the `G-`-versus-`P-` prefix convention.

## How the canon is written and published

The source documents are agent-primary. They're authored for an agent reader as the first consumer, with the human-facing site generated from the same sources rather than maintained separately. Every page declares a `primary-audience` value in its frontmatter so the publish pipeline knows how to treat it.

Publishing is dual-audience. The sources under `docs/src/` render two ways:

- a human-facing site, built with [mdBook](https://rust-lang.github.io/mdBook/), for reading in a browser;
- an agent-facing set used to generate `llms.txt` and `llms-full.txt`, for loading into an agent's context.

The render mechanism and the reasoning behind it are recorded in [G-0014](adrs/G-0014-publish-time-human-render.md). The agent-primary stance itself is the `P-AgentPrimarySource` principle in the [architecture principles](architecture-principles.md).

## Repository

Source lives at [https://github.com/mnemra/governance](https://github.com/mnemra/governance).
