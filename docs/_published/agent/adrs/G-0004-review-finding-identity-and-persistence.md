---
title: "G-0004: Review Finding Identity and Per-PR Per-Round Persistence"
summary: "A review finding's identity is the triple (file, content-anchor, severity), where the content-anchor is a SHA-256 of a normalized code window; dedup keys on (file, content-anchor) ignoring severity, while gating reads current-round severity, so the iterate-to-zero count survives line shifts, severity flips, and reviewer rewording."
primary-audience: agent
---

# G-0004: Review Finding Identity and Per-PR Per-Round Persistence

**Status:** Accepted
**Date:** 2026-04-30

## Context

Stage 4 review is iterate-to-zero with a five-round hard cap. Across rounds, the same finding can recur with cosmetic drift in its description (different reviewer phrasing, slight rewording on a re-read). Without a stable identity, the iterate-to-zero count drifts: Round 2 shows "5 issues remaining" not because 5 are unresolved but because 3 are restatements of Round 1 findings already addressed.

The question is twofold: what identity tuple lets Round N say "this is the same finding as in Round N-1, not a new issue," and where do round-by-round findings live so a reviewer in Round N can see what Round N-1 surfaced?

One candidate identity was `(location, severity)`; a tighter candidate added a hash of the finding text, but the text-hash version produces false negatives when a reviewer rephrases the same defect. The decision locked on a content-anchored tuple.

This ADR's testing-standard dependency is `depends-on P-TDDPairs` (the coverage-floor and pyramid standard).

## Decision

**Finding identity = the `(file, content-anchor, severity)` triple.** Identity decouples from line numbers because line numbers shift when lines are inserted or deleted higher in the file between rounds — under a `(file:line-range, severity)` form, a fix-driven line shift made the same physical defect appear as a "new" finding in the next round, exhausting the five-round cap on a single underlying issue.

**Content-anchor:** a SHA-256 of a normalized window around the cited finding. The window is the cited line plus two lines of context above and below (five lines total), with trailing whitespace stripped per line. Normalization produces a stable hash even when the line numbers around the defect change. The window is intentionally small: large enough to disambiguate two findings on the same file from each other, small enough that an unrelated edit two screens away does not rotate the anchor.

**Reviewer output format includes the anchor.** Reviewers cite the location AND emit the anchor inline, so downstream dedup logic does not need to re-read the file at the cited round's commit:

```markdown
# <reviewer> review — PR <pr-ref> — round <N>

## blocker
- `path/to/file.rs:42-58` (anchor `a3f9c1`) — <description>
- `path/to/other.rs:120` (anchor `7e2d80`) — <description>

## major
- ...
```

Anchors render as the first six hex characters of the SHA-256 in the markdown for human readability; the full hash lives in a fenced YAML block at the bottom of each reviewer file for tooling. Reviewers receive the anchor-computation recipe in their dispatch brief (a reference anchor-computation script ships with the review tooling).

**Whole-file findings** (no line range) use a fixed content-anchor of `whole-file`. Two file-level findings of the same severity on the same file collapse — acceptable for v1, since file-level findings are rare; reviewers should prefer line-anchored findings whenever a specific location is identifiable.

**Location format:** `<path>:<start_line>-<end_line>` for single-file ranges; `<path>:<start_line>` for point findings; `<path>` (file-level only) for whole-file findings.

**Severity values:** `blocker`, `major`, `minor`, `nit`. Stage 4 iterate-to-zero blocks on `blocker` and `major`; `minor` and `nit` are advisory and do not block merge.

**Severity mutation handling.** Within a single PR's review history, a defect may surface at different severities across rounds (Round 1 marks it `blocker`, Round 2 downgrades to `major` after a partial fix). The iterate-to-zero set-difference uses the **`(file, content-anchor)`** pair as the dedup key, ignoring severity, when computing the "new findings" delta — but the gating decision uses the **current-round severity** to decide whether the finding still blocks merge. This split prevents two pathologies the severity-in-identity form introduced: (a) severity-flipped findings counted as new (cap exhaustion); and (b) a downgrade-to-`nit` producing a false-pass exit while the underlying defect is still present.

Concretely, iterate-to-zero terminates when no `(file, content-anchor)` pair carries a `blocker` or `major` severity in the current round, regardless of what severity it carried in prior rounds. A reviewer downgrade then has its intended meaning ("this is no longer blocking after the fix") without leaking through as a false-pass.

**Persistence:** one markdown file per `(repo, PR, round, reviewer)` tuple, in a per-PR working area namespaced by the repo's canonical short name. The repo namespace prevents collision when the same PR number is concurrently in flight across two different repos (concurrent PRs across different repos are allowed). The namespace uses the canonical short name, not the host owner/name pair, since it is an internal working area.

**Round-read discipline.** Reviewers in Round N+1 MUST read **Round N files only — never the current Round N+1 files for the same PR**. The dispatch brief points reviewers at the prior round's files (one less than the round being authored). This closes a same-round dedup ambiguity: concurrent reviewers in the same round MUST NOT read each other's files mid-round, only the prior round's files. Same-round dedup happens at round-end aggregation, after all reviewer files are written, by the dispatch coordinator.

**Round counter increment rule.** The Stage 4 round counter increments when at least one `(file, content-anchor)` pair newly carries a `blocker` or `major` severity in the current round (i.e., absent from the prior round's blocker+major set). Same-pair severity changes within blocker+major (blocker → major or vice versa) do not increment the counter — they are "the same defect, a different reviewer call." Termination happens when the increment is zero across all reviewers for the round.

## Alternatives Considered

- **`(location, severity, hash(text))` triple.** Rejected. The same defect described differently across rounds produces hash drift; identity becomes too narrow and the dedup fails the use case it exists for.
- **Reviewer-assigned finding IDs (`F-0001`, `F-0002`).** Rejected. It adds bookkeeping burden; reviewer-side state-tracking across rounds is exactly the failure mode iterate-to-zero is trying to remove.
- **A database-backed finding store.** Rejected for v1. A richer relational substrate is deferred; markdown files are the lean substrate for now.
- **A per-PR single file updated each round.** Rejected. It loses per-round-per-reviewer attribution, is harder to diff across rounds, and races when concurrent reviewer dispatches write it.
- **Finding-text canonicalization** (lowercase and whitespace-normalize before hashing). Rejected. Too fragile; reviewers express the same defect with different vocabulary, not just whitespace differences.

## Consequences

- **Duplicate findings collapse on `(file, content-anchor)` regardless of severity.** Round N+1's count of "new findings" is the set of `(file, content-anchor)` pairs at blocker+major severity not present in Round N's blocker+major set. Same-pair severity flips do not count as new; drops from blocker+major to minor+nit count as resolutions; rises from minor+nit to blocker+major count as new findings (the reviewer just discovered the worse impact).
- **Reviewer briefs include prior-round files.** The Stage 4 dispatch envelope MUST include the prior round's reviewer files (one round earlier than the round being authored) so reviewers see prior context before issuing findings.
- **Severity ordering is fixed.** Reviewers MUST use the four-value enum; no custom severities. `blocker` = merge-blocker requiring a fix; `major` = should-fix this round; `minor` = nice-to-have, advisory; `nit` = style/preference.
- **Cross-repo namespace.** The persistence area includes the repo namespace so concurrent PRs sharing a number across repos cannot collide.
- **Working-area hygiene.** Per-PR working directories accumulate during a PR's life. Cleanup happens at PR close (merged or abandoned); a session-start sweep archives closed-PR directories after merge.
- **Concurrent-round-write discipline.** Within a single round, multiple reviewers dispatch in parallel and write their files at completion. Reviewers do NOT read each other's same-round files — same-round dedup happens at the dispatch coordinator's post-round aggregation. The dispatch brief explicitly cites the prior-round files to prevent read-the-current-round mistakes.
- **Anchor computation is reviewer-side.** Reviewers compute the SHA-256 over the five-line normalized window. The anchor must be computed against the commit at which the reviewer is reading the file (typically the PR's HEAD at dispatch time). Round N+1 anchors against the new HEAD produce different content-anchors only if the cited code itself changed; line-shift drift elsewhere in the file does not rotate the anchor — that is the whole point.
- **Whole-file findings caveat.** Two file-level findings (anchor `whole-file`) of the same severity on the same file collapse. Reviewers preferring line-anchored findings reduce the chance of this collision. An acceptable corner case in v1.
- **The iterate-to-zero metric is exact.** The new-findings set-difference produces a clean termination signal that survives line-range drift, severity flips, and reviewer-prose variation across rounds.
- **Content-addressed identity survives substrate migration.** The `(file, content-anchor, severity)` tuple is invariant if the persistence area later moves to a richer store; the content-anchor is content-addressed by construction, so it survives substrate changes.
- **Anchor stability across reformatters.** A defect inside a region reformatted by an auto-formatter (e.g., `cargo fmt`) between rounds will rotate the anchor — the whitespace-stripped five-line window changes when the formatting changes. Because the formatter runs after every implementer/test-author edit cycle, anchor rotation is the common case, not the edge case: every iterate-to-zero cycle that involves agent edits sees anchor rotation across all touched files. The operational rule: the dispatch coordinator performs a one-shot anchor remap at the start of each round, after the round's agent edits and formatting have landed but before reviewers read the prior-round findings. The remap re-computes anchors for prior-round findings against the current round's HEAD, writing the remapped findings to a sidecar file that reviewers read in place of the original. The remap is mechanical (find the cited file and line, recompute the anchor on the new content) but bounded and supervised: when a finding's cited file no longer exists or the cited range has been deleted (the defect was fixed structurally), the remap entry reads "FIXED — finding resolved by structural change" and the reviewer need not re-flag it.
