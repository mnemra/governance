---
title: Constraint Edges
summary: "Edges view over the workspace constraint graph — relationships between values, principles, and workspace ADRs."
primary-audience: agent
---

# Constraint Edges

> Living doc. Declares relationships between architecture values (`architecture-values.md`), principles (`architecture-principles.md`), and workspace ADRs (`adrs/G-*.md`) in the workspace constraint graph.

## How to use this doc

Three audiences read these edges:

- **The decomposer** consults during the Frame stage of a brief — the graph walk traverses these edges to surface constraints that bear on a proposed decision.
- **The agentic team** consults at every review pass — finding identity often resolves to "X conflicts with Y per this edge"; recommendations cite the edge that grounds them.
- **Future maintainers** consult when extending a principle, adding an ADR, or adopting a new value — the existing edges show where the new artifact fits structurally.

Nodes remain primary in their existing locations (values doc, principles doc, `adrs/G-*.md`). This file is the **edges view** over those primaries — per G-0013's source-of-truth pattern (the agent-first workflow ADR). Markdown table is the format for now; promotion to a more structured representation (graphdb, query language) defers to friction-driven need.

## Edge types

Per G-0013 (agent-first workflow):

| Type | Meaning |
|------|---------|
| **specializes** | Source is a specific case of target. (e.g., a principle specializes a value; an ADR specializes a principle.) Most common edge. |
| **depends-on** | Source presupposes target. Removing the target breaks the source's mechanism. |
| **conflicts-with** | Source and target can't both hold without negotiation. Surfaces at review-pass intersection points. Resolution: name the axis, present both, decomposer decides. |
| **refines** | Source tightens target. Same domain, narrower scope. Often appears when an ADR refines a principle's "How it shows up" with concrete mechanism. |

Traversal rule (per G-0013): most-specific applies when no conflict (per-task > project ADR > workspace ADR > principle). Conflicts escalate at intersection points.

## Specializes

### Principle → Value (from each principle's "Anchors" header)

| Source | Target | Rationale |
|--------|--------|-----------|
| P-Defer | Simplicity | "Defer mechanism until evidence forces the choice" is a specific case of "smallest mechanism that solves the problem." |
| P-Defer | Reversibility | Deferred mechanisms preserve optionality — the mitigation path includes "don't adopt yet." |
| P-PerRepoFirst | Simplicity | Per-repo-first avoids the workspace artifact every reader has to reason about. |
| P-PerRepoFirst | Migration cost | Premature extraction inflates migration cost; per-repo-first defers extraction until reuse is observed. |
| P-LockContract | Simplicity | Contract locking lets implementations vary without rippling through callers — the smallest stable interface. |
| P-LockContract | Migration cost | Stable contracts let implementations migrate without coordinating consumers. |
| P-LockContract | Rust-ecosystem alignment | Trait-based contract locking is idiomatic Rust. |
| P-StackDiscipline | Rust-ecosystem alignment | Direct operationalization — reject ecosystem-misaligned tooling. |
| P-SecurityLayered | Security | Direct operationalization — security composes by layer. |
| P-InstrumentBefore | Observability | Direct operationalization — instrumentation ships before first user-touch. |
| P-Worktrees | Reversibility | Worktrees keep main stable; failed work is discardable. |
| P-Worktrees | Decomposition | Worktrees enable parallel dispatch; the dispatch model decomposes work across agents. |
| P-MainProtected | Reversibility | PR + CI gate preserves the mitigation surface. |
| P-MainProtected | Quality | The gate exists to enforce quality before main. |
| P-ShiftLeft | Reversibility | Catching at intent-time is cheaper than catching at merge-time. |
| P-ShiftLeft | Decomposition | The decomposer's eye is the structural-intent check that automated gates can't make. |
| P-TDDPairs | Quality | Spec-derived tests catch impl-vs-spec drift that single-agent TDD doesn't. |
| P-TDDPairs | Decomposition | TDD pair is a decomposition of one task into test-writing and impl-writing dispatches. |
| P-IterateToZero | Quality | Convergent fix loops with stable identity drive defect counts to zero. |
| P-IterateToZero | Reversibility | The round cap is itself a reversal trigger — escalate rather than grind. |
| P-HeterogeneousReviewers | Honesty | Multiple distinct lenses surface different findings — single-lens reviews launder blind spots. |
| P-HeterogeneousReviewers | Quality | Distinct lenses catch defects each lens alone would miss. |
| P-PreserveDecisionSpace | Honesty | Erasing rejected alternatives makes future decisions blind — a form of dishonesty about the decision space. |
| P-PreserveDecisionSpace | Decomposition | Decomposition relies on the option space being visible at framing time. |
| P-WriteTimeAudience | Honesty | Genericizing repo artifacts at write-time prevents publish-leak; preserving attribution on workspace-private prevents pattern-signal loss. |
| P-WriteTimeAudience | Dogfooding | The dual durability profile is what makes workspace artifacts useful as forcing function. |
| P-TrustThenRetro | Dual-audience | The principle is *about* the composition — direction set up-front, team executes within direction. |
| P-TrustThenRetro | Quality | Concentrating review on outcomes (not per-flag) is what makes the workflow sustainable. |
| P-TrustThenRetro | Composition | Direct operationalization — protocol mechanism for the Composition value (paired with P-CompositionBridge's substrate mechanism). |
| P-CompositionBridge | Composition | Direct operationalization — substrate mechanism for the Composition value (paired with P-TrustThenRetro's protocol mechanism). |
| P-CompositionBridge | Dogfooding | The two-durability-profile discipline (workspace-private vs publish-ready artifacts) is what makes the substrate work as forcing function. |
| P-MinBlastRadius | Maintainability | Direct operationalization — minimum-blast-radius fix is the value's stated unit goal. |
| P-MinBlastRadius | Reversibility | Bounded change cost preserves the mitigation surface — small changes are easier to revert. |
| P-AgentPrimarySource | Decomposition | Source artifacts are for agents; human views derivative — preserves the decomposer's role as direction-setter. |
| P-AgentPrimarySource | Dual-audience | Explicit dual-audience model with agents as primary consumer. |
| P-LeadOrchestration | Composition | The lead owns work direction (control converges) while teammates exchange information peer-to-peer — the team-topology operationalization of Composition. |
| P-TrustworthySignal | Observability | Operationalizes the Observability value's faithful-instrument clause for the verification signal specifically (CI gate, test suite, coverage/lint, runner) — the fidelity-axis sibling to P-InstrumentBefore's timing/backfillable axis. |
| P-TrustworthySignal | Quality | A flaky gate is a quality defect in the verification apparatus — a nondeterministic signal on the gated merge line undermines the quality the gate exists to enforce. |
| P-TestableByDesign | Quality | Design-time injection seams let the test drive the real path cheaply and deterministically — the design-side complement to P-TDDPairs' test-authorship discipline and P-TrustworthySignal's no-flaky-infrastructure discipline. |
| P-TestableByDesign | Maintainability | The injection seam is usually the same structural lever as P-MinBlastRadius' change-isolation seam — a dependency injected behind a stable contract bounds change reach and enables the swap. |
| P-GuaranteeByMechanism | Quality | Enforcing a guarantee with a loud-failing mechanism (test, schema, type-token, hash, lint, hook) rather than a convention is what makes the quality guarantee actually hold — a violation fails visibly instead of silently no-opping. |
| P-GuaranteeByMechanism | Observability | The mechanism *fails loudly* — a guarantee's breach is observable rather than a silent no-op. The parent of DF1 (deferral firing), TS2 (coverage-scope reconciliation), and MB1's consolidation clause; see the parent walk-note below. |
| P-VerifyInheritedState | Honesty | Re-verifying an inherited claim against its source before acting preserves the known-vs-asserted distinction; a producer's assertion is not evidence, regardless of who produced it. |
| P-VerifyInheritedState | Reversibility | Verifying before acting on an inherited claim keeps a mitigation path open where acting on a false claim would foreclose one. |
| P-LeastAuthority | Security | Direct operationalization — a component/agent/credential holds the minimum standing authority its role requires; the authority-axis analogue of P-MinBlastRadius' change-isolation. |

### ADR → Principle or Value (workspace ADRs, obvious specializes)

| Source | Target | Rationale |
|--------|--------|-----------|
| G-0001 (ADR two-tier system) | P-PreserveDecisionSpace | Two-tier (G-workspace / P-project) ADRs preserve decision lineage across scope levels. |
| G-0002 (Justfile as CI contract) | P-LockContract | Justfile is the single contract; runner (hosted/self-hosted/local) is swappable. |
| G-0003 (merge governance) | P-ShiftLeft | The governing artifact carries the maintainer's review; the merge verifies the marker, not the PR — review shifted left. |
| G-0004 (review-finding identity and persistence) | P-IterateToZero | Content-anchored finding identity is what makes iterate-to-zero converge across rounds. |
| G-0005 (devcontainer per-repo upstream base) | P-PerRepoFirst | Per-repo devcontainer with shared upstream — extraction only at the base layer. |
| G-0006 (layered secret detection) | P-SecurityLayered | Direct operationalization of the runtime layer. |
| G-0007 (feature flags FlagProvider trait) | P-LockContract | Trait in front of feature-flag backend lets backend swap without touching call sites. |
| G-0008 (PR-merge apparatus) | P-Worktrees | Concrete worktree merge lifecycle including failure recovery. Multi-anchor node — see also the Reversibility and P-MainProtected edges below. |
| G-0008 (PR-merge apparatus) | Reversibility | Tag-race serialization — no lost work under concurrent tag operations. |
| G-0008 (PR-merge apparatus) | P-MainProtected | Single-merge-at-a-time merge queue is the merge gate. |
| G-0009 (Rust release apparatus) | P-StackDiscipline | Stack-aligned release tooling. |
| G-0009 (Rust release apparatus) | Honesty | Monotonic non-decreasing version policy — versions don't lie about progression. |
| G-0010 (embargo flow architecture) | Security | Embargo flow protects pre-disclosure work. |
| G-0011 (internal IPC typed binary encoding) | P-LockContract | Typed schema is the locked contract. |
| G-0012 (project dev-docs tooling) | Dual-audience | Dev docs serve both decomposer and agents reading docs cold. |
| G-0013 (agent-first workflow shape) | Composition | Workflow shape blends human and agent strengths; applies structure where drift occurs. |
| G-0013 (agent-first workflow shape) | Decomposition | The brief's intake-exit and spec-exit gates preserve the decomposer's structural role. |
| G-0014 (publish-time human render) | Dual-audience | The publish-time render pass is the mechanism serving the value's third audience (outside humans on a rendered docs site) while source self-containment stays with the in-workspace audience — the value's publish-boundary clause names it directly. |
| G-0015 (relational substrate default) | P-LockContract | The engine-agnostic `Storage` seam is the locked intrinsic contract; the engine (Postgres/SQLite) varies behind it. (Also specializes P-Defer for the deferred second adapter.) |
| G-0016 (unattended GitHub credential) | P-SecurityLayered | Scoped, short-lived, revocable app-installation tokens replace an account-wide key — the smallest-blast-radius credential discipline applied at the automation trust boundary. |
| G-0016 (unattended GitHub credential) | P-LeastAuthority | Scoped, short-lived, revocable app-installation tokens are the smallest-authority credential the automation loop can run on — least authority applied at the automation trust boundary. G-0016's first specialization on the authority axis (a multi-anchor node; it also specializes P-SecurityLayered on the layer axis). |

## Depends-on

| Source | Target | Rationale |
|--------|--------|-----------|
| P-IterateToZero | P-HeterogeneousReviewers | Stable finding identity requires distinct reviewer lenses; same model on same prompt produces identity collapse. |
| P-TDDPairs | P-HeterogeneousReviewers | TDD pair *is* a heterogeneous pair (test-writer + impl-writer); same agent produces contamination. |
| P-Worktrees | P-MainProtected | Worktrees solve the main-stability problem that main protection enforces. Removing main-protection makes worktrees decorative. |
| P-ShiftLeft | P-PreserveDecisionSpace | The decomposer's intent check operates on the full option space; erased alternatives produce a blind gate. |
| G-0013 (agent-first workflow) | P-AgentPrimarySource | G-0013 names this dependency in its prose — a workflow that produces agent-primary artifacts presupposes the artifacts-are-agent-primary stance. |
| G-0008 (PR-merge apparatus) | G-0002 (Justfile as CI contract) | The merge queue runs the Justfile recipe; without the contract, the queue has no canonical gate. |
| G-0003 (merge governance) | G-0016 (unattended GitHub credential) | G-0003's unattended push→PR→merge loop presupposes a sleep-surviving, no-human-present credential; G-0016's own prose names itself the missing piece that lets the loop actually run. |
| G-0004 (review-finding identity) | P-TDDPairs | Finding identity assumes the test gates fire on changes; without the gates, the identity has nothing to anchor against. |
| G-0007 (feature flags FlagProvider trait) | P-LockContract | The trait is the lock; the principle is the rationale. |
| Composition (value) | Decomposition (value) | Per `architecture-values.md`: "Decomposition tells you what to build; Composition is how the team that builds it stays coherent." Composition presupposes decomposition has happened. |

## Refines

| Source | Target | Rationale |
|--------|--------|-----------|
| G-0013 (agent-first workflow) | Decomposition | The mandatory Stage 0 baseline-load tightens the value's "scope known before the first dispatch" claim into a concrete workflow step. Same domain, narrower mechanism. |
| G-0004 (review-finding identity) | P-IterateToZero | Concrete identity tuple definition narrows what counts as "same finding across rounds." |
| G-0013 (agent-first workflow) | P-TrustThenRetro | The workflow shape *is* the structural implementation of trust-then-retro — same principle, narrower mechanism. |
| G-0010 (embargo flow) | P-SecurityLayered | Embargo flow refines the design-time layer with disclosure-window mechanics. |
| G-0002 (Justfile as CI contract) | P-StackDiscipline | Justfile choice over alternatives like Make or scripts — refines stack-discipline at the build-tooling layer. |
| G-0013 (agent-first workflow) | P-LockContract | The designed-tier/committed-tier amendment is the workflow mechanism that implements "the spec is a locked contract; the plan varies behind it." The principle owns the *why*; G-0013 owns the workflow stage that produces the locked spec. |

## Conflicts-with

Per `architecture-values.md` conflict-resolution table, two-core trade-offs surface the axis rather than pre-resolving. The pairs below are *known tension points* — not blockers, but escalation surfaces for the review pass.

| A | B | Tension axis | Resolution posture |
|---|---|--------------|---------------------|
| Security | Simplicity | "Each layer is load-bearing" vs "smallest mechanism" | Name the axis; default-to-Security per "default-on, never opt-in." |
| Observability | Simplicity | Instrumentation cost vs minimum mechanism | Name the axis; default-to-Observability for production surfaces. |
| Observability | Security | Logs leak secrets if untreated | P-SecurityLayered's runtime layer handles via redaction discipline. |
| Quality | Cost (situational, not a core value but a weighting axis) | Quality outranks cost as default | Surface the cost override explicitly — "doing this at quality cost X because Y." |
| Simplicity | Migration cost | A clever simpler abstraction may be harder to migrate to/away from | Per-repo first per P-PerRepoFirst; defer the migration cost by deferring the abstraction. |
| Honesty | Dogfooding | Workspace-private attribution preserves pattern signal; repo artifacts get genericized | P-WriteTimeAudience resolves — two durability profiles, two disciplines. |
| P-Defer | P-InstrumentBefore | "Don't add until evidence forces" tension with "ship instrumented before launch" | P-InstrumentBefore wins for production surfaces — observability is the evidence-gathering mechanism that makes deferral safe elsewhere. |
| P-LockContract | P-PreserveDecisionSpace | *When to lock.* "Lock the contract early" pulls toward early commitment; "preserve the decision space / keep options open" pulls toward deferring it. | Surface the axis; do not pre-resolve (scope-rule 3). The discriminator: lock what is *intrinsic to the artifact's identity* — an intrinsic invariant locks at the stage it is defined, even if not exposed until later — and preserve the space on what is a *separable future option*. A lock is scoped to the assumptions it was made against; when a later change falsifies that world, the contract is re-derived against the new world, not honored as if the world had not moved. |
| P-AgentPrimarySource | P-ShiftLeft | *Form optimized for the primary (agent) consumer* vs *the form the accountable human gates most reliably*. Deterministic view-generation guarantees the human's view matches the source byte-wise; it does not guarantee the human catches in catalog form what they would catch in narrative. | Surface, don't pre-resolve. The workspace reads the agent-primary form directly at the Frame/spec gates; G-0014's publish-render is the analogous mitigation at the publish boundary. |

> **Performance — a situational weighting axis alongside cost, not a core value.** Like cost (the `Quality | Cost` row above), performance is a situational weighting axis rather than a core system-property value: latency, throughput, and resource efficiency weight design choices where a surface bears them, surfaced explicitly when they override a core value rather than carried as a default lean. A performance-*budget* principle is deferred with a fireable trip-wire — it fires when the first latency-bearing surface adopts a stated budget (for example, retrieval latency in mnemra, page-load on a public site, an editor's input responsiveness), at which point the budget and its measurement land in that project's P-ADR. Naming the axis now closes the reads-as-omission gap: the canon named cost as a deliberate non-value weighting axis but left performance unnamed, and that absence was an omission, not a deliberate scoping-out.

## Notes on this initial walk

- **Coverage:** 8 core values + 8 supporting values + 24 named principles + 16 live G-ADRs. Edges below are the *obvious* ones — not exhaustive. Add edges as work surfaces them.
- **Composition value is recent (2026-05-13).** G-0013's specializes-Composition edge is load-bearing; expect that node to gain edges as the workflow lands.
- **Maintainability value adopted 2026-05-13.** P-MinBlastRadius lands as the operationalizing principle. F/R-rule stack-specific extensions live in the implementer stack skills' `<maintainability>` sections (skill content, not nodes).
- **ADR-to-ADR depends-on edges are sparse.** Most ADRs anchor on a principle/value rather than another ADR. The G-0008 → G-0002 edge (PR-merge apparatus → Justfile CI contract) is the load-bearing cross-ADR dependency; the G-0004 → P-TDDPairs edge is the load-bearing cross-ADR-to-principle dependency. Others may surface during graph walks.
- **Refines vs specializes** is a continuum — "narrower scope" can read as either. Used `refines` when the source narrows the *mechanism* the target named (vs adding a new case to a class).
- **P-PerRepoFirst ⇄ P-MinBlastRadius — rule-of-three at two scopes.** Both principles invoke a rule-of-three, and they do not collide: P-PerRepoFirst's governs *workspace-crate birth* (cross-repo — create the shared crate when a third repo adopts the shape; rule PR1), P-MinBlastRadius's governs *function/abstraction extraction within a single codebase*. Disambiguation note, not a conflict edge.
- **P-Worktrees ⇄ P-MinBlastRadius — compose at change-isolation.** The two operationalize change isolation at different layers: P-Worktrees at the workflow layer (isolate the work in progress), P-MinBlastRadius at the code layer (bound how far the change reaches). Recorded here for graph-walk visibility (a compose relationship, with no formal edge type for it).
- **P-TestableByDesign ⇄ P-MinBlastRadius ⇄ P-LockContract — one lever, three ends.** A dependency injected behind a stable contract is usually the *same structural seam* serving three principles at once: the change lands behind it (P-MinBlastRadius), the implementation swaps behind it (P-LockContract), and the test drives through it (P-TestableByDesign). Named in P-TestableByDesign's Why; recorded here for graph-walk visibility (a compose relationship, with no formal edge type for it) so a review finding on any of the three can cite the shared lever.
- **P-GuaranteeByMechanism is the cross-family parent of three existing X-rules.** DF1 (P-Defer), TS2 (P-TrustworthySignal), and MB1's consolidation clause (P-MinBlastRadius) each specialize P-GuaranteeByMechanism — the general "enforce a guarantee with a loud-failing mechanism, not a convention" discipline — on their respective surfaces (deferral firing, coverage-scope reconciliation, deduplication). X-rules are not constraint-graph nodes (they live inside their parent principles, scope-rule 2), so this cross-family parent relationship is recorded here as a walk-note rather than as edge rows, with each rule back-linked to P-GuaranteeByMechanism at its site in `architecture-principles.md`. The language-agnostic control-integrity clause on P-SecurityLayered is a fourth specialization, on the Security surface.
- **Observability ⇄ Honesty — a faithful instrument is where they coincide.** A signal that reports success without verifying, reports a failure that did not occur, or stops reporting silently is simultaneously an Observability fidelity defect and an Honesty defect (it asserts confidence it has not earned). Recorded so review findings can cite "the instrument lied" against both values; no formal edge type fits a value↔value mutual-reinforcement, so it sits here rather than in a typed table. **P-TrustworthySignal** operationalizes this coincidence for the verification signal specifically; its anchors are Observability + Quality, and it names the Honesty coincidence in its Why as a cross-reinforcement rather than a third anchor — so this value↔value note and the principle stay linked rather than asserting the faithful-instrument idea unlinked in two places.
- **P-LockContract ⇄ P-PreserveDecisionSpace — a worked instance of the when-to-lock edge (in the Conflicts-with table).** A storage layer was locked as an *engine-agnostic trait* (an interface every storage call site depends on) with exactly one implementation built behind it (Postgres) and no second adapter. The two principles do not collide; they govern different objects. **P-LockContract** justifies locking the trait *now* — the storage seam is intrinsic to the layer's identity, so the contract locks at definition even though no second engine yet exercises it. **P-PreserveDecisionSpace** justifies *not* building the second adapter — that is a separable future option, deferred behind a named trip-wire (a candidate engine relicenses permissively, or the single-engine path strains under the real workload), not foreclosed. The same instance illustrates the cell's *re-derive-on-reshape* half: this lock **reversed** an earlier project-local "this engine is natural here, no swap needed" lock, because that earlier lock was scoped to "no realistic swap pressure" — an assumption a later on-merits storage re-evaluation falsified. When the world the lock assumed moved, the contract was re-derived against the new world rather than honored as if the world had stood still. (Project ADR pointer: the storage layer's project ADR carries the full reasoning; cited as a pointer, not a dependency — the edge decides the general case without it.)

## Scope rules (resolved 2026-05-13)

1. **Project P-ADR edges live in per-project files.** Each project bootstraps `<project>/docs/src/adrs/constraint-edges.md` once it accumulates ~5 P-ADRs. The per-project file extends this one via `specializes` edges to G-ADRs. Workspace file stays clean.

2. **Skills are not nodes in the constraint graph.** Skill files operationalize principles — they're the mechanism layer, not the constraint layer. When a skill rule conflicts with a principle or another constraint, surface the conflict edge back into this file at discovery time (skill files referenced by name in the rationale, but no per-skill nodes).

3. **Principle-pair conflict walks are surfacing-driven.** No systematic walk of principle pairs for tensions; conflict edges are added when a review pass or graph walk forces them. Aligned with P-Defer.

## Changelog

- **2026-07-04** — Axis-2 gap-scan landing. Anchoring `specializes` edges for three new principles: **P-GuaranteeByMechanism → Quality** and **→ Observability**; **P-VerifyInheritedState → Honesty** and **→ Reversibility**; **P-LeastAuthority → Security**. Added **G-0016 → P-LeastAuthority** (its second anchor, alongside the existing → P-SecurityLayered, making it a multi-anchor node). Added the **P-AgentPrimarySource ⇄ P-ShiftLeft** conflict edge. Recorded the **P-GuaranteeByMechanism** parent-of-DF1/TS2/MB1 cross-family walk-note and the **performance situational-weighting-axis** note alongside the cost row. Coverage note reconciled to **8 core values + 8 supporting values + 24 named principles + 16 live G-ADRs**.
- **2026-07-04** — Added **P-TestableByDesign** (Anchors Quality, Maintainability). Two anchoring `specializes` rows and the *one lever, three ends* walk-note (P-TestableByDesign ⇄ P-MinBlastRadius ⇄ P-LockContract).
- **2026-06-26** — Added **P-TrustworthySignal** (Anchors Observability, Quality). Two anchoring `specializes` rows; cross-linked the *Observability ⇄ Honesty* faithful-instrument walk-note to the new principle.
- **2026-06-22** — Added **P-LeadOrchestration → Composition**. Consolidated the merge-governance node (**G-0003**) and the multi-anchor PR-merge apparatus (**G-0008 →** P-Worktrees, Reversibility, P-MainProtected) and Rust release apparatus (**G-0009 →** P-StackDiscipline, Honesty); the **G-0008 → G-0002** cross-ADR dependency is the load-bearing one.
- **2026-06-11** — Added the **P-AgentPrimarySource** anchoring rows (→ Decomposition, → Dual-audience) and the **G-0013 → P-AgentPrimarySource** dependency.
- **2026-06-09** — Added the P-LockContract ⇄ P-PreserveDecisionSpace worked-instance walk-note (the engine-agnostic storage-trait example).
- **2026-05-31** — Added the **P-LockContract ⇄ P-PreserveDecisionSpace** *when-to-lock* conflict edge and the **G-0013 → P-LockContract** refine. Recorded three walk-note relationships (P-PerRepoFirst ⇄ P-MinBlastRadius, P-Worktrees ⇄ P-MinBlastRadius, Observability ⇄ Honesty).
- **2026-05-15** — P-CompositionBridge principle landed. Added **P-CompositionBridge → Composition** and **→ Dogfooding** anchoring edges; added **P-TrustThenRetro → Composition** (paired protocol mechanism).
- **2026-05-13** — Maintainability value + **P-MinBlastRadius** principle landed (→ Maintainability, → Reversibility). Initial walk: obvious specializes/depends-on/refines edges and known value-level conflicts.
