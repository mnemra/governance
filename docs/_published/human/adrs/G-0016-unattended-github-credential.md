---
title: "G-0016: Unattended Host Access via a GitHub App + Password-Manager Service Account"
summary: "Unattended, sleep-surviving host access splits into two independently-decided layers: identity (a GitHub App minting 1-hour installation tokens) and secret serving (a read-only, single-vault password-manager service account serving the App key headlessly). The only option that is non-interactive, minimal-blast-radius, PR/merge-capable, and multi-repo."
primary-audience: agent
---

# G-0016: Unattended Host Access via a GitHub App + Password-Manager Service Account

**Status:** Accepted
**Date:** 2026-06-27

## Context and Problem Statement

Unattended agent runs (overnight, "finish it," and the autonomous push→PR→merge loop) authenticate to the host over SSH using a key served by an interactive password manager's **SSH agent**. That agent is suspended when the machine sleeps and expires on session timeout, exactly when an unattended run needs it. The symptom (`Permission denied (publickey)` / `sign_and_send_pubkey: signing failed`) is the single most common halt for unattended push/merge runs: 27 of the last 30 days. Keeping the machine awake and pause-and-surface are band-aids, not a fix.

The requirement is a credential an **unattended, sleep-surviving, no-human-present** runner can use to clone/fetch/push **and** open/merge PRs, with a **small, revocable blast radius**. This credential is the missing piece that lets the autonomous push→PR→merge loop in [G-0003 merge-governance](G-0003-merge-governance.md) actually run unattended.

The problem splits into two independent layers, each decided separately:

- **Layer A, host identity:** what the host trusts to allow a push or PR.
- **Layer B, secret serving:** how that secret reaches a headless runner non-interactively (surviving sleep, no fingerprint/biometric prompt).

## Decision Drivers

- **Unattended + sleep-surviving + no human present.** No fingerprint/biometric/password unlock anywhere in the path (that is exactly what the SSH-agent path failed).
- **Smallest practical blast radius.** Scoped, short-lived, revocable; narrower than an account-wide SSH key.
- **PR open + merge via API** (not git-only) across a **multi-repo setup spanning a personal account and a separate organization**.
- **Low cost / low operational friction.** This is personal automation, not a product; avoid a new paid account if possible.
- Avoiding the maintainer's *personal* credentials is a **nice-to-have tiebreaker**, not a hard constraint.

## Considered Options

**Layer A (host identity):**

1. **A GitHub App + short-lived installation tokens:** a non-personal app identity; 1-hour tokens; per-repo and per-permission scope.
2. **A personal fine-grained token (HTTPS):** scoped, but a standing secret that acts as the maintainer.
3. **A machine user + fine-grained token:** clean attribution, but a second account to defend; the host steers away from this pattern.
4. **Per-repo deploy keys:** git-only (no PR API), plaintext-on-disk by default, N-key sprawl at multi-repo scale.
5. **Status quo: a personal SSH key in the password-manager agent:** account-wide scope; suspends on sleep (the problem).

**Layer B (secret serving):**

1. **A password-manager service account:** a non-interactive service-account token; read-only; a single dedicated vault.
2. **Local stores:** OS keychain, a `chmod 600` file, an encrypted file (fallbacks).

## Decision Outcome

**Chosen. Layer A: one GitHub App with short-lived installation tokens. Layer B: a password-manager service account serving the App's private key.** This is the only option that satisfies every driver: non-interactive and sleep-safe, two-tier minimal blast radius (a protected long-lived root plus an ephemeral scoped operational token), PR/merge-capable, multi-repo, and free on the existing plan.

Concrete shape:

- **One GitHub App**, owned by the maintainer's **personal account**, with visibility set to **public**. Public is *required* because the App must install on both the personal account and a separate organization; a **private** personal App can only install on the owning account. Public changes only *who can discover/install* it; it does **not** expose the private key, and other installers grant the App access to *their* repos only.
- Installed on the personal account and the **organization** (the org install is approved by the org owner, the org's own control point). One App means **one private key**; two installations, each minting its own installation token (routed by repo owner).
- Tokens are **1-hour installation access tokens**, minted at run-start and **re-minted on expiry** for long runs. The local runner mints via a **JWT signed with the App private key** (the hosted Actions helper does not apply to a local runner). Least-privilege permissions: `contents: write` (clone/fetch/push), `pull_requests: write` (open/merge), `metadata: read`; add others only if a loop touches them. The exact set is pinned at implementation.
- **Layer B, a password-manager service account** on the existing family plan. Confirmed available at no new account, email, or cost. The service account is **read-only**, scoped to a **single dedicated vault** (service accounts cannot read the built-in personal vaults). The vault holds the App private key as an item. The runner sets the service-account token and reads the key at run-start. This is **fully headless**: the token is a self-contained JWT carrying all cryptographic material client-side, so the read works on a waking machine with no desktop app, biometric, or interactive unlock, which is precisely what fixes the sleep-suspension halt.
- **Bootstrap-token storage** (the service-account token, "secret zero"): the OS **keychain**, ACL-scoped to the CLI binary, on a **full-disk-encrypted** disk. A `chmod 600` file is the fallback if keychain-after-sleep proves finicky. **Never** the global process environment (process-wide readable). (A dedicated non-admin OS service user was considered and **not** adopted: on a single-user machine, the keychain item's ACL bound to the CLI binary already provides binary-level access control, so a separate OS user is redundant.)
- **Rotation: 90 days**, with a 24-hour grace overlap on rotation; immediate revoke on suspicion.

**One App ⇒ one personal-owned key ⇒ one service account + one vault.** The organization is an install *target* (a host-side concern), not a reason for a second password-manager account. A second service account would be needed only if a separate organization account later held *other* secrets.

### Consequences

**Good:**

- Unattended runs authenticate headless and survive sleep; this removes the 27/30-day halt and unblocks the [G-0003](G-0003-merge-governance.md) autonomous loop.
- Defense-in-depth, small blast radius: a read-only single-vault service account means a leaked bootstrap token reads one vault and nothing else; the App key mints only 1-hour scoped tokens; 90-day rotation, instant revoke, and an audit log on every read.
- Narrows host scope versus the account-wide SSH key (per-repo + per-permission).
- **Free** on the existing plan; no new account or email.
- Portable: if the runner later moves to a headless Linux box, the same credential works unchanged.

**Bad / Trade-offs:**

- The App private key and the service-account bootstrap token are **standing secrets the machine must self-read**, the irreducible floor for any unattended credential. Mitigated by full-disk encryption, least-privilege scope, 90-day rotation, and the [G-0006 layered-secret-detection](G-0006-layered-secret-detection.md) guard ensuring neither is ever committed.
- The App is **public** (discoverable and installable by others on *their own* repos, harmless; simply do not advertise the install URL).
- A small **mint step** (JWT → installation token, with re-mint on 1-hour expiry) must be written for the local runner, work the hosted Actions helper would otherwise do.

## Pros and Cons of the Options

### Layer A — Option 1: GitHub App + installation tokens (chosen)

- Pro: an ephemeral 1-hour operational token plus a protected long-lived root is the smallest blast radius; finest scope; clean non-personal attribution; PR/merge-capable; multi-repo via two installations.
- Con: the most setup; the local runner must mint via JWT; the App key is still a standing secret (well-protected in the vault); the App must be public to span both accounts.

### Layer A — Option 2: Personal fine-grained token

- Pro: the lowest setup; scoped (repo + permission); instantly revocable; PR/merge-capable.
- Con: a standing operational secret usable for its full remaining life if leaked; acts as the maintainer (muddied attribution).

### Layer A — Option 3: Machine user + fine-grained token

- Pro: clean (non-personal) attribution; a scoped token.
- Con: a second account to secure (login/2FA/session = a new phishable surface); a standing token; the host recommends Apps over machine users.

### Layer A — Option 4: Per-repo deploy keys

- Pro: the tightest per-credential scope (one repo).
- Con: git-only, no PR/API, which breaks the merge workflow; plaintext-on-disk by default; N-key management at multi-repo scale.

### Layer A — Option 5: Status quo SSH key in the password-manager agent

- Pro: already set up; the key is well-protected at rest.
- Con: account-wide scope; the agent suspends on sleep, the failure this ADR exists to fix.

### Layer B — Option 1: Password-manager service account (chosen)

- Pro: free on the existing plan; non-interactive and sleep-safe (a self-contained JWT); read-only single-vault scope; an audit log; instant revoke; a single trust root.
- Con: introduces a bootstrap token ("secret zero") that must be stored locally; the vault list is immutable after creation (rotate-and-replace to change scope).

### Layer B — Option 2: Local stores (keychain / file / encrypted file)

- Pro: no vendor account; the keychain encrypts at rest plus binary-ACL; a permissively-licensed encryptor is available.
- Con: no central audit or revocation; keychain-after-sleep is settings-dependent; encrypted files just shift the bootstrap problem, and some encryptors carry a license that needs approval. Retained as a fallback only.

## Amendments

### 2026-06-28 — Implementation language: Go (scoped internal-helper exception)

The original plan specified the credential helper as a Rust binary. **It is implemented in Go instead**, as a deliberate, scoped exception to the Rust default. Drivers:

- **No official password-manager Rust SDK exists.** The vendor ships official SDKs for Go, JS/TS, Python, and .NET, not Rust. The only Rust crate is unofficial and unsuitable for a credential helper. The Rust path would mean shelling out to the CLI as a subprocess.
- **The official Go SDK reads the key in-process**, which *drops* the CLI-on-PATH dependency the original plan assumed and avoids parsing CLI output, a cleaner dependency story for an unattended helper.
- JWT mint (RS256), the installation-token exchange, and the git-credential-helper protocol are equally clean in Go.

**Consequence:** the credential helper is no longer a candidate to graduate into the shared Rust CLI tooling; it stays a standalone internal tool. Non-secret config (the vault reference, the App ID, the owner→installation map) lives in a config file under the user config directory; the secret (the service-account token) stays in env (keychain). The pre-live security review and the rest of the process are language-agnostic and unchanged.

## More Information

- **Related, [G-0003 merge-governance](G-0003-merge-governance.md):** defines the autonomous push→PR→merge loop (the merge gate, one-PR-in-flight) that this credential enables to run unattended; G-0003 was blocked on the SSH-agent halt this ADR removes.
- **Related, [G-0006 layered-secret-detection](G-0006-layered-secret-detection.md):** the guard ensuring the App private key and the service-account bootstrap token are never committed.
- Implements the fix flagged in the unattended-run pre-check (the 27/30-day SSH-agent-suspend halt).
- Dependency note: the password-manager CLI is proprietary subscription software (part of the existing plan, not a new library dependency); the fallback encryptor's license is relevant only if the local fallback is ever adopted.
