# Phase 1 acceptance criteria

Reference: User-provided unofficial Netflix engineering challenge, page 1-2, 3 and 6.

| ID | Requirement | Implementation | Verification |
|---|---|---|---|
| P1-01 | Swift 6, iOS 18+, SwiftUI | project.yml and Swift packages | iOS build: NOT TESTED here |
| P1-02 | Three profiles, two adults and one child | ViewerProfile.demo | Core type declarations |
| P1-03 | 2,000 Mock titles | catalog.json | Fixture/test definitions |
| P1-04 | Hero and five recommendation rails | HomeView, MockCatalogRepository | Simulator pending |
| P1-05 | Continue Watching per profile | Demo progress seeds | Core test included |
| P1-06 | Kids content guard | CatalogRepository.detail and filtering | Core test included |
| P1-07 | Search | SearchViewModel and SearchView | Simulator pending |
| P1-08 | Cursor pagination and deduplication | browse/search/loadNext | Core test included |
| P1-09 | Image lazy loading | Local symbol posters and lazy UI lists | Remote image loading deferred |
| P1-10 | Stale search cancelled | Task cancellation and generation | Race test pending |
| P1-11 | Mockable dependencies | CatalogRepository protocol | Swift 6 Core target |
| P1-12 | Engineering docs | README, ADRs, status report | Included |

Phase 2: AVPlayer/HLS streaming, session state machine, QoE, playback failure recovery. Later phases: sync, authentication and HLS downloading.
