---
title: "G-0016: Layered Secret Detection — Pre-Commit + GitHub-Native + Stage 5 Alerts Query"
summary: "Three-layer defense: lefthook regex at pre-commit, GitHub-native push protection continuously, Stage 5 verify-secrets recipe as deterministic backstop."
primary-audience: agent
---

# G-0016: Layered Secret Detection — Pre-Commit + GitHub-Native + Stage 5 Alerts Query

**Status:** Accepted
**Date:** 2026-04-30

## Context

Secret-detection gate addition was identified as a per-repo concern. The question: which detection mechanism, where in the workflow, and at what cost?

Three layers of opportunity exist:
- **Pre-commit (Stage 2):** catch secrets before they enter local history.
- **Server-side push protection / scanning (continuous):** catch what slipped past local hooks at push time and continuously after.
- **Stage 5 (`just ci`):** explicit fail-the-build query for any open secret-scanning alert.

Verification confirmed all current GitHub-hosted workspace repos are PUBLIC — GitHub Advanced Security (GHAS) subscription not required for native secret-scanning + push protection. Local-only repos need GitHub migration as an execution-stage prereq, and default to public unless flagged otherwise.

An initial proposal suggested lefthook regex + GitHub-native + Stage 5 query as the simplest defense in depth. gitleaks (entropy-based + custom patterns) was a richer alternative, rejected for v1 on simplicity grounds.

**External-PR contributors are out of scope for v1.** All in-scope repos restrict PR creation to collaborators. Fork-PR posture (pull_request_target vs pull_request semantics, secrets-from-forks exclusion, first-time-contributor approval gate) is revisited only if a future external-contributor scenario arises — at which point this ADR and G-0015 / G-0020 are amended together.

## Decision

**Three layers, each with a distinct trigger and tool. All three apply per in-scope repo.**

### Layer 1 — Pre-commit (Stage 2)

`lefthook` `commit-msg` and `pre-commit` hooks running a workspace-shared narrow regex covering common patterns:

| Pattern class | Example trigger |
|---------------|-----------------|
| AWS access key | `AKIA[0-9A-Z]{16}` |
| GitHub PAT | `ghp_[A-Za-z0-9]{36}`, `gho_...`, `ghs_...`, `ghr_...` |
| Common API token prefixes | `sk_live_`, `sk_test_`, `xoxb-`, `xoxp-` |
| JWT signature | `eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` |
| Private-key headers | `-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----` |

Workspace-shared regex lives at `skills/secret-detection-regex.md` (or per repo /spec template). Per-repo lefthook config references it.

### Layer 2 — GitHub-native (continuous, always-on)

For every in-scope GitHub-hosted repo:
- `secret_scanning` enabled (free for public repos, GHAS-required for private)
- `secret_scanning_push_protection` enabled (same applicability)

These run continuously without per-repo CI configuration. Push protection blocks pushes containing detected provider secrets at the GitHub edge.

### Layer 3 — Stage 5 (`just ci`)

`just ci` includes a `verify-secrets` recipe that queries the secret-scanning alerts API. Recipe spec:

1. The calling GHA job MUST declare `permissions.security-events: read`. Without it, the token has no scope to read alerts and the API returns 404 (indistinguishable from "no alerts" in a naive `--jq` invocation).
2. The recipe MUST use `gh api -i` and check the response status explicitly. Non-200 (404 disabled, 403 forbidden, 5xx transient) fails the build with a loud diagnostic; only a 200 with empty `state=open` filtered output passes.
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
     echo "::error::$open open secret-scanning alert(s); rotate per R10c then resolve before merge"
     exit 1
   fi
   ```

Any open alert fails the build. This is a backstop: if Layer 1 missed it AND Layer 2 didn't auto-block (e.g., a new pattern not yet in GitHub's catalog), Stage 5 catches it before merge.

**Closed-alerts gap (acknowledged behavior, not a fix).** The query filters on `state=open`; alerts auto-closed by GitHub on key revocation (or manually closed) won't fail the build. The secret can still be present in repo history for the rotation window. Recovery rule R10c is the operator's anchor here: rotate the credential, don't merely rewrite history.

## Alternatives Considered

- **gitleaks (entropy-based + custom patterns).** Rejected for v1 on simplicity grounds (no new tool to install/maintain). **Trip-wire:** if any incident slips through Layers 1+2+3, switch Layer 1 from lefthook regex to gitleaks. gitleaks is a Go single-binary, low add-cost; preserved as a fallback path.
- **trufflehog.** Same rejection rationale as gitleaks; gitleaks is the lighter-touch fallback if needed.
- **GHAS subscription for entropy-based scanning + non-provider patterns.** Rejected for v1. All current repos are public, so the free tier covers the provider-pattern catalog. Revisit if a private repo enters scope.
- **Pre-commit-only (no Stage 5 query).** Rejected. Pre-commit relies on every contributor having lefthook configured locally; Stage 5 is the deterministic backstop.
- **Stage 5-only (no pre-commit).** Rejected. Stage 5 catches the secret after it's in branch history; pre-commit catches it before. The local hook is the cheap first line.

## Consequences

- **Per-repo retrofit:** lefthook config update + workflow setting changes (`secret_scanning`, `secret_scanning_push_protection`) + `verify-secrets` recipe addition. Deployment specialist dispatch per repo as part of merge-mode migration runbook.
- **Workspace-shared regex** lives in one place; updates ripple to all repos via /spec retrofit. Regex is conservative (favors false negatives over false positives) — false positives in commit-msg hooks degrade dev velocity fast.
- **Layer 2 enablement requires `gh api -X PATCH` calls** per repo. Listed in the retrofit runbook.
- **Local-only repos** must migrate to GitHub before Layer 2 + Layer 3 apply. Until migrated, they have only Layer 1. This is acceptable given their local-only state and is named in the retrofit runbook.
- **Private-repo case** (none today; possible later): GHAS subscription cost vs gitleaks fallback evaluated at that point. Not a v1 concern.
- **Image-vuln scanning** is out of scope for this ADR; flagged at G-0015 if it becomes a need (Trivy or similar would attach to the GHCR image-publish job).
- **Cross-tool cost:** zero new tools (lefthook already in workspace; `gh` CLI in CI). Aligned with simplicity anchor.
- **Detection latency:** Layer 1 ≈ ms (commit time); Layer 2 ≈ seconds (push time); Layer 3 ≈ minutes (CI run). The earlier the layer, the cheaper the remediation.
- **Layer 1 is best-effort, not a security boundary.** `git commit --no-verify` skips lefthook entirely; this is by design (developer velocity aid). Layer 2 (GitHub-native push protection) is the structural defense at the trust boundary — it runs on the server side and can't be bypassed by a local flag. Layer 3 (Stage 5 query) is the deterministic backstop that runs in CI regardless of local hook state.

## Changelog

### 2026-04-30 — Round 1 review amendments

- **Updated:** Layer 3 (`verify-secrets`) recipe spec — requires `permissions.security-events: read` on the calling job; uses `gh api -i` with explicit response-status check; fails loudly on non-200 to differentiate "no alerts" from "API forbidden / disabled". Added a reference shell shape.
- **Added:** Consequence stating Layer 1 is best-effort (locally bypassable via `--no-verify`); Layer 2 is the structural defense; Layer 3 is the deterministic backstop.
- **Added:** Explicit out-of-scope statement — external-PR contributors are out of scope for v1; in-scope repos restrict PR creation to collaborators.
- **Added:** Note acknowledging the closed-alerts gap — `state=open` filter means alerts auto-closed by GitHub won't fail the build; recovery rule R10c (rotate, don't rewrite history) is the operator anchor.
- **Cross-reference:** Workspace skill `skills/secret-detection-regex.md` is the canonical home for the Layer 1 regex patterns.
