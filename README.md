# StreamLab — SwiftUI Phase 1

비공식 학습·포트폴리오 프로젝트입니다. Netflix 공식 채용 과제나 제품이 아닙니다.

**Swift 6 / iOS 18+ / SwiftUI** 오프라인 카탈로그 앱입니다. 원문 Netflix_iOS_과제.docx의 SwiftUI 조건에 맞춰 2026-10-12 UIKit 버전을 전환했습니다. 실제 AVPlayer 재생·동기화·다운로드는 Phase 2 이후이며 현재 재생 버튼은 “Phase 2 예정” 안내를 표시합니다.

## 현재 상태

- 구현: 프로필 3개, 히어로, 추천 레일 5개, 계속 시청, 검색, 상세, 커서 페이지네이션, 중앙 로딩.
- Core의 2,000개 fixture, Repository 수준 키즈 등급 제한, 요청 세대·프로필·취소 검사를 재사용합니다.
- 최신 사용자 Mac 결과: Fixture·구조·bootstrap·Core·Simulator 빌드·빌드 경고 검사 **PASS**.
- UI 테스트 **7 PASS / 4 FAIL**: 검색 행 탐색 3개, 검색창 최대 글자 잘림 1개. 검색 접근성·레이아웃을 수정했으며 **수정 후 빌드/UI 재검증은 NOT TESTED**입니다.
- UIKit PASS는 새 UI의 PASS가 아닙니다. [현재 보고서](Docs/PHASE1_REPORT.md)와 [이력](Docs/Archive/UIKIT_PHASE1_REPORT.md)을 구분합니다.
- **Phase 1 전체 완료 판정 보류**, Phase 2는 시작하지 않았습니다.

## 실행 및 검증

Mac, Swift 6 / iOS 18 SDK를 지원하는 Xcode와 XcodeGen이 필요합니다. 사용자 환경은 Xcode 27.0 / Swift 6.4입니다. 변경을 작성한 호스트에는 Xcode·Swift가 없습니다.

    brew install xcodegen
    ./scripts/bootstrap-mac.sh
    open StreamLab.xcodeproj

StreamLab scheme과 iPhone Simulator를 선택해 실행합니다. SwiftUI @main App → WindowGroup으로 시작하며 Storyboard/SceneDelegate가 없습니다. XcodeGen이 없으면 위 첫 명령으로 설치합니다.

전체 자동 검증:

    ./scripts/verify-mac.sh

Fixture → 구조 검사 → XcodeGen → 생성 프로젝트 검사 → Core 17개 → Simulator 빌드 → UI 11개 → 빌드 경고 검사 순서입니다. **개수는 소스 정의 수이며 현재 통과 수가 아닙니다.** 출력되는 Docs/Validation/.../RESULTS.txt 및 environment.txt를 보관하세요. UI 실패는 같은 폴더의 ui-tests.log / UITests.xcresult에서 확인합니다.

Release 및 런타임 회귀:

    ./scripts/check-runtime-mac.sh

새 Release 제품으로 상세 ↔ 홈 60회, 20/40/60회 스크린샷, 앱 로그와 glassEffect 진단을 수집합니다. **UI 반복은 누수 측정이 아닙니다.** 로그 수집 실패나 선택 테스트 미실행은 PASS로 처리하지 않습니다.

특정 Simulator는 SIMULATOR_ID=<UDID> 환경변수로 선택합니다. Debug에서만 --ui-test-slow-catalog 인자를 넣으면 Mock 응답을 4초로 늦춰 HUD·취소를 확인할 수 있습니다. 검사 뒤 제거하세요.

업데이트가 로컬 생성 프로젝트 변경으로 막히면 git status와 diff를 먼저 확인합니다. 소스를 일괄 discard하지 않습니다. 생성된 파일만 백업하려면:

    git stash push -m "Backup generated Xcode project before SwiftUI migration" -- StreamLab.xcodeproj/project.pbxproj StreamLab.xcodeproj/xcshareddata/xcschemes/StreamLab.xcscheme
    git pull --ff-only --no-rebase origin main
    ./scripts/bootstrap-mac.sh

이전 UIKit 프로젝트 설정을 새 프로젝트에 그대로 stash pop하지 말고 필요한 개인 설정만 확인해서 옮기세요.

## 폴더 구조

- App/Application/StreamLabApp.swift: SwiftUI 진입점.
- App/Scene/AppRootView.swift: 프로필, 세션 교체, 탭, NavigationStack.
- Packages/StreamLabUI/Sources/StreamLabProfileFeature/Profile/: 프로필.
- Packages/StreamLabUI/Sources/StreamLabCatalogFeature/: Home, Search, Detail, State.
- Packages/StreamLabUI/Sources/StreamLabDesignSystem/Theme/: 테마, 포스터, 버튼, HUD.
- Packages/StreamLabCore/: Domain, actor MockRepository, MainActor CatalogStore, fixture, 테스트.
- Tests/StreamLabUITests/: 화면·프로필·페이지·접근성·백그라운드·반복 이동.
- Docs/ADR/: 설계 결정. [ADR-0006](Docs/ADR/0006-swiftui-migration.md)이 UIKit ADR-0004를 대체합니다.

## 상태와 수명주기

화면마다 @StateObject CatalogScreenModel을 소유합니다. 어댑터가 Foundation 기반 CatalogStore의 변경을 SwiftUI에 전달합니다. Core는 SwiftUI/Combine에 의존하지 않습니다.

선택마다 새 UUID의 CatalogSession을 만듭니다. 프로필 전환 시 이전 세션의 살아 있는 Store를 먼저 동기적으로 무효화하고, .id(session.id)로 탐색 경로·검색어·화면을 새로 만듭니다. 세션 레지스트리는 Store를 약하게 참조합니다.

onDisappear/비활성 scenePhase에서 요청을 중단합니다. 현재 화면만 active 복귀 시 재개하며 받은 검색 페이지·커서는 유지합니다. 상세 조회도 Repository 권한 검사를 거칩니다.

## 남은 범위

- 포스터는 SF Symbols와 로컬 그라데이션. 네트워크 이미지 로더는 [ADR-0005](Docs/ADR/0005-image-loader-design.md)의 제안이며 미구현입니다.
- 계속 시청은 샘플 진도이며 영속 저장/멀티디바이스 동기화는 미구현입니다.
- 실제 재생, Player/Download 상태 머신, DRM Mock, 인증, 오프라인 큐, 카오스 전체는 이후 범위입니다.
- 전체 과제의 필수 ADR: 충돌 처리 / 플레이어 수명주기 / 다운로드 캐시 정책은 후속 단계에서 작성합니다. 현재 문서 개수만으로 전체 산출물 완료라고 보지 않습니다.
- SwiftUI VoiceOver, 최대 글자, Reduce Motion, 작은 iPhone/iPad, 런타임, Instruments를 다시 확인합니다. [수동 QA](Docs/PHASE1_MANUAL_QA.md).
