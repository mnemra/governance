---
title: "G-0025: Internal IPC Uses Typed Binary Encoding by Default; JSON for Stored State and External Surfaces"
summary: "Typed binary encoding (Protocol Buffers or FlatBuffers) for internal IPC; JSON reserved for stored state, user-visible APIs, and cross-trust-domain surfaces."
primary-audience: agent
---

# G-0025: Internal IPC Uses Typed Binary Encoding by Default; JSON for Stored State and External Surfaces

**Status:** Accepted
**Date:** 2026-05-04

## Context

Default toolchain conventions push systems toward JSON-everywhere on internal boundaries. Extism's Rust PDK uses `Json<T>` as the path of least resistance, hyper-mcp's host-fn registration is `Json<T>` end to end, and the JSON-RPC shape of MCP leaks one boundary further inward than it needs to. JSON's value is introspectability, tooling, and human-readable diffs. Those properties attach to surfaces that are persisted, user-facing, or cross trust domains. None of them pay off on a host↔plugin or service↔service path where both ends control the contract. There the marshalling cost is the entire price, with no value returned.

This architecture decision record (ADR) was triggered by the mnemra plugin runtime architecture work. The internal-boundary wire-format choice surfaced as a real architectural fork. It generalizes beyond mnemra: every project with multiple components communicating in-process or across plugin boundaries faces the same call.

## Decision

Internal IPC defaults to a typed binary encoding (Protocol Buffers or FlatBuffers). JSON is reserved for stored state and external surfaces.

**Internal** means: both endpoints under the same project/team's control, payload is not persisted as the canonical record, and the boundary does not cross a trust domain. Examples: host↔plugin host-fn calls, plugin↔plugin via mediated `plugins.invoke`, in-process service↔service calls when crossing a process or sandbox boundary, internal RPC between services in the same deployment.

**External / stored** means: user-visible APIs, persisted records (DB columns, files, event tables), cross-trust-domain protocols (third-party APIs, public webhooks, MCP-on-the-wire), or surfaces where introspectability is itself the value (config files, logs, debugging tools). JSON remains the right answer here.

Choice between Protocol Buffers and FlatBuffers is per-use-case: protobuf for typical request/response with cross-language tooling depth; flatbuffers for read-heavy zero-copy / mmap-able payloads. Pick per shape. Both are acceptable defaults under this ADR.

## Alternatives Considered

**JSON everywhere.** The current default of most ecosystems on the stack (MCP, hyper-mcp, Extism PDK). Rejected: marshalling cost has no offsetting value on internal boundaries; encoding-level schema enforcement is stronger than JSON-schema-as-discipline (which drifts silently); typed contracts are clearer at the boundary itself.

**Component Model + WIT typed-native passing.** On WASM Component Model targets, this eliminates encoding entirely. Values cross the boundary with no marshalling. Considered as the truly-cleanest path on WASM substrates. Not chosen as the universal default because (a) it's only available on Component Model targets, not in-process service↔service or subprocess IPC; (b) toolchain maturity in 2026 is still uneven across non-Rust PDKs. Where applicable, CM is the preferred encoding-free alternative. This ADR does not preclude a project from choosing it over typed binary.

**Custom encodings (msgpack, cbor, raw structs).** Rejected as default: they lose the schema-level versioning and cross-language codegen tooling that protobuf and flatbuffers provide. Ad-hoc encodings re-introduce the drift surface this ADR removes.

**FlatBuffers exclusively.** Considered. Rejected as the universal default: protobuf has broader language support and better ergonomics for typical request/response shapes. FlatBuffers wins for read-heavy zero-copy / mmap-friendly payloads but isn't a fit for everything.

## Consequences

**Positive:**
- Marshalling tax removed from hot internal paths.
- Schema-as-contract enforced at the encoding layer: typed deserialization fails loudly, where JSON-schema-as-discipline drifts silently.
- Multi-language plugin / service authoring gets typed contracts at the wire format, not only at the application layer.
- Boundary classification (internal vs. external/stored) becomes an explicit design step rather than a default that gets entrenched by toolchain convention.

**Negative / accepted:**
- Plugin authors and service authors learn one more tool (protobuf or flatbuffers schemas + codegen).
- Debugging needs a decoder (`protoc --decode`, `flatc`, `grpcurl`, and similar) instead of `cat` for JSON. Build a story for this in projects with non-trivial IPC volume.
- Schema repositories and codegen pipelines become build-time concerns for any project that hits the internal-IPC threshold.
- The classification is a judgment call at the margin. A boundary that *might* one day be persisted or exposed externally is awkward. Default to the actual current shape, document the rationale, and migrate if the boundary changes character.

**Project-level guidance:**
- A project may legitimately stay JSON-only at V0 when internal IPC volume is low and codegen overhead exceeds the marshalling cost being paid. Record a project-level ADR override (a `P-*.md` decision record in the project's own repo) citing G-0025 with the V0 cost-benefit rationale.
- Mnemra's V0 internal wire-format choice inherits from this ADR. The mnemra-side ADR will reference G-0025.
