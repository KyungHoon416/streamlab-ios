# ADR 0015 — HLS Picture in Picture

상태: 구현, Apple SDK 빌드 및 런타임 검증 대기 (2026-10-15)

## 결정

기존 AVPlayerLayer에 AVPictureInPictureController를 연결한다. PlaybackModel이
PiP 컨트롤러를 소유하고 delegate 콜백은 MainActor에서 처리한다. 모델 콜백은
weak self로 순환 참조를 막는다. 상태 관찰은 기존 250ms 샘플링을 재사용한다.

PiP 시작 시 SwiftUI fullScreenCover를 dismiss하지 않는다. 시스템 복귀 요청은
이미 설치된 동일 플레이어로 복귀한다. 작은 창 X는 pause/save, 앱 닫기·소스 변경·
프로필 무효화는 delegate 해제, PiP 중지, AVPlayer 정리 순서로 처리한다.
프로필을 바꾸려면 플레이어를 먼저 닫는다. PiP 중 앱 내부 카탈로그 탐색은 이번 범위가 아니다.

Background audio와 playback/moviePlayback 오디오 세션을 사용한다.
일반 백그라운드에서는 pause, 명시적으로 시작한 PiP에서만 재생을 유지한다.
PiP 시작 중에도 이 정책을 적용하고 시작 응답이 지연되면 10초 후 중지한다.
다른 앱의 오디오를 의도적으로 섞지 않는다. 전화/오디오 인터럽션 정책 확장은 별도 검증 대상이다.

HLS native media-selection 자막/오디오는 동일 item의 선택을 유지한다.
SwiftUI overlay SRT는 AVPlayerLayer 출력이 아니므로 번들/에피소드 데모는 PiP를
비활성화한다. 향후 데모 자막을 AVFoundation이 렌더링하는 트랙으로 제공해야 확장 가능하다.

## 검증

실제 PiP 가능 여부는 supported/possible로 확인한다. 지원하지 않는 환경에서
강제로 활성화하거나 테스트를 PASS로 표시하지 않는다. PIP_QA.md에 기기/런타임별 기록한다.

## 근거

- https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player
- https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller
