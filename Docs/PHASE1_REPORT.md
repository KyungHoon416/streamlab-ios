# Phase 1 — SwiftUI 전환 보고서

2026-10-12 사용자 요청. UIKit 기준선 a2ecc89.
**SwiftUI 전환 후 첫 빌드 FAIL → 관찰 코드 수정 / 수정 후 빌드·iOS 실행 NOT TESTED / Phase 1 전체 완료 보류.**

## 변경

- SwiftUI App/WindowGroup 진입점. AppDelegate·SceneDelegate·4개 Storyboard/ViewController·UIKit 전용 셀/헤더 제거.
- 프로필, 홈, 검색, 상세: 검정·빨강 테마, 히어로, 5레일, 계속 시청, 페이지네이션, 중앙 HUD, 재시도, Phase 2 안내.
- Foundation Core/CatalogStore, 기존 17개 테스트와 2,000개 fixture 재사용. Core 수정은 설명 주석뿐.
- MainActor CatalogScreenModel(StateObject)와 약한 Store 레지스트리 CatalogSession. 이전 세션 동기 무효화 후 UUID로 UI 교체.
- 화면 이탈/scenePhase 비활성에서 suspend, 화면 표시/active에서 resume. 받은 페이지 유지.
- UI 11개 정의: 재실행, 안내, 검색/프로필, 페이지 보존, HUD, 요청 중 전환, 재시도, 20/60회 이동, 백그라운드 재개, 최대 글자 감사.
- UIKit 셀 수 대신 결과 수·접근성 ID로 lazy UI 검사.
- checked-in 프로젝트/scheme, Package 리소스, Info.plist, 구조 검사, 런타임 시작 마커 변경.
- ADR-0006 작성. ADR-0004는 역사적 결정으로 보관.

## 검증

| 항목 | 결과 | 범위 |
|---|---|---|
| Fixture | PASS | Python, 2,000 고유 ID·등급 |
| 구조 | PASS | 파일/참조/App 진입점/scene, 컴파일 대체 아님 |
| 프로젝트 파서 | PASS | 새 소스 기대값 포함 2개 |
| Shell syntax | PASS | Mac 스크립트 문법 |
| Core gate (정의 17개) | PASS | 사용자 RESULTS(8).txt: core exit=0; 개별 테스트 로그 미첨부 |
| SwiftUI 최초 빌드 | FAIL | e9dfba1, simulator-build exit=65, ConformanceIsolation |
| 수정 후 빌드·경고 | NOT TESTED | 이 호스트 Xcode 없음; Mac 재실행 필요 |
| UI 11개 | NOT TESTED | Simulator 없음 |
| VoiceOver·Dynamic Type·기기 | NOT TESTED | 새 검사 필요 |
| Release·런타임 glassEffect | NOT TESTED | 새 로그 필요 |
| Instruments·프레임 타임 | NOT TESTED | UIKit 수치 전용하지 않음 |

## 남은 범위

Mac에서 ./scripts/verify-mac.sh && ./scripts/check-runtime-mac.sh 실행 후 RESULTS.txt와 environment.txt 확인.
새 [수동 QA](PHASE1_MANUAL_QA.md)·Instruments 필요.
원격 이미지 로더는 설계만 있고 미구현이며, 로컬 아트/Lazy UI를 전체 구현으로 간주하지 않는다.
실제 재생/저장/다운로드·전체 ADR/상태도/카오스는 후속 범위다. 이번 변경은 Phase 2 구현이 아니다.
[UIKit 보관 보고서](Archive/UIKIT_PHASE1_REPORT.md)는 새 UI 정상 동작이나 경고 제거 근거가 아니다.

## 2026-10-12 사용자 빌드 로그와 수정

증거: RESULTS(8).txt, environment(3).txt, simulator-build(2).log. 실행 폴더 20261012T002524Z-CK5RYs, 커밋 e9dfba1d89cbc6edac91c5ab57c9b019b2d74986, Xcode 27.0(27A266a), Swift 6.4.

Fixture, project-structure, bootstrap, generated-project-structure, Core는 PASS. Simulator 빌드는 arm64/x86_64 모두 CatalogScreenModel의 명시적 objectWillChange가 ObservableObject의 nonisolated 요구사항과 충돌하여 FAIL(exit=65). UI와 warning-free는 실행되지 않아 NOT TESTED.

CatalogScreenModel의 직접 publisher 선언/전송을 제거하고 @Published private revision으로 Core 변경을 전달한다. MainActor 상태 변경과 weak self 콜백을 유지한다. README와 ADR-0006을 함께 갱신했다. 오류를 숨기는 설정 변경은 없다. 수정 후 실제 컴파일·화면 갱신은 verify-mac.sh와 check-runtime-mac.sh로 확인해야 한다.
