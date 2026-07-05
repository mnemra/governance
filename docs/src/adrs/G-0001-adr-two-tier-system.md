---
title: "G-0001: Two-Tier Architecture Decision Records"
summary: "General standards are numbered ADRs recorded once in a central location; project-specific decisions are P-prefixed ADRs that home with the project and shift into its repo when one is created; qualifying general defaults project into a repo's DEFAULTS.md. A project is a unit of work; a repo is optional."
primary-audience: agent
---

# G-0001: Two-Tier Architecture Decision Records

**Status:** Accepted
**Date:** 2026-04-05

## Context

Design decisions were scattered across notes, task descriptions, and conversation history. None of those forms are readable architectural documentation. Projects published to public repositories need self-contained decision records that do not reference internal structure. General standards (testing philosophy, build patterns) apply across projects but were being rediscovered per project.

One framing to correct up front: "projects published to a public repository need self-contained decision records" reads as if having a repo were a *defining* property of being a project. It is not. Self-containment-when-published is a property of the *published form* of a project — its materialized repo — not of *being* a project. A project exists, and homes its knowledge, with or without a repo.

## Decision

### What a project is

**A project is a unit of work with associated data; a repo is optional (0, 1, or many).** A repo is one *kind* of associated data — ADRs, tasks, and research are others. The unit is the "project," not the "product" (which smuggles in "has a repo"). This aligns with the existing project registry, where projects without a repo already exist. A project may be *tagged* with one or more subject facets; a subject is an orthogonal axis, **not** a project (governance, for instance, is a cross-cutting concern living inside projects, not a project of its own).

**General-vs-project test.** An ADR is **general** when it states a rule you would reuse building *other* projects (ecosystem governance, a hard-to-reverse fork every project follows). It is **project-specific** when it is specific to one project. Location follows the test, not the reverse: a decision that governs only one project is a project ADR even if it currently has no repo to live in.

**General ADRs include cross-project conditional defaults.** A rule of the form "if a project needs X → use Y" (e.g., "if you need a relational DB → Postgres") is a *general* ADR — reusable across projects, hard to reverse — that **projects into** each *qualifying* project rather than living in one. It is general because the rule is reusable; it is conditional because it applies only to projects that meet its predicate. How a project knows it "qualifies" to receive a conditional default is a mechanism deliberately left unbuilt until two projects actually disagree about whether a default applies to them; that disagreement cannot arise without someone raising it, so the need is self-announcing and no detector is required in advance.

### Where a project's knowledge lives (the home rule)

There is one rule, not a special case: **a project's knowledge home is a persistent per-project location.** Its details, research, status, and decisions live there from the moment the project exists — with or without a repo. This home is persistent: a repo never replaces it and never decides where a project's information lives. (This is a recovered convention, already in practice — the project knowledge home holds both projects with repos and projects without; a project may live there before any repo exists and continue to after one is created.)

The split of *what goes where* is by **what the artifact governs**, and the project→repo shift activates **when a repo is created**:

- **General project information** (research, status, exploration, details) stays in the project's knowledge home, repo or not.
- **Project-specific (P-) ADRs** govern how the code is written, so they belong where the implementation is worked on. While there is no repo, they home in the project's knowledge home under a `docs/src/adrs/` path (nowhere else to go). When a repo is created they **shift** into the repo (`docs/src/adrs/`); after the shift, the repo is their home. The pre-repo path **mirrors** the repo path so the shift is a clean move, not a re-layout.
- **Qualifying general (G-) ADRs** project into the repo's `DEFAULTS.md` at repo-creation — only the ones the project needs. Pre-repo, the project reads general ADRs from the central location directly and carries **no** `DEFAULTS.md`.

**Materialization trigger.** At repo-creation (and thereafter as needed), the repo receives, as a single repo-bootstrap step, (a) the projected qualifying general ADRs as `DEFAULTS.md` and (b) its own project-specific P-ADRs shifted from the project's knowledge home.

**Store form.** Filesystem markdown under the project's knowledge home — the *same* store the general ADRs themselves live in. A content database is not the home; that option was considered and superseded by this recovered filesystem convention (see Alternatives Considered).

### The three tiers (for a project that has a repo)

The three-tier mechanism below describes how decisions live *in a project that has a repo*. A project with no repo yet homes its general information and its P-ADRs per the home rule above, reads general ADRs from the central location directly, and carries no `DEFAULTS.md` until a repo is born.

1. **General standards** (`G-NNNN-<slug>.md` in a central location) — full ADRs with context, alternatives, and consequences. These are the canonical source of reasoning.
2. **Project projection** (`<project>/docs/src/adrs/DEFAULTS.md`) — a one-time concise snapshot of the qualifying general standards applied to the project. It contains only the decision statement (one to three sentences), no rationale chain. Self-contained, with no references back to the central store. Materializes at repo-creation; a repo-less project carries none.
3. **Project-specific ADRs** (`<project>/docs/src/adrs/P-NNNN-<slug>.md`) — full ADRs for decisions scoped to one project. They include full context and rationale, since they are meaningful to external readers. Pre-repo they home in the project's knowledge home; they shift to the repo at repo-creation.

Key rules:

- `DEFAULTS.md` is a snapshot. Once projected, it belongs to the project. General-ADR updates do not auto-sync.
- Overrides are explicit. A project-specific ADR states "Overrides G-NNNN" in its status field.
- The ADR-recording tooling handles both recording and projection.

### Open consequence — the genericization boundary the shift crosses

The **shift** of a P-ADR from the project's knowledge home into a repo crosses the publish-time genericization boundary (P-WriteTimeAudience), and that boundary's two-profile model does **not** cleanly classify the case. A pre-repo P-ADR is simultaneously private-to-the-workspace (which argues for identity-preserving) **and** repo-destined (which argues for generic-at-write). How the write-time-audience discipline should handle a repo-destined-but-currently-private artifact is undecided; this decision does not pick a horn. It is named here as a real open architectural point, to be resolved at the next genericization-boundary friction.

## Alternatives Considered

- **Symlinks from a project to the central store.** Rejected: symlinks break across git clones and agents may not follow them. Not self-contained.
- **Full ADR copies in every project.** Rejected: this duplicates rationale that is only relevant internally and creates sync overhead across projects.
- **A reference file pointing back to the central store.** Rejected: projects need to be self-contained for public repos. External references leak internal structure.
- **A content database as the repo-less project's ADR home.** A pre-repo project's P-ADRs and deferred `DEFAULTS.md` projection could have lived as content-database rows keyed to the project, with the repo path as a pure rendering target. Superseded by the recovered filesystem convention: project knowledge already homes as filesystem markdown (the same store as the general ADRs), and that home is persistent and pre-existing. The content database is a projection/materialization surface, not the home. Kept visible per P-PreserveDecisionSpace.

## Consequences

- General decisions are recorded once, with full reasoning, in a single location.
- Projects get concise, self-contained summaries that work on public repos without exposing internal structure.
- Projection is a one-time operation per project — no ongoing sync maintenance.
- Project-specific overrides are visible and traceable.
- "Self-contained for a public repo" is a property of the *published form* of a project — its materialized repo — not a defining property of *being* a project. A repo-less project is a full project; it homes its knowledge in the project knowledge home, reads general ADRs from the central store directly, and materializes the repo-bound artifacts (`DEFAULTS.md`, the P-ADR tree) only when a repo is born.
- Making "project" repo-optional dissolves the prior taxonomy gap where some general-numbered ADRs fit neither the general bucket nor a project bucket: a decision specific to one repo-less project is a project P-ADR of that project, homed per the home rule above, with no new ADR class required.
