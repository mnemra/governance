---
title: Constraint Edges
summary: "Edges view over the workspace constraint graph — relationships between values, principles, and workspace ADRs."
primary-audience: agent
---

# Constraint Edges

> Living doc. Declares relationships between architecture values (`architecture-values.md`), principles (`architecture-principles.md`), and workspace ADRs (`adrs/G-*.md`) in the workspace constraint graph.

## How to use this doc

Three audiences read these edges:

- **The decomposer** (the role that figures out what to build before execution: framing a design session, drafting an ADR, writing a spec, cutting scope) consults during the Frame stage of a brief. Frame is the stage that elicits and synthesizes the problem shape before a spec is written. The graph walk traverses these edges to surface constraints that bear on a proposed decision.
- **The agentic team** (the specialists the orchestrator dispatches to) consults at every review pass. Finding identity, the tuple that decides whether two review findings are the same defect, often resolves to "X conflicts with Y per this edge," and recommendations cite the edge that grounds them.
- **Future maintainers** consult when extending a principle, adding an ADR, or adopting a new value. The existing edges show where the new artifact fits structurally.

Nodes stay primary in their existing locations: the values doc, the principles doc, and `adrs/G-*.md`. This file is the **edges view** over those primaries, per the source-of-truth pattern set in G-0028 (the governance ADR that defines the agent-first workflow shape and the edge-graph conventions). A Markdown table is the format for now. Promotion to something more structured, a graph database or a query language, waits until friction forces it.

## Edge types

Per G-0028:

| Type | Meaning |
|------|---------|
| **specializes** | Source is a specific case of target. (e.g., a principle specializes a value; an ADR specializes a principle.) Most common edge. |
| **depends-on** | Source presupposes target. Removing the target breaks the source's mechanism. |
| **conflicts-with** | Source and target can't both hold without negotiation. Surfaces at review-pass intersection points. Resolution: name the axis, present both, decomposer decides. |
| **refines** | Source tightens target. Same domain, narrower scope. Often appears when an ADR refines a principle's "How it shows up" with concrete mechanism. |

Traversal rule (per G-0028): the most-specific node applies when there's no conflict (per-task > project ADR > workspace ADR > principle). Conflicts escalate at intersection points.

## Specializes

### Principle → Value (from each principle's "Anchors" header)

The source of each edge is a principle. The target is an architecture value or, in a few cases, another principle. The values the rows point at include the eight core values plus supporting ones like Reversibility (keeping a change easy to undo) and Migration cost (the cost of moving to or away from a chosen mechanism). Each principle code below is glossed inline on its first appearance.

| Source | Target | Rationale |
|--------|--------|-----------|
| P-Defer (defer the mechanism choice until evidence forces it) | Simplicity | "Defer mechanism until evidence forces the choice" is a specific case of "smallest mechanism that solves the problem." |
| P-Defer | Reversibility | Deferred mechanisms keep options open. The mitigation path includes "don't adopt yet." |
| P-PerRepoFirst (keep a thing per-repo until reuse is observed) | Simplicity | Per-repo-first avoids the workspace artifact every reader has to reason about. |
| P-PerRepoFirst | Migration cost | Premature extraction inflates migration cost. Per-repo-first defers extraction until reuse shows up. |
| P-LockContract (lock the interface so implementations can vary) | Simplicity | Contract locking lets implementations vary without rippling through callers. It's the smallest stable interface. |
| P-LockContract | Migration cost | Stable contracts let implementations migrate without coordinating consumers. |
| P-LockContract | Rust-ecosystem alignment | Trait-based contract locking is idiomatic Rust. |
| P-StackDiscipline (reject tooling that misaligns with the stack) | Rust-ecosystem alignment | Direct operationalization. Reject ecosystem-misaligned tooling. |
| P-SecurityLayered (compose security in independent layers) | Security | Direct operationalization. Security composes by layer. |
| P-InstrumentBefore (ship instrumentation before first user-touch) | Observability | Direct operationalization. Instrumentation ships before first user-touch. |
| P-Worktrees (do code-modifying work in a discardable worktree) | Reversibility | Worktrees keep main stable. Failed work is discardable. |
| P-Worktrees | Decomposition | Worktrees enable parallel dispatch, and the dispatch model decomposes work across agents. |
| P-MainProtected (gate main behind PR plus CI) | Reversibility | The PR plus CI gate keeps the mitigation surface intact. |
| P-MainProtected | Quality | The gate exists to enforce quality before main. |
| P-ShiftLeft (catch problems at intent-time, not merge-time) | Reversibility | Catching at intent-time is cheaper than catching at merge-time. |
| P-ShiftLeft | Decomposition | The decomposer's eye is the structural-intent check automated gates can't make. |
| P-TDDPairs (split a task into a test-writer and an impl-writer) | Quality | Spec-derived tests catch impl-vs-spec drift that single-agent TDD doesn't. |
| P-TDDPairs | Decomposition | A TDD pair is a decomposition of one task into test-writing and impl-writing dispatches. |
| P-IterateToZero (run fix-and-review rounds until no blocking finding remains) | Quality | Convergent fix loops with stable identity drive defect counts to zero. |
| P-IterateToZero | Reversibility | The round cap is itself a reversal trigger. Escalate rather than grind. |
| P-HeterogeneousReviewers (review with distinct lenses, not one repeated) | Honesty | Multiple distinct lenses surface different findings. Single-lens reviews launder blind spots. |
| P-HeterogeneousReviewers | Quality | Distinct lenses catch defects each lens alone would miss. |
| P-PreserveDecisionSpace (keep rejected alternatives visible) | Honesty | Erasing rejected alternatives makes future decisions blind, which is a form of dishonesty about the decision space. |
| P-PreserveDecisionSpace | Decomposition | Decomposition relies on the option space being visible at framing time. |
| P-WriteTimeAudience (write each artifact for its durability profile at write-time) | Honesty | Genericizing repo artifacts at write-time prevents publish-leak. Preserving attribution on workspace-private artifacts prevents pattern-signal loss. |
| P-WriteTimeAudience | Dogfooding | The dual durability profile is what makes workspace artifacts useful as a forcing function. |
| P-TrustThenRetro (set direction up-front, review outcomes after) | Dual-audience | The principle is *about* the composition. Direction is set up-front, and the team executes within it. |
| P-TrustThenRetro | Quality | Concentrating review on outcomes, not on each flag, is what makes the workflow sustainable. |
| P-TrustThenRetro | Composition | Direct operationalization. It's the protocol mechanism for the Composition value, paired with P-CompositionBridge's substrate mechanism. |
| P-CompositionBridge (carry session-level signal into durable, reloadable artifacts) | Composition | Direct operationalization. It's the substrate mechanism for the Composition value, paired with P-TrustThenRetro's protocol mechanism. |
| P-CompositionBridge | Dogfooding | The two-durability-profile discipline (workspace-private vs publish-ready artifacts) is what makes the substrate work as a forcing function. |
| P-MinBlastRadius (isolate a fix to the smallest surface) | Maintainability | Direct operationalization. The minimum-blast-radius fix is the value's stated unit goal. |
| P-MinBlastRadius | Reversibility | Bounded change cost keeps the mitigation surface intact. Small changes are easier to revert. |

### ADR → Principle or Value (workspace ADRs, obvious specializes)

| Source | Target | Rationale |
|--------|--------|-----------|
| G-0001 (testing philosophy) | P-TDDPairs | Codifies branch-delta plus property-based testing as gates with an inverted pyramid. Concrete mechanism for the TDD-pairs discipline. |
| G-0001 (testing philosophy) | Quality | Testing standards as the quality floor. |
| G-0002 (no compile-time embedding) | P-Defer | Defers the asset-embedding mechanism in favor of ServeDir plus Docker. Simpler, with an evidence-driven revisit later if needed. |
| G-0003 (ADR two-tier system) | P-PreserveDecisionSpace | Two-tier ADRs (G-workspace, P-project) preserve decision lineage across scope levels. |
| G-0004 (XML agent profiles) | Dual-audience | The XML profile format reads cleanly for humans and parses reliably for agents. |
| G-0005 (SQL file migrations) | Reversibility | File-based migrations are reversible, encoded in `up`/`down` pairs. |
| G-0006 (Justfile as CI contract) | P-LockContract | The Justfile is the single contract. The runner (hosted, self-hosted, or local) is swappable. |
| G-0007..G-0012 (knowledge-extraction series) | P-CompositionBridge | Encodes session-level pattern signal into durable artifacts loadable in future sessions. P-CompositionBridge is the operationalizing principle, and the series specializes the substrate mechanism. The Composition value stays reachable transitively through P-CompositionBridge. |
| G-0013 (Stage 6 approval label vocabulary) | P-ShiftLeft | The closed-enum vocabulary moves decomposer intent into a state machine that later gates can read. |
| G-0014 (review finding identity and persistence) | P-IterateToZero | Content-anchored finding identity is what makes iterate-to-zero converge across rounds. |
| G-0015 (devcontainer per-repo upstream base) | P-PerRepoFirst | A per-repo devcontainer with a shared upstream. Extraction only at the base layer. |
| G-0016 (layered secret detection) | P-SecurityLayered | Direct operationalization of the runtime layer. |
| G-0017 (feature flags FlagProvider trait) | P-LockContract | A trait in front of the feature-flag backend lets the backend swap without touching call sites. |
| G-0018 (workspace merge template + recovery cap) | P-Worktrees | Concrete lifecycle for worktree merges, including failure recovery. |
| G-0019 (tag race serialization) | Reversibility | No lost work under concurrent tag operations. |
| G-0020 (Rust release-plz) | P-StackDiscipline | Stack-aligned release tooling. |
| G-0021 (monotonic non-decreasing version policy) | Honesty | Versions don't lie about progression. |
| G-0022 (embargo flow architecture) | Security | The embargo flow protects pre-disclosure work. |
| G-0023 (GitHub merge queue) | P-MainProtected | Direct operationalization of the merge gate. |
| G-0024 (Stage 6 label authorization) | P-ShiftLeft | Authorization on the state machine gates intent earlier. |
| G-0025 (internal IPC typed binary encoding) | P-LockContract | The typed schema is the locked contract. |
| G-0026 (project dev-docs tooling) | Dual-audience | Dev docs serve both the decomposer and agents reading docs cold. |
| G-0027 (agent-primary source artifacts) | Decomposition | Source artifacts are for agents, with human views derivative. This preserves the decomposer's role as direction-setter. |
| G-0027 (agent-primary source artifacts) | Dual-audience | An explicit dual-audience model with agents as the primary consumer. |
| G-0028 (agent-first workflow shape) | Composition | The workflow shape blends human and agent strengths, applying structure where drift occurs. |
| G-0028 (agent-first workflow shape) | Decomposition | The Stage 1 and Stage 3 gates (intake-exit and spec-exit) preserve the decomposer's structural role. |

## Depends-on

| Source | Target | Rationale |
|--------|--------|-----------|
| P-IterateToZero | P-HeterogeneousReviewers | Stable finding identity requires distinct reviewer lenses. The same model on the same prompt produces identity collapse. |
| P-TDDPairs | P-HeterogeneousReviewers | A TDD pair *is* a heterogeneous pair (test-writer plus impl-writer). The same agent produces contamination. |
| P-Worktrees | P-MainProtected | Worktrees solve the main-stability problem that main protection enforces. Remove main protection and worktrees turn decorative. |
| P-ShiftLeft | P-PreserveDecisionSpace | The decomposer's intent check operates on the full option space. Erased alternatives produce a blind gate. |
| G-0028 (agent-first workflow) | G-0027 (agent-primary source artifacts) | G-0028 names this dependency in its prose. A workflow that produces agent-primary artifacts presupposes the artifacts-are-agent-primary stance. |
| G-0023 (merge queue) | G-0006 (Justfile as CI contract) | The merge queue runs the Justfile recipe. Without the contract, the queue has no canonical gate. |
| G-0014 (finding identity) | G-0001 (testing philosophy) | Finding identity assumes the test gates from G-0001 fire on changes. Without the gates, the identity has nothing to anchor against. |
| G-0017 (FlagProvider trait) | P-LockContract | The trait is the lock. The principle is the rationale. |
| G-0007..G-0012 (knowledge-extraction) | G-0008 (capture schema) | The series builds on a shared schema. The capture schema is the load-bearing root. |
| Composition (value) | Decomposition (value) | "Decomposition tells you what to build; Composition is how the team that builds it stays coherent." Composition presupposes decomposition has happened. |

## Refines

| Source | Target | Rationale |
|--------|--------|-----------|
| G-0024 (Stage 6 label authorization) | G-0013 (Stage 6 approval label vocabulary) | G-0024 tightens authorization rules on the label vocabulary G-0013 introduced. |
| G-0028 (agent-first workflow) | Decomposition | G-0028's mandatory Stage 0 baseline-load tightens the value's "scope known before the first dispatch" claim into a concrete workflow step. Same domain, narrower mechanism. |
| G-0014 (finding identity) | P-IterateToZero | The concrete identity tuple definition narrows what counts as the "same finding across rounds." |
| G-0028 (agent-first workflow) | P-TrustThenRetro | The workflow shape *is* the structural implementation of trust-then-retro. Same principle, narrower mechanism. |
| G-0022 (embargo flow) | P-SecurityLayered | The embargo flow refines the design-time layer with disclosure-window mechanics. |
| G-0006 (Justfile as CI contract) | P-StackDiscipline | The Justfile choice over alternatives like Make or scripts refines stack-discipline at the build-tooling layer. |

## Conflicts-with

Per the `architecture-values.md` conflict-resolution table, two-core trade-offs surface the axis rather than pre-resolving it. The pairs below are *known tension points*. They aren't blockers; they're escalation surfaces for the review pass.

| A | B | Tension axis | Resolution posture |
|---|---|--------------|---------------------|
| Security | Simplicity | "Each layer is load-bearing" vs "smallest mechanism" | Name the axis. Default to Security per "default-on, never opt-in." |
| Observability | Simplicity | Instrumentation cost vs minimum mechanism | Name the axis. Default to Observability for production surfaces. |
| Observability | Security | Logs leak secrets if untreated | P-SecurityLayered's runtime layer handles this via redaction discipline. |
| Quality | Cost (situational, not a core value but a weighting axis) | Quality outranks cost as default | Surface the cost override explicitly: "doing this at quality cost X because Y." |
| Simplicity | Migration cost | A clever simpler abstraction may be harder to migrate to or away from | Per-repo first, per P-PerRepoFirst. Defer the migration cost by deferring the abstraction. |
| Honesty | Dogfooding | Workspace-private attribution preserves pattern signal; repo artifacts get genericized | P-WriteTimeAudience resolves it with two durability profiles and two disciplines. |
| P-Defer | P-InstrumentBefore | "Don't add until evidence forces" tension with "ship instrumented before launch" | P-InstrumentBefore wins for production surfaces. Observability is the evidence-gathering mechanism that makes deferral safe elsewhere. |

## Notes on this initial walk

- **Coverage:** 7 core values plus 5 supporting values plus 15 named principles plus 28 G-ADRs. The edges below are *obvious* per the initial walk framing, not exhaustive. Add edges as work surfaces them.
- **Composition value is recent (2026-05-13).** G-0028's specializes-Composition edge is load-bearing. Expect that node to gain edges as the workflow lands.
- **Maintainability value adopted 2026-05-13.** P-MinBlastRadius lands as the operationalizing principle. Stack-specific extensions live in the implementer stack skills' `<maintainability>` sections, which are skill content rather than nodes.
- **ADR-to-ADR depends-on edges are sparse.** Most ADRs anchor on a principle or value rather than another ADR. The G-0023 → G-0006 and G-0014 → G-0001 edges are the load-bearing cross-ADR dependencies. Others may surface during graph walks.
- **Refines vs specializes** is a continuum. "Narrower scope" can read as either. This walk used `refines` when the source narrows the *mechanism* the target named, rather than adding a new case to a class.

## Scope rules (resolved 2026-05-13)

1. **Project P-ADR edges live in per-project files.** Each project bootstraps `<project>/docs/src/adrs/constraint-edges.md` once it accumulates around 5 P-ADRs. The per-project file extends this one via `specializes` edges to G-ADRs. The workspace file stays clean.

2. **Skills are not nodes in the constraint graph.** Stack skill files operationalize principles. They're the mechanism layer, not the constraint layer. When a skill rule conflicts with a principle or another constraint, surface the conflict edge back into this file at discovery time. Skill files are referenced by name in the rationale, but there are no per-skill nodes.

3. **Principle-pair conflict walks are surfacing-driven.** There's no systematic walk of principle pairs for tensions. Conflict edges get added when a review pass or graph walk forces them. This aligns with P-Defer.

4. **G-0007..G-0012 → Composition holds at series level for now.** A per-ADR second pass for more-specific principle anchors is deferred. The Composition edge stays. Finer anchors land when a graph walk needs them.

## Changelog

- **2026-05-15:** P-CompositionBridge principle landed. Added P-CompositionBridge → Composition (specializes) plus P-CompositionBridge → Dogfooding (specializes) anchoring edges; added P-TrustThenRetro → Composition (specializes, the paired protocol mechanism); re-anchored the G-0007..G-0012 series from the Composition value direct to P-CompositionBridge (Composition still reachable transitively).
- **2026-05-13:** Maintainability value plus P-MinBlastRadius principle landed. Added Maintainability and P-MinBlastRadius nodes via anchoring edges.
- **2026-05-13:** Initial walk. 28 G-ADRs plus 15 principles plus 12 values walked for obvious specializes/depends-on/refines edges and known value-level conflicts. Composition plus Maintainability nodes flagged for population as those values land in `architecture-values.md`.
- **2026-05-13:** Open questions resolved: the per-project P-ADR file pattern is locked, skills are out of scope as nodes, the conflict walk is surfacing-driven, and the G-0007..G-0012 per-ADR pass is deferred. The initial walk is now stable.
