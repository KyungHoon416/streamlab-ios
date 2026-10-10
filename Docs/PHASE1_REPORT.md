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
