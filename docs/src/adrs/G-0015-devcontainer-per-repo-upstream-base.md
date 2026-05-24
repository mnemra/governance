---
title: "G-0015: Devcontainer Architecture — Per-Repo Upstream FROM + GHCR Push"
summary: "Per-repo devcontainer FROM upstream language-native base (SHA-pinned); built and pushed to GHCR by repo's own CI; no workspace-shared base image."
primary-audience: agent
---

# G-0015: Devcontainer Architecture — Per-Repo Upstream FROM + GHCR Push

**Status:** Accepted
**Date:** 2026-04-30

## Context

G-0006 fixed `just ci` as the CI contract and named devcontainer integration as adjacent (deferred to a follow-up ADR). This is that follow-up.

The image-strategy question had three live options:

- **Workspace-shared base image:** one workspace-built image; per-repo Dockerfiles `FROM` it. Lowest per-repo work; couples repos to a workspace-side image-publish pipeline.
- **Per-repo, FROM upstream language-native base:** each repo owns its devcontainer; pulls e.g. `mcr.microsoft.com/devcontainers/rust` directly. Highest per-repo independence; no workspace-side pipeline.
- **Per-repo, FROM workspace-built rust-base + python-base + ts-base layered images:** middle ground; workspace owns thin language bases.

The QA anchor (simplicity) and the forward-compatibility requirement (multi-repo polyglot model wants each repo to own its environment without depending on a workspace-side build pipeline that may not exist after mnemra absorbs the workspace) both point to per-repo independence.

## Decision

**Per-repo devcontainer, `FROM` upstream language-native base, built and pushed to GHCR by the repo's own CI workflow on `devcontainer.json` / `Dockerfile` change, SHA-pinned in the repo.** No workspace-built shared base image.

Concrete shape per Rust repo:

```dockerfile
# .devcontainer/Dockerfile
FROM mcr.microsoft.com/devcontainers/rust:dev-1-bookworm@sha256:<digest>
# repo-specific tooling layered after — pin EACH binary by version
RUN cargo install --locked --version <X.Y.Z> release-plz \
 && cargo install --locked --version <X.Y.Z> cargo-audit
# ... other repo-specific layers
```

**Note on the upstream tag.** MCR's Rust devcontainer tags follow the **devcontainer-image** version scheme (e.g., `dev-1-bookworm`, `1.0.27-bookworm`, `latest`), NOT the Rust-toolchain version. Pinning a specific Rust toolchain version is done **inside the per-repo Dockerfile**, with `rust-toolchain.toml` as the canonical place (or `RUN rustup toolchain install <ver>` if a Dockerfile-side install is required). Do not attempt to encode the Rust toolchain in the `FROM` tag — those tags don't exist on MCR.

**Layered binary pinning is mandatory.** Every `cargo install` line in a devcontainer Dockerfile MUST pass both `--locked` and `--version <X.Y.Z>`. `--locked` protects against transitive churn for that install invocation; `--version` pins the top-level binary, closing the supply-chain window where a future patch release of a devcontainer tool could be baked into a privileged-context image. Dependabot's Dockerfile parser tracks pinned `cargo install --version` lines; the per-repo retrofit's Dependabot config MUST include Dockerfile pattern coverage so binary-version bumps surface as PRs. Stretch goal once ecosystem tools ship signed release artifacts: switch to `cargo binstall` with checksum verification.

```jsonc
// .devcontainer/devcontainer.json
{
  "name": "<repo-name>-dev",
  "build": { "dockerfile": "Dockerfile" },
  "features": { /* devcontainer features as needed */ }
}
```

The repo's CI workflow includes a job that, on changes to `.devcontainer/**`, builds the image and pushes to `ghcr.io/<owner>/<repo>-devcontainer:<git-sha>` plus `:latest`. CI runs (`just ci`) execute inside this image — pulled, not rebuilt — so local-vs-CI parity holds.

**SHA-pinning is mandatory** for the upstream `FROM` line. Tag-only references (`:1.86-bookworm` without `@sha256:...`) drift silently when the upstream refreshes the tag.

**Polyglot repos** layer additional language bases in their own Dockerfile (e.g., a repo with Rust + Python adds `apt-get install python3` or layers a Python base image). No workspace-shared polyglot base.

## Alternatives Considered

- **Workspace-built shared base image.** Rejected. Requires a workspace-side image-publish pipeline that has no current owner; couples repo CI cycles to a workspace artifact; doesn't survive mnemra absorption. Each repo owning its own image is forward-compatible with that absorption.
- **Per-repo FROM workspace-built thin language bases (rust-base, python-base, ts-base).** Rejected. Same workspace-pipeline-dependency problem at smaller scale; the upstream Microsoft devcontainer images already provide the thin language base.
- **No devcontainer; rely on host environment.** Rejected. Defeats the local-vs-CI parity goal G-0006 was designed around.
- **`devcontainers/cli` build-on-demand without GHCR push.** Rejected. Pulling and rebuilding per CI run wastes time + bandwidth; pushing the built image to GHCR makes CI a pull-only operation.
- **Tag-only upstream references (no SHA pin).** Rejected. Upstream tag drift is a silent supply-chain risk; SHA-pinning is the cheap insurance. Upstream image refreshes become deliberate Dependabot-style PRs.

## Consequences

- **Per-repo CI workflow includes a devcontainer-publish job.** Triggered on `.devcontainer/**` path filter. Workspace template ships this workflow YAML as `devcontainer-publish.yml`. Required permissions on the calling job: `contents: read, packages: write, id-token: write, attestations: write` (packages:write for GHCR push, id-token:write + attestations:write for OIDC-based provenance attestations). Workflow uses `docker/login-action` against `ghcr.io`, `docker/setup-buildx-action`, and `docker/build-push-action`. **Multi-arch posture:** SHA-pin targets the upstream manifest list (the multi-arch manifest); per-repo builds run on `ubuntu-latest` amd64 only by default. arm64 build matrix is added per-repo via /spec when an arm64 contributor / runner enters scope — not workspace-default to avoid 2x build cost without demand.
- **GHCR retention is bounded by a workspace-template retention workflow, opt-in by default.** Workspace template ships `.github/workflows/devcontainer-retention.yml` using `actions/delete-package-versions` with a keep-last-10 policy on the `<repo>-devcontainer` package. Repos opt out via /spec; the default keeps GHCR storage bounded without per-repo manual cleanup.
- **Upstream image refresh follows upstream cadence.** SHA-pinning means refreshes are explicit PRs. Dependabot is configured to monitor the `FROM` line per supply-chain hygiene principles.
- **GHCR storage cost is per-repo.** Each devcontainer image lives in `ghcr.io/<owner>/<repo>-devcontainer`. Old SHAs accumulate; per-repo retention policy is a per-repo /spec concern, not workspace canon.
- **Polyglot needs are repo-local.** A repo that needs Rust + Python adds layers in its own Dockerfile. No workspace coordination required.
- **Retrofit cost per repo:** ~1 PR — `.devcontainer/Dockerfile` + `devcontainer.json` + `.github/workflows/devcontainer.yml` + Dependabot config update. The deployment specialist role is the dispatch target per repo.
- **Local Developer Experience (DX):** `devcontainer up` from VS Code or CLI pulls from GHCR (cached after first pull); rebuilds only happen on `.devcontainer/**` changes. Faster than rebuild-on-every-open.
- **No workspace-shared base means no workspace-side image-publish pipeline to maintain.** Zero workspace infrastructure debt for this concern.

## Changelog

### 2026-04-30 — Round 1 review amendments

- **Fixed:** Replaced non-existent upstream example tag with correct MCR Rust devcontainer format. MCR's Rust devcontainer tags follow the devcontainer-image version scheme, not the Rust-toolchain version. Added a paragraph clarifying that Rust toolchain pinning is repo-controlled inside the Dockerfile (`rust-toolchain.toml` is canonical), not via the `FROM` tag.
- **Added:** Layered binary pinning requirement — every `cargo install` line in a devcontainer Dockerfile MUST pass `--locked --version <X.Y.Z>`. Dependabot Dockerfile pattern coverage required in per-repo retrofit. cargo-binstall + signed releases noted as a stretch goal once upstreams support it.
- **Added:** Consequence subsection naming the workspace-template `devcontainer-publish.yml` shape — required permissions and multi-arch posture (SHA-pin the manifest list; amd64-only default, arm64 per /spec).
- **Added:** Consequence naming the workspace-template GHCR retention workflow (`actions/delete-package-versions` keep-last-10, opt-in default).
