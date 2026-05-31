---
title: "G-0027: Agent-Primary Source Artifacts; Human Views Derivative"
summary: "Source-of-truth artifacts (requirements, specs, architecture, ADRs) are authored in agent-primary form: structured, machine-addressable, named identifiers, no integrated-narrative requirement. Human views are generated on demand."
primary-audience: agent
---

# G-0027: Agent-Primary Source Artifacts; Human Views Derivative

**Status:** Accepted
**Date:** 2026-05-11

## Context

Source-of-truth artifacts in this workspace — requirements, specs, architecture
documents, ADRs — are read primarily by AI agents performing dispatched work,
not by humans reading top-to-bottom. The conventional aesthetic of these
documents (integrated narrative prose, woven cross-references, designed flow)
is a legacy of the human-authoring tradition and adds little value to agent
consumers while taxing every author with composition work on every change.

Investigation of OpenSpec (spec-driven development framework) confirmed that a
successful agent-targeted format is structurally different from human-narrative
documents: named identifiers as primary keys, labeled sections (ADDED /
MODIFIED / REMOVED / RENAMED), block-level addressability, deterministic merge
by name. The integrated-narrative property is incidental to human readers;
agents prefer the catalog.

The decision point arose during a specops CLI discovery session when the choice
between an LLM-assisted merge engine (to preserve integrated prose) and a
deterministic structural merge (catalog-shaped output) forced a re-examination
of *who the spec is actually for*.

Related prior decisions (G-0004, G-0025) applied this format-follows-consumer
logic to narrower domains (agent profiles, internal IPC). G-0027 makes the
underlying principle explicit and applies it to documentation source artifacts.

## Decision

Source-of-truth artifacts (requirements, specs, architecture, ADRs) are
authored, stored, and maintained in agent-primary form:

1. **Structured and machine-addressable.** Named blocks with stable
   identifiers, labeled sections, RFC 2119 keywords where applicable, explicit
   cross-references by name.

2. **Identifiers carry both a stable unique ID and a human-readable name.**
   Names alone collide; bare numbers are opaque to humans. Pairing gives
   durable identity (for merge, supersede, cross-reference) and grokable
   references (for review, discussion, recall). Exact syntax is per-format.

3. **No integrated-narrative requirement.** Connective prose between blocks is
   not load-bearing. Mechanical operations may discard it.

4. **Operations on these artifacts are mechanical code, not LLM-driven.**
   Parse, validate, merge, archive — all deterministic. The format is
   *consumed by* agents; the operations on the format are not *performed by*
   them. Any language model in the artifact lifecycle sits at a clear boundary
   (authoring assist upstream, view generation downstream), never inside the
   core operation.

Human-readable views, when needed, are *derivative*: generated from the
agent-primary source on demand. They are never the source of truth. A change
to a generated view that does not also change the source is a bug.

## Alternatives Considered

**Human-primary with agent-readable subset.** The traditional approach: design
the document for human readers, structure it well enough that agents can
parse it. Rejected because the actual read ratio is heavily agent-skewed in
this workspace, and the human-author tax (composing narrative, integrating
each change into the whole) is the slowest part of the cycle. Optimizing for
the rarer consumer is wrong.

**LLM-driven merge to preserve integrated narrative.** Use a language model to
rewrite the source into integrated form on each change. Rejected because (a)
it introduces non-determinism into a load-bearing path, (b) it makes
byte-identical acceptance criteria impossible to enforce, (c) it consumes
model budget for a property the primary consumer doesn't need, (d) the
"looks-integrated" aesthetic is itself a derivative concern that can be
served downstream without polluting the source.

**Dual-source: keep both an agent-primary and a human-primary copy.** Rejected
because dual sources drift. The whole point of a source of truth is that
there's one.

## Consequences

**Positive:**

- Mechanical merge engines become tractable for spec/architecture deltas —
  deterministic structural code, no model in the merge path.
- Authoring discipline shifts toward named blocks and structured deltas, which
  improves clarity even for the occasional human reader of the source.
- Cross-artifact references survive renames, refactors, and document
  reorganizations in ways narrative cross-references do not.
- Human-view generation becomes optional: pay for it only when a real reader
  needs one, not preemptively on every change.
- Format evolution is evaluated on agent-consumability, not on whether the
  source "reads well."

**Negative:**

- Direct readers of the source will find it more catalog-like, less designed.
  Acceptable: the source is not the reader's document.
- Authoring cost shifts to discipline (thinking in named blocks) rather than
  composition (free-form prose). Paid by every author of every artifact.
- View generation is an additional surface when humans actually need a view.
  Non-trivial work; worth doing only when a real reader is present.
- Existing narrative-shaped artifacts will not match this standard until
  rewritten. Migration is opportunistic — rewrite when an artifact is
  touched, not on a blanket sweep.

**Downstream:**

- Specops CLI inherits directly: the named-block additive primitive
  (OpenSpec-style) is this decision's implementation for the spec format.
  Separately captured as a project ADR for specops.
- Architecture tooling inherits directly: architecture documents adopt the same
  named-block primitive; the integrated-narrative goal drops from
  architecture-doc structure.
- The `/spec` skill needs revisiting — feature-spec is reasonably structured but
  doesn't use named requirements as identifiers.
- Per-format syntax decisions (exact form of the name+ID pair, section
  layout) are captured in per-project P-* ADRs, not relitigated at the
  general level.
