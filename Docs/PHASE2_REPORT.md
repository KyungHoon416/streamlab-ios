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
