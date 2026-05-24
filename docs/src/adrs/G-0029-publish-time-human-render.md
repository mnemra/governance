---
title: "G-0029: Publish-Time Human Render via Bidirectional Translation"
summary: "Agent-primary doc repos publish two surfaces (mdBook HTML for humans; llms.txt for agents) from one canonical source tree via EXPLAIN/STRIP translation passes run locally; committed build artifacts; hash-gated regeneration."
primary-audience: agent
---

# G-0029: Publish-Time Human Render via Bidirectional Translation

**Status:** Accepted
**Date:** 2026-05-20

## Context

Agent-first source artifacts (per G-0027) are optimized for agent consumers: dense, named,
cross-referenced, leveraging workspace-internal vocabulary (ADR codes like G-0027, principle
shorthand like P-Defer, requirement codes like R12, lifecycle tier names). That vocabulary is
load-bearing for agents but opaque to outside humans — contributors, integrators, evaluators
encountering a published docs site.

G-0026 established mdBook as the workspace docs stack and already ships rendered HTML to
GitHub Pages. A repo following G-0026 + G-0027 therefore publishes a human-readable surface
(mdBook HTML) whose source is agent-first prose — the two decisions create a gap: humans land
on pages not authored for them.

The standard answer — P-WriteTimeAudience — strips workspace-internal team names at publish
time, but does not resolve conceptual shorthand. A separate translation pass is required.

A second gap surfaced alongside: no agent-addressable docs surface (llms.txt / llms-full.txt)
exists; agents querying published docs have no structured entry point. The same pipeline that
generates the human surface can generate the agent surface from the same canonical source.

These two gaps, resolved together, define the mechanism this ADR records.

## Decision

Agent-primary doc repos publish two surfaces from one canonical source tree, via a
publish-time bidirectional translation pass.

### 1. Single canonical source tree

`docs/src/` is the canonical authoring location. No parallel sibling trees. Every document
(intent, ADRs, specs, guides, glossary) is authored once, in agent-primary form where that is
the natural audience, or human-primary where it is not. The source is the source of truth;
both publication surfaces are derivative.

### 2. Two publication surfaces

| Surface | Location | Generated via |
|---------|----------|---------------|
| mdBook HTML (humans) | `_published/human/` → GitHub Pages | EXPLAIN-pass translations + mdBook build |
| llms.txt + llms-full.txt (agents) | `_published/agent/` + `_published/llms*.txt` | STRIP-pass translations + concatenation |

Both surfaces are generated locally and **committed to the repo**. CI is dumb: it runs
`mdbook build` against the committed `_published/human/` tree, copies the committed
llms.txt / llms-full.txt into the build output, and deploys to gh-pages. No LLM calls in
cloud CI.

### 3. Bidirectional translation at publish time

Each canonical page declares a `primary-audience` frontmatter field (`agent` or `human`).
Default by directory: `intent/`, `adrs/`, `specs/` → `agent`; `guides/`, `intro.md` → `human`.

Two translation passes, invoked via `/docs-translate` slash command [superseded — see Mechanism details (resolved 2026-05-21)]:

- **EXPLAIN pass** — agent-primary source → human render: resolve jargon, add narrative, link
  glossary terms, surface implicit context. Used for intent docs, ADRs, specs.
- **STRIP pass** — human-primary source → agent render: remove pedagogical scaffolding, tighten
  to facts and contracts, add explicit cross-references to ADRs and specs. Used for guides.

Each page's canonical-audience side is copied verbatim into the matching `_published/`
subtree. Only the opposite-audience side requires a translation pass.

### 4. Translation runs locally, not in cloud CI

Translation is invoked via the `/docs-translate` slash command on the maintainer's local machine
using Claude Code subscription usage (plan budget, not API spend). Translated outputs are
committed. This is the API-budget constraint in force: any LLM call in cloud CI would draw
API credits on every push.

### 5. Frontmatter `summary:` as llms.txt description source

Each canonical `.md` carries a `summary:` YAML frontmatter field. The llms.txt manifest is
generated from SUMMARY.md navigation structure + these `summary:` values. The translation
pass populates `summary:` when generating the human-form page if the canonical source does
not already have one.

### 6. Hash-gated translation regeneration via `.translation-manifest.json`

A `.translation-manifest.json` sidecar tracks the content hash of each canonical source page.
`just docs-check` computes hashes for all `docs/src/**/*.md` and returns nonzero
if any source has changed without a corresponding translation update — the enforcement
signal for pre-push validation. Translation only runs for pages whose source hash differs from
the manifest entry.

### 7. Canonical specs vs. implementation-history split

Two categories of "spec" exist in a docs tree:

| Category | Role | mdBook nav |
|----------|------|------------|
| Canonical architecture specs | Living, locked frame+spec deliverables. Primary reading. | Included — front-and-center in SUMMARY.md |
| Implementation-history specs | Dated snapshots of completed setup/infra work. Audit trail. | Excluded from SUMMARY.md nav; on disk only |

Implementation-history specs live at `docs/src/history/` on disk so `llms-full.txt`
picks them up (agent surface gets the full trail), but SUMMARY.md does not include them —
mdBook does not render them to HTML. Outside humans see only primary content; agents see
everything.

### 8. Build factoring: hybrid scaffold-then-promote

The mechanism builds in the first adopting repo (mnemra-core). The workspace-canon slot is
reserved now (this ADR) with mechanism details promoted from TBD. Once the mechanism
stabilizes in mnemra-core, it is promoted in-place into the workspace-shared tool
(a `scripts/` recipe or `.claude/commands/docs-translate.md` slash command) without
relocation. Adopter repos get a thin justfile recipe that invokes the workspace tool.

## Mechanism details (resolved 2026-05-21)

The translation pipeline's deterministic gating, prompt/substitution mechanism, manifest,
and agent (llms.txt) surface were built and proven in the first adopter (mnemra-core). The
human (mdBook) surface *generates* correctly but is NOT yet wired into the published build —
tracked separately; the specifics below are promoted from the TBD placeholder into canon.

### Pipeline surfaces

Three collaborating surfaces:

- **`scripts/docs-translate.py`** — deterministic gating only, no LLM calls. Modes
  `--plan` / `--finalize` / `--check`, with `--src docs/src --out docs/_published
  --prompts docs/prompts`. Owns: source hashing, manifest IO, verbatim copies of
  canonical-audience and structural pages, orphan cleanup, and emitting the per-page
  translation plan (assembled prompts) for the orchestrator to dispatch.
- **`scripts/docs-llms.py`** — generates `llms.txt` (manifest) and `llms-full.txt`
  (agent-tree concatenation in SUMMARY.md order); `--check` is the drift gate.
- **`/docs-translate` slash command** — the orchestration loop (see Dispatch contract).

### Recipes

- `just docs-check` → `docs-translate.py --check` + `docs-llms.py --check` (the pre-push
  non-stale gate).
- `just docs-llms` → regenerate `llms.txt` / `llms-full.txt`.
- `just docs-serve` → `mdbook serve docs/`.

(There is intentionally no `just docs-translate` recipe — translation requires in-session Agent dispatch that a justfile recipe cannot perform.)

### Prompt files and substitution

EXPLAIN-pass and STRIP-pass prompts live at `docs/prompts/explain-pass.md` and
`docs/prompts/strip-pass.md`. The planner assembles each page's prompt by substituting
three tokens:

| Token | Substituted with |
|-------|------------------|
| `{{GLOSSARY}}` | full contents of `docs/src/glossary.md` (the EXPLAIN register) |
| `{{PAGE}}` | the canonical source page body + frontmatter |
| `{{NONCE}}` | a per-run random nonce delimiter (prompt-injection defense, LLM01) |

`validate_prompt` requires `{{NONCE}}` in every prompt template; a template missing it
fails the planner. The nonce wraps untrusted page content so instructions injected inside a
source page cannot escape the data region.

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

Hash gating keys on **both** `source_sha256` and `prompt_sha256`: a page retranslates when
its source changes OR when its pass prompt changes.

### Structural (never-translated) pages

`SUMMARY.md` and `glossary.md` are structural: copied verbatim to BOTH `_published/human/`
and `_published/agent/`, and excluded from the manifest and plan items. (`glossary.md` is
additionally the `{{GLOSSARY}}` injection source.)

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

Translation requires an in-session LLM call, so the loop is an orchestrator-driven slash
command, not a justfile recipe:

1. **Plan** — `docs-translate.py --plan` emits JSON `items[]`, each with `source_path`,
   `output_path`, and an `assembled_prompt`. Empty `items` → nothing stale, stop.
2. **Dispatch** — for each item, the orchestrator dispatches a general-purpose sub-agent
   (`mode: default`, no Write/Edit/Bash) whose sole job is to return the translated
   Markdown as its final message; the parent session writes each result to `output_path`.
   Parallelism is mandatory — sub-agents dispatch in batches of 4 in a single message.
   Empty/preamble responses retry once with a "return only Markdown" prefix; a second
   failure aborts before finalize.
3. **Finalize** — `docs-translate.py --finalize` updates the manifest after all outputs are
   on disk; non-zero (missing output) aborts without a partial manifest write.

### Operational notes (orchestrator-side — policy, not pipeline mechanism)

The pipeline itself is model-agnostic. The following is orchestration policy applied at dispatch time:

- EXPLAIN-pass renders (human-facing prose) default to the Opus tier per the
  human-prose-output standard. STRIP-pass (agent form) can use a cheaper tier.

### CI shape

CI remains dumb (no LLM calls): it runs `mdbook build docs/`, copies the committed
`llms.txt` / `llms-full.txt` into the build output (`docs/book/`), and deploys that tree to
the `gh-pages` branch.

**Current-state caveat (2026-05-21):** `book.toml` sets `src = "src"`, so mdBook builds the
canonical `docs/src/` tree, NOT `_published/human/`. The human surface is therefore not yet
wired to the EXPLAIN translations — the §2 design-intent wiring is pending. The agent
surface (`docs-llms.py`, default `--src docs/_published/agent`) IS wired to the STRIP
translations.

## Scope

Workspace-shared pattern. **First adopter: mnemra-core.** The pattern applies to any workspace
repo that publishes docs to outside humans where the canonical source is agent-first.
Downstream adopters are not enumerated here — the trigger is "publishing to outside humans
from an agent-primary source," not membership in a fixed list.

Workspace tool location (promotion target when mechanism stabilizes): TBD at promotion time.
Current candidates: `scripts/docs-translate`, `.claude/commands/docs-translate.md`.

## Alternatives Considered

**Workspace-shared tooling from day one.** Build translation prompts and scripts in the workspace immediately, before mnemra-core proves the pattern. Rejected: premature workspace plumbing before the mechanism is validated in a real adopter.

**Per-repo-then-extract on second adopter.** Build the full mechanism in mnemra-core; extract only when a second repo needs it. Rejected: the maintainer explicitly named workspace scope at design time, overriding rule-of-three. Waiting for a second adopter defers the promotion-path design.

**First-paragraph extraction as llms.txt description source.** Use each page's first paragraph after the H1 as the llms.txt description. Rejected: first paragraphs are not always good one-liners; the pattern produces inconsistent manifest quality.

**Accept non-deterministic translation.** Run translation on every invocation, accepting diff churn. Rejected: noisy diffs on unchanged source impede PR review quality and erode trust in the committed translation artifacts.

## Consequences

**Positive:**

- Outside humans land on pages authored for them; outside agents have a structured llms.txt
  entry point. Both gaps from the Context section are closed.
- Single canonical source; no dual-source drift (the failure mode explicitly rejected in
  G-0027's "Dual-source" alternative).
- Translation cost is bounded to local subscription usage; cloud CI remains API-spend-free.
- Hash gating produces stable, meaningful diffs — translation commits correlate with actual
  source changes.
- The glossary provides a shared register for EXPLAIN-pass consistency across pages and over
  time.

**Negative / accepted:**

- `_published/` tree is a committed build artifact. PR diffs include translated content
  alongside source changes. Mitigation: PR review convention focuses on `docs/src/` for
  content review; `_published/` changes are visual confirmation only.
- Translation quality depends on EXPLAIN/STRIP prompts. A prompt change triggers a full retranslation (one-off cost, bounded, explicit in the PR diff).
- Future contributors must run `just docs-check` before pushing doc changes. The
  failure-with-message handles first-violation cases; this is an acknowledged onboarding cost.
- Translation is local-subscription-gated. A repo maintainer without a Claude Code
  subscription cannot regenerate translations. Accepted constraint.

**Downstream:**

- Mnemra-core docs restructure inherits directly from the spec layout and the frontmatter contract (`title`, `summary:`, `primary-audience`).
- When the mechanism stabilizes in mnemra-core, a workspace-promotion task updates this ADR with the resolved workspace tool location.
- The glossary migrates to a structured form when the structured-delta tooling lands; the EXPLAIN-pass will read from the structured source at that point.

## Changelog

- 2026-05-20 — Initial draft. Decision lineage recorded; mechanism details TBD pending
  first-adopter implementation.
- 2026-05-20 — Amendment: corrected "session codes" → "requirement codes" in Context section.
  R-codes are requirement identifiers from canonical requirements docs, not session-episode
  shorthand.
- 2026-05-21 — Amendment: "Mechanism details" promoted from TBD placeholder to resolved
  mechanism, following first-adopter (mnemra-core) implementation. Records the three pipeline
  surfaces, the recipe set, prompt files + `{{GLOSSARY}}`/`{{PAGE}}`/`{{NONCE}}` substitution
  (incl. the nonce injection defense), the manifest schema (source/prompt sha256 hash-gating),
  the structural-page both-sides-verbatim rule (`SUMMARY.md` + `glossary.md`), the
  `_published/` layout, and the `/docs-translate` dispatch contract. Resolves the proposal's
  `just docs-translate` recipe to a `/docs-translate` slash command (translation needs
  in-session Agent dispatch).
- 2026-05-21 — Correction: the same-day "Mechanism details" amendment overclaimed the human
  surface as built. In fact `book.toml` sets `src = "src"`, so CI builds `docs/src/` and the
  human EXPLAIN translations are not yet served (the agent/llms surface IS wired). Corrected
  the resolved-section intro and CI-shape subsection to current state; human-surface wiring
  tracked as a separate pending task.
