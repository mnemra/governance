---
title: "G-0013: Agent-First Workflow Shape — /brief + /verify, with Principles+Values as Baseline"
summary: "A unified /brief skill (intake → frame → spec) with a mandatory Stage 0 baseline load of values, principles, and ADRs, and a paired /verify skill (four-signal verification). Human touchpoints collapse to intake + spec-exit for brownfield extension and expand to add a Frame-exit gate for cold-start work. Stage 3 produces the designed-tier spec only; tasks belong to the committed-tier plan."
primary-audience: agent
---

# G-0013: Agent-First Workflow Shape — /brief + /verify, with Principles+Values as Baseline

**Status:** Accepted
**Date:** 2026-05-13

## Context

The existing `/discover → /architect → /spec` workflow was designed around the way humans elicit and decide. Each skill walks the decomposer through a multi-step conversation: questions surfaced, options weighed, decisions confirmed per cluster. The shape made sense when the agents were assistants and the decomposer was the producer.

The premise has shifted. The agents *are* the producers; the decomposer is the intent-source and the final acceptor. The human-elicitation shape now over-asks for course-correction, produces too many in-loop interruptions, and trial-and-errors on a substrate (human-centric workflow design) that the actual workload (agent-led production) does not share.

An architecture session made the gap concrete: three substrate-level pivots occurred mid-session, each legitimately surfaced by the decomposer, and only one of six planned decision clusters got fully walked. Two specific gaps named there this ADR resolves first:

- The workflow does not load the architecture principles and values at session start; the anchor layer is missing for the whole conversation up to the point a human notices.
- The ADR-vs-design-note criterion was anthropocentric ("major + hard to change"); the agent-first cut is "reversal forces downstream agent rework or is referenced by an external consumer."

The reframe makes the workflow's job explicit: take the decomposer's intent plus the locked constraint framework (principles, values, ecosystem ADRs) and produce correct software with human input only at intent and final acceptance. "Correct" means spec conformance + property-based test pass + intent-conformance review + decomposer spot check. Spec quality is the load-bearing input (garbage in, garbage out), so the workflow's real job is producing a spec tight enough that downstream is mechanical.

**The meta-frame.** *Apply structure at points where drift occurs.* The goal is human+agent productivity with correctness as the default. Humans and agents each carry characteristic strengths and characteristic failure modes; the workflow's job is to blend the strengths and bound the failure modes of each, applying structure precisely at the points where work would otherwise drift. The old workflow was shaped by how humans work alone; the new workflow is shaped by how humans and agents work together. This meta-frame may eventually deserve its own ecosystem-level principle or value; for this ADR, it is the rationale behind every decision below.

This ADR builds directly on **`P-AgentPrimarySource`** (agent-primary source artifacts): the same principle applied to the workflow that produces those artifacts. That principle says "source artifacts are for agents"; this ADR says "the workflow that produces them is also for agents."

## Drivers

- The decomposer's stated goal: "out of the loop unless required." Minimize human-in-loop friction.
- The measurement problem: no data loop exists today for workflow success. The framing must enable a measurement loop, not just an aesthetic.
- Agent autonomy is safe iff the spec is verifiable. The workflow must produce verifiable specs.
- Trial-and-error on workflow design is unsustainable. The framing must lock so iteration moves to implementation.
- Principles and values are already authored as baseline; the workflow must load them, not ignore them.

## Decision

Adopt an agent-first workflow shape with two skills: **`/brief`** (unified, three internal stages, two human touchpoints, mandatory principles+values baseline at Stage 0) and **`/verify`** (paired, four-signal verification stack).

### Mandatory Stage 0 — baseline load (applies to every `/brief` and `/verify` invocation)

Every `/brief` run begins by loading the constraint baseline into the working context:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Architecture values | `architecture-values.md` | The core values + supporting values; the system properties and meta values the work must respect |
| Architecture principles | `architecture-principles.md` | The named principles (`P-Defer`, `P-PerRepoFirst`, `P-LockContract`, etc.) that operationalize the values |
| Ecosystem ADRs (G-prefix) | `adrs/G-*.md` | Ecosystem-wide locked decisions |
| Constraint graph + edges | `constraint-edges.md` | Relationships between principles, ADRs, and project constraints |
| Project ADRs (P-prefix) | `<project>/docs/src/adrs/P-*.md` (when a project is named) | Project-specific locked decisions inherited or overridden |

Loading is non-optional. The previous workflow treated principles and values as latent context the agent might pick up if asked; agent-first treats them as the operating frame the work must explicitly cite. Review passes at each stage check decisions against this baseline.

### `/brief` — unified intake → frame → spec, two human touchpoints

| Stage | Owner | Activity | Output |
|-------|-------|----------|--------|
| **1. Intake** | Decomposer writes; agents review | Structured intent capture (JTBD + non-goals + success criteria + hard constraints — exact schema in a downstream task); an agent review pass validates schema completeness and detects principle/value conflicts; the decomposer iterates until lock. **For existing projects, see "Project alignment audit" below.** | Validated intent |
| **2a. Frame elicitation** | Agent proposes; decomposer inputs | The agent surfaces an architectural-shape proposal (boundaries, component map, cross-cutting decisions, open ADR slots) drawn from intent + baseline + any predecessor substrate. The decomposer inputs architectural direction. A `/clarify`-style 95%-confidence loop iterates until threshold. **Collapsed under brownfield-extension modulation (see below).** | Architectural-direction input record |
| **2b. Frame synthesis** | Agents synthesize | Walk the constraint graph from validated intent + baseline + the Stage 2a input record; propose operating constraints; a review pass flags conflicts; batch routine ADRs and escalate only on novel-decision triggers | Frame doc (constraint summary + rationale chain) |
| **3. Spec** | Agents synthesize | Produce a testable spec from the frame doc; a review pass validates testability and spec-quality; the spec is the contract `/verify` consumes | Locked spec |

(JTBD is "jobs to be done," the intake's statement of what the work is for.)

**Decomposer touchpoints (cold-start default):**

- **Intake-exit gate:** confirm validated intent.
- **Stage 2a elicitation loop:** input architectural direction; iterate to confidence (a bounded loop, not a single gate).
- **Frame-exit gate:** review the synthesized Frame before Spec begins. The Frame *is* the architecture; reviewing it is the load-bearing checkpoint that distinguishes "correct shape" from "passes agent review of its own work."
- **Spec-exit gate:** confirm the locked spec.

**Decomposer touchpoints (brownfield-extension modulation):** Stage 2a elicitation collapses; the Frame-exit gate collapses to a light "no surprises" scan (kept as a floor, easier to relax later than restore). The two-touchpoint shape (intake + spec-exit) is effectively recovered for extension work where the architecture is already framed and stable.

Between gates, agents operate autonomously. Pause-and-escalate triggers (below) are the only legitimate re-entry path **outside the Stage 2a elicitation loop and Frame-exit review**.

### Project alignment audit (Stage 1 sub-process for existing projects)

When `/brief` is invoked against an existing project (a task-DB project id supplied or a project path detected), Stage 1's first action is a project-state audit *before* intent capture proceeds:

| Check | Question | If misaligned |
|-------|----------|---------------|
| Intent artifact | Does an intent doc exist in the validated schema (JTBD + non-goals + success criteria + hard constraints)? | Propose a retrofit from existing discovery/scoping artifacts; surface to the decomposer |
| Frame artifact | Does a frame doc / constraints summary exist? Does it cite principles + values + ADRs? | Propose a retrofit; complete missing clusters before forward progress |
| ADRs | Are ADRs in the expected format (per-file MADR with a P-prefix; the agent-first reversal-cost criterion)? | Identify drift; opportunistic retrofit |
| Spec | Does a spec exist in `/verify`-consumable shape? | Defer to Stage 3 once the Frame is aligned |
| Self-contained references | Do artifacts cite by name+ID self-containedly (per `P-AgentPrimarySource` and the ADR-format conventions)? | Retrofit references |

Migration happens *before* the workflow continues.

### Cold-start vs brownfield-extension modulation

The cold-start case is the norm. The original lock of this ADR implicitly calibrated to the warm-start case: a project with months of upstream architectural work that supplied Frame-quality substrate. Most projects do not start there; running agent-only Frame against a thin substrate would invent or stop. This surfaced during a warm-start project's first run through Stage 2 (Frame): the output was good *because* the warm-start substrate was sufficient. For cold-start projects the same path would fail.

Modulation is **novelty-keyed.** Alignment with the existing Lightweight path (intent-size keyed) gives one collapse rule with two discriminators:

| Discriminator | Heavy (default) | Light (collapse) |
|---|---|---|
| Intent size | Multi-cluster, principle-crossing | Small, single-cluster, principles cover cleanly |
| Frame novelty | New project OR new architectural surface OR Frame-altering feature | Extension of an established Frame within an existing project |

When BOTH discriminators land light, the full collapse fires (the existing Lightweight path). When either lands heavy, the heavier shape applies: Stage 2a elicitation + the Frame-exit gate are in.

**Detection at Stage 0:** load the project's existing Frame doc (if any) plus the last `/brief` run telemetry. Brownfield-extension is detected when a Frame doc exists for the target project AND the intent does not propose architectural-surface changes; the collapse fires. Otherwise default to heavy. The Project alignment audit (Stage 1 sub-process) already detects Frame-artifact presence; modulation reuses that signal.

### Calibration phase + re-evaluation tripwire

This shape is heavier-touchpoint than the original lock. The shape is **calibration**, not the final answer. The decomposer does not yet know which Frames would be rejected vs. nit-resolved vs. rubber-stamped at the Frame-exit gate. Operating heavy now is intentional over-pay; the tripwire prevents calcification.

**Tripwire:**

- **N = 5 cold-start Frame-exit reviews** (the cohort). Tracked on per-run telemetry as a per-stage flag.
- **At N, refit:** the decomposer reviews the catch-rate: how often was the Frame revised at Frame-exit vs. accepted as-is? Were the revisions things downstream code+security review would have caught anyway?
- **Brownfield expectation:** a higher skip-rate than greenfield (the architecture is stable). If brownfield-extension is *always* triggering the full heavy shape, the modulation rule is not detecting correctly; investigate detection, not the rule.
- **Greenfield expectation:** a lower skip-rate. If the decomposer is *always* skipping Frame-exit on greenfield too, that is the calibration signal saying the gate has converged on rubber-stamp; refit gate density downward.

**Refit options at N:** (a) keep gate density unchanged if the catch-rate justifies it; (b) collapse the Frame-exit gate to a notification (the decomposer is told the Frame is ready, no blocking review); (c) full collapse to the original two-touchpoint shape; (d) tighten further if the catch-rate evidence shows downstream review is not catching what Frame-exit catches.

Per the calibration-bias meta-rule this instances: bias toward more touchpoints during calibration; relax case-by-case as evidence accumulates; the tripwire prevents calcification.

### `/verify` — paired with `/brief`; four-signal verification

| Signal | Source | Type | Notes |
|--------|--------|------|-------|
| Tests pass | Generated from the spec | Mechanical | Per the testing philosophy `P-TDDPairs` |
| PBT pass | Property-based tests on spec invariants | Mechanical | Catches spec-vs-impl drift |
| Intent-conformance review | Agent (security-and-correctness-lensed) | Mechanical (a hard step, current posture) | Confirms the impl satisfies intent, not just the spec — bridges the "passing tests on a lookup table" failure class |
| Spot check | Decomposer | Human | Scales with trust; can lighten as the loop converges |

Three mechanical signals + one human signal. `/verify` consumes the spec produced by `/brief` under a shared schema contract. Intent-conformance review is a hard step at current posture; revisit when the loop has accumulated enough signal to soften it.

### Constraint graph

A graph view (not a stack) over Principles, Values, Ecosystem ADRs, Project ADRs, and per-task constraints.

- **Nodes:** Principles, Values, Ecosystem ADRs (G-prefix), Project ADRs (P-prefix), per-task constraints.
- **Edges:** `specializes`, `depends-on`, `conflicts-with`, `refines`.
- **Source-of-truth pattern:** view-with-explicit-edges-file. Principles and ADRs remain primary in their existing locations. A `constraint-edges.md` file declares relationships (markdown for now; promotion to a structured format deferred to friction-driven need).
- **Traversal rule:** most-specific applies when no conflict (per-task > project ADR > ecosystem ADR > principle). Conflicts escalate at intersection points (the review-pass surface).

### Pause-and-escalate triggers (the only legitimate human-in-loop re-entry between gates)

The triggers below are a **starter set, not a closure**. Per the meta-frame, structure applies at points where drift occurs; new triggers will be discovered through friction. The learning loop (below) classifies missed triggers as a discrete error class and adds them to this list. Treat the table as living, not exhaustive.

| Trigger | Action |
|---------|--------|
| Principle conflict during any stage | Pause, escalate, single-decision walk |
| Intent ambiguity unresolvable from current inputs | Pause, escalate, re-elicit |
| Novel decision setting cross-project precedent | Pause, escalate, single-decision walk |
| Substrate pivot that would invalidate locked artifacts in the session | Hard stop, capture as a gap note, stash, retro |

Routine decisions (within principles, no rework of done work) execute inline; agents batch them and report at the next exit gate. This implements `P-TrustThenRetro` (direction set up-front, the team executes within direction, the decomposer's review concentrated on outcomes and patterns).

### Learning loop — error-classification

Post-deploy errors (and workflow drift caught in-session) classify into deterministic update targets:

| Error class | Artifact to update | Forward-port to |
|---|---|---|
| Missed test case | Add a test | `/brief` Stage 3 test-generation step |
| Missed spec scenario | Add to the spec | `/brief` Stage 2 (frame-exit checklist) |
| Missed principle implication | Add to principles or an ecosystem ADR | `/brief` Stage 1 validation pass |
| Missed constraint | Add to the constraint graph | `/brief` Stage 2 graph walk |
| Principle right, mechanism wrong (incl. maintenance disciplines: blast-radius limiting, locality, constants over inline strings, abstraction boundaries) | Refine the principle's "How it shows up" or add a design note; if the discipline is not in principles+values at all, add it | `/brief` Stage 2 mechanism selection; `/brief` Stage 3 spec |
| Missed pause-and-escalate trigger | Add a new trigger to the table | `/brief` pause-trigger list |

Each error class has a deterministic update target. The loop is mechanical, not ad-hoc, ending the trial-and-error posture on workflow design. The table itself is expected to grow; new error classes are added when classification surfaces a category that does not fit existing rows.

### Naming

- **`/brief`:** replaces `/discover` and forward-direction `/architect`. The unified workflow.
- **`/verify`:** a new skill; paired with `/brief`.
- **`/architect`:** forward-direction retired (replaced by `/brief`). The audit / reverse-engineering direction (scan an existing codebase + `/brief` output → architecture docs, ADRs, design notes) survives as a concept but is **deferred, not built**. The legacy `/architect` skill file is archived alongside `/discover`, `/spec`, and `/clarify` as harvest input, not retained as an operational skill in the interim.
- **`/clarify`:** absorbed into the `/brief` intake review pass.
- **`/spec`:** absorbed as `/brief` Stage 3; the existing skill file may remain as the implementation behind Stage 3.

### Canonical entry (addendum)

`/brief` is the single canonical entry for any work that produces a spec. Standalone invocation of `/discover`, `/spec`, or `/clarify` as a canonical entry point defeats canonical status, even where each still functions. Those skills survive only as **internal mechanisms** reused by `/brief` stages: the `/spec` core as Stage 3, `/clarify`'s confidence loop as the intake review iteration. Internal mechanism-reuse is consistent with `P-Defer` (defer a mechanism until evidence forces it) and minimum-blast-radius; a parallel canonical door is not.

Rationale: `/brief` is the one mechanism every spec-producing change routes through indefinitely; a defect or a bypass is multiplied across every future feature and product. Implied-by-naming ("replaces /discover and forward /architect") is too weak a peg for that load-bearing status; this addendum makes the exclusivity explicit. The recursion across feature/product altitudes (in the `/brief` skill) does not create a second entry; it is one door with an altitude argument.

## Alternatives Considered

**Keep the `/discover → /architect → /spec` triad, amend in place.** The shape itself encodes human-elicitation; amendments would be patches over a wrong-shaped contract. The three substrate-level pivots in one architecture session evidenced this. Rejected.

**Three separate skills (`/intent`, `/frame`, `/spec`) instead of a unified `/brief`.** Composable: re-run `/frame` without re-doing intent when principles shift. Rejected because the agent-first contract demands fewer human touchpoints by design; three skills means three exit gates, defeating "out of the loop unless required." A unified `/brief` bakes the contract into the shape.

**A stack-based constraint hierarchy (most-specific wins).** Rejected because principle dimensions are independent axes (Determinism, Atomicity, Operability, etc.) that do not override each other but apply orthogonally. A graph captures specialization-vs-orthogonal correctly; a stack flattens it.

**An independent `/verify` (not paired with `/brief`).** More flexible: `/verify` works on any artifact, including legacy. Rejected (for now) because the agent-first contract demands deterministic verification, which demands a shared schema between producer and verifier. Independence invites schema drift. Revisit when `/verify`-on-legacy becomes a real use case.

**Principle-conflict as a separate downstream gate.** Rejected because conflicts caught downstream require re-walking the work that violated them. Catching at the input-review pass (and at every stage's review pass) eliminates the re-walk.

**Treat principles+values as latent context** (the current behavior, agents pick them up if asked). Rejected because a live session evidenced the failure mode: principles+values were not loaded at session start; the anchor layer was missing for the whole conversation until the decomposer caught it mid-session. Stage 0 is a mandatory load, not optional.

**A storage-substrate change (per-file MADR → a single-doc named-block format) within this ADR.** Considered as a recursive-dogfooding move. Rejected for this ADR's scope: storage vs. output are separate concerns. Output (the human view via mdBook) is addressed separately; storage stays per-file MADR for now. The locks here are workflow shape, not storage format.

## Consequences

**Positive:**

- Two human touchpoints per `/brief` run (intake + spec exit), down from N. Aligns with "out of the loop unless required."
- Principles and values are loaded as baseline at Stage 0; the anchor gap that hurt earlier sessions is closed by structure, not by vigilance.
- Spec quality is explicit load-bearing input; the workflow's real job is now nameable and tunable.
- The verification stack is concrete (three mechanical + one human); it enables a measurement loop.
- The learning loop has deterministic update targets, ending trial-and-error on workflow design.
- The constraint graph makes principle-conflict detection machine-tractable.
- `/brief` + `/verify` form a contract; the schema can be enforced.
- Implements `P-TrustThenRetro` structurally; the workflow shape *is* the trust-then-retro composition.
- The cold-start case is now structurally accommodated (was: implicitly assumed away). Most projects do not start with a warm-start substrate.
- The Frame is reviewed *as architecture*, not as an agent-produced artifact. The Frame-exit gate is the load-bearing checkpoint at the level where decisions are hardest to reverse.
- The calibration phase is structurally bounded (a re-evaluation tripwire); workflow design moves out of a trial-and-error posture on its own meta-shape.
- Novelty modulation prevents over-serving brownfield-extension work, where the architecture is already framed and stable.

**Negative:**

- Unified `/brief` is heavier per-run than a lightweight `/clarify`; small features may feel over-served. Mitigation: Stage 1 + Stage 2 collapse fast when intent is small and principles cover it cleanly; the heaviness is proportional to the work, not fixed.
- Intent-conformance review is new agent work; it needs design and instrumentation.
- The constraint graph + edges file is new infrastructure; initial population is hand-work.
- Existing skill files (the legacy discover/spec/architect definitions) need rewrite + retirement. Migration is opportunistic per `P-WriteTimeAudience` (the write-time-audience discipline); touch when adjacent work occurs.
- Cross-project specs and ADRs that referenced the old triad need updating opportunistically; not blocking.
- The `/architect` (audit direction) skill survives standalone but needs its own scope clarification, separate from the forward-direction workflow.
- The cold-start touchpoint count is 3 (intake + Frame-exit + spec-exit), not 2. The "out of the loop unless required" driver is honored more conservatively in the cold-start case; the modulation restores the two-touchpoint shape for brownfield-extension where it still applies.
- The Stage 2a elicitation loop is new; it needs design and instrumentation. Mechanism reuse from `/clarify`'s 95%-confidence loop is plausible but unverified at Stage 2 scale.
- Novelty detection at Stage 0 depends on the Project alignment audit detecting Frame-artifact presence correctly; modulation reliability rides on that audit.

**Downstream / open work:**

- Intake schema design (the JTBD (jobs to be done) + non-goals + success criteria + hard constraints schema): a separate task.
- Constraint graph initial population: a separate task; a markdown edges file.
- `/brief` skill draft: implementation; this ADR locks the shape.
- `/verify` skill draft: implementation; intent-conformance review process design.
- Per-run telemetry update: per-stage flags within `/brief`.
- ADR-vs-design-note criterion codification: a separate task.
- mdBook aggregation for ADRs: downstream of `/brief` Stage 3.
- **Add Maintainability as a core value** in `architecture-values.md` (with a downstream principle if needed). The unit goal is **minimum-blast-radius fix**: when a change is needed, isolate it as much as possible; the codebase architecture supports isolation. When the minimal fix would require a large rewrite, that signals a deeper architectural problem; fix the immediate issue minimally, then surface the restructure as a follow-on task. Even with AI-generated code (where the impl style is plastic), minimum-blast-radius is the discipline that prevents collateral breakage. The value sits in `architecture-values.md`; mechanism details live in the implementer skills and profiles (concrete rules on abstraction, locality, constants vs. inline strings, module boundaries); the review surface is the operations-lensed reviewer, added to the rotation where maintainability is a load-bearing concern.
- **Research on maintainable-software rules:** survey established practices (blast-radius limiting, locality, abstraction discipline, change-isolation patterns, module boundaries, naming, constants). The output feeds the Maintainability value's "How it shows up" section and the implementer-skill mechanism details.
- **Add the meta-frame as a value** in `architecture-values.md`: *"Apply structure at points where drift occurs. Blend the strengths of human and agent work; bound the failure modes of each."* Load-bearing rationale for the `/brief` shape; promoted from an inline citation to first-class status so it shapes other decisions.
- Cross-references in `architecture-principles.md` and `architecture-values.md` to `/discover` / `/architect` need updating to `/brief` at the next touch.

## Amendment — designed-tier vs committed-tier separation

A lifecycle-tier framing locked in a product brief defines a feature register with five tiers: `idea`, `proposed`, `designed`, `committed`, `live`. `designed` = a locked Frame + a locked Spec exists. `committed` = `designed` + a plan, release-bound.

**Stage 3 produces the designed-tier artifact (the Spec) only. Tasks belong to the committed-tier plan, not the Spec.**

Concretely:

- **The `/spec` core is reused at Stage 3** (spec type, template selection, RFC-2119 language, out-of-scope, scenarios, data model, API contract, UI behavior, the Verify Contract).
- **The `/spec` task-decomposition step is excluded from Stage 3 reuse.** Tasks, per-task acceptance criteria, test expectations, files/dependencies, and release-binding are committed-tier artifacts.
- **Plan-doc convention:** committed-tier plans live in a per-project plans location, authored from a plan template. Plans are transient (target-release-scoped) and archive out when the feature lands `live`. Per `P-CompositionBridge` (the durability-tier rule), transient build artifacts (plan + audit) home in the project's knowledge store, not the repo; only the durable spec stays repo-side.
- **Plan authorship is not a `/brief` Stage.** It is its own workflow step at the `designed` → `committed` transition. The plan references the locked Spec it implements but is authored separately.
- **Verify Contract update:** `/verify`-at-spec-stage consumes requirements + scenarios + out-of-scope + data model + API contract. Per-task acceptance criteria and test expectations are the plan-stage `/verify` surface, not the spec-stage.

**Why the amendment.** Caught at a spec-exit gate: a V0 substrate Spec carried a `## Tasks` section inherited from the `/spec` template content, collapsing the designed-tier and committed-tier into a single artifact. The decomposer identified that the tier-collapse had occurred before; the structural fix is to align `/brief` Stage 3 with the lifecycle-tier framing rather than rely on review-catch. Composes with the spec-owns-scope / plan-owns-sequencing separation.

## Changelog

- Canonical-entry addendum: an explicit standalone-defeats-canonical statement; `/brief` recursive across feature/product altitudes is one door, not two.
- Naming truth-fix: `/architect` no longer "stays in place under an interim shape." Forward-direction retired; audit-direction deferred (the concept survives, not built); the legacy skill file archived as harvest input.
- Cold-start amendment: explicit cold-start-vs-warm-start framing; a Stage 2a pre-Frame elicitation sub-stage added (a `/clarify`-style 95%-confidence loop); the Frame-exit human gate restored for cold-start runs (cold-start touchpoint count 2 → 3); the novelty-keyed modulation rule aligned with the existing Lightweight path; the calibration tripwire baked in (N=5 cold-start Frame-exit cohort, refit at N). The original two-touchpoint lock was calibrated to the warm-start case; cold-start is the norm.
- Designed-tier vs. committed-tier amendment: Stage 3 produces the designed-tier Spec only; the `/spec` task-decomposition step is excluded from reuse; tasks live in the committed-tier plan; the Verify Contract drops per-task acceptance criteria and gains the data model + API contract. The lifecycle-tier framing locked in a product brief is the canon source. (Plan-path placement is governed by `P-CompositionBridge`.)
