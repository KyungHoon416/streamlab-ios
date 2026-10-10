# ADR-0002 — Profile isolation

Status: Accepted (Phase 1)

**Context:** Kids must not see adult titles or other profiles' viewing progress.

**Decision:** Every repository query is profile scoped, including direct detail lookup. Changing profiles recreates the feature tab tree and discards previous Home results.

**Consequence:** Backend authorization and session expiry must later be tested separately; Phase 1 uses only a deterministic mock.
