# ADR 0007 — SwiftUI 재생 모델과 프로필 단위 수명

- 날짜: 2026-10-12
- 상태: 채택, iOS 빌드·실행 검증 대기

## 문제
Phase 1 상세 화면의 예정 안내를 실제 데모 재생으로 전환한다. 상세를 빠르게 닫거나 프로필이 바뀌어도 이전 권한 응답이 플레이어를 만들거나 이전 영상이 계속 재생되면 안 된다.

## 결정
- StreamLabCatalogFeature/Playback에 MainActor PlaybackModel과 SwiftUI PlaybackView를 둔다. 기존 Domain/Repository를 재사용하며 UIKit 화면은 추가하지 않는다.
- 매번 재생 시작/소스 변경/재시도 전에 Repository.detail(id:profile:)을 호출한다. 반환된 콘텐츠에도 canView를 확인한다. Session이 비활성이면 생성/재개하지 않는다.
- 모델이 AVPlayer 한 개와 권한/상태 샘플링/탐색 Task를 소유한다. 시작/정리마다 generation을 증가시킨다. 비동기 결과는 cancellation, generation, session.isActive를 검사한다.
- CatalogSession은 weak 모델 목록을 갖는다. invalidate에서 동기적으로 stop하여 SwiftUI 트리 교체 이전에 정리한다. 화면 닫기/onDisappear에서도 멱등 stop을 호출한다.
- stop은 Task 취소, pause, cancelPendingSeeks, replaceCurrentItem(nil), 참조 제거를 수행한다. Task는 모델을 weak으로 캡처한다.
- 상태/재생 시간은 MainActor에서 250ms마다 샘플링한다. Task는 sleep 동안 모델을 강하게 유지하지 않는다. 초기 구현에서 KVO/시간 옵저버의 actor 경계와 제거 문제를 줄인다. 진행 표시 지연은 최대 약 250ms이며 고정밀 미디어 이벤트 분석용 설계는 아니다. 향후 측정 결과에 따라 옵저버 어댑터로 교체한다.
- seek는 AVPlayer의 async completion을 기다린 후 같은 세대만 반영한다. 동시 탐색은 비활성화한다.
- 비활성/백그라운드 진입 시 pause. 복귀해도 자동 재생하지 않는다. background audio/PiP 지원은 이번 범위 밖이다.
- 30초 동안 로딩/버퍼링 상태가 계속되면 오류 및 재시도를 표시한다. 느린 네트워크에서도 사용자가 재시도할 수 있다.

## 소스와 제약
기본 번들 MP4는 ffmpeg로 직접 생성한 30초 H.264 480×270, yuv420p, 무음 테스트 영상이다. 실제 카탈로그 작품 또는 상용 영상이 아니며 모든 항목에서 동일하다. Resources를 SwiftPM으로 process하고 Bundle.module로 조회한다.
HLS 메뉴는 Apple 공개 예제 URL을 사용한다. 실패해도 번들 데모를 선택할 수 있다. DRM·다운로드·재생 이력 저장·멀티 디바이스 동기화는 구현하지 않았다.

## 검증
기존 UI 재생 예정 알림 검증을 실제 번들 재생/일시정지/10초 탐색 검증으로 대체한다. 추가로 리소스 누락 후 재시도(Debug 전용 입력), 권한 요청 중 닫기/키즈 재진입, 백그라운드 후 수동 재생을 검사한다. 실제 Xcode 실행 전에는 NOT TESTED로 기록한다.

## 참고
- https://developer.apple.com/documentation/avkit/videoplayer
- https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:completionhandler:)
- https://developer.apple.com/streaming/examples/
