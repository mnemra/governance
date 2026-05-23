---
title: mnemra-governance
summary: "Governance canon for the mnemra ecosystem. Canon migration pending; this is the scaffold."
primary-audience: human
---

# mnemra-governance

Governance for the mnemra ecosystem. This repo holds the agent-primary canon that describes how mnemra projects work: architecture values, architecture principles, constraint edges, and the G-* series of architecture decision records.

Canon migration is pending. This scaffold is the foundation on which that migration lands.

## About this site

This documentation is built with [mdBook](https://rust-lang.github.io/mdBook/) and published through a dual-audience pipeline:

- **Agent-primary sources** live in `docs/src/` (Markdown with YAML frontmatter)
- **Human-rendered output** is built into `docs/_published/human/` and rendered by mdBook
- **Agent-rendered output** is built into `docs/_published/agent/` and used to generate `llms.txt` / `llms-full.txt`

The publish mechanism is documented at `scripts/docs-translate.py` and `scripts/docs-llms.py`.

## Repository

Source code lives at: [https://github.com/mnemra/governance](https://github.com/mnemra/governance).
