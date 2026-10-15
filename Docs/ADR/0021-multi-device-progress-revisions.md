# ADR 0021 — A3 기기 간 재생 진도 Mock

상태: 구현, Swift 실행 검증 대기 (2026-10-16)

## 범위

동일 프로필의 기기 A/B가 공유하는 in-process actor 서버와 독립 클라이언트.
1540초(25:40) 복원, 지연 요청 차단, 처음부터 보기 예외를 테스트한다.
현재 AVPlayer의 UserDefaults 저장소를 대체하지 않는다. 실제 두 기기 네트워크,
Firebase, 인증, 앱 종료 후 서버 저장, B 과제의 영속 outbox는 별도 작업이다.

## 저장 계약

키는 profileID/titleID/sourceID이며 값은 position/revision이다. 초기값은 0/0.
명령에는 UUID, deviceID, 키, 생성 시점의 baseRevision, checkpoint 또는 restart가 있다.
서버 actor의 await 없는 apply 구간에서 revision 비교와 저장을 원자적으로 수행한다.
baseRevision이 현재 revision과 같을 때만 revision을 1 올린다. 다르면 거절하고 현재 값을 반환한다.
도착 시간, 기기 시계, max(position)을 사용하지 않는다. 낮은 위치로의 의도적 시킹도 허용한다.
restart는 position=0인 새 revision이다. 예전 checkpoint는 이전 revision이므로 거절된다.

같은 baseRevision의 동시 쓰기는 먼저 처리된 하나만 성공한다. 서버는 관찰하지 못한
사용자 행동의 실제 시간 순서를 추측하지 않는다. 충돌한 과거 이벤트는 최신 revision으로
자동 재전송하지 않는다. 최신 상태 확인 후 새 사용자 행동만 새 명령을 생성한다.
오래된 restart도 같은 규칙으로 거절하며 명시적인 새 요청이 필요하다.

동일 UUID 재전송은 원 응답을 반환해 중복 저장을 막는다. UUID를 다른 payload로 재사용하면 오류다.
클라이언트는 낮은 revision 응답을 무시하므로 과거 중복 응답이 최신 로컬 진도를 되돌리지 않는다.
프로필/콘텐츠/기기 identity는 클라이언트 생성 후 고정되며 다른 identity 명령을 제출할 수 없다.

## 검증

ProgressSyncTests 8개: 25:40 복원, 응답 지연 이벤트, restart/새 시청,
중복 응답 역전, 동시 쓰기, 프로필/회차 격리, 잘못된 숫자/UUID, 오래된 restart.
실시간 sleep 없이 이벤트 제출 순서를 제어한다. 경합 테스트는 승자 identity 대신 단일 승자 불변식을 검사한다.
실행: scripts/check-progress-sync-mac.sh. Swift/Xcode 미설치 환경이므로 아직 NOT TESTED.

## 제한

메모리 receipts는 이 단기 시뮬레이션에 한해 무제한 보관한다. 운영 서버에는 보관 기간과
중복 키 만료 계약, 저장 트랜잭션, 인증 기반 profile 권한 검사, 콘텐츠 duration 검증이 필요하다.
현재 Mock은 25:40 값 복원을 검증하며 실제 동영상이 그 위치에서 재생되는 UI 검증은 아니다.
