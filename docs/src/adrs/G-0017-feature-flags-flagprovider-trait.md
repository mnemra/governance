---
title: "G-0017: Feature Flags — FlagProvider Trait + Per-Repo Crate, Extract-When-Common"
summary: "FlagProvider trait shape is workspace canon; per-repo env-var backend per repo; extract to shared crate only at rule-of-three (3+ repos) — no premature extraction."
primary-audience: agent
---

# G-0017: Feature Flags — FlagProvider Trait + Per-Repo Crate, Extract-When-Common

**Status:** Accepted
**Date:** 2026-04-30

## Context

The semver companion doc decoupled release cadence from merge cadence by tying versioning to feature-flag activation (Pattern A): merge new code dark, flip the flag at release time, bump the version. This ADR addresses what mechanism implements the flag layer per repo.

Research on the Rust ecosystem found:
- **OpenFeature Rust SDK is pre-1.0** (v0.3.0, March 2026, marked WIP). No first-party provider integrations shipped from OpenFeature org for Rust as of April 2026; only flagd contrib has shipped a 0.x release. Eventing not yet implemented. Not production-grade for the next 6-12 months.
- **Hand-rolled env-var pattern** is dominant in Rust services today: ~5 lines per flag, no dependency, no abstraction layer.
- **No mature Rust-native feature-flag-management library** at OpenFeature's vendor-bridging tier.

The shape question split: per-repo crate with hand-rolled env-var backend, or workspace-shared crate from day one. The extract-when-common principle (per-repo first, extract to a shared crate when commonality is observed at rule-of-three) points at per-repo today.

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

**The trait shape is workspace canon** (this ADR). The implementation is per-repo. Default backend is env-var-driven:

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

Flag keys use kebab-case in source (`new-search-ranking`); env vars are screaming-snake-case with `FLAG_` prefix (`FLAG_NEW_SEARCH_RANKING`).

**Extract to shared crate `<workspace-root>/crates/feature-flags/` only when commonality emerges across three or more repos** (rule of three). Until then, per-repo copies are intentional duplication; drift between them is fine because backends differ per-repo deployment context.

**Backend swap path:** because `FlagProvider` is the seam, swapping `EnvVarFlags` for `OpenFeatureFlags` (when OpenFeature Rust reaches 1.0) or a vendor SDK is a per-repo decision: implement the trait against the new backend, swap the binding in repo `main.rs` / DI container.

## Alternatives Considered

- **Inline `LazyLock<bool>` per flag, no abstraction.** Rejected: "must be a library, abstracted, replaceable backend." Inline pattern locks the backend choice into every call site.
- **Workspace-shared `feature-flags` crate from day one.** Rejected. Premature extraction couples repos before commonality is observed. Per-repo first; extract later if 3+ repos diverge in superficial ways but share the trait shape.
- **OpenFeature Rust SDK as the abstraction layer today.** Rejected — pre-1.0, eventing unimplemented, no vendor providers shipped. Adopting it now means inheriting upstream churn.
- **Cargo features (compile-time).** Rejected. Flags must toggle at runtime to support the dark-merge-then-flip release model. Compile-time is the wrong granularity.
- **`features` or `env-flags` crates from crates.io.** Rejected. Both lightly maintained, low download volume; offer thin wrappers around what's a 5-line pattern. Direct std::env is leaner.
- **Vendor (LaunchDarkly, Statsig, etc.) from day one.** Rejected. Vendor lock-in cost vs current usage volume (zero production flags) is poor trade. The trait-seam preserves the option to swap in later.

## Consequences

- **Per-repo crate copy is the v1 cost.** ~50 lines of code (LOC) per repo — trait + EnvVarFlags impl + tests. Acceptable per the extract-when-common principle.
- **Trait shape locked in workspace canon** (this ADR). Per-repo implementations conform; if a repo deviates, the deviation is either trivial (extra method) or signals the trait needs revision in this ADR.
- **Flag-key naming convention is enforced by env-var derivation.** Source-code key `new-search-ranking` ↔ env var `FLAG_NEW_SEARCH_RANKING`. Avoids per-repo bikeshed.
- **OpenFeature seam preserved.** When OpenFeature Rust reaches 1.0 with vendor providers, individual repos can adopt by writing an `OpenFeatureFlags: FlagProvider` impl. Trait stays; backend swaps. No re-architecture.
- **Polyglot signal:** if a non-Rust repo adopts the workflow, it implements its own `FlagProvider` equivalent in its language. The trait shape is the canon; the language is per-repo.
- **Versioning interaction:** Pattern A bump-on-flag-permanent-activation reads activation events from the FlagProvider boundary; the flag's lifecycle (created → off-default → on-default → permanent → removed) is the bump trigger. Release automation doesn't need to know about flags directly; the conventional-commits message at flag-permanent commit declares the bump.
- **Cleanup discipline:** flags are intended to be transient. Cap on flag count or age is a per-repo /spec concern, not workspace canon.
- **Mnemra migration:** once mnemra absorbs the workspace and per-repo independence remains, the FlagProvider trait migrates as a workspace-shared crate IF rule-of-three has fired by then. If not, per-repo crates persist.
