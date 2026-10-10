# Phase 1 implementation and verification status

**Verified in this environment (Linux Swift 6.2 toolchain)**
- `swift test` on `Packages/StreamLabCore`: 7 / 7 tests passed, 0 failures.
- Fixture count: exactly 2,000 JSON records.
- `StreamLabDomain` and `StreamLabCatalogData` compiled in Swift language mode 6.
- SwiftUI source passed syntax parse only (`swiftc -frontend -parse`).

**Not verified here**
- Full iOS build and run (Xcode and iOS simulator are not available in this Linux environment).
- XcodeGen project generation on macOS.
- Accessibility on a physical iOS device.
- SwiftUI lifecycle when navigating rapidly and cancelling view tasks.
- Instruments, memory, frame time, TTFF; playback is outside Phase 1.

**Known limitations**
- Continue Watching demo progress lives as canned `profileId`-scoped data; it is not yet persisted or synced.
- Art uses offline SF Symbols and gradients, not network images; network image lazy loading remains a later A1 item.
- Search and UI cancellation have not been instrumented or tested on an Apple simulator.
- `offset:` cursor is a test-only pagination scheme, not production cursor security protocol; use opaque server cursors in future.
- No video playback or downloads are implemented.

**Next Mac command**

```bash
./scripts/bootstrap-mac.sh
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Update this report with the real Xcode version, simulator device, build result and failure logs before marking Phase 1 complete.

## 화면별 폴더 분리 업데이트

사용자 요청에 따라 AppDelegate/SceneDelegate, Home/Search/Detail 컨트롤러, Theme/PosterCell/RailHeader를 개별 파일과 폴더로 분리했습니다. 프로필/홈/검색/상세 Storyboard도 네 파일로 분리해 각 화면 컨트롤러 옆에 배치했습니다. SwiftPM resources 선언과 Bundle.module 로딩, Xcode 소스 참조, 구조 검사 스크립트를 함께 갱신했습니다.

폴더 분리 후 Fixture 및 정적 구조 검사는 PASS입니다. 기존 및 추가 Swift 테스트 소스는 변경하지 않았습니다. 실제 Xcode/Swift 테스트와 Storyboard 리소스 컴파일은 NOT TESTED이며, 기존 Phase 1 검증 보류 상태는 유지합니다.

## Black-screen startup investigation — 2026-10-10

User reports a black Simulator screen with Xcode 27.0 (27A266a), Apple Swift 6.4, iPhone 18 Pro / iOS 27.0. This is a user-reported runtime failure, not a verified successful launch. The exact cause cannot be established from a screenshot without startup logs.

Startup previously relied on generated scene metadata. Added an explicit App/Configuration/Info.plist with a named UIWindowScene configuration and module-qualified SceneDelegate; disabled automatic Info.plist generation for the app in both project.yml and the checked-in project. The scene now explicitly sizes and retains its window, eagerly loads the profile root and restores a missing root upon scene reconnection. Normal foregrounding preserves navigation.

OSLog category Startup records: application launched; requested scene configuration; scene will connect; loading Profile.storyboard; profile root installed; window is visible. No profile identifiers or content history are logged. These markers distinguish scene registration from Storyboard loading failures.

Added cold launch / relaunch UI coverage (UI suite now 5 tests). Static plist/wiring checks: PASS. Xcode build, five UI tests, and resolution on the user's simulator: NOT TESTED. No claim that the screenshot's root cause has been reproduced or the black screen resolved.

After pulling the fix, quit and relaunch the app. If the old scene configuration is restored, delete only the StreamLab demo app from the simulator and run again (deletes its local demo state). If still black, collect all Startup messages and the first runtime exception from Xcode's debug console.

## Storyboard controller lookup crash — 2026-10-11

FAIL (user Simulator log): application and scene callbacks run, then Profile.storyboard lookup raises NSInvalidArgumentException: no controller with identifier Profiles. This supersedes the earlier unconfirmed scene-registration hypothesis for this observed crash.

The source has the matching storyboardIdentifier, but all four scene controllers omit sceneMemberID="viewController". Added this scene membership to Profile, Home, Search and Detail without changing controller identifiers, modules or outlets. Strengthened structural checks for scene membership and initial controller identity. The previous structural checks missed this omission.

PASS: corrected XML and structural checks; regression check rejects each original missing-membership storyboard. NOT TESTED: ibtool compilation, iOS build, five UI tests and post-fix Simulator launch. The XML defect is corrected; runtime resolution still requires Mac verification. Rebuild with Product > Clean Build Folder before running to recompile Storyboard resources.

## Phase 1 navigation follow-up — 2026-10-11

PASS (user-supplied evidence, not agent-run): after d9d1dc2, iPhone 18 Pro / iOS 27.0 screenshot shows Alex, Jamie and Kids. Startup logs reach profile root installed and window is visible with no supplied Storyboard exception. This verifies the observed first-screen launch only, not all flows or warning-free compilation.

Home/Search/Detail now suspend offscreen requests with cancellation and generation invalidation while retaining loaded data. Returning resumes an interrupted request; completed search pages, cursor and query remain intact across detail navigation and tab changes. Profile switching and scene teardown still call invalidate to clear data and pending resumption. Detail retry is disabled while loading.

Added two Core lifecycle tests (Core total: 17) and a search-navigation UI regression (UI total: 6). Swift and Xcode executables are unavailable here: all new Swift tests, Simulator navigation, accessibility and compiler warnings remain NOT TESTED. Existing structural checks PASS. Phase 2 remains out of scope.
