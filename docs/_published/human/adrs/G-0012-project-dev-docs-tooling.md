---
title: "G-0012: Project Dev Docs Use mdBook + D2 + Mermaid; Product Surfaces Unaffected"
summary: "Project-level developer documentation standardizes on mdBook for static sites, D2 for architecture-grade diagrams in built docs, and Mermaid for diagrams read in the GitHub web UI; product-level marketing surfaces are out of scope."
primary-audience: agent
---

# G-0012: Project Dev Docs Use mdBook + D2 + Mermaid; Product Surfaces Unaffected

**Status:** Accepted
**Date:** 2026-05-04

## Context

Mermaid `C4Container` and `classDef`-styled flowcharts hit reliability limits during system-overview drafting in the mnemra ecosystem: rendering was inconsistent across renderers, and dark mode required defensive overrides. A research survey of the 2026 state of project-level dev-docs tooling and diagramming informed the choice recorded here.

This ADR captures the ecosystem-wide choice. It applies to **project-level developer documentation**: ADRs, system overviews, architecture docs, READMEs, and design notes that live in project git repos and render to GitHub Pages or equivalent. It is distinct from product-level surfaces (e.g., the mnemra.dev marketing site), which run on different stacks and remain out of scope here.

## Decision

**Static-site generator:** mdBook (Apache-2.0 / MIT, rust-lang official). Each project repo gets its own `book.toml` + `SUMMARY.md`; CI deploys to GitHub Pages via `peaceiris/actions-mdbook` + `peaceiris/actions-gh-pages`.

**Diagrams: a tool pair by surface.**

- **D2** (MPL-2.0, text DSL) for architecture-grade diagrams in built docs sites. First-class C4 (the C4 model for visualizing software architecture) since v0.7, dark mode without `classDef` overrides, three layout engines (Dagre default, ELK, and the paid TALA).
- **Mermaid** (MIT, text DSL) for diagrams in committed `.md` read in the GitHub web UI. It is the only diagrams-as-code tool natively rendered by GitHub (since 2022). Use it for sequence, flow, and state-machine diagrams; avoid `C4Container` (experimental, brittle).

**Integration:** mdBook + a custom `mdbook-d2` preprocessor (a small Rust crate, tracked separately) + `mdbook-mermaid` for dual rendering. Reference pattern: TigerBeetle's mdBook custom preprocessors (`docs.tigerbeetle.com`).

**Agent-driven authoring:** install `i2y/d2mcp` (MIT, off-the-shelf, ten tools including the Oracle API for incremental edits). Mermaid skips MCP; direct file-write is lighter.

## Alternatives Considered

**mkdocs-material.** Best-in-class polish in 2026, but it entered maintenance mode in November 2025; critical bug fixes only until November 2026. Picking it commits to a forced migration on a known schedule. Defensible as a stopgap with an explicit migration budget; rejected as a long-term default.

**Zensical.** The official successor to mkdocs-material. Rust core with a Python frontend, MIT, `mkdocs.yml`-compatible, 4 to 5× faster builds via differential compilation. Beta as of May 2026; third-party module ecosystem opening in early 2026 with uncertain coverage. Rejected for now: beta-on-beta during a period of tooling consolidation is uncomfortable. Reconsider when stable; same-team continuity makes the future migration cheap.

**Docusaurus, Astro Starlight, VitePress.** TS/JS stacks. Rejected per the stack-alignment preference; none is decisively better for the docs use case to override that preference.

**Antora.** A multi-repo aggregation specialist (native cross-repo, branch/tag-aware versioning). Best-in-class for that specific need. Rejected unless multi-repo aggregation becomes a hard requirement; its cost is AsciiDoc and a JS-built toolchain. Per-repo mdBook plus a top-level link-out is sufficient at current scale.

**Hugo, Zola.** Hugo (Go) and Zola (Rust, single binary) are solid generators, but less docs-specialized than mkdocs-material was. Rejected: mdBook is more docs-focused and is rust-lang's official tool.

**Diagram alternatives.** Structurizr-DSL (the C4 reference implementation, model-first) was the runner-up; rejected at current scale because model-first overhead does not earn its keep at one to three architecture diagrams. Migration trigger: the second time a component is named differently across two diagrams. PlantUML rejected: GPL-3.0 is RED-tier under the dependency policy. Excalidraw rejected (opaque JSON diffs). draw.io rejected (a GUI dependency conflicts with the CLI-first stack and agent-driven authoring).

## Consequences

**Positive:**

- Stack-aligned (Rust toolchain throughout: mdBook, the D2 CLI, and the future preprocessor crate).
- No EOL on the chosen tools; active upstream maintenance, and official rust-lang status for mdBook.
- Diagrams render cleanly in dark mode without per-renderer theme overrides.
- D2-by-surface is honest about both targets: ADRs viewed in GitHub get diagrams natively via Mermaid; built docs sites get architecture-grade visuals via D2.
- MCP-server access for D2 (`i2y/d2mcp`) supports agent-driven authoring with no wrap effort.
- A production exemplar (TigerBeetle's custom mdBook preprocessors) gives a known-good reference for the approach.

**Negative / accepted:**

- mdBook's D2-preprocessor ecosystem is thin in May 2026. Bounded mitigation: a roughly 200-to-400-line Rust wrapper crate, tracked separately. A side quest, not blocking on the first ADR drafts.
- Multi-repo docs aggregation is not native. Per-repo sites plus a top-level link-out is the current answer; revisit if Antora becomes a hard requirement.
- mkdocs-material familiarity does not carry; mdBook's idiom (`book.toml` + `SUMMARY.md`) is a small but real learning curve.
- Existing native-themed Mermaid diagrams in committed `.md` carry forward unchanged. Architecture-grade ones migrate to D2 once a docs site stands up.

**Project-level guidance:**

- Each project repo gets its own mdBook; ADRs follow the two-tier P-/G- shape (cf. G-0001).
- The `mdbook-d2` preprocessor crate, once written, lives in a shared location to avoid duplication across project repos.
- A project may stay on a different generator if deliverable timing or product context warrants. Out of scope: product-level surfaces (e.g., mnemra.dev), which run on their own stack.
