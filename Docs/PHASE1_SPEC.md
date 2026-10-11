# Phase 1 requirements / acceptance criteria

Current implementation: Swift 6 / iOS 18+, UIKit + four editable Storyboards.
The user's explicit UIKit request supersedes the initial SwiftUI requirement (ADR-0004).
UICollectionView/UITableView cell reuse replaces LazyHStack/LazyVStack.

Verification baseline: app commit 114d734, Mac build evidence supplied 2026-10-12 KST.
PASS on an earlier suite is historical evidence, not a claim of a fresh run.

| ID | Requirement | Implementation / evidence | Status |
|---|---|---|---|
| P1-01 | Swift 6 strict concurrency, iOS app | project.yml; RESULTS(6), build exit 0, warning count 0 | PASS: supplied Mac Debug Simulator build |
| P1-02 | Three profiles | ViewerProfile.demo; earlier UI launch/profile tests | PASS: earlier UI suite |
| P1-03 | 2,000 unique titles | catalog.json; validate-fixtures.py rerun | PASS |
| P1-04 | Hero, five rails, Continue Watching | HomeViewController; repository rail/progress tests | PASS: earlier Core suite; full visual review limited |
| P1-05 | Profile isolation | repository policy; CatalogStore.select/invalidate, generation and profile checks | PASS: earlier deterministic Core suite |
| P1-06 | Kids listing/direct-detail restriction | MockCatalogRepository; kidsNeverSeeAdultTitlesEvenByDirectId | PASS: earlier Core suite; user Kids route confirmation |
| P1-07 | Search, response reversal protection | CatalogStore; reversedSearchResponseCannotOverwriteLatest | PASS: earlier Core suite |
| P1-08 | Cursor pagination, deduplication | repository/store paging tests; user pagination confirmation | PASS: earlier tests + manual report |
| P1-09 | Reused cells / image-loader proposal | UICollectionView, UITableView; ADR-0005 | PASS: source review/proposal only; no remote image implementation |
| P1-10 | Rapid exit, cancellation, stale completion | Core lifecycle tests; earlier rapid navigation UI test | PASS: earlier suites; latest UI rerun NOT TESTED |
| P1-11 | Injectable/mockable modules | CatalogRepository, controlled continuations, SwiftPM | PASS: source review + earlier Core execution |
| P1-12 | Accessibility | historical automated audit; manual detail playback confirmation | NOT TESTED: full VoiceOver, max-text HUD, latest retry layout |
| P1-13 | Runtime/performance | user reports immediate detail, no freeze/flicker | NOT TESTED: full Instruments; glassEffect initially once remains unresolved |
| P1-14 | Latest UI regression | 9 UI test methods including detail retry | NOT TESTED: current 9-test suite |
| P1-15 | Docs / reproducible validation | README, report, manual checklist, verify-mac.sh | PASS: local review; Mac execution of updated verifier pending |

Overall acceptance: **NOT TESTED (incomplete), not all PASS**.
Before Phase 2: run the current automated gate, finish manual accessibility/layout/memory checks, and resolve or explicitly accept the initial runtime warning with rationale. Build-only PASS does not verify runtime diagnostics.

The broader challenge's actual remote image loading and performance targets must not be described as implemented. Phase 1 currently uses local generated artwork and provides a future loader design.
