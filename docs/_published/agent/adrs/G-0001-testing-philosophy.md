---
title: "G-0001: Testing Philosophy — 90% Coverage, Inverted Pyramid"
summary: "Workspace testing standards: 90% coverage floor, inverted pyramid (unit-heavy), no personal-project discount."
primary-audience: agent
---

# G-0001: Testing Philosophy — 90% Coverage, Inverted Pyramid

**Status:** Accepted
**Date:** 2026-04-05

## Context

Coverage thresholds were being set per-project based on current baselines rather than a principled standard. AI-assisted development makes writing tests dramatically cheaper, removing the historical excuse for low coverage on personal projects.

## Decision

1. **90% code coverage threshold** as the enforced default for all projects — lines and functions. 100% is aspirational but 90% is the floor.
2. **Inverted test pyramid** — far more unit tests than integration tests. Use mocks so unit tests cover handler logic, business rules, and error paths. Integration tests only verify actual integration seams (DB connects, HTTP routes wire up, external APIs respond).
3. **Professional standards on all projects**, personal or not. These projects are public-facing and representative of the maintainer's work. No "personal project discount."
4. **Threshold exceptions must be documented** in project-level config or docs with explicit reasoning. Never silently accepted.

## Alternatives Considered

- **Per-project pragmatic thresholds** (set threshold near current baseline, raise incrementally): Rejected because it codifies "we don't test the interesting parts" and creates no pressure to improve.
- **Integration-heavy testing** (test at the route/API level, skip unit tests): Rejected because integration tests are slower, give less precise failure signals, and duplicate effort when unit tests already cover the logic.

## Consequences

- Existing projects may have coverage gaps that need closing.
- New test work should prioritize unit tests with mocked dependencies over integration tests.
- Coverage recipes in justfiles should use `--fail-under-lines 90 --fail-under-functions 90` unless a documented exception exists.
- Writing tests is now a first-class part of every implementation dispatch, not an afterthought.
