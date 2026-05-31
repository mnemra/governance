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

Nodes remain primary in their existing locations (values doc, principles doc, `adrs/G-*.md`). This file is the **edges view** over those primaries — per G-0028's source-of-truth pattern. Markdown table is the format for now; promotion to a more structured representation (graphdb, query language) defers to friction-driven need.

## Edge types

Per G-0028:

| Type | Meaning |
|------|---------|
| **specializes** | Source is a specific case of target. (e.g., a principle specializes a value; an ADR specializes a principle.) Most common edge. |
| **depends-on** | Source presupposes target. Removing the target breaks the source's mechanism. |
| **conflicts-with** | Source and target can't both hold without negotiation. Surfaces at review-pass intersection points. Resolution: name the axis, present both, decomposer decides. |
| **refines** | Source tightens target. Same domain, narrower scope. Often appears when an ADR refines a principle's "How it shows up" with concrete mechanism. |

Traversal rule (per G-0028): most-specific applies when no conflict (per-task > project ADR > workspace ADR > principle). Conflicts escalate at intersection points.

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

### ADR → Principle or Value (workspace ADRs, obvious specializes)

| Source | Target | Rationale |
|--------|--------|-----------|
| G-0001 (testing philosophy) | P-TDDPairs | Codifies branch-delta + PBT as gates with inverted pyramid; concrete mechanism for TDD-pairs discipline. |
| G-0001 (testing philosophy) | Quality | Testing standards as quality floor. |
| G-0002 (no compile-time embedding) | P-Defer | Defers the asset-embedding mechanism in favor of ServeDir + Docker — simpler, evidence-driven later if needed. |
| G-0003 (ADR two-tier system) | P-PreserveDecisionSpace | Two-tier (G-workspace / P-project) ADRs preserve decision lineage across scope levels. |
| G-0004 (XML agent profiles) | Dual-audience | XML profile format reads cleanly for humans + parses reliably for agents. |
| G-0005 (SQL file migrations) | Reversibility | File-based migrations are reversible; encoded in `up`/`down` pairs. |
| G-0006 (Justfile as CI contract) | P-LockContract | Justfile is the single contract; runner (hosted/self-hosted/local) is swappable. |
| G-0007..G-0012 (knowledge-extraction series) | P-CompositionBridge | Encodes session-level pattern signal into durable artifacts loadable in future sessions. P-CompositionBridge is the operationalizing principle; series specializes the substrate mechanism. Composition value still reachable transitively via P-CompositionBridge. |
| G-0013 (Stage 6 approval label vocabulary) | P-ShiftLeft | Closed-enum vocabulary moves decomposer intent into a state machine subsequent gates can read. |
| G-0014 (review finding identity and persistence) | P-IterateToZero | Content-anchored finding identity is what makes iterate-to-zero converge across rounds. |
| G-0015 (devcontainer per-repo upstream base) | P-PerRepoFirst | Per-repo devcontainer with shared upstream — extraction only at the base layer. |
| G-0016 (layered secret detection) | P-SecurityLayered | Direct operationalization of the runtime layer. |
| G-0017 (feature flags FlagProvider trait) | P-LockContract | Trait in front of feature-flag backend lets backend swap without touching call sites. |
| G-0018 (workspace merge template + recovery cap) | P-Worktrees | Concrete lifecycle for worktree merges including failure recovery. |
| G-0019 (tag race serialization) | Reversibility | No lost work under concurrent tag operations. |
| G-0020 (Rust release-plz) | P-StackDiscipline | Stack-aligned release tooling. |
| G-0021 (monotonic non-decreasing version policy) | Honesty | Versions don't lie about progression. |
| G-0022 (embargo flow architecture) | Security | Embargo flow protects pre-disclosure work. |
| G-0023 (GitHub merge queue) | P-MainProtected | Direct operationalization of the merge gate. |
| G-0024 (Stage 6 label authorization) | P-ShiftLeft | Authorization-on-state-machine gates intent earlier. |
| G-0025 (internal IPC typed binary encoding) | P-LockContract | Typed schema is the locked contract. |
| G-0026 (project dev-docs tooling) | Dual-audience | Dev docs serve both decomposer and agents reading docs cold. |
| G-0027 (agent-primary source artifacts) | Decomposition | Source artifacts are for agents; human views derivative — preserves decomposer's role as direction-setter. |
| G-0027 (agent-primary source artifacts) | Dual-audience | Explicit dual-audience model with agents as primary consumer. |
| G-0028 (agent-first workflow shape) | Composition | Workflow shape blends human and agent strengths; applies structure where drift occurs. |
| G-0028 (agent-first workflow shape) | Decomposition | Stage 1 + Stage 3 gates (intake-exit + spec-exit) preserve decomposer's structural role. |

## Depends-on

| Source | Target | Rationale |
|--------|--------|-----------|
| P-IterateToZero | P-HeterogeneousReviewers | Stable finding identity requires distinct reviewer lenses; same model on same prompt produces identity collapse. |
| P-TDDPairs | P-HeterogeneousReviewers | TDD pair *is* a heterogeneous pair (test-writer + impl-writer); same agent produces contamination. |
| P-Worktrees | P-MainProtected | Worktrees solve the main-stability problem that main protection enforces. Removing main-protection makes worktrees decorative. |
| P-ShiftLeft | P-PreserveDecisionSpace | The decomposer's intent check operates on the full option space; erased alternatives produce a blind gate. |
| G-0028 (agent-first workflow) | G-0027 (agent-primary source artifacts) | G-0028 names this dependency in its prose — workflow that produces agent-primary artifacts presupposes the artifacts-are-agent-primary stance. |
| G-0023 (merge queue) | G-0006 (Justfile as CI contract) | Merge queue runs the Justfile recipe; without the contract, the queue has no canonical gate. |
| G-0014 (finding identity) | G-0001 (testing philosophy) | Finding identity assumes the test gates from G-0001 fire on changes; without the gates, the identity has nothing to anchor against. |
| G-0017 (FlagProvider trait) | P-LockContract | The trait is the lock; the principle is the rationale. |
| G-0007..G-0012 (knowledge-extraction) | G-0008 (capture schema) | The series builds on a shared schema; capture schema is the load-bearing root. |
| Composition (value) | Decomposition (value) | "Decomposition tells you what to build; Composition is how the team that builds it stays coherent." Composition presupposes decomposition has happened. |

## Refines

| Source | Target | Rationale |
|--------|--------|-----------|
| G-0024 (Stage 6 label authorization) | G-0013 (Stage 6 approval label vocabulary) | G-0024 tightens authorization rules on the label vocabulary G-0013 introduced. |
| G-0028 (agent-first workflow) | Decomposition | G-0028's mandatory Stage 0 baseline-load tightens the value's "scope known before the first dispatch" claim into a concrete workflow step. Same domain, narrower mechanism. |
| G-0014 (finding identity) | P-IterateToZero | Concrete identity tuple definition narrows what counts as "same finding across rounds." |
| G-0028 (agent-first workflow) | P-TrustThenRetro | The workflow shape *is* the structural implementation of trust-then-retro — same principle, narrower mechanism. |
| G-0022 (embargo flow) | P-SecurityLayered | Embargo flow refines the design-time layer with disclosure-window mechanics. |
| G-0006 (Justfile as CI contract) | P-StackDiscipline | Justfile choice over alternatives like Make or scripts — refines stack-discipline at the build-tooling layer. |

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

## Notes on this initial walk

- **Coverage:** 7 core values + 5 supporting values + 15 named principles + 28 G-ADRs. Edges below are *obvious* per the initial walk framing — not exhaustive. Add edges as work surfaces them.
- **Composition value is recent (2026-05-13).** G-0028's specializes-Composition edge is load-bearing; expect that node to gain edges as the workflow lands.
- **Maintainability value adopted 2026-05-13.** P-MinBlastRadius lands as the operationalizing principle. Stack-specific extensions live in the implementer stack skills' `<maintainability>` sections (skill content, not nodes).
- **ADR-to-ADR depends-on edges are sparse.** Most ADRs anchor on a principle/value rather than another ADR. The G-0023 → G-0006 and G-0014 → G-0001 edges are the load-bearing cross-ADR dependencies; others may surface during graph walks.
- **Refines vs specializes** is a continuum — "narrower scope" can read as either. Used `refines` when the source narrows the *mechanism* the target named (vs adding a new case to a class).

## Scope rules (resolved 2026-05-13)

1. **Project P-ADR edges live in per-project files.** Each project bootstraps `<project>/docs/src/adrs/constraint-edges.md` once it accumulates ~5 P-ADRs. The per-project file extends this one via `specializes` edges to G-ADRs. Workspace file stays clean.

2. **Skills are not nodes in the constraint graph.** Stack skill files operationalize principles — they're the mechanism layer, not the constraint layer. When a skill rule conflicts with a principle or another constraint, surface the conflict edge back into this file at discovery time (skill files referenced by name in the rationale, but no per-skill nodes).

3. **Principle-pair conflict walks are surfacing-driven.** No systematic walk of principle pairs for tensions; conflict edges are added when a review pass or graph walk forces them. Aligned with P-Defer.

4. **G-0007..G-0012 → Composition holds at series level for now.** A per-ADR second pass for more-specific principle anchors is deferred. The Composition edge stays; finer anchors land when a graph walk needs them.

## Changelog

- **2026-05-15** — P-CompositionBridge principle landed. Added P-CompositionBridge → Composition (specializes) + P-CompositionBridge → Dogfooding (specializes) anchoring edges; added P-TrustThenRetro → Composition (specializes — paired protocol mechanism); re-anchored G-0007..G-0012 series from Composition value direct to P-CompositionBridge (composition still reachable transitively).
- **2026-05-13** — Maintainability value + P-MinBlastRadius principle landed. Added Maintainability and P-MinBlastRadius nodes via anchoring edges.
- **2026-05-13** — Initial walk. 28 G-ADRs + 15 principles + 12 values walked for obvious specializes/depends-on/refines edges and known value-level conflicts. Composition + Maintainability nodes flagged for population as those values land in `architecture-values.md`.
- **2026-05-13** — Open questions resolved: per-project P-ADR file pattern locked, skills out of scope as nodes, conflict walk is surfacing-driven, G-0007..G-0012 per-ADR pass deferred. Initial walk now stable.
