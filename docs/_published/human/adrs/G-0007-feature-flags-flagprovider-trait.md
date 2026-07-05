---
title: "G-0007: Feature Flags — FlagProvider Trait, Per-Repo Crate, Extract-When-Common"
summary: "Each in-scope repo defines its own feature-flag crate implementing a small FlagProvider trait (env-var backend by default); the trait shape is canon, the implementation is per-repo, extracted to a shared crate only on the rule of three."
primary-audience: agent
---

# G-0007: Feature Flags — FlagProvider Trait, Per-Repo Crate, Extract-When-Common

**Status:** Accepted
**Date:** 2026-04-30

## Context

A companion versioning decision decoupled release cadence from merge cadence by tying versioning to feature-flag activation: merge new code dark, flip the flag at release time, bump the version. The open question was which mechanism implements the flag layer per repo.

Research found:

- **The OpenFeature Rust SDK is pre-1.0** (v0.3.0, March 2026, marked WIP). No first-party vendor providers (LaunchDarkly, GoFeatureFlag, etc.) had shipped from the OpenFeature org for Rust as of April 2026; only flagd contrib had shipped a 0.x release. Eventing was not yet implemented. Not production-grade for the next 6 to 12 months unless the team upstreams contrib providers itself.
- **The hand-rolled env-var pattern** is dominant in Rust services today: roughly five lines per flag, no dependency, no abstraction layer.
- **No mature Rust-native feature-flag-management library** exists at OpenFeature's vendor-bridging tier.

The maintainer pushed back on an earlier inline-`LazyLock` proposal with "must be a library, abstracted, replaceable backend." That conversation surfaced the operating rule: per-repo first, extract to a shared crate when commonality is observed (the rule of three).

The shape question split into two options: a per-repo crate with a hand-rolled env-var backend (option A), or a workspace-shared crate from day one (option B). The analysis pointed at option A: per-repo today, extract later.

## Decision

**Each in-scope repo defines its own feature-flag library** as an internal crate (e.g., `<repo>/crates/feature-flags/`) implementing a small trait:

```rust
pub trait FlagProvider: Send + Sync {
    fn enabled(&self, key: &str) -> bool;
    fn enabled_with_default(&self, key: &str, default: bool) -> bool {
        self.enabled(key)
    }
}
```

**The trait shape is canon** (this ADR). The implementation is per-repo. The default backend is env-var-driven:

```rust
pub struct EnvVarFlags;

impl FlagProvider for EnvVarFlags {
    fn enabled(&self, key: &str) -> bool {
        std::env::var(format!("FLAG_{}", key.to_uppercase().replace('-', "_")))
            .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
            .unwrap_or(false)
    }
}
```

Flag keys use kebab-case in source (`new-search-ranking`); env vars are screaming-snake-case with a `FLAG_` prefix (`FLAG_NEW_SEARCH_RANKING`).

**Extract to a shared crate only when commonality emerges across three or more repos** (the rule of three). Until then, per-repo copies are intentional duplication; drift between them is fine because backends differ per-repo deployment context.

**Backend swap path:** because `FlagProvider` is the seam, swapping `EnvVarFlags` for an `OpenFeatureFlags` impl (when OpenFeature Rust reaches 1.0) or a vendor impl (if adoption justifies it) is a per-repo decision: implement the trait against the new backend, swap the binding in the repo's `main.rs` or DI container.

## Alternatives Considered

- **Inline `LazyLock<bool>` per flag, no abstraction.** Rejected per the maintainer's pushback: "must be a library, abstracted, replaceable backend." The inline pattern locks the backend choice into every call site.
- **Workspace-shared `feature-flags` crate from day one.** Rejected. Premature extraction couples repos before commonality is observed. Per-repo first; extract later if three or more repos diverge in superficial ways but share the trait shape.
- **OpenFeature Rust SDK as the abstraction layer today.** Rejected per the research finding: pre-1.0, eventing unimplemented, no vendor providers shipped. Adopting it now means inheriting upstream churn.
- **Cargo features (compile-time).** Rejected. Runtime-toggled flags are required to support the dark-merge-then-flip release model. Compile-time is the wrong granularity.
- **`features` or `env-flags` crates from crates.io.** Rejected. Both are lightly maintained, low download volume, and offer thin wrappers around what is a five-line pattern. Direct `std::env` is leaner.
- **A vendor SDK from day one.** Rejected. Vendor lock-in cost versus current usage volume (zero production flags) is a poor trade. The trait seam preserves the option to swap one in later.

## Consequences

- **Per-repo crate copy is the v1 cost.** Roughly 50 lines per repo: trait + `EnvVarFlags` impl + tests. Acceptable under the extract-when-common principle.
- **Trait shape locked in canon** (this ADR). Per-repo implementations conform; a deviation is either trivial (an extra method) or signals the trait needs revision in this ADR.
- **Flag-key naming is enforced by env-var derivation.** Source key `new-search-ranking` maps to env var `FLAG_NEW_SEARCH_RANKING`, avoiding per-repo bikeshed.
- **The OpenFeature seam is preserved.** When OpenFeature Rust reaches 1.0 with vendor providers, an individual repo can adopt it by writing an `OpenFeatureFlags: FlagProvider` impl. The trait stays; the backend swaps. No re-architecture.
- **Polyglot signal.** If a non-Rust repo adopts the workflow, it implements its own `FlagProvider` equivalent in its language. The trait shape is the canon; the language is per-repo.
- **Versioning interaction.** The bump-on-flag-permanent-activation model reads activation events from the `FlagProvider` boundary; the flag's lifecycle (created → off-default → on-default → permanent → removed) is the bump trigger. Release tooling does not need to know about flags directly; the conventional-commit message at the flag-permanent commit declares the bump.
- **Cleanup discipline.** Flags are intended to be transient. A cap on flag count or age is a per-project spec concern, not canon.
- **Consolidation path.** When shared tooling consolidates and per-repo independence still holds, the `FlagProvider` trait migrates to a shared crate if the rule of three has fired by then. If not, per-repo crates persist.
