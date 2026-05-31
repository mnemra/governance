---
title: "G-0014: Review Finding Identity and Per-PR Per-Round Persistence"
summary: "(file, content-anchor, severity) triple as finding identity; SHA-256 5-line window; per-round markdown files in the review store; severity-mutation and anchor-remap rules for iterate-to-zero correctness."
primary-audience: agent
---

# G-0014: Review Finding Identity and Per-PR Per-Round Persistence

**Status:** Accepted
**Date:** 2026-04-30

## Context

Stage 4 review is iterate-to-zero with a 5-round hard cap. Across rounds, the same finding can recur with cosmetic drift in its description (different reviewer phrasing, slight rewording when a reviewer re-reads). Without a stable identity, the iterate-to-zero count drifts: Round 2 shows "5 issues remaining" not because 5 are unresolved but because 3 are restatements of Round 1 findings the implementing developer already addressed.

The question: what's the identity tuple that lets Round N say "this is the same finding as in Round N-1, not a new issue"? And where do round-by-round findings live so a reviewer in Round N can see what Round N-1 surfaced?

An initial proposal used `(location, severity)` as identity. A subsequent proposal used `(location, severity, finding-text-hash)` — the hash version tightens identity but produces false negatives when a reviewer rephrases the same defect. The discussion locked on `(file, content-anchor, severity)`.

## Decision

**Finding identity = `(file, content-anchor, severity)` triple.** Identity decouples from line numbers because line numbers shift when implementing developers insert/delete lines higher in the file between rounds — under the older `(file:line-range, severity)` form, a fix-driven line shift made the same physical defect appear as a "new" finding in the next round, exhausting the 5-round cap on a single underlying issue.

**Content-anchor:** SHA-256 of a normalized window around the cited finding. The window is the cited line plus 2 lines of context above and below (5 lines total), with trailing whitespace stripped per line. Normalization produces a stable hash even when the line numbers around the defect change. The window is intentionally small: large enough to disambiguate two findings on the same file from each other, small enough that an unrelated edit two screens away doesn't rotate the anchor.

**Reviewer output format includes the anchor.** Reviewers cite location AND emit the anchor inline so downstream dedup logic doesn't need to re-read the file at the cited round's commit:

```markdown
# <reviewer> review — PR <pr-ref> — round <N>

## blocker
- `path/to/file.rs:42-58` (anchor `a3f9c1`) — <description>
- `path/to/other.rs:120` (anchor `7e2d80`) — <description>

## major
- ...
```

Anchors render as the first 6 hex characters of the SHA-256 in the markdown for human readability; the full hash lives in a fenced YAML block at the bottom of each reviewer file for tooling. Reviewer profiles get the anchor-computation recipe in their dispatch brief (workspace template ships a `<workspace-root>/bin/finding-anchor.sh` reference script).

**Whole-file findings** (no line range) use a fixed-content-anchor of `whole-file`. Two file-level findings of the same severity on the same file collapse — acceptable for v1 since file-level findings are rare; reviewers should prefer line-anchored findings whenever a specific location is identifiable.

**Location format:** `<path>:<start_line>-<end_line>` for single-file ranges; `<path>:<start_line>` for point findings; `<path>` (file-level only) for whole-file findings.

**Severity values:** `blocker`, `major`, `minor`, `nit`. Stage 4 iterate-to-zero blocks on `blocker` + `major`; `minor` and `nit` are advisory and don't block merge.

**Severity mutation handling.** Within a single PR's review history, a defect may surface at different severities across rounds (Round 1 marks it `blocker`, Round 2 reviewer downgrades to `major` after a partial fix). The iterate-to-zero set-difference uses the **(file, content-anchor)** pair as the dedup key, ignoring severity, when computing the "new findings" delta — but the gating decision uses the **current-round severity** to determine whether the finding still blocks merge. This split prevents two pathologies the older identity tuple introduced: (a) severity-flipped findings counted as new (cap exhaustion); (b) downgrade-to-`nit` producing a false-pass exit when the underlying defect at a `nit` severity is still present.

Concretely, iterate-to-zero terminates when no `(file, content-anchor)` pair carries a `blocker` or `major` severity in the current round, regardless of what severity it carried in prior rounds. Reviewer downgrade has its intended meaning ("this is no longer blocking after the fix") without leaking through as a false-pass.

**Persistence path:** `<review-store>/<repo>-pr<N>/r<round>/<reviewer>.md` — one markdown file per `(repo, PR, round, reviewer)` tuple. The repo prefix prevents collision when two concurrent PRs share the same PR number across different repos. The repo segment uses the canonical short name (e.g., `<repo-a>`, `<repo-b>`) — not the GitHub owner/name pair, since the segment is workspace-private.

**Round-read discipline (disambiguated).** Reviewers in Round N+1 MUST read **Round N-1 files only — never the current Round N+1 files for the same PR**. The dispatch brief glob is `<review-store>/<repo>-pr<N>/r<N>/*.md` (where `<N>` is the prior-round counter, deliberately one less than the round being authored). This closes the same-round-dedup ambiguity — concurrent reviewers in the same round MUST NOT read each other's files mid-round, only the prior round's files. Same-round dedup happens at round-end aggregation, after all reviewer files are written, by the dispatch coordinator.

**Round counter increment rule.** Stage 4 round counter increments when at least one `(file, content-anchor)` pair newly carries a `blocker` or `major` severity in the current round (i.e., absent from the prior round's blocker+major set). Same-pair severity changes within blocker+major (blocker → major or vice versa) do not increment the counter — they're considered "the same defect, different reviewer call." Termination happens when the increment is zero across all reviewers for the round.

## Alternatives Considered

- **`(location, severity, hash(text))` triple.** Rejected. Same defect described differently across rounds produces hash drift; identity becomes too narrow and the dedup fails the use case it exists for.
- **Reviewer-assigned finding IDs (`F-0001`, `F-0002`).** Rejected. Adds bookkeeping burden; reviewer-side state-tracking across rounds is the failure mode iterate-to-zero is trying to remove.
- **DB-backed finding store** (e.g., `findings` table in task DB). Rejected for v1. Same workspace-CLI-in-maintenance argument as G-0013 — invest later in mnemra. Markdown-in-store is the lean substrate.
- **Per-PR single file (`<review-store>/<pr-ref>/findings.md`) updated each round.** Rejected. Loses the per-round-per-reviewer attribution; harder to diff rounds; concurrent reviewer dispatches would race on the file.
- **Finding text canonicalization** (lowercase + whitespace-normalize before hashing). Rejected. Too fragile; reviewers express the same defect with different vocabulary, not just whitespace differences.

## Consequences

- **Duplicate findings collapse on (file, content-anchor) regardless of severity.** Round N+1's count of "new findings" is the set of `(file, content-anchor)` pairs at blocker+major severity not present in Round N's blocker+major set. Same-pair severity flips don't count as new; severity drops from blocker+major to minor+nit count as resolutions; severity rises from minor+nit to blocker+major count as new findings (the reviewer just discovered the worse impact).
- **Reviewer briefs include prior-round files.** Stage 4 dispatch envelope MUST include the path glob `<review-store>/<repo>-pr<N>/r<N-1>/*.md` (one round earlier than the round being authored) so reviewers see prior context before issuing findings.
- **Severity ordering is fixed.** Reviewers MUST use the four-value enum; no custom severities. Mapping: `blocker` = merge-blocker requiring fix; `major` = should-fix this round; `minor` = nice-to-have, advisory; `nit` = style/preference.
- **Cross-repo namespace.** The persistence path includes the repo segment (`<review-store>/<repo>-pr<N>/r<N>/<reviewer>.md`) so concurrent PRs sharing the same number across repos cannot collide.
- **Store hygiene:** `<review-store>/<repo>-pr<N>/` directories accumulate during a PR's life. Cleanup happens at PR close (merged or abandoned). The session-start archive sweep moves closed-PR directories to archive after merge.
- **Concurrent-round-write discipline.** Within a single round, multiple reviewers dispatch in parallel and write their files at completion. Reviewers do NOT read each other's same-round files — same-round dedup happens at the dispatch-coordinator post-round aggregation. The dispatch brief explicitly cites the `r<N-1>` glob to prevent read-the-current-round mistakes.
- **Anchor computation is reviewer-side.** Reviewers compute the SHA-256 over the 5-line normalized window using the workspace-template `<workspace-root>/bin/finding-anchor.sh` (or equivalent). The anchor must be computed against the commit-SHA at which the reviewer is reading the file (typically the PR's HEAD at dispatch time). Round N+1 anchors against the new HEAD will produce different content-anchors only if the cited code itself changed; line-shift drift in unrelated parts of the file does not rotate the anchor.
- **Whole-file findings caveat.** Two file-level findings (anchor `whole-file`) of the same severity on the same file collapse. Reviewers preferring line-anchored findings reduce the chance of this collision. Acceptable corner case in v1.
- **Iterate-to-zero metric is exact:** the new-findings-set difference produces a clean termination signal that survives line-range drift, severity flips, and reviewer-prose variation across rounds.
- **Mnemra migration invariant.** Pre-mnemra: paths are store-relative under `<review-store>/<repo>-pr<N>/`. Post-mnemra: paths migrate to mnemra content-plugin namespace; the **(file, content-anchor, severity)** identity tuple is invariant across the migration. The content-anchor is content-addressed by construction, so it survives substrate changes.
- **Anchor stability across reformatters.** A defect that lives inside a region of code reformatted by `cargo fmt` (or equivalent) between rounds will rotate the anchor — the whitespace-stripped 5-line window changes when the formatting changes. In workspaces where format-on-edit is a harness hook for agent edits, this means every iterate-to-zero cycle involving agent edits will see anchor rotation across all touched files. The operational rule: the dispatch coordinator **MUST** perform a one-shot anchor remap at the start of each round AFTER the round's agent edits + cargo fmt have landed but BEFORE reviewers read the prior-round findings file. The remap re-computes anchors for prior-round findings against the current round's HEAD, writing the remapped findings to a sidecar file (`<review-store>/<repo>-pr<N>/r<N-1>/<reviewer>-remapped.md`) that reviewers read in place of the original. The re-mapping is mechanical but is bounded human-supervised: when a finding's cited file no longer exists or the cited line range has been deleted (the defect was actually fixed structurally), the remap entry says "FIXED — finding resolved by structural change" and the reviewer doesn't need to re-flag.

## Changelog

### 2026-04-30 — Round 2 review amendments

- **Anchor rotation as common case (cargo-fmt):** original round 1 amendment treated reformatter rotation as a rare edge. In workspaces where cargo fmt runs after every agent edit cycle, anchor rotation is the common case, not the edge. **Fixed:** rewrote the "Anchor stability across reformatters" Consequence to spell out the one-shot anchor-remap rule (dispatch coordinator regenerates prior-round anchors after agent edits + fmt land), with a sidecar file pattern (`<reviewer>-remapped.md`) that reviewers read.

### 2026-04-30 — Round 1 review amendments

Round 1 review (test-author + security + editor review) surfaced five issues with the original `(location, severity)` identity:

- **Line-range drift:** dev-edits shift line numbers; same defect appeared as new in each round, exhausting the 5-round cap on one underlying issue. **Fixed:** identity is now `(file, content-anchor, severity)` with the content-anchor a SHA-256 of a normalized 5-line window. Survives line shifts.
- **Concurrent reviewer race on Round N files:** wording "Read Round N files" was ambiguous — could mean prior round (intended) or current round (mistaken same-round dedup). **Fixed:** explicit "Read Round N-1 only, never current round." Same-round dedup is dispatch-coordinator responsibility, not reviewer.
- **Cross-repo `<pr-ref>` collision:** `<review-store>/pr-17/...` collides for two repos concurrently at the same PR number. **Fixed:** path is `<review-store>/<repo>-pr<N>/...`.
- **Severity-mutation false-pass + cap exhaustion:** identity tuple included severity, so flips between rounds counted as new findings (cap exhaustion) AND downgrades to nit produced a false-pass exit (the underlying defect remained). **Fixed:** dedup uses (file, content-anchor) regardless of severity; gating decision uses current-round severity.
- **Workspace-to-mnemra migration unspecified:** ADR mentioned migration without naming the invariant. **Fixed:** explicit "(file, content-anchor, severity) identity invariant across migration."

Status remains **Proposed** pending r2 review on the amended Decision + Consequences sections.
