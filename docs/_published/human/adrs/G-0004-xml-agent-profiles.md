---
title: "G-0004: Hybrid XML Format for Agent Profiles"
summary: "Agent profiles use hybrid XML format: XML tags for structure, markdown inside tags for prose. Required top-level tags enumerated; max two nesting levels."
primary-audience: agent
---

# G-0004: Hybrid XML Format for Agent Profiles

**Status:** Accepted
**Date:** 2026-04-05

## Context

Agent profiles are the files that define each specialist on the agentic team: who the agent is, what model it runs on, and the rules it works under. Early profiles were written in pure markdown, using `##` headers to mark sections. That broke down as profiles grew. Principles picked up subsections, and command scopes picked up allow and deny lists. Section navigation turned ambiguous.

The dispatch protocol made the problem worse. Dispatch (handing a scoped task to a specialist with the context it needs to act) sometimes wants only part of a profile. A light dispatch might load just the `<role>`, `<persona>`, and `<command-scope>` sections and skip the rest. Markdown headers don't give a clean way to select sections like that.

## Decision

Use hybrid XML format for all team agent profiles: XML tags for structural sections, markdown preserved inside tags for prose content.

Required top-level tags: `<role>`, `<model>`, `<persona>`, `<principles>`, `<instructions>`, `<command-scope>`. Subsections within `<principles>` use semantically named nested tags (`<testing>`, `<error-handling>`, etc.). Maximum two levels of nesting. Content inside tags stays as markdown (bullets, bold, code blocks).

The format spec and conversion guide live in the agent-skills library.

## Alternatives Considered

- **Pure markdown with conventions** (e.g., always use `###` for subsections): Rejected because positional ambiguity remains. Agents and grep both struggle with "which `## Testing` do you mean?"
- **Pure XML/YAML** (structured data throughout): Rejected because profile prose (persona descriptions, principle explanations) reads poorly in XML. The hybrid keeps content human-readable.
- **JSON profiles**: Rejected for the same readability reason. JSON is for machines, not for describing an agent's personality.

## Consequences

- All active agent profiles use the format. New profiles must follow it.
- Light dispatches can grep or parse specific tags without loading the full profile.
- Profiles stay under 4KB. If a profile exceeds this, behavioral rules split into a skill file.
- The format is non-standard. Contributors unfamiliar with the workspace need the skill doc to understand it.
