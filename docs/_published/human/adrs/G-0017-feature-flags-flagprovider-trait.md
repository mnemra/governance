---
title: "G-0017: Feature Flags — FlagProvider Trait + Per-Repo Crate, Extract-When-Common"
summary: "FlagProvider trait shape is workspace canon; per-repo env-var backend per repo; extract to shared crate only at rule-of-three (3+ repos) — no premature extraction."
primary-audience: agent
---

# G-0017: Feature Flags — FlagProvider Trait + Per-Repo Crate, Extract-When-Common

**Status:** Accepted
**Date:** 2026-04-30

## Context

The semver companion doc separated release cadence from merge cadence. It did this by tying versioning to feature-flag activation, which it calls Pattern A: merge new code dark, flip the flag at release time, then bump the version. This decision record answers a narrower question. What mechanism implements the flag layer inside each repo?

Research on the Rust ecosystem found three things worth recording.

- **OpenFeature Rust SDK is pre-1.0** (v0.3.0, March 2026, marked WIP). The OpenFeature org shipped no first-party provider integrations for Rust as of April 2026. Only flagd contrib has a 0.x release. Eventing isn't implemented yet. It isn't production-grade for the next 6-12 months.
- **A hand-rolled env-var pattern** is what most Rust services use today: about 5 lines per flag, no dependency, no abstraction layer.
- **No mature Rust-native feature-flag-management library** exists at the vendor-bridging tier that OpenFeature aims for.

That left a shape question with two answers. A per-repo crate with a hand-rolled env-var backend, or a workspace-shared crate from day one. The extract-when-common principle (build per-repo first, then extract to a shared crate once the same need shows up in three or more repos) points at per-repo for now.

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

**The trait shape is workspace canon** (this ADR). The implementation is per-repo. The default backend reads from environment variables:

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

Flag keys are kebab-case in source (`new-search-ranking`). The env vars are screaming-snake-case with a `FLAG_` prefix (`FLAG_NEW_SEARCH_RANKING`).

**Extract to a shared crate at `<workspace-root>/crates/feature-flags/` only when the same need appears across three or more repos** (the rule of three). Until then, per-repo copies are intentional duplication. Drift between them is fine, because backends differ with each repo's deployment context.

**Backend swap path:** the `FlagProvider` trait is the seam. Swapping `EnvVarFlags` for `OpenFeatureFlags` (once OpenFeature Rust reaches 1.0) or for a vendor SDK is a per-repo decision. Implement the trait against the new backend, then swap the binding in the repo's `main.rs` or DI container.

## Alternatives Considered

- **Inline `LazyLock<bool>` per flag, no abstraction.** Rejected. The requirement was a library, abstracted, with a replaceable backend. The inline pattern locks the backend choice into every call site.
- **A workspace-shared `feature-flags` crate from day one.** Rejected. Premature extraction couples repos before the common need is observed. Per-repo first; extract later if three or more repos diverge in superficial ways but share the trait shape.
- **OpenFeature Rust SDK as the abstraction layer today.** Rejected. It's pre-1.0, eventing is unimplemented, and no vendor providers have shipped. Adopting it now means inheriting upstream churn.
- **Cargo features (compile-time).** Rejected. Flags have to toggle at runtime to support the dark-merge-then-flip release model. Compile-time is the wrong granularity.
- **The `features` or `env-flags` crates from crates.io.** Rejected. Both are lightly maintained with low download volume, and both offer thin wrappers around what's a 5-line pattern. Direct `std::env` is leaner.
- **A vendor (LaunchDarkly, Statsig, etc.) from day one.** Rejected. Vendor lock-in cost against current usage volume (zero production flags) is a poor trade. The trait seam keeps the option to swap one in later.

## Consequences

- **The per-repo crate copy is the v1 cost.** About 50 lines of code per repo: the trait, the `EnvVarFlags` impl, and tests. That's acceptable under the extract-when-common principle.
- **The trait shape is locked in workspace canon** (this ADR). Per-repo implementations conform. If a repo deviates, the deviation is either trivial (an extra method) or it signals the trait needs revision here.
- **The flag-key naming convention is enforced by env-var derivation.** Source-code key `new-search-ranking` maps to env var `FLAG_NEW_SEARCH_RANKING`. That removes per-repo bikeshedding.
- **The OpenFeature seam is preserved.** When OpenFeature Rust reaches 1.0 with vendor providers, a repo can adopt it by writing an `OpenFeatureFlags: FlagProvider` impl. The trait stays; the backend swaps. No re-architecture.
- **Polyglot signal:** if a non-Rust repo adopts the workflow, it implements its own `FlagProvider` equivalent in its language. The trait shape is the canon. The language is per-repo.
- **Versioning interaction:** the Pattern A rule of bumping when a flag becomes permanently active reads activation events from the `FlagProvider` boundary. The flag's lifecycle (created → off-default → on-default → permanent → removed) is the bump trigger. Release automation doesn't need to know about flags directly. The conventional-commits message at the flag-permanent commit declares the bump.
- **Cleanup discipline:** flags are meant to be transient. A cap on flag count or age is a per-repo spec concern (the `/spec` step that defines what done looks like), not workspace canon.
- **Mnemra migration:** once mnemra absorbs the workspace and per-repo independence still holds, the `FlagProvider` trait migrates as a workspace-shared crate IF the rule of three has fired by then. If it hasn't, the per-repo crates persist.
