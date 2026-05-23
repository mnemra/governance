# mnemra-governance

Governance canon for the mnemra ecosystem.

This repository holds the agent-primary canon that describes how mnemra projects work:

- **Architecture Values** — the values that drive architectural decisions
- **Architecture Principles** — the principles derived from those values
- **Constraint Edges** — the hard boundaries those principles imply
- **G-\* ADRs** — workspace-level architecture decision records (project-level decisions live in their respective project repos under a `P-` prefix)

## Layout

- `docs/src/` — agent-primary Markdown source with YAML frontmatter
- `docs/_published/agent/` — agent-rendered output (verbatim copies of agent-primary sources, stripped translations of human-primary sources)
- `docs/_published/human/` — human-rendered output (mdBook reads from here)
- `docs/prompts/` — translation prompts driving the dual-audience publish pipeline
- `scripts/` — `docs-translate.py` (translation pipeline) and `docs-llms.py` (`llms.txt` / `llms-full.txt` generator)
- `justfile` — common recipes (`just docs`, `just docs-serve`, `just docs-check`, `just check`)

## Status

This is the scaffold. The actual canon migrates here in a follow-up dispatch.

## Visibility

The repository is currently **private**. It goes public after the `/brief` apparatus is completed end-to-end.

## Building locally

```sh
just docs        # build the mdBook site
just docs-serve  # serve locally with live reload
just check       # full drift gate (build + translate --check + llms --check)
```

Requires `mdbook`, `mdbook-mermaid`, `mdbook-d2`, the `d2` CLI, and `uv` on PATH.
