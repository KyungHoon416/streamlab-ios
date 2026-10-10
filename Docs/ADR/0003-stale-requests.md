# ADR-0003 — Cancel and fence stale requests

Status: Accepted (Phase 1)

**Context:** Search requests can return in a different order than they were issued.

**Decision:** SearchViewModel cancels earlier tasks and uses monotonically increasing generation counters. Only matching generations may update current UI. Home uses a similar check.

**Consequence:** Race conditions must still be exercised on the Apple simulator with injected delays and deterministic tests.
