---
title: "G-0028: Agent-First Workflow Shape — /brief + /verify, with Principles+Values as Baseline"
summary: "Unified /brief skill (intake → frame → spec, two human touchpoints); /verify paired skill (four-signal verification); mandatory Stage 0 baseline load of architecture values, principles, and ADRs."
primary-audience: agent
---

# G-0028: Agent-First Workflow Shape — /brief + /verify, with Principles+Values as Baseline

**Status:** Accepted
**Date:** 2026-05-13

## Context

The existing `/discover → /architect → /spec` workflow was built around the way humans elicit and decide. Each skill walks the [decomposer](../glossary.md#the-decomposer) (the role that figures out what to build before execution: framing a design session, drafting an ADR, writing a spec, cutting scope) through a multi-step conversation. Questions get surfaced, options get weighed, decisions get confirmed one cluster at a time. The shape made sense when the agents were assistants and the decomposer was the producer.

The premise has shifted. The agents *are* the producers now. The decomposer is the source of intent and the final acceptor. The human-elicitation shape over-asks for course-correction, produces too many in-loop interruptions, and trial-and-errors on a substrate (human-centric workflow design) that the actual workload (agent-led production) doesn't share.

An architecture session on 2026-05-13 made the gap concrete. Three substrate-level pivots happened mid-session, each one legitimately raised by the decomposer, and only one of six planned decision clusters got fully walked. Two specific gaps were named there, and this ADR resolves them first:

- The workflow doesn't load `architecture-principles.md` (the named rules that operationalize the values) and `architecture-values.md` (the standing beliefs behind every decision) at session start. The anchor layer is missing for the whole conversation up to the point a human notices.
- The criterion for "is this an ADR or a design note" was built for humans ("major and hard to change"). The agent-first cut is different: a decision is an ADR when reversing it forces downstream agent rework, or when an external consumer already references it.

The reframe makes the workflow's job explicit. Take the decomposer's intent plus the locked constraint framework (principles, values, workspace ADRs) and produce correct software, with human input only at intent and final acceptance. "Correct" has four parts: spec conformance, property-based test pass, intent-conformance review, and a decomposer spot check. Spec quality is the load-bearing input. Garbage in, garbage out. So the workflow's real job is producing a spec tight enough that everything downstream is mechanical.

**The meta-frame.** *Apply structure at points where drift occurs.* The goal is human-and-agent productivity with correctness as the default. Humans and agents each carry characteristic strengths and characteristic failure modes. The workflow's job is to blend the strengths and bound the failure modes of each, applying structure precisely at the points where work would otherwise drift. The old workflow was shaped by how humans work alone. The new one is shaped by how humans and agents work together.

This ADR builds directly on **[G-0027 (agent-primary source artifacts)](./G-0027.md)**, which establishes that source artifacts are authored for an agent reader first, with human views generated from them. This is the same principle applied to the workflow that produces those artifacts.

## Drivers

- The decomposer's stated goal: "out of the loop unless required." Minimize human-in-loop friction.
- The measurement problem. No data loop exists today for workflow success. The framing has to enable a measurement loop, not just an aesthetic.
- Agent autonomy is safe only when the spec is verifiable. The workflow has to produce verifiable specs.
- Trial-and-error on workflow design is unsustainable. The framing has to lock so that iteration moves to implementation.
- Principles and values are already written down as a baseline. The workflow has to load them, not ignore them.

## Decision

Adopt an agent-first workflow shape with two skills. **`/brief`** is the unified workflow (three internal stages, two human touchpoints, mandatory principles-and-values baseline at Stage 0). **`/verify`** is its paired skill (a four-signal verification stack).

### Mandatory Stage 0 — baseline load (applies to every `/brief` and `/verify` invocation)

Stage 0 is the baseline-load step that every run starts from. Each `/brief` run begins by loading the constraint baseline into the working context:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Architecture values | `docs/src/architecture-values.md` | The six core values plus supporting values; the system properties and meta values the work must respect |
| Architecture principles | `docs/src/architecture-principles.md` | The named principles (`P-Defer` defers a mechanism choice until evidence forces it, `P-PerRepoFirst` keeps work per-repo before extracting to shared code, `P-LockContract` locks a contract once it has external consumers, and so on) that operationalize the values |
| Workspace ADRs (G-prefix) | `docs/src/adrs/G-*.md` | Workspace-wide locked decisions, the `G-` governance series |
| Constraint graph and edges | `docs/src/constraint-edges.md` | Relationships between principles, ADRs, and project constraints |
| Project ADRs (P-prefix) | `<project>/docs/src/adrs/P-*.md` (when project is named) | Project-specific locked decisions, inherited or overridden |

Loading isn't optional. The previous workflow treated principles and values as latent context the agent might pick up if asked. Agent-first treats them as the operating frame the work must explicitly cite. Review passes at each stage check decisions against this baseline.

### `/brief` — unified intake → frame → spec, two human touchpoints

`/brief` runs a piece of work from intake through a locked spec. Its three stages are Intake, Frame (the stage that elicits and synthesizes the problem shape before a spec is written), and Spec (the specification that defines what done looks like; agents decide how, the spec defines what).

| Stage | Owner | Activity | Output |
|-------|-------|----------|--------|
| **1. Intake** | Decomposer writes; agents review | Structured intent capture: jobs-to-be-done (JTBD) plus non-goals plus success criteria plus hard constraints, with the exact schema set in a downstream task. An agent review pass validates schema completeness and detects conflicts with a principle or value. The decomposer iterates until lock. **For existing projects, see "Project alignment audit" below.** | Validated intent |
| **2a. Frame elicitation** | Agent proposes; decomposer inputs | The agent surfaces an architectural shape proposal (boundaries, component map, cross-cutting decisions, open ADR slots) drawn from intent, baseline, and any predecessor substrate. The decomposer inputs architectural direction. A `/clarify`-style loop iterates to 95% confidence. **Collapsed under brownfield-extension modulation (see below).** | Architectural-direction input record |
| **2b. Frame synthesis** | Agents synthesize | Walk the constraint graph from validated intent, baseline, and the Stage 2a input record. Propose operating constraints. A review pass flags conflicts. Batch routine ADRs and escalate only on novel-decision triggers. | Frame doc (constraint summary plus rationale chain) |
| **3. Spec** | Agents synthesize | Produce a testable spec from the frame doc. A review pass validates testability and spec quality. The spec is the contract `/verify` consumes. | Locked spec |

**Decomposer touchpoints (cold-start default):**

- **Intake-exit gate.** Confirm validated intent.
- **Stage 2a elicitation loop.** Input architectural direction, iterating to confidence. This is a bounded loop, not a single gate.
- **Frame-exit gate.** Review the synthesized Frame before Spec begins. The Frame *is* the architecture. Reviewing it is the load-bearing checkpoint that separates "correct shape" from "passes agent review of its own work."
- **Spec-exit gate.** Confirm the locked spec.

**Decomposer touchpoints (brownfield-extension modulation):** The Stage 2a elicitation collapses. The Frame-exit gate collapses to a light "no surprises" scan, kept as a floor because it's easier to relax later than to restore. The two-touchpoint shape (intake plus spec-exit) is effectively recovered for extension work, where the architecture is already framed and stable.

Between gates, agents operate autonomously. The pause-and-escalate triggers below are the only legitimate re-entry path **outside the Stage 2a elicitation loop and Frame-exit review**.

### Project alignment audit (Stage 1 sub-process for existing projects)

When `/brief` is invoked against an existing project (project-id supplied or project path detected), Stage 1's first action is a project-state audit *before* intent capture proceeds:

| Check | Question | If misaligned |
|-------|----------|---------------|
| Intent artifact | Does an intent doc exist in the validated schema (JTBD plus non-goals plus success criteria plus hard constraints)? | Propose a retrofit from existing discovery or scoping artifacts; surface it to the decomposer |
| Frame artifact | Does a frame doc or constraints summary exist? Does it cite principles, values, and ADRs? | Propose a retrofit; complete missing clusters before forward progress |
| ADRs | Are ADRs in the expected format (per-file MADR with the P-prefix, and the agent-first reversal-cost criterion)? | Identify drift; retrofit opportunistically |
| Spec | Does a spec exist in a `/verify`-consumable shape? | Defer to Stage 3 once the Frame is aligned |
| Self-contained references | Do artifacts cite by name and ID self-containedly, per G-0027? | Retrofit references |

MADR is the lightweight ADR template the `G-` series follows: Context, Decision, Alternatives Considered, Consequences. `/verify` is the backstop stage that re-validates a finished change against the spec it was built from. Migration happens *before* the workflow continues.

### Cold-start vs brownfield-extension modulation

The cold-start case is the norm. The original lock of this ADR was implicitly calibrated to the warm-start case: projects with months of upstream architectural work that already supplied Frame-quality substrate. Most projects don't start there. Running an agent-only Frame against a thin substrate would invent or stop. This surfaced on 2026-05-22 during mnemra-core's first run through Stage 2 (Frame). The output was good *because* the warm-start substrate was sufficient. For cold-start projects the same path would fail.

The modulation is **novelty-keyed**. Aligning it with the existing Lightweight path (which is intent-size keyed) gives one collapse rule with two discriminators:

| Discriminator | Heavy (default) | Light (collapse) |
|---|---|---|
| Intent size | Multi-cluster, principle-crossing | Small, single-cluster, principles cover cleanly |
| Frame novelty | New project OR new architectural surface OR Frame-altering feature | Extension of an established Frame within an existing project |

When BOTH discriminators land light, the full collapse fires (the existing Lightweight path). When either lands heavy, the heavier shape applies. The Stage 2a elicitation and the Frame-exit gate are in.

**Detection at Stage 0:** load the project's existing Frame doc (if any) plus the last `/brief` run telemetry. Brownfield-extension is detected when a Frame doc exists for the target project AND the intent doesn't propose architectural-surface changes. The collapse fires. Otherwise default to heavy.

### Calibration phase + re-evaluation tripwire

This amendment introduces a heavier-touchpoint shape than the original lock. The shape is **calibration**, not the final answer.

**Tripwire:**

- **N = 5 cold-start Frame-exit reviews** (the cohort). Tracked on `skill_run` telemetry as a per-stage flag.
- **At N, refit:** the decomposer reviews the catch-rate. How often was the Frame revised at Frame-exit versus accepted as-is? Were the revisions things downstream code-and-security review would have caught anyway?
- **Brownfield expectation:** a skip-rate higher than greenfield, because the architecture is stable. If brownfield-extension is *always* triggering the full heavy shape, the modulation rule isn't detecting correctly.
- **Greenfield expectation:** a lower skip-rate. If the decomposer is *always* skipping Frame-exit on greenfield too, that's the calibration signal saying the gate has converged on a rubber-stamp. Refit gate density downward.

**Refit options at N:**

1. Keep gate density unchanged if the catch-rate justifies it.
2. Collapse the Frame-exit gate to a notification (the decomposer is told the Frame is ready, with no blocking review).
3. Full collapse to the original two-touchpoint shape.
4. Tighten further if catch-rate evidence shows downstream review isn't catching what Frame-exit catches.

Bias toward more touchpoints during calibration. Relax case-by-case as evidence accumulates. The tripwire prevents calcification.

### `/verify` — paired with `/brief`; four-signal verification

| Signal | Source | Type | Notes |
|--------|--------|------|-------|
| Tests pass | Generated from spec | Mechanical | Per G-0001 testing philosophy |
| PBT pass | Property-based tests (PBT) on spec invariants | Mechanical | Catches spec-vs-impl drift |
| Intent-conformance review | Agent (security-and-correctness-lensed) | Mechanical (hard step, current posture) | Confirms the impl satisfies the intent, not just the spec. Bridges the "passing tests on a lookup table" failure class |
| Spot check | Decomposer | Human | Scales with trust; can lighten as the loop converges |

Three mechanical signals plus one human signal. `/verify` consumes the spec produced by `/brief` under a shared schema contract.

### Constraint graph

A graph view (not a stack) over Principles, Values, Workspace ADRs, Project ADRs, and per-task constraints.

- **Nodes:** Principles, Values, Workspace ADRs (G-prefix), Project ADRs (P-prefix), per-task constraints
- **Edges:** `specializes` (the source is a specific case of the target), `depends-on` (the source presupposes the target), `conflicts-with` (the two can't both hold without negotiation), `refines` (the source tightens the target within the same domain)
- **Source-of-truth pattern:** a view with an explicit edges file. Principles and ADRs stay primary in their existing locations. A file at `docs/src/constraint-edges.md` declares the relationships (markdown for now; promotion to a structured format is deferred to friction-driven need).
- **Traversal rule:** the most-specific node applies when there's no conflict (per-task > project ADR > workspace ADR > principle). Conflicts escalate at intersection points (the review-pass surface).

### Pause-and-escalate triggers (the only legitimate human-in-loop re-entry between gates)

The triggers below are a **starter set, not a closure**. Per the meta-frame, structure applies at the points where drift occurs, and new triggers will be discovered through friction.

| Trigger | Action |
|---------|--------|
| Principle conflict during any stage | Pause, escalate, single-decision walk |
| Intent ambiguity unresolvable from current inputs | Pause, escalate, re-elicit |
| Novel decision setting cross-project precedent | Pause, escalate, single-decision walk |
| Substrate pivot that would invalidate locked artifacts in the session | Hard stop, capture as a gap note, stash, retro |

Routine decisions (within principles, no rework of done work) execute inline. Agents batch them and report at the next exit gate. This implements `P-TrustThenRetro`: direction is set up-front, the team executes within that direction, and the decomposer's review concentrates on outcomes and patterns.

### Learning loop — error-classification

Post-deploy errors, and workflow drift caught in-session, classify into deterministic update targets:

| Error class | Artifact to update | Forward-port to |
|---|---|---|
| Missed test case | Add test | `/brief` Stage 3 test-generation step |
| Missed spec scenario | Add to spec | `/brief` Stage 2 (frame exit checklist) |
| Missed principle implication | Add to principles or workspace ADR | `/brief` Stage 1 validation pass |
| Missed constraint | Add to constraint graph | `/brief` Stage 2 graph walk |
| Principle right, mechanism wrong (including maintenance disciplines: blast-radius limiting, locality, constants over inline strings, abstraction boundaries) | Refine the principle's "How it shows up" or add a design note | `/brief` Stage 2 mechanism selection; `/brief` Stage 3 spec |
| Missed pause-and-escalate trigger | Add a new trigger to the table | `/brief` pause-trigger list |

Each error class has a deterministic update target. The loop is mechanical, not ad-hoc. That ends the trial-and-error posture on workflow design.

### Naming

- **`/brief`** replaces `/discover` (the earlier-generation discovery pass that shaped scope before a spec) and the forward-direction of `/architect`. It's the unified workflow.
- **`/verify`** is a new skill, paired with `/brief`.
- **`/architect`** retires in its forward direction (replaced by `/brief`). The audit and reverse-engineering direction survives as a concept but is deferred. It isn't built.
- **`/clarify`** is absorbed into the `/brief` intake review pass.
- **`/spec`** is absorbed as `/brief` Stage 3. The existing skill file may remain as the implementation behind Stage 3.

### Canonical entry (addendum — 2026-05-17)

`/brief` is the single canonical entry for any work that produces a spec. Invoking `/discover`, `/spec`, or `/clarify` standalone as a canonical entry point defeats canonical status, even where each still functions. Those skills survive only as **internal mechanisms** reused by `/brief` stages.

Rationale: `/brief` is the one mechanism every spec-producing change routes through indefinitely. A defect or a bypass is multiplied across every future feature and product. Implied-by-naming ("replaces /discover and forward /architect") is too weak a peg for that load-bearing status, so this addendum makes the exclusivity explicit. The recursion across feature and product altitudes (in the `/brief` skill) doesn't create a second entry. It's one door with an altitude argument.

## Alternatives Considered

**Keep the `/discover → /architect → /spec` triad and amend in place.** The shape itself encodes human-elicitation. Amendments would be patches over a wrong-shaped contract. The three substrate-level pivots in one architecture session evidenced this. Rejected.

**Three separate skills (`/intent`, `/frame`, `/spec`) instead of a unified `/brief`.** This would be composable: re-run `/frame` without re-doing intent when principles shift. Rejected because the agent-first contract demands fewer human touchpoints by design. Three skills means three exit gates, which defeats "out of the loop unless required." Unified `/brief` bakes the contract into the shape.

**Stack-based constraint hierarchy (most-specific wins).** Rejected because principle dimensions are independent axes (Determinism, Atomicity, Operability, and so on) that don't override each other but apply orthogonally. A graph captures specialization versus orthogonality correctly. A stack flattens it.

**Independent `/verify` (not paired with `/brief`).** This would be more flexible: `/verify` works on any artifact, including legacy. Rejected for now because the agent-first contract demands deterministic verification, which demands a shared schema between producer and verifier. Independent invites schema drift.

**Principle-conflict as a separate downstream gate.** Rejected because conflicts caught downstream require re-walking the work that violated them. Catching at the input-review pass, and at every stage's review pass, eliminates the re-walk.

**Treat principles and values as latent context** (the current behavior, where agents pick them up if asked). Rejected because the 2026-05-13 session evidenced the failure mode. Principles and values weren't loaded at session start, so the anchor layer was missing for the whole conversation until the decomposer caught it mid-session. Stage 0 is a mandatory load, not optional.

## Consequences

**Positive:**

- Two human touchpoints per `/brief` run (intake plus spec exit), down from N. Aligns with "out of the loop unless required."
- Principles and values are loaded as a baseline at Stage 0. The anchor gap that hurt the 2026-05-13 session is closed by structure, not by vigilance.
- Spec quality is now an explicit load-bearing input. The workflow's real job is nameable and tunable.
- The verification stack is concrete (three mechanical signals plus one human). That enables a measurement loop.
- The learning loop has deterministic update targets, ending trial-and-error on workflow design.
- The constraint graph makes principle-conflict detection machine-tractable.
- `/brief` and `/verify` form a contract, so the schema can be enforced.
- Implements `P-TrustThenRetro` structurally. The workflow shape *is* the trust-then-retro composition.
- The cold-start case is now structurally accommodated. Most projects don't start with warm-start substrate.
- The Frame is reviewed *as architecture*, not as an agent-produced artifact.
- The calibration phase is structurally bounded by the re-evaluation tripwire. Workflow design moves out of trial-and-error posture on its own meta-shape.
- Novelty modulation prevents over-serving brownfield-extension work.

**Negative:**

- Unified `/brief` is heavier per-run than today's lightweight `/clarify`. Small features may feel over-served. Mitigation: Stage 1 and Stage 2 collapse fast when the intent is small and principles cover it cleanly.
- Intent-conformance review is new agent work. It needs design and instrumentation.
- The constraint graph and edges file is new infrastructure. The initial population is hand-work.
- Existing skill files need a rewrite and retirement. Migration is opportunistic: touch the file when adjacent work occurs.
- The cold-start touchpoint count is 3 (intake plus Frame-exit plus spec-exit), not 2. The modulation restores the two-touchpoint shape for brownfield-extension where it still applies.
- The Stage 2a elicitation loop is new. It needs design and instrumentation.

**Downstream / open work:**

- Intake schema design. A separate task.
- Constraint graph initial population. A separate task; markdown edges file at `docs/src/constraint-edges.md`.
- `/brief` skill draft. Implementation; this ADR locks the shape.
- `/verify` skill draft. Implementation; intent-conformance review process design.
- `skill_run` telemetry update. Per-stage flags within `/brief`.
- ADR-vs-design-note criterion codification. A separate task.
- mdbook aggregation for ADRs. Downstream of `/brief` Stage 3.
- **Add Maintainability as a core value** in `architecture-values.md`. The unit goal is the **minimum-blast-radius fix**: when a change is needed, isolate it as much as possible, and the codebase architecture supports that isolation. The value sits in `architecture-values.md`; mechanism details live in the implementer skills and profiles, as concrete rules on abstraction, locality, constants versus inline strings, and module boundaries.
- **Add the meta-frame as a workspace value** in `architecture-values.md`: *"Apply structure at points where drift occurs. Blend the strengths of human and agent work; bound the failure modes of each."*

## Changelog

- 2026-05-17: Canonical-entry addendum. Explicit statement that standalone invocation defeats canonical status; `/brief` recursive across feature and product altitudes is one door, not two.
- 2026-05-17: Naming truth-fix. `/architect` no longer "stays in place under interim shape." Forward-direction retired; audit-direction deferred (the concept survives, but it isn't built); the legacy skill file is archived as harvest input.
- 2026-05-23: Cold-start amendment. Explicit cold-start-vs-warm-start framing; Stage 2a pre-Frame elicitation sub-stage added (`/clarify`-style 95%-confidence loop); Frame-exit human gate restored for cold-start runs (cold-start touchpoint count 2 → 3); novelty-keyed modulation rule aligned with the existing Lightweight path; calibration tripwire baked in (N=5 cold-start Frame-exit cohort, refit at N). Source: the 2026-05-23 frame-canonical-entry alignment session. The original two-touchpoint lock was calibrated to the warm-start case, and cold-start is the norm. Calibration framing per the meta-rule: bias toward more touchpoints during calibration, relax case-by-case as evidence accumulates.
