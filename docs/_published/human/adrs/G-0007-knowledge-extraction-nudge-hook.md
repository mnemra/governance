---
title: "G-0007: Knowledge-Extraction Skill — Task-Completion Nudge Hook"
summary: "Two-hook pattern (Stop for detection + UserPromptSubmit for delivery) implements a once-per-session nudge at task-completion boundaries; session-keyed state file."
primary-audience: agent
---

# G-0007: Knowledge-Extraction Skill — Task-Completion Nudge Hook

**Status:** Accepted
**Date:** 2026-04-24

## Context

The knowledge-extraction skill has a task-completion nudge. It's a one-shot prompt offered at task-completion boundaries to catch rule candidates before the session context evaporates. The requirement says the implementation has to be **deterministic**, driven by a harness hook. A skill file that invokes itself is soft compliance, and it's forbidden. A per-session cap stops the nudge from firing more than once per session.

This ADR picks the hook event and the session-boundary semantics.

## Decision

**Two-hook pattern.** Detection is separate from delivery.

- **Detection:** a `Stop` hook at turn boundaries. It checks a state file keyed by the `session_id` from the hook payload. If the nudge hasn't fired this session, it writes `state=pending` to the state file.
- **Delivery:** a `UserPromptSubmit` hook on the next turn reads the pending flag and injects the nudge instruction into the context of the orchestrator (the role that routes and coordinates work, dispatching to specialists and integrating their results). Injection happens through `additionalContext` JSON output. On a new session, after a `/clear`, `SessionStart` is the fallback delivery path.

**Session semantics:** the conversation-session. The `session_id` from the hook payload changes on `/clear`. The state file is keyed by `session_id`, so `/clear` resets nudge eligibility on its own.

State file path: `.claude/hooks/state/knowledge-extraction-nudge`. The plaintext shape, with the exact format in the implementation spec, carries a `session_id`, an ISO timestamp, and a response state (`pending | fired`). The state-file enum is intentionally two-state. Carrier accept and decline are **conversational events**. They're recorded on the capture row in the task DB through the workspace CLI, NOT on the state file. That split preserves the trust boundary. Hooks own state-file writes, the orchestrator owns capture-row writes, and no path lets the hook mutate capture content.

**Why two hooks, not one:** `Stop` fires *after* the orchestrator has stopped responding, and its stdout isn't injected into the next conversation turn by design. Injection needs a hook that fires *before* the next response, which is `UserPromptSubmit` or `SessionStart`. Splitting detection from delivery keeps each hook's responsibility single and deterministic.

## Alternatives Considered

- **Single-hook: Stop only with stdout nudge.** Rejected. `Stop` fires *after* the orchestrator stops responding, and its stdout isn't injected into the next conversation turn. `Stop` on its own can't deliver a prompt the carrier sees at the next interaction.
- **Single-hook: Stop with `decision: "block"` JSON + reason.** Rejected. It abuses the block-decision mechanism, which is designed to prevent stopping, not to deliver content. Brittle and off-label.
- **Single-hook: UserPromptSubmit alone.** Rejected. Detection would need the hook to re-derive "did a task just complete?" from prompt content or history. That's soft compliance, and it violates the determinism requirement.
- **PostToolUse on TaskUpdate→completed.** Rejected. Many task completions don't route through `TaskUpdate`. The carrier says "done" verbally about as often as tasks get checked off. Too narrow.
- **SubagentStop.** Rejected. It fires at the dispatch and subagent boundary, not at carrier-level task completion. Wrong event class.
- **Harness-session semantics (persists across `/clear`).** Rejected. It would cap the nudge at one per day across multiple conversations. Too conservative for the "catch rules before context evaporates" intent.

## Consequences

- Deterministic per the requirement. Both hooks are harness-fired, not skill-file self-invocation.
- `/clear` resets nudge eligibility, verified through multiple `session_id` values within a single day.
- Detection runs on every turn boundary. It's cheap: a state-file read plus a conditional write. Delivery only fires when there's a pending nudge to inject.
- Specific-versus-generic nudge phrasing needs the orchestrator's in-context view. The detection hook can't identify candidates. The implementation spec owns the delivery-payload shape and the specific-candidate detection logic.
- **Smoke-test gate before implementation commits:** confirm `UserPromptSubmit` supports `additionalContext` injection in the current harness version. `additionalContext` is verified working on `PostToolUse` and `PreToolUse`. If the smoke test fails, the `SessionStart` fallback keeps the semantics but shifts delivery latency by one session, so the nudge fires at the start of the *next* session. The latency shift is acceptable, and the skill semantics don't change.
- **JSON delivery discipline:** hooks that emit `additionalContext` MUST build the JSON with `jq -n` or equivalent Rust. Never with shell `echo "{...}"`. Nudge payloads can reference rule text or session content with quotes and backslashes, and shell-echo JSON silently produces malformed output under those inputs.
- **Hook deployment stanza:** both hooks land in the harness settings under the workspace's existing hook-config pattern. To roll back, remove both hook entries from the settings file and delete `.claude/hooks/state/knowledge-extraction-nudge`. The state file is disposable.
- **State-file hygiene:** writes use the atomic `tmpfile + rename` pattern to avoid partial-write corruption. On a missing or malformed state file the default is graceful: treat it as "not yet fired this session." That's the safest read. At worst it re-nudges once, and it never blocks. A `SessionEnd` hook deletes the state file at session close as cleanup.
- Composition integrity: hooks only fire the prompt. The carrier has to respond for the transform loop to run. Hooks never write rules.
