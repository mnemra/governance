---
title: Architecture Values
summary: "The workspace's standing architecture values — core system-property and meta values that shape every architecture decision."
primary-audience: agent
---

# Architecture Values

> Living doc. Source for the principles in `architecture-principles.md`.
> Captures the workspace's standing architecture values, evolved over time.

## How to use this doc

These are the beliefs that shape architecture decisions in this workspace. Two audiences read them:

- **The decomposer** consults before opening a design session, framing a discovery pass, drafting an Architecture Decision Record (ADR), or weighing in on a design proposal.
- **The agentic team** consults during dispatch — when ranking options for a spec, drafting a finding, choosing an implementation seam, or proposing tradeoffs back.

Both audiences use the doc in-the-moment. It's written to be readable without external context: no specific decision records cited, no working-session shorthand, no memory-doc paths. If a value is invoked, the prose here is what carries the meaning.

When values trade off, name the axis. When a value pulls against a workspace `<guardrails>` rule, guardrails win — they're hard operational rules (credential handling, destructive git ops, force-push-to-main, external publishing approval), not preferences.

## Structure

The values are split into **core** (eight dimensions weighed in every architecture decision, equal weight, no rank order) and **supporting** (apply when work intersects, or describe the method by which decisions get made). Within core, five values describe what the *system* must be — each names a distinct unit goal architecture must satisfy: Security at the trust boundary, Simplicity at the design-time mechanism layer, Quality at the execution standard, Observability at the runtime evidence layer, and Maintainability at the change-time isolation layer. The remaining three describe how the *decision-making process and the human-agent composition* must operate.

## Core values

### System-property core — the qualities the system must always exhibit

These are quality attributes (non-functional requirements). They apply to every project regardless of feature scope.

#### Security

Default-on, never opt-in. Production-grade hygiene is the floor on every project — no personal-project discount.

Security defaults compose by layer, with each layer independently load-bearing: supply-chain (dependency review, SBOM per change), design-time (threat modeling on changes that touch trust boundaries), change-time (a security-lensed reviewer on every change that ships), runtime (layered detection — pre-commit + native repo controls + downstream verification, defense in depth). Losing any layer weakens the whole.

When a change ships without one of these layers because "it's only X," the value is being conceded silently. Surface it instead — name what's deferred and the trip-wire to add it back.

"Default-on, never opt-in" deliberately accepts a friction cost as the price of the floor. That acceptance has a limit: a control whose friction reliably drives users or agents to bypass it has failed *as security*, not merely as usability — the posture's job is the tightest control the workflow will actually keep, not the tightest control imaginable. When friction forces a bypass, the fix is a *usable* control, never a disabled one.

#### Simplicity

The smallest mechanism that solves the problem. Defer where evidence allows. Fewer moving parts beat clever architecture, especially when the system already has years of accumulated structure to reason about.

Simplicity is not minimalism for its own sake. It's the recognition that every mechanism added is a mechanism every future reader, every future tool, and every future migration has to account for. Speculative mechanisms — "we'll need this later" — defer until evidence forces the choice; the shape of that evidence then informs the shape of the mechanism.

When "complete and elegant" competes with "small and sufficient," simplicity picks small.

#### Quality

Quality outranks cost as the default weighting axis. Production standards apply to every project. Cost surfaces explicitly when it overrides; otherwise quality wins.

This is the value that resists the personal-project discount most directly. If the answer is different because "this one's just for me," that's a cost-based override of quality, and it should be named as such. Sometimes that override is the right call — but it's a call, not a default.

When ranking options, the cost-weighted answer and the quality-weighted answer are both present on the menu. The axis being weighed is named. The default lean is quality; departures are deliberate.

#### Observability

Every production surface ships instrumented. Metrics, structured logs, and traces — sized to the surface — are in place at first user-touch, not added after the first incident.

"Production" means any system intended for use past an explicitly-scoped experiment phase. Learning-mode work is allowed and useful, but it carries a stated time-box and a stated transition criterion ("when X happens, this becomes production"). Anything not explicitly time-boxed is production. No personal-project exception — code that nominally runs "just for me" still ships instrumented if it's meant to keep running.

Observability is the value that lets quality and reversibility be enforced empirically rather than by hope. Without it, "production-grade" is a claim without evidence.

An instrument is only as useful as it is faithful. A signal that reports success without verifying, reports a failure that did not occur, or stops reporting silently is worse than no signal, because it is trusted and acted upon. So the instrumentation layer is held to the same standard as the system it watches: it surfaces its own gaps and false readings. A result that cannot be produced is reported as inconclusive, not as pass or fail, and an expected signal that goes missing is itself detected.

Observability covers delivery outcomes, not only runtime health. An instrumented surface additionally measures how *change* to it behaves — change-failure rate, time to recover, rework — because the delivery pipeline that produces the surface is itself a production surface, and "how often a change breaks and how fast it recovers" is a runtime-evidence question about that pipeline. A surface can ship clean runtime metrics while the process that changes it degrades unmeasured; naming delivery outcomes as in-scope for Observability closes that blind spot.

#### Maintainability

Changes land minimally. A fix isolates to the smallest possible surface; a feature lands behind one seam; a refactor leaves callers untouched. The unit goal is **minimum-blast-radius fix**: when a change is needed, the architecture supports isolating it. When the minimal fix would require a sprawling rewrite, that is a signal of a deeper architectural problem — surface the restructure as a separate task rather than expanding the immediate fix.

The discipline operates at three layers. Modules hide design decisions rather than data, so that the decision can change without rippling — a deep module with a small interface absorbs change, a shallow module exports it. Coupling decays with distance: strong forms (shared meaning, shared algorithm, positional dependency) live within a single encapsulation boundary; only weak forms (named symbols, types) cross module boundaries. Changes land behind seams, abstractions, or toggles that bound where the change reaches; large changes land as sequences (introduce the seam first, then change behavior behind it) rather than in lock-step across modules.

Maintainability composes with Simplicity (fewer mechanisms are easier to maintain) and with Reversibility (a fix you can revert minimally is one whose blast radius is bounded). It trades off against premature generality — the discipline is *not* "abstract everything"; it is "abstract on the third occurrence, when the abstraction deepens rather than thinning." Duplication is far cheaper than the wrong abstraction (a practitioner heuristic — Metz — with no controlled study either way as of 2026-07); the rule-of-three is the extraction trigger and the depth test is the gate.

Where the codebase resists isolation — a fix that requires touching ten files in lock-step, a change to a constant that ripples to twenty callers, a new feature that needs three modules to know about each other — the architecture is reporting a debt. Name it. Decide whether to pay it now or later, but do not paper over it by expanding the fix.

### Meta core — the qualities the decision-making process must always exhibit

These three values operate on the integrity of artifacts, the structure of the work, and the composition of the team that does it — not on the system itself. They're the guardrails on how the system gets shaped.

#### Honesty

Distinguish established fact from finding from inference. Cite where a recommendation came from. Mark hype vocabulary as a tell. When work is borrowed, say so. State what we know vs. what we don't with precision.

This value sits upstream of architecture. It's how *anything* — a research brief, a strawman, a review finding, a design recommendation — gets evaluated for trust. Trust erodes on cherry-picking, loaded questions, and hand-waved confidence. One instance is a flag. A pattern is a verdict.

The discipline's recent stress source is agent-generated content. LLMs produce sourced and synthesized claims with the same fluency; the boundary that human writers feel between "I cite this" and "I'm inferring this" is not internally available to an agent. The workspace's mechanisms (the established/finding/inference distinction, heterogeneous-reviewer cross-checks, claim-grounding against the personal-baseline and user-context memory) compose with model-layer honesty discipline (constitutional AI) rather than replacing it; both layers are required.

In ADRs, honesty shows up as the Alternatives Considered section: rejecting an option without naming why it lost is a form of dishonesty about the decision space. In review work, it shows up as separating opinion from finding from established practice. In dispatch reporting, it shows up as agents naming uncertainty rather than asserting confidence they don't have.

#### Decomposition

Figuring out what to build happens before execution. Specs are written before implementation. Plans are pure sequencing once scope is known. Investigation that would happen at plan time was owed at design time.

The decomposer's eye is the structural integrity check the agentic team can't replicate. The team executes within direction; direction is set up-front. When a plan needs an "audit the API surface" step, the spec is incomplete — fix the spec, don't paper over it in the plan.

Decomposition before execution is not a stage the workflow chooses; it is the order the workspace runs in. What the decomposer cuts before dispatch is what the agentic team operates inside: agent-side work assumes the decomposition is already done and works within it, not around it.

A sharper thesis sits under this: the maintainer's primary-source hypothesis that decomposition is the durable human contribution as AI compresses code-writing toward zero while scope-cutting stays at the human grain. The workspace takes it seriously as an operating posture, corroborated in parts by labor-market data on routine-coding compression and by agentic-workflow patterns that name decomposition as a load-bearing primitive, but does not treat it as established empirical fact.

This value is what makes the rest of the architecture stack work: small mechanisms, locked contracts, layered reviewers, and stable trip-wires all assume the scope is understood before the first dispatch. Without decomposition, every subsequent value gets applied to a moving target.

Decomposition runs up front and is the durable human contribution — and it is bounded by what the evidence has forced, not run to exhaustion. Designing what should instead be *learned* by building is big-design-up-front, and over-committing to an un-forced scope is paid back in rework. The bound is on *scope*, not on decomposition's primacy: decompose to the last responsible moment (see P-Defer) and let greenfield scope emerge as vertical slices rather than a single exhaustive upfront layering.

#### Composition

Apply structure at points where drift occurs. Blend the strengths of human and agent work; bound the failure modes of each.

This is the value that shapes the workflow itself. Humans and agents each carry characteristic strengths and characteristic failure modes — humans set intent and judge satisfaction, agents execute and synthesize at scale, humans drift on detail over time, agents drift on intent without grounding. The workflow's job is to blend the strengths of each and bound the failure modes of each, applying structure precisely at the points where work would otherwise drift.

The old workflow was shaped by how humans work alone: multi-step elicitation, per-decision approval, narrative documents. The new workflow is shaped by how humans and agents work together: structured intent, principle-anchored baselines, machine-verifiable specs, mechanical signals plus human spot check at the gates that matter. Where the composition would drift — a missed principle, a stale baseline, an ambiguous handoff — that's where the workflow grows structure. Where it composes cleanly, the workflow stays out of the way.

The asymmetry between participants closes at the artifact layer, not at runtime — durable artifacts (specs, ADRs, principles, skills, memory) encode the slow-changing low-resolution context the human carries into the fast-loading high-resolution context the agents need. Where the artifact is present and well-maintained, the composition is stable; where it is missing or stale, composition stress shows up at runtime.

Composition is what makes the rest of the architecture stack actually run. Decomposition tells you what to build; Composition is how the team that builds it stays coherent. Without it, every other value applies to a workflow that was never designed for the team that runs it.

## Supporting values

These shape *how* the work happens — method values — or apply when the work intersects their domain.

#### Migration cost as a first-class constraint

New mechanisms get evaluated against the cost of retrofitting existing systems. A workspace-wide adoption that requires every repo to converge is structurally more expensive than a per-repo opt-in that lets convergence happen organically.

When a "shared abstraction" competes with "per-repo copy with a stable trait," migration cost picks per-repo unless reuse is already observed. Premature extraction creates a workspace artifact every reader has to reason about before the shared code earns its keep.

#### Rust-ecosystem alignment

Default to Rust for tooling, infrastructure, libraries, and CLI surfaces. Adopt non-Rust paths only when no viable Rust path exists. SvelteKit at the SPA layer is by accommodation, not preference.

The point isn't language tribalism — it's reducing the toolchain surface the workspace has to keep current. Every additional ecosystem (Node, Python, Java) is another set of upgrade cycles, lockfile semantics, and security advisories to track. When the Rust path requires hand-rolling a small mechanism vs. inheriting upstream churn from a pre-1.0 ecosystem outsider, the hand-rolled path often wins. Under sandboxed-agent dispatch this compounds: each extra ecosystem is also a provisioning surface — a toolchain that may simply be absent in the agent's environment at dispatch time, turning an ecosystem choice into a setup cost paid on every run.

#### Reversibility (forward or backward)

Value the *existence* of a mitigation path, not specifically rollback. Sometimes the simplest reversal is to move forward to a fix; sometimes it's to roll the change back; what matters is that a path exists and was named before commit.

Mechanisms that preserve the mitigation surface — branch-and-PR flows, worktrees that keep main stable, human gates before irreversible publication, layered review before merge — earn their cost because they preserve optionality. Changes that have no mitigation path either way are flagged as load-bearing irreversibles, not blocked; the team enters them with the awareness they can't be undone cheaply.

The existence of a mitigation path lowers the *cost* of a mistake; it does not lower the *bar* for making the change. Reversibility mitigates the cost of an action taken in error — it is never authorization to take the action. "I can undo it" is not a substitute for the gate the action would otherwise pass.

#### Dogfooding as a forcing function

Tools we ship get used internally first. Pain we hit ourselves drives the roadmap; pain a hypothetical user might hit doesn't.

Dogfooding does *not* mean these tools are personal utilities. They're products that we happen to use first — the workspace is the early validation surface, not the sole audience. The forcing function is what closes the gap between "ships clean" and "actually solves the problem."

#### Architecture artifacts as dual-audience decision substrate

These documents are written for both the decomposer and the agentic team. Both consult them when ranking options, drafting decisions, or weighing tradeoffs. The dual-audience posture shapes how the artifacts are written: self-contained for the in-workspace audience — the decomposer and the agentic team — in-the-moment-readable, requiring no external context to consult cold. A third audience exists at the publish boundary: outside humans reading a rendered docs site, for whom agent-first source vocabulary is opaque. That audience is served by a publish-time render pass that supplies the context the source intentionally omits, not by relaxing the source's self-containment. Self-containment is a property of the canonical source for its in-workspace readers; the published human surface adds context on top of it, it does not subtract from it.

This value is what justifies the writing standard for documents like this one and the principles doc. They're not internal field notes — they're load-bearing references that future agents and future sessions will consult cold.

#### Data minimization

Collect and retain the minimum data the surface's job requires. Holding another party's data is a design decision, not a default. This is distinct from Security: a fully-secure system can still over-collect — security asks whether data leaks, privacy asks whether we should hold it at all — so the concern is named as its own constraint, not folded into the security lens.

The value is named now; the operationalizing mechanism is deferred per-project with a fireable trip-wire. It fires for a surface the first time that surface holds data beyond single-user-personal — a public-facing personal site (external visitors) and a tool holding third-party PII partially qualify today, and a hosted mnemra holding adopter data would qualify fully. When a surface crosses that line, its data-minimization discipline (what is collected, why, how long it is retained) is operationalized in that project's P-ADR. Naming the value now, per P-Defer, is what makes the deferral fireable rather than a silent absence.

#### Accessibility

User-facing surfaces meet an accessibility floor as a hard requirement, not a polish pass. Where surfaces diverge, the accessible path is chosen by default. This is a committed constraint, not an aspiration: it applies now to every human-facing surface (a public personal site, a document editor), because the condition — a surface used by a human other than the author — is already met.

The floor is operationalized now, not deferred: the P-HeterogeneousReviewers accessibility reviewer lens in `architecture-principles.md` is the mechanism that checks UI changes against it — an accessibility-and-design reviewer joins when a change touches a user-facing surface. The value states the floor as a hard requirement; the reviewer lens enforces it per change.

#### Reliability

Availability and correctness under failure are designed and measured, not assumed. A surface's behavior when a dependency is slow, a process crashes, or load spikes is a property to design for (resilience patterns — timeouts, retries with backoff, circuit breakers, graceful degradation) and to measure (is it meeting its target?), not one hoped for and discovered in an incident.

The value is named now; the operationalizing mechanism is deferred with a fireable trip-wire. It fires when the first running surface adopts a *stated reliability target* — at that point the target, its measurement (an SLI/SLO and error budget, the field's principled answer to "how much gate is the right amount of gate"), and the resilience patterns that defend it are set in that project's P-ADR. No live surface carries a stated target yet (a live personal site is running but sets none; a hosted mnemra is prospective), so the mechanism waits on that first target, per P-Defer. Reliability spans both design and measurement, so it is named as its own supporting value rather than folded into Observability (the evidence layer), which owns the measurement half but not the design half.

## How values compose

Every architecture decision passes through the eight core values. None of them rank above the others by default. When two trade off — security vs. simplicity, observability vs. simplicity, observability vs. security — surface the conflict explicitly. Don't silently pick a winner; name the axis being weighed (security, quality, cost, time, migration burden) and present both options with their tradeoffs visible.

Supporting values shape the *how* of executing on core, or apply when the decision intersects their domain. Migration cost is a method lens on decisions that touch existing systems; reversibility is a method lens on commit-time decisions; dogfooding is a method lens on tools we ship.

### Conflict resolution

| When | Rule |
|------|------|
| Two **core** values trade off | Name the axis. Present both options with tradeoffs visible. The decomposer makes the call; the team surfaces the conflict rather than pre-resolving. |
| **Core** vs **supporting** | Core dominates by default. Supporting shapes *how* core gets executed, or applies when the decision intersects its domain. |
| Two **supporting** values trade off | Contextual. Surface the axis when proposing tradeoffs. |
| A **principle** appears to conflict with a workspace **guardrail** | Guardrails win. They're operational hard rules — credential handling, destructive git ops, force-push-to-main, external publishing approval — not preferences. Principles guide decisions; guardrails forbid actions. |

## Changelog

- **2026-07-04** — Three supporting values added: **Data minimization** (collect and retain the minimum the surface's job requires; holding another party's data is a design decision, not a default; distinct from Security; operationalization deferred per-project until a surface first holds data beyond single-user-personal), **Accessibility** (user-facing surfaces meet an accessibility floor as a hard requirement, not a polish pass; the accessible path is the default where surfaces diverge; operationalized now via the P-HeterogeneousReviewers accessibility reviewer lens), and **Reliability** (availability and correctness under failure are designed and measured, not assumed; SLI/SLO + error-budget and resilience-pattern mechanism deferred until the first surface adopts a stated reliability target). Core sections expanded without changing posture: **Observability** gains a faithful-instrument clause (a signal that reports success without verifying is worse than no signal) and a delivery-outcomes clause (change-failure rate, recovery time, and rework are in scope); **Security** gains a usable-security clause (a control whose friction reliably drives bypass has failed as security); **Reversibility** gains a moral-hazard clause (a mitigation path lowers the cost of a mistake, never the bar for the change); **Decomposition** gains a big-design-up-front scope bound (bounded by forced evidence — bounds scope, not decomposition's primacy); **Rust-ecosystem alignment** notes the sandboxed-agent provisioning surface; **Maintainability**'s duplication-vs-abstraction line is tagged a practitioner heuristic. Count fixes: the Meta core intro now reads *three* values (it lists three), and How values compose now reads *eight* core values.
- **2026-05-31** — Extended the Dual-audience value to name a third audience at the publish boundary (outside humans reading a rendered docs site), served by a publish-time render pass that supplies the context the self-contained source omits. Additive, not corrective — the published human surface adds context on top of the self-contained source, it does not subtract from it.
- **2026-05-13** — Added Maintainability as 5th system-property core value (sibling to Security, Simplicity, Quality, Observability). Unit goal: minimum-blast-radius fix (change-time isolation). P-MinBlastRadius operationalizes it. Structure paragraph reframed to surface unit-goal-per-value framing.
- **2026-05-13** — Added Composition as a third meta core value: *apply structure at points where drift occurs; blend the strengths of human and agent work, bound the failure modes of each*. Surfaced as the load-bearing meta-frame behind G-0013 (Agent-First Workflow Shape). Promotes the rationale from inline citation to first-class workspace value so it shapes future workflow and tooling decisions.
- **2026-04-30** — Initial structure: 6 core values (security, simplicity, quality, observability, honesty, decomposition) + 5 supporting values (migration cost, Rust-ecosystem alignment, reversibility, dogfooding, dual-audience).
