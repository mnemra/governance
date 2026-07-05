---
title: "G-0011: Internal IPC Uses Typed Binary Encoding by Default; JSON for Stored State and External Surfaces"
summary: "Internal boundaries (host↔plugin, service↔service under one team's control, non-persisted, non-trust-crossing) default to a typed binary encoding (Protocol Buffers or FlatBuffers); JSON is reserved for stored state, user-facing APIs, and cross-trust-domain protocols."
primary-audience: agent
---

# G-0011: Internal IPC Uses Typed Binary Encoding by Default; JSON for Stored State and External Surfaces

**Status:** Accepted
**Date:** 2026-05-04

## Context

Default toolchain conventions push systems toward JSON-everywhere on internal boundaries. Extism's Rust PDK (plugin development kit) uses `Json<T>` as the path of least resistance, host-function registration in the plugin runtime is `Json<T>` end to end, and the JSON-RPC shape of MCP (Model Context Protocol) leaks one boundary further inward than it needs to. JSON's value (introspectability, tooling, human-readable diffs) attaches to surfaces that are persisted, user-facing, or cross trust domains. None of those properties pay off on a host↔plugin or service↔service path where both ends control the contract; the marshalling cost is the entire price, with no value returned.

This decision was triggered by plugin-runtime architecture work in the mnemra ecosystem, but it generalizes: every project with multiple components communicating in-process or across plugin boundaries faces the same call.

## Decision

Internal IPC (inter-process communication) defaults to a typed binary encoding (Protocol Buffers or FlatBuffers). JSON is reserved for stored state and external surfaces.

**Internal** means: both endpoints are under the same project or team's control, the payload is not persisted as the canonical record, and the boundary does not cross a trust domain. Examples: host↔plugin host-function calls, plugin↔plugin via mediated invocation, in-process service↔service calls when crossing a process or sandbox boundary, internal RPC between services in the same deployment.

**External / stored** means: user-visible APIs, persisted records (DB columns, files, event tables), cross-trust-domain protocols (third-party APIs, public webhooks, MCP-on-the-wire), or surfaces where introspectability is itself the value (config files, logs, debugging tools). JSON remains the right answer here.

The choice between Protocol Buffers and FlatBuffers is per-use-case: protobuf for typical request/response with cross-language tooling depth; FlatBuffers for read-heavy zero-copy / mmap-able payloads. Pick per shape; both are acceptable defaults under this ADR.

## Alternatives Considered

**JSON everywhere.** The current default of most ecosystems on the stack (MCP, the plugin runtime PDK). Rejected: the marshalling cost has no offsetting value on internal boundaries; encoding-level schema enforcement is stronger than JSON-schema-as-discipline (which drifts silently); typed contracts are clearer at the boundary itself.

**Component Model + WIT typed-native passing.** On WASM Component Model targets, this eliminates encoding entirely; values cross the boundary with no marshalling. (WIT is WebAssembly Interface Types, the Component Model's interface-description language.) Considered as the truly cleanest path on WASM substrates. Not chosen as the universal default because (a) it is only available on Component Model targets, not in-process service↔service or subprocess IPC; and (b) toolchain maturity in 2026 is still uneven across non-Rust PDKs. Where applicable, the Component Model is the preferred encoding-free alternative; this ADR does not preclude a project from choosing it over typed binary.

**Custom encodings (msgpack, cbor, raw structs).** Rejected as the default: they lose the schema-level versioning and cross-language codegen tooling that protobuf and FlatBuffers provide. Ad-hoc encodings re-introduce the drift surface this ADR removes.

**FlatBuffers exclusively.** Considered. Rejected as the universal default: protobuf has broader language support and better ergonomics for typical request/response shapes. FlatBuffers wins for read-heavy zero-copy / mmap-friendly payloads but is not a fit for everything.

## Consequences

**Positive:**

- The marshalling tax is removed from hot internal paths.
- Schema-as-contract is enforced at the encoding layer; typed deserialization fails loudly, where JSON-schema-as-discipline drifts silently.
- Multi-language plugin and service authoring gets typed contracts at the wire format, not only at the application layer.
- Boundary classification (internal vs. external/stored) becomes an explicit design step rather than a default entrenched by toolchain convention.

**Negative / accepted:**

- Plugin authors and service authors learn one more tool (protobuf or FlatBuffers schemas + codegen).
- Debugging needs a decoder (`protoc --decode`, `flatc`, `grpcurl`, and the like) versus `cat` for JSON. Build a story for this in projects with non-trivial IPC volume.
- Schema repositories and codegen pipelines become build-time concerns for any project that hits the internal-IPC threshold.
- The classification is a judgment call at the margin. A boundary that *might* one day be persisted or exposed externally is awkward; default to the actual current shape, document the rationale, and migrate if the boundary changes character.

**Project-level guidance:**

- A project may legitimately stay JSON-only at V0 when internal IPC volume is low and codegen overhead exceeds the marshalling cost being paid. Record a project-level ADR override citing G-0011 with the V0 cost-benefit rationale.
- Mnemra's V0 internal wire-format choice inherits from this ADR; the mnemra-side ADR references G-0011.
