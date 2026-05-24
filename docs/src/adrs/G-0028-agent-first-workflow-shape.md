---
title: "G-0028: Agent-First Workflow Shape — /brief + /verify, with Principles+Values as Baseline"
summary: "Unified /brief skill (intake → frame → spec, two human touchpoints); /verify paired skill (four-signal verification); mandatory Stage 0 baseline load of architecture values, principles, and ADRs."
primary-audience: agent
---

# G-0028: Agent-First Workflow Shape — /brief + /verify, with Principles+Values as Baseline

**Status:** Accepted
**Date:** 2026-05-13

## Context

The existing `/discover → /architect → /spec` workflow was designed around the way humans elicit and decide. Each skill walks the decomposer through a multi-step conversation: questions surfaced, options weighed, decisions confirmed per cluster. The shape made sense when the agents were assistants and the decomposer was the producer.

The premise has shifted. The agents *are* the producers; the decomposer is the intent-source and the final acceptor. The human-elicitation shape now over-asks for course-correction, produces too many in-loop interruptions, and trial-and-errors on a substrate (human-centric workflow design) that the actual workload (agent-led production) doesn't share.

An architecture session on 2026-05-13 made the gap concrete: three substrate-level pivots occurred mid-session, each legitimately surfaced by the decomposer, and only one of six planned decision clusters got fully walked. Two specific gaps were named there that this ADR resolves first:

- The workflow doesn't load `architecture-principles.md` + `architecture-values.md` at session start — the anchor layer is missing for the whole conversation up to the point a human notices.
- The ADR-vs-design-note criterion was anthropocentric ("major + hard to change"); the agent-first cut is "reversal forces downstream agent rework or external-consumer-referenced."

The reframe makes the workflow's job explicit: take the decomposer's intent + the locked constraint framework (principles, values, workspace ADRs) and produce correct software with human input only at intent and final acceptance. "Correct" means spec conformance + property-based test pass + intent-conformance review + decomposer spot check. Spec quality is the load-bearing input — garbage in, garbage out — so the workflow's real job is producing a spec tight enough that downstream is mechanical.

**The meta-frame.** *Apply structure at points where drift occurs.* The goal is human+agent productivity with correctness as the default. Humans and agents each carry characteristic strengths and characteristic failure modes; the workflow's job is to blend the strengths and bound the failure modes of each, applying structure precisely at the points where work would otherwise drift. The old workflow was shaped by how humans work alone; the new workflow is shaped by how humans and agents work together.

This ADR builds directly on **G-0027 (agent-primary source artifacts)** — the same principle applied to the workflow that produces those artifacts.

## Drivers

- The decomposer's stated goal: "out of the loop unless required." Minimize human-in-loop friction.
- The measurement problem: no data loop exists today for workflow success. The framing must enable a measurement loop, not just an aesthetic.
- Agent autonomy is safe iff the spec is verifiable. The workflow must produce verifiable specs.
- Trial-and-error on workflow design is unsustainable. Framing must lock so iteration moves to implementation.
- Principles + values are already authored as baseline; the workflow must load them, not ignore them.

## Decision

Adopt an agent-first workflow shape with two skills: **`/brief`** (unified, three internal stages, two human touchpoints, mandatory principles+values baseline at Stage 0) and **`/verify`** (paired, four-signal verification stack).

### Mandatory Stage 0 — baseline load (applies to every `/brief` and `/verify` invocation)

Every `/brief` run begins by loading the constraint baseline into the working context:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Architecture values | `docs/src/architecture-values.md` | The six core values + supporting values; the system properties + meta values the work must respect |
| Architecture principles | `docs/src/architecture-principles.md` | The named principles (`P-Defer`, `P-PerRepoFirst`, `P-LockContract`, etc.) that operationalize the values |
| Workspace ADRs (G-prefix) | `docs/src/adrs/G-*.md` | Workspace-wide locked decisions |
| Constraint graph + edges | `docs/src/constraint-edges.md` | Relationships between principles, ADRs, and project constraints |
| Project ADRs (P-prefix) | `<project>/docs/src/adrs/P-*.md` (when project is named) | Project-specific locked decisions inherited or overridden |

Loading is non-optional. The previous workflow treated principles+values as latent context the agent might pick up if asked; agent-first treats them as the operating frame the work must explicitly cite. Review passes at each stage check decisions against this baseline.

### `/brief` — unified intake → frame → spec, two human touchpoints

| Stage | Owner | Activity | Output |
|-------|-------|----------|--------|
| **1. Intake** | Decomposer writes; agents review | Structured intent capture (JTBD + non-goals + success criteria + hard constraints — exact schema in downstream task); agent review pass validates schema completeness and detects principle/value conflicts; decomposer iterates until lock. **For existing projects, see "Project alignment audit" below.** | Validated intent |
| **2a. Frame elicitation** | Agent proposes; decomposer inputs | Agent surfaces architectural shape proposal (boundaries, component map, cross-cutting decisions, open ADR slots) drawn from intent + baseline + any predecessor substrate. Decomposer inputs architectural direction. `/clarify`-style 95%-confidence loop iterates until threshold. **Collapsed under brownfield-extension modulation (see below).** | Architectural-direction input record |
| **2b. Frame synthesis** | Agents synthesize | Walk the constraint graph from validated intent + baseline + Stage 2a input record; propose operating constraints; review pass flags conflicts; batch routine ADRs, escalate only on novel-decision triggers | Frame doc (constraint summary + rationale chain) |
| **3. Spec** | Agents synthesize | Produce testable spec from frame doc; review pass validates testability and spec-quality; spec is the contract `/verify` consumes | Locked spec |

**Decomposer touchpoints (cold-start default):**

- **Intake-exit gate** — confirm validated intent.
- **Stage 2a elicitation loop** — input architectural direction; iterate to confidence (a bounded loop, not a single gate).
- **Frame-exit gate** — review the synthesized Frame before Spec begins. The Frame *is* the architecture; reviewing it is the load-bearing checkpoint that distinguishes "correct shape" from "passes agent review of its own work."
- **Spec-exit gate** — confirm locked spec.

**Decomposer touchpoints (brownfield-extension modulation):** Stage 2a elicitation collapses; Frame-exit gate collapses to a light "no surprises" scan (kept as floor — easier to relax later than restore). Two-touchpoint shape (intake + spec-exit) is effectively recovered for extension work where the architecture is already framed and stable.

Between gates, agents operate autonomously. Pause-and-escalate triggers (below) are the only legitimate re-entry path **outside the Stage 2a elicitation loop and Frame-exit review**.

### Project alignment audit (Stage 1 sub-process for existing projects)

When `/brief` is invoked against an existing project (project-id supplied or project path detected), Stage 1's first action is a project-state audit *before* intent capture proceeds:

| Check | Question | If misaligned |
|-------|----------|---------------|
| Intent artifact | Does an intent doc exist in the validated schema (JTBD + non-goals + success criteria + hard constraints)? | Propose retrofit from existing discovery/scoping artifacts; surface to decomposer |
| Frame artifact | Does a frame doc / constraints summary exist? Does it cite principles + values + ADRs? | Propose retrofit; complete missing clusters before forward progress |
| ADRs | Are ADRs in expected format (per-file MADR with P-prefix; agent-first reversal-cost criterion)? | Identify drift; opportunistic retrofit |
| Spec | Does a spec exist in `/verify`-consumable shape? | Defer to Stage 3 once Frame is aligned |
| Self-contained references | Do artifacts cite by name+ID self-containedly (per G-0027)? | Retrofit references |

Migration happens *before* the workflow continues.

### Cold-start vs brownfield-extension modulation

The cold-start case is the norm. The original lock of this ADR implicitly calibrated to the warm-start case — projects with months of upstream architectural work that supplied Frame-quality substrate. Most projects don't start there; running agent-only Frame against a thin substrate would invent or stop. Surfaced 2026-05-22 during mnemra-core's first run through Stage 2 (Frame): output was good *because* warm-start substrate was sufficient. For cold-start projects the same path would fail.

Modulation is **novelty-keyed** — alignment with the existing Lightweight path (intent-size keyed) gives one collapse rule with two discriminators:

| Discriminator | Heavy (default) | Light (collapse) |
|---|---|---|
| Intent size | Multi-cluster, principle-crossing | Small, single-cluster, principles cover cleanly |
| Frame novelty | New project OR new architectural surface OR Frame-altering feature | Extension of established Frame within an existing project |

When BOTH discriminators land light, the full collapse fires (existing Lightweight path). When either lands heavy, the heavier shape applies — Stage 2a elicitation + Frame-exit gate are in.

**Detection at Stage 0:** load the project's existing Frame doc (if any) + last `/brief` run telemetry. Brownfield-extension is detected when a Frame doc exists for the target project AND the intent doesn't propose architectural-surface changes; collapse fires. Otherwise default to heavy.

### Calibration phase + re-evaluation tripwire

This amendment introduces a heavier-touchpoint shape than the original lock. The shape is **calibration**, not the final answer.

**Tripwire:**

- **N = 5 cold-start Frame-exit reviews** (the cohort). Tracked on `skill_run` telemetry as a per-stage flag.
- **At N, refit:** decomposer reviews the catch-rate — how often was the Frame revised at Frame-exit vs accepted as-is? Were the revisions things downstream code+security review would have caught anyway?
- **Brownfield expectation:** skip-rate higher than greenfield (architecture is stable). If brownfield-extension is *always* triggering full heavy shape, the modulation rule isn't detecting correctly.
- **Greenfield expectation:** lower skip-rate. If the decomposer is *always* skipping Frame-exit on greenfield too, that's the calibration signal saying the gate has converged on rubber-stamp — refit gate density downward.

**Refit options at N:** (a) keep gate density unchanged if catch-rate justifies; (b) collapse Frame-exit gate to a notification (decomposer is told the Frame is ready, no blocking review); (c) full collapse to the original 2-touchpoint shape; (d) tighten further if catch-rate evidence shows downstream review isn't catching what Frame-exit catches.

Bias toward more touchpoints during calibration; relax case-by-case as evidence accumulates; tripwire prevents calcification.

### `/verify` — paired with `/brief`; four-signal verification

| Signal | Source | Type | Notes |
|--------|--------|------|-------|
| Tests pass | Generated from spec | Mechanical | Per G-0001 testing philosophy |
| PBT pass | Property-based tests on spec invariants | Mechanical | Catches spec-vs-impl drift |
| Intent-conformance review | Agent (security-and-correctness-lensed) | Mechanical (hard step, current posture) | Confirms impl satisfies intent, not just spec — bridges the "passing tests on a lookup table" failure class |
| Spot check | Decomposer | Human | Scales with trust; can lighten as the loop converges |

Three mechanical signals + one human signal. `/verify` consumes the spec produced by `/brief` under a shared schema contract.

### Constraint graph

A graph view (not a stack) over Principles, Values, Workspace ADRs, Project ADRs, and per-task constraints.

- **Nodes:** Principles, Values, Workspace ADRs (G-prefix), Project ADRs (P-prefix), per-task constraints
- **Edges:** `specializes`, `depends-on`, `conflicts-with`, `refines`
- **Source-of-truth pattern:** view-with-explicit-edges-file. Principles and ADRs remain primary in their existing locations. A file `docs/src/constraint-edges.md` declares relationships (markdown for now; promotion to structured format deferred to friction-driven need).
- **Traversal rule:** most-specific applies when no conflict (per-task > project ADR > workspace ADR > principle). Conflicts escalate at intersection points (review-pass surface).

### Pause-and-escalate triggers (the only legitimate human-in-loop re-entry between gates)

The triggers below are a **starter set, not a closure**. Per the meta-frame, structure applies at points where drift occurs; new triggers will be discovered through friction.

| Trigger | Action |
|---------|--------|
| Principle conflict during any stage | Pause, escalate, single-decision walk |
| Intent ambiguity unresolvable from current inputs | Pause, escalate, re-elicit |
| Novel decision setting cross-project precedent | Pause, escalate, single-decision walk |
| Substrate pivot that would invalidate locked artifacts in the session | Hard stop, capture as gap note, stash, retro |

Routine decisions (within principles, no rework of done work) execute inline; agents batch them and report at the next exit gate. This implements `P-TrustThenRetro` — direction set up-front, team executes within direction, decomposer's review concentrated on outcomes and patterns.

### Learning loop — error-classification

Post-deploy errors (and workflow drift caught in-session) classify into deterministic update targets:

| Error class | Artifact to update | Forward-port to |
|---|---|---|
| Missed test case | Add test | `/brief` Stage 3 test-generation step |
| Missed spec scenario | Add to spec | `/brief` Stage 2 (frame exit checklist) |
| Missed principle implication | Add to principles or workspace ADR | `/brief` Stage 1 validation pass |
| Missed constraint | Add to constraint graph | `/brief` Stage 2 graph walk |
| Principle right, mechanism wrong (incl. maintenance disciplines: blast-radius limiting, locality, constants over inline strings, abstraction boundaries) | Refine the principle's "How it shows up" or add a design note | `/brief` Stage 2 mechanism selection; `/brief` Stage 3 spec |
| Missed pause-and-escalate trigger | Add new trigger to the table | `/brief` pause-trigger list |

Each error class has a deterministic update target. The loop is mechanical, not ad-hoc, ending the trial-and-error posture on workflow design.

### Naming

- **`/brief`** — replaces `/discover` and forward-direction `/architect`. Unified workflow.
- **`/verify`** — new skill; paired with `/brief`.
- **`/architect`** — forward-direction retired (replaced by `/brief`). Audit / reverse-engineering direction survives as a concept but is deferred — not built.
- **`/clarify`** — absorbed into `/brief` intake review pass.
- **`/spec`** — absorbed as `/brief` Stage 3; the existing skill file may remain as the implementation behind Stage 3.

### Canonical entry (addendum — 2026-05-17)

`/brief` is the single canonical entry for any work that produces a spec. Standalone invocation of `/discover`, `/spec`, or `/clarify` as a canonical entry point defeats canonical status, even where each still functions. Those skills survive only as **internal mechanisms** reused by `/brief` stages.

Rationale: `/brief` is the one mechanism every spec-producing change routes through indefinitely — a defect or a bypass is multiplied across every future feature and product. Implied-by-naming ("replaces /discover and forward /architect") is too weak a peg for that load-bearing status; this addendum makes the exclusivity explicit. The recursion across feature/product altitudes (in the `/brief` skill) does not create a second entry — it is one door with an altitude argument.

## Alternatives Considered

**Keep `/discover → /architect → /spec` triad, amend in place.** The shape itself encodes human-elicitation; amendments would be patches over a wrong-shaped contract. Three substrate-level pivots in one architecture session evidenced this. Rejected.

**Three separate skills (`/intent`, `/frame`, `/spec`) instead of unified `/brief`.** Composable — re-run `/frame` without re-doing intent when principles shift. Rejected because the agent-first contract demands fewer human touchpoints by design; three skills means three exit gates, defeating "out of the loop unless required." Unified `/brief` bakes the contract into the shape.

**Stack-based constraint hierarchy (most-specific wins).** Rejected because principle dimensions are independent axes (Determinism, Atomicity, Operability, etc.) that don't override each other but apply orthogonally. A graph captures specialization-vs-orthogonal correctly; a stack flattens it.

**Independent `/verify` (not paired with `/brief`).** More flexible — `/verify` works on any artifact, including legacy. Rejected (for now) because the agent-first contract demands deterministic verification, which demands a shared schema between producer and verifier. Independent invites schema drift.

**Principle-conflict as a separate downstream gate.** Rejected because conflicts caught downstream require re-walking the work that violated them. Catching at the input-review pass (and at every stage's review pass) eliminates the re-walk.

**Treat principles+values as latent context** (the current behavior — agents pick them up if asked). Rejected because the 2026-05-13 session evidenced the failure mode: principles+values were not loaded at session start; the anchor layer was missing for the whole conversation until the decomposer caught it mid-session. Stage 0 is mandatory load, not optional.

## Consequences

**Positive:**

- Two human touchpoints per `/brief` run (intake + spec exit), down from N. Aligns with "out of the loop unless required."
- Principles+values are loaded as baseline at Stage 0 — the anchor gap that hurt the 2026-05-13 session is closed by structure, not by vigilance.
- Spec quality is explicit load-bearing input; the workflow's real job is now nameable and tunable.
- Verification stack is concrete (3 mechanical + 1 human); enables a measurement loop.
- Learning loop has deterministic update targets, ending trial-and-error on workflow design.
- Constraint graph makes principle-conflict detection machine-tractable.
- `/brief` + `/verify` form a contract — schema can be enforced.
- Implements `P-TrustThenRetro` structurally — the workflow shape *is* the trust-then-retro composition.
- Cold-start case is now structurally accommodated. Most projects don't start with warm-start substrate.
- Frame is reviewed *as architecture*, not as agent-produced artifact.
- Calibration phase is structurally bounded (re-evaluation tripwire); workflow design moves out of trial-and-error posture on its own meta-shape.
- Novelty modulation prevents over-serving brownfield-extension work.

**Negative:**

- Unified `/brief` is heavier per-run than today's lightweight `/clarify` — small features may feel over-served. Mitigation: Stage 1 + Stage 2 collapse fast when intent is small and principles cover it cleanly.
- Intent-conformance review is new agent work — needs design and instrumentation.
- Constraint graph + edges file is new infrastructure; initial population is hand-work.
- Existing skill files need rewrite + retirement. Migration is opportunistic — touch when adjacent work occurs.
- Cold-start touchpoint count is 3 (intake + Frame-exit + spec-exit), not 2. The modulation restores the 2-touchpoint shape for brownfield-extension where it still applies.
- Stage 2a elicitation loop is new — needs design and instrumentation.

**Downstream / open work:**

- Intake schema design — separate task
- Constraint graph initial population — separate task; markdown edges file at `docs/src/constraint-edges.md`
- `/brief` skill draft — implementation; this ADR locks the shape
- `/verify` skill draft — implementation; intent-conformance review process design
- `skill_run` telemetry update — per-stage flags within `/brief`
- ADR-vs-design-note criterion codification — separate task
- mdbook aggregation for ADRs — downstream of `/brief` Stage 3
- **Add Maintainability as a core value** in `architecture-values.md`. The unit goal is **minimum-blast-radius fix**: when a change is needed, isolate it as much as possible; the codebase architecture supports isolation. Value sits in `architecture-values.md`; mechanism details live in the implementer skills/profiles — concrete rules on abstraction, locality, constants vs inline strings, module boundaries.
- **Add the meta-frame as a workspace value** in `architecture-values.md`: *"Apply structure at points where drift occurs. Blend the strengths of human and agent work; bound the failure modes of each."*

## Changelog

- 2026-05-17 — Canonical-entry addendum: explicit standalone-defeats-canonical statement; `/brief` recursive across feature/product altitudes is one door, not two.
- 2026-05-17 — Naming truth-fix: `/architect` no longer "stays in place under interim shape." Forward-direction retired; audit-direction deferred (concept survives, not built); legacy skill file archived as harvest input.
- 2026-05-23 — Cold-start amendment: explicit cold-start-vs-warm-start framing; Stage 2a pre-Frame elicitation sub-stage added (`/clarify`-style 95%-confidence loop); Frame-exit human gate restored for cold-start runs (cold-start touchpoint count 2 → 3); novelty-keyed modulation rule aligned with existing Lightweight path; calibration tripwire baked in (N=5 cold-start Frame-exit cohort, refit at N). Source: 2026-05-23 frame-canonical-entry alignment session; original 2-touchpoint lock was calibrated to warm-start case, cold-start is the norm. Calibration framing per meta-rule: bias toward more touchpoints during calibration; relax case-by-case as evidence accumulates.
