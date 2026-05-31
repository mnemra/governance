---
title: "G-0029: Publish-Time Human Render via Bidirectional Translation"
summary: "Agent-primary doc repos publish two surfaces (mdBook HTML for humans; llms.txt for agents) from one canonical source tree via EXPLAIN/STRIP translation passes run locally; committed build artifacts; hash-gated regeneration."
primary-audience: agent
---

# G-0029: Publish-Time Human Render via Bidirectional Translation

**Status:** Accepted
**Date:** 2026-05-20

## Context

Source artifacts written for agents first ([agent-primary source](../glossary.md#agent-primary-source), the convention G-0027 sets) are tuned for an agent reader: dense, named, heavily cross-referenced, and full of workspace-internal vocabulary. That vocabulary includes ADR codes like G-0027, principle shorthand like P-Defer (the principle that defers a mechanism choice until evidence forces it), requirement codes like R12, and lifecycle-tier names. It carries real meaning for an agent. To an outside human, it's opaque. The outside humans here are the contributors, integrators, and evaluators who land on a published docs site without any of that context.

G-0026 made mdBook the workspace docs stack and already ships rendered HTML to GitHub Pages. So a repo that follows both G-0026 and G-0027 publishes a human-readable surface, the mdBook HTML, whose underlying source was authored for agents. The two decisions leave a gap between them. Humans arrive on pages that were never written for them.

The usual fix is P-WriteTimeAudience (strip workspace-internal team names when the page is published). That removes the names but leaves the conceptual shorthand untouched. Resolving the shorthand needs a separate translation pass.

A second gap showed up at the same time. There's no agent-addressable docs surface (no `llms.txt` or `llms-full.txt`), so an agent querying the published docs has no structured way in. The same pipeline that builds the human surface can build the agent surface, both from the one canonical source.

Resolving those two gaps together is the mechanism this ADR records.

## Decision

Repos whose source is agent-primary publish two surfaces from one canonical source tree, using a translation pass at publish time that runs in both directions.

### 1. Single canonical source tree

`docs/src/` is the one place documents are authored. No parallel sibling trees. Every document (intent, ADRs, specs, guides, glossary) is written once: in agent-primary form where an agent is the natural reader, or in human-primary form where a human is. The source is the source of truth. Both published surfaces derive from it.

### 2. Two publication surfaces

| Surface | Location | Generated via |
|---------|----------|---------------|
| mdBook HTML (humans) | `_published/human/` → GitHub Pages | EXPLAIN-pass translations + mdBook build |
| llms.txt + llms-full.txt (agents) | `_published/agent/` + `_published/llms*.txt` | STRIP-pass translations + concatenation |

Both surfaces are generated locally and **committed to the repo**. CI stays dumb: it runs `mdbook build` against the committed `_published/human/` tree, copies the committed llms.txt and llms-full.txt into the build output, and deploys to gh-pages. No LLM calls happen in cloud CI.

### 3. Bidirectional translation at publish time

Each canonical page declares a `primary-audience` frontmatter field, either `agent` or `human`. The default comes from the directory: `intent/`, `adrs/`, and `specs/` default to `agent`; `guides/` and `intro.md` default to `human`.

There are two translation passes, invoked via the `/docs-translate` slash command [superseded — see Mechanism details (resolved 2026-05-21)]:

- **EXPLAIN pass** — agent-primary source to a human render. It resolves jargon, adds narrative, links glossary terms, and surfaces the context the source left implicit. Used for intent docs, ADRs, and specs.
- **STRIP pass** — human-primary source to an agent render. It removes pedagogical scaffolding, tightens the prose to facts and contracts, and adds explicit cross-references to ADRs and specs. Used for guides.

For each page, the side that matches its canonical audience is copied verbatim into the matching `_published/` subtree. Only the opposite-audience side needs a translation pass.

### 4. Translation runs locally, not in cloud CI

Translation is invoked through the `/docs-translate` slash command on the maintainer's local machine, using Claude Code subscription usage (the plan budget, not metered API spend). The translated outputs get committed. This is the API-budget constraint at work: any LLM call placed in cloud CI would draw API credits on every push.

### 5. Frontmatter `summary:` as llms.txt description source

Each canonical `.md` carries a `summary:` YAML frontmatter field. The llms.txt manifest is generated from the SUMMARY.md navigation structure plus these `summary:` values. When the translation pass generates the human-form page and the canonical source has no summary yet, the pass populates `summary:`.

### 6. Hash-gated translation regeneration via `.translation-manifest.json`

A `.translation-manifest.json` sidecar tracks the content hash of each canonical source page. `just docs-check` computes hashes for all `docs/src/**/*.md` and returns nonzero if any source has changed without a matching translation update. That nonzero is the enforcement signal for pre-push validation. Translation only runs for pages whose source hash differs from the manifest entry.

### 7. Canonical specs vs. implementation-history split

A docs tree holds two categories of "spec":

| Category | Role | mdBook nav |
|----------|------|------------|
| Canonical architecture specs | Living, locked frame+spec deliverables. Primary reading. | Included — front-and-center in SUMMARY.md |
| Implementation-history specs | Dated snapshots of completed setup/infra work. Audit trail. | Excluded from SUMMARY.md nav; on disk only |

Implementation-history specs live at `docs/src/history/` on disk so `llms-full.txt` picks them up, which gives the agent surface the full trail. SUMMARY.md leaves them out, so mdBook never renders them to HTML. Outside humans see only the primary content. Agents see everything.

### 8. Build factoring: hybrid scaffold-then-promote

The mechanism is built in the first repo to adopt it (mnemra-core). The workspace-canon slot is reserved now, by this ADR, with the mechanism details promoted up from a TBD placeholder. Once the mechanism settles in mnemra-core, it gets promoted in place into the workspace-shared tool (either a `scripts/` recipe or a `.claude/commands/docs-translate.md` slash command), with no relocation. Repos that adopt later get a thin justfile recipe that calls the workspace tool.

## Mechanism details (resolved 2026-05-21)

The translation pipeline's deterministic gating, its prompt and substitution mechanism, its manifest, and the agent (llms.txt) surface were built and proven in the first adopter, mnemra-core. The human (mdBook) surface *generates* correctly but is NOT yet wired into the published build. That wiring is tracked separately. The specifics below are promoted from the TBD placeholder into canon.

### Pipeline surfaces

Three surfaces work together:

- **`scripts/docs-translate.py`** — deterministic gating only, no LLM calls. It has modes `--plan`, `--finalize`, and `--check`, with `--src docs/src --out docs/_published --prompts docs/prompts`. It owns: source hashing, manifest IO, verbatim copies of canonical-audience and structural pages, orphan cleanup, and emitting the per-page translation plan (the assembled prompts) for the orchestrator to dispatch.
- **`scripts/docs-llms.py`** — generates `llms.txt` (the manifest) and `llms-full.txt` (the agent-tree concatenation in SUMMARY.md order). Its `--check` mode is the drift gate.
- **`/docs-translate` slash command** — the orchestration loop (see Dispatch contract).

### Recipes

- `just docs-check` → `docs-translate.py --check` plus `docs-llms.py --check` (the pre-push non-stale gate).
- `just docs-llms` → regenerate `llms.txt` and `llms-full.txt`.
- `just docs-serve` → `mdbook serve docs/`.

There's intentionally no `just docs-translate` recipe. Translation needs an in-session agent dispatch, and a justfile recipe can't perform one.

### Prompt files and substitution

The EXPLAIN-pass and STRIP-pass prompts live at `docs/prompts/explain-pass.md` and `docs/prompts/strip-pass.md`. The planner builds each page's prompt by substituting three tokens:

| Token | Substituted with |
|-------|------------------|
| `{{GLOSSARY}}` | full contents of `docs/src/glossary.md` (the EXPLAIN register) |
| `{{PAGE}}` | the canonical source page body + frontmatter |
| `{{NONCE}}` | a per-run random nonce delimiter (prompt-injection defense, LLM01) |

`validate_prompt` requires `{{NONCE}}` in every prompt template. A template that's missing it fails the planner. The nonce wraps untrusted page content so that any instructions injected inside a source page can't escape the data region.

### Manifest schema

`docs/_published/.translation-manifest.json`:

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

Hash gating keys on **both** `source_sha256` and `prompt_sha256`. A page retranslates when its source changes OR when its pass prompt changes.

### Structural (never-translated) pages

`SUMMARY.md` and `glossary.md` are structural. They're copied verbatim into BOTH `_published/human/` and `_published/agent/`, and they're excluded from the manifest and the plan items. (`glossary.md` is also the `{{GLOSSARY}}` injection source.)

### `_published/` layout (as built)

```
docs/_published/
  human/                      # EXPLAIN-translated + verbatim human-canonical pages (mdBook source)
  agent/                      # STRIP-translated + verbatim agent-canonical pages
  llms.txt                    # generated manifest (Jeremy Howard format)
  llms-full.txt               # agent/ concatenation in SUMMARY.md order
  .translation-manifest.json  # source + prompt content hashes
```

### Dispatch contract (`/docs-translate`)

Translation needs an in-session LLM call, so the loop is an orchestrator-driven slash command rather than a justfile recipe:

1. **Plan** — `docs-translate.py --plan` emits JSON `items[]`, each carrying `source_path`, `output_path`, and an `assembled_prompt`. An empty `items` means nothing is stale, so stop.
2. **Dispatch** — for each item, the orchestrator dispatches a general-purpose sub-agent (`mode: default`, no Write/Edit/Bash) whose only job is to return the translated Markdown as its final message. The parent session writes each result to `output_path`. Parallelism is mandatory: sub-agents dispatch in batches of 4 in a single message. An empty or preamble response retries once with a "return only Markdown" prefix; a second failure aborts before finalize.
3. **Finalize** — `docs-translate.py --finalize` updates the manifest after all outputs are on disk. A non-zero exit (a missing output) aborts without writing a partial manifest.

### Operational notes (orchestrator-side — policy, not pipeline mechanism)

The pipeline itself is model-agnostic. What follows is orchestration policy applied at dispatch time:

- EXPLAIN-pass renders (the human-facing prose) default to the Opus tier, per the human-prose-output standard. The STRIP pass (the agent form) can use a cheaper tier.

### CI shape

CI stays dumb, with no LLM calls. It runs `mdbook build docs/`, copies the committed `llms.txt` and `llms-full.txt` into the build output (`docs/book/`), and deploys that tree to the `gh-pages` branch.

**Current-state caveat (2026-05-21):** `book.toml` sets `src = "src"`, so mdBook builds the canonical `docs/src/` tree, NOT `_published/human/`. The human surface is therefore not yet wired to the EXPLAIN translations. The §2 design-intent wiring is pending. The agent surface (`docs-llms.py`, default `--src docs/_published/agent`) IS wired to the STRIP translations.

## Scope

This is a workspace-shared pattern. **First adopter: mnemra-core.** It applies to any workspace repo that publishes docs to outside humans where the canonical source is agent-first. Downstream adopters aren't enumerated here. The trigger is "publishing to outside humans from an agent-primary source," not membership in a fixed list.

The workspace tool location (the promotion target once the mechanism settles) is TBD at promotion time. Current candidates: `scripts/docs-translate`, `.claude/commands/docs-translate.md`.

## Alternatives Considered

**Workspace-shared tooling from day one.** Build the translation prompts and scripts in the workspace right away, before mnemra-core proves the pattern. Rejected: that's premature workspace plumbing, laid before the mechanism is validated in a real adopter.

**Per-repo-then-extract on second adopter.** Build the full mechanism in mnemra-core, and extract it only when a second repo needs it. Rejected: the maintainer named workspace scope explicitly at design time, which overrides the rule-of-three. Waiting for a second adopter would defer the promotion-path design.

**First-paragraph extraction as llms.txt description source.** Use each page's first paragraph after the H1 as its llms.txt description. Rejected: first paragraphs aren't always good one-liners, and the pattern produces inconsistent manifest quality.

**Accept non-deterministic translation.** Run translation on every invocation and accept the diff churn. Rejected: noisy diffs on unchanged source hurt PR review quality and erode trust in the committed translation artifacts.

## Consequences

**Positive:**

- Outside humans land on pages authored for them, and outside agents get a structured llms.txt entry point. Both gaps from the Context section close.
- One canonical source, so there's no dual-source drift. That's the failure mode G-0027 explicitly rejected in its "Dual-source" alternative.
- Translation cost stays bounded to local subscription usage. Cloud CI stays free of API spend.
- Hash gating produces stable, meaningful diffs. Translation commits line up with actual source changes.
- The glossary gives the EXPLAIN pass a shared register, which keeps it consistent across pages and over time.

**Negative / accepted:**

- The `_published/` tree is a committed build artifact, so PR diffs include translated content next to the source changes. Mitigation: the PR review convention focuses content review on `docs/src/`, and treats `_published/` changes as visual confirmation only.
- Translation quality depends on the EXPLAIN and STRIP prompts. A prompt change triggers a full retranslation (a one-off cost, bounded, and explicit in the PR diff).
- Future contributors have to run `just docs-check` before pushing doc changes. The failure-with-message handles first-violation cases. This is an acknowledged onboarding cost.
- Translation is gated on a local subscription. A repo maintainer without a Claude Code subscription can't regenerate translations. That's an accepted constraint.

**Downstream:**

- The mnemra-core docs restructure inherits directly from the spec layout and the frontmatter contract (`title`, `summary:`, `primary-audience`).
- When the mechanism settles in mnemra-core, a workspace-promotion task updates this ADR with the resolved workspace tool location.
- The glossary migrates to a structured form once the structured-delta tooling lands. At that point the EXPLAIN pass reads from the structured source.

## Changelog

- 2026-05-20 — Initial draft. Decision lineage recorded; mechanism details TBD pending first-adopter implementation.
- 2026-05-20 — Amendment: corrected "session codes" → "requirement codes" in Context section. R-codes are requirement identifiers from canonical requirements docs, not session-episode shorthand.
- 2026-05-21 — Amendment: "Mechanism details" promoted from TBD placeholder to resolved mechanism, following first-adopter (mnemra-core) implementation. Records the three pipeline surfaces, the recipe set, prompt files + `{{GLOSSARY}}`/`{{PAGE}}`/`{{NONCE}}` substitution (incl. the nonce injection defense), the manifest schema (source/prompt sha256 hash-gating), the structural-page both-sides-verbatim rule (`SUMMARY.md` + `glossary.md`), the `_published/` layout, and the `/docs-translate` dispatch contract. Resolves the proposal's `just docs-translate` recipe to a `/docs-translate` slash command (translation needs in-session Agent dispatch).
- 2026-05-21 — Correction: the same-day "Mechanism details" amendment overclaimed the human surface as built. In fact `book.toml` sets `src = "src"`, so CI builds `docs/src/` and the human EXPLAIN translations are not yet served (the agent/llms surface IS wired). Corrected the resolved-section intro and CI-shape subsection to current state; human-surface wiring tracked as a separate pending task.
