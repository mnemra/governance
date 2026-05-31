---
title: "G-0007: Knowledge-Extraction Skill — Task-Completion Nudge Hook"
summary: "Two-hook pattern (Stop for detection + UserPromptSubmit for delivery) implements a once-per-session nudge at task-completion boundaries; session-keyed state file."
primary-audience: agent
---

# G-0007: Knowledge-Extraction Skill — Task-Completion Nudge Hook

**Status:** Accepted
**Date:** 2026-04-24

## Context

The knowledge-extraction skill has a task-completion nudge — a one-shot prompt offered at task-completion boundaries to catch rule candidates before the session context evaporates. The requirement mandates the implementation be **deterministic** via a harness hook; skill-file self-invocation is soft compliance and forbidden. A per-session cap prevents the nudge from firing more than once per session.

This ADR picks the hook event and session-boundary semantics.

## Decision

**Two-hook pattern** — detection separate from delivery:

- **Detection:** `Stop` hook at turn boundaries. Checks state file (keyed by `session_id` from hook payload). If not yet fired this session, writes `state=pending` to the state file.
- **Delivery:** `UserPromptSubmit` hook on the next turn reads the pending flag and injects the nudge instruction into the orchestrator's context via `additionalContext` JSON output. On a new session (post-`/clear`), `SessionStart` is the fallback delivery path.

**Session semantics:** conversation-session — `session_id` from the hook payload changes on `/clear`. State file is keyed by `session_id`, so `/clear` naturally resets nudge eligibility.

State file path: `.claude/hooks/state/knowledge-extraction-nudge`. Plaintext shape (exact format in the implementation spec): `session_id`, ISO timestamp, response state (`pending | fired`). The state-file enum is intentionally two-state. Carrier accept/decline are **conversational events** recorded on the capture row in the task DB via the workspace CLI, NOT on the state file. This preserves the trust boundary: hooks own state-file writes, the orchestrator owns capture-row writes — no path lets the hook mutate capture content.

**Why two hooks, not one:** `Stop` fires *after* the orchestrator has stopped responding; its stdout is not injected into the next conversation turn by design. Injection requires a hook that fires *before* the next response (`UserPromptSubmit` or `SessionStart`). Separating detection from delivery keeps each hook's responsibility single and deterministic.

## Alternatives Considered

- **Single-hook: Stop only with stdout nudge** — rejected. Stop fires *after* the orchestrator stops responding; its stdout is not injected into the next conversation turn. Stop alone cannot deliver a prompt the carrier sees at the next interaction.
- **Single-hook: Stop with `decision: "block"` JSON + reason** — rejected. Abuses the block-decision mechanism (designed to prevent stopping, not to deliver content). Brittle and off-label.
- **Single-hook: UserPromptSubmit alone** — rejected. Detection would need the hook to re-derive "did task just complete?" from prompt content or history — soft compliance, violates the determinism requirement.
- **PostToolUse on TaskUpdate→completed** — rejected. Many task completions don't route through `TaskUpdate`; the carrier says "done" verbally as often as tasks are checked off. Too narrow.
- **SubagentStop** — rejected. Fires at dispatch/subagent boundary, not at carrier-level task completion. Wrong event class.
- **Harness-session semantics (persists across `/clear`)** — rejected. Would cap the nudge at one per day across multiple conversations. Too conservative for the "catch rules before context evaporates" intent.

## Consequences

- Deterministic per the requirement — both hooks are harness-fired, not skill-file self-invocation.
- `/clear` resets nudge eligibility — verified via multiple `session_id` values per day.
- Detection runs on every turn boundary (cheap — state-file read + conditional write); delivery only fires when there's a pending nudge to inject.
- Specific-vs-generic nudge phrasing requires the orchestrator's in-context view; the detection hook cannot identify candidates. The implementation spec owns the delivery-payload shape and the specific-candidate detection logic.
- **Smoke-test gate before implementation commits:** confirm `UserPromptSubmit` supports `additionalContext` injection in the current harness version. `additionalContext` is verified working on `PostToolUse` and `PreToolUse`; if the smoke test fails, `SessionStart` fallback preserves semantics but shifts delivery latency by one session (nudge fires at the start of the *next* session). Latency shift is acceptable; skill semantics unchanged.
- **JSON delivery discipline:** hooks that emit `additionalContext` MUST construct JSON via `jq -n` or equivalent Rust — never shell `echo "{...}"`. Nudge payloads may reference rule text or session content containing quotes and backslashes; shell-echo JSON silently produces malformed output under those inputs.
- **Hook deployment stanza:** both hooks land in the harness settings under the workspace's existing hook-config pattern. Rollback: remove both hook entries from the settings file and delete `.claude/hooks/state/knowledge-extraction-nudge` — state file is disposable.
- **State-file hygiene:** writes use atomic `tmpfile + rename` pattern to avoid partial-write corruption. Graceful default on missing or malformed state file: treat as "not yet fired this session" (safest — at worst, re-nudges once; does not block). `SessionEnd` hook deletes the state file at session close as cleanup.
- Composition integrity: hooks only fire the prompt; carrier must respond for the transform loop to run. Hooks never write rules.
