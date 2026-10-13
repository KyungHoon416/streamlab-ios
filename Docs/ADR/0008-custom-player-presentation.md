# ADR 0008 — SwiftUI 커스텀 플레이어와 장면별 회전

- 날짜: 2026-10-13
- 상태: 구현, Mac 빌드·실행 검증 대기

## 결정

기존 PlaybackModel의 AVPlayer, 프로필 재검증, 요청 세대, 취소, 탐색 및 stop 수명주기를 재사용한다. 재생 엔진과 화면 조작 상태를 분리한다.

- PlaybackView는 기존 fullScreenCover 내부의 SwiftUI 화면이다. 기본 VideoPlayer 컨트롤을 제거하고 영상 위에 제목/닫기/재생/10초 이동/시킹/소스/비율/회전 버튼을 배치한다.
- PlayerSurface는 AVPlayerLayer를 backing layer로 사용하는 UIViewRepresentable이다. 재생 동작을 소유하지 않고 모델의 player만 연결한다. dismantle에서 layer.player를 nil로 정리한다. 기본 비율은 resizeAspect이며 화면 채우기에서 resizeAspectFill을 사용한다. 후자는 영상 일부를 잘라 표시할 수 있다.
- PlaybackOrientation은 현재 view.window.windowScene에만 geometry 요청을 보낸다. iPhone/iPad 전체 화면 진입에서 가로 방향을 요청하고 닫을 때 진입 직전 방향을 요청한다. 화면의 회전 버튼으로 세로/가로를 다시 요청한다. 전역 UIDevice KVC, AppDelegate 회전 잠금, 별도 UIWindow는 사용하지 않는다.
- iOS 26 이상에서는 effectiveGeometry.interfaceOrientation을 읽고 이전 OS는 scene.interfaceOrientation을 읽는다. 앱 plist에 세로/가로 지원은 이미 선언되어 있다.
- 회전은 시스템 요청이며 강제 잠금이 아니다. 멀티태스킹/Stage Manager 등에서 거부되면 로그를 남기고 실제 가용 크기에 맞는 UI를 유지한다. iPad에서 가로 전체 화면을 강제하기 위해 멀티태스킹을 비활성화하지 않는다.
- UIKit 연결은 위 두 파일에만 한정한다. SwiftUI App/NavigationStack/TabView를 유지하며 Storyboard, UIKit 화면 컨트롤러 또는 UIHostingController로 회귀하지 않는다. 구조 검사기는 두 경로에만 import UIKit을 허용한다.

## 조작 상태

- 재생 중 4초간 조작이 없으면 컨트롤을 숨긴다. 표면 버튼으로 다시 표시한다.
- SwiftUI task(id:)는 재생/탐색/스크럽/소스 시트/scene/접근성/조작 카운터 변화로 취소·재시작되며 화면 제거 시 취소된다. 별도의 무제한 타이머를 생성하지 않는다.
- 일시정지/로딩/실패/종료/배경에서는 컨트롤을 표시한다. VoiceOver 또는 접근성 글자 크기에서는 자동 숨김을 하지 않는다. 작은 세로 높이와 접근성 글자 크기는 스크롤 가능한 컨트롤 배치를 사용한다.
- 시킹 중 슬라이더의 로컬 드래그 값을 표시하고 드래그 종료에 한 번 seek한다. VoiceOver 조절은 10초 증감이다. 기존 모델이 유한값/범위를 검사하고 탐색 완료 전 중복 요청을 막는다.
- 소스 변경은 기존 권한 검증부터 다시 시작하며 처음부터 재생한다. 시트 닫기로 모델을 다시 생성하지 않는다. 닫기 및 onDisappear의 stop은 멱등이다.

## 검증과 한계

기존 재생/오류 재시도/권한 조회 중 닫기/백그라운드 테스트를 유지한다. 자동 숨김 후 복구, 가로 화면, 일시정지 상태에서 슬라이더 탐색, 비율 전환, 닫기/재진입, 최대 글자 audit 테스트를 추가한다. 수동으로 닫은 후 방향 복원, iPad 멀티태스킹, VoiceOver 순서, 실제 HLS, 메모리 해제를 확인한다.

자막 선택, 다음 에피소드, 이어보기 저장, 다운로드, DRM, PiP, AirPlay UI는 이번 단계에서 구현하지 않는다. 렌더링 코드는 작성했으나 Linux에서 Xcode/Simulator를 실행할 수 없어 실제 성공 여부는 NOT TESTED이다.

## 근거

- https://developer.apple.com/documentation/avfoundation/avplayerlayer
- https://developer.apple.com/documentation/uikit/uiwindowscene/requestgeometryupdate(_:errorhandler:)
- https://developer.apple.com/documentation/uikit/uiwindowscene/effectivegeometry
- https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityvoiceoverenabled
