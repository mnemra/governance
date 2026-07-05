---
title: Glossary
summary: "Terms and conventions used across the mnemra governance canon."
primary-audience: human
---

# Glossary

Terms and conventions used across this canon. A first-time reader can start here. Entries are grouped by kind: the document set, the naming conventions, the roles, the workflow vocabulary, and the domain terms the architecture decision records assume.

## Document set

**Architecture values.** The standing beliefs that shape every architecture decision. Eight core values (Security, Simplicity, Quality, Observability, Maintainability, Honesty, Decomposition, Composition) plus supporting method values. Lives in `architecture-values.md`.

**Architecture principles.** Named rules that operationalize the values. Each carries a `P-` label and traces back to one or more values. Lives in `architecture-principles.md`.

**Constraint edges.** The relationships between values, principles, and ADRs, expressed as a graph of typed edges (specializes, depends-on, conflicts-with, refines). The nodes live in the values doc, the principles doc, and the ADR files; this doc is the edges view over them. Lives in `constraint-edges.md`.

**G-ADR.** A governance architecture decision record. The `G-` series captures decisions that apply across the ecosystem rather than to one project. G-0001 through G-0016 at the time of this writing.

## Naming conventions

**`G-` prefix.** Governance-level ADRs. They apply to the whole ecosystem and live in this repo under `adrs/`.

**`P-` prefix.** Two meanings, disambiguated by context. As a principle label (`P-Defer`, `P-LockContract`) it names an entry in the principles doc. As an ADR prefix it names a project-level decision record that lives in an individual project repo, not here. The principles doc and the ADR series both use `P-`; the surrounding words make clear which is meant.

**MADR.** Markdown Any Decision Record, the lightweight ADR template the `G-` series follows: Context, Decision, Alternatives Considered, Consequences.

## Roles

These labels name participants by function. The canon uses them in place of internal personal names.

**The maintainer.** The person who owns the canon and sets direction. Named directly in narrative when a document is theirs.

**The decomposer.** The role that figures out what to build before execution: framing a design session, drafting an ADR, writing a spec, cutting scope. The decomposer sets direction; the agentic team works inside it.

**The orchestrator.** The role that routes and coordinates work: assessing a task, dispatching it to a specialist, and integrating the result. The orchestrator does not execute the specialist work itself.

**The agentic team.** The specialists the orchestrator dispatches to. They execute within direction. Specialists carry function labels too: the implementer (backend or frontend), the code reviewer, the security reviewer, the QA engineer, the researcher, the operations engineer, the writer, the designer, the conformance reviewer, the plan author.

## Workflow vocabulary

**Brief.** The unified workflow that runs a piece of work from intake through a locked spec. Its stages are Intake, Frame, and Spec, with human checkpoints at intake, Frame exit, and spec exit.

**Frame.** The brief stage that elicits and synthesizes the problem shape before a spec is written. It produces a framed problem the spec stage builds on.

**Spec.** A specification that defines what done looks like. The decomposer writes it before implementation. Agents decide how; the spec defines what.

**Verify.** The backstop stage that re-validates a finished change against the spec it was built from.

**Discover.** The earlier-generation discovery pass that shaped scope before a spec. The brief workflow absorbs its role.

**Stage 0 through Stage 7.** The numbered steps of a change's life from baseline-load (Stage 0) through review (Stage 4), approval labelling (Stage 6), and auto-merge (Stage 7). Several G-ADRs decide the mechanics of specific stages.

**Dispatch.** Handing a scoped task to a specialist with the context that lets them act on the decomposer's intent: the skill injection, the scope envelope, and the question shape the receiving role needs.

**Iterate-to-zero.** The review loop that runs fix-and-review rounds until no blocking finding remains, with a round cap that triggers escalation rather than another round.

**Worktree.** A separate working tree off the main branch, opened per code-modifying dispatch so the main branch stays stable and failed work is discardable.

## Domain terms

**Finding identity.** The tuple that decides whether two review findings across rounds are the same defect: file plus content-anchor plus severity. Dedup ignores severity so a downgraded finding still matches; gating reads current-round severity. Defined in G-0004.

**Content-anchor.** A hash of a normalized window of code around a cited finding. It anchors a finding to content rather than line numbers, so the finding survives line shifts and reformatting.

**Edge types.** The four relationships in the constraint graph. Specializes: the source is a specific case of the target. Depends-on: the source presupposes the target. Conflicts-with: the two can't both hold without negotiation. Refines: the source tightens the target within the same domain.

**Dual-audience publish model.** The publishing posture for this canon. The source documents are agent-primary: written for agents first, with humans as a derivative audience. Each page declares a `primary-audience` in its frontmatter. At publish time the sources render into a human-facing site and an agent-facing set used to generate `llms.txt` and `llms-full.txt`.

**Agent-primary source.** A source artifact (spec, ADR, principle) authored for an agent reader as the first consumer. Human-readable views are generated from it rather than maintained alongside it.

**Guardrails.** Hard operational rules that forbid actions outright: credential handling, destructive git operations, force-push to a protected branch, external-publishing approval. When a value or principle pulls against a guardrail, the guardrail wins.

**Quality attribute.** A non-functional system property (security, simplicity, quality, observability, maintainability) that applies to every project regardless of feature scope.

**Minimum-blast-radius fix.** The unit goal of the Maintainability value: when a change is needed, the architecture supports isolating it to the smallest surface. A fix that forces a sprawling rewrite signals a deeper problem to surface as its own task.

**Dogfooding.** Using a tool internally before shipping it, so the pain that drives the roadmap is pain actually hit rather than pain a hypothetical user might hit.
