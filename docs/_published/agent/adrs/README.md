---
title: Architecture Decision Records
summary: "The G-series of governance architecture decision records: MADR format, G- prefix, ecosystem-wide scope."
primary-audience: human
---

# Architecture Decision Records

Holds the `G-` series of governance ADRs, G-0001 through G-0016. Each record captures one decision: context, decision, rejected alternatives with rationale, consequences.

## Conventions

Records follow [MADR](https://adr.github.io/madr/): Context, Decision, Alternatives Considered, Consequences. The `G-` prefix marks governance ADRs — ecosystem-wide scope across the mnemra ecosystem. Project-level decisions use the `P-` prefix and live in their own project repos, not here. Records are named, not renumbered when others are added; insert order is not load-bearing.

Records anchor to the canon. Most trace to an architecture principle or value; [constraint edges](../constraint-edges.md) records the links — which principle a decision specializes, which earlier decision it refines, which value it serves.

## What the series covers

- **Documentation and decision-recording.** G-0001 sets the two-tier ADR system (general `G-` decisions versus project-local `P-` decisions). G-0012 sets the project dev-docs tooling; G-0014 records the publish-time human render that turns agent-first sources into a human-readable site.
- **Workflow and review.** G-0013 defines the agent-first workflow shape (`/brief` + `/verify`). G-0004 defines review-finding identity and round-to-round persistence.
- **Merge, release, and versioning.** G-0003 sets merge governance (shift-left review on the governing artifact, verified at merge). G-0008 is the PR-merge apparatus (merge template, recovery cap, tag-race serialization, merge queue). G-0009 is the Rust release apparatus (release automation + version policy). G-0010 records the embargo flow for coordinated security disclosure.
- **Repository and infrastructure baseline.** G-0002 makes the justfile the CI contract. G-0005 (devcontainers), G-0006 (layered secret detection), G-0007 (feature flags), G-0011 (internal IPC encoding), and G-0016 (unattended host credential) set per-repo and automation defaults.
- **Data substrate.** G-0015 sets the default relational store, keyed on deployment topology, behind an engine-agnostic seam.

Full ordered list: navigation sidebar and [SUMMARY.md](../SUMMARY.md).
