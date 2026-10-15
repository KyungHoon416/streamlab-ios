# ADR 0020 — 오디오 세션 작업 직렬화

상태: 구현, Mac 검증 대기 (2026-10-15)

## 문제

미디어 복구 UI 테스트 4개는 통과했지만 각 테스트에서 AVAudioSession의
메인 스레드 블로킹 가능 경고가 발생했다. 오디오 세션은 프로세스 공용이므로
화면마다 독립 Task를 만들면 이전 화면의 종료가 새 화면의 활성화 뒤에 실행될 수 있다.

## 결정

단일 private DispatchQueue에서 모든 category/setActive 호출을 FIFO 실행한다.
API가 iOS 18에서도 지원되는 형태를 유지한다. main.sync 또는 semaphore 대기는 없다.
큐 전용 owner UUID가 activation/release 소유권을 관리하며 이전 UUID의 release는 무시한다.
MainActor는 activate 완료 Bool만 전달받아 generation, session, owner가 유효한 경우에만
AVPlayer를 만든다. stop은 플레이어를 먼저 정리한 뒤 release를 enqueue한다.
지연 완료와 deinit에서도 release하며 중복 release는 무해하다.

unchecked Sendable의 범위는 이 큐 어댑터 한 곳이다. mutable owner는 큐 안에서만 접근하며
AVAudioSession을 actor 사이로 전달하지 않는다. 활성화 오류는 기존 사용자 재시도 UI로,
비활성화 오류는 개인정보 없는 OSLog로 기록한다. 미디어 리셋은 기존 사용자 요청 복구 정책 유지.

## 검증과 한계

기존 미디어 리셋/재시도/로딩 중 종료/Kids 재진입 UI 테스트를 재사용한다.
check-media-recovery-mac.sh는 UI 성공과 별개로 해당 런타임 경고가 발견되면 FAIL 처리한다.
이 변경의 Xcode 빌드/UI 테스트는 구현 환경에 Xcode가 없어 NOT TESTED다.
실제 OS 호출의 취소는 불가능하므로 완료까지 큐가 대기할 수 있지만 UI는 차단하지 않는다.
동시 다중 플레이어 믹싱은 지원 대상이 아니며 활성 플레이어 하나를 전제로 한다.

참고: Apple AVAudioSession 및 setActive 문서
https://developer.apple.com/documentation/avfaudio/avaudiosession
https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)
