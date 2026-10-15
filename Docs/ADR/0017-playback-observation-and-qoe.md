# ADR 0017 — 재생 상태 관측 및 QoE

## 결정
MainActor PlaybackModel의 AVPlayer 효과/수명주기를 유지하고, 순수 Sendable 값
PlaybackDiagnostics가 관측 전이의 유효성과 계측 불변식을 검사한다.
현재 단계는 관측 reducer이며 AVPlayer 명령 전체를 구동하는 상태 머신으로의 전환은 아니다.
거부된 관측은 invalid_transitions로 기록한다. UI 오류를 조용히 성공 처리하지 않는다.

- idle → preparing → ready → playing ⇄ paused.
- ready/playing/paused → seeking 또는 buffering.
- seeking → playing/paused/buffering/ended. ended → seeking(처음부터 보기).
- 활성 상태 → failed, 모든 상태 → idle(취소/정리). failed는 새 begin으로만 재시작.
- 같은 상태 반복은 멱등. 세대가 다른 이벤트 및 역행/비유한 시간은 무시.
- begin은 새 attempt. stop/fail은 열린 버퍼링 구간을 닫고 요약 한 번 출력.
- 초기 준비 및 seek 직후 대기는 rebuffer에서 제외. 실제 playing 관측 이후부터 집계.

## 시간 및 계측 한계
Production은 systemUptime 단조 시간을 주입한다. 테스트는 숫자 시각을 직접 진행하며
sleep/실제 네트워크를 쓰지 않는다.
AVPlayerLayer.isReadyForDisplay 최초 관측을 first_frame_ready_seconds로 기록한다.
시작점은 사용자 재생 요청 이후 권한 조회 직전이며 권한 조회/준비/위치 복원을 포함한다.
250ms 샘플링 오차와 메인 스레드 지연이 있다. 실제 디스플레이 프레젠테이션 시각,
정밀 TTFF 또는 서버 지연 단독 측정이라고 주장하지 않는다.
관측 레이어가 없는 PiP 등에서는 not-observed가 정상이며 0으로 대체하지 않는다.
observedBitrate는 AVPlayer access log의 관측 전송률이며 선택 화질/인코딩 비트레이트가 아니다.

## 보안/수명주기
레이어는 weak 참조; 새 observer 또는 타이머를 추가하지 않고 기존 250ms sample 사용.
OSLog PlaybackQoE에는 임시 attempt UUID, 상태 이름, 수치만 기록하며 URL/프로필/작품 ID는 제외.
기존 Debug 진도 로그의 프로필/작품/위치도 private으로 변경한다.
영속 분석 DB나 서버 업로드는 이번 범위가 아니다.

## 검증
Core 테스트: 전이 행렬 81쌍, 중복 버퍼링/실패, 초기 대기/seek 제외,
취소/재시도/세대 격리, 잘못된 시각, 최초 프레임 한 번만 기록.
Mac 실행은 scripts/check-playback-qoe-mac.sh. 실제 HLS/실기기 계측은 별도.
미디어 서비스 리셋, 상태 머신 전체 효과 분리, 성능 p50/p95 보고는 후속 작업.
