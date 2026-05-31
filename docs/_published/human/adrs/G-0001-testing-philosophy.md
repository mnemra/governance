---
title: "G-0001: Testing Philosophy — 90% Coverage, Inverted Pyramid"
summary: "Workspace testing standards: 90% coverage floor, inverted pyramid (unit-heavy), no personal-project discount."
primary-audience: agent
---

# G-0001: Testing Philosophy — 90% Coverage, Inverted Pyramid

**Status:** Accepted
**Date:** 2026-04-05

G-0001 is a governance ADR, a decision that applies across the whole ecosystem rather than to a single project.

## Context

Coverage thresholds were being set per project against each project's current baseline instead of against a principled standard. That meant the bar moved with whatever a project happened to have already. AI-assisted development makes writing tests dramatically cheaper, which removes the old excuse for low coverage on personal projects.

## Decision

1. **90% code coverage threshold** as the enforced default for all projects, covering both lines and functions. 100% is aspirational, but 90% is the floor.
2. **Inverted test pyramid**, meaning far more unit tests than integration tests. Use mocks so unit tests cover handler logic, business rules, and error paths. Integration tests only verify actual integration seams: the database connects, HTTP routes wire up, external APIs respond.
3. **Professional standards on all projects**, personal or not. These projects are public-facing and represent the maintainer's work. (The maintainer is the person who owns the canon and sets direction.) There's no "personal project discount."
4. **Threshold exceptions must be documented** in project-level config or docs with explicit reasoning. Never silently accepted.

## Alternatives Considered

- **Per-project pragmatic thresholds** (set the threshold near the current baseline, raise it incrementally): Rejected because it codifies "we don't test the interesting parts" and creates no pressure to improve.
- **Integration-heavy testing** (test at the route or API level, skip unit tests): Rejected because integration tests are slower, give less precise failure signals, and duplicate effort when unit tests already cover the logic.

## Consequences

- Existing projects may have coverage gaps that need closing.
- New test work should prioritize unit tests with mocked dependencies over integration tests.
- Coverage recipes in justfiles should use `--fail-under-lines 90 --fail-under-functions 90` unless a documented exception exists.
- Writing tests is now a first-class part of every implementation dispatch, the handing of a scoped task to a specialist along with the context to act on it. Tests aren't an afterthought.
