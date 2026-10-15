# ADR 0019 — 미디어 서비스 리셋 및 유한 재시도

## 정책
AVAudioSession.mediaServicesWereResetNotification을 재생 attempt 동안 관찰한다.
콜백은 payload를 전달하지 않고 MainActor로 진입하며 generation/session을 검사한다.
불변 토큰 소유자가 observer를 해제한다. @unchecked Sendable은 이 토큰 소유자에만
사용하며 공개 가변 상태는 없다. NotificationCenter 등록/해제의 스레드 안전성에 의존한다.

리셋 시 invalidated player의 위치를 새로 저장하지 않는다. 마지막 정상 저장 위치를
유지하고 Task/seek/PiP/player를 기존 stop 경로로 정리한다.
실패 안내 후 사용자 재시도 때 새 AVPlayer 및 audio session category/mode/active를 설정한다.
자동 재생/자동 재시도는 하지 않는다. 완료 상태에서 리셋되면 정리만 수행한다.

재시도는 소스/플레이어 표시 수명 동안 사용자 요청 최대 3회.
같은 소스에서 정상 재생했다가 다시 실패해도 사용한 횟수를 되돌리지 않는다.
다른 소스 선택 또는 새 플레이어 표시 시 예산을 새로 시작한다.
중복 탭은 첫 요청이 loading으로 바뀌므로 두 번째 요청을 거부한다.
권한 거부/리소스 오류/네트워크 timeout도 동일 예산을 적용한다.
자막/음성 목록 재조회는 미디어 재생 재시도 예산과 별개다.

## 검증
PlaybackRetryBudgetTests 3개: 한도, 반복 소진, 명시 reset, 잘못된 limit.
UI: Debug 알림 1회 주입 → 사용자 재시도 → 재생 복구.
Debug 영구 리소스 실패 → 세 번 재시도 → 버튼 비활성화.
NotificationCenter 알림 주입은 실제 시스템 데몬 재시작을 검증하지 않는다.
실기기 설정의 Developer → Reset Media Services를 이용한 별도 수동 검증 필요.
리셋 직전 seek/프로필 전환 경쟁, 실제 데몬 재시작, 백그라운드 PiP 경계는 미검증.

## 출처
https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification
Apple 지침에 따라 오디오 객체 재생성/세션 재설정 후 사용자 행동으로만 재생한다.
