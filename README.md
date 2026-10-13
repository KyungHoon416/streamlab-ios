# StreamLab — SwiftUI Phase 2 재생

비공식 학습·포트폴리오 프로젝트입니다. Netflix 공식 채용 과제나 제품이 아닙니다.

**Swift 6 / iOS 18+ / SwiftUI** 오프라인 카탈로그 앱입니다. 원문 Netflix_iOS_과제.docx의 SwiftUI 조건에 맞춰 2026-10-12 UIKit 버전을 전환했습니다. Phase 2 첫 구현으로 AVPlayer 데모 재생을 추가했습니다. 상세 → 데모 영상 재생에서 번들 영상 또는 HLS 스트리밍을 선택합니다. 동기화·다운로드·DRM·이어보기 저장은 아직 구현하지 않았습니다.

## Phase 2 재생 — 이번 변경

- SwiftUI `VideoPlayer` + `AVPlayer`: 재생/일시정지, 10초 탐색, 위치 슬라이더, 재생 완료/다시 재생.
- 기본 영상: 직접 생성한 30초 무음 MP4. 실제 작품 영상이 아니며 모든 카탈로그 항목에 같은 데모를 사용합니다.
- 소스 메뉴에서 Apple HLS 예제로 전환 가능. 인터넷이 필요하며 외부 서비스 가용성은 보장하지 않습니다.
- 로딩/실패/30초 로딩 시간 초과/재시도, 재생 직전 Repository 권한 재검사.
- 닫기/프로필 전환 시 요청 취소와 player 정리. 백그라운드 전환 시 일시정지, 복귀 후 수동 재생.
- 추가 UI 회귀 3개와 기존 재생 안내 테스트 교체. **iOS 빌드·15개 UI 테스트·Swift 6 경고 검사는 이번 코드에서 NOT TESTED**입니다.
- 범위와 검사 결과: [Phase 2 보고서](Docs/PHASE2_REPORT.md), [재생 ADR](Docs/ADR/0007-playback-lifecycle.md).

## 홈·상세 디자인 개선

홈에 추천/영화/시리즈 필터, 이미지 위 히어로 타이틀과 직접 데모 재생, 가로 계속 시청 카드/남은 시간, 세로 포스터 레일을 적용했습니다. 필터는 현재 프로필의 추천 스냅샷 안에서 동작하며 전체 2,000개 탐색은 검색에서 제공합니다. 상세는 대표 이미지 → 제목/메타정보 → 재생 → 소개 순서입니다. 상단 프로필 버튼에는 현재 프로필을 표시합니다.

참고 이미지의 사진 포스터 대신 기존 생성형 색상 Mock 아트워크를 사용합니다. 시즌/에피소드와 다운로드는 별도 기능 작업으로 남아 있습니다. 가로 커스텀 플레이어는 아래 후속 구현 상태를 참고하세요. 이전 기본 재생 버전의 Mac 자동 검사 PASS와 이번 레이아웃 변경의 미검증 상태는 [Phase 2 보고서](Docs/PHASE2_REPORT.md)에서 구분합니다.

## 현재 상태

- 구현: 프로필 3개, 히어로, 추천 레일 5개, 계속 시청, 검색, 상세, 커서 페이지네이션, 중앙 로딩.
- Core의 2,000개 fixture, Repository 수준 키즈 등급 제한, 요청 세대·프로필·취소 검사를 재사용합니다.
- 최신 사용자 Mac 결과: Fixture·구조·bootstrap·Core·Simulator 빌드·빌드 경고 검사 **PASS**.
- 검색 접근성 수정 후 사용자 RESULTS(20261012-013429).txt에서 UI gate **PASS(exit=0)**. 개별 테스트 수는 해당 요약 파일에 없습니다.
- 최대 글자·VoiceOver·작은 iPhone·iPad 세로/가로는 사용자 확인 범위 PASS. Allocations의 홈/상세 반복 후 Store/Model 각 1개 잔존, 21개 해제 확인.
- 메모리 전체 완료는 보류: Instruments 시작 구간 32바이트 1개 원인 미확인. 별도 Debug Memory Graph 누수 목록은 사용자 확인상 비어 있습니다.
- 이전 Release 60회 런타임 검사 PASS 이후 수동 Debug에서 glassEffect 경고가 재발했습니다. 사용자는 화면 이상 없이 콘솔에만 표시된다고 확인했습니다.
- UIKit PASS는 새 UI의 PASS가 아닙니다. [현재 보고서](Docs/PHASE1_REPORT.md)와 [이력](Docs/Archive/UIKIT_PHASE1_REPORT.md)을 구분합니다.
- Phase 1의 미확인 32B 항목과 수동 glassEffect 경고는 남겨두고, 사용자 승인으로 Phase 2를 시작했습니다. 아래 Phase 1 PASS는 새 재생 코드의 통과 증거가 아닙니다.

## 실행 및 검증

Mac, Swift 6 / iOS 18 SDK를 지원하는 Xcode와 XcodeGen이 필요합니다. 사용자 환경은 Xcode 27.0 / Swift 6.4입니다. 변경을 작성한 호스트에는 Xcode·Swift가 없습니다.

    brew install xcodegen
    ./scripts/bootstrap-mac.sh
    open StreamLab.xcodeproj

StreamLab scheme과 iPhone Simulator를 선택해 실행합니다. SwiftUI @main App → WindowGroup으로 시작하며 Storyboard/SceneDelegate가 없습니다. XcodeGen이 없으면 위 첫 명령으로 설치합니다.

전체 자동 검증:

    ./scripts/verify-mac.sh

Fixture → 구조 검사 → XcodeGen → 생성 프로젝트 검사 → Core 17개 → Simulator 빌드 → UI 17개 → 빌드 경고 검사 순서입니다. **개수는 소스 정의 수이며 현재 통과 수가 아닙니다.** 출력되는 Docs/Validation/.../RESULTS.txt 및 environment.txt를 보관하세요. UI 실패는 같은 폴더의 ui-tests.log / UITests.xcresult에서 확인합니다.

Release 및 런타임 회귀:

    ./scripts/check-runtime-mac.sh

새 Release 제품으로 상세 ↔ 홈 60회, 20/40/60회 스크린샷, 앱 로그와 glassEffect 진단을 수집합니다. **UI 반복은 누수 측정이 아닙니다.** 로그 수집 실패나 선택 테스트 미실행은 PASS로 처리하지 않습니다.

Debug에서만 재현되는 경고를 확인하려면:

    CONFIGURATION=Debug ./scripts/check-runtime-mac.sh

할당 호출 경로는 **StreamLab-Memory** Scheme으로 별도 수집합니다. `MallocStackLogging=1`이 Run/Profile에 적용됩니다. [메모리 진단 절차](Docs/MEMORY_DIAGNOSTICS.md)를 따르세요. 사용자는 새 진단 Scheme에서 상세 왕복 후 누수 필터 목록이 비어 있다고 확인했습니다. 해당 범위만 PASS이며 전체 메모리 검증 완료를 뜻하지 않습니다.

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
- AVPlayer 기본 재생은 구현했습니다. Download 상태 머신, DRM Mock, 인증, 오프라인 큐, 카오스 전체는 이후 범위입니다.
- 전체 과제의 필수 ADR: 충돌 처리 / 플레이어 수명주기 / 다운로드 캐시 정책은 후속 단계에서 작성합니다. 현재 문서 개수만으로 전체 산출물 완료라고 보지 않습니다.
- VoiceOver·최대 글자·기기 레이아웃의 사용자 확인 범위와 남은 메모리/런타임 항목을 구분합니다. [수동 QA](Docs/PHASE1_MANUAL_QA.md).

## 히어로 조작 / 나의 리스트

히어로 이미지·제목을 누르면 상세 화면으로 이동합니다. 하단 버튼은 데모 재생과 나의 리스트 추가/제거입니다. 홈의 나의 리스트 필터에서 저장된 작품을 열고, 상세에서도 추가/제거할 수 있습니다. 프로필별 UserDefaults에 로컬 저장하며 앱 재실행 후 유지합니다. 서버 동기화는 없고, 상세/재생은 Repository에서 다시 권한을 확인합니다. 새 UI 회귀 1개를 포함한 총 15개 테스트는 이번 변경에서 Mac 실행 대기입니다.

## 최대 글자 검사 상태 (2026-10-13)

전체 검사(d5efaff)는 빌드/Core/컴파일 경고 검사 PASS, UI 14/15 PASS입니다. 0da634b의 버튼 높이 수정 후 2026-10-13 08:35(KST) 선택 실행에서도 상세 화면 Text clipped 1개로 FAIL(1개 실행, 1개 실패)했습니다. 후속 변경은 접근성 글자 크기에서 대표 이미지 문구를 분리하고 메타정보를 항목별 세로 배치하며, 화면별 실패 요소 로그와 상세 스크롤 검사를 추가합니다. 후속 변경의 Xcode 빌드·접근성 검사는 NOT TESTED입니다. 전체 통과로 간주하지 않습니다. 상세 근거는 Docs/PHASE2_REPORT.md를 참고하세요.


### 최대 글자 재검사 후속 상태 (2026-10-13 08:52 KST)

4eca380 선택 UI 검사는 마지막 상세 버튼 도달성 assertion 1개로 FAIL입니다. 후속 변경은 상세 스크롤 영역을 지정하고 목표 버튼의 위치를 확인하며 이동하도록 테스트를 보완합니다. 접근성 검사는 버튼 도달 후 실행하며, 실패는 그대로 기록합니다. 실제 스크롤 버그와 테스트 이동 문제의 원인은 아직 확정하지 않았습니다. 후속 빌드·UI 검증은 NOT TESTED입니다.


## 커스텀 전체 화면 플레이어 (2026-10-13)

데모 재생을 누르면 영상 위에 재생/일시정지, 10초 앞뒤, 시킹, 시간, 닫기와 소스 선택을 표시합니다. 진입 시 가로 회전을 요청하며, 회전 버튼으로 세로/가로를 요청할 수 있습니다. 닫을 때 이전 방향으로 복원을 요청합니다. 회전이 제한된 iPad 멀티태스킹에서도 가용 크기로 배치합니다. 화면 채우기는 일부 영상을 잘라 표시할 수 있고 다시 누르면 전체 영상을 봅니다.

재생 중 4초 무조작이면 컨트롤을 숨기고 화면을 누르면 다시 표시합니다. 일시정지/로딩/VoiceOver/접근성 글자 크기에서는 컨트롤을 유지합니다. 기본 영상은 30초 무음, HLS는 소스 메뉴에서 선택합니다. 소스 변경 시 처음부터 재생합니다.

사용자 제공 RESULTS(20261013-004227).txt의 변경 직전 자동 gate는 모두 PASS입니다. **이번 커스텀 플레이어의 구조 검사만 PASS이며 Xcode 빌드·UI·회전·VoiceOver·메모리는 NOT TESTED**입니다. Mac에서 ./scripts/verify-mac.sh 후 [Phase 2 보고서](Docs/PHASE2_REPORT.md)의 수동 항목을 확인하세요. 설계는 [ADR 0008](Docs/ADR/0008-custom-player-presentation.md)에 기록했습니다.

자막 선택·재생 시간 복원·자동 다음 에피소드·다운로드·DRM은 아직 구현하지 않았습니다.

### 커스텀 플레이어 첫 Mac 결과와 후속 테스트 수정

RESULTS(20261013-012609).txt 및 ui-tests(4).log에서 빌드/Core/빌드 경고 PASS, UI 17개 중 15개 PASS입니다. 가로 플레이어와 큰 글자 테스트는 통과했고, 재생 종료 후 뒤로가기/프로필 전환 2개 테스트가 실패했습니다. 닫기와 세로 회전이 겹치는 로그를 근거로 테스트가 cover 종료·원래 window frame 복원·뒤로가기 완료를 기다리도록 보완했습니다. 이 테스트 수정의 Xcode/UI 재검증은 NOT TESTED입니다. 수동 항목과 전체 완료는 별도입니다.


### Phase 2: 자막 선택 (2026-10-13)

플레이어 하단 말풍선 자막 버튼 → 끄기 / 한국어·영어 데모 자막을 선택합니다.
오프라인 MP4에는 30초 안내용 SRT 2종이 동봉되며 실제 작품 대사 번역이 아닙니다.
HLS에서는 스트림의 legible 트랙만 표시합니다. 자막이 없으면 안내하고, 필수 자막은 끄기를 비활성화합니다.
SRT는 재생 시간 기준으로 표시하고 시킹 중 숨긴 뒤 완료 위치에서 다시 계산합니다.
소스 변경·닫기·프로필 무효화 시 선택과 비동기 작업을 초기화합니다. 외부 SRT 파일 가져오기 UI와 선택 영구 저장은 이번 범위에 없습니다.

기존 사용자 제출 `RESULTS(20261013-022429).txt`의 자동 검증 8개 게이트는 모두 PASS입니다.
이번 자막 코드: 프로젝트 구조 검사 PASS, 새 Core 4개/UI 1개 테스트 및 Xcode 빌드·경고 검사는 NOT TESTED입니다.
Mac에서 `./scripts/verify-mac.sh`로 다시 검증하세요. UI 테스트 정의는 총 18개입니다.


### 2026-10-13 일시 정지 중 시킹 대기 복구

사용자가 일시 정지 후 10초 이동 시 로딩과 버튼 비활성화가 계속되는 현상을 보고했다.
코드에서 시킹 완료 대기에 별도 제한이 없는 경로를 확인했다. 사용자 환경에서의 정확한 원인은 아직 재현하지 못했다.
8초 watchdog이 시킹 요청을 무효화/취소하고 실제 재생 위치로 돌아가 안내와 조작 버튼을 복구한다.
시킹별 generation으로 늦은 완료를 무시하고, 일시 정지 의도를 유지한다.
일시 정지 중의 waitingToPlayAtSpecifiedRate를 재생 버퍼링으로 표시하지 않는다.
시킹 허용 오차는 ±0.1초이며 자막은 완료 후 실제 currentTime으로 계산한다.
Debug 전용 완료 지연 주입으로 시간 초과 후 앞뒤 반복 이동/재생 재개 UI 테스트를 추가했다(총 UI 19개 정의).

- 이전 제출 RESULTS(20261013-040411).txt: 자동 검증 8개 게이트 PASS.
- 이번 변경 프로젝트 구조: PASS.
- 이번 변경 Xcode 빌드/Swift 6/UI 테스트/실제 증상 재검증: NOT TESTED (Mac 필요).


### 2026-10-13 — 재생 위치 저장·이어보기

- 프로필 ID + 작품 ID + 버전이 있는 영상 소스 ID별 UserDefaults 저장.
- 5초마다, 닫기/소스 변경/백그라운드/프로필 전환 직전에 실제 currentTime 저장.
- 권한 확인 및 영상 준비 후 저장 위치로 먼저 이동하고 재생. 복원 완료 전에는 기존 기록을 덮어쓰지 않음.
- 이어보기 안내와 처음부터 보기 버튼 제공. 1초 미만 또는 끝에서 min(5초, 전체 5%) 이내는 다음 진입 시 처음부터 재생.
- 비정상 수치와 크게 변경된 영상 길이는 복원하지 않음. 자막은 실제 복원 위치 기준으로 동기화.
- 기존 테스트에는 Debug 전용 이어보기 비활성 인자를 적용해 테스트 간 기록 영향을 차단.
- 신규 UI 테스트는 고유 UserDefaults suite를 사용하여 앱 재실행 뒤 복원/처음부터 보기를 검증.
- 홈의 기존 계속 시청 Fixture 레일은 이번 변경 대상이 아니며, 이번 범위는 플레이어 재진입 위치 복원이다.
- 서버 동기화, 종료 순간 강제 종료의 무손실 저장, 라이브/무한 길이 스트림 복원은 지원하지 않는다.

검증: 프로젝트 구조 PASS. 새 Core 3개 테스트 및 UI 1개 추가(총 UI 20개 정의).
새 코드의 Xcode 빌드/Swift 6 경고/Core/UI 실행은 NOT TESTED — Mac verify-mac.sh 필요.
이전 RESULTS(20261013-044301).txt는 자동 8개 게이트 PASS이며, 사용자도 로딩 해제/앞뒤 이동/자막 변경을 정상 확인했다.

수동 확인: 데모 15초에서 닫기 → 같은 작품 재생 → 약 15초부터 시작.
앱을 종료하고 다시 열어도 유지되는지, 다른 프로필에는 해당 위치가 노출되지 않는지,
처음부터 보기 후 0초로 이동하는지 확인한다.


### 2026-10-13 — 가로 플레이어 자막 버튼 접근성 보완

제출 ui-tests(5).log: 18개 테스트 실행, 16개 통과/2개 실패, 실패 이벤트 9건.
이 로그에는 새 이어보기 및 시킹 timeout 테스트가 없으므로 최신 20개 회귀 검증 근거로 사용하지 않는다.
자막 테스트는 한국어 표시/앞뒤 동기화까지 통과했으나 이후 playback-subtitles isHittable=false로 연쇄 실패했다.
코드상 화면 높이 300pt 이상에서 고정 VStack을 사용해 자막/복구 문구 증가 시 footer가 화면 밖으로 밀릴 위험이 있었다.
항상 콘텐츠 높이를 수용하는 ScrollView로 변경하고 테스트는 해당 컨트롤 ScrollView를 직접 스크롤한다.
최초 실패에서 테스트를 중단하고 접근 불가 시 hierarchy/screenshot을 보존한다.

왕복 테스트는 27.76초 기록 뒤 951.45초 기록으로 약 15분 공백이 있고 BackButton 대기 실패 1건이 있다.
원인(앱 응답/시뮬레이터/호스트 중단)은 이 로그만으로 확정할 수 없다. 통과 처리하거나 대기 시간을 늘리지 않았다.
왕복 회차/시각 및 실패 화면 진단을 보강했으며 재실행이 필요하다.

이번 구조 검사 PASS. Xcode 빌드/수정 후 UI 테스트 및 왕복 실패 원인 확인 NOT TESTED.


### 2026-10-13 — 홈 실제 계속 시청

홈의 Fixture 기반 계속 시청 레일을 프로필별 실제 저장 기록으로 교체했다.
최근 20개 작품을 표시하며 작품별 가장 최근 소스 하나를 선택한다. 카드에 실제 진행률/초 단위 재생 시간/소스를 표시하고
누르면 상세 화면을 거치지 않고 해당 소스의 저장 위치에서 재생한다.
Repository.detail 및 canView로 현재 프로필 권한을 다시 확인하고, 취소/세션/갱신 세대를 검사해 이전 응답을 차단한다.
홈 재진입, 플레이어 닫기, foreground 복귀 시 갱신한다. 없는 작품/알 수 없는 소스는 제외하며 로드 오류는 재시도 버튼을 제공한다.
완료된 기록은 기존 완료 정책으로 삭제된다. 이전 v1 기록은 updatedAt이 없어도 읽으며 오래된 기록으로 정렬한다.
동일 작품의 여러 소스 기록 중 하나가 완료되면 다른 소스의 미완료 기록은 남을 수 있다.

검증: validate-project.py PASS. Core 목록 검증 1개/UI 홈 이어보기 및 프로필 분리 1개 추가(총 UI 21개 정의).
이번 변경 Xcode 빌드/Swift Concurrency/자동 테스트 실행은 NOT TESTED.
이전 제출 RESULTS(20261013-080817).txt는 자동 게이트 모두 PASS, ui-tests(6).log는 20개/실패 0건.
별도 SpringBoard 크래시는 테스트 종료 직후 XCTAutomationSupport에서 발생했고 일반 실행은 사용자 정상 보고. 근본 원인은 미확정.

수동 검증: 작품 A 15초 재생 → 닫기 → 홈 계속 시청 카드/진행률 확인 → 카드 선택 시 이어보기.
다른 프로필에서 A 기록 미노출, 원래 프로필 복귀 시 유지, 영상 끝까지 재생 후 목록 제거 확인.

## 2026-10-13 홈 이어보기 회전 복원 수정

사용자 제출 RESULTS(20261013-114236).txt: Core/빌드/경고 검사 PASS, UI FAIL.
ui-tests(7).log: 21개 중 20개 PASS, testHomeContinueWatchingUsesSavedProgress 1개 FAIL.
카드 표시와 저장 위치 복원/재생은 통과했으나 닫은 뒤 원래 402×874 프레임 복원이 10초 내 완료되지 않았다.
홈 재생 중 Portrait/Landscape가 반복되었다. 정확한 UIKit 콜백 순서는 추가 실행 확인이 필요하다.
회전 소유권을 PlaybackView의 StateObject로 이동하고 중복 요청을 차단했다.
브리지 dismantle에서는 회전을 복원하지 않으며, 닫기/플레이어 이탈 시 한 번만 복원한다.
종료한 세션의 늦은 콜백은 무시한다. 기존 프레임 복원 테스트 조건/10초 제한은 유지하고 실패 시 화면/계층을 첨부한다.
수정 후 구조 검사 PASS. 수정 후 Xcode 빌드·UI·실기기 회전 검증 NOT TESTED (이 환경에 Xcode 없음).

## 2026-10-13 플레이어 컨트롤 조작 중 숨김 및 UI 테스트 진단

ui-tests(10).log는 최초 상세 재생 후 일시정지 버튼 접근에서 실패했다. 홈 카드/회전 복원 단계까지 도달하지 못했으므로 이전 회전 수정의 결과는 미확정이다.
32~40초 컨트롤 스크롤 반복 중 컨트롤이 사라졌고, 테스트의 앱 전체 swipe fallback 이후 detail-scroll만 노출되었다. 자동 숨김과 조작의 경합 가능성을 수정하되, 전체 화면 소실의 원인은 아직 확정하지 않는다.
플레이어 컨트롤 드래그 동안 자동 숨김을 중단하고 제스처 종료 시 타이머를 갱신한다. 테스트는 매 시도마다 숨겨진 컨트롤을 다시 표시하고 실제 뷰포트/버튼 프레임을 검사한다. 플레이어 대상에는 앱 전체 스와이프를 보내지 않는다. 화면 안의 버튼이 가려져 있으면 임의 스크롤 대신 진단을 첨부하고 실패한다.
단일 재검증: `bash scripts/check-home-playback-mac.sh` (선택 사항: SIMULATOR_ID=실제UUID). 새 DerivedData, environment.txt, RESULTS.txt, ui-tests.log, xcresult를 생성한다.
구조 검사 및 bash 문법 검사 PASS. 수정 후 Xcode/단일 UI/전체 회귀/제스처 실기기 검증 NOT TESTED.
