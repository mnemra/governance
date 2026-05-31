---
title: "G-0017: Feature Flags — FlagProvider Trait + Per-Repo Crate, Extract-When-Common"
summary: "FlagProvider trait shape is workspace canon; per-repo env-var backend per repo; extract to shared crate only at rule-of-three (3+ repos) — no premature extraction."
primary-audience: agent
---

# G-0017: Feature Flags — FlagProvider Trait + Per-Repo Crate, Extract-When-Common

**Status:** Accepted
**Date:** 2026-04-30

## Context

The semver companion doc separated release cadence from merge cadence. It did so by tying versioning to feature-flag activation, the approach it calls Pattern A: merge new code in a dark (disabled) state, flip the flag at release time, then bump the version. This decision record covers the next question down. What mechanism implements the flag layer inside each repo?

Research on the Rust ecosystem found three things worth recording.
- **OpenFeature Rust SDK is pre-1.0** (v0.3.0, March 2026, marked work-in-progress). No first-party provider integrations had shipped from the OpenFeature org for Rust as of April 2026. Only the flagd contrib had shipped a 0.x release. Eventing wasn't implemented yet. It isn't production-grade for the next 6 to 12 months.
- **The hand-rolled env-var pattern** is dominant in Rust services today. About 5 lines per flag, no dependency, no abstraction layer.
- **No mature Rust-native feature-flag-management library** exists at OpenFeature's vendor-bridging tier.

That left the shape question split two ways. A per-repo crate with a hand-rolled env-var backend, or a workspace-shared crate from day one. The choice falls out of an existing rule. [P-ExtractWhenCommon](../glossary.md) (build per-repo first, extract to a shared crate only once the same need shows up across enough repos to satisfy the rule-of-three) points at per-repo today.

## Decision

**Each in-scope repo defines its own feature-flag library** as an internal crate (for example, `<repo>/crates/feature-flags/`) implementing a small trait:

```rust
pub trait FlagProvider: Send + Sync {
    fn enabled(&self, key: &str) -> bool;
    fn enabled_with_default(&self, key: &str, default: bool) -> bool {
        self.enabled(key)
    }
}
```

**The trait shape is workspace canon** (this ADR governs it). The implementation is per-repo. The default backend reads from environment variables:

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

Flag keys use kebab-case in source (`new-search-ranking`). The matching env vars are screaming-snake-case with a `FLAG_` prefix (`FLAG_NEW_SEARCH_RANKING`).

**Extract to a shared crate at `workspace/crates/feature-flags/` only when the same shape emerges across three or more repos** (the rule of three). Until then, the per-repo copies are intentional duplication. Drift between them is fine, because backends differ with each repo's deployment context.

**Backend swap path.** `FlagProvider` is the seam. Swapping `EnvVarFlags` for `OpenFeatureFlags` (once OpenFeature Rust reaches 1.0) or for a vendor SDK is a per-repo decision. Implement the trait against the new backend, then swap the binding in the repo's `main.rs` or dependency-injection container.

## Alternatives Considered

- **Inline `LazyLock<bool>` per flag, no abstraction.** Rejected. The constraint was that this must be a library: abstracted, with a replaceable backend. The inline pattern locks the backend choice into every call site.
- **A workspace-shared `feature-flags` crate from day one.** Rejected. That's premature extraction. It couples repos before the commonality has actually been observed. Per-repo first, and extract later if 3 or more repos diverge in superficial ways while sharing the trait shape.
- **The OpenFeature Rust SDK as the abstraction layer today.** Rejected. It's pre-1.0, eventing is unimplemented, and no vendor providers have shipped. Adopting it now means inheriting upstream churn.
- **Cargo features (compile-time).** Rejected. Flags have to toggle at runtime to support the dark-merge-then-flip release model. Compile-time is the wrong granularity.
- **The `features` or `env-flags` crates from crates.io.** Rejected. Both are lightly maintained with low download volume, and they offer thin wrappers around what's a 5-line pattern. Direct `std::env` is leaner.
- **A vendor (LaunchDarkly, Statsig, and similar) from day one.** Rejected. The cost of vendor lock-in against current usage volume is a poor trade, and current usage is zero production flags. The trait seam keeps the option to swap a vendor in later.

## Consequences

- **The per-repo crate copy is the v1 cost.** Roughly 50 lines of code (LOC) per repo: the trait, the `EnvVarFlags` impl, and tests. Acceptable under P-ExtractWhenCommon.
- **The trait shape is locked in workspace canon** (this ADR). Per-repo implementations conform to it. If a repo deviates, the deviation is either trivial (an extra method) or it signals that the trait itself needs a revision here.
- **The flag-key naming convention is enforced by the env-var derivation.** The source-code key `new-search-ranking` maps to the env var `FLAG_NEW_SEARCH_RANKING`. That removes per-repo bikeshedding over names.
- **The OpenFeature seam is preserved.** Once OpenFeature Rust reaches 1.0 with vendor providers, individual repos can adopt it by writing an `OpenFeatureFlags: FlagProvider` impl. The trait stays. The backend swaps. No re-architecture.
- **Polyglot signal.** If a non-Rust repo adopts the workflow, it implements its own `FlagProvider` equivalent in its own language. The trait shape is the canon. The language is per-repo.
- **Versioning interaction.** Pattern A bumps the version when a flag becomes permanently active. It reads those activation events from the `FlagProvider` boundary. The flag's lifecycle is the bump trigger: created, off-by-default, on-by-default, permanent, removed. Release automation doesn't need to know about flags directly. The conventional-commits message on the flag-permanent commit declares the bump.
- **Cleanup discipline.** Flags are meant to be transient. Any cap on flag count or age is a per-repo [Spec](../glossary.md) concern, not workspace canon.
- **Mnemra migration.** Once Mnemra absorbs the workspace and per-repo independence remains, the `FlagProvider` trait migrates as a workspace-shared crate, but only if the rule of three has fired by then. If it hasn't, the per-repo crates persist.
