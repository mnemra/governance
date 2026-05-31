---
title: "G-0004: Hybrid XML Format for Agent Profiles"
summary: "Agent profiles use hybrid XML format: XML tags for structure, markdown inside tags for prose. Required top-level tags enumerated; max two nesting levels."
primary-audience: agent
---

# G-0004: Hybrid XML Format for Agent Profiles

**Status:** Accepted
**Date:** 2026-04-05

## Context

Agent profiles written in pure markdown with `##` headers produced ambiguous section navigation as profiles grew more complex (principles with subsections, command scopes with allow/deny lists). The dispatch protocol also needed to selectively load profile sections (e.g., only `<role>` + `<persona>` + `<command-scope>` for light dispatches), which markdown headers don't support cleanly.

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
- The format is non-standard — contributors unfamiliar with the workspace need the skill doc to understand it.
