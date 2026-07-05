---
title: "G-0015: Relational Substrate Default — Postgres (Server-Side) / SQLite (Embedded), Behind an Engine-Agnostic Seam"
summary: "The default relational store is keyed on deployment topology: PostgreSQL for server-side/multi-tenant/managed stores (after a hard license gate), SQLite for embedded/single-writer stores. An engine-agnostic Storage seam is locked as an intrinsic contract; a second engine is deferred behind a named trip-wire. Postgres RLS operational preconditions ride with the default."
primary-audience: agent
---

# G-0015: Relational Substrate Default — Postgres (Server-Side) / SQLite (Embedded), Behind an Engine-Agnostic Seam

**Status:** Accepted
**Date:** 2026-06-11

## Context

A relational-store choice is a decision-fork every qualifying project faces identically; it is not project-specific. It is also near-irreversible at scale — a substrate migration is the most expensive migration a project makes — which is the decision-altitude signature (a hard-to-reverse fork), not implementation tuning.

The backing-services area of the constraint taxonomy read as *empty* of decision-altitude members. The reason was structural: the one decision-altitude member that belonged there was buried inside a project ADR, while the thing sitting in general canon at this subject (a SQL file-based migration recipe) was an implementation-altitude *recipe* that did not belong at this altitude. That recipe has been demoted to an implementation-level Rust reference; this ADR records the right-altitude substrate fork the slot was missing.

The decision is conditioned on deployment topology, and the condition is load-bearing. A bare "need a relational store → Postgres" would collide with the live SQLite lane — the project task DB itself runs on embedded SQLite, the lane the demoted migration recipe still serves. The two defaults are siblings keyed on topology, not a collision.

## Decision

The default relational substrate is keyed on deployment topology:

- **Server-side / multi-tenant / managed-tier relational store → default PostgreSQL.** Chosen on affirmative merits after a license-pass-first gate, not on incumbency. The merits that ground the default (and that any project re-runs rather than inheriting as survivor bias): a hard license gate applied first (pass/fail, not a scored axis — a redistributed product's substrate license propagates downstream); multi-tenancy maturity (Postgres Row-Level Security is the reference implementation for tenant-scoped isolation); single-transaction atomicity for multi-write operations that must commit or roll back as a whole; and decades-deep backup / point-in-time-recovery / observability maturity, a quality requirement for any sold or operated product.

- **Embedded / single-writer / single-process relational store → SQLite.** The live lane — the project task DB, and the lane the demoted file-based-migration recipe still serves. Choosing SQLite here is not a fallback from Postgres; it is the correct default for the embedded topology.

A project's substrate choice is recorded against its topology. A server-side/multi-tenant project does not get to pick SQLite for convenience, and an embedded single-writer tool does not inherit Postgres operational weight it has no use for.

### Mitigation — engine-agnostic `Storage` seam (named, not a second default)

Lock an engine-agnostic `Storage` seam **only** for an intrinsic contract invariant: the storage surface is an engine-agnostic trait, and the chosen engine is the implementation behind it. The contract is locked because it is intrinsic to the storage layer's identity (P-LockContract — lock what is intrinsic, even when only one engine exercises it; an in-memory test adapter is reason enough for the seam). A future engine swap is bounded behind that one seam (P-MinBlastRadius), so a future permissively-relicensed engine slots in without re-architecting call sites.

Do **not** build a second adapter speculatively (P-Defer). The seam is locked now; the second implementation is deferred behind a named trip-wire (a candidate engine relicenses to a permissive tier and becomes a shippable default, or the single-engine path measurably strains on a real workload). This is P-LockContract + P-MinBlastRadius *applied* as the mitigation for the near-irreversibility of the substrate choice; it is not a separate promotable "use a trait" default.

### Postgres operational preconditions (applies when the Postgres default is chosen with RLS)

When the Postgres default is taken and Row-Level Security is the multi-tenancy mechanism, RLS *is* the reference implementation for tenant-scoped isolation — but only with its operational preconditions met; omitting any one is a silent cross-tenant-leak risk. These are operational guidance riding with the substrate default, not a separate ADR:

1. **The application role MUST NOT hold `BYPASSRLS` and MUST NOT be a superuser.** Superusers and `BYPASSRLS` roles bypass every policy by default; the application connects as an ordinary role.
2. **`ALTER TABLE … FORCE ROW LEVEL SECURITY` is required if the application role owns the tables.** Table owners are exempt from their own RLS unless `FORCE` is set.
3. **The tenant key MUST be set per-transaction, not per-session.** Under a transaction-mode connection pooler, use `SET LOCAL <tenant-key> = …` *inside* the transaction; a bare session-level `SET` persists on the physical connection and leaks across pooled checkouts to the next tenant.

## Alternatives Considered

**Unconditioned "relational → Postgres."** Rejected: it collides with the live embedded SQLite lane. The fork is real only when keyed on deployment topology; an embedded single-writer tool that adopted Postgres would pay multi-tenant operational weight for no benefit.

**Leave the substrate fork buried in a project ADR (the prior state).** Rejected: the fork recurs identically across every qualifying project. Leaving it project-local manufactures the *opposite* problem the generality audit warned against — a general decision-altitude fork hidden where the next project re-derives it blind. The fork "projects into" each project rather than living in one.

**Build a second storage adapter now to prove the seam.** Rejected per P-Defer: the seam is justified by the in-memory test adapter and its role as the swap re-open point; a second production adapter spends effort on a non-shippable path before a trip-wire forces it. The seam is locked; the second implementation is deferred.

**A Postgres-shaped (not engine-agnostic) trait.** Rejected: a deliberately Postgres-shaped seam forecloses the relicense/landscape optionality the mitigation exists to preserve. The seam is engine-agnostic; Postgres is the only implementation built.

## Consequences

- The backing-services slot now carries its decision-altitude member; the slot read as empty only because that member was buried in a project ADR while a recipe sat in its place. The fold takes the wrong-altitude recipe out; this ADR puts the right-altitude fork in.
- The two defaults are siblings keyed on deployment topology; a project records its substrate against its topology rather than re-litigating Postgres-vs-SQLite from scratch.
- The engine-agnostic seam preserves swap optionality at the cost of a one-implementation-deep trait — justified by the in-memory test adapter and by the seam's role as the trip-wired re-open point.
- The Postgres RLS preconditions travel with the default, so a project taking the Postgres lane carries them rather than rediscovering them as implementation trivia after a cross-tenant leak.

**Project-local, NOT promoted here.** A specific product's embedded-engine choice (a single-self-hosted-binary deployment posture), its V0 stack (pgvector HNSW / native full-text search / recursive CTEs / JSONB), its single-transaction keyed-supersession headline guarantee, and its per-capability trip-wires (keyword / graph / time-series) stay in that product's own project ADRs. Those are the product's sizing and identity, not a cross-project fork. This ADR carries only the kernel: the conditioned substrate default plus the engine-agnostic seam as the P-LockContract / P-MinBlastRadius mitigation, with the Postgres RLS operational preconditions riding along.
