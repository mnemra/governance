---
title: "G-0019: Tag-Race Serialization — GHA Concurrency Directive + R26b"
summary: "Per-repo release workflow uses GHA concurrency on release-pr job only; release job is concurrency-free per release-plz guidance; Mode B race is accepted + monitored."
primary-audience: agent
---

# G-0019: Tag-Race Serialization — GHA Concurrency Directive + R26b

**Status:** Accepted
**Date:** 2026-04-30

## Context

This is a governance ADR (`G-` series, an ecosystem-wide decision recorded as MADR: Context, Decision, Alternatives Considered, Consequences). It covers two ways a repo can cut a release. Mode A opens a release pull request and tags when that PR merges. Mode B deploys as the release and creates the tag at release time. Mode B opens a race that Mode A doesn't: two PRs merging close together can each start a release sub-flow, and both will try to read the current tag, compute the next one, and push a new tag. The bad outcomes range from duplicate tags, when both runs compute the same next version, to orphaned commits between tags, when one push wins and the other run's commits get mis-attributed in the CHANGELOG.

Discovery R26b is a finding from the earlier scope-shaping pass (the role the brief workflow now covers). It already serializes the upstream merge step itself: at most one PR may merge to main at a time. What's left is the race between a merge completing and the release sub-flow's tag push. Two adjacent merges can trigger two release runs that overlap.

Three candidates for the serialization mechanism:

- **release-plz lock** (or equivalent tool-level mutex). Couples to the release tool.
- **GHA `concurrency:` directive** scoped to the repo.
- **External lock** (e.g., a workspace-side queue). Adds infrastructure.

GitHub Actions ships `concurrency:` natively. release-plz doesn't provide its own lock. Simplicity points to the GHA-native option.

## Decision

**Per-repo release sub-flow workflow uses GHA `concurrency:` directive scoped to the *release-pr* job (Mode A), NOT the release job, with `cancel-in-progress: false`.** Combined with discovery R26b ("at most one PR may merge to main at a time"), enforced through G-0023's GitHub Merge Queue for Mode B repos, this gives two-layer serialization. G-0023's merge queue guards the merge gate. GHA concurrency guards the release-PR-update path.

Per-repo workflow YAML pattern (Mode A — release-PR mode):

```yaml
name: Release
on:
  push:
    branches: [main]

# NO workflow-level concurrency. Concurrency is scoped per-job below.

jobs:
  release-pr:
    # release-plz "open/update release-PR" invocation per G-0020.
    # Concurrency on this job: serialise release-PR updates so feature-PR
    # merges don't race release-PR updates against the eventual release-PR merge.
    concurrency:
      group: release-pr-${{ github.repository }}
      cancel-in-progress: false
    # ... release-plz invocation (Mode A)

  release:
    # release-plz "tag + publish on release-PR merge" invocation per G-0020.
    # NO concurrency block here — see note below. release-plz upstream
    # quickstart explicitly advises against concurrency on the release job
    # because GHA concurrency cancels the *pending* run when a third trigger
    # arrives, which under rapid Mode B merges drops releases on the floor.
    needs: release-pr
    # ... release-plz invocation (release/publish step)
```

**Why concurrency lives only on `release-pr`.** The release-plz quickstart (<https://release-plz.dev/docs/github/quickstart>) explicitly advises against concurrency on the release job. GHA's concurrency semantic is "one running plus one pending; a third arrival cancels the pending one." Three rapid Mode B merges would cause the middle run to be cancelled, NOT queued, the opposite of "queue, don't cancel." The release-PR-update path is where concurrency genuinely helps. Feature-PR merges trigger release-plz to update an open release-PR, and serialising those updates prevents racey CHANGELOG state. The release job itself, when it fires on release-PR merge, runs after Stage 6 / G-0023 has already serialised the merge. (Stage 6 is the approval-labelling step in the numbered life of a change.) So it inherits serialisation upstream and doesn't need its own.

**Mode B (deploy-as-release) serialization is partially provided by G-0023 (GitHub Merge Queue) — but a rapid-merge release-job race remains as a known limitation.** Mode B repos have no release-PR. The release fires on each main push. The merge queue serialises the merges themselves, and the release job runs once-per-merge after the queue admits. But the queue does NOT space out the resulting `push: main` events, and adding `concurrency:` to the release job introduces a different pathology.

Verification against primary GitHub Actions and merge queue documentation confirmed:

- GHA docs verbatim: *"Any existing pending job or workflow in the same concurrency group, if it exists, will be canceled and the new queued job or workflow will take its place."* `cancel-in-progress: false` does NOT change this. It only protects the running slot.
- Merge queue admits PRs in FIFO but does not space the resulting `push: main` events. Three rapid Mode B merges produce three rapid `release.yml` triggers in close succession.
- Under those conditions, `concurrency:` on the release job would still drop the middle run (cancellation of pending), the exact pathology release-plz's quickstart warns about.

**v1 posture: accept as known limitation + fail-loud monitoring.** No `concurrency:` block on the release job. Operators monitor for missing release runs:

- **Per-release expected-tag check:** after each Stage 8 merge expected to bump the version, sweep `gh api /repos/{owner}/{repo}/git/refs/tags/v<expected>` and verify the tag landed. A missing tag means investigate the workflow history.
- **release-plz workflow-history audit:** `gh run list --workflow=release.yml` periodically. A gap between expected and actual run counts flags drops.
- Documented in the per-repo retrofit runbook.

**v2 hardening path (deferred).** Merge-queue batching with `merge_method: squash` plus queue limits ≥ 2 collapses N successive PRs into one merge group, one `push: main` event, one release run. That eliminates the race structurally. Adoption requires a separate spike on release-plz's multi-version-bump-per-push tolerance. release-plz expects one bump per push by default, and batching changes that. **Trip-wire to v2:** any rapid-merge race incident observed in production, OR Mode B repo volume increases such that the race becomes likely.

For Mode A (release-PR pattern), the release-pr-job concurrency above stays the correct mechanism. Mode A's "release event = release-PR merge" is itself a single-PR-at-a-time event under merge queue, which composes cleanly with concurrency on the release-pr job.

The `cancel-in-progress: false` setting on the release-pr job is mandatory. A release-PR update that's writing CHANGELOG / Cargo.toml MUST NOT be cancelled mid-flight by a newer trigger. Instead, the newer trigger queues until the in-flight update completes.

## Alternatives Considered

- **release-plz lock / tool-level mutex.** Rejected. release-plz provides no native lock. Bolting one on is custom work outside the tool's surface. GHA concurrency is the framework-native answer.
- **`cancel-in-progress: true`.** Rejected. Cancelling an in-flight release at tag-push time produces partial state: tag pushed but GitHub release notes not generated, or the reverse.
- **External queue / mutex** (Redis lock, etcd, etc.). Rejected. Adds infrastructure for a problem GHA's concurrency directive solves natively.
- **R26b alone** (no GHA concurrency). Rejected. R26b serializes the merge gate. The release sub-flow runs after merge, with timing controlled by GitHub's webhook delivery, so two near-simultaneous merges could still produce two release runs in flight.
- **No serialization** (accept rare double-tag attempts). Rejected. Even rare double-tag is messy: CHANGELOG drift, version skew, on-call surprise. The cost of `concurrency:` is one YAML stanza.

## Consequences

- **Per-repo workflow YAML adds the per-job `concurrency:` block on `release-pr` only.** The workspace template ships the stanza on the release-PR job exclusively. The release job stays concurrency-free. Concurrency on the release job is a bug per release-plz upstream guidance.
- **Two-layer serialization for Mode A:** G-0023 merge queue (single PR merging to main at a time) plus GHA `concurrency:` on the release-pr job (single release-PR-update at a time). The layers are independent.
- **Mode B serialization is provided by G-0023 merge queue, not by GHA `concurrency:` directives.** The release job runs once-per-merge after the merge queue has admitted the merge. Concurrency on the release job is explicitly NOT used.
- **workflow_dispatch escape hatch.** When a hung release run blocks the queue, operators may cancel via the GitHub Actions UI or `gh run cancel <run-id>`. The per-repo retrofit runbook documents the manual-cancel path.
- **Workflow permissions stanza.** The release workflow declares its minimum required permissions explicitly: `permissions: { contents: write, id-token: write, packages: write }`. No workflow-level `permissions: write-all`.
- **Queueing latency:** under serial release-PR-update flows, two near-simultaneous feature-PR merges produce two queued release-pr-job runs. The second run starts after the first completes (~30-90s for a typical Rust release-plz cycle). Acceptable.
- **No release-plz coupling** for serialization. release-plz operates per-PR. Concurrency-control is a workflow-level concern.
- **Per-repo scope** of the concurrency group (`release-pr-${{ github.repository }}`) means cross-repo releases run in parallel. The goal is to serialize within a repo, not across the workspace.
- **Cross-namespace concurrency edge (acknowledged limitation, no fix).** The group name includes the owner. If a repo is transferred or renamed, in-flight queued runs reference the old `github.repository` value while new runs reference the new one. Very low probability for the current workspace state.
- **Mnemra migration:** when mnemra absorbs the workspace, the per-repo workflow YAML stays. The concurrency group naming may shift if mnemra changes the repo identity model.
- **Alternative workload trigger paths** (manual `workflow_dispatch`, scheduled releases) for the release-pr job MUST share the same concurrency group `release-pr-${{ github.repository }}` regardless of trigger source.

## Changelog

### 2026-04-30 — Round 2 review amendments

Round 2 review flagged that under merge queue, the release-pr-only concurrency leaves Mode B repos with no serializer for parallel `release.yml` runs that fire when the queue admits multiple PRs in succession.

- **Verification spike** confirmed against primary GHA + merge queue docs: the hypothesis "restore concurrency on release job under merge queue" does NOT hold. The concurrency cancellation pathology applies under merge queue too. **Confidence: high.**
- **Pivoted G-0019 Mode B posture to accept as known limitation + fail-loud monitoring.** Per-release expected-tag check plus release-plz workflow-history audit added as monitoring mechanisms.
- **v2 hardening trip-wire added:** merge-queue batching (queue limits ≥ 2 collapsing N PRs into one push) eliminates the race structurally. Deferred until first incident OR Mode B volume increase.

### 2026-04-30 — Round 1 review amendments

- **Fixed (structural):** Moved the `concurrency:` block from the release job to the `release-pr` job per release-plz upstream quickstart guidance. GHA's concurrency semantic would drop releases under rapid Mode B merges if applied to the release job.
- **Added:** Mode B serialization is provided by G-0023 (GitHub Merge Queue), NOT by GHA `concurrency:` on the release job.
- **Added:** Consequence documenting the `workflow_dispatch` escape hatch.
- **Added:** Workflow-permissions Consequence. The release workflow declares minimum permissions; no workflow-level `permissions: write-all`.
- **Added:** Trip-wire. If mnemra adopts a cross-crate dependency where two crates share a release cadence, a workspace-level concurrency group becomes necessary.
- **Added:** Cross-namespace concurrency edge (repo transfer / rename) acknowledged as a known limitation.
