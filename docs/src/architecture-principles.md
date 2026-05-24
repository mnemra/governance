---
title: Architecture Principles
summary: "The workspace's standing named architecture principles, operationalizing the values in architecture-values.md."
primary-audience: agent
---

# Architecture Principles

> Living doc. Operationalizes the values in `architecture-values.md`.
> Captures the workspace's standing architecture principles, evolved over time.

## How to use this doc

Values describe what we believe matters; principles describe how we act on it. Two audiences read this doc:

- **The decomposer** consults during ADR drafting (every Decision section traces to one or more principles), design-session option-generation (principles are the tiebreakers under the locked quality-attribute anchor), and discovery requirement-shaping (principles surface as RFC 2119 SHALL/SHOULD form when they cross into observable behavior).
- **The agentic team** consults during dispatch — reviewers cite principles when grounding findings; implementers check proposed mechanisms against them; researchers shape recommendations to align.

Principles are named, not numbered. Insert order is not load-bearing; reorders and additions don't renumber surrounding rules. Each principle below carries a short label (`P-Defer`, `P-PerRepoFirst`, etc.) that other documents can reference.

When a principle conflicts with a workspace `<guardrails>` rule, guardrails win. Principles guide decisions; guardrails forbid actions.

## Principles

### P-Defer

Defer mechanism until evidence forces the choice. (Anchors Simplicity, Reversibility.)

**Why.** Trip-wire-driven adoption beats anticipated-need adoption. When the trip-wire fires, the shape of the evidence informs the shape of the mechanism. Speculative mechanisms get sized for the imagined problem, not the real one — and they accumulate maintenance cost from the day they ship.

**How it shows up.** Open/Deferred sections in architecture documents name the mechanisms that are *not* being adopted now, each with a stated trip-wire to revisit. A workflow stage is built when the absence of it has hurt more than once; not when someone imagines it might.

**Anti-example.** "We should add this now because we'll probably need it later" — without naming the trip-wire that would make it necessary, or what the evidence would look like. Or worse: claiming a tool enforces a constraint the tool doesn't actually support, and only catching the gap during review.

### P-PerRepoFirst

Per-repo first; extract on rule-of-three. (Anchors Simplicity, Migration cost.)

**Why.** Premature extraction creates a workspace artifact every reader and every tool has to reason about before the shared code earns its keep. Extraction shapes that grow from observed reuse beat shapes built from speculation about what the reuse will look like.

**How it shows up.** A trait or interface contract may live as workspace canon (a single decision record), while the implementation lives per-repo. Shared crates emerge when three repos diverge in non-trivial ways on the same problem — not before.

**Anti-example.** Building a shared library for a problem only one repo has, on the assumption others will eventually need it. Building workspace-side image pipelines or shared scaffolding before any repo has demonstrated the need.

### P-LockContract

Lock the contract; vary the implementation. (Anchors Simplicity, Migration cost, Rust-ecosystem alignment.)

**Why.** The contract is what other code depends on. Implementations are swappable when the contract is stable. Locking the contract is what makes substitution safe — the runtime, the storage backend, the third-party SDK can all change behind a stable seam.

**How it shows up.** A CI orchestrator that calls a single workspace recipe, with all gate logic behind that recipe — runner choice (hosted, self-hosted, local) becomes substitutable. A trait in front of a feature-flag backend lets the backend swap from environment variables to a hosted SDK without touching call sites. A finding-identity tuple anchored on content rather than line numbers survives format-rewriting.

**Anti-example.** Hard-coding a specific tool invocation directly in CI YAML. Pinning a contract to a specific runner. Putting business logic in the orchestrator layer instead of behind the contract.

### P-MinBlastRadius

A change reaches as far as the architecture lets it. (Anchors Maintainability, Reversibility.)

**Why.** Every dependency is a propagation surface. The cost of a change is proportional to the number of files, callers, and downstream systems it touches; the architecture's job is to keep that cost small. The unit goal is that a fix isolates to one module, a feature lands behind one seam, and the rest of the codebase does not know either happened. When that isn't possible, the architecture is reporting structural debt — surface it as a separate restructure task rather than expanding the immediate change.

**How it shows up.** Modules hide design decisions, not data (Parnas / Ousterhout). Strong-form coupling stays within an encapsulation boundary; cross-module coupling is by name or type only (connascence — Page-Jones). Behavior changes land behind seams (Feathers) or abstractions (branch-by-abstraction — Hammant); risky changes ship behind toggles when feasible. New abstractions extract on the third occurrence (rule of three — Hunt/Thomas, Fowler) and only when the abstraction *deepens* — hides a decision behind a smaller interface than the duplication exposed. Wrong abstractions get re-inlined and re-extracted, not patched with another flag parameter (Metz).

Five cross-stack mechanism rules operationalize this principle (stack-specific extensions live in the implementer stack skills' `<maintainability>` sections):

- **Extract on the third occurrence.** Two occurrences stay duplicated; the third reveals the actual shape of the abstraction.
- **Re-inline before re-abstracting.** A wrong abstraction gets inlined back into its callers, then a new abstraction is extracted from the new pattern. Do not patch the wrong abstraction with another flag parameter.
- **Vocabulary consistency across the codebase.** One verb per operation (`fetch` *or* `get`, not both); one noun per domain concept. Project-level vocabulary doc in `ai_docs/` when scale demands.
- **Cross-module coupling is by name and type only.** Shared meaning, shared algorithm, positional dependency stay within a single encapsulation boundary.
- **A change touching N modules in lock-step is a defect.** First commit introduces the seam; subsequent commits change behavior behind it.

**Anti-example.** A spec that requires changes in N modules in lock-step (the seam is missing; first commit should introduce it). An abstraction extended with a third parameter to handle a new case (the abstraction is wrong; re-inline and re-extract). A constant whose name adds no information (`MAGIC = 3`). A module whose public interface is 60% of its line count (shallow; should deepen or merge). Code reviewed in isolation that compiles correctly but creates non-local coupling (the diff hides connascence across module boundaries).

### P-StackDiscipline

Reject ecosystem-misaligned tooling unless no in-stack path exists. (Anchors Rust-ecosystem alignment.)

**Why.** Tooling that drags in a foreign toolchain for non-essential reasons creates upgrade-and-version-management burden the stack-alignment value explicitly resists. Each additional ecosystem is another set of advisory feeds, lockfile semantics, and breaking-change cadences to track.

**How it shows up.** Hook tooling and pre-commit checks pick the stack-aligned option even when a more popular cross-ecosystem option exists. When Python is required, the toolchain is consolidated to a single tool rather than an accreted layer of historical tooling. When the in-stack option is pre-1.0 or thin, hand-rolling a small mechanism often beats inheriting churn from outside.

**Anti-example.** Adopting a richer-dashboard tool over an in-stack equivalent because the dashboard is nicer. Adding a foreign-language dependency to a recipe that has no other reason to need it. Picking a tool because it's industry-default when the stack-aligned alternative already covers the requirement.

### P-SecurityLayered

Security defaults compose by layer, with each layer independently load-bearing. (Anchors Security.)

The layers:

- **Supply chain.** SBOM generated per change. Dependencies pass tier review (license, maintenance, source).
- **Design-time.** A threat model is generated for every spec covering new components or integrations crossing a trust boundary, AND every architectural decision touching authentication, authorization, data egress, secret handling, or external dependencies. Copy-edit-scope changes do not trigger a threat model.
- **Change-time.** Security review on every change that ships. The reviewer's lens is security, not just code-correctness.
- **Runtime.** Layered detection — pre-commit checks plus native repo controls plus downstream verification. Defense in depth, not single-gate.

**Why.** Losing any layer weakens the whole; the layers are not substitutable. Supply-chain hygiene without design-time threat modeling lets architectural risks ship clean. Threat modeling without runtime detection lets known risks land unmonitored. Single-gate enforcement creates a bypass that owns the whole posture.

**Anti-example.** A "we'll add security review when there's something risky to review" posture — security review is the mechanism that determines what's risky. A pre-commit check that's the only check, with no downstream verification if it's bypassed. A spec that touches authentication or secret handling and doesn't carry a threat model.

### P-InstrumentBefore

Every production surface ships instrumented before launch. (Anchors Observability.)

Metrics, structured logs, and traces — sized to the surface — in place at first user-touch. Not added after the first incident.

**Why.** Without observability, claims about quality, reliability, and reversibility are unverifiable. The first time something breaks under load is the worst time to start adding instrumentation; the operator is debugging blind and the evidence to root-cause is gone.

**Production threshold.** "Production" means any system intended for use — by anyone, including the decomposer alone — past an explicitly-scoped experiment phase. Learning-mode is allowed only when it carries (a) a stated time-box and (b) a stated transition criterion ("when X happens, this becomes production"). Anything not explicitly time-boxed is production. No personal-project exception — code that nominally runs "just for me" still ships instrumented if it's meant to keep running.

**Anti-example.** "We'll add metrics once we have users." A long-running tool with no structured logs and no error-rate visibility, justified as "just for me." A learning-mode prototype that's been running production traffic for six months without ever crossing the transition criterion.

### P-Worktrees

All code work happens in worktrees. (Anchors Reversibility, Decomposition.)

**Why.** Worktrees keep main stable while agents work in isolation. They make verification on dirty trees safe. They make parallel dispatch possible. The "no exceptions" rule exists because skipping the worktree on standalone repos rationalizes past the discipline — consistency is what builds the habit, and the habit is what the dispatch model depends on.

**How it shows up.** Every code-modifying dispatch opens a worktree at the start of the workflow. The worktree is created by the orchestrator before dispatch, not via subagent isolation flags (which override the dispatch permission model). Cleanup follows a known sequence to handle squash-merge gotchas.

**Anti-example.** Direct commits to main on any repo. Stashing a working tree, checking out a branch to verify its tests, and stash-popping back — silently lost working-tree deltas have happened this way. Using subagent isolation flags to create a worktree, which forfeits permissions the dispatched agent needs.

### P-MainProtected

Main is protected. PR plus CI is the gate every change passes. (Anchors Reversibility, Quality.)

**Why.** CI must run before code reaches main. Direct pushes — even with server-side bypass — skip the gate the protection rule exists to enforce. Bypass warnings are a hard stop, not a footnote.

**How it shows up.** Repo settings disable direct push to main. Merge mode is constrained to preserve a clean history. The main branch maintains linear, CI-validated state. Auto-merge on green is allowed only when the diff has already passed the human gate before PR creation.

**Anti-example.** Treating "bypassed rule violations" output as a note to surface later. Pushing directly to main "just this once" because the change feels small. Scope: this principle binds repos with a remote main branch under protection; early-development repos with no remote yet follow their own workflow rules, but the moment a remote exists, the gate applies.

### P-ShiftLeft

Shift the human gate left. (Anchors Reversibility, Decomposition.)

**Why.** Rework cost grows the later it's caught. The decomposer's eye catches "this isn't what I meant" — a structural-intent check that automated gates can't make. Automated gates catch structural defects — a correctness check the decomposer doesn't have time to make. Both layers are required; neither replaces the other.

**How it shows up.** The decomposer reviews the diff before PR creation, not after. Automated reviewers (security, code, tests) run after every implementation cycle, not just at the end. The closed-enum approval vocabulary moves the decomposer's intent into a state machine that subsequent gates can read.

Three decomposition discipline patterns operationalize the shift-left posture upstream of code review. First, *scope known before execution*: the spec carries explicit scope (layers touched, layers not touched, data requirements, whether existing surfaces satisfy) and the plan is pure sequencing once scope is locked. A plan with an "audit the API surface" step or other investigation that was owed at design time is the spec reporting a decomposition gap. Second, *validator before field*: for any structured schema (spec template, ADR shape, completion-report header, intake form), write the mechanical Stage-X validator for each candidate field before adding the field. A hand-wavy validator means the field hasn't earned its slot; tightening the validator forces the field into one of three resolutions, namely narrower scope, a different stage, or recognition as a property rather than a field. Third, *catalog before unifying mechanism*: within a single research pass, catalog the operation/concept surface first, propose the simplest unified shape, then let decomposition emerge from where the shape strains. Don't import an external framework's family of abstractions top-down. The decomposer's grain operates at the structural-mechanism layer; reviewers and orchestrators check for these patterns at workflow handoff boundaries.

Three cross-stack mechanism rules operationalize the decomposition discipline (anti-example-anchored, same form as the P-MinBlastRadius rules):

| # | Rule | Anti-example |
|---|------|--------------|
| D1 | **Scope known before planning.** A spec carries explicit scope: layers touched, layers not touched, data requirements, whether existing surfaces satisfy. A plan that includes "audit X" or "check whether Y exists" is the spec reporting a decomposition gap; fix the spec. | A redesign plan whose first phase was an "API audit" step: scope discovery that was owed at design time leaked into the plan. |
| D2 | **Validator before field.** For any structured schema (spec template, ADR shape, completion-report header, intake form), write the mechanical Stage-X validator for each candidate field before adding the field. A hand-wavy validator means the field doesn't earn its slot. | An intake-schema review that caught two ambiguous fields (a risk-profile-at-intake field and an audience-as-field) only because each was made to face a mechanical validator first. |
| D3 | **Catalog before unifying mechanism.** Within a single research pass, catalog the operation/concept surface first, propose the simplest unified shape, then let decomposition emerge from where the shape strains. Don't impose a family of abstractions top-down from an external framework. | A knowledge-object survey that converged on a small schema family by catalog-then-strain rather than by importing an external framework's structure wholesale. |

**Anti-example.** Autonomous merge to main without a decomposer-intent check. Removing the decomposer's review even when automated gates passed clean — the gates check correctness, not intent. Trying to make the decomposer faster by surfacing every flag instead of trusting the loop on the routine ones.

### P-TDDPairs

TDD pairs on non-trivial work; self-tests on mechanical work. (Anchors Quality, Decomposition.)

**Why.** Single-agent TDD is a known contamination failure mode — the same model writing tests and implementation in one context relaxes assertions to make the suite green. Property-based tests are spec-derived rather than impl-derived, so they catch spec-vs-impl drift the same agent can't see.

The quality-over-speed tradeoff is corroborated by industrial TDD studies (a four-team industrial study found 40-90% lower pre-release defect density at a 15-35% development-time cost; a controlled experiment found test-first code passed 18% more black-box cases at a 16% time cost). The single-agent contamination mechanism is corroborated by AI-era empirical work: a 2026 study of LLM coding agents found agent-written tests are dominated by value-revealing output over assertions, and that changing test *volume* did not change task outcomes. Agent self-tests reshape process and cost more than they verify behavior. Property-based tests resist this because a property is a specification-derived invariant (the technique originates with QuickCheck, 2000): it asserts what the code *should* do independent of what it *does*, so it detects spec-vs-impl drift that an implementation-derived test cannot. The failure the discipline defends against is the "cycle of self-deception," tests that share the implementation's flaws.

**How it shows up.** Non-trivial work — security boundaries, concurrency, public APIs, data validation, trait or interface contracts — gets a red-phase test task dispatched separately from the implementation task. The test-writer dispatches first; the implementer's task depends on the red phase landing. Mechanical work — scaffolds, config loaders, simple CRUD, format conversions — accepts implementer self-tests because the contamination risk is low and the dispatch overhead is high relative to the work.

Verifying the red phase means confirming the test fails for the spec reason, not merely that it fails. A test that errors before its behavioral assertion runs, because a dependency is un-mocked or a setup step is wrong, is a wrong-reason red. It is a red-phase defect, not a valid red phase. Assertions on spec-mandated output use the strength the spec mandates. Where the spec requires equality, a substring or positional check is too weak. Assert equality. A test suite that cannot fail (counters that never increment, a harness that always exits zero) is not a test. Tests do not mutate process-global state without isolation, and carry no hardcoded secrets even in fixtures.

Five cross-stack mechanism rules operationalize this principle (anti-example-anchored, same form as the P-MinBlastRadius rules):

| # | Rule | Anti-example |
|---|------|--------------|
| T1 | **Assertions are spec-derived, not implementation-derived.** A non-trivial surface's tests are written from the specification by a separate context, before the implementation, so they encode intended behavior independently. On critical logic (parsers, validators, security boundaries) the assertion is a property (a spec invariant), not a single worked example. | An acceptance criterion satisfiable by pasting the expected output into a file without running the behavior under test. The test was shaped to the artifact, not the spec. |
| T2 | **Verify red for the *right reason*.** A red phase passes only when the test fails on the behavioral assertion the spec names. A test that errors before its assertion runs (un-mocked dependency, setup fault) is a wrong-reason red and is a red-phase defect. Grade the pre-review red run, not a post-review artifact that was fixed into shape. | A red-phase test that throws on an un-stubbed call before reaching its behavioral assertion. The test is reported as a valid failing test. It is not. |
| T3 | **Assertions are as strong as the spec mandates, and the suite can fail.** Where the spec requires equality, assert equality. A substring/positional/`in` check is too weak. A harness whose counters never increment or that always exits zero is not a test. | A golden-output test using a substring/position check where the spec requires exact equality; a runner that reports 0/0 passed and exits zero while testing nothing. |
| T4 | **Tests isolate process-global state.** Tests that mutate global state (environment variables, process-wide config, shared fixtures) serialize access so they do not flake under parallel execution. | A test mutating a process-global environment variable with no isolation, passing single-threaded and flaking under the parallel test runner. |
| T5 | **No hardcoded secrets in tests.** Test credentials are generated per run from a shared helper, not literal constants, even in fixtures and even when not exploitable. Fix the smell; do not filter the scanner. | A test fixture with a hardcoded password literal, dismissed as a scanner false-positive and excluded by path filter instead of removed. |

The split that already exists (non-trivial surfaces get a separate red-phase task; mechanical work accepts implementer self-tests) is unchanged; T1-T5 specify what good looks like inside the red-phase task once the split has been made.

**Anti-example.** Asking a single agent to write tests, implementation, and recovery for a security boundary in one dispatch. Re-presenting the TDD-pair pattern as "one of three options" each dispatch instead of applying it as standard. Single-agent TDD on parsers, validators, allowlists, or anything that ingests untrusted input.

### P-IterateToZero

Iterate-to-zero with stable finding identity, hard cap. (Anchors Quality, Reversibility.)

**Why.** Iterate-to-zero only converges if "same finding" can be detected across rounds; otherwise the count drifts and the cap exhausts on cosmetic restatements of fixed defects. Finding identity must be content-anchored, not line-anchored — formatting passes shift line numbers without changing the underlying defect. The cap exists because fix loops longer than the limit usually indicate a deeper design problem the loop won't resolve — escalate, don't grind.

This is the AI-era operationalization of formal inspection's iterate-to-converge discipline (Fagan, 1976 — 60–90% defect detection through structured rounds with per-round diminishing returns). The loop converges *only because the grading signal is external*. Intrinsic self-correction — the same agent grading and fixing its own output with no outside feedback — is empirically shown to sometimes *degrade* output across self-correction rounds rather than improve it (Huang et al., ICLR 2024). The reviewer is that external signal; this is why iterate-to-zero depends-on heterogeneous reviewers (P-HeterogeneousReviewers) rather than treating review as optional polish — the dependency is what keeps the loop on the convergent side of the self-correction result.

**How it shows up.** Finding identity is a tuple of file plus content-anchor (a normalized window around the cited finding) plus severity. Dedup keys ignore severity so a downgraded finding still matches; gating uses current-round severity. After each implementation cycle, the orchestrator runs a deterministic format pass before review so reviewer findings don't drift on whitespace.

A fix can move a defect's content-anchor and surface a *related* defect in its place — the fix-induced variant (a worked instance: a label-authorization fix closed the original path but left a sibling path open at a new anchor). A fix-induced variant counts as a new finding for convergence accounting (its anchor differs), but the round records it *as* fix-induced rather than as an unrelated discovery. The fraction of a round's new findings that are fix-induced variants is the discriminator between a loop that is converging (variants trending to zero) and a loop that is grinding on a deeper design problem (variants persisting or rising) — when that fraction stays high as the cap approaches, the cap-escalation discipline applies (escalate to a design conversation; see P-TrustThenRetro's *cap-escalation-vs-iteration* discipline). The content-anchor's stability is bounded: it survives line-shift and formatter churn (a normalized window absorbs whitespace and line-number drift), but agent regeneration between rounds can rewrite the surrounding code semantically — renaming, extracting, reordering — and rotate the anchor without resolving the defect. The remap pass handles the mechanical cases; semantic-drift handling beyond remap is deferred until evidence forces it (P-Defer), the trip-wire being remapped-FIXED entries that re-occur at a different anchor above a threshold.

Three cross-stack mechanism rules operationalize this principle (anti-example-anchored, same form as the P-MinBlastRadius rules):

| # | Rule | Anti-example |
|---|------|--------------|
| I1 | **Identity is content-anchored, never line-anchored.** A finding's identity across rounds is `(file, content-anchor, severity)` where the anchor is a normalized window of code, not a line range. Line-anchored identity breaks every round under AI-era between-round churn. | A finding tuple keyed on `path:42-58`: an agent inserts ten lines higher in the file between rounds, the same untouched defect now reads `path:52-68`, the round counts it as new, and the cap exhausts on one underlying issue. (The line-shift incident that drove G-0014's content-anchor decision; corroborated industry-wide by GitClear's two-week churn rising 3.1%→5.7%.) |
| I2 | **Dedup ignores severity; the gate reads current-round severity.** "Same finding across rounds" is keyed on `(file, content-anchor)` with severity excluded, so a downgraded finding still matches; the merge/ship gate then reads the current round's severity to decide whether it still blocks. | A reviewer downgrades a `blocker` to `nit` after a partial fix; a severity-in-the-key identity counts it as a new finding (cap exhaustion) *and* a downgrade-to-`nit` produces a false-pass exit while the defect is still present. (G-0014's M9 closure.) |
| I3 | **A fix-induced variant counts as new but is recorded as fix-induced; rising variant-rate near the cap triggers escalation, not another round.** When a round's new finding is a variant of a prior finding the fix shifted (different anchor, related defect), the round dispositions it as a variant. If variants stay a high fraction of new findings as the cap approaches, the loop is grinding — escalate to a design conversation per P-TrustThenRetro's cap-escalation discipline. | A label-authorization fix closes the original path but leaves a detective-only sibling path open at a new anchor; three rounds later the same defect class keeps reappearing at fresh anchors and the loop grinds to the hard cap on a problem a one-line structural decision would have closed. (Worked instance from the review corpus; the implementation-side analogue is a fix loop re-attempting verification three times against the same surface without converging.) |

**Anti-example.** Reviewer-assigned finding IDs that depend on the reviewer remembering state across rounds. A line-anchored identity tuple that breaks every time a formatter runs. Grinding past the round cap on a defect that keeps reappearing in different shapes — the right move there is a design conversation, not another fix attempt.

### P-HeterogeneousReviewers

Reviewers are heterogeneous specialists, layered by surface. (Anchors Honesty, Quality.)

**Why.** Multiple copies of the same model converge on the same blind spots — the homogeneous LLM-on-LLM echo failure mode. Heterogeneous specialists each apply a distinct domain lens (security, operations, accessibility, voice, test design, research, perspective) and surface different findings. Layering is by surface touched, not by routine fan-out.

This is the algorithmic-monoculture failure formalized outside the workspace. A collection of decision-makers running the same construction is susceptible to correlated failure even when each is individually more capable (Kleinberg & Raghavan 2021). Shared components (same base model, same training data) homogenize outcomes by construction, not merely by coincidence of heuristic (Bommasani et al. 2022). Same-model evaluation also carries a measurable self-preference bias (Panickssery et al. 2024): a copy reviewing a sibling's output is biased toward the patterns it shares with that sibling, compounding rather than correcting the shared error. The literature's prescribed fix is evaluator diversity by construction (Verga et al. 2024), which is what "heterogeneous specialists, layered by surface" operationalizes, with model-tier diversity added where review judgment is load-bearing (the perspective-versus-judgment split: the assigned lens selects which reviewer, the model tier selects the judgment depth, and the two choices are independent).

**How it shows up.** A code-and-security reviewer is on every change. Other specialists join when their domain is touched: UI changes draw an accessibility-and-design reviewer; deploy or CI changes draw an operations reviewer; external-facing prose draws a voice-and-clarity reviewer; backend logic implemented by one perspective draws a different perspective lens. Briefs are scoped to a single tier — discovery review surfaces requirement gaps, architecture review surfaces mechanism choices, execution review surfaces migration concerns. Mixing tiers produces noise.

The heterogeneity also catches factual errors the originating author would not have surfaced alone. A worked instance: a decision record claimed a release tool enforced a path-coverage check; the operations reviewer's distinct lens verified the tool's actual mechanism (commit-message matching, no path coverage) and surfaced the unverified claim before it shipped. Without the heterogeneous-reviewer pass the false mechanism would have landed, and subsequent specs would have built on it. Heterogeneity is a Honesty mechanism, not only a quality mechanism.

Heterogeneity also compounds over time through the review-mining loop. Because distinct lenses produce distinct findings (a homogeneous set produces correlated findings that collapse to one), the review corpus accumulates a diverse finding stream worth mining. Recurring findings get extracted and embedded into the relevant skill or agent profile, so the next review no longer has to re-find them. The maintainability review (findings landing in the stack skills) and this principles series (review findings landing as canon amendments) are worked examples: heterogeneous review produces distinct findings, distinct findings become an embedded rule, and the finding stops recurring. A homogeneous reviewer set short-circuits the loop at the first step, because correlated reviewers produce the same findings, collapsing the diverse input stream the loop depends on.

Four cross-stack mechanism rules operationalize this principle (anti-example-anchored, same form as the P-MinBlastRadius rules):

| # | Rule | Anti-example |
|---|------|--------------|
| H1 | **Select reviewers by lens, not by name or count.** A touched surface draws the reviewer whose lens covers it; a surface with no matching lens draws no reviewer, not a default one. Confidence does not come from more reviewers. It comes from more *distinct* lenses. | Adding a second reviewer "to be safe" when the second carries no lens the first lacks: correlated draws add confidence, not coverage. |
| H2 | **Same model fanned out is not heterogeneity.** Re-running one agent on one artifact, even across separate dispatches, produces correlated errors by construction (shared base model). Heterogeneity requires a distinct *lens*; where review judgment is load-bearing, a distinct *model tier* strengthens it. | Dispatching the same reviewer three times for confidence, or treating two same-model passes as an independent cross-check. |
| H3 | **Author and reviewer are separate participants at dispatch time.** The participant who produced an artifact does not gate it; a distinct lens does. This holds at document granularity (implementer is not reviewer) and at sub-document granularity (a second-lens cross-check on one's own draft before it hardens). | A single agent writing tests, implementation, and self-review in one pass: assertions relax to make its own output pass. |
| H4 | **One tier and one surface per reviewer brief; load lenses conditionally.** A reviewer brief is scoped to a single review tier (discovery, architecture, or execution) and the lens-specific skill loads only when the diff touches its surface. Tier-mixing produces false positives at every tier; always-loading every lens burns context and dilutes signal. | A brief asking one reviewer to flag requirement gaps, mechanism choices, and migration concerns at once; or every security sub-lens loaded on a diff with no matching surface. |

**Anti-example.** Running the same reviewer three times for confidence. Adding a generic-purpose reviewer that duplicates an existing lens. Putting tier-mixed findings in one reviewer brief — the result is false-positive findings at every tier.

### P-PreserveDecisionSpace

Preserve the decision space. (Anchors Honesty, Decomposition.)

**Why.** Decisions stripped of their rejected alternatives become unreproducible — the next reader and the next decision-making session re-litigate the same options blind. Artifacts rewritten without preserving prior versions lose the durable trail of what changed and why. Both forms of erasure cost the same thing: future readers can't see the option space the decision was made against.

**How it shows up.** Every architecture decision record carries an Alternatives Considered section listing rejected options with reasons. Open/Deferred sections document what was *not* adopted, each with a trigger to revisit. Evolving documents carry a Changelog section in-line; snapshot-style coexistence (where multiple versions need to live side-by-side) uses a version prefix on the filename, but evolving docs amend rather than re-version. Amend, don't erase.

**Anti-example.** "We chose X because X is the right answer," without naming what the alternatives were and why they lost. Dropping a rejected alternative from the Considered list because it now feels obviously wrong — the future reader needs to know it was on the table. Rewriting a living doc without recording what changed. Asserting a factual claim without its evidence basis ("the maintainer uses X" with no grounding in a personal-baseline, a user-context memory, or a verified prior-work artifact): the future reader cannot see the basis the claim was evaluated against, and the structural failure is the same shape as an erased alternative because both make the artifact's reasoning unreproducible. The worked instance is an inference jump that produced a fabricated vendor-integration claim (the agent observed the maintainer uses a tool, observed the vendor ships an integration for it, and concluded the maintainer uses that integration); the discipline the workspace landed in response requires source-grounding before any such claim hardens.

### P-WriteTimeAudience

Generic at write-time for repo artifacts; identity-preserving for workspace artifacts. (Anchors Honesty, Dogfooding.)

**Why.** Two durability profiles need two write-time disciplines. Repo-persisted artifacts (specs, ADRs, plans, READMEs) live in a context where any commit can become a publish event — there's no reliable "right before publish" sweep moment. They get genericized at write-time: generic role labels, no workspace-specific paths, no internal-feedback citations, no team-agent personal names. Workspace-private artifacts (reviews, internal field notes) preserve team-agent attribution because that *is* the pattern signal worth keeping for future analysis and learning.

**How it shows up.** A repo's specs and ADRs use roles ("the maintainer," "the implementing developer," "the design reviewer"). A workspace-private review keeps the reviewing agent's name, the dispatch identifier, and the context of the dispatch. Reviews live workspace-internal, not in the project repo, precisely so the attribution can be preserved without leaking on publish.

For repo-persisted artifacts specifically, the discipline strips: workspace absolute paths (`/Users/...`, `$HOME/...`, bare workspace-root references), workspace-internal directory citations (`brain/...`, `team_inbox/`, `scratch/`), workspace-feedback-memory citations (`feedback_*.md`), workspace-team-agent names (the orchestrator's and specialist agents' personal labels), and memory-internal taxonomy (the task DB, the workspace-CLI binary, internal-project codenames). The maintainer's name in narrative is preserved when the artifact is theirs: the discipline strips workspace-internal taxonomy, not authorship attribution. Workspace-internal operational specs that are never destined for a project repo are exempt; the discipline applies at the durability boundary, not as a blanket sweep. This enumeration is the source-of-truth; the workspace operational rules carry an imperative pointer back to it rather than a second copy.

Three cross-stack mechanism rules operationalize this principle at the artifact level (anti-example-anchored, same form as the P-MinBlastRadius rules):

| # | Rule | Anti-example |
|---|------|--------------|
| W1 | **Role-label-before-name check at write.** When writing a repo-persisted artifact, name the participant by role ("the maintainer," "the implementer," "the security reviewer," "the orchestrator"). Use a personal name only when authorship attribution requires it (the maintainer's name in narrative when the artifact is theirs) or when the name is the externally-known product or framework name. Personal names for team-agent specialists are workspace-internal vocabulary and do not survive into repo artifacts. | A published project spec that says "the orchestrator must decide before dispatch whether the SvelteKit specialist waits," leaking orchestrator and specialist by workspace-internal name. |
| W2 | **Path-and-citation hygiene check at write.** When writing a repo-persisted artifact, never cite workspace absolute paths, workspace-internal directory roots (`brain/...`, `team_inbox/`, `scratch/`), workspace-feedback-memory files (`feedback_*.md`), or memory-internal taxonomy (the task DB, workspace-CLI binary paths). The repo's own paths are fine; the workspace's are not. The maintainer's name in narrative is permitted when authorship requires it. | A published project spec whose Target line is an absolute workspace path under the operator's home directory. |
| W3 | **Two-profile decision before file creation, not at move-time.** Before creating a file, name its durability profile: workspace-private (lives outside the project repo tree; identity-preserving discipline applies) or repo-persisted (lives inside the repo tree; generic-at-write discipline applies). Don't write under one profile and refactor at move-time; the over-genericization vector lives at those move moments, where identity-preserving content gets stripped on the way in. | A mid-development sweep over workspace-internal skill files that would have stripped the configured-agent attribution the maintainer values during daily use; the right discipline is to decide each new file's destination at creation, not to sweep mid-life. |

**Anti-example.** Putting reviewer files inside a project repo where they'll ride along on publish. Writing a project ADR that cites a workspace-internal feedback note. Genericizing a workspace-private artifact to the point where it loses the attribution that made it useful.

### P-TrustThenRetro

Trust the loop; retro selectively. (Anchors Dual-audience, Quality.)

**Why.** This is a principle about the architecture of the human–agentic-team composition itself, not about any single system. Direction is set up-front by the decomposer; the team executes within direction; review concentrates on outcomes and patterns rather than per-step approval. Walking every flag returns the decomposer to a per-step approval gate rather than the direction-setter role — and the decomposer is the bottleneck in the composition. Optimizing review time on what matters is what makes the workflow sustainable; trusting the rest until evidence says otherwise is what makes the composition scale.

**How it shows up.** Routine quality gates (automated review, test execution, format passes) run and resolve their findings without per-finding approval, escalating only on patterns that exceed a threshold. Architectural concerns get flagged in deviation reports — not blocked at execution time. The decomposer's review is shifted to load-bearing checkpoints (intent-mismatch, scope drift, design conflicts), not to every diff line.

Three composition failure-mode patterns are anti-cases for this principle: (a) *wrong participant in control* — the orchestrator executing directly when the work should have been dispatched, or executing without intent grounding the human's context would have supplied; (b) *insufficient handoff* — a dispatch lacking the context-load that lets the dispatched agent act under the orchestrator's intent (missing skill injection, missing scope envelope, wrong question-shape for the receiving agent); (c) *trust failures in either direction* — under-trust where the orchestrator walks every routine finding with the human and serializes work through human attention, or over-trust where the orchestrator introduces decisions without the reviewer signal that would catch wrong assumptions. Reviewers and orchestrators check for these patterns at handoff boundaries.

Three trust-calibration disciplines operationalize this principle at dispatch boundaries; where the failure-mode catalog above names what to avoid, these name what to do. First, *participant capability declaration*: every dispatched agent's scope envelope declares what the agent is reliable for. Reliance above the declared scope is over-trust; reliance below it is under-trust. Calibration is to the declared scope, not to general agent capability. Second, *reliance-level taxonomy at dispatch time*: each dispatch sits at one of three reliance levels. Advice means the agent proposes and the decomposer decides. Vetted means the agent acts, a reviewer gates, and the decomposer samples. Autonomous-with-veto means the agent acts within bounds and the decomposer overrides post-hoc. The level is a dispatch parameter, not a runtime discovery. Third, *cap escalation versus iteration*: when an iterate-to-zero loop approaches the cap (P-IterateToZero), the escalation mode is a design conversation, not another fix round. Grinding past the cap on a defect that keeps reappearing in different shapes is the failure mode the cap exists to prevent.

**Anti-example.** Surfacing every reviewer finding for per-item approval before the dispatched fix can land. Treating routine pre-commit and CI failures as escalations rather than routine. Re-presenting standard practices as menu options on every dispatch instead of applying them silently.

### P-CompositionBridge

Durable artifacts close the human-agent asymmetry. (Anchors Composition, Dogfooding.)

**Why.** The human in the composition carries persistent low-resolution context (years of decisions, patterns, taste, accumulated rules); the agentic team carries session-scoped high-resolution context (fine-grained file state, current spec, in-loop reasoning). The asymmetry doesn't close at runtime — there is no protocol that loads years of context into a session prompt at sufficient resolution. It closes at the *artifact layer* — durable encodings (architecture documents, skill files, ADRs, the workspace canon, the task DB) that load the slow-changing context into the fast-loading session. Where the artifact is present and current, the composition is stable; where it is missing or stale, the asymmetry leaks at runtime and either the human becomes the bottleneck (re-explaining context every session) or the agent runs without grounding.

**How it shows up.** Session-level patterns get encoded into reloadable artifacts when caught (the knowledge-extraction loop). Specs, ADRs, and architecture docs are agent-primary (G-0027) — written to be loaded cold and applied directly, not to be summarized for an agent that then loads its summary. Constraint baselines (principles, values, ADRs) load at every workflow-stage start (G-0028 Stage 0) — never assumed to be latent. Memory writes are bounded and append-only at the carrier's discretion (G-0007..G-0012); hooks never write rule content. Cross-session continuity is handled by stash and inbox, both visible at session-start checklists; nothing is left to organic recall.

Three cross-stack rules operationalize this principle (composition discipline at the participant boundary):

- **Participant-in-control check before action.** Before acting, name which participant should be in control. If the answer is "the orchestrator" but the work is in a category that always dispatches (project source, tests, runtime config, spec revisions, README, ADRs), the answer is wrong — dispatch.
- **Handoff context-load before dispatch.** A dispatch is well-formed when the receiving agent has objective, output format and completion-report shape, tool and scope guidance, task boundaries, and load-bearing skill injection. Hand-built dispatches with one or two template blocks are the failure mode.
- **Trust-execute-retro after direction.** Once direction is set on a structured flow, execute forward; the orchestrator reviews selectively at points of the human's choosing, and retros on outcome divergence. Walking every flag with the human serializes work through their attention, which is never the goal.

**Anti-example.** A skill or ADR drafted referencing memory paths or team names without verification. A spec carrying claims about "the operator uses X" that aren't anchored in a memory or file. A repeated pattern across sessions that surfaces in three retros before being encoded as a rule (the bottleneck the knowledge-extraction loop exists to close). An orchestrator executing a spec edit directly instead of dispatching, or a hand-built agent call with one template block where five were required.

## Changelog

- **2026-05-21** — Tier-1 Batch B canon landing. Extended P-HeterogeneousReviewers "Why" with AI-era algorithmic-monoculture grounding (Kleinberg & Raghavan 2021, Bommasani et al. 2022, Panickssery et al. 2024, Verga et al. 2024) and "How it shows up" with the review-mining loop, plus four X-rules (H1-H4). Extended P-TDDPairs "Why" with industrial and AI-era empirical grounding and "How it shows up" with red-phase / assertion-strength discipline, plus five X-rules (T1-T5) and a companion Rust stack-skill `<P-TDDPairs>` block (TF1-TF4). Extended P-IterateToZero "Why" with the external-feedback dependency (Huang et al., ICLR 2024) and "How it shows up" with the fix-induced-variant disposition and the semantic-drift boundary, plus three X-rules (I1-I3). Added reviewer-seat and orchestrator `<push-back-when>` rules to the agent profiles. The cap number stays domain-specific (principle remains number-free). Each principle validated under outside literature, AI-era empirical work, and the workspace review corpus.
- **2026-05-17** — Tier-1 Batch A canon landing. Extended P-ShiftLeft "How it shows up" with three decomposition discipline patterns plus D1-D3 X-rules; extended P-WriteTimeAudience "How it shows up" with the relocated repo-artifact enumeration (now source-of-truth) plus W1-W3 X-rules; extended P-TrustThenRetro "How it shows up" with three trust-calibration disciplines (participant-capability-declaration / reliance-level-taxonomy / cap-escalation-vs-iteration), composing with the existing failure-mode catalog; extended P-PreserveDecisionSpace Anti-example with the fabricated-claim case; extended P-HeterogeneousReviewers "How it shows up" with the unverified-mechanism worked example. P-TrustThenRetro validated under external literature (Bainbridge 1983 / Lee & See 2004 / Hollnagel 2009).
- **2026-05-15** — Added P-CompositionBridge principle (artifact-as-substrate) and extended P-TrustThenRetro "How it shows up" with three composition failure-mode patterns (wrong-participant / insufficient-handoff / trust-failures-both-directions). Operationalizes Composition value's substrate mechanism and protocol mechanism under separate principles by mechanism distinction. Three cross-stack X-rules (participant-in-control check, handoff context-load, trust-execute-retro) land under P-CompositionBridge.
- **2026-05-13** — Added P-MinBlastRadius principle. Operationalizes the new Maintainability core value via information-hiding + locality + change-isolation seams + cross-stack X-rules. Composes with P-LockContract (system-boundary case) and P-Worktrees (workflow-layer change isolation).
- **2026-04-30** — Initial structure: 15 named principles (`P-Defer`, `P-PerRepoFirst`, `P-LockContract`, `P-StackDiscipline`, `P-SecurityLayered`, `P-InstrumentBefore`, `P-Worktrees`, `P-MainProtected`, `P-ShiftLeft`, `P-TDDPairs`, `P-IterateToZero`, `P-HeterogeneousReviewers`, `P-PreserveDecisionSpace`, `P-WriteTimeAudience`, `P-TrustThenRetro`).
