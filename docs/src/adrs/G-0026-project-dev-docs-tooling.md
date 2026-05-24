---
title: "G-0026: Project Dev Docs Use mdBook + D2 + Mermaid; Product Surfaces Unaffected"
summary: "mdBook for project-level developer documentation; D2 for architecture-grade diagrams in built doc sites; Mermaid for GitHub-native diagram rendering in committed .md files."
primary-audience: agent
---

# G-0026: Project Dev Docs Use mdBook + D2 + Mermaid; Product Surfaces Unaffected

**Status:** Accepted
**Date:** 2026-05-04

## Context

Mermaid `C4Container` and `classDef`-styled flowcharts hit reliability limits during a system overview drafting exercise: rendering inconsistent across renderers, dark-mode required defensive overrides. A survey of the 2026 state of project-level dev docs tooling and diagramming informed this decision.

This ADR captures the workspace-wide choice. It applies to **project-level developer documentation** — ADRs, system overviews, architecture docs, READMEs, design notes that live in project git repos and render to GitHub Pages or equivalent. It is distinct from product-level surfaces (e.g., a marketing site) which run on different stacks and remain out of scope here.

## Decision

**Static-site generator:** mdBook (Apache-2.0 / MIT, rust-lang official). Each project repo gets its own `book.toml` + `SUMMARY.md`; CI deploys to GitHub Pages via `peaceiris/actions-mdbook` + `peaceiris/actions-gh-pages`.

**Diagrams: tool pair by surface.**

- **D2** (MPL-2.0, text DSL) for architecture-grade diagrams in built docs sites. First-class C4 since v0.7, dark mode without `classDef` overrides, three layout engines (Dagre default, ELK, paid TALA).
- **Mermaid** (MIT, text DSL) for diagrams in committed `.md` read in the GitHub web UI. Only diagrams-as-code tool natively rendered by GitHub since 2022. Use for sequence / flow / state-machine; avoid `C4Container` (experimental, brittle).

**Integration:** mdBook + a custom `mdbook-d2` preprocessor (small Rust crate, tracked separately) + `mdbook-mermaid` for dual rendering. Reference pattern: TigerBeetle's mdBook custom preprocessors (`docs.tigerbeetle.com`).

**Claude-driven authoring:** install `i2y/d2mcp` (MIT, off-the-shelf, 10 tools including the Oracle API for incremental edits). Mermaid skips MCP — direct file-write is lighter.

## Alternatives Considered

**mkdocs-material.** Best-in-class polish in 2026 but entered maintenance mode November 2025; critical bug fixes only until November 2026. Picking it commits to a forced migration on a known schedule. Defensible as a stopgap with explicit migration budget; rejected as long-term default.

**Zensical.** Official squidfunk successor to mkdocs-material. Rust-core with Python frontend, MIT, mkdocs.yml-compatible, 4–5x faster builds via differential compilation. Currently beta as of May 2026; third-party module ecosystem opening early 2026 with coverage uncertain. Rejected for now: beta-on-beta during workspace→mnemra absorption is uncomfortable. Reconsider when stable.

**Docusaurus, Astro Starlight, VitePress.** TS/JS stacks. Rejected per workspace stack-alignment preference; none decisively better for the docs use case to override the preference.

**Antora.** Multi-repo aggregation specialist (native cross-repo, branch/tag-aware versioning). Best-in-class for that specific need. Rejected unless multi-repo aggregation becomes a hard requirement; cost is AsciiDoc and a JS-built toolchain. Per-repo mdBook + a workspace-level link-out is sufficient at current scale.

**Hugo, Zola.** Hugo (Go), Zola (Rust, single binary). Solid generators; less docs-specialized than mkdocs-material was. Rejected: mdBook is more docs-focused and is rust-lang's official tool.

**Diagram alternatives.** Structurizr-DSL (C4 reference impl, model-first) was the runner-up; rejected at current scale because model-first overhead doesn't earn its keep at 1–3 architecture diagrams. Migration trigger: the second time a component is named differently across two diagrams. PlantUML rejected — GPL-3.0 is RED-tier under the workspace dependency policy. Excalidraw rejected (opaque JSON diffs). draw.io rejected (GUI dependency conflicts with the CLI-first stack and Claude-driven authoring).

## Consequences

**Positive:**

- Stack-aligned (Rust toolchain throughout — mdBook, D2 CLI, the future preprocessor crate).
- No EOL on chosen tools; active upstream maintenance, official rust-lang status for mdBook.
- Diagrams render cleanly in dark mode without per-renderer theme overrides.
- D2-by-surface is honest about both targets: ADRs viewed in GitHub get diagrams natively via Mermaid; built docs sites get architecture-grade visuals via D2.
- MCP-server access for D2 (`i2y/d2mcp`) supports Claude-driven authoring with no wrap effort.
- Production exemplar (TigerBeetle's custom mdBook preprocessors) gives a known-good reference for the approach.

**Negative / accepted:**

- mdBook's D2-preprocessor ecosystem is thin in May 2026. Bounded mitigation: a ~200–400 LOC Rust wrapper crate. Side quest, not blocking on the first ADR drafts.
- Multi-repo docs aggregation is not native. Per-repo sites plus workspace-level link-out is the current answer; revisit if Antora becomes a hard requirement.
- mkdocs-material familiarity does not carry; mdBook's idiom (`book.toml` + `SUMMARY.md`) is a small but real learning curve.
- Existing native-themed Mermaid diagrams in committed `.md` carry forward unchanged. Architecture-grade ones migrate to D2 once a docs site stands up.

**Project-level guidance:**

- Each project repo gets its own mdBook; ADRs follow the two-tier P-*/G-* shape (cf G-0003).
- The `mdbook-d2` preprocessor crate, once written, lives in a workspace-shared location (mnemra-core workspace or a workspace-level home) to avoid duplication across project repos.
- A project may stay on a different generator if the deliverable timing or product context warrants. Out of scope: product-level surfaces (e.g., a marketing site) which run on their own stack.
