# ADR 0009 — SRT sidecar와 HLS 자막 선택

상태: 채택 (2026-10-13), Xcode 검증 대기

## 결정

자막 형식에 따라 재생 엔진을 나눈다. 번들 무음 데모는 Domain의 순수 Sendable SubRip 파서로 읽고
기존 PlaybackModel의 250ms 재생 시간 샘플을 이용해 SwiftUI 오버레이에 표시한다.
HLS는 AVFoundation의 legible 그룹과 select(_:in:)을 사용해 AVPlayerLayer에서 출력한다.
실제 제공되지 않는 언어를 HLS 선택 목록에 만들어 넣지 않는다.

모든 AVFoundation 선택 상태는 MainActor PlaybackModel이 소유한다. 선택 UI에는 ID와 표시명만 전달한다.
비동기 그룹 로딩은 Task 취소, 재생 generation, 활성 프로필 세션, 현재 item identity를 확인한 후 반영한다.
stop은 작업과 선택 데이터를 초기화한다. 선택은 영구 저장하지 않고 새 영상은 끄기로 시작한다.
단, 필수 선택 그룹(allowsEmptySelection=false)은 첫 트랙을 선택하고 끄기를 비활성화한다.

SRT는 UTF-8 plain text만 지원하고 BOM/CRLF를 정규화한다. 범위는 start <= time < end이며
겹친 큐는 줄바꿈으로 합친다. 시킹 중 이전 문구를 숨기고 완료 후 실제 재생 시점에서 다시 계산한다.
이는 약 250ms 표시 해상도를 가지며 프레임 단위 동기화를 보장하지 않는다.
소량의 번들 SRT만 메인 액터에서 읽는다. 사용자 대용량 파일 가져오기는 별도 비동기 파싱 설계가 필요하다.

## 검증

파서 테스트는 BOM/다중 행/경계/뒤로 이동/겹침/잘못된 큐를 포함한다.
오프라인 UI 테스트는 두 언어 변경, 끄기, 10초 이동, 재진입 초기화를 검증한다.
실제 HLS 트랙과 네트워크 실패는 별도 수동 검증 대상이다.

## API 근거

- https://developer.apple.com/documentation/avfoundation/avasset/loadmediaselectiongroup(for:completionhandler:)
- https://developer.apple.com/documentation/avfoundation/avplayeritem/select(_:in:)
