# CLAUDE.md — mnemra-governance

## What this repository is

This repository is a **publish-only render** of the mnemra governance canon. It is **not** the source of truth.

The authoritative canon — architecture values, principles, constraint edges, and the `G-*` ADRs — is **currently maintained upstream in the private workspace**. Over the last two months that canon has evolved, been renumbered, and been consolidated (for example, the ADR corpus was reset and renumbered — historical `G-` numbers in this repo may not match the current authoritative set). The goal of this repository is to **reflect the current workspace canon**, re-rendered for a public audience.

## Working rule for agents

- Treat `docs/src/` and `docs/_published/` as **generated artifacts, not canon.** Do not author or "correct" canon here. A change made in this repo does not flow back upstream and is overwritten on the next sync.
- Canon changes **originate upstream.** This repo is updated by re-rendering the authoritative canon: bring `docs/src/` into line with the upstream canon (genericized for a public audience — no workspace-internal file paths, tool names, or team labels), then run the publish pipeline to regenerate `docs/_published/`.
- The dual-audience render (`agent` / `human`), the translation prompts, and the drift gates are described in `README.md` and the `justfile` (`just check`).

## Audience discipline

Everything published here is written for an external reader with no workspace context. Keep workspace-internal taxonomy out: no private file paths, no internal tool or agent names, no internal ticket references. Term definitions live in `docs/src/glossary.md`.
