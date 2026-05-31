---
title: Architecture Decision Records
summary: "The G-series of governance architecture decision records: MADR format, G- prefix, ecosystem-wide scope."
primary-audience: human
---

# Architecture Decision Records

This directory holds the `G-` series of governance architecture decision records, G-0001 through G-0029. Each record captures one decision: the context that forced it, the decision itself, the alternatives that were rejected and why, and the consequences.

## Conventions

The records follow the [MADR](https://adr.github.io/madr/) format. The `G-` prefix marks them as governance ADRs: decisions that apply across the mnemra ecosystem rather than to a single project. Project-level decisions use a `P-` prefix and live in their own project repos, not here. A record is named, not renumbered when others are added; insert order is not load-bearing.

Records anchor to the canon. Most trace to an architecture principle or value, and the [constraint edges](../constraint-edges.md) doc records those links: which principle a decision specializes, which earlier decision it refines, which value it serves.

## What the series covers

The decisions group into a few areas.

- **Testing and review.** G-0001 sets the testing philosophy. G-0014 defines how review findings are identified and persisted across rounds.
- **Build, release, and versioning.** G-0006 makes the justfile the CI contract. G-0019 through G-0023 cover tag-race serialization, release automation, the version policy, embargo flow, and the merge queue.
- **Repository and infrastructure baseline.** G-0002 (asset embedding), G-0005 (SQL migrations), G-0015 (devcontainers), G-0016 (secret detection), G-0017 (feature flags), and G-0025 (internal IPC encoding) set per-repo defaults.
- **Approval and authorization.** G-0013 sets the approval-label vocabulary; G-0024 sets who may apply those labels; G-0018 covers the merge template and recovery cap.
- **Knowledge capture.** G-0007 through G-0012 cover the knowledge-extraction mechanism, from the capture hook to the schema, duplicate detection, worked examples, drift detection, and the safety ceiling.
- **Documentation and workflow.** G-0003 (the two-tier ADR system), G-0004 (XML agent profiles), G-0026 (project dev-docs tooling), G-0027 (agent-primary source artifacts), G-0028 (the agent-first workflow shape), and G-0029 (the publish-time human render).

The full list, in order, is in the navigation sidebar and in [SUMMARY.md](../SUMMARY.md).
