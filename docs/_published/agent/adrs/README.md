---
title: Architecture Decision Records
summary: "The G-series of governance architecture decision records: MADR format, G- prefix, ecosystem-wide scope."
primary-audience: human
---

# Architecture Decision Records

Holds the `G-` series of governance ADRs, G-0001 through G-0029. Each record captures one decision: context, decision, rejected alternatives with rationale, consequences.

## Conventions

Records follow [MADR](https://adr.github.io/madr/): Context, Decision, Alternatives Considered, Consequences. The `G-` prefix marks governance ADRs — ecosystem-wide scope across the mnemra ecosystem. Project-level decisions use the `P-` prefix and live in their own project repos, not here. Records are named, not renumbered when others are added; insert order is not load-bearing.

Records anchor to the canon. Most trace to an architecture principle or value; [constraint edges](../constraint-edges.md) records the links — which principle a decision specializes, which earlier decision it refines, which value it serves.

## What the series covers

- **Testing and review.** G-0001 sets the testing philosophy. G-0014 defines finding identity and round-to-round persistence of review findings.
- **Build, release, and versioning.** G-0006 makes the justfile the CI contract. G-0019 through G-0023 cover tag-race serialization, release automation, version policy, embargo flow, and the merge queue.
- **Repository and infrastructure baseline.** G-0002 (asset embedding), G-0005 (SQL migrations), G-0015 (devcontainers), G-0016 (secret detection), G-0017 (feature flags), G-0025 (internal IPC encoding) set per-repo defaults.
- **Approval and authorization.** G-0013 sets the approval-label vocabulary; G-0024 sets who may apply those labels; G-0018 covers the merge template and recovery cap.
- **Knowledge capture.** G-0007 through G-0012 cover the knowledge-extraction mechanism: capture hook, schema, duplicate detection, worked examples, drift detection, safety ceiling.
- **Documentation and workflow.** G-0003 (two-tier ADR system), G-0004 (XML agent profiles), G-0026 (project dev-docs tooling), G-0027 (agent-primary source artifacts), G-0028 (agent-first workflow shape), G-0029 (publish-time human render).

Full ordered list: navigation sidebar and [SUMMARY.md](../SUMMARY.md).
