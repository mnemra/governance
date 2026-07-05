---
title: Architecture Decision Records
summary: "The G-series of governance architecture decision records: MADR format, G- prefix, ecosystem-wide scope."
primary-audience: human
---

# Architecture Decision Records

This directory holds the `G-` series of governance architecture decision records, G-0001 through G-0016. Each record captures one decision: the context that forced it, the decision itself, the alternatives that were rejected and why, and the consequences.

## Conventions

The records follow the [MADR](https://adr.github.io/madr/) format. The `G-` prefix marks them as governance ADRs: decisions that apply across the mnemra ecosystem rather than to a single project. Project-level decisions use a `P-` prefix and live in their own project repos, not here. A record is named, not renumbered when others are added; insert order is not load-bearing.

Records anchor to the canon. Most trace to an architecture principle or value, and the [constraint edges](../constraint-edges.md) doc records those links: which principle a decision specializes, which earlier decision it refines, which value it serves.

## What the series covers

The decisions group into a few areas.

- **Documentation and decision-recording.** G-0001 sets the two-tier ADR system (general `G-` decisions versus project-local `P-` decisions). G-0012 sets the project dev-docs tooling; G-0014 records the publish-time human render that turns agent-first sources into a human-readable site.
- **Workflow and review.** G-0013 defines the agent-first workflow shape (`/brief` + `/verify`). G-0004 defines how review findings are identified and persisted across rounds.
- **Merge, release, and versioning.** G-0003 sets merge governance (shift-left review on the governing artifact, verified at merge). G-0008 is the PR-merge apparatus (merge template, recovery cap, tag-race serialization, merge queue). G-0009 is the Rust release apparatus (release automation + the version policy). G-0010 records the embargo flow for coordinated security disclosure.
- **Repository and infrastructure baseline.** G-0002 makes the justfile the CI contract. G-0005 (devcontainers), G-0006 (layered secret detection), G-0007 (feature flags), G-0011 (internal IPC encoding), and G-0016 (unattended host credential) set per-repo and automation defaults.
- **Data substrate.** G-0015 sets the default relational store, keyed on deployment topology, behind an engine-agnostic seam.

The full list, in order, is in the navigation sidebar and in [SUMMARY.md](../SUMMARY.md).
