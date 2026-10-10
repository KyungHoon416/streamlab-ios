# ADR-0002 — Filter at repository boundary and invalidate old UI tree

Status: Accepted for Phase 1

Context: Kids profiles must never see adult titles or another profile's playback progress. Filtering only at the view layer leaks information through detail lookups and old asynchronous results.

Decision: Every catalog query receives a `ViewerProfile`. The repository checks content rating for both listing and direct lookups. On profile switch, the app sets the selection back to nil, and feature tabs are keyed by profile ID. Home resets stale data before new results arrive.

Consequences: Type-level guarantee is not sufficient for eventual backend API; network requests must also carry server-authorized profile context. Phase 1 uses a deterministic mock only.
