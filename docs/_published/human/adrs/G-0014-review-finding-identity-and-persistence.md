---
title: "G-0014: Review Finding Identity and Per-PR Per-Round Persistence"
summary: "(file, content-anchor, severity) triple as finding identity; SHA-256 5-line window; per-round markdown files in the review store; severity-mutation and anchor-remap rules for iterate-to-zero correctness."
primary-audience: agent
---

# G-0014: Review Finding Identity and Per-PR Per-Round Persistence

**Status:** Accepted
**Date:** 2026-04-30

## Context

Stage 4 is the review step in a change's life (the numbered steps run Stage 0 through Stage 7). It runs as an iterate-to-zero loop: fix-and-review rounds repeat until no blocking finding is left, with a 5-round hard cap that triggers escalation rather than another round. Across those rounds, the same finding can come back with cosmetic drift in its description. A different reviewer phrases it differently, or one reviewer rewords it slightly on a re-read. Without a stable identity, the iterate-to-zero count drifts. Round 2 shows "5 issues remaining" not because 5 are unresolved, but because 3 are restatements of Round 1 findings the implementing developer already addressed.

Two questions follow. What is the finding identity (the tuple that lets Round N say "this is the same finding as in Round N-1, not a new issue")? And where do round-by-round findings live, so a reviewer in Round N can see what Round N-1 surfaced?

An initial proposal used `(location, severity)` as identity. A later proposal used `(location, severity, finding-text-hash)`. The hash version tightens identity but produces false negatives when a reviewer rephrases the same defect. The discussion locked on `(file, content-anchor, severity)`.

## Decision

**Finding identity = `(file, content-anchor, severity)` triple.** Identity is decoupled from line numbers because line numbers shift when implementing developers insert or delete lines higher in the file between rounds. Under the older `(file:line-range, severity)` form, a fix-driven line shift made the same physical defect appear as a "new" finding in the next round, which exhausted the 5-round cap on a single underlying issue.

**Content-anchor.** A content-anchor is a SHA-256 hash of a normalized window around the cited finding. It anchors a finding to the surrounding code rather than to line numbers, so the finding survives line shifts and reformatting. The window is the cited line plus 2 lines of context above and below, 5 lines total, with trailing whitespace stripped per line. Normalization produces a stable hash even when the line numbers around the defect change. The window is intentionally small. It's large enough to tell two findings on the same file apart, and small enough that an unrelated edit two screens away doesn't rotate the anchor.

**Reviewer output format includes the anchor.** Reviewers cite location AND emit the anchor inline, so downstream dedup logic doesn't need to re-read the file at the cited round's commit:

```markdown
# <reviewer> review — PR <pr-ref> — round <N>

## blocker
- `path/to/file.rs:42-58` (anchor `a3f9c1`) — <description>
- `path/to/other.rs:120` (anchor `7e2d80`) — <description>

## major
- ...
```

Anchors render as the first 6 hex characters of the SHA-256 in the markdown for human readability. The full hash lives in a fenced YAML block at the bottom of each reviewer file for tooling. Reviewer profiles get the anchor-computation recipe in their dispatch brief, the context handed to a specialist when a scoped task is routed to them. The workspace template ships a `bin/finding-anchor.sh` reference script.

**Whole-file findings** (no line range) use a fixed content-anchor of `whole-file`. Two file-level findings of the same severity on the same file collapse into one. That's acceptable for v1 because file-level findings are rare. Reviewers should prefer line-anchored findings whenever a specific location is identifiable.

**Location format:** `<path>:<start_line>-<end_line>` for single-file ranges; `<path>:<start_line>` for point findings; `<path>` (file-level only) for whole-file findings.

**Severity values:** `blocker`, `major`, `minor`, `nit`. Stage 4 iterate-to-zero blocks on `blocker` and `major`. `minor` and `nit` are advisory and don't block merge.

**Severity mutation handling.** Within a single PR's review history, a defect can surface at different severities across rounds. Round 1 marks it `blocker`; the Round 2 reviewer downgrades it to `major` after a partial fix. The iterate-to-zero set-difference uses the **(file, content-anchor)** pair as the dedup key, ignoring severity, when computing the "new findings" delta. But the gating decision uses the **current-round severity** to determine whether the finding still blocks merge. This split prevents two pathologies the older identity tuple introduced: (a) severity-flipped findings counted as new, which exhausts the cap; (b) a downgrade to `nit` producing a false-pass exit while the underlying defect at a `nit` severity is still present.

Concretely, iterate-to-zero terminates when no `(file, content-anchor)` pair carries a `blocker` or `major` severity in the current round, regardless of what severity it carried in prior rounds. A reviewer downgrade keeps its intended meaning ("this is no longer blocking after the fix") without leaking through as a false-pass.

**Persistence path:** `<review-store>/<repo>-pr<N>/r<round>/<reviewer>.md`, one markdown file per `(repo, PR, round, reviewer)` tuple. The repo prefix prevents collision when two concurrent PRs share the same PR number across different repos. The repo segment uses the canonical short name (for example, `<repo-a>`, `<repo-b>`), not the GitHub owner/name pair, since the segment is workspace-private.

**Round-read discipline (disambiguated).** Reviewers in Round N+1 MUST read **Round N-1 files only, never the current Round N+1 files for the same PR.** The dispatch brief glob is `<review-store>/<repo>-pr<N>/r<N>/*.md`, where `<N>` is the prior-round counter, deliberately one less than the round being authored. This closes the same-round-dedup ambiguity. Concurrent reviewers in the same round MUST NOT read each other's files mid-round, only the prior round's files. Same-round dedup happens at round-end aggregation, after all reviewer files are written, by the dispatch coordinator.

**Round counter increment rule.** The Stage 4 round counter increments when at least one `(file, content-anchor)` pair newly carries a `blocker` or `major` severity in the current round (that is, the pair is absent from the prior round's blocker-plus-major set). Same-pair severity changes within blocker and major (blocker to major or the reverse) do not increment the counter. They're considered the same defect, a different reviewer call. Termination happens when the increment is zero across all reviewers for the round.

## Alternatives Considered

- **`(location, severity, hash(text))` triple.** Rejected. The same defect described differently across rounds produces hash drift. Identity becomes too narrow and the dedup fails the use case it exists for.
- **Reviewer-assigned finding IDs (`F-0001`, `F-0002`).** Rejected. It adds bookkeeping burden. Reviewer-side state-tracking across rounds is the failure mode iterate-to-zero is trying to remove.
- **DB-backed finding store** (for example, a `findings` table in the task DB). Rejected for v1. Same workspace-CLI-in-maintenance argument as G-0013: invest later in mnemra. Markdown-in-store is the lean substrate.
- **Per-PR single file (`<review-store>/<pr-ref>/findings.md`) updated each round.** Rejected. It loses the per-round-per-reviewer attribution, makes rounds harder to diff, and concurrent reviewer dispatches would race on the file.
- **Finding text canonicalization** (lowercase and whitespace-normalize before hashing). Rejected. Too fragile. Reviewers express the same defect with different vocabulary, not just whitespace differences.

## Consequences

- **Duplicate findings collapse on (file, content-anchor) regardless of severity.** Round N+1's count of "new findings" is the set of `(file, content-anchor)` pairs at blocker or major severity that aren't present in Round N's blocker-plus-major set. Same-pair severity flips don't count as new. Severity drops from blocker or major down to minor or nit count as resolutions. Severity rises from minor or nit up to blocker or major count as new findings, because the reviewer just discovered the worse impact.
- **Reviewer briefs include prior-round files.** The Stage 4 dispatch envelope MUST include the path glob `<review-store>/<repo>-pr<N>/r<N-1>/*.md` (one round earlier than the round being authored) so reviewers see prior context before issuing findings.
- **Severity ordering is fixed.** Reviewers MUST use the four-value enum. No custom severities. Mapping: `blocker` is a merge-blocker requiring a fix; `major` is should-fix this round; `minor` is nice-to-have, advisory; `nit` is style or preference.
- **Cross-repo namespace.** The persistence path includes the repo segment (`<review-store>/<repo>-pr<N>/r<N>/<reviewer>.md`) so concurrent PRs sharing the same number across repos cannot collide.
- **Store hygiene.** `<review-store>/<repo>-pr<N>/` directories accumulate during a PR's life. Cleanup happens at PR close, whether the PR merged or was abandoned. The session-start archive sweep moves closed-PR directories to archive after merge.
- **Concurrent-round-write discipline.** Within a single round, multiple reviewers dispatch in parallel and write their files at completion. Reviewers do NOT read each other's same-round files. Same-round dedup happens at the dispatch-coordinator post-round aggregation. The dispatch brief explicitly cites the `r<N-1>` glob to prevent read-the-current-round mistakes.
- **Anchor computation is reviewer-side.** Reviewers compute the SHA-256 over the 5-line normalized window using the workspace-template `bin/finding-anchor.sh` (or an equivalent). The anchor must be computed against the commit-SHA at which the reviewer is reading the file, which is typically the PR's HEAD at dispatch time. Round N+1 anchors against the new HEAD will produce different content-anchors only if the cited code itself changed. Line-shift drift in unrelated parts of the file does not rotate the anchor.
- **Whole-file findings caveat.** Two file-level findings (anchor `whole-file`) of the same severity on the same file collapse. Reviewers who prefer line-anchored findings reduce the chance of this collision. It's an acceptable corner case in v1.
- **Iterate-to-zero metric is exact.** The new-findings-set difference produces a clean termination signal that survives line-range drift, severity flips, and reviewer-prose variation across rounds.
- **Mnemra migration invariant.** Pre-mnemra, paths are store-relative under `<review-store>/<repo>-pr<N>/`. Post-mnemra, paths migrate to the mnemra content-plugin namespace. The **(file, content-anchor, severity)** identity tuple is invariant across the migration. The content-anchor is content-addressed by construction, so it survives substrate changes.
- **Anchor stability across reformatters.** A defect that lives inside a region of code reformatted by `cargo fmt` (or an equivalent) between rounds will rotate the anchor. The whitespace-stripped 5-line window changes when the formatting changes. In workspaces where format-on-edit is a harness hook for agent edits, every iterate-to-zero cycle involving agent edits will see anchor rotation across all touched files. The operational rule: the dispatch coordinator **MUST** perform a one-shot anchor remap at the start of each round, AFTER the round's agent edits and `cargo fmt` have landed but BEFORE reviewers read the prior-round findings file. The remap re-computes anchors for prior-round findings against the current round's HEAD, writing the remapped findings to a sidecar file (`<review-store>/<repo>-pr<N>/r<N-1>/<reviewer>-remapped.md`) that reviewers read in place of the original. The re-mapping is mechanical, but it's bounded and human-supervised. When a finding's cited file no longer exists, or the cited line range has been deleted because the defect was actually fixed structurally, the remap entry says "FIXED: finding resolved by structural change" and the reviewer doesn't need to re-flag it.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Anchor rotation as common case (cargo-fmt):** the original round 1 amendment treated reformatter rotation as a rare edge. In workspaces where `cargo fmt` runs after every agent edit cycle, anchor rotation is the common case, not the edge. **Fixed:** rewrote the "Anchor stability across reformatters" Consequence to spell out the one-shot anchor-remap rule (the dispatch coordinator regenerates prior-round anchors after agent edits and fmt land), with a sidecar file pattern (`<reviewer>-remapped.md`) that reviewers read.

### 2026-04-30 — Round 1 review amendments

Round 1 review (test author, security reviewer, and writer review) surfaced five issues with the original `(location, severity)` identity:

- **Line-range drift:** dev-edits shift line numbers, so the same defect appeared as new in each round and exhausted the 5-round cap on one underlying issue. **Fixed:** identity is now `(file, content-anchor, severity)`, with the content-anchor a SHA-256 of a normalized 5-line window. It survives line shifts.
- **Concurrent reviewer race on Round N files:** the wording "Read Round N files" was ambiguous. It could mean the prior round (intended) or the current round (mistaken same-round dedup). **Fixed:** explicit "Read Round N-1 only, never the current round." Same-round dedup is a dispatch-coordinator responsibility, not a reviewer one.
- **Cross-repo `<pr-ref>` collision:** `<review-store>/pr-17/...` collides for two repos concurrently at the same PR number. **Fixed:** the path is `<review-store>/<repo>-pr<N>/...`.
- **Severity-mutation false-pass plus cap exhaustion:** the identity tuple included severity, so flips between rounds counted as new findings (cap exhaustion) AND downgrades to nit produced a false-pass exit while the underlying defect remained. **Fixed:** dedup uses (file, content-anchor) regardless of severity; the gating decision uses current-round severity.
- **Workspace-to-mnemra migration unspecified:** the ADR mentioned migration without naming the invariant. **Fixed:** explicit "(file, content-anchor, severity) identity invariant across migration."

Status remains **Proposed** pending r2 review on the amended Decision and Consequences sections.
