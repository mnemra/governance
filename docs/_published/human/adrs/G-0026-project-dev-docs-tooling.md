---
title: "G-0026: Project Dev Docs Use mdBook + D2 + Mermaid; Product Surfaces Unaffected"
summary: "mdBook for project-level developer documentation; D2 for architecture-grade diagrams in built doc sites; Mermaid for GitHub-native diagram rendering in committed .md files."
primary-audience: agent
---

# G-0026: Project Dev Docs Use mdBook + D2 + Mermaid; Product Surfaces Unaffected

**Status:** Accepted
**Date:** 2026-05-04

## Context

Mermaid's `C4Container` and `classDef`-styled flowcharts ran into reliability limits while someone was drafting a system overview. Rendering came out inconsistent across renderers. Dark mode needed defensive overrides to look right. A survey of where project-level dev-docs tooling and diagramming stood in 2026 fed into this decision.

This decision record captures the choice for the whole workspace. It applies to **project-level developer documentation**: ADRs, system overviews, architecture docs, READMEs, and design notes that live in project git repos and render to GitHub Pages or an equivalent. It's separate from product-level surfaces such as a marketing site, which run on different stacks and stay out of scope here.

## Decision

**Static-site generator:** mdBook (Apache-2.0 / MIT, rust-lang official). Each project repo gets its own `book.toml` + `SUMMARY.md`; CI deploys to GitHub Pages via `peaceiris/actions-mdbook` + `peaceiris/actions-gh-pages`.

**Diagrams: tool pair by surface.**

- **D2** (MPL-2.0, text DSL) for architecture-grade diagrams in built docs sites. First-class C4 since v0.7, dark mode without `classDef` overrides, three layout engines (Dagre default, ELK, paid TALA).
- **Mermaid** (MIT, text DSL) for diagrams in committed `.md` read in the GitHub web UI. Only diagrams-as-code tool natively rendered by GitHub since 2022. Use for sequence / flow / state-machine; avoid `C4Container` (experimental, brittle).

**Integration:** mdBook + a custom `mdbook-d2` preprocessor (small Rust crate, tracked separately) + `mdbook-mermaid` for dual rendering. Reference pattern: TigerBeetle's mdBook custom preprocessors (`docs.tigerbeetle.com`).

**Claude-driven authoring:** install `i2y/d2mcp` (MIT, off-the-shelf, 10 tools including the Oracle API for incremental edits). Mermaid skips MCP. A direct file-write is lighter.

## Alternatives Considered

**mkdocs-material.** Best-in-class polish in 2026, but it entered maintenance mode in November 2025, with critical bug fixes only through November 2026. Picking it commits the workspace to a forced migration on a known schedule. It's defensible as a stopgap if you budget the migration up front. Rejected as a long-term default.

**Zensical.** The official squidfunk successor to mkdocs-material. Rust core with a Python frontend, MIT, mkdocs.yml-compatible, and 4x to 5x faster builds through differential compilation. It's in beta as of May 2026, and its third-party module ecosystem is opening in early 2026 with uncertain coverage. Rejected for now. Running a beta tool on top of a beta ecosystem during the workspace-to-mnemra migration is uncomfortable. Reconsider once it's stable.

**Docusaurus, Astro Starlight, VitePress.** TS/JS stacks. Rejected per the workspace preference to stay on one stack; none is decisively better for the docs use case in a way that would override that preference.

**Antora.** A multi-repo aggregation specialist with native cross-repo support and branch/tag-aware versioning. Best-in-class for that specific need. Rejected unless multi-repo aggregation becomes a hard requirement. The cost is AsciiDoc and a JS-built toolchain. Per-repo mdBook plus a workspace-level link-out is enough at the current scale.

**Hugo, Zola.** Hugo is in Go; Zola is Rust as a single binary. Both are solid generators, but less docs-specialized than mkdocs-material was. Rejected because mdBook is more docs-focused and is rust-lang's official tool.

**Diagram alternatives.** Structurizr-DSL (the C4 reference implementation, model-first) was the runner-up. Rejected at the current scale because the model-first overhead doesn't earn its keep across one to three architecture diagrams. The trigger to migrate: the second time a component is named differently across two diagrams. PlantUML is rejected because GPL-3.0 is RED-tier under the workspace dependency policy, the tier the policy forbids by license. Excalidraw is rejected for its opaque JSON diffs. draw.io is rejected because its GUI dependency conflicts with the CLI-first stack and with Claude-driven authoring.

## Consequences

**Positive:**

- Stack-aligned (Rust toolchain throughout: mdBook, D2 CLI, the future preprocessor crate).
- No EOL on chosen tools; active upstream maintenance, official rust-lang status for mdBook.
- Diagrams render cleanly in dark mode without per-renderer theme overrides.
- D2-by-surface is honest about both targets: ADRs viewed in GitHub get diagrams natively via Mermaid; built docs sites get architecture-grade visuals via D2.
- MCP-server access for D2 (`i2y/d2mcp`) supports Claude-driven authoring with no wrap effort.
- Production exemplar (TigerBeetle's custom mdBook preprocessors) gives a known-good reference for the approach.

**Negative / accepted:**

- mdBook's D2-preprocessor ecosystem is thin in May 2026. Bounded mitigation: a Rust wrapper crate of roughly 200 to 400 lines. Side quest, not blocking on the first ADR drafts.
- Multi-repo docs aggregation is not native. Per-repo sites plus workspace-level link-out is the current answer; revisit if Antora becomes a hard requirement.
- mkdocs-material familiarity does not carry; mdBook's idiom (`book.toml` + `SUMMARY.md`) is a small but real learning curve.
- Existing native-themed Mermaid diagrams in committed `.md` carry forward unchanged. Architecture-grade ones migrate to D2 once a docs site stands up.

**Project-level guidance:**

- Each project repo gets its own mdBook; ADRs follow the two-tier ADR shape, where `P-*` records hold project-level decisions and `G-*` records hold ecosystem-wide ones (cf G-0003).
- The `mdbook-d2` preprocessor crate, once written, lives in a workspace-shared location (mnemra-core workspace or a workspace-level home) to avoid duplication across project repos.
- A project may stay on a different generator if the deliverable timing or product context warrants. Out of scope: product-level surfaces (e.g., a marketing site) which run on their own stack.
