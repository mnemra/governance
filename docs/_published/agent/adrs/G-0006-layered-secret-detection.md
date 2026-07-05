---
title: "G-0006: Layered Secret Detection — Pre-Commit + Host-Native + CI Alerts Query"
summary: "Three complementary secret-detection layers per in-scope repo: a pre-commit regex hook, host-native push protection and scanning, and a CI recipe that fails the build on any open secret-scanning alert. Pre-commit is a velocity aid; host-native is the structural boundary; the CI query is the deterministic backstop."
primary-audience: agent
---

# G-0006: Layered Secret Detection — Pre-Commit + Host-Native + CI Alerts Query

**Status:** Accepted
**Date:** 2026-04-30

## Context

Secret-detection gates are a per-repo concern. The question was which detection mechanism, where in the workflow, and at what cost.

Three layers of opportunity exist:

- **Pre-commit (Stage 2):** catch secrets before they enter local history.
- **Server-side push protection / scanning (continuous):** catch what slipped past local hooks at push time and continuously after.
- **CI (Stage 5, `just ci`):** an explicit fail-the-build query for any open secret-scanning alert.

All current host-hosted repos are public, so host-native secret scanning and push protection are available on the free tier — no paid advanced-security subscription is required. Local-only repos need host migration as an execution-stage prerequisite, and default to public unless flagged otherwise.

The chosen shape is a pre-commit regex plus host-native scanning plus a CI query — the simplest defense in depth. A richer entropy-based scanner was a considered alternative, rejected for v1 on simplicity grounds.

**External-PR contributors are out of scope for v1.** All in-scope repos restrict PR creation to collaborators. The fork-PR posture (`pull_request_target` vs `pull_request` semantics, secrets-from-forks exclusion, a first-time-contributor approval gate) is revisited only if a future external-contributor scenario arises — at which point this ADR and G-0005 / G-0009 are amended together. The CI secret-scanning recipe and the pre-commit hooks therefore assume an in-team-collaborator threat model.

## Decision

**Three layers, each with a distinct trigger and tool. All three apply per in-scope repo.**

### Layer 1 — Pre-commit (Stage 2)

Git `commit-msg` and `pre-commit` hooks (via a hook manager such as lefthook) running a shared narrow regex covering common patterns:

| Pattern class | Example trigger |
|---------------|-----------------|
| AWS access key | `AKIA[0-9A-Z]{16}` |
| Host access token | `ghp_[A-Za-z0-9]{36}`, `gho_...`, `ghs_...`, `ghr_...` |
| Common API token prefixes | `sk_live_`, `sk_test_`, `xoxb-`, `xoxp-` |
| JWT signature | `eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` |
| Private-key headers | `-----BEGIN (RSA \|EC \|OPENSSH \|PGP )?PRIVATE KEY-----` |

The shared regex is kept in one canonical place; per-repo hook config references it.

### Layer 2 — Host-native (continuous, always-on)

For every in-scope host-hosted repo:

- secret scanning enabled (free for public repos)
- secret-scanning push protection enabled (same applicability)

These run continuously without per-repo CI configuration. Push protection blocks pushes containing detected provider secrets at the host edge.

### Layer 3 — CI (Stage 5, `just ci`)

`just ci` includes a `verify-secrets` recipe that queries the secret-scanning alerts API. Recipe spec:

1. The calling CI job MUST declare `permissions.security-events: read`. Without it, the token has no scope to read alerts and the API returns 404 (indistinguishable from "no alerts" in a naive query).
2. The recipe MUST check the response status explicitly. A non-200 (404 disabled, 403 forbidden, 5xx transient) fails the build with a loud diagnostic; only a 200 with empty open-state output passes.
3. Reference shape:

   ```bash
   # just ci recipe: verify-secrets
   response="$(gh api -i /repos/{owner}/{repo}/secret-scanning/alerts)"
   status="$(printf '%s\n' "$response" | head -1 | awk '{print $2}')"
   if [ "$status" != "200" ]; then
     echo "::error::secret-scanning API returned $status (expected 200); check permissions.security-events: read"
     exit 1
   fi
   open="$(printf '%s\n' "$response" | sed '1,/^$/d' | jq '[.[] | select(.state=="open")] | length')"
   if [ "$open" != "0" ]; then
     echo "::error::$open open secret-scanning alert(s); rotate the credential then resolve before merge"
     exit 1
   fi
   ```

Any open alert fails the build. This is a backstop: if Layer 1 missed it AND Layer 2 did not auto-block (e.g., a new pattern not yet in the host's catalog), the CI query catches it before merge.

**Closed-alerts gap (acknowledged behavior, not a fix).** The query filters on open state; alerts auto-closed on key revocation (or manually closed) will not fail the build. The secret can still be present in repo history for the rotation window. The recovery rule is the anchor here: rotate the credential, do not merely rewrite history. This is acknowledged behavior — alert state is a workflow-progress signal, not a residual-risk signal.

## Alternatives Considered

- **An entropy-based scanner (gitleaks) as Layer 1.** Rejected for v1 on simplicity grounds (no new tool to install/maintain). **Trip-wire:** if any incident slips through all three layers, switch Layer 1 to an entropy-based scanner. It is a single-binary, low-add-cost fallback, preserved as a path.
- **trufflehog.** Same rejection rationale; the entropy-based single-binary is the lighter-touch fallback if one is needed.
- **A paid advanced-security subscription for entropy-based scanning and non-provider patterns.** Rejected for v1. All current repos are public, so the free tier covers the provider-pattern catalog. Revisit if a private repo enters scope or if entropy-based detection becomes valuable (e.g., custom org secret formats).
- **Pre-commit only (no CI query).** Rejected. Pre-commit relies on every contributor having the hook configured locally; the CI query is the deterministic backstop.
- **CI query only (no pre-commit).** Rejected. The CI query catches the secret after it is in branch history; pre-commit catches it before. The local hook is the cheap first line.

## Consequences

- **Per-repo retrofit:** a hook-config update, host repo settings (secret scanning, push protection), and the `verify-secrets` recipe. Part of the merge-mode migration runbook (G-0008-adjacent).
- **The shared regex lives in one place;** updates ripple to all repos. The regex is conservative (favors false negatives over false positives) — false positives in commit-msg hooks degrade dev velocity fast.
- **Layer 2 enablement requires per-repo settings changes.** Listed in the retrofit runbook.
- **Local-only repos** must migrate to a host before Layers 2 and 3 apply. Until migrated, they have only Layer 1. Acceptable given their local-only state, and named in the retrofit runbook.
- **Private-repo case** (none today; possible later): the advanced-security subscription cost versus an entropy-scanner fallback is evaluated at that point. Not a v1 concern.
- **Image-vuln scanning** is out of scope for this ADR; flagged at G-0005 if it becomes a need (a scanner would attach to the registry image-publish job).
- **Cross-tool cost:** zero new tools (the hook manager is already present; the host CLI is in CI). Aligned with the simplicity posture.
- **Detection latency:** Layer 1 is milliseconds (commit time); Layer 2 is seconds (push time); Layer 3 is minutes (CI run). The earlier the layer, the cheaper the remediation.
- **Layer 1 is best-effort, not a security boundary.** A `--no-verify` commit skips the local hooks entirely; this is by design (a developer-velocity aid). Layer 2 (host-native push protection) is the structural defense at the trust boundary — it runs server-side and cannot be bypassed by a local flag. Layer 3 (the CI query) is the deterministic backstop that runs regardless of local hook state. Treat Layer 1 as a velocity aid that catches easy mistakes early; rely on Layers 2 and 3 for the security guarantee.
