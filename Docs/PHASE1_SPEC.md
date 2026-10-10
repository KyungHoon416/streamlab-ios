# Phase 1 requirements / acceptance criteria

Source: user's `Netflix_iOS_과제.docx`, page 1 (iOS 18+, Swift 6), page 2 A1 (3 profiles, 2,000 titles, 5 rails, search, cursor paging, deduplication, lazy loading, stale request cancellation), page 3 B3 (profile-scoped responses), page 6 (mockable modules, tests, README).

| ID | Requirement | Implementation | Phase 1 check |
|---|---|---|---|
| P1-01 | iOS 18+ SwiftUI / Swift 6 | `project.yml`, Package manifests | Xcode build on Mac: PENDING |
| P1-02 | 3 profiles, 2 adults / 1 child | `ViewerProfile.demo` | Unit + iOS UI manual |
| P1-03 | 2,000 fixture items | `Resources/catalog.json` | Auto test PASSED |
| P1-04 | 5 home rails, hero | `MockCatalogRepository.home`, `HomeView` | Repo test PASSED; UI manual PENDING |
| P1-05 | Continue Watching data per profile | Profile scoped demo progress | Repo test PASSED |
| P1-06 | Kid visibility and details guard | `canView`, `detail` restrictions | Auto test PASSED |
| P1-07 | Search and results | `SearchViewModel`, `SearchView` | SwiftUI smoke: PENDING |
| P1-08 | Cursor pagination and deduplication | `browse`, `search`, `loadNext` | Repo test PASSED |
| P1-09 | Image lazy loading | `LazyHStack` for artwork (no network images yet) | Remote image lazy loading deferred |
| P1-10 | Stale search requests discarded | cancellation + request generation | Concurrency UI scenario: PENDING |
| P1-11 | Dependencies injectable/mockable | `CatalogRepository` protocol | Compile check for core PASSED |
| P1-12 | README and initial ADRs | Docs folder | Included |

Important: The original challenge requires **actual image lazy loading** and performance measurements in later work. Phase 1 provides generated local artwork with lazy view construction, not network image lazy loading. This is an explicit gap, not falsely reported as complete.

### Manual tests to perform on macOS
1. Select Kids → browse/search: only `ALL` and `7+` titles appear.
2. Kids → profile switch → Adult A → Continue Watching changes.
3. Enter search term, replace immediately, repeat 20x; old results never replace the new query.
4. Open a detail and navigate back; home/search remains available.
5. Open the first and 60th browse pages using a unit test: IDs unique.
6. Switch the profile during a simulated 120ms `home` wait; old content does not appear.
7. Swift 6 complete mode produces no concurrency diagnostics.
8. Validate compact iPhone and iPad layouts, VoiceOver, Dynamic Type.
