# Phase 1 — SwiftUI 전환 보고서

2026-10-12 사용자 요청. UIKit 기준선 a2ecc89.
**최신 자동 gate PASS / 사용자 수동 확인 반영 / Instruments 32바이트 원인 미확인·Debug glassEffect 재발 / Phase 1 전체 완료 보류.**

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

## 검색 접근성 수정 당시 검증 이력 (최신 결과는 아래 후속 검증 참조)

| 항목 | 결과 | 범위 |
|---|---|---|
| Fixture | PASS | Python, 2,000 고유 ID·등급 |
| 구조 | PASS | 파일/참조/App 진입점/scene, 컴파일 대체 아님 |
| 프로젝트 파서 | PASS | 새 소스 기대값 포함 2개 |
| Shell syntax | PASS | Mac 스크립트 문법 |
| Core gate (정의 17개) | PASS | 사용자 RESULTS(8).txt: core exit=0; 개별 테스트 로그 미첨부 |
| SwiftUI 최초 빌드 | FAIL | e9dfba1, simulator-build exit=65, ConformanceIsolation |
| 관찰 수정 후 빌드·경고 | PASS | 사용자 RESULTS(9).txt: simulator-build / warning-free exit=0 |
| 검색 접근성 수정 후 빌드·UI | NOT TESTED | 이번 변경은 Mac 재실행 필요 |
| UI 11개 | FAIL | ui-tests(2).log: 7 PASS, 4 FAIL, exit=65 |
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

## 검색 접근성 후속 수정 — RESULTS(9), ui-tests(2)

사용자 로그: 11개 실행, 4개 실패. 검색 결과 수 24/48 검사는 통과했으나 Button 타입으로 제한한 검색 행 쿼리가 0개를 반환하여 키즈 전환 2개와 상세/탭 페이지 보존 1개가 실패했다. 실제 AX 타입은 텍스트 로그에 없어 확정하지 않는다. NavigationLink의 자식 접근성을 combine하고 버튼 trait을 명시했으며, 테스트는 element type 대신 고유 ID로 탐색하고 존재를 기다린다. 키즈 행에 ALL/7+ 등급이 명시되는지 양방향으로 검사한다.

최대 글자 감사 실패는 검색 화면 catalog-search-field의 Text clipped로 보고되었다. 긴 안내를 줄바꿈 가능한 별도 Text로 옮기고 입력 placeholder를 검색어로 줄였다. 입력 높이는 폰트에 맞춰 확장하고 기존 접근성 이름을 유지한다. 감사 항목을 제외하거나 실패를 무시하지 않는다.

통과한 7개: 시작/재실행, SwiftUI 화면·Phase2 안내, 상세 재시도, 페이지 HUD, 백그라운드 페이지 재개, 상세 20회, 상세 60회. 마지막 테스트 이름에 Release가 있으나 이번 실행은 Debug UI 검증이므로 Release 런타임 또는 메모리 PASS로 해석하지 않는다. 이번 검색 수정 후 실제 Xcode 빌드·UI 테스트는 NOT TESTED다.


## 2026-10-12 후속 검증 및 진단 보완

| 항목 | 결과 | 근거와 범위 |
|---|---|---|
| 자동 gate | PASS | RESULTS(20261012-013429).txt: fixtures, structure, bootstrap, Core, simulator-build, UI, warning-free 모두 exit=0. SHA/개별 테스트 개수는 파일에 없음 |
| Release 60회 이동 | PASS | RESULTS(10).txt: test-observed=True, build warnings=0, 수집된 구간 glass 진단 없음 |
| 최대 Dynamic Type | PASS | 사용자 캡처/확인: 홈·검색·상세 글자 및 스크롤, Phase 2 안내, 중앙 HUD. 감사 전체와 동일 범위라는 뜻은 아님 |
| VoiceOver | PASS | 사용자 확인: 프로필·홈·검색·상세 낭독과 두 번 탭 동작 |
| 작은 iPhone/iPad | PASS | iPhone SE 3 iOS 18.0 및 iPad Air 11 M4 iPadOS 27.0 캡처와 사용자 확인 범위. 실기기 검증 아님 |
| Allocations 객체 수명 | PASS | 홈→상세→뒤로 반복 후 CatalogStore 640B/1 persistent/21 transient, CatalogScreenModel 80B/1 persistent/21 transient. 전체 누수 판정 아님 |
| Release Instruments 누수 0건 기준 | FAIL | 1:19 기록 시작 검사에 Malloc 32 Bytes 1개. 이후 확인한 회색 검사 tooltip No new leaks. 최초 원인 미확인 |
| Debug Memory Graph 누수 필터 | PASS | 별도 실행에서 사용자 보고상 목록 없음. Malloc stack logging 미활성. Release의 32B 해결 증거 아님 |
| 수동 Debug 런타임 경고 없음 기준 | FAIL | 15:27 KST 콘솔 glassEffect 재발. 15:32 사용자 확인: UI 이상은 없고 콘솔에만 표시. 과거 Release PASS를 취소하지 않지만 전체 경고 없음으로 일반화 불가 |
| 프로필 전환 누적·40/60회 Allocations·frame time·실기기 | NOT TESTED | 이번 제출에서 해당 계측 증거 없음 |
| 새 메모리 Scheme·Debug 자동 런타임 실행 | NOT TESTED | 작성 호스트 Linux, Xcode/Swift 없음. Mac 실행 필요 |

### 코드 검토

AppRootView: 탭마다 NavigationStack 및 destination 한 번씩 등록. 앱 소스에 glassEffect 직접 호출 없음.
CatalogScreenModel→Store.onChange는 weak self. CatalogSession 레지스트리는 weak Store.
CatalogStore Task는 repository await 동안 self를 강하게 잡지 않고, 완료 시 generation/profile/cancellation을 검사한다.
이 검토에서 32바이트 항목 또는 시스템 glass 경고와 연결되는 특정 코드 결함은 확인하지 못했다.
Leaks 실행에서만 보고된 중복 이동도 원인 미확인이다. 정상 실행에서 재현되지 않았다는 사용자 보고를 함께 보존한다.

### 이번 변경과 한계

- StreamLab-Memory Scheme과 project.yml: Run/Profile에 MallocStackLogging=1. 기본 Scheme은 그대로 유지.
- check-runtime-mac.sh: CONFIGURATION=Debug 또는 Release 선택, 구성별 로그/결과명, 환경 기록.
- summarize-runtime.py: 구성별 판정, 필수 로그 누락 시 NOT TESTED. 경고가 없어도 수집 증거 없으면 PASS 금지.
- README, 수동 QA, MEMORY_DIAGNOSTICS 갱신. 화면 디자인/Swift 앱 로직 변경 없음.
- Linux에서 fixture/프로젝트 구조/파서/런타임 요약 회귀와 shell/XML/YAML 확인. iOS 빌드·실행을 대신하지 않음.
- 누수 또는 glass 경고 해결 완료로 주장하지 않는다. Phase 2 진행 보류.
