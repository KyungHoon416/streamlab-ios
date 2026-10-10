# ADR-0001 — SwiftPM modules and repository contracts

Status: Accepted (Phase 1)

**Context:** The assignment requires replaceable network, storage and player layers under Swift 6 concurrency.

**Decision:** StreamLabDomain defines Sendable entities and CatalogRepository; StreamLabCatalogData implements an actor-based fixture repository; feature targets depend on protocols rather than concrete data implementations. App composes dependencies.

**Consequence:** Local core can be tested independently of iOS, while player and sync engines can be added later.
