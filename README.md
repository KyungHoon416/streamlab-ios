# StreamLab — Phase 1 iOS Starter

> Unofficial learning/portfolio project. Not a Netflix recruiting task, product, API client, or affiliated project.

This repository is a **Swift 6 / iOS 18+** UIKit + Storyboard streaming app with a portable, fully offline fixture repository. It implements **Phase 1 only** (profiles + catalog + discovery). It does **not** stream actual video yet.

## What works in Phase 1

- Three profiles (`Alex`, `Jamie`, `Kids`); changing profiles rebuilds feature UI.
- Exactly **2,000 deterministic** original/sample metadata items in bundled `catalog.json`.
- Profile-scoped five content rails and profile-scoped sample Continue Watching.
- Kids entitlement filter enforced at **repository** boundary, including direct `detail()` lookup.
- Cursor paging with no duplicated IDs, strict page-size validation and invalid cursor rejection.
- Search debouncing, cancellation and generation checks for out-of-order results.
- Offline poster artwork rendered via UIKit (no unauthorized image downloads).
- Accessible buttons, labels, dynamic text; dark mode first.
- Core Swift Testing suite: seven repository tests and ten state/race tests; eight UI tests (execution status: `Docs/PHASE1_REPORT.md`).

## Requirements

- Mac with a recent stable Xcode version that supports **Swift 6 + iOS 18 SDK**.
- iOS 18+ simulator or device.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to turn `project.yml` into an Xcode project.
- Homebrew recommended for installation, optional if XcodeGen already installed.

## First run on Mac

```bash
# unzip and enter the StreamLab-Phase1 directory
xcode-select -p
xcodebuild -version
brew install xcodegen
./scripts/bootstrap-mac.sh
open StreamLab.xcodeproj
```

In Xcode choose the **StreamLab** scheme and an iPhone simulator; press **Cmd+R**.

Command-line build (simulator):

```bash
xcodebuild \
  -project StreamLab.xcodeproj \
  -scheme StreamLab \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

If device signing fails, replace demo bundle ID and select your development team in Xcode. `project.yml` contains a placeholder `com.example.streamlab.demo` ID.

## Fast portable core tests

```bash
cd Packages/StreamLabCore
swift test
```

The `StreamLabCore` package uses only Foundation and Swift Testing, allowing its unit tests to run without UIKit, SwiftUI, or a simulator.

## Module boundaries

```text
App (UIKit + Storyboard, XcodeGen)
  |-- StreamLabProfileFeature --> StreamLabDesignSystem --> StreamLabDomain
  |-- StreamLabCatalogFeature --> StreamLabDesignSystem --> StreamLabDomain
  |-- StreamLabCatalogData -------------------------------> StreamLabDomain
```

- `StreamLabDomain`: `Sendable` entities, profile policy, pagination models, and the repository protocol.
- `StreamLabCatalogData`: actor-based deterministic offline fixture repository.
- `StreamLabDesignSystem`: static gradients/poster illustrations, reusable poster cards.
- `StreamLabProfileFeature`: select Adult A / Adult B / Kids.
- `StreamLabCatalogFeature`: Home, Search and Detail with cancellation-sensitive state.
- `App`: UIKit app, explicit scene registration, dependency composition and profile session.

No external packages are used in SwiftPM; `XcodeGen` is a Mac-side **project generator**, not a runtime dependency.

## Product flow

1. Launch → select Alex/Jamie/Kids.
2. Home → hero, five rails, per-profile Continue Watching.
3. Tap card → Detail, playback button explicitly explains Phase 2.
4. Search tab → type quickly; old requests must not overwrite latest.
5. Tap profile toolbar button to switch; old feature state is discarded.

## Phase boundary (not built yet)

- Real HLS/AVPlayer playback and player state machine
- Persistent user progress, server-revision sync, offline mutation queue
- Auth, Keychain, 401/409/429 handling, DRM mock
- HLS Download + cache quota and recovery
- Instruments performance measurements and ten chaos scenarios

Do not represent placeholders as implemented. README proof and risk notes: `Docs/PHASE1_REPORT.md`.

## Important scope and licensing

The content titles/metadata are programmatically fabricated and posters are local SF Symbols and gradients. No Netflix media, logos or APIs are bundled. There are no backend calls and no networking requirement to browse fixtures. The next phase can use legally licensed public test HLS URLs with licensing documented.

## Suggested commit sequence

1. `chore: bootstrap iOS app and Swift packages`
2. `feat: add domain types and 2000 deterministic fixtures`
3. `feat: implement profile, home, search and detail`
4. `test: verify catalog paging and profile authorization`
5. `docs: add ADRs and Phase 1 validation report`

## 화면별 폴더 구성

기능별로 컨트롤러와 Storyboard를 같은 폴더에 배치했습니다. 각 Storyboard는 해당 SwiftPM 모듈의 리소스로 등록되며, `instantiate()`가 `Bundle.module`에서 로드합니다.

| 폴더 | 내용 |
|---|---|
| App/Application | AppDelegate.swift |
| App/Configuration | Info.plist — 명시적 SceneDelegate 등록 |
| App/Scene | SceneDelegate.swift — 프로필 세션·화면 전환 |
| Packages/StreamLabUI/Sources/StreamLabProfileFeature/Profile | ProfileViewController.swift + Profile.storyboard |
| Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Home | HomeViewController.swift + Home.storyboard |
| Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Search | SearchViewController.swift + Search.storyboard |
| Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Detail | DetailViewController.swift + Detail.storyboard |
| Packages/StreamLabUI/Sources/StreamLabDesignSystem/Theme | 공통 색상·폰트·버튼 스타일 |
| Packages/StreamLabUI/Sources/StreamLabDesignSystem/Cells | PosterCell.swift |
| Packages/StreamLabUI/Sources/StreamLabDesignSystem/Headers | RailHeader.swift |
| Packages/StreamLabCore/Sources/StreamLabDomain/Models | 데이터 모델·Repository 계약 |
| Packages/StreamLabCore/Sources/StreamLabCatalogData/Repositories | MockCatalogRepository.swift |
| Packages/StreamLabCore/Sources/StreamLabCatalogData/Resources | catalog.json, 2,000개 원본 Fixture |
| Packages/StreamLabCore/Sources/StreamLabPresentation/Stores | CatalogStore.swift |
| Packages/StreamLabCore/Tests | Repository·상태 관리 테스트 |
| Tests/StreamLabUITests | UI 테스트 |
| Docs | 사양·설계 결정·변경 목록·검증 보고서 |
| scripts | 프로젝트 생성·검증 스크립트 |

Xcode의 Package Dependencies에서 로컬 패키지를 펼치면 화면 폴더를 확인할 수 있습니다. Finder의 실제 디렉터리도 동일하게 분리했습니다. 폴더 재구성 후의 SwiftPM 리소스 컴파일/Storyboard 로딩은 아직 Mac에서 검증하지 않았습니다.

GitHub 저장소: https://github.com/KyungHoon416/streamlab-ios

## 검은 시작 화면 진단

`App/Configuration/Info.plist`가 SceneDelegate를 명시적으로 등록합니다. 업데이트 후 `./scripts/bootstrap-mac.sh`로 프로젝트를 생성하고 Xcode에서 실행을 중지한 뒤 다시 실행하세요. 계속 검은 화면이면 Debug Console의 `[Startup]` 로그와 첫 예외 메시지를 공유해 주세요. 로그는 앱 시작 → Scene 연결 → Profile.storyboard 로드 → 루트 화면 설치 → 창 표시 순서입니다.

이 변경의 설정·XML 정적 검사는 수행했지만, Xcode 빌드와 Simulator 실행은 이 Linux 환경에서 **NOT TESTED**입니다. 실제 실행 성공을 의미하지 않습니다.


### Profiles 식별자 조회 크래시 수정 (2026-10-11)

`Profile.storyboard` 로딩 중 `doesn't contain a view controller with identifier 'Profiles'`가 발생한 실행 로그를 확인했습니다. 네 Storyboard의 누락된 `sceneMemberID="viewController"` 속성을 추가하고 정적 검사를 보강했습니다. 업데이트 후 Xcode의 **Product > Clean Build Folder**를 실행하고 다시 Run하여 Storyboard 리소스를 재컴파일하세요. 수정 후 Simulator 실행은 아직 NOT TESTED입니다.

### 탐색 상태 유지

같은 프로필에서 상세 화면을 다녀오거나 홈/검색 탭을 전환해도 완료된 검색 결과와 페이지 수를 유지합니다. 화면 이탈 시 진행 중 요청은 취소하고, 복귀 시 중단된 요청을 재개합니다. 프로필 변경 시에는 이전 프로필 데이터와 재개할 요청을 모두 비웁니다.

2026-10-11 사용자 Simulator 캡처·로그로 프로필 첫 화면 표시를 확인했습니다. 홈·검색·상세 전환과 자동 테스트는 별도 실행 검증이 필요합니다.

## Phase 1.1 — 검증 및 안정화

중앙 로딩 동작은 사용자 수동 확인 PASS입니다. 이번 버전은 홈 탭 이름을 고정하고, 중앙 로딩 표시 및 로딩 중 프로필 전환 UI 테스트를 추가합니다. Core 17개 / UI 8개는 테스트 소스 개수이며, 실행 성공 개수가 아닙니다.

Mac에서 프로젝트 루트에서 실행하세요:

```bash
./scripts/verify-mac.sh
```

실행별 `Docs/Validation/<실행 ID>/`에 `RESULTS.txt`, 명령별 로그, 환경·커밋 정보, 빌드 및 UI 테스트 `.xcresult`를 저장합니다. 검사 종료 코드를 기록하며 미실행 항목은 NOT TESTED로 표시합니다. 기본적으로 실행 중인 iPhone Simulator를 우선 선택합니다. 특정 기기는 `SIMULATOR_ID=<UDID> ./scripts/verify-mac.sh`로 지정하세요. 스크립트는 XcodeGen으로 프로젝트를 다시 생성하므로 별도 프로젝트 설정 변경은 project.yml에 반영하세요.

UI 테스트의 `--ui-test-slow-catalog` 인수는 DEBUG 빌드에서만 Mock 응답을 2초로 늦춰 로딩 상태를 관찰하게 합니다. 일반 실행과 Release 응답 속도는 변경하지 않습니다. 실제 플레이어 개발은 Phase 1 검증 결과와 미해결 항목을 정리한 뒤 진행합니다.

### Xcode 27 / Swift 6.4 validation follow-up (2026-10-11)

The supplied Mac RESULTS.txt at 59d5cd2 reports simulator-build and ui-tests PASS, but project-structure and core FAIL. The structure checker now resolves XcodeGen group-relative paths and build-phase membership instead of matching serialized strings. The Core lifetime test now uses a weak capture probe to avoid Swift 6.4's never-mutated local weak-variable diagnostic; warnings-as-errors remain enabled. Run `git pull --ff-only origin main` then `./scripts/verify-mac.sh` again. The verifier also checks the regenerated project after bootstrap. Post-fix Apple tests remain NOT TESTED until that run; results are under `Docs/Validation/<timestamp>-<suffix>/RESULTS.txt`.

Latest supplied Mac evidence (5bc2bae, 2026-10-11 17:19 KST): project structure before/after XcodeGen PASS; Simulator build PASS; UI tests 8/8 PASS. Core is blocked at code signing by extended attributes on generated test bundles; Core execution is not yet verified. See `Docs/PHASE1_REPORT.md` for targeted recovery. Manual VoiceOver, Instruments and remaining build-tool warnings are still open.

Core follow-up (2026-10-11 18:07 KST): supplied `core-fresh.log` confirms **17/17 Swift Testing tests PASS, exit 0**, with no compiler warnings shown in the fresh build. Together with the earlier **8/8 UI tests PASS**, the recorded automated suites now pass across separate runs. `verify-mac.sh` now uses a unique `/private/tmp/streamlab-core.*` directory for Core build products and records that path in `environment.txt`; the directory is retained for diagnosis. Manual VoiceOver, Instruments and the app-build App Intents warning remain open. No immediate repeat of the already-passing suites is required for this documentation/script change.

Remaining Phase 1 manual checks: see [VoiceOver, Dynamic Type and Instruments procedure](Docs/PHASE1_MANUAL_QA.md). Run `./scripts/check-build-warnings-mac.sh` only when investigating the remaining app-build warning; it records build success separately from warning-free status and does not repeat UI tests. Reports are in `Docs/Validation/warnings-*/`.
