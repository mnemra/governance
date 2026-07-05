---
title: "G-0014: Publish-Time Human Render via Bidirectional Translation"
summary: "Agent-primary doc repos publish two surfaces (mdBook HTML for humans; llms.txt for agents) from one canonical source tree via EXPLAIN/STRIP translation passes run locally on subscription budget; outputs are committed build artifacts, hash-gated so regeneration tracks real source changes, and orchestrated by an in-session slash command rather than a CI recipe."
primary-audience: agent
---

# G-0014: Publish-Time Human Render via Bidirectional Translation

**Status:** Accepted
**Date:** 2026-05-20

## Context

Agent-first source artifacts (per `P-AgentPrimarySource`) are optimized for agent consumers: dense, named, cross-referenced, leveraging insider vocabulary (ADR codes, principle shorthand like `P-Defer`, requirement codes, lifecycle tier names). That vocabulary is load-bearing for agents but opaque to outside humans — contributors, integrators, and evaluators encountering a published docs site.

The project dev-docs tooling decision ([G-0012](G-0012-project-dev-docs-tooling.md)) established mdBook as the docs stack, already shipping rendered HTML to GitHub Pages. A repo following G-0012 + P-AgentPrimarySource therefore publishes a human-readable surface (mdBook HTML) whose source is agent-first prose — the two decisions create a gap: humans land on pages not authored for them. The standard publish-time discipline (`P-WriteTimeAudience`) strips insider team names but does not resolve conceptual shorthand; a separate translation pass is required.

A second gap surfaced alongside: no agent-addressable docs surface (`llms.txt` / `llms-full.txt`) exists, so agents querying published docs have no structured entry point. The same pipeline that generates the human surface can generate the agent surface from the same canonical source.

These two gaps, resolved together, define the mechanism this ADR records.

## Decision

Agent-primary doc repos publish two surfaces from one canonical source tree, via a publish-time bidirectional translation pass.

### 1. Single canonical source tree

`docs/src/` is the canonical authoring location. No parallel sibling trees. Every document (intent, ADRs, specs, guides, glossary) is authored once — in agent-primary form where that is the natural audience, human-primary where it is not. The source is the source of truth; both publication surfaces are derivative.

### 2. Two publication surfaces

| Surface | Location | Generated via |
|---------|----------|---------------|
| mdBook HTML (humans) | `docs/_published/human/` → GitHub Pages | EXPLAIN-pass translations + mdBook build |
| llms.txt + llms-full.txt (agents) | `docs/_published/agent/` + `docs/_published/llms*.txt` | STRIP-pass translations + concatenation |

Both surfaces are generated locally and **committed to the repo**. CI is dumb: it runs `mdbook build docs/`, copies the committed `llms.txt` / `llms-full.txt` into the build output (`docs/book/`), and deploys that tree to the `gh-pages` branch. No LLM calls in cloud CI. The llms files are therefore served at the Pages site root alongside the human HTML and remain committed in `docs/_published/`.

### 3. Bidirectional translation at publish time

Each canonical page declares a `primary-audience` frontmatter field (`agent` or `human`). Default by directory: `intent/`, `adrs/`, `specs/` → `agent`; `guides/`, `intro.md` → `human`.

Two translation passes, orchestrated by a `docs-translate` slash command (see §9 for why a slash command rather than a recipe):

- **EXPLAIN pass** — agent-primary source → human render: resolve jargon, add narrative, link glossary terms, surface implicit context. Used for intent docs, ADRs, specs.
- **STRIP pass** — human-primary source → agent render: remove pedagogical scaffolding, tighten to facts and contracts, add explicit cross-references to ADRs and specs. Used for guides.

Each page's canonical-audience side is copied verbatim into the matching `_published/` subtree. Only the opposite-audience side requires a translation pass. The passes are not symmetrical rewrites; they are directed transformations. EXPLAIN resolves insider vocabulary for readers who do not share the agent's context; STRIP removes instructional scaffolding that wastes an agent's token budget. The glossary is the load-bearing register for EXPLAIN — it anchors what terms mean so the pass produces consistent translations rather than invented paraphrases.

### 4. Translation runs locally, not in cloud CI

Translation is invoked on the maintainer's local machine using a subscription budget (plan budget, not API spend); translated outputs are committed. This is the API-budget constraint in force: any LLM call in cloud CI would draw API credits on every push. The tradeoff — committed build artifacts in the diff — is explicitly accepted.

### 5. Frontmatter `summary:` as llms.txt description source

Each canonical `.md` carries a `summary:` YAML frontmatter field. The `llms.txt` manifest is generated from `SUMMARY.md` navigation structure + these `summary:` values. The translation pass populates `summary:` when generating the human-form page if the canonical source does not already have one — the agent-canonical summary feeds both the translated page and the `llms.txt` manifest.

### 6. Hash-gated translation regeneration

LLM translation is non-deterministic; without a gate, every translation run would re-generate all pages and produce diff churn even when no source changed. A `.translation-manifest.json` sidecar tracks the content hash of each canonical source page (and of each pass prompt). A translation pass runs only for pages whose source hash OR prompt hash differs from the manifest entry; unchanged pages are copied from the existing `_published/` tree. A `docs-check` mode computes hashes for all `docs/src/**/*.md` and returns nonzero if any source has changed without a corresponding translation update — the enforcement signal for pre-push validation.

### 7. Canonical specs vs. implementation-history split

| Category | Role | mdBook nav |
|----------|------|------------|
| Canonical architecture specs | Living, locked frame+spec deliverables. Primary reading. | Included — front-and-center in SUMMARY.md |
| Implementation-history specs | Dated snapshots of completed setup/infra work. Audit trail. | Excluded from SUMMARY.md nav; on disk only |

Implementation-history specs live at `docs/src/history/` on disk so `llms-full.txt` picks them up (the agent surface gets the full trail), but `SUMMARY.md` does not include them — mdBook does not render them to HTML. Outside humans see only primary content; agents see everything.

### 8. Pipeline surfaces (the resolved mechanism)

Three collaborating surfaces:

- **`scripts/docs-translate.py`** — deterministic gating only, no LLM calls. Modes `--plan` / `--finalize` / `--check`, with `--src docs/src --out docs/_published --prompts docs/prompts`. Owns: source hashing, manifest IO, verbatim copies of canonical-audience and structural pages, orphan cleanup, and emitting the per-page translation plan (assembled prompts) for the orchestrator to dispatch.
- **`scripts/docs-llms.py`** — generates `llms.txt` (a manifest, Jeremy Howard format) and `llms-full.txt` (an agent-tree concatenation in SUMMARY.md order); `--check` is the drift gate.
- **The `docs-translate` slash command** — the orchestration loop (the in-session LLM-dispatch step; see §9).

**Recipes (deterministic, no-LLM — these remain justfile recipes):**

- `just docs-check` → `docs-translate.py --check` + `docs-llms.py --check` (the pre-push non-stale gate).
- `just docs-llms` → regenerate `llms.txt` / `llms-full.txt`.
- `just docs-serve` → `mdbook serve docs/`.

**Prompt files and substitution.** EXPLAIN-pass and STRIP-pass prompts live at `docs/prompts/explain-pass.md` and `docs/prompts/strip-pass.md`. The planner assembles each page's prompt by substituting three tokens:

| Token | Substituted with |
|-------|------------------|
| `{{GLOSSARY}}` | full contents of `docs/src/glossary.md` (the EXPLAIN register) |
| `{{PAGE}}` | the canonical source page body + frontmatter |
| `{{NONCE}}` | a per-run random nonce delimiter (prompt-injection defense, LLM01) |

`validate_prompt` requires `{{NONCE}}` in every prompt template; a template missing it fails the planner. The nonce wraps untrusted page content so instructions injected inside a source page cannot escape the data region.

**Manifest schema** (`docs/_published/.translation-manifest.json`):

```json
{
  "schema_version": 1,
  "entries": {
    "<rel-path under docs/src>": {
      "primary_audience": "agent" | "human",
      "prompt_path": "explain-pass.md" | "strip-pass.md",
      "prompt_sha256": "<hex>",
      "source_sha256": "<hex>",
      "translated_at": "<ISO-8601 UTC>"
    }
  }
}
```

Hash gating keys on **both** `source_sha256` and `prompt_sha256`: a page retranslates when its source changes OR when its pass prompt changes.

**Structural (never-translated) pages.** `SUMMARY.md` and `glossary.md` are structural: copied verbatim to BOTH `_published/human/` and `_published/agent/`, and excluded from the manifest and plan items. (`glossary.md` is additionally the `{{GLOSSARY}}` injection source.)

**`_published/` layout (as built):**

```
docs/_published/
  human/                      # EXPLAIN-translated + verbatim human-canonical pages (mdBook source)
  agent/                      # STRIP-translated + verbatim agent-canonical pages
  llms.txt                    # generated manifest (Jeremy Howard format)
  llms-full.txt               # agent/ concatenation in SUMMARY.md order
  .translation-manifest.json  # source + prompt content hashes
```

### 9. Why a slash command, not a recipe — the dispatch contract

Translation requires an in-session LLM call, which a justfile recipe cannot perform; the orchestration loop is therefore a slash command. The deterministic, no-LLM portions (`--check`, manifest IO, verbatim copies) remain script/recipe-invoked (§8). The loop:

1. **Plan** — `docs-translate.py --plan` emits JSON `items[]`, each with `source_path`, `output_path`, and an `assembled_prompt`. Empty `items` → nothing stale, stop.
2. **Dispatch** — for each item, the orchestrator dispatches a general-purpose sub-agent (default mode, no Write/Edit/Bash) whose sole job is to return the translated Markdown as its final message; the parent session writes each result to `output_path`. Parallelism is mandatory — sub-agents dispatch in batches of four in a single message. An empty/preamble response retries once with a "return only Markdown" prefix; a second failure aborts before finalize.
3. **Finalize** — `docs-translate.py --finalize` updates the manifest after all outputs are on disk; a non-zero (missing output) aborts without a partial manifest write.

**Operational note (orchestrator-side policy, not pipeline mechanism).** The pipeline is model-agnostic (the slash command pins the default sub-agent mode and selects no model). EXPLAIN-pass renders (human-facing prose) default to the strategy tier per the human-prose-output standard — in early runs, cheaper sub-agents narrated preamble before the document on a majority of EXPLAIN pages, while the strategy tier produced clean first-pass renders. STRIP-pass (agent form) can use a cheaper tier.

### 10. Build factoring: scaffold-then-promote

The mechanism builds in the first adopting repo; the shared-canon slot is reserved by this ADR. Once the mechanism stabilizes there, it is promoted in-place into a shared tool (a shared script recipe or slash-command definition) without relocation. Adopter repos get a thin justfile recipe that invokes the shared tool. The shared tool location is decided at promotion time.

## Drivers / Rationale

- **Agent-first, but humans still read docs.** P-AgentPrimarySource optimizes source for agent consumers; this decision closes the resulting gap at the only point that does not violate the principle — the publish surface, not the source. Translating the source would introduce two sources; refusing to translate would leave human readers with unreadable prose.
- **EXPLAIN/STRIP framing.** The passes are directed transformations, not symmetrical rewrites. The glossary is the load-bearing register for EXPLAIN — it anchors term meanings so the pass produces consistent translations rather than invented paraphrases.
- **Local translation, not CI.** API spend in cloud CI would run on every push, unbounded. Local subscription translation + committed outputs caps the cost: one translation event per source change, at the maintainer's workstation, result stored in the repo. The committed-build-artifact tradeoff is explicitly accepted.
- **Hash-gated regeneration.** The manifest bounds regeneration to actual source (or prompt) deltas, so translation commits correlate with real changes and PR diffs stay meaningful.
- **Ecosystem-scoped by declaration.** `P-PerRepoFirst` ordinarily defers extraction until a second adopter materializes. The maintainer explicitly declared this pattern ecosystem-scoped at design time, overriding the rule-of-three. The ADR is drafted before the mechanism is fully built — the first adopter is the proving ground; the slot is reserved to make the promotion path clean, not to impose premature shared tooling.

## Current-state caveat

The deterministic gating, prompt/substitution mechanism, manifest, and agent (`llms.txt`) surface were built and proven in the first adopter. The **agent surface IS wired** (`docs-llms.py`, default `--src docs/_published/agent`, reads the STRIP translations). The **human (mdBook) surface generates correctly but is NOT yet wired into the published build**: `book.toml` sets `src = "src"`, so mdBook builds the canonical `docs/src/` tree, not `_published/human/`. Wiring the human surface to the EXPLAIN translations (and stripping YAML frontmatter so it stops rendering as page text) is tracked as a separate task. This caveat records state at the time of writing and is not asserted resolved.

## Alternatives Considered

**Shared tooling from day one.** Build translation prompts and scripts as a shared tool immediately, before the first adopter proves the pattern. Rejected: premature plumbing before the mechanism is validated in a real adopter; the build cost is unjustified until the shape is known.

**Per-repo-then-extract on a second adopter.** Build the full mechanism in the first adopter; extract only when a second repo needs it. Rejected: the maintainer explicitly named ecosystem scope at design time, overriding the rule-of-three. Waiting for a second adopter ignores a known signal and defers the promotion-path design.

**First-paragraph extraction as the `llms.txt` description source.** Use each page's first paragraph after the H1 as the description. Rejected: first paragraphs are not always good one-liners; the pattern produces inconsistent manifest quality and cannot be reliably auto-populated by the translation pass.

**Accept non-deterministic translation.** Run translation on every invocation, accepting diff churn. Rejected: noisy diffs on unchanged source impede PR review quality (reviewers cannot distinguish content changes from translation re-rolls) and erode trust in the committed translation artifacts.

## Scope

An ecosystem-shared pattern. The pattern applies to any repo that publishes docs to outside humans where the canonical source is agent-first. The trigger is "publishing to outside humans from an agent-primary source," not membership in a fixed list; downstream adopters are not enumerated here.

## Consequences

**Positive:**

- Outside humans land on pages authored for them; outside agents have a structured `llms.txt` entry point. Both Context-section gaps are closed.
- A single canonical source; no dual-source drift (the failure mode P-AgentPrimarySource's "dual-source" alternative explicitly rejected).
- Translation cost is bounded to local subscription usage; cloud CI remains API-spend-free.
- Hash gating produces stable, meaningful diffs — translation commits correlate with actual source changes.
- The glossary provides a shared register for EXPLAIN-pass consistency across pages and over time.

**Negative / accepted:**

- `_published/` is a committed build artifact. PR diffs include translated content alongside source changes. Mitigation: the PR review convention focuses on `docs/src/` for content review; `_published/` changes are visual confirmation only.
- Translation quality depends on the EXPLAIN/STRIP prompts. A prompt change at `docs/prompts/` triggers a full retranslation (a one-off, bounded, explicit-in-the-diff cost).
- Future contributors must run the translation step before pushing doc changes. The `just docs-check` failure-with-message handles first-violation cases; this is an acknowledged onboarding cost.
- Translation is local-subscription-gated. A repo maintainer without a subscription cannot regenerate translations. Accepted; it matches the current tooling profile.

**Downstream:**

- A docs restructure inherits directly from the spec layout (§7) and the frontmatter contract (`title`, `summary:`, `primary-audience`).
- When the mechanism stabilizes in the first adopter, a promotion task updates this ADR with the resolved shared-tool location (§10).
- The glossary migrates to a structured form when the structured-delta tooling lands; the EXPLAIN pass will read from the structured source at that point. This ADR accommodates that migration without requiring a revision.
- Human-surface wiring plus the frontmatter strip is tracked as a separate task (see Current-state caveat).
