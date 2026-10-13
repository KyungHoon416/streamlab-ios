# Phase 2 첫 구현 — 데모 재생

2026-10-12. 사용자 승인으로 시작했다. Phase 2 전체 완료 보고서가 아니라 재생 첫 구현과 검증 대기 내역이다.

## 구현
- 상세 화면에서 전체 화면 SwiftUI 플레이어를 연다.
- AVPlayer/VideoPlayer, 기본 30초 무음 번들 데모와 선택형 Apple HLS 예제.
- 재생/일시정지, 10초 앞뒤, 슬라이더, 시간 표시, 재생 완료/다시 재생.
- 로딩, 오류, 재시도, 연속 로딩 30초 시간 초과.
- 권한 재검사, 오래된 요청 차단, 닫기/프로필 전환 정리, 비활성 시 일시정지.
- 스크롤 가능한 세로 컨트롤, 텍스트 기반 접근성 이름/값/자동 테스트 식별자.

## 변경 파일
- Packages/StreamLabUI/Package.swift: 영상 리소스 포함.
- StreamLabCatalogFeature/Playback/PlaybackModel.swift, PlaybackView.swift: 재생 구현.
- StreamLabCatalogFeature/Resources/playback-demo.mp4: 직접 생성한 테스트 영상.
- StreamLabCatalogFeature/Detail/DetailView.swift: 예정 알림을 플레이어로 전환.
- StreamLabCatalogFeature/State/CatalogSession.swift: weak 플레이어 등록 및 세션 정리.
- Tests/StreamLabUITests/StreamLabUITests.swift: 기존 테스트 갱신, 새 UI 회귀 3개(총 정의 14개).
- README.md, Docs/PHASE1_REPORT.md, Docs/ADR/0007-playback-lifecycle.md, 이 보고서.

## 검증 결과
| 검증 | 결과 | 근거/한계 |
|---|---|---|
| Fixture 2,000개/ID/등급 | PASS | Linux validate-fixtures.py exit=0 |
| SwiftUI 프로젝트 구조 | PASS | validate-project.py exit=0. Swift 타입 검사가 아님 |
| 프로젝트 파서 회귀 2개 | PASS | test-project-parser.py exit=0 |
| 런타임 요약 회귀 6개 | PASS | test-runtime-summary.py exit=0. 실제 런타임 검사가 아님 |
| 데모 영상 형식/길이 | PASS | ffprobe: H.264, 480×270, yuv420p, 30초, 71,397바이트 |
| Swift 6 타입/Strict Concurrency/경고 | NOT TESTED | 작성 환경에 Swift/Xcode 없음 |
| Simulator 빌드 / Core 17개 / UI 14개 | NOT TESTED | 이번 변경에서 xcodebuild/swift test 미실행 |
| HLS 실제 재생/버퍼링/네트워크 오류 | NOT TESTED | Mac 또는 실기기 필요 |
| 새 재생 화면 최대 글자/VoiceOver/iPad | NOT TESTED | 기존 탐색 화면 검증을 재사용하지 않음 |
| 새 플레이어 메모리/종료 후 미디어 정리 | NOT TESTED | 코드 구현과 계측 검증을 구분 |

## Mac 자동 검사
```bash
cd ~/Desktop/streamlab-ios
./scripts/verify-mac.sh
```
기존 스크립트가 Debug 빌드와 수정된 전체 UI 테스트를 실행한다. 실패한 경우 RESULTS.txt와 ui-tests.log/UITests.xcresult를 보관한다. 재시도 테스트의 --playback-missing-resource-once는 DEBUG에서만 첫 리소스 조회 실패를 주입하며 다음 요청에는 정상 번들을 사용한다. 실제 네트워크 실패 검증의 대체가 아니다.

## 재생 수동 검사
1. 상세 → 데모 영상 재생. 숫자와 영상이 진행되는지 확인한다. 기본 영상은 무음이다.
2. 일시정지/재생, 10초 앞뒤, 슬라이더, 끝까지 재생 후 다시 재생을 확인한다.
3. 소스 메뉴 → HLS 스트리밍. 인터넷 연결 시 재생/소리가 나오는지, 연결이 없을 때 오류 후 재시도/오프라인 데모 전환이 되는지 확인한다.
4. 로딩 중 닫기 → 다시 열기, 재생 중 닫기, 홈으로 이동 후 프로필 변경. 이전 영상이나 소리가 남지 않아야 한다.
5. Simulator Home으로 앱을 배경에 보냈다가 복귀한다. 일시정지 상태여야 하며 재생 버튼으로 재개한다.
6. 최대 글자와 VoiceOver, iPad 세로·가로에서 컨트롤을 읽고 조작한다.
7. Instruments에서 플레이어 열기/닫기 20회 후 객체 수가 계속 증가하는지 측정한다.

## 남은 범위와 이월
- 재생 이력/이어보기 저장, 다운로드, DRM, 동기화는 아직 미구현. 기존 계속 시청 레일은 Mock 데이터이다.
- Phase 1 Release 시작 구간 Malloc 32B 1개 원인은 미확인이다. Debug 상세 왕복 후 누수 필터 목록 없음은 사용자 확인 범위만 PASS이다.
- 수동 Debug glassEffect 경고는 해결 완료로 주장하지 않는다. 사용자 보고상 UI 이상은 없었고, 별도 Debug 60회 자동 실행에서는 경고가 잡히지 않았다.
- 실제 iOS 검증 결과를 받기 전에는 Phase 2 전체 또는 경고 없는 빌드로 표시하지 않는다.


## 2026-10-12 홈·상세 화면 개선

### 직전 기본 재생 버전의 사용자 증거
RESULTS(20261012-080504).txt는 fixtures/project-structure/bootstrap/generated-project-structure/core/simulator-build/ui-tests/warning-free 모두 PASS(exit=0)이다. 요약에는 개별 테스트 개수와 커밋 SHA가 없으며, 사용자는 기본 재생 업데이트 명령의 결과라고 확인했다. VoiceOver/Dynamic Type/runtime/device layouts/Instruments는 해당 실행에서 NOT TESTED다. 이어서 사용자가 기본 영상 진행·일시정지·재개가 정상이라고 확인했다. 수동 10초 이동/슬라이더 결과는 아직 받지 않았다.

### 이번 변경
- HomeView: 추천/영화/시리즈 필터(프로필별 추천 스냅샷 범위), 이미지 위 제목/재생/상세 버튼, 직접 재생 fullScreenCover, 가로 계속 시청/남은 시간.
- DetailView: 대표 이미지, 메타정보 적응형 배치, 주 재생 버튼, 소개 카드. 재조회 버튼의 식별자·요청 중 비활성화 유지.
- StreamLabTheme: 160×220 세로 아트워크, 영화/시리즈 배지, 장르 표시. 원래 Mock 아트워크 유지.
- AppRootView: 현재 프로필 이름/아이콘 표시와 VoiceOver 값.
- 고정 텍스트 높이/줄 수 제한을 추가하지 않고 ViewThatFits, 세로 스크롤, 기존 Lazy 컨테이너를 유지한다.

### 범위
사용자 요청에 따라 홈/상세 디자인부터 반영했다. 실제 시즌·에피소드 데이터, 찜/다운로드, 커스텀 가로 플레이어/자동 다음 편은 이번 변경에 포함하지 않았다. 동작하지 않는 장식용 버튼은 추가하지 않았다. 사진 레퍼런스와 동일한 상용 콘텐츠 포스터를 포함하지 않는다.

### 이번 변경 검증
- PASS: Linux fixture 검사, 프로젝트 구조 검사, 프로젝트 파서 2개, 런타임 요약 회귀 6개.
- NOT TESTED: 이번 레이아웃의 Xcode 빌드/Swift 6 경고/UI 테스트/Simulator 렌더링/VoiceOver/최대 글자/iPad. 직전 버전의 PASS를 이번 변경의 PASS로 재사용하지 않는다.
- Mac: ./scripts/verify-mac.sh 실행 후 홈 추천/영화/시리즈 전환, 히어로 재생/닫기, 상세 재생/재조회, 최대 글자에서 제목/버튼 줄바꿈을 확인한다.


## 2026-10-12 히어로 터치 영역 및 나의 리스트

사용자 정정: 히어로 이미지·제목이 상세 진입이며, 오른쪽 버튼은 상세 정보가 아닌 나의 리스트 추가여야 한다.

- HomeView: 상세 NavigationLink와 재생/저장 Button을 형제로 분리하여 중첩 탭 동작 방지. 홈 나의 리스트 필터/빈 상태/저장 목록 추가.
- MyListStore: 프로필 ID별 버전 키로 UserDefaults에 CatalogTitle 스냅샷 저장. 중복 ID 제거, 키즈 허용 등급 필터링, 세션 invalidate 후 변경 차단. 상세·재생은 기존 Repository로 재검증.
- MyListButton: + 추가 / 체크 제거 상태, 접근성 값, 보조 버튼 스타일. 홈과 상세에서 같은 Store 관찰.
- CatalogSession/DetailView 연결. 홈 복귀·포그라운드 진입 시 저장 상태 갱신. 로컬 저장만 지원하며 다중 기기 동기화는 미구현.
- hero-detail 식별자를 카드의 NavigationLink로 이동. UI 테스트는 요소 타입을 한정하지 않고 이 ID로 조회한다.
- UI 회귀 1개 추가: 저장 버튼이 상세를 열지 않음, 홈/상세 상태 공유, 프로필 분리, 재실행 유지, 제거. 총 정의 15개. 실제 실행 전 NOT TESTED.
- PASS: Linux fixtures/구조 검사, 프로젝트 파서 2개, 런타임 요약 6개.
- NOT TESTED: 새 Swift 코드 타입 검사·Xcode 빌드·15개 UI 테스트·저장 동작 수동 검증. 이전 버전 PASS와 구분.

## 2026-10-13 최대 글자 상세 화면 회귀

- 사용자 제공 RESULTS(20261012-085752).txt: fixtures, project structure, bootstrap, generated structure, Core, Simulator build, compiler warning audit PASS. UI suite FAIL.
- StreamLab-UI-failure.zip 내부 SQLite: UI 15개 중 14개 성공, testLargeTextAccessibilityAudit 1개 실패. iPhone 17 Pro / iOS Simulator 26.4.1에서 상세 화면 audit의 Text clipped. 런타임 경고 없음이나 메모리 PASS로 확대 해석하지 않는다.
- detailedDescription은 "Text of this element may be clipped at larger Dynamic Type sizes."이며 대상 요소 ID가 없다. 원본 이미지에는 큰 글자 상세 화면과 화면 하단에 일부만 노출된 나의 리스트 버튼이 보인다. 스크롤 경계에 걸린 것만으로 원인을 확정하지 않는다.
- 수정: 상세 재생/재조회 및 공용 나의 리스트 Label의 Text가 여러 줄 높이를 확보하도록 fixedSize(horizontal: false, vertical: true) 적용. 상세 배지/소개/장르/대표 이미지 문구에도 세로 압축 방지.
- 접근성 검사 전 UI hierarchy와 화면을 keepAlways 첨부한다. 기존 dynamicType/textClipped/hitRegion 검사와 실패 처리는 유지한다.
- NOT TESTED: 이 수정의 Swift 타입 검사, Xcode 빌드 및 Simulator 접근성 재검증. 이 환경에는 Xcode가 없다. 원인 확정 및 해결 PASS는 재실행 증거가 필요하다.

## 2026-10-13 08:35 KST 재검사 및 후속 조정

- 증거: 사용자 첨부 StreamLab-LargeText-failure.zip, Test-StreamLab-2026.10.13_08-35-18-+0900.xcresult. 0da634b 적용 후 testLargeTextAccessibilityAudit 단독 실행, 24.948초, 1개 실패. 상세 audit의 Text clipped가 재현됐다. 기존 fixedSize 변경만으로 해결되지 않았다.
- 이번 번들의 Data payload에서 상세 hierarchy와 audit 스크린샷을 추출해 확인했다. 실패 요약에는 여전히 대상 요소가 없다. 빌드 후 UI 테스트가 실행됐지만 이 선택 실행은 전체 Core/UI 통과 증거가 아니다.
- 관찰: 재생 문구는 2줄 높이(125.3pt)를 확보한다. 메타정보는 가용 폭 362pt를 모두 사용한다. ORIGINAL 문구는 고정 높이 아트워크의 중앙 아이콘과 시각적으로 겹친다. 화면 아래 일부 노출된 저장 버튼만으로 textClipped 원인을 확정하지 않는다.
- DetailView: 접근성 글자 크기에서 ORIGINAL 문구를 이미지 밖의 자연 높이 텍스트로 분리한다. 등급/연도/종류/시간을 각각 세로 배치하며 해당 크기에서는 ViewThatFits 가로 후보를 사용하지 않는다. 기본 글자 크기의 기존 배치는 유지한다. 원인 확정에 따른 최종 해결이 아닌 관찰된 레이아웃 위험 보완이다.
- UITest: 각 화면 이름을 첨부 파일에 붙인다. issueHandler에서 compact/detailed description 및 제공되는 경우 element의 identifier/label/frame/debugDescription을 콘솔과 첨부에 남긴다. element가 nil이면 명시한다. 항상 false를 반환하여 기존 audit 실패를 보존한다.
- 상세 상단뿐 아니라 재조회 버튼에 도달할 때까지 스크롤한 화면도 동일한 dynamicType/textClipped/hitRegion audit을 수행한다. 하단 버튼 도달 여부를 검증한다.
- API 확인: https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityauditissue 및 https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)
- NOT TESTED: 후속 수정의 Xcode 빌드, Swift 6 타입/Concurrency 검사, Simulator 접근성 검사 및 전체 UI 회귀. 작성 환경에 swift/xcodebuild가 없어 실행하지 않았다.

## 2026-10-13 08:52 KST 도달성 검사 실패

- 사용자 로그: 4eca380 업데이트 후 testLargeTextAccessibilityAudit 1개 실행, 67.549초, 1개 실패. 실패는 line 345의 마지막 상세 버튼 도달성 assertion이다. 이번 요약에 textClipped 실패는 없지만, 모든 콘텐츠의 접근성 해결을 뜻하지 않는다.
- 원인 구분: 상세 스크롤 문제인지 테스트 제스처/검사 간 레이아웃 변경 문제인지는 현재 로그만으로 확정할 수 없다. 기존 테스트는 앱 전체 swipeUp과 audit을 반복하며 실제 이동량을 기록하지 않았다.
- 후속 변경: DetailView ScrollView에 detail-scroll 식별자 추가. 테스트는 내비게이션/탭 영역을 제외한 상세 viewport 안에서 목표 버튼 중심과의 차이만큼 드래그한다. 접근성 audit을 스크롤 루프와 분리하고 재생/나의 리스트/재조회 각각의 완전 노출 및 hittable을 확인한 뒤 audit을 실행한다. audit 실패를 무시하지 않는다.
- DetailScroll 로그에 각 시도의 요소 frame, viewport, hittable을 남긴다. 도달 실패는 hierarchy/스크린샷 첨부와 XCTest 실패로 유지한다. 실제 앱 레이아웃과 터치 동작은 이 변경에서 수정하지 않는다.
- NOT TESTED: 후속 변경의 Xcode 빌드/Swift 타입 검사/Simulator 테스트. Mac 재실행 필요. 이전 FAIL을 PASS로 변경하지 않는다.


## 2026-10-13 전체 자동 검사 증거 및 커스텀 플레이어

### 변경 직전 결과

사용자 RESULTS(20261013-004227).txt는 fixtures/project-structure/bootstrap/generated-project-structure/core/simulator-build/ui-tests/warning-free 모두 PASS(exit=0)이다. 앞서 사용자는 최대 글자 선택 테스트 성공도 보고했다. 요약에는 커밋 SHA와 개별 테스트 수가 없으므로 개별 실행 수를 추정하지 않는다. VoiceOver/최대 글자 수동 확인/runtime warnings/device layouts/Instruments는 해당 파일에서 NOT TESTED이다. 이 결과는 아래 새 플레이어 변경의 통과 증거가 아니다.

### 구현

- PlaybackView: 영상 위 SwiftUI 커스텀 컨트롤, 전체 화면, 재생/일시정지/완료 후 재생, ±10초, 슬라이더, 시간, 로딩/오류 재시도, 소스 시트, 영상 전체/채우기 전환.
- PlayerSurface: AVPlayerLayer 출력과 dismantle 시 연결 해제. 기존 PlaybackModel은 변경하지 않는다.
- PlaybackOrientation: 연결된 scene의 가로 회전 요청 및 종료 시 원래 방향 요청. 세로/가로 요청 버튼. 시스템이 거부하면 가용 화면에 적응한다.
- 재생 중 무조작 4초 후 컨트롤 숨김. VoiceOver/접근성 글자/로딩/일시정지/스크럽/소스 시트/비활성에서는 숨기지 않는다. 숨김 Task는 상태 변화와 화면 종료에서 취소된다.
- 기존 UI 재생 테스트의 컨트롤 재표시 처리, 새 UI 회귀 2개 추가. 정의 수는 총 17개이며 실행 통과 수가 아니다.
- 구조 검사에서 영상/회전 연결 파일 2개에만 UIKit import 허용. App/일반 화면은 SwiftUI 유지.
- ADR 0008 추가, README 및 ADR 0007 보완.

### 이번 변경 검증

| 항목 | 결과 | 근거 |
|---|---|---|
| 프로젝트 구조 검사 | PASS | python3 scripts/validate-project.py exit=0 |
| Swift 6 타입/Strict Concurrency/경고 | NOT TESTED | 작성 환경에 Swift/Xcode 없음 |
| iOS Simulator 빌드·Core·UI 17개 | NOT TESTED | Mac 실행 필요 |
| 가로 전환/복원·커스텀 컨트롤 렌더링 | NOT TESTED | iPhone/iPad 실제 확인 필요 |
| HLS·VoiceOver·Instruments | NOT TESTED | 수동/계측 확인 필요 |

### Mac 검증

먼저 git pull --ff-only --no-rebase origin main 후 ./scripts/verify-mac.sh를 실행한다. 전체 스크립트는 새 SwiftPM 파일을 포함해 생성/빌드/UI 검사를 수행한다. 단일 테스트만으로 전체 완료를 표시하지 않는다.

수동 체크:
1. 홈/상세 → 데모 재생: 가로 화면 요청, 영상/시간 진행, 닫기 가능.
2. 4초 무조작 → 컨트롤 숨김 → 화면 탭으로 복구. 일시정지 중 유지.
3. ±10초와 슬라이더: 시작/끝 범위, 재생/일시정지 상태 확인.
4. 전체 영상/화면 채우기와 세로/가로 요청, 닫기 후 이전 화면/방향 복원.
5. 소스 → HLS/오프라인 전환, 로딩 중 닫기, 재진입, 백그라운드 복귀 시 일시정지.
6. VoiceOver/최대 글자에서 조작 순서와 스크롤·닫기, iPad 분할 화면에서 회전 거부 시에도 조작 가능.
7. Instruments 재생 진입/종료 20회 후 player/model/layer 연결 정리와 지속 증가 여부.

이번 범위 이후 자막 선택 → 재생 시간 복원 → 에피소드 데이터와 자동 다음 편 순으로 진행한다. 다운로드/DRM/PiP는 미구현이다.

## 2026-10-13 10:26 사용자 커스텀 플레이어 검증 및 전환 대기 보완

- RESULTS(20261013-012609).txt: Fixture/구조/bootstrap/Core/Simulator 빌드/빌드 경고 PASS, UI FAIL(exit=65), 수동 5개 항목 NOT TESTED.
- ui-tests(4).log: 17개 중 15개 테스트 PASS, 2개 테스트 FAIL. 6 failures는 2개 테스트에서 연쇄 발생한 assertion/탭 오류 수이다.
- PASS: testCustomPlaybackLandscapeAndControls, testPlaybackLargeTextControls, 기존 상세 최대 글자, 백그라운드 재생, 누락 리소스 재시도, 검색/프로필/페이지/반복 이동 등 로그의 15개 테스트. 이 실행만으로 수동 HLS/VoiceOver/실기기/메모리 통과를 주장하지 않는다.
- FAIL: testPlaybackCloseDuringAuthorizationAndReopenForKids와 testSwiftUIScreensAndPlayback. 각각 닫기 직후 BackButton 합성 이벤트 사이에 Interface orientation changed to Portrait가 기록되고, 이후에도 상세의 BackButton/playback-open/detail-my-list/detail-retry만 남아 switch-profile 탐색에 실패했다. 회전 중 탭 경합이 유력하며 완전한 원인 확정은 후속 실행으로 검증한다.
- 후속 수정은 UI 테스트만 변경한다. openPlayback은 진입 직전 app.frame을 저장한다. closePlayback은 닫기 버튼 소멸, 원래 window frame 복원, 상세 및 BackButton hittable을 각각 기다린다. back은 정확한 BackButton을 탭하고 상세가 사라졌는지 확인한다. 고정 sleep, 무조건 재탭, 실패 무시를 사용하지 않는다.
- 공용 tap은 대상이 없거나 hittable이 아니면 실패를 기록하고 반환하여 불필요한 탭 오류 연쇄를 줄인다. 앱의 회전·재생 동작은 이번 수정에서 바꾸지 않았다.
- 이번 후속 구조 검사: PASS(exit=0). 후속 Xcode 빌드/Swift 타입 검사/UI 재실행: NOT TESTED(Linux 환경). 이전 2개 실패는 재검증 전 해결 완료로 처리하지 않는다.


## 2026-10-13 — 자막 선택

### 이전 회귀 검증 결과 수신

사용자가 제출한 RESULTS(20261013-022429).txt에서 fixtures, project-structure, bootstrap,
generated-project-structure, core, simulator-build, ui-tests, warning-free 8개 게이트 모두 PASS를 확인했다.
요약 파일에는 개별 테스트 수와 커밋 SHA가 없으므로 이 파일만으로 이를 확정하지 않는다.
수동 VoiceOver, Dynamic Type, runtime-warning-free, device-layouts, Instruments는 해당 실행에서 NOT TESTED다.

### 변경

- Domain SubRip 파서: BOM/CRLF, 다중 행, 잘못된 타임코드 제외, 겹치는 큐, 종료 경계 제외.
- 번들 한국어·영어 SRT 안내 자막과 재생 시간 기반 오버레이. 일시 정지 유지, 10초 이동/시킹 이후 재계산.
- SwiftUI 자막 시트: 언어 선택/끄기/현재 선택 표시, 로딩/없음/로드 실패 재시도.
- HLS AVMediaSelectionGroup(.legible), AVPlayerItem.select로 실제 트랙 선택.
- allowsEmptySelection=false인 자막 그룹은 끄기 비활성화 및 설명 제공.
- 로드 작업 취소 + generation/session/currentItem 검증으로 이전 영상 응답 차단.
- 닫기/소스 변경/프로필 무효화 시 자막 초기화. 자막 시트를 열면 컨트롤 자동 숨김 중지.
- Core 테스트 4개, UI 테스트 1개 추가(언어 변경/끄기/앞뒤 시킹/재진입 초기화).

### 검증 상태

| 항목 | 결과 | 근거 |
| --- | --- | --- |
| 프로젝트 구조 | PASS | Linux에서 validate-project.py exit=0 |
| 새 Swift 코드 컴파일, Strict Concurrency | NOT TESTED | 현 환경에 Swift/Xcode 없음 |
| 새 Core 테스트 및 UI 18개 전체 | NOT TESTED | Mac verify-mac.sh 필요 |
| HLS 트랙 선택/없음/실패 복구 | NOT TESTED | 네트워크와 해당 트랙 제공 스트림 필요 |
| 큰 글자/VoiceOver/가로·세로 자막 배치 | NOT TESTED | 시뮬레이터·실기기 수동 확인 필요 |

### Mac 수동 검증

1. 오프라인 데모를 일시 정지 → 자막 버튼 → 한국어. 화면에 안내 문구가 표시된다.
2. 10초 앞으로/뒤로 및 슬라이더 이동 → 해당 시점의 문구가 표시된다.
3. 영어로 바꾸면 영어, 끄기를 선택하면 문구가 사라진다.
4. 자막이 켜진 상태로 닫고 다시 열기 → 기본 끄기, 이전 문구 없음.
5. 재생 컨트롤이 자동으로 숨겨져도 자막은 계속 표시된다.
6. HLS 소스로 변경 → 이전 SRT 없음. 제공되는 실제 자막 선택 또는 자막 없음 안내 확인.
7. HLS 자막 로딩 도중 닫기/소스 변경 → 이전 응답이 새 재생에 반영되지 않는지 확인.
8. 최대 글자 크기 및 VoiceOver로 자막 버튼/언어/끄기/완료 접근 확인.

외부 파일 가져오기, 자막 스타일 태그, 자막 지연 조절, 선택 영구 저장은 이번 구현 범위 밖이다.


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
