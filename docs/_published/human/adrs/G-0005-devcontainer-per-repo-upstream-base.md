---
title: "G-0005: Devcontainer Architecture — Per-Repo Upstream FROM + Registry Push"
summary: "Each repo owns its devcontainer, built FROM an upstream language-native base, SHA-pinned, with every layered binary version-pinned; the repo's own CI builds and pushes the image to a container registry on devcontainer changes, and CI runs inside the pulled image for local-vs-CI parity. No shared base image."
primary-audience: agent
---

# G-0005: Devcontainer Architecture — Per-Repo Upstream FROM + Registry Push

**Status:** Accepted
**Date:** 2026-04-30

## Context

G-0002 fixed `just ci` as the CI contract and named devcontainer integration as adjacent, deferred to a follow-up ADR. This is that follow-up.

The image-strategy question had three live options:

- **A shared base image:** one centrally-built image that per-repo Dockerfiles `FROM`. Lowest per-repo work; couples every repo to a central image-publish pipeline.
- **Per-repo, `FROM` an upstream language-native base:** each repo owns its devcontainer and pulls e.g. `mcr.microsoft.com/devcontainers/rust` directly. Highest per-repo independence; no central pipeline.
- **Per-repo, `FROM` centrally-built thin language bases** (a rust-base, python-base, ts-base layer): a middle ground where the shared layer owns thin language bases.

Simplicity and the goal of a self-owning multi-repo polyglot model point to per-repo independence: each repo should own its environment without depending on a central build pipeline that may not persist as tooling consolidates.

## Decision

**Per-repo devcontainer, `FROM` an upstream language-native base, built and pushed to a container registry by the repo's own CI workflow on `devcontainer.json` / `Dockerfile` change, SHA-pinned in the repo.** No centrally-built shared base image.

Concrete shape per Rust repo:

```dockerfile
# .devcontainer/Dockerfile
FROM mcr.microsoft.com/devcontainers/rust:dev-1-bookworm@sha256:<digest>
# repo-specific tooling layered after — pin EACH binary by version
RUN cargo install --locked --version <X.Y.Z> release-plz \
 && cargo install --locked --version <X.Y.Z> cargo-audit
# ... other repo-specific layers
```

**Note on the upstream tag.** The upstream Rust devcontainer tags follow the **devcontainer-image** version scheme (e.g., `dev-1-bookworm`, `1.0.27-bookworm`, `latest`), NOT the Rust-toolchain version. Pin a specific Rust toolchain **inside the per-repo Dockerfile**, with `rust-toolchain.toml` as the canonical place (or a `rustup toolchain install <ver>` line if a Dockerfile-side install is required). Do not attempt to encode the Rust toolchain in the `FROM` tag; those tags do not exist upstream.

**Layered binary pinning is mandatory.** Every `cargo install` line in a devcontainer Dockerfile MUST pass both `--locked` and `--version <X.Y.Z>`. `--locked` protects against transitive churn for that install invocation; `--version` pins the top-level binary, closing the supply-chain window where a future patch release of a tool could be baked into a privileged-context image. The devcontainer is pushed to a registry and pulled by every CI run that handles registry and repository tokens. A dependency scanner's Dockerfile parser tracks pinned `cargo install --version` lines; the per-repo dependency-scan config MUST include Dockerfile pattern coverage so binary-version bumps surface as PRs. Stretch goal once tools ship signed release artifacts: switch to `cargo binstall` with checksum verification.

```jsonc
// .devcontainer/devcontainer.json
{
  "name": "<repo-name>-dev",
  "build": { "dockerfile": "Dockerfile" },
  "features": { /* devcontainer features as needed */ }
}
```

The repo's CI workflow includes a job that, on changes to `.devcontainer/**`, builds the image and pushes it to the registry under `<owner>/<repo>-devcontainer:<git-sha>` plus `:latest`. CI runs (`just ci`) execute inside this image (pulled, not rebuilt) so local-vs-CI parity holds.

**SHA-pinning is mandatory** for the upstream `FROM` line. Tag-only references (`:1.86-bookworm` without `@sha256:...`) drift silently when the upstream refreshes the tag.

**Polyglot repos** layer additional language bases in their own Dockerfile (e.g., a repo with Rust + Python adds `apt-get install python3` or layers a Python base image). No shared polyglot base.

## Alternatives Considered

- **A centrally-built shared base image.** Rejected. It requires a central image-publish pipeline with no clear owner, couples repo CI cycles to a central artifact, and does not survive tooling consolidation. Each repo owning its own image is forward-compatible.
- **Per-repo `FROM` centrally-built thin language bases.** Rejected. Same central-pipeline dependency at smaller scale; the upstream devcontainer images already provide the thin language base.
- **No devcontainer; rely on the host environment.** Rejected. It defeats the local-vs-CI parity goal G-0002 was designed around.
- **Build-on-demand without a registry push.** Rejected. Pulling and rebuilding per CI run wastes time and bandwidth; pushing the built image to the registry makes CI a pull-only operation.
- **Tag-only upstream references (no SHA pin).** Rejected. Upstream tag drift is a silent supply-chain risk; SHA-pinning is cheap insurance, and upstream image refreshes become deliberate dependency-bump PRs.

## Consequences

- **Per-repo CI workflow includes a devcontainer-publish job.** Triggered on a `.devcontainer/**` path filter. A workspace template ships this workflow. Required permissions on the calling job: `contents: read, packages: write, id-token: write, attestations: write` (packages:write for the registry push, id-token:write and attestations:write for OIDC-based provenance attestations). The workflow logs in to the registry, sets up buildx, and builds/pushes. **Multi-arch posture:** the SHA pin targets the upstream multi-arch manifest list; per-repo builds run amd64-only by default. An arm64 build matrix is added per-repo when an arm64 contributor or runner enters scope, not a default, to avoid doubling build cost without demand.
- **Registry retention is bounded by a template retention workflow, opt-in by default.** The template ships a retention workflow with a keep-last-10 policy on the `<repo>-devcontainer` package. Repos opt out (e.g., a long-lived archival need); the default keeps registry storage bounded without per-repo manual cleanup.
- **Upstream image refresh follows the upstream cadence.** SHA-pinning means refreshes are explicit PRs. The dependency scanner is configured to monitor the `FROM` line per G-0006 (supply-chain hygiene).
- **Registry storage cost is per-repo.** Each devcontainer image lives under `<owner>/<repo>-devcontainer`. Old SHAs accumulate; a per-repo retention policy is a per-repo concern, not canon.
- **Polyglot needs are repo-local.** A repo needing Rust + Python adds layers in its own Dockerfile. No central coordination required.
- **The CI pilot picks up this ADR:** its devcontainer Dockerfile uses the upstream Rust base plus a SHA pin, and its CI workflow publishes to the registry.
- **Retrofit cost per repo:** roughly one PR: `.devcontainer/Dockerfile`, `devcontainer.json`, the publish workflow, and a dependency-scan config update.
- **Local developer experience:** `devcontainer up` pulls from the registry (cached after the first pull); rebuilds happen only on `.devcontainer/**` changes. Faster than rebuild-on-every-open.
- **No shared base means no central image-publish pipeline to maintain.** Zero central infrastructure debt for this concern.
