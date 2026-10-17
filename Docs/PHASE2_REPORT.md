# Phase 2 — 재생 구현 및 검증 이력

## B2 URLSession 기본 loader loopback 통합 테스트 추가 — 2026-10-17

이전 HTTP adapter Core 146 PASS를 기준으로 전송 경계 검증을 추가했다.
제품 코드/UI/기본 Mock 연결은 변경하지 않는다.

- Python 표준 라이브러리 서버를 127.0.0.1 임의 포트에서 실행한다.
  외부 인터넷 및 운영 서버가 필요하지 않으며 스크립트 종료 시 서버를 종료한다.
- execute 주입 없이 HTTPMutationTransport.load와 실제 URLSession/로컬 소켓을 사용한다.
- 302 응답 반환 및 redirect 대상 요청 0회 확인.
- Content-Length 없는 chunked 응답: 정확히 4 MiB 수신 성공, 1바이트 초과 오류.
- 전송 시작을 서버에서 확인한 뒤 취소하고 오류 및 서버 측 연결 종료 확인.
- 전용 스크립트는 suite PASS와 세 완료 marker를 함께 요구한다.
  일반 Core 실행에서는 서버 환경 변수가 없으면 신규 suite를 skip한다.
- 로컬 Python fixture smoke test PASS: redirect/두 크기의 chunked body/연결 종료.
  프로젝트 구조/2,000 fixture/셸 구문/공백 검사 PASS.
- Swift 컴파일 및 URLSession 테스트 실행은 Mac 검증 대기다.
  Python 서버 검증 결과를 Swift 테스트 통과로 간주하지 않는다.

실행: `bash scripts/check-http-loader-mac.sh`.
RESULTS.txt, environment.txt, core.log, server.log 4개를 검토 후 다음 단계를 판단한다.
localhost HTTP는 테스트 전용이며 제품 adapter의 HTTPS 요구를 완화하지 않는다.
TLS/운영 인증/외부 서버/실제 인터넷 복구/iOS UI/B2·Part D 전체는 별도 검증이다.

## B2 HTTP mutation adapter Mac 검증 통과 — 2026-10-17

사용자 core/environment(20261017-032855), RESULTS(20261017-032856) 대조.
실행 HEAD a991ef91ff5a733cfe10ecededae6d4ea2a1a592, Xcode 27.0 (27A266a), Swift 6.4.
프로젝트/Memory 스킴 로컬 변경이 있는 Mac 작업 트리 결과다.

- Core 146 PASS: XCTest 15 + Presentation Swift Testing 124 + Catalog 7.
- HTTP mutation adapter 신규 8개 모두 PASS, suite 0.151초.
- 일반 큐/데이터별 충돌/가상 시계 카오스 각각 1,000 seed PASS.
- Core 로그 error:/warning: 없음. 빌드 11.72초, Presentation Swift Testing 20.740초.
- 판정: HTTP 요청 직렬화 및 주입 응답 변환 검증 통과, 다음 단계 진행 가능.
- 다음 우선순위: 기본 URLSession loader의 전송 경계 검증(redirect 차단,
  streaming 응답 상한, 전송 중 취소). 현재 테스트는 execute 주입을 사용하므로
  기본 loader의 실제 동작을 검증한 것은 아니다.

이번 결과는 iOS UI, 실제 HTTP 서버/TLS/네트워크 복구, 운영 인증,
B2 전체 및 Part D 전체 완료를 의미하지 않는다. 앱 기본 연결은 Mock이다.
이번 커밋은 검증 결과 기록만 추가하며 동일 테스트 재실행은 필요하지 않다.

## B2 HTTP mutation adapter 추가 — 2026-10-17

이전 Core 138 및 가상 시계 1,000 seed PASS를 기준으로 다음 단계를 진행했다.
HTTPMutationTransport를 opt-in으로 추가하고 앱 UI 및 기본 Mock 연결은 유지한다.

- POST mutation/snapshot, 요청 ID 헤더, 200 receipt 검증, 409 충돌 변환.
- 429/503 Retry-After 정수/표준 날짜 파싱 및 기존 bounded retry 연결.
- 잘못된 receipt/scope/revision, 비 HTTP 응답, 4 MiB 초과, 취소 처리.
- HTTP adapter 테스트 8개 추가: 주입한 응답 기반이며 실제 서버 통신 테스트가 아니다.
- 서버 계약은 Docs/MUTATION_HTTP_CONTRACT.md의 **초안**이다. 운영 서버/인증 미설정.
- 로컬 프로젝트 구조/fixture/셸 구문/공백 검사 PASS.
  Linux 환경이라 Swift 빌드·실행은 미검증. Mac 로그 확인 전 통과 처리하지 않는다.
- Mac 실행: `bash scripts/check-http-mutation-mac.sh`.
  RESULTS.txt, environment.txt, core.log를 검토한 뒤 다음 단계 진행 여부를 결정한다.

## B2 가상 시계 재시도 1,000 seed Mac 검증 통과 — 2026-10-17

사용자 core/environment(20261017-031717), RESULTS(20261017-031718) 대조.
실행 HEAD dff44655f5fc3662800c358db8d1f4e1a86cad5f, Xcode 27.0 (27A266a), Swift 6.4.
프로젝트/Memory 스킴 로컬 변경이 있는 Mac 작업 트리 결과다.

- Core 138 PASS: XCTest 15 + Presentation Swift Testing 116 + Catalog 7.
- RETRY CLOCK CHAOS PASS seeds=1000 replay=1...1000 확인, suite 0.652초.
- DOMAIN CHAOS PASS seeds=1000 및 일반 큐 CHAOS PASS seeds=1000도 확인.
  Presentation 전체 실행 21.033초. suite별 시간은 병렬 실행이므로 합산하지 않는다.
- Core error:/warning: 없음. 테스트만 추가한 단계여서 UI는 실행하지 않았다.
- 판정: 가상 시계 기반 재시도 검증 범위 통과, 다음 단계 진행 가능.
  다음 우선순위는 실제 HTTP 상태/Retry-After 헤더를 기존 mutation 재시도 정책에
  연결하는 adapter 및 응답 변환 검증이다. 서버 계약은 명시적으로 정의해야 한다.

3개 suite 각각 1,000 seed의 Mock/가상 시간 검증이다. 실제 HTTP 서버·인터넷 복구,
B2 전체 및 Part D 전체 카오스 완료를 의미하지 않는다.
이번 커밋은 결과 기록만 추가하므로 동일 테스트 재실행은 필요하지 않다.

## B2 가상 시계 기반 재시도 반복 검증 추가 — 2026-10-17

기존 RetryingMutationTransport의 sleep/random 주입점을 사용하고 앱 구현은 변경하지 않는다.
RetryClockChaosTests의 단일 테스트가 seed 1...1000으로 429/503/timeout 순서,
Retry-After, jitter 표본, 취소 시점을 선택한다. 수동 가상 시계가 각 sleep의 deadline을
보관하며 테스트가 시간을 전진시켜야만 continuation을 깨운다. 실제 backoff 시간은 기다리지 않는다.

- 대기 시간의 절반에서는 다음 send가 없어야 한다. deadline 도달 후에만 다음 시도가 가능하다.
- 각 지연이 Retry-After 및 기존 equal-jitter 정책을 따르는지 확인한다.
- 첫/둘째/셋째 대기에서 취소하거나 3회 대기 후 네 번째 전송 성공 경로를 실행한다.
  가상 sleeper는 의도적으로 취소를 무시해 어댑터의 wake 후 취소 검사도 검증한다.
- 모든 재전송은 원래 요청 전체와 동일해야 한다. 취소 시 서버 revision 0,
  성공 시 1을 확인한다. 실패 시 seed/오류 순서/대기 조건/취소 위치를 기록한다.
- 예상한 sleep 요청이 오지 않는 지연을 실패로 표시하도록 테스트에 2분 제한을 둔다.
- 기존 MutationRetryTests의 최대 4회 소진, 긴/잘못된 Retry-After 중단, 종료 오류,
  ACK 유실 테스트도 전체 Core 실행에 포함된다. 신규 seed 테스트는 이 경계 조건 전부를
  무작위화한 것은 아니다.
- 실행: `bash scripts/check-retry-clock-mac.sh`, 단일 seed는 STREAMLAB_CHAOS_SEED 지정.
  신규 suite와 `RETRY CLOCK CHAOS PASS seeds=1000` 완료를 함께 확인한다.

로컬 구조/fixture/셸 구문/공백 검사 PASS. Swift 실행은 Mac 결과 대기이며
신규 1,000 seed 통과로 기록하지 않는다. 이번 단계는 테스트만 추가해 UI 실행은 생략한다.
결과 파일은 RESULTS.txt/environment.txt/core.log 3개다. 실제 HTTP 헤더 파싱,
실제 인터넷 복구, Part D 전체 카오스 및 B2 전체 완료는 별도 남아 있다.

## B2 데이터별 충돌 1,000 seed Mac 검증 통과 — 2026-10-17

사용자 core/RESULTS(20261017-030734), environment(20261017-030733) 대조.
실행 HEAD a36a750acd62ae46aa9e35a5c1f194db4954b536, Xcode 27.0 (27A266a), Swift 6.4.
프로젝트/Memory 스킴 로컬 변경이 있는 Mac 작업 트리 결과다.

- Core 137 PASS: XCTest 15 + Presentation Swift Testing 115 + Catalog 7.
- DOMAIN CHAOS PASS seeds=1000 replay=1...1000 확인, 해당 suite 17.607초.
- 기존 일반 영속 큐 CHAOS PASS seeds=1000 replay=1...1000 eventsPerSeed=24도 확인,
  해당 suite 21.767초. 두 suite 시간은 병렬 실행되므로 합산하지 않는다.
- Core error:/warning: 없음. 앱 코드 변경이 없는 테스트 전용 단계라 UI 미실행.
- 판정: 이번 데이터별 충돌 검증 범위 통과, 다음 단계 진행 가능.
  다음 우선순위는 가상 시계 기반 429/503 backoff·취소·재시도 상한의 반복 검증이다.

일반 큐와 데이터별 충돌 suite 각각 1,000개 seed이며 서로 독립적인 seed 공간은 아니다.
실제 HTTP/인터넷 복구, B2 모든 불변식, Part D 전체 카오스 완료를 의미하지 않는다.
이번 커밋은 검증 결과만 기록하므로 같은 테스트의 재실행은 필요하지 않다.

## B2 데이터별 충돌 규칙 seed 반복 검증 추가 — 2026-10-17

기존 일반 큐 1,000 seed 검증을 유지하고 DomainConflictChaosTests를 추가했다.
단일 테스트 안에서 seed 1...1000으로 작업 순서와 다음 조건을 선택한다:
같은/다른 찜 작품, 명시적 restart/일반 0초 checkpoint, 검색 개별/전체 삭제,
restart 이후 후속 checkpoint 유무, 재구성 후 전송 전 실패/커밋 후 ACK 유실.

- 매 seed에서 A 전송을 continuation으로 보류하고 B가 먼저 commit한 뒤 해제한다.
  따라서 B의 새 revision과 A의 오래된 요청이 충돌하는 비동기 순서를 보장한다.
- A의 재구성된 요청이 실패한 후 클라이언트와 디스크 Mock 서버를 재실행한다.
  대기 요청/게시 snapshot이 그대로 복원되고 재전송 후 양쪽 큐가 비는지 확인한다.
- 독립된 예상값: 다른 찜 작품은 모두 보존, 같은 작품은 B의 서버 상태 유지,
  개별 검색 삭제는 새 서버 검색어 보존/전체 삭제는 비움, restart는 0 또는 후속 30,
  일반 오래된 0초 checkpoint는 서버의 1400을 덮어쓰지 않음.
- 이 테스트는 공통 큐의 충돌 정책을 함께 시험하기 위해 같은 scope에 세 키를 넣는다.
  실제 앱의 별도 저장소/revision stream 구성 및 PlaybackProgressStore 값 변환은
  기존 개별 테스트의 범위다. 이번 raw 진도 값은 정책 판별용이며 재생 엔진 검증이 아니다.
- 실패 시 seed/선택 조건/작업 순서를 기록한다. `STREAMLAB_CHAOS_SEED=42`로 단일 seed 재현.
  `bash scripts/check-domain-chaos-mac.sh`는 전체 Core와 신규 suite 및
  `DOMAIN CHAOS PASS seeds=1000` 완료 표시를 확인한다.

앱 코드/UI 변경 없음. 로컬 구조/fixture/셸 구문/공백 검사 PASS.
Swift/Xcode 실행은 불가하여 신규 1,000 seed의 실제 통과 여부는 Mac 결과 대기다.
결과 파일은 RESULTS.txt/environment.txt/core.log 3개다.
실제 HTTP/네트워크 복구, fake clock 기반 retry 카오스, Part D 전체 및 B2 모든
불변식 검증 완료로 간주하지 않는다.

## B2 영속 큐 1,000 seed Mac 검증 통과 — 2026-10-17

사용자 core/environment/RESULTS(20261017-024812) 대조.
실행 HEAD 44f0f0e8583653bb38c65b74b54118bbabed4acf, Xcode 27.0 (27A266a), Swift 6.4.
프로젝트/Memory 스킴 로컬 변경이 있는 Mac 작업 트리 결과다.

- Core 136 PASS: XCTest 15 + Presentation Swift Testing 114 + Catalog 7.
- `CHAOS PASS seeds=1000 replay=1...1000 eventsPerSeed=24` 확인.
  단일 chaos 테스트 내부에서 seed 1...1000을 실행했고 suite 소요 시간은 11.636초다.
  24,000개 생성 이벤트와 각 seed의 마지막 동시 전송/최종 수렴 검사를 통과했다.
- Core 로그 error:/warning: 없음. UI는 이번 테스트 전용 변경에서 실행하지 않았다.
- 판정: 영속 큐 반복 검증 범위 통과, 다음 단계 진행 가능.
  다음 범위는 찜 항목별 병합/진도 restart/최근 검색 삭제의 도메인별 충돌 규칙 반복 검증이다.

이번 성공은 일반 server-wins 영속 큐의 Mock 검증 근거이며 실제 HTTP/인터넷 복구,
B2 모든 불변식 및 Part D 10종 전체 카오스 검증 완료를 의미하지 않는다.
이번 커밋은 결과 기록만 추가하므로 동일 검증의 재실행은 필요하지 않다.

## B2 영속 큐 seed 기반 반복 검증 추가 — 2026-10-17

과제의 랜덤 이벤트 순서 1,000회 재현 요구에 대한 첫 범위로 영속 큐 테스트를 추가한다.
앱 동작/UI는 변경하지 않는다. MutationChaosTests의 단일 테스트가 seed 1...1000을
순회하며 seed마다 24개 이벤트와 마지막 두 클라이언트 동시 전송을 수행한다.

- 이벤트: 두 클라이언트 저장/삭제, 정상 동기화, 전송 전 오프라인, 커밋 후 ACK 유실,
  클라이언트 journal 재실행, 디스크 기반 Mock 서버 재실행.
- 매 seed에 async let 동시 전송 및 transport의 비동기 양보 지점을 포함한다.
  의사 난수는 고정 LCG이고 실패 시 seed/이벤트 번호 순서를 출력한다.
- 서버 snapshot과 별도로 수락된 요청 ID/revision/키별 최신 값을 기록하는 oracle로
  중복 효과·receipt 변경·서버 상태 불일치를 검사한다. ACK 유실/오프라인의 요청 보존,
  재실행의 journal 보존, 복구 후 양쪽 큐 비움/서버 수렴/추가 sync 무효과를 확인한다.
- 기존 일반 server-wins 정책의 거절된 로컬 변경은 폐기될 수 있다. 이번 테스트는
  찜 항목별 병합/진도 restart/검색 삭제 정책 전체의 랜덤 검증을 대체하지 않는다.
- 실행: `bash scripts/check-mutation-chaos-mac.sh`. Core 전체와 chaos suite 및
  `CHAOS PASS seeds=1000`을 모두 확인한다. 재현은
  `STREAMLAB_CHAOS_SEED=42 bash scripts/check-mutation-chaos-mac.sh`처럼 실행한다.
  seed 재현은 이벤트 순서 재현이며 OS의 세부 Task 스케줄까지 고정하지는 않는다.

로컬 구조/fixture 2,000개/셸 구문/공백 검사 PASS. Swift 실행은 불가하여
1,000개 seed 통과는 아직 확인되지 않았다. 이번 단계는 Core 테스트만 추가했으므로
Mac 스크립트는 UI를 재실행하지 않는다. 결과물은 RESULTS.txt/environment.txt/core.log다.
가상 시계 기반 backoff 카오스, Part D 10종 전체, 실제 HTTP/네트워크 복구,
B2 나머지 불변식의 랜덤 검증은 남아 있다. 과제 전체 카오스 완료로 간주하지 않는다.

## B2 연결 복귀 스케줄링 Mac 검증 통과 — 2026-10-17

사용자 core(20261017-022445), environment(20261017-022443),
RESULTS/ui-tests(20261017-022441) 대조. 실행 HEAD f9e0326d4861814f1ef8a6b6be548c831fe02221.
Xcode 27.0 (27A266a), Swift 6.4, arm64 Mac/iPhone Simulator.
프로젝트/Memory 스킴 로컬 변경이 있는 작업 트리이며 이전 실행과 Simulator UUID가 다르다.

- Core 135 PASS: XCTest 15 + Presentation Swift Testing 113 + Catalog 7.
  신규 연결 복귀 suite 6개 모두 PASS. Core error:/warning: 없음.
- UI 3 PASS/0 FAIL, TEST SUCCEEDED, 총 302.254초.
  일반 로그아웃 129.624초, 오프라인 대기 변경 로그아웃 120.457초,
  찜 저장/프로필 격리 52.174초. UI 빌드 로그 error:/warning: 없음.
- 연결 복귀 판단/중복 억제/후속 재시도는 Core에서 상태를 주입해 검증했다.
  UI는 기존 찜/로그아웃 회귀이며 실제 네트워크 단절·복구 시나리오가 아니다.

실제 HTTP 서버 도달/인터넷 복구, 실제 경로 전환 UI, 인증/토큰 폐기,
전원 유실, VoiceOver/최대 글자 크기, 전체 회귀는 미검증이다.
B2 전체 완료로 간주하지 않는다. 이번 변경은 검증 기록만 추가한다.

## B2 연결 복귀 시 자동 재동기화 — 2026-10-17

기존 프로필 배너의 NWPathMonitor 구현을 DesignSystem의 NetworkPathObserver로
분리하고 배너와 CatalogSession에서 재사용한다. 세션별 관찰자는 찜/최근 검색/재생
진도의 기존 영속 큐 및 제한된 재시도 경로를 호출하며 화면 구조는 유지한다.

- 첫 satisfied 경로와 unavailable → satisfied 전환을 재시도 기회로 사용한다.
  동일 satisfied 콜백은 무시한다. 진행 중 복구 작업에 여러 복귀 이벤트가 오면
  후속 작업 하나로 합치고, 후속 실행 전 다시 오프라인이면 실행하지 않는다.
- 기존 전송이 진행 중이면 종료를 기다린 뒤 재시도하므로 복귀 이벤트가 유실되지 않는다.
  각 저장소의 single-flight 및 기존 요청 ID/충돌/백오프 정책은 그대로 적용한다.
- inactive/background에서 관찰과 복구 예약을 중단하고 active에서 새 경로를 관찰한다.
  일반 저장/이미 진행 중인 전송의 기존 정책은 유지한다. 프로필 전환/로그아웃 시에는
  세션 무효화로 관찰/복구 및 기존 저장소 전송을 취소한다. 늦은 경로 콜백은 generation으로 차단한다.
- Core ConnectionRecoveryTests 6개 추가: 온라인 중복, 전송 중 복귀 병합,
  후속 실행 전 오프라인, 중단 후 이벤트 차단, 포그라운드 재시도, 실패한 영속 요청 재전송.
- `bash scripts/check-connection-recovery-mac.sh`: 전체 Core 및 신규 suite 완료 확인 후
  찜 저장/프로필 격리와 일반·오프라인 로그아웃 UI 3개 회귀. UI 로그는 터미널에도 출력한다.

로컬 구조/fixture 2,000개/셸 구문/공백 검사 PASS. Swift/Xcode가 없는 Linux에서
신규 Swift 테스트 및 iOS 빌드는 미실행이며 Mac 결과 확인이 필요하다.
NWPathMonitor satisfied는 서버 도달 가능성을 보장하지 않는다. 전송은 여전히 Mock이며
실제 HTTP/인터넷 복구 성공, 실제 경로 전환 UI 자동화, 전체 회귀 및 B2 전체 완료를 주장하지 않는다.

## B2 찜 병합 및 로그아웃 재검증 통과 — 2026-10-17

사용자 core/environment(20261017-015256), RESULTS(20261017-015257),
ui-tests(20261017-015258) 로그 대조. 실행 HEAD fd9bf12bbddf8903f3eb26c2f05c5cbdb73f328f.
Xcode 27.0 (27A266a), Swift 6.4, arm64 Mac/iPhone Simulator.
프로젝트/Memory 스킴 로컬 변경 및 별도 프로젝트 폴더가 있는 작업 트리 결과다.

- Core 129 PASS: XCTest 15 + Presentation Swift Testing 107 + Catalog 7.
  신규 작품별 찜 병합 7개 모두 PASS. Core 로그 error/warning 없음.
- UI 3 PASS/0 FAIL, TEST SUCCEEDED, 총 326.178초.
  일반 로그아웃/재실행 145.175초, 오프라인 대기 변경 로그아웃 125.065초,
  찜 저장/프로필 격리 55.939초. UI 빌드 로그 error:/warning: 없음.
- 이전에 실패한 오프라인 로그아웃의 재생 위치 이동 준비 단계를 포함해 이번 실행은
  끝까지 통과했다. 12초 대기 조정 후 재검증 통과이며 AVPlayer 탐색 지연의 근본 원인을
  해결했다거나 간헐 지연이 없어졌다는 의미는 아니다.

작품별 충돌 병합 근거는 Core Mock 테스트이며, UI 3개는 연결/저장/삭제 회귀 근거다.
실제 인증/토큰 폐기, 실제 네트워크 복구, 두 기기 충돌 UI, 전원 유실,
VoiceOver/최대 글자 크기 및 전체 회귀는 미검증이다. B2 전체 완료로 간주하지 않는다.
이번 변경은 검증 결과 기록만 추가한다.

## B2 찜 병합 Mac 검증 및 로그아웃 준비 단계 대기 수정 — 2026-10-17

사용자 core(20261017-014220), environment/RESULTS/ui-tests(20261017-014219) 대조.
실행 HEAD 87f298345aa50af7b06187640c80a8cbe8c8e645, Xcode 27.0 (27A266a), Swift 6.4.
프로젝트/Memory 스킴 로컬 변경이 있는 Mac/iPhone Simulator 실행 결과다.

- Core 129 PASS: XCTest 15 + Presentation 107 + Catalog 7. 신규 찜 병합 7개 모두 PASS.
- UI 2 PASS/1 FAIL, 총 215.166초, xcodebuild exit 65. 찜 저장/프로필 격리와 일반
  로그아웃은 통과했다. 오프라인 로그아웃은 로그아웃 전 재생 위치 이동 준비 단계에서 실패.
- StreamLabUITests.swift:1253: 목표 시각 조건은 충족했지만 playback-toggle enabled
  조건을 5초 내 충족하지 못했다. 따라서 해당 실행의 오프라인 로그아웃 삭제 동작은 미검증.
- 앱의 seek watchdog은 8초인데 테스트 대기는 5초였다. 이 준비 단계만 12초로 조정해
  복구 및 접근성 폴링 시간을 허용한다. 목표 시각/저장된 진행 카드/로그아웃 후 삭제 검증은 유지.
  AVPlayer seek 완료가 지연된 근본 원인은 현재 로그만으로 확정하지 않는다.
- check-my-list-merge-mac.sh의 UI 출력을 tee로 터미널과 파일에 함께 기록하고
  PIPESTATUS[0]으로 xcodebuild 종료 코드를 보존한다.

수정 후 shell 구문/공백 검사 PASS. Swift/iOS 재실행은 Mac에서 필요하며,
이번 수정으로 UI 실패가 해결되었다고 아직 판정하지 않는다.

## B2 찜 목록 작품별 충돌 병합 — 2026-10-17

기존 화면과 저장 구조를 유지하고 MyListStore의 충돌 정책을 작품 단위로 확장했다.
서로 다른 작품의 변경은 서버 목록 위에 순서대로 재적용하고, 같은 작품이 관찰한
revision 이후 서버에서 변경되었다면 서버 상태를 따른다. 삭제된 작품의 revision도
Mock 서버 파일에 남겨 오래된 추가 요청이 삭제를 되돌리는 것을 방지한다.

- 요청에 작품/추가·삭제/관찰 revision을 선택 필드로 저장한다. 기존 journal/서버
  파일은 읽을 수 있으며 작품 이력이 없는 snapshot은 보수적으로 서버 우선 처리한다.
- 자신의 ACK revision도 journal에 원자적으로 보관해, 자신의 추가 후 대기 중인
  삭제가 다른 작품의 서버 변경 때문에 부당하게 버려지지 않도록 한다.
- 409로 명시적으로 거절된 요청만 새 ID/sequence로 재구성한다. ACK 유실 시에는
  기존 요청을 그대로 재전송한다. 재구성 후 전송 실패 시에도 화면은 저장된 목록을 읽는다.
- 계정 삭제 시 작품 revision 이력도 지운다. 기존 취소/프로필 격리/충돌 재시도 상한 유지.
- MyListMergeTests 7개 추가: 서로 다른 작품/재실행, 같은 작품 충돌과 다른 작품 보존,
  삭제 이력 서버 재실행, 자신의 ACK 후 삭제, ACK 유실, 재구성 후 오프라인/재실행,
  작품 이력 없는 기존 snapshot 대체 정책.
- Mac 검증: `bash scripts/check-my-list-merge-mac.sh`. Core 전체 및 신규 suite 완료를
  확인한 뒤 기존 찜 저장·프로필 격리/로그아웃 UI 3개를 실행한다.

로컬 확인: 프로젝트 구조/fixture 2,000개 검증 PASS, shell 구문 및 diff 공백 검사 PASS.
현재 Linux 환경에는 Swift/Xcode가 없어 신규 Swift 테스트와 iOS 빌드는 미실행이다.
위 7개는 추가된 테스트 수이며 통과 수가 아니다. Mac 결과 확인 전 검증 완료로 간주하지 않는다.
실제 백엔드/두 기기 UI 충돌/전원 유실/전체 회귀 및 B2 전체 완료는 확인이 필요하다.

## B2 최근 검색 삭제 충돌 검증 통과 — 2026-10-17

사용자 core/environment/RESULTS(20261017-000636), ui-tests(20261017-000637) 대조.
실행 HEAD f24221acbb725cd17b9e8e37385037d8783fcf6b.
Xcode 27.0 (27A266a), Swift 6.4, arm64 Mac/iPhone Simulator.
프로젝트/Memory 스킴 로컬 변경 및 별도 프로젝트 폴더가 있는 작업 트리 결과다.

- Core 122 PASS: XCTest 15 + Presentation Swift Testing 100 + Catalog 7.
  Core 로그 error/warning 없음.
- 신규 최근 검색 삭제 충돌 7개 모두 PASS: 오래된 목록의 재등장 방지/명시적 재검색,
  오프라인 개별 삭제와 다른 서버 항목 보존, 전체 삭제/프로필 격리,
  재구성 후 전송 실패와 재실행, ACK 유실 중복 효과 방지,
  snapshot 중 프로필 무효화, 반복 충돌 상한/삭제 큐 보존.
- UI 3 PASS/0 FAIL, TEST SUCCEEDED, 총 182.047초.
  최근 검색 일반 82.141초, Mock 오프라인 73.011초,
  기존 검색 페이지네이션/프로필 전환 26.895초.

충돌 검증은 Core Mock 테스트, 화면 연결은 기존 UI 회귀 근거로 구분한다.
실제 네트워크 복구, 전원 유실, 이번 변경 후 로그아웃 UI, 최근 검색 VoiceOver/
최대 글자 크기, 두 기기 충돌 UI 시연, 전체 회귀는 완료 처리하지 않는다.
이번 변경은 검증 결과 기록만 추가했다. B2 전체 완료를 의미하지 않는다.

## B2 최근 검색 충돌 및 삭제 의도 보존 — 2026-10-17

최근 검색 동기화에 기존 snapshot/409 경로를 연결하고, 성공/부분 재구성 후 게시 목록을
journal에서 다시 읽는다. 일반 오래된 검색 snapshot은 서버 우선으로 버린다.
충돌한 배치의 검색 추가는 자동 재적용하지 않으며, 사용자가 동기화 후 다시 검색하면
최신 revision의 새 요청으로 기록할 수 있다.

개별 삭제/전체 삭제는 optional SearchDeletion으로 immutable envelope에 함께 저장한다.
409 후 서버 snapshot 위에 대기 삭제 의도만 순서대로 재적용하여 새 ID/sequence의 요청과
로컬 projection을 한 journal 교체로 커밋한다. 개별 삭제는 정규화/대소문자 무시 비교로
해당 검색어만 제거하고 다른 서버 항목은 유지한다. 전체 삭제는 재연결 시의 서버 목록을
비운다. 재구성 후 전송 실패/강제 종료에도 삭제 요청을 복구하며 ACK 유실은 같은 요청을
재전송한다. 충돌 조정 3회 상한, scope/새 편집 검사, 취소/무효화 방어를 재사용한다.
기존 envelope에는 searchDeletion이 없어도 디코딩된다. 이미 빈 목록에 대한 clear 또는
없는 항목 remove는 기존 no-op 정책을 유지한다. 화면 레이아웃은 변경하지 않았다.

Core 테스트 7개: 오래된 snapshot의 삭제 기록 재등장 방지와 명시적 재검색,
오프라인 개별 삭제/재실행/서버의 다른 항목 보존, 전체 삭제/프로필 격리,
재구성 후 실패와 재실행, ACK 유실 효과 1회, snapshot 중 프로필 무효화,
반복 409 상한 및 삭제 큐 보존. Fixture에 MainActor를 명시했다.
로컬 PASS: 구조, fixture 2,000개, shell 문법, diff 공백.
NOT TESTED: Swift 컴파일/Core/iOS 실행 (현재 호스트에 Apple toolchain 없음).
Mac: `caffeinate -i bash scripts/check-search-conflict-mac.sh`
전체 Core의 새 suite 및 기존 최근 검색 일반/오프라인/페이지네이션 UI를 실행한다.
UI 회귀는 두 기기 409 주입 시연이 아니다.

제한: 충돌 배치의 추가 기록(삭제 후 추가 포함)은 보수적으로 버리는 삭제 우선 정책이다.
항목별 추가 병합/기기 간 실제 시각 순서 추정은 하지 않는다. 업데이트 전 이미 쌓인
삭제 요청은 의도 메타데이터가 없어 충돌 시 서버 우선이며 소급 복원하지 않는다.
실제 HTTP/온라인 복귀, 찜 항목별 병합, seeded chaos, 전체 회귀/성능은 남아 있다.
B2 전체 완료로 처리하지 않는다.

## B2 진도 충돌·재시작 검증 통과 — 2026-10-17

사용자 core/ui-tests(20261016-233227), environment/RESULTS(20261016-233226) 대조.
실행 HEAD 097217c970513497f9ff4b4721c23bfcf6d1773a.
Xcode 27.0 (27A266a), Swift 6.4, arm64 Mac/iPhone Simulator.
프로젝트/Memory 스킴 로컬 변경 및 별도 프로젝트 폴더가 있는 작업 트리에서 실행했다.

- Core 115 PASS: XCTest 15 + Presentation Swift Testing 93 + Catalog 7.
  Fixture MainActor 컴파일 오류 해소. Core 로그 error/warning 없음.
- 새 B2 진도 충돌 6개 전부 PASS: 과거 checkpoint 차단, 오프라인 restart와 후속 진도
  재실행/충돌 복원, 0초 checkpoint 구분, ACK 유실 효과 1회, 반복 409 상한/큐 보존,
  기존 envelope 디코딩 호환.
- UI 4 PASS/0 FAIL, TEST SUCCEEDED, 총 238.894초.
  홈 이어보기 53.218초, 찜 52.555초, 재생 재실행/처음부터 보기 66.054초,
  Mock 오프라인 재생 복원 67.067초.
- 이전 108분 UI 지연과 idle notification 미수신 문구는 이번 실행에서 재현되지 않았다.
  환경/앱 중 원인을 확정하거나 지연 문제 해결로 단정하지 않는다.

진도 충돌과 재시작 의도 보존은 Core 테스트, 앱 연결은 해당 UI 회귀 결과로 구분한다.
실제 네트워크 복구, 전원 유실, 두 기기 충돌 UI, 최근 검색 충돌, 전체 회귀는 미검증.
이번 변경은 결과 기록만 추가했으며 앱 코드는 변경하지 않았다.

## 진도 충돌 테스트 Fixture actor 격리 수정 — 2026-10-17

사용자가 첨부한 붙여넣은 마크다운(3).md의 실행 로그 확인:
check-progress-conflict-mac.sh의 Core 빌드가 exit=1로 중단되었다.
ProgressConflictTests.swift:12에서 nonisolated Fixture.store가 @MainActor인
PlaybackProgressStore initializer를 동기 호출한 것이 컴파일 오류 원인이다.
바깥 테스트 타입의 @MainActor는 내부 타입 Fixture의 메서드에 자동 적용되지 않는다.
기존 DurablePlaybackProgressTests의 Fixture와 동일하게 @MainActor를 명시했다.
앱 코드/충돌 정책/UI는 변경하지 않았다. Core 테스트 실행 및 후속 UI는 미검증이다.

로컬 PASS: 프로젝트 구조, fixture 2,000개, 스크립트 문법, diff 공백 검사.
Swift 재컴파일은 현재 호스트에 Apple toolchain이 없어 Mac 재실행이 필요하다.
`caffeinate -i bash scripts/check-progress-conflict-mac.sh`

## B2 진도 충돌 및 명시적 오프라인 재시작 — 2026-10-17

DurableMutation에 optional restartPlayback intent를 추가했다. 기존 journal/receipt는
intent 없이 디코딩되며 기존 mutation ID/필드가 변하지 않는다. 일반 0초 checkpoint나
완료 tombstone은 명시적 재시작과 구분한다. 실제 플레이어의 처음부터 보기 버튼은
seek 전에 restart를 영속 저장하며 저장 실패 시 seek하지 않고 기존 오류 문구로 알린다.

진도 동기화에 snapshot/409 처리를 연결했다. 일반 과거 checkpoint 배치는 서버 우선으로
조정한다. 충돌 배치에 명시적 restart가 있으면 key별 마지막 restart 및 그 이후의
로컬 이벤트만 보존하고 서버 revision 위에 새 ID/sequence로 원자적으로 재구성한다.
기존 요청은 수정하지 않는다. 409로 거절된 요청만 재구성하며 ACK 유실은 같은 요청을
재전송한다. 재구성 후 앱 종료에도 새 queue가 유지된다. 한 flush에서 충돌 조정은
최대 3회이며 추가 충돌은 pending을 보존한 채 종료한다.

서버 상태로 교체된 현재 세션은 requiresReload로 checkpoint 저장을 차단하여 기존
플레이어 위치가 다시 서버를 덮지 않게 한다. 프로필 재선택(새 세션) 또는 명시적
처음부터 보기로 재개한다. 로컬 restart 이후의 진도를 보존해 재구성한 경우에는
동일 로컬 재생 흐름을 유지한다. 기기 시간이나 max(position)으로 순서를 결정하지 않는다.
앱 레이아웃은 유지하며 진도 저장/재시작 경로와 동기화 연결만 변경했다.

Core 테스트 6개 추가: 오래된 진도 거절/후속 저장 차단, 오프라인 restart→후속 진도→
재실행→충돌 복구, 0초 checkpoint와 restart 구분, restart ACK 유실, 반복 409 상한과
디스크 보존, 구형 envelope 호환. 기존 snapshot 편집/로그아웃 race 테스트도 유지한다.
로컬 PASS: 구조, 2,000 fixture, shell 문법, diff 공백.
NOT TESTED: Swift 컴파일/Core/iOS 실행 (현재 호스트에 Apple toolchain 없음).
Mac: `caffeinate -i bash scripts/check-progress-conflict-mac.sh`
전체 Core 및 재생 복원/restart, offline, 홈 이어보기, 찜 UI 회귀 4개를 실행한다.
UI 회귀는 두 기기 409 주입 시연을 대체하지 않는다.

남은 범위: 최근 검색 충돌, 찜 항목별 병합, 실제 HTTP/온라인 복귀, seeded chaos,
UI 실행 지연 원인/전체 회귀/실기기 성능. 명시적 restart는 재연결 시점에 서버 위에
적용하는 정책이며 기기 간 실제 사용자 동작 시각의 선후를 추정하지 않는다.

## B2 찜 충돌 처리 검증 통과 및 UI 지연 관측 — 2026-10-17

사용자 core/environment/RESULTS/ui-tests(20261016-153837) 네 파일 대조.
실행 HEAD 319f795c6c2293e62d02626178cae0f9c7d19cbf,
Xcode 27.0 (27A266a), Swift 6.4, arm64 Mac/iPhone Simulator.
프로젝트 및 Memory 스킴 로컬 변경과 별도 프로젝트 폴더가 있는 작업 트리에서 실행했다.

- Core 109 PASS: XCTest 15 + Presentation Swift Testing 87 + Catalog 7.
  새 B2 server wins reconciliation 6개 모두 PASS. Core error/warning 없음.
- UI 3 PASS/0 FAIL, TEST SUCCEEDED. 일반 로그아웃 2761.863초,
  Mock 오프라인 로그아웃 2023.444초, 기존 찜 1717.620초.
- UI 총 6502.927초(약 108분 23초). 직전 306.631초보다 현저히 길다.
  기존 찜 테스트 시작 시 idle 대기 뒤 1025.34초 간격과
  `App event loop idle notification not received, will attempt to continue.` 관측.
  hero-detail 존재 확인 및 최근 검색 버튼 확인에도 각각 약 1004초/932초 간격이 있다.
  테스트 assertion 통과와 별개로 실행 지연 원인은 미확인이다. 이 로그만으로
  호스트 절전/시뮬레이터 정지/앱 event loop 문제 중 하나로 단정하지 않는다.
  다음 실행 시 환경 상태와 지연 재현 여부를 함께 확인해야 한다.

찜 서버 우선 충돌 수렴/경쟁 안전성은 Core 검증, 앱 연결은 기존 UI 회귀 근거로
구분한다. 두 기기 충돌 UI 시연, 진도/검색 충돌, 항목별 병합, 실제 네트워크 복구,
전체 회귀 및 성능 검증을 완료 처리하지 않는다. 이번 변경은 검증 보고서만 갱신했다.

## B2 409 첫 단계 — 찜 서버 우선 수렴 — 2026-10-16

찜에 명시적인 whole-profile server-wins 규칙을 적용했다. 서버가 먼저 수락한
버전을 유지하고, 409가 발생한 오래된 로컬 배치를 서버 snapshot으로 교체한다.
자동 rebase/재전송으로 오래된 찜 설정을 되살리지 않는다. 다음 명시적 사용자 변경은
수신한 revision을 기준으로 새 mutation을 만든다. 진도/검색은 이 정책에 opt-in하지 않는다.

MockMutationServer의 snapshot은 scope/revision/values를 같은 actor 시점에서 읽는다.
DurableMutationStore는 기존 flush의 single-flight 안에서 snapshot을 받으며,
서버 우선 처리는 선택 인자다. pending이 비어 있어도 최신 snapshot을 받아 수렴한다.
요청 중 또는 snapshot 대기 중 새 로컬 변경이 있으면 교체를 거부하고 큐를 보존한다.
다음 refresh/변경/세션 시작에서 재시도할 수 있다. 잘못된 scope/역행 revision/취소/
무효 세션은 반영하지 않는다. snapshot과 pending 제거는 한 journal 교체로 커밋한다.
찜의 게시 목록은 성공한 동기화 후 다시 읽어 optimistic 상태를 조정한다.

Core 테스트 6개: A/B 경쟁→수렴→재실행→새 의도 반영, snapshot 중 새 편집,
로그아웃 중 늦은 snapshot, 다른 scope/과거 revision, opt-in 없는 기존 충돌 보존,
send 중 추가 편집 후 409. 기존 코드/UI 레이아웃과 요청 envelope는 유지했다.
로컬 PASS: 구조 검사, 2,000 fixture, shell 문법, diff 공백.
NOT TESTED: 이번 Swift 컴파일/Core/iOS 실행 (Apple toolchain 없음).
Mac: `caffeinate -i bash scripts/check-mutation-conflict-mac.sh`
전체 Core에서 새 suite 완료를 확인한 뒤 기존 로그아웃/찜 UI 3개를 실행한다.
UI 테스트 3개 자체는 두 기기 409 주입 테스트가 아니며 충돌 경쟁은 Core에서 검증한다.

제한: 찜 전체 snapshot 단위로 서버가 이기므로 같은 배치의 비충돌 항목도 서버 상태를
따른다. 항목별 intent 병합은 아직 아니다. 진도 restart semantics와 최근 검색 충돌,
실제 HTTP snapshot/409 adapter, 자동 온라인 감지, 1,000회 seeded chaos는 남아 있다.
B2 전체 완료로 처리하지 않는다.

## B2 재시도 및 UI 회귀 검증 통과 — 2026-10-16

사용자 core/environment/RESULTS/ui-tests(20261016-112319) 네 파일을 대조했다.
실행 HEAD: 77f67022713a7ecf3c0383f4355c1eb36dd4cc66.
Xcode 27.0 (27A266a), Swift 6.4, arm64 Mac 및 iPhone Simulator 환경.
project.pbxproj/StreamLab-Memory.xcscheme 로컬 변경과 별도 프로젝트 폴더가 있는
작업 트리에서 실행했으므로 깨끗한 checkout의 재현 결과와 구분한다.

- Core 103 PASS: XCTest 15 + Presentation Swift Testing 81 + Catalog 7.
- B2 신규 5개 모두 PASS: 429/503/timeout 혼합 및 대기값/요청 보존,
  ACK 유실 중복 효과 방지, terminal 오류 중단, 예산 소진 후 큐 복원,
  backoff 중 취소 후 추가 전송 없음. Core 로그 error/warning 없음.
- UI 3 PASS/0 FAIL/306.631초, TEST SUCCEEDED.
  일반 로그아웃 124.725초, Mock 오프라인 로그아웃 128.752초,
  기존 찜 영속 저장/프로필 격리 53.154초.

이번 결과는 주입한 오류/sleeper/random 기반 Core 재시도 검증과 기존 UI 회귀다.
실제 HTTP/네트워크 복구, 409 병합/원격 snapshot 동기화, 실제 인증/토큰 폐기,
전원 유실, 로그아웃 VoiceOver/최대 글자 크기, 전체 회귀는 완료로 처리하지 않는다.
아래의 미실행 표기는 구현 당시 이력이며 이번 로그가 재시도 단계의 실행 근거다.

## B2 첫 단계 — 제한된 전송 재시도 — 2026-10-16

과제 원문 B2/F07의 429 Retry-After, 지수 백오프, jitter, 상한, 취소 처리를 시작했다.
RetryingMutationTransport를 찜·진도·최근 검색의 기존 FIFO 전송에 연결했다.
요청당 최초 1회 + 재시도 최대 3회이며 immutable envelope 전체를 유지한다.
일시적 URL 오류 및 명시적인 HTTP 429/503 오류만 재시도한다.
기본 대기는 equal jitter로 0.5~1, 1~2, 2~4초다. Retry-After는 최소 대기값이며
30초 초과/음수/비유한 값이면 현재 전송을 종료하고 큐를 보존한다. 긴 서버 대기를
짧게 잘라 조기 재전송하지 않는다. 409/401/알 수 없는 오류는 그대로 전달한다.
취소는 send 전, 응답 후, 대기 전후에 확인하며 기존 세션 전환/로그아웃 취소를 따른다.

Core 테스트 5개 추가: 혼합 장애와 정확한 envelope/대기값, ACK 유실 시 효과 1회,
terminal 오류/긴 Retry-After 중단, 예산 소진 후 journal 재실행 복원, 대기 중 취소.
실제 sleep 대신 주입한 sleeper/random으로 재현한다.
로컬 PASS: 프로젝트 구조, fixture 2,000개, shell 문법, diff 공백 검사.
NOT TESTED: Swift 컴파일/Core 실행/iOS 실행 (현재 호스트에 Apple toolchain 없음).
Mac: `caffeinate -i bash scripts/check-mutation-retry-mac.sh`
전체 Core의 B2 suite 성공 후 앱 빌드 및 기존 로그아웃/찜 UI 3개를 실행한다.

남은 B2: 서버 snapshot 다운로드와 409 optimistic UI 조정/명시적 병합,
찜 동시 변경 수렴, 진도의 restart action semantics 통합, 온라인 복귀 감지.
이번 작업을 B2 전체 완료로 간주하지 않는다. 실제 HTTP adapter와 Retry-After 헤더
파싱은 아직 없으며 오류는 transport 경계에서 주입한다. 기존 UI offline flag는
전송 자체를 차단하는 B1 검증용이고 새 재시도 테스트를 대신하지 않는다.
재시도 예산은 요청/flush 호출 단위이며 재실행·새 변경 시 새 예산을 사용한다.

## 로그아웃 UI 재검증 통과 — 2026-10-16

사용자 RESULTS/ui-tests(20261016-104751) 대조: UI 3 PASS/0 FAIL,
486.049초, `TEST SUCCEEDED` 확인.
- 전체 프로필 기록 삭제 및 재실행 후 로그아웃 유지: PASS (130.699초).
- Mock 오프라인 pending 변경 삭제: PASS (304.038초).
- 기존 찜 영속 저장 및 프로필 격리: PASS (51.313초).

로그아웃 테스트는 데모 재진입 후 A/B 프로필의 찜·진도·최근 검색 삭제와
새 검색 기록 저장/재실행도 확인한다. 앞선 확인 버튼 중복 선택 실패는 재현되지 않았다.
Core는 이번 RESULTS에서 PASS로 보고되었으나 이번 Core 원본 로그는 미첨부다.
직전 원본 로그에서 확인한 98 PASS와 구분한다. environment 미첨부로 실행 SHA는
확정하지 않는다. debugger version lookup 진단은 남지만 테스트 실패로 이어지지 않았다.
실제 인증/토큰 폐기, 실제 네트워크 복구, 전원 유실, 로그아웃 VoiceOver/최대 글자 크기,
전체 회귀는 여전히 미검증이다. 아래의 실패/미실행 기록은 각 변경 당시의 이력이다.

## 로그아웃 UI 확인 버튼 선택 수정 — 2026-10-16

사용자 core/RESULTS/ui-tests(20261016-102548) 대조: Core 98 PASS
(XCTest 15 + Swift Testing 76 + Catalog 7), UI 1 PASS/2 FAIL/187.188초.
기존 찜 프로필 격리 테스트는 PASS. 로그아웃 일반/Mock 오프라인 테스트는 모두
확인 버튼 클릭 전에 `Multiple matching elements found`로 실패했다.
로그의 Sheet 안에 같은 confirm-logout 식별자를 가진 부모/자식 Button이 노출되었다.
따라서 이 결과로 로그아웃 삭제·재실행 UI 동작을 통과 처리하지 않는다.
환경 로그 미첨부로 실행 커밋 SHA는 확정하지 않는다.

확인 대화상자의 표시를 기다린 뒤 그 Sheet 내부의 confirm-logout 첫 표현을 선택하도록
해당 테스트만 수정했다. 기존 공통 tap의 존재/터치 가능 검사와 로그아웃 이후 검증,
앱 코드 및 UI는 유지했다.
로컬 검증: 프로젝트 구조, 2,000 fixture, shell 문법, diff 공백 검사 PASS.
수정 후 Swift/iOS UI 실행은 Xcode가 없어 미검증이며 Mac 재실행이 필요하다.
`caffeinate -i bash scripts/check-account-logout-mac.sh`

## B1 데모 계정 로그아웃 및 로컬 기록 삭제 — 2026-10-16

선행 사용자 core/RESULTS/ui-tests(20261016-094326) 대조: Core 91 PASS
(XCTest 15 + Swift Testing 69 + Catalog 7), UI 3 PASS/0 FAIL/173.585초.
최근 검색 일반 72.939초, Mock 오프라인 72.294초, 기존 검색 페이지네이션 28.352초.
실행 environment 미첨부로 SHA는 추가 확정하지 않는다. 아래 변경의 실행 결과는 아니다.

이번 구현:
- 실제 인증 서버가 없는 앱에 명시적 데모 계정 로그아웃/데모 시작 흐름 추가.
  툴바의 로그아웃 확인 후 모든 프로필의 찜·진도·최근 검색 journal과 pending 요청,
  해당 계정 defaults의 구형 찜/진도/언어 선호를 삭제한다. 프로필 전환은 기록 유지.
- My List도 기존 progress/search와 같은 계정 namespace를 사용하도록 정리했다.
  일반 앱은 local-demo, DEBUG 테스트는 독립 UserDefaults suite/account를 사용한다.
- AccountLocalData는 디스크에 signed-out marker를 먼저 기록한다. 삭제 도중 앱이
  종료되면 다음 실행에서도 signed-out 상태이며, 정리 완료 전 데모 진입을 차단한다.
  삭제 실패는 표시하고 재시도한다. marker 제거는 cleanup 성공 후 명시적 데모 시작 때만.
- 삭제 전 전송 작업 취소, player/catalog/언어 저장소 무효화. Weak registry로 이전 프로필
  작업이 붙잡고 있는 journal도 account+directory 범위로 무효화하고 메모리 projection 삭제.
  늦은 ACK/저장 callback이 삭제한 파일을 다시 만들지 못하도록 한다.
- 로컬 Mock 서버의 계정 records/revisions/sequences/receipts도 제거한다. 이전 device UUID만
  거부 목록에 보관해 늦은 요청 재생성을 막고 새 UUID의 세션은 revision 0부터 시작한다.
  실제 원격 계정 삭제 API가 아니다. A3 인메모리 데모도 새 coordinator로 교체한다.
- Core 테스트 7개 추가: 전체 profile/store 삭제와 다른 계정 보존, 중단 후 재실행,
  삭제 실패/재시도, Mock 서버 재실행 후 오래된 요청 거부, 반복 revoke, 늦은 ACK,
  무효 언어 저장소 callback. UI 일반/오프라인 2개는 A/B 기록 생성→로그아웃→재실행→
  재진입 후 기록 없음→새 검색 기록 저장을 검증한다. 기존 찜 프로필 전환 회귀도 실행.

PASS: 프로젝트 구조, 2,000 fixture, shell 문법, diff 공백 검사.
NOT TESTED: 새 Swift 컴파일/Core 테스트/iOS 빌드/UI 실행 (현재 호스트에 Xcode 없음).
Mac: `caffeinate -i bash scripts/check-account-logout-mac.sh`
Core 전체 후 로그아웃 UI 2개와 기존 찜 UI 1개를 실행한다.

미완료/미검증: 실제 인증·토큰 폐기/Keychain(B3/C), 실제 네트워크 복구,
원격 상태 다운로드, B2 conflict/backoff, queue/receipt/revoked-ID 용량 관리,
로그아웃 화면 VoiceOver/최대 글자 크기, 전원 유실 fsync 내구성, 전체 회귀.
계정 defaults는 계정별 suite를 주입하는 계약이며 실제 여러 계정 로그인 UI는 없다.
삭제 실패를 성공으로 처리하지 않는다. OS/파일 권한 문제로 marker 작성 자체가 실패한
경우에는 현재 프로세스의 진입은 차단하지만 재실행 상태 보존까지 보장할 수 없다.


## B1 최근 검색어 영속 저장·전송 연결 — 2026-10-16

선행 검증: 사용자 RESULTS/core/ui-tests(20261016-092940) 대조 완료.
Core 84 PASS (XCTest 15 + Swift Testing 62 + Catalog 7), UI 4 PASS/0 FAIL,
236.677초. 홈 이어보기 50.729초, 찜 50.716초, 재실행·재시작 68.600초,
Mock 전송 실패 중 복원 66.633초. environment 미첨부로 커밋 SHA는 추가 확정하지 않는다.
이 결과는 앞선 진도 구현의 실행 근거이며 아래 새 변경의 PASS가 아니다.

최근 검색 구현:
- RecentSearchStore가 기존 DurableMutationStore/MockMutationServer를 재사용한다.
  account/profile별 독립 journal, 검색 전용 Mock revision stream 및 영속 receipt 사용.
- 검색 입력 중에는 기록하지 않고 명시적 submit 또는 최근 검색어 재선택 때 저장한다.
  앞뒤/연속 공백 정규화, Unicode NFC, 대소문자 무시 중복 제거, 최신순 20개,
  항목당 100자 제한. 저장 실패 시 기존 표시를 유지하고 오류 문구를 표시한다.
- 기존 검색/결과/더 보기/로딩은 유지한다. 빈 검색어일 때 기존 결과 ScrollView 상단에
  최근 검색어/다시 검색/개별 삭제/전체 삭제를 추가한다. 터치 영역 44pt 이상과
  별도 접근성 이름을 부여했다. 실제 VoiceOver/최대 글자 크기는 아직 미검증.
- 변경 snapshot과 전송 요청을 원자적으로 저장하며 전체 삭제는 nil tombstone이다.
  앱 재진입/변경 때 Mock 전송, 실패 시 요청 유지. 프로필 전환은 취소/invalidate.
  DEBUG progress-suite namespace를 검색에도 사용하여 테스트 간 기록을 분리한다.
- Core 테스트 7개 추가: 정규화/중복/순서, 크기 제한, 오프라인 재생성 및 ACK 유실,
  개별/전체 삭제, scope/무효 세션, 쓰기 실패, 손상 snapshot 보존.
- UI 2개 추가: 일반 및 Mock 오프라인에서 입력 중 미저장/submit/재검색/프로필 격리/
  개별 삭제 후 재실행/전체 삭제 후 재실행. 기존 검색 페이지네이션도 함께 검사한다.

PASS: 프로젝트 구조, 2,000 fixture, shell 문법 및 diff 공백 검사.
NOT TESTED: 신규 Swift 컴파일/Core 테스트/iOS 빌드/UI 실행 (현재 호스트에 Xcode 없음).
Mac: `caffeinate -i bash scripts/check-recent-searches-mac.sh`
Core 전체 후 검색 UI 3개를 실행한다.

B1 전체 완료 아님: 실제 계정 로그인/로그아웃과 계정 전체 로컬 데이터 삭제,
원격 상태 다운로드 및 실제 네트워크 복구는 남아 있다. B2 충돌 해결·backoff,
B3 인증, queue/receipt 용량 관리, 실기기 성능·전원 유실·전체 회귀도 미완료/미검증이다.


## B1 재생 진도 영속 큐 연결 — 2026-10-16

이전 사용자 RESULTS(20261016-085506).txt: PASS Core/B1 journal tests,
PASS My List UI. 원본 Core/UI 로그와 environment는 이 실행에 첨부되지 않아
실행 커밋/개별 소요 시간/개별 테스트 수는 추가 확정하지 않는다.
이는 앞선 찜 구현 검증이며 아래 새 변경의 실행 결과가 아니다.

- PlaybackProgressStore에 DurableMutationStore를 재사용하는 저장 모드 추가.
  앱 CatalogSession은 이 모드를 사용한다. 기존 재생 위치 조건/이어보기 정렬/완료 판정 유지.
- 진도 snapshot과 immutable 요청을 함께 저장하고 완료/처음부터 보기는 nil 삭제 요청으로
  전송한다. ACK가 와도 로컬 이어보기 기록은 유지하고 대기 요청만 제거한다.
- 기존 UserDefaults 기록은 최초 journal 생성 때만 이관한다. 계정 정보가 없는 구형 기록은
  local-demo 계정만 이관할 수 있다. 원본 보존, 삭제된 진도의 재이관 방지.
- 찜과 진도는 서로 다른 journal/Mock 서버 파일 및 revision stream을 사용한다.
  큐 엔진과 MockMutationServer 코드를 재사용하며 별도 큐 구현은 만들지 않는다.
  실제 다중 기기 A3 coordinator/demo 경로는 유지한다.
- 진입/성공한 checkpoint 저장 때 Mock 전송을 시도한다. 프로필 전환은 마지막 진도 저장 후
  작업 취소/invalidate. 늦은 callback의 추가 진도 저장을 막는다.
  저장 오류는 기존 playback syncMessage에 표시하며 UserDefaults로 조용히 우회하지 않는다.
- DEBUG progress-suite를 journal의 테스트 전용 account namespace에도 적용한다.
  기존 릴리스 UI는 유지한다. 오프라인 Mock UI 시나리오는 전송만 차단하며 영상은 로컬 fixture다.
- 신규 Core 테스트 8개: 오프라인/재생성 복구, 완료·재시작 삭제, 일회성 이관,
  account/profile/title/source 격리, 잘못된 수치, 저장 실패, 무효 세션, ACK 후 이어보기.
  기존 재실행/재시작 UI 흐름을 재사용한 오프라인 Mock UI 테스트 1개 추가.

PASS: 프로젝트 구조, 2,000 fixtures, shell 문법, diff 공백 검사.
NOT TESTED: 새 Swift 컴파일/Core 테스트/iOS 빌드/UI 실행 (현재 호스트에 Apple 도구 없음).
Mac: `caffeinate -i bash scripts/check-durable-progress-mac.sh`
Core 전체 실행 후 재실행·재시작/오프라인 Mock/홈 이어보기/찜 회귀 UI 4개를 실행한다.

미완료: 최근 검색 큐, 실제 계정 로그인/로그아웃 삭제, 원격 상태 다운로드,
B2 충돌 해결·429 재시도/온라인 감지, B3 인증, 전체 회귀 및 실기기 성능.
진도는 기존 5초/이벤트 저장 주기를 유지하며 queue/Mock receipt 크기 제한과
디스크 IO 성능은 아직 해결하지 않았다. 파일 원자성은 전원 유실 fsync 보장이 아니다.


## B1 Core 빌드 실패 수정 — 2026-10-16 17:44 KST

사용자 실행 49a70ce / Xcode 27.0 / Swift 6.4:
RESULTS(20261016-084341).txt, environment(20261016-084342).txt,
core(20261016-084342).log 확인. Core 컴파일 FAIL exit=1; 테스트 실행 전 중단.
My List UI는 Core 선행 조건 실패로 NOT TESTED이며 UI 로그가 없는 것이 정상이다.

DurableMutationStore.append를 static으로 분리하면서 인스턴스 scope 참조가 남았다.
요청의 scope를 전달된 journal의 next.scope에서 읽도록 수정한다.
기존 UI와 저장 형식은 변경하지 않는다.

PASS: 프로젝트 구조 검증 및 diff 공백 검사.
NOT TESTED: 수정 후 Swift 컴파일/Core 11개 신규 테스트 및 My List UI 실행.
Apple 도구가 없는 현재 환경에서 컴파일 성공을 주장하지 않는다.
동일 check-durable-my-list-mac.sh를 다시 실행해야 한다.


## B1 첫 구현 — 찜 목록 영속 journal 및 재전송 Mock (2026-10-16)

기존 UI, 재생/진도/A3 경로를 유지하고 MyListStore 저장 계층만 교체했다.
- 단일 원자적 파일에 로컬 snapshot과 FIFO pending mutation을 함께 기록한다.
  성공적으로 저장한 뒤에만 화면 상태를 바꾼다. 읽기/쓰기 실패는 사용자에게 알린다.
- account/profile 경로 분리, 재실행 시 같은 device ID/요청 ID/sequence/baseRevision 복원.
  기존 UserDefaults 찜 목록은 최초 journal 생성 때 이관하고 원본은 보존한다.
- 단일 실행 flush, ACK 후에만 dequeue. 오류/취소/409는 요청을 유지한다.
  프로필 전환은 invalidate/cancel하며 늦은 응답이 저장소를 갱신하지 못한다.
- 앱에서는 파일 기반 MockMutationServer에 연결했다. Mock의 receipt도 영속화하여
  서버 처리 후 ACK 유실/앱 재실행에도 중복 적용하지 않는다. 실제 HTTP 서버가 아니다.
  진입/refresh/찜 변경 시 재시도한다. DEBUG --ui-test-mutation-offline은 전송만 차단한다.
- Core 테스트 11개 추가: 재생성 복구/FIFO, ACK 유실, Mock 재시작, 단일 flush 중 추가,
  취소, 삭제 후 늦은 응답, ID 재사용/순서 위반, 오프라인/충돌, scope/이관/삭제,
  journal 유실, 손상 파일 보존. 프로세스 객체 재생성 테스트이며 실제 강제종료 증거는 아니다.

검증: 프로젝트 구조/2,000개 fixture 검증 PASS, shell 문법/diff 공백 검사 PASS.
NOT TESTED: Swift 컴파일, Core 테스트 실행, 새 iOS 빌드, 찜 UI/접근성/전체 회귀.
현재 실행 환경에 Swift/Xcode가 없다. Mac 실행:
`caffeinate -i bash scripts/check-durable-my-list-mac.sh`
Core 전체(경고 오류 처리/strict concurrency) 후 기존 찜 지속성·프로필 격리 UI를 실행한다.

B1 전체 완료 아님: 진도/최근 검색 큐 연결, 실제 계정 인증/로그아웃 연결 및 계정 전체 삭제,
서버 상태를 새 클라이언트에 가져오는 동기화는 남아 있다. 현재 account는 local-demo다.
삭제 API는 단일 scope journal용이며 legacy 데이터/Mock 서버 데이터 삭제 UI는 아직 없다.
409 병합/429 backoff/401 single-flight/온라인 복귀 감지는 B2/B3 작업이다.
Mock receipt와 pending 작업의 용량 제한/정리, 파일 IO 성능 및 전원 유실 내구성도 미검증이다.
파일 원자적 교체는 multi-process writer나 디스크 fsync 보장을 뜻하지 않는다.


## 실제 HLS 오디오 역할 대체 및 자막 선호 검증 통과 — 2026-10-16 17:25 KST

사용자 environment(10).txt: 319d0727333074fbe06a0730ef9411e17614f5f2,
Xcode 27.0 (27A266a), Simulator, 로컬 Xcode 프로젝트/scheme 수정 존재.
RESULTS(20261016-082443).txt 및 ui-tests(20261016-082443).log 대조:

- Core PASS exit=0 (요약 기준, Core 원본 로그 미첨부).
- testRealHLSAudioRoleFallbackRestoresDVSAndIsolatesProfiles PASS 125.878초.
- testRealHLSMissingSubtitlePreservesPreference PASS 53.630초.
- UI 2개 실행, 실패 0개, skip 없음. 총 179.508초, hls-audio-fallback exit=0.
- QoE 수집 및 관측된 전이 거부 없음 PASS (요약 기준; 성능 목표 판정 아님).

외부 HLS의 네이티브 트랙 목록을 이용한 일반 음성 대체/DVS 선호 복원/프로필 격리와
자막 누락 시 선호 유지의 자동 UI 검증 근거다. 실제 DVS 음성 청취 증거는 아니다.
재생 불가 native 트랙, 실기기 HLS QoE, 실제 OS 리셋, 전체 PiP 및 최신 전체 회귀는
여전히 별도 미확인이다. A2 전체 완료나 전체 과제 완료로 표시하지 않는다.

이전 전체 회귀의 계속 시청 실패는 68331c9 대상 실행에서 통과했고,
이번 HLS 2개도 개별 통과했다. 서로 다른 실행을 합쳐 전체 회귀 PASS로 계산하지 않는다.
다음 구현 우선순위는 B1 영속 mutation 큐/로컬 우선 저장이며 기존 찜/진도 저장과
A3 revision/idempotency Mock을 재사용한다. 실기기 성능 계측은 별도 진행 항목으로 유지한다.


## 계속 시청 대상 테스트 통과 — 2026-10-16 17:01 KST

environment(9).txt: 68331c93dc4e8e4d4d6af0d0293c0527f8dc757d,
Xcode 27.0 (27A266a), Simulator. 로컬 Xcode 프로젝트/scheme 수정 존재.
RESULTS(20261016-080105).txt 및 ui-tests(20261016-080105).log:
testHomeContinueWatchingUsesSavedProgress PASS 51.525초, 1개 실행/실패 0개,
home-playback exit=0. 화면 진입, 복원 안내, 저장 위치 이상에서 재생, 닫기/방향 복귀,
프로필 B의 빈 계속 시청 목록 검증 통과. HUD 유지 테스트 플래그를 사용한 실행이다.
이미지 터치 범위와 HUD 동기화를 함께 변경했으므로 어느 하나만이 원인이었다고 단정하지 않는다.

이번 실행은 Core/전체 UI/수동 실기기 검증을 수행하지 않았다. 이전 전체 실행은
28 PASS/4 SKIP/1 FAIL이며, 그 유일한 실패 항목이 이번 대상 실행에서 통과한 것이다.
이를 최신 전체 회귀 PASS로 합산하지 않는다.

다음 검증은 이전 전체 실행에서 SKIP된 실제 HLS 오디오 역할 대체 및 자막 선호 복원:
`caffeinate -i bash scripts/check-hls-audio-fallback-mac.sh`.
실제 외부 샘플 HLS 연결 필요. 자동 UI는 선택/복원/재생 상태를 검사하며 실제 음성 청취,
재생 불가 트랙, 실기기 성능, 실제 OS 리셋, 전체 PiP/최신 전체 회귀는 별도 미확인이다.


## 전체 회귀 28개 통과 및 계속 시청 보정 — 2026-10-16 16:32 KST

사용자 environment(8).txt: fb622802 / Xcode 27.0 / Swift 6.4, 로컬 Xcode 설정 변경 존재.
RESULTS(20261016-073159).txt, ui-tests(20261016-073200).log:
Fixture/구조/bootstrap/Core/Simulator 빌드/경고 검사 PASS (요약 기준).
UI 33개: 28 PASS, 4 외부 HLS opt-in SKIP, 1 FAIL, 총 1941.904초.
나의 리스트 52.001초, 최대 글자 접근성 69.128초, navigation soak 475.553초 PASS.
SKIP된 HLS 검증과 실기기/수동/성능 검증은 PASS에 포함하지 않는다.

FAIL testHomeContinueWatchingUsesSavedProgress (44.684초), 675행 playback-resumed 미발견.
카드 탭 후 화면 진입 여부를 구분하는 assertion/계층 출력이 없어 원인 확정 불가.
계속 시청 카드에도 실제 label layout 기준 contentShape와 접근성 자식 제외를 적용한다.
기존 카드의 작품명/등급/진도/이어보기 label은 Button에 그대로 유지한다.
테스트는 기존 테스트 전용 HUD 유지 플래그를 사용하여 자동 숨김을 분리하고,
화면 진입/복원 안내/실제 재생 위치/회전 복귀/프로필 B 격리를 각각 검사한다.
제품의 자동 숨김 정책과 별도 자동 숨김 테스트는 변경하지 않는다.

로컬 구조/fixture/shell/diff 검사 PASS. 수정 후 Swift/Xcode/UI NOT TESTED (Linux).
먼저 scripts/check-home-playback-mac.sh로 실패한 1개만 재검증한다.


## 대상 회귀 3개 통과 — 2026-10-16 15:50 KST

사용자 environment(7).txt: eb9ce50d52810127a3a025554b104b52c8916b55,
Xcode 27.0 (27A266a), iOS Simulator. Xcode 프로젝트/메모리 scheme 로컬 수정 존재.
입력 RESULTS(20261016-065034).txt / ui-tests(20261016-065031).log 대조 결과:

- Core PASS exit=0 (제공 요약 기준, Core 원본 로그 미첨부).
- testMissingSubtitleFallsBackAndRestoresWithoutChangingOtherProfile PASS 100.812초.
- testMyListPersistsAndIsolatesProfiles PASS 52.909초.
- testPlaybackLargeTextControls PASS 32.354초.
- 대상 UI 3개 실행, 실패 0개, skip 없음, 186.076초. regression-fixes exit=0.
- QoE 수집 PASS, 관측된 전이 거부 없음 (요약 기준; 성능 목표 달성 아님).

추천 전환 실패는 이번 대상 회귀에서 해소됐다. 이미지 터치 제외/카드 영역 보정 후
저장/프로필 격리/재실행 복원/추천 복귀/찜 해제 assertion이 모두 통과했다.
원인의 모든 내부 경로가 증명됐거나 전체 앱이 검증됐다는 뜻은 아니다.

다음: scripts/verify-mac.sh로 전체 회귀. 장식 이미지의 터치 제외가 홈/검색/상세의
상위 Button/NavigationLink 접근에 영향을 주지 않는지 기존 UI 전체 테스트로 확인한다.
실제 재생 불가 트랙/오디오 역할 대체, 실기기 HLS QoE, 실제 OS 리셋, 전체 PiP 및
전체 회귀는 이번 실행 범위 밖이며 NOT TESTED를 유지한다.


## 최신 수정 실행 결과 및 이미지 터치 영역 보정 — 2026-10-16

사용자 environment(6).txt에서 ce0824a / Xcode 27.0 (27A266a) 실행 확인.
RESULTS(20261016-064036).txt 및 ui-tests(20261016-064036).log:
Core PASS (요약), 자막/프로필 격리 PASS 102.864초, 큰 글자 플레이어 PASS 32.169초.
나의 리스트 FAIL 55.010초, 추천 선택 검사 1171행. 이전 보정으로 해결되지 않았다.
QoE 수집 PASS이며 성능 합격을 뜻하지 않는다. 로컬 Xcode 설정 변경이 존재한다.

실패 AX 트리: 추천 버튼 (20,128,65,47), 카테고리 스크롤 (20,116,362,71),
저장 카드 (20,67,362,543.3). 저장 카드 및 이미지의 보고 영역이 카테고리와 겹친다.
scaledToFill 이미지의 시각적 clipping만으로 상호작용 범위를 제한하지 못하는 것이
유력한 원인이다. 실제 화면/탭 전달은 아직 확인 전이며 원인 확정으로 표시하지 않는다.

장식 CatalogArtwork는 allowsHitTesting(false)로 터치 대상에서 제외한다.
저장 카드 label은 최종 layout에 contentShape를 적용하고 접근성 자식 이미지 대신
작품명/등급/장르의 단일 label을 제공한다. UI 배치/색/데이터/선택 assertion은 유지한다.
기존 실패 테스트로 추천 선택, 히어로 재등장, 찜 해제를 다시 검증한다.

로컬 구조/fixture/shell/diff 검사 PASS. Swift/Xcode/UI 실행 NOT TESTED (Linux).
실행: caffeinate -i bash scripts/check-regression-fixes-mac.sh.


## 작업 재개 및 카테고리 탭 보정 — 2026-10-16

기준 HEAD: ee4c30c. 새로 개발하지 않고 기존 구현과 첨부 과제, 최신 로그를 대조했다.
ADR-0006의 사용자 요청에 따라 현재 앱은 SwiftUI이며 과거 대화 제목에 맞춰
UIKit/Storyboard로 되돌리지 않는다. Core, UI 스타일, 저장 데이터는 유지한다.

최신 입력 RESULTS(20261016-053954)(2).txt / ui-tests(20261016-053954)(2).log:
- Core PASS (제공된 요약 기준; 이번 환경에서 재실행한 결과가 아님).
- 자막 누락/복원/프로필 격리 PASS (100.052초).
- 최대 글자 플레이어 PASS (32.272초).
- 나의 리스트 FAIL (51.658초): 1143행 추천 선택 확인. 저장 목록 선택과 카드 조회는 통과.
- QoE 수집 PASS 및 관측된 전이 거부 없음. 성능 목표 충족의 근거는 아니다.

추천 버튼 tap 이벤트 이후 isSelected 대기가 실패했다. 첨부 xcresult 화면/계층은
없어 실제 히트 영역 문제와 SwiftUI 상태/접근성 갱신 문제 중 원인을 확정할 수 없다.
Plain 카테고리 버튼의 패딩 전체에 contentShape를 지정했다. UI 테스트는 카테고리
ScrollView 안에서 버튼 중앙이 보이도록 가로 스크롤하고 탭한다. 기존 선택 상태,
저장 카드, 프로필 격리, 재실행 복원 assertion과 제한시간은 유지한다.
추천 선택 실패 시 계층을 텍스트 로그에도 남긴다. 무조건 성공 처리나 재탭은 하지 않는다.

이번 검증 PASS: validate-project.py, validate-fixtures.py (2,000개), 대상 shell 구문,
git diff --check. 현재 Linux에 Swift/Xcode가 없어 Swift 컴파일/Core/UI 재실행은 NOT TESTED.
수정 효과는 Mac 재실행 전까지 미확인이다.

재검증: `caffeinate -i bash scripts/check-regression-fixes-mac.sh`.
세 항목 통과 후 `caffeinate -i bash scripts/verify-mac.sh`로 전체 회귀한다.


## 나의 리스트 전환 대기 검증 — 2026-10-16 14:23 KST

사용자 RESULTS(20261016-052259), ui-tests(20261016-052300): Core PASS,
자막 복원 PASS, 큰 글자 플레이어 PASS, 나의 리스트 FAIL. 이번 실패는 추천 복귀 이전,
나의 리스트 탭 직후 saved-card의 즉시 exists 검사(1119행)다. 따라서 이전 히어로
복귀 수정의 성공 여부는 아직 확인할 수 없다. QoE summary는 미수집으로 NOT TESTED.

테스트에서 나의 리스트 선택 상태와 저장 카드 존재를 각각 최대 5초 기다리며,
실패 시 화면/계층 첨부에 더해 텍스트 로그에도 계층을 남긴다. 저장/프로필 분리
assertion은 유지한다. 타이밍 문제인지 실제 렌더링 문제인지는 재실행 전 확정하지 않는다.
구조 검사 PASS, 수정 후 Xcode/UI NOT TESTED. 동일 대상 회귀 스크립트로 재검증한다.


## 카테고리 복귀 후 히어로 접근 수정 — 2026-10-16

사용자 RESULTS(20261016-041607) 및 ui-tests 로그: Core PASS, 대상 UI 3개 중
자막 누락/복원 PASS, 최대 글자 플레이어 PASS, 나의 리스트 FAIL. QoE 수집 PASS,
관측된 전이 거부 없음(성능 합격 판정 아님). 전체 회귀는 이번 실행에서 NOT TESTED.

추천 복귀 후 10회 스크롤에도 hero-my-list가 AX 트리에 나타나지 않았다.
로그만으로 실제 화면/SwiftUI 내부 원인을 확정할 수 없다. HomeView의 카테고리별
ScrollView identity를 분리하여 전환 시 LazyVStack과 스크롤 위치를 새로 구성한다.
모델, 저장 목록, 재생 presentation 상태는 이 identity 경계 밖에 유지한다.
UI 테스트는 추천 isSelected와 히어로 존재를 각각 확인해 선택 실패와 렌더링 실패를 구분한다.

수정 후 구조 검사 PASS. Xcode 빌드 및 대상 UI 재실행 NOT TESTED(현재 Linux 환경).
동일 check-regression-fixes-mac.sh로 재검증하고 세 항목 PASS 후 전체 검증한다.


## 전체 회귀 3개 실패에 대한 스크롤 검증 수정 — 2026-10-16

사용자 RESULTS(20261016-034909): Fixture/구조/bootstrap/Core/빌드/경고 PASS,
UI FAIL(exit65). UI 로그: 33개 중 4개 외부 HLS opt-in skip, 실패 3개, 나머지 26개 PASS.
별도 실행에서 통과한 HLS 테스트를 이번 전체 실행의 PASS로 세지 않는다.

실패 지점: 자막 복원에서 offscreen 3화 소스, 나의 리스트에서 카테고리 전환 후 히어로,
최대 글자 크기에서 playback-toggle 접근. 소스 선택에 목록 내 양방향 스크롤 helper를 재사용하고,
추천 복귀 후 홈 스크롤 안에서 히어로를 찾는다. 플레이어 helper는 ScrollView 컨테이너 자체의
isHittable을 스크롤 선행조건으로 쓰지 않고 관측된 viewport 안에서만 드래그한다.
버튼 탭은 여전히 해당 버튼의 exists/isHittable 확인 후 수행한다. 실패 시 화면/트리를 첨부한다.
assertion 제거나 대기시간 연장은 하지 않았다. 실제 앱 UI 문제가 모두 없다고 단정하지 않는다.

구조/shell PASS. 수정 후 Swift/Xcode/UI NOT TESTED.
먼저 scripts/check-regression-fixes-mac.sh의 3개를 재검증한 뒤 전체 verify-mac.sh를 실행한다.


## 실기기 첫 프레임 측정 및 보고서 도구 — 2026-10-16

attempt_started/summary에 동일 attempt UUID와 source ID를 기록해 로컬/HLS 시도를 분리한다.
측정 정의는 기존 load 시작 → first-frame-ready 관측이며 실제 디스플레이 시각은 아니다.
Docs/TTFF_QA.md에 실기기 20회 절차, Docs/TTFF_REPORT_TEMPLATE.md에 미측정 보고서 양식을 추가했다.
scripts/summarize-ttff.py는 source별 원본 로그를 samples.csv/REPORT.md로 변환하고 nearest-rank
p50/p95, 실패/미관측/누락을 기록한다. 동일 attempt 중복 제거, 충돌/잘못된 숫자 거부.
성능 목표가 제공되지 않았으므로 성능 PASS를 자동 판정하지 않는다.
Python 집계 테스트 3개/구조 PASS. 변경된 Swift 빌드와 실기기 시간 측정 NOT TESTED.

사용자 실기기 PiP 보고: 홈 직접 이동 자동 진입, PiP 영상·음성 지속, X로 음성 중지 PASS.
아이폰 모델/iOS 미제공. 전체 화면 복귀/자동 시작 OFF/시스템 리셋은 이 보고로 검증되지 않았다.


## 실기기 자동 PiP 전환 수정 — 2026-10-16

사용자 실기기 확인: PiP 버튼 진입 시 끊김 없음. 시스템 자동 시작 설정이 켜져 있어도
홈으로 직접 이동하면 일시정지. 기존 코드가 canStartPictureInPictureAutomaticallyFromInline을
false로 설정하고 scene inactive 즉시 pause하던 동작을 확인했다.

재생 중인 HLS에 자동 시작을 허용한다. scene 전환 시 PiP가 가능하면 최대 2초간
AVKit의 자동 시작을 기다리고, 시작되지 않으면 pause한다. 앱이 직접 자동 start를 강제하지 않는다.
시스템 설정/지원 여부는 AVKit이 결정한다. 일반 로컬 재생/일시정지/시킹은 즉시 pause 경로를 유지한다.
전환 대기는 stop/프로필 세션 종료/소스 변경/앱 복귀에서 취소하고 generation 검사로 늦은 작업을 막는다.
PiP willStart부터 기존 10초 시작 watchdog을 적용한다. PiP 닫기/실패 시 음성도 중지한다.

구조 검사 PASS. 수정 후 Xcode/UI 및 실기기 자동 PiP는 NOT TESTED.
기존 수동 버튼 진입 성공은 사용자 보고 범위의 PASS이며 자동 진입 성공으로 확대하지 않는다.
시뮬레이터 회귀: scripts/check-pip-mac.sh. 실기기 재검증: Docs/PIP_QA.md 최신 항목.


## 자막 대체 검증 PASS · 다음 검증: 실제 HLS 오디오 역할 대체 — 2026-10-16

사용자 RESULTS(20261016-013618): Core/HLS 자막 대체/QoE 수집 PASS.
근거: Docs/Validation/hls-tracks-20261016/RESULTS.txt. 요약 제공 기준이며 원본 xcresult는 미첨부.
기존 자막 누락/복원/프로필 격리 테스트와 실제 HLS 자막 선호 유지 테스트가 통과한 결과다.

일반 영어만 제공하는 Apple HLS 소스를 추가했다. 원격 master 조회에서 en 일반 음성만
선언되고 DVS characteristic이 없음을 확인했다. 기존 DVS 소스는 en-US와 화면 해설을 선언한다.
manifest 조회는 재생 PASS를 의미하지 않는다. 오디오 행에는 실제 AVFoundation 역할에 따라
'일반 음성'/'화면 해설'을 표시한다. 저장 및 fallback 로직은 기존 구현을 재사용한다.

새 UI 테스트: DVS 선택 → 일반 영어 소스의 같은 언어/다른 역할 대체 안내와 선택 확인 →
DVS 소스로 복귀 시 복원 → 앱 재실행 복원 → 새 프로필 B의 기본 오디오 확인.
실제 native 트랙을 사용하며 목록을 제거하는 주입 플래그는 사용하지 않는다.
기존 HLS 자막 테스트와 함께 실행한다. Core에는 en-US DVS → en 일반 음성 사례를 추가했다.
검증 명령: `caffeinate -i bash scripts/check-hls-audio-fallback-mac.sh`.

구조/shell PASS. 새 Core/Xcode/UI 테스트 NOT TESTED.
자동 검증은 목록/선택/재생 상태를 확인하며 실제 해설 청취 증명은 아니다.
재생 불가 트랙, 실제 OS 리셋, 실기기 QoE/PiP, 전체 회귀는 NOT TESTED 유지.


## HLS 회차 검증 통과 · 다음 검증: 네이티브 자막 누락 — 2026-10-16

사용자가 제공한 RESULTS(20261016-011640).txt를 근거로 Core/HLS 회차 UI/QoE 수집 PASS.
HLS 전용 스크립트는 자동 다음 회차·최종 종료와 회차별 진도 복원 두 테스트가 실제 passed인지 검사한다.
근거 보관: Docs/Validation/hls-episodes-20261016/RESULTS.txt (사용자 제공 요약, 원본 xcresult 미첨부).
QoE PASS는 수집 및 관측된 상태 전이 오류 없음이며 성능 목표 달성을 뜻하지 않는다.
이 결과가 위 항목에 대한 이전 NOT TESTED/FAIL 이력을 대체한다. 전체 회귀 PASS는 아니다.

다음 자동 테스트는 로컬에서 한국어 선호 저장 → 실제 외부 HLS의 네이티브 자막 목록 조회 →
한국어 미제공 안내 및 단일 대체 선택 → 실제 재생 유지 → 로컬 복귀 후 한국어 복원을 검사한다.
트랙 조회 실패를 대체 성공으로 인정하지 않는다. 자막 제거 주입 플래그는 사용하지 않는다.
기존 로컬 누락/복원/프로필 격리 테스트도 함께 실행하고 두 테스트의 passed를 확인한다.
외부 Apple HLS의 제공 트랙이 변경되면 Fixture 전제 실패로 조사하며 skip/PASS로 우회하지 않는다.

추가 파일: scripts/check-hls-tracks-mac.sh. 실행은 인터넷 연결 후:
`caffeinate -i bash scripts/check-hls-tracks-mac.sh`
새 코드 구조/shell 검사 PASS. 새 Swift/Xcode/HLS 자막 UI 검증 NOT TESTED.
네이티브 재생 불가 트랙 및 오디오 역할 대체, 실기기 QoE/실제 OS 리셋/PiP/전체 회귀는 여전히 NOT TESTED.


## HLS 종료 알림 연결 및 회차 헤더 가시성 — 2026-10-16

사용자 RESULTS(20261016-010628): Core PASS, 회차별 진도 복원 PASS,
자동 회차 전환 FAIL(exit65), QoE 수집 PASS. 종료 직전 시킹/일시정지 검사는 통과했으나
2화 label 대기가 실패했다. 로그만으로 실제 종료 미감지와 화면 밖 label을 구분할 수 없다.

AVPlayerItem.didPlayToEndTimeNotification을 해당 item에 한정하여 관찰한다.
MainActor에서 재생 generation/seek generation/프로필 활성 상태를 확인하고 종료를 기록한다.
HLS 종료 시각과 duration 차이에 의존하지 않고 종료 상태 및 기존 카운트다운을 처리한다.
seek/stop에서 종료 상태와 observer를 해제하고 seek 완료/취소 watchdog 후 다시 등록한다.
기존 시간 비교 fallback은 유지한다. item_end 진단 로그를 추가했다.

UI 테스트는 footer에서 시킹한 후 컨트롤을 위로 스크롤해 회차 헤더의 가시성을 확인한다.
실패 시 status/time/source와 screenshot/접근성 트리를 남긴다. timeout 연장이나 assertion 제거는 없다.
수정 후 구조 검사 PASS. Swift 컴파일/Xcode/HLS UI 재실행 NOT TESTED.
재검증: `caffeinate -i bash scripts/check-hls-episodes-mac.sh`.


## HLS 자동 다음 회차 테스트 관측 보강 — 2026-10-16

사용자 RESULTS(20261016-004915): Core PASS, HLS 회차별 진도 복원 PASS,
자동 다음 회차 FAIL(재생 완료 label 대기 timeout), QoE 수집 PASS.
로그만으로 실제 종료 실패와 일시적인 UI 상태 미관측을 구분할 수 없다.

테스트를 일시정지 → 종료 10초 전 시킹 → 실제 잔여 1~25초 확인 → 재생으로 변경했다.
첫 회차는 잠깐 표시되는 종료 label 대신 실제 2화 자동 선택과 재생을 검증한다.
마지막 회차는 종료 상태와 다음 회차 버튼/카운트다운 부재를 그대로 검증한다.
DEBUG 전용 인자로 해당 테스트에서만 HUD 자동 숨김을 막는다. 재생 상태, 종료,
카운트다운, 외부 HLS URL은 조작하지 않는다. 실패 단계별 화면/접근성 트리도 첨부한다.

수정 후 프로젝트 구조 검사 PASS. Swift 컴파일/Xcode/HLS UI 재실행은 NOT TESTED.
`caffeinate -i bash scripts/check-hls-episodes-mac.sh`로 재검증한다.


## HLS 테스트 소스 목록 스크롤 수정 — 2026-10-16

사용자 RESULTS(20261016-003040): Core PASS, HLS UI 2개 FAIL(exit65).
두 테스트 모두 source-hls-series-episode-1-v1을 찾지 못해 실제 HLS 검증 전 중단됐다.
소스 ID는 일치한다. 기존 helper는 offscreen List 행의 존재만 기다려 스크롤하지 않았다.
영상 소스 List에 식별자를 추가하고 sheet 등장 확인 후 해당 목록 안에서 최대 8회
스크롤해 행의 존재/탭 가능 여부를 확인한다. 재생 검증 assertion과 timeout은 유지한다.
수정 후 구조 PASS. Xcode/UI 및 실제 HLS 재생은 NOT TESTED. check-hls-episodes-mac.sh로 재검증.


## 이미지 캐시 actor 호출 수정 — 2026-10-16

사용자 core(9).log에서 ArtworkDataCache.swift:46의 actor-isolated finish 호출에
await 누락이 확인되어 Core 컴파일 FAIL(exit=1). UI 테스트는 실행되지 않았다.
Task 완료 지점에서 await로 캐시 actor에 진입하도록 수정했다.
generation 검사/구독자 취소/캐시 제한은 기존대로 유지한다.
수정 후 구조 검사 PASS. Swift 컴파일/Core/UI 재실행은 NOT TESTED.
재검증: scripts/check-artwork-mac.sh.


## A1 이미지 비동기 로딩·메모리 캐시 — 2026-10-16

CatalogArtwork가 실제 PNG를 비동기로 읽고 ImageIO로 최대 720px 다운샘플링한다.
6개 자체 생성 추상 PNG Fixture를 2,000개 콘텐츠의 visualSeed로 재사용한다.
선택적 artworkURL이 있으면 HTTPS 로더를 사용하고 없으면 번들 이미지로 오프라인 동작한다.
로딩/실패 시 기존 그라데이션·아이콘 placeholder를 유지한다.

원본 16MiB LRU, 이미지 1개 최대 8MiB, 디코딩 이미지 24MiB LRU.
동일 URL 요청은 합치며 마지막 구독자 취소 시 작업을 취소한다. 이전 세대의 완료는 무시한다.
SwiftUI task(id:)와 generation 검사로 화면 이탈/이미지 변경 후 늦은 UI 반영을 막는다.
이 수치는 캐시 자체의 한도이며 표시 중 이미지, URLSession 캐시 등 전체 프로세스 메모리 한도는 아니다.

Core 캐시/취소 테스트 5개 추가. 구조/shell PASS. Swift/Core/Xcode/UI NOT TESTED.
실제 HTTPS 서버/시각 QA/Instruments 메모리 측정도 NOT TESTED.
검증: `caffeinate -i bash scripts/check-artwork-mac.sh`
직전 4836ed2 사용자 로그: Core 59개 + A3 실제 플레이어 UI 1개 PASS.


## A3 플레이어 연동 · 가상 기기 A/B — 2026-10-16

직전 30b9e54의 Core 56개와 A3 시뮬레이션 8개는 사용자 Mac 로그에서 PASS 확인.
이번 변경은 Debug 상세 화면의 가상 기기 A/B 선택을 실제 AVPlayer 진도 저장/복원에 연결한다.
로컬 저장은 기존 UserDefaults 경로를 유지하고 Mock 모드는 서버 값만 사용한다.
앱 내 두 가상 기기는 프로세스 공용 Mock을 공유하며 프로필/작품/회차 키를 분리한다.
닫기 저장 후 다음 열기 순서, FIFO 체크포인트→restart, 충돌 이후 저장 차단 Core 테스트 3개와
A 재생→B 복원→restart→A 초기화 UI 테스트 1개를 추가했다.

이번 변경: 구조/shell PASS. Swift/Core/Xcode/UI NOT TESTED.
실제 기기 간 네트워크, 서버 영속 저장, 홈 계속 시청 레일의 서버 연동은 아직 미구현.
30초 로컬 영상으로 UI 검증하며 정확한 25:40은 기존 Core 테스트에서 검증한다.
실행: `caffeinate -i bash scripts/check-progress-playback-mac.sh`


## A3 기기 간 진도 복원 Mock — 2026-10-16

- 도메인 계약, actor 서버 Mock, 기기별 클라이언트 구현.
- 25:40 복원, revision 충돌 거절, restart=0 새 revision, UUID 중복 처리.
- 지연/역전 응답, 같은 revision 동시 쓰기, 프로필/콘텐츠/회차 격리 자동 테스트 8개 추가.
- 구조/shell 검사 PASS. Swift/Core 실행은 NOT TESTED.
- 기존 AVPlayer/UserDefaults에 연결한 것은 아님. 실제 기기 간 네트워크와 영속 서버는 미구현.
- 실행: `caffeinate -i bash scripts/check-progress-sync-mac.sh`
- 설계: Docs/ADR/0021-multi-device-progress-revisions.md

직전 af5a25e 사용자 로그: Core PASS, 미디어 복구 UI 4개 PASS,
오디오 메인 스레드 경고 미관측 PASS. 실제 OS 리셋/실기기 성능/전체 회귀는 NOT TESTED.


## 오디오 세션 비동기 큐 처리 — 2026-10-15

사용자 제공 db001a0 검증 로그: Core 48개(15 XCTest + 26 + 7 Swift Testing),
UI 4개 PASS. QoE rejected transition 0. 단, UI 로그에서 AVAudioSession
메인 스레드 응답성 경고 4회 발견. 이 결과는 경고 없음 PASS가 아니다.

수정: process-wide PlaybackAudioSession 직렬 큐에서 category/activation/deactivation을
처리한다. 플레이어는 활성화 성공 후 MainActor에서 생성하며 generation/session/UUID를
검사한다. stop은 즉시 UI/플레이어를 정리하고 비동기 release를 제출한다.
이전 재생의 release는 소유 UUID가 다르면 새 재생을 비활성화하지 않는다.
iOS 18 호환 API를 유지하며 메인 큐를 동기 대기시키지 않는다.

check-media-recovery-mac.sh에 실제 UI 로그의 오디오 메인 스레드 경고 검사를 추가했다.
수정 후: 구조·shell 구문 PASS. Xcode 빌드, Core/UI, 런타임 경고 제거 NOT TESTED.
실제 OS 리셋/실기기 PiP/전체 회귀 및 HLS 회차 테스트도 아직 미검증이다.


## 미디어 리셋·재시도 한도 — 2026-10-15

리셋 알림의 generation/session 검사, 기존 플레이어/Task/PiP 정리,
사용자 재시도 시 새 플레이어/오디오 세션 준비 추가. 자동 재시도는 0회,
사용자 요청은 같은 표시/소스에서 최대 3회. 소진 UI에 남은 횟수를 표시한다.
리셋된 객체의 현재 위치를 저장하지 않고 마지막 정상 진도를 유지한다.
Core 예산 테스트 3개, 리셋 주입/한도 소진 UI 2개와 회귀 2개를 전용 스크립트로 실행.

PASS: 프로젝트 구조/스크립트 구문. NOT TESTED: 수정 후 Xcode/Core/UI,
실제 OS 미디어 서비스 재시작, 리셋-프로필/seek 경쟁, 실기기 PiP.
앞서 014a074의 실제 HLS 회차 테스트 결과도 아직 받지 않아 NOT TESTED 유지.
이번 코드는 관측 reducer 전체를 AVPlayer 명령 상태 머신으로 바꾼 것은 아니다.
검증: scripts/check-media-recovery-mac.sh, ADR 0019.



## HLS 테스트 시즌 연결 — 2026-10-15

이전 48ec545 검증: 사용자 core(5).log XCTest 12개 + Swift Testing 33개 PASS,
트랙 fallback/자막 UI 2개 PASS. 실제 HLS 누락 트랙은 여전히 NOT TESTED.

새 구현: 플레이어 소스 메뉴에 HLS 테스트 시즌 1~2화. 기존 Apple 공개 샘플
bipbop 및 오디오 비교 URL을 재사용하되 고유 progressID로 로컬 진도를 분리.
1화 종료 시 기존 10초 카운트다운/취소/지금 재생을 거쳐 2화 이동.
2화에는 nextEpisode가 없으므로 마지막 종료. HLS 실패 알림/PiP 정책도 재사용.
실제 작품 회차/신규 콘텐츠 업로드/상세 회차 목록 서버화는 이번 범위가 아니다.

새 opt-in UI 2개: 실제 HLS 종료 seek/자동 이동/마지막 종료,
회차 간 새 진도/저장 위치 복원. 외부 서버 접속 실패는 실패로 남긴다.
전용 스크립트는 두 테스트의 passed 로그까지 확인하여 skip을 성공 처리하지 않는다.
PASS 구조/스크립트 구문. NOT TESTED 새 Swift 빌드/UI 실재생, 장시간 자연 종료,
실기기/네트워크 단절 중 회차 전환. Docs/HLS_EPISODES_QA.md 참조.



## A2 트랙 대체 처리 보강 — 2026-10-15

이전 bf55787 사용자 첨부 검증: Core XCTest 8개 + Swift Testing 7개 PASS,
선택 UI 4개 PASS, QoE 요약/invalid_transitions=0 확인.
이는 이번 변경의 통과 근거가 아니라 이전 버전 검증 이력이다.

이번 변경: native 선택 직전 isPlayable 확인, 빈 playable 목록 안내, 재요청 시
이전 그룹/목록 제거. 선호 언어는 fallback으로 덮어쓰지 않는다.
TrackFallbackTests 4개 및 없는 한국어→복원→재실행→B 프로필 분리 UI 테스트 추가.
PASS 구조 검사/스크립트 구문. NOT TESTED Swift/Core/UI 실행, 실제 HLS 트랙 장애 통합 검증.

남은 A 순서: 트랙 대체 검증 → 실제 HLS 회차 → 네트워크 재시도 한도/미디어 서비스
리셋 → 상태 전이 효과 통합/QoE 실측 → A1 이미지 로더 → A3 revision 서버 Mock.
A 전체 완료로 표시하지 않는다.



## A2 계측 추가 — 2026-10-15

사용자 보고: check-detail-episodes-mac.sh TEST SUCCEEDED, 이후 프로필 전용 오프라인
배너/홈·상세 로컬 탐색/HLS 취소·재시도 5개 수동 항목 정상. 사용자 보고 PASS로 기록하며
새 계측 코드나 전체 회귀가 통과했다는 근거로 사용하지 않는다.

구현: PlaybackDiagnostics 관측 상태 reducer, 초기 대기/seek 제외 rebuffer 횟수·시간,
first-frame-ready 관측 지연, 실패/무효 전이, access-log observed bitrate,
종료 시 익명 attempt 요약. 실제 AVPlayer 명령 전체의 상태 머신 재구성은 아직 아니다.
Core 결정적 테스트 5개 및 scripts/check-playback-qoe-mac.sh 추가.
PASS: 프로젝트 구조 검사, 스크립트 구문 검사.
NOT TESTED: Swift 컴파일/Core/UI 테스트, 실기기 HLS 계측, 최신 전체 회귀.
A2 전체 완료 아님: 미디어 서비스 리셋, 정밀 성능 보고 및 전체 상태 효과 검증은 남아 있다.



## 최신 결과 — 2026-10-15 18:35 KST

RESULTS(20261015-093546).txt 및 ui-tests(20261015-093546).log:
- PASS testDetailEpisodeSelectionAndProgress (43.434초): 2화 선택, seek, 진행 표시,
  다른 회차 기록 분리 및 재진입 복원 검사 통과.
- FAIL testLargeTextAccessibilityAudit (11.800초): 홈 home-category-나의 리스트,
  Text clipped. 총 2개 중 1개 실패, exit=65.
- ViewThatFits 후보 측정 대신 AnyLayout으로 동일 카테고리 버튼의 축을 전환하고
  접근성 크기에서 가용 너비/다중 행/내용 높이를 사용하도록 보정.
- 수정 후 구조 검사 PASS. Mac 컴파일/접근성 재실행 NOT TESTED.
- 전체 회귀, HLS 알림/네트워크 변화, 실기기 PiP는 이번 실행 범위 밖이다.



2026-10-12 사용자 승인으로 시작했다. 아래 날짜별 항목은 당시 검증 이력이다.

## 회차 선택 및 홈 Dynamic Type 재검증 — 2026-10-15 18:30 KST

사용자 RESULTS(20261015-093039).txt / ui-tests(20261015-093040).log:
FAIL detail-episodes exit=65, 2개 실행 2개 실패.
회차 식별자는 이번 실행에서 발견되며 2화 버튼 탭 후 재생 중까지 도달했다.
51행에서 playback-source-label의 2화 검사가 실패했다. 진도 저장 검증은 도달하지 못했다.
최대 글자 감사는 홈 home-category-추천에서 dynamicType 부분 미지원으로 실패했다.

- 상세의 Bool 표시 + 별도 Source 상태를 optional Source 기반 fullScreenCover(item:)로 통합.
  선택 소스를 cover 인자로 전달하고 플레이어 identity에 포함해 초기 소스 캡처 불일치를 방지.
- 홈 카테고리는 글자 크기에 따른 ScrollView/VStack 교체 대신 ViewThatFits로 가로/세로 배치.
  버튼에 semantic headline 폰트를 적용. 감사 실패 무시/제외는 하지 않는다.
- 회차 소스 assertion에 실제 label을 추가해 재실패 시 원인을 확인 가능하게 했다.
- PASS: 구조 검사. NOT TESTED: 수정 후 Swift 컴파일, UI 및 Dynamic Type 감사.
  이전 최대 글자 PASS와 달리 이번 실행은 FAIL이며 재실행 전 해결 확정하지 않는다.

## 회차 목록 첫 실행 결과 및 접근성 식별자 보정 — 2026-10-15

사용자 RESULTS(20261015-080516).txt: FAIL detail-episodes exit=65.
ui-tests(20261015-080516).log: 총 2개, 1개 실패.
- testLargeTextAccessibilityAudit: PASS (68.735초).
- testDetailEpisodeSelectionAndProgress: FAIL (28.483초). 재생 시작 전에
  detail-episode-2 Button을 찾지 못했다. 회차 진행 복원은 아직 검증되지 않았다.

실패 계층에는 이름이 합쳐진 1/2/3화 Button이 있으나 지정한 identifier는 없다.
카드 장식 후 붙인 accessibilityElement(children: .ignore)를 제거하고 Button에
label/value/identifier를 직접 적용한 뒤 장식을 붙이도록 수정한다.
테스트의 식별자 검증을 우회하거나 텍스트 매칭으로 바꾸지 않는다.
누락 진단에서도 없는 element.identifier를 읽지 않고 계층/스크린샷을 저장한다.
PASS: 수정 후 구조 검사. NOT TESTED: 수정 후 Xcode 및 같은 UI 테스트 재실행.

## 상세 미리보기 및 데모 회차 목록 — 2026-10-15

- 대표 아트워크에 데모 미리보기 버튼을 추가했다. 자동/인라인 재생이 아닌 기존
  전체 화면 플레이어로 번들 데모를 재생한다. 실제 예고편 파일은 아직 없다.
- 별도 DetailEpisodeSection에 데모 시즌 1의 1~3화 썸네일/설명/30초 길이를 표시한다.
  시즌은 하나이므로 다른 시즌 선택 기능은 제공하지 않는다. 실제 작품 회차가 아니다.
- 각 회차를 해당 Source로 열어 기존 자동 다음 화 및 마지막 화 종료를 재사용한다.
- 기존 프로필/작품/소스별 PlaybackProgressStore로 진행률을 읽으며 닫기/복귀 시 갱신한다.
  완료/마지막 구간은 기존 저장 정책에 따라 이어보기 기록이 제거된다.
- 세 회차는 같은 30초 MP4를 사용한다. UI에 명시한다. 큰 글자에서는 세로 카드 배치.
- 회차2 선택/seek/닫기/진행 표시/다른 회차 분리/재진입 복원을 확인하는 UI 테스트 추가.
- scripts/check-detail-episodes-mac.sh: 새 테스트 및 기존 최대 글자 감사 실행.
- PASS: 구조 검사, 스크립트 bash 구문 검사. NOT TESTED: Xcode/Swift 6 빌드,
  새 UI 테스트, 화면/VoiceOver/회차 자동 연결의 실제 실행. 실제 기기 PiP도 여전히 미검증.

## 화면별 오프라인 정책 확정 — 2026-10-15

프로필 선택에만 ProfileNetworkBanner를 추가한다. 해당 화면에서 경로 변경을
관찰하고 이탈 시 정리하며, 재진입/활성화 시 새 monitor로 재확인한다.
이전 콜백은 세대 검사로 무시한다. 홈/검색/상세/플레이어에는 배너가 없다.
HLS 실패의 취소/재시도 및 취소 시 상세 이동은 ea988ea 구현을 유지한다.

홈/검색/상세는 이미 MockCatalogRepository의 번들 catalog.json만 읽으며
URLSession 호출이 없다. 네트워크가 없어도 로컬 카탈로그를 탐색한다.
재생 이력은 기존 UserDefaults를 사용한다. SQLite/Core Data 기반 로컬 DB나
원격 카탈로그 캐시는 아직 미구현이며 이번 변경에서 구현했다고 간주하지 않는다.
NWPathMonitor는 경로 관찰이므로 Wi-Fi 뒤 외부 인터넷 장애까지 확정하지 않는다.
PASS: 프로젝트 구조 검사. NOT TESTED: 새 코드 Xcode/Swift 6, 프로필 배너
연결 전환/재진입, HLS 알림 실제 동작 및 전체 회귀.

## 배너 제거 및 외부 재생 오류 알림 — 2026-10-15

사용자 요청으로 기존 네트워크 배너 및 감지 객체를 제거했다.
HLS의 실제 PlaybackModel failed 상태에 취소/재시도 alert를 연결한다.
취소는 플레이어 정리 후 상세 복귀이며 홈 직접 재생은 cover onDismiss 이후
해당 콘텐츠 상세로 이동한다. 재시도는 기존 load를 사용하고, 재실패도 알림 표시한다.
NWPathMonitor의 false 값으로 URL 재생을 미리 차단하지 않는다.
버퍼 재생/AVPlayer 오류 전달 및 기존 30초 제한 때문에 알림에 시간이 걸릴 수 있다.
PASS: 프로젝트 구조 검사. NOT TESTED: Xcode/Swift 6, 알림 재시도/취소 이동,
전체 UI 회귀, 실제 HLS 단절/복구. NETWORK_STATUS_QA.md를 현재 절차로 교체했다.

## 전체 화면 전환 시 연결 감지 수명 보정 — 2026-10-15

사용자 스크린샷에서 플레이어의 빨간 배너 잔류를 다시 확인했다.
기존 root .task가 fullScreenCover로 가려질 때 취소되면 defer에서 monitor도
해제되고 마지막 false 상태가 남을 수 있는 구조를 확인했다. 실제 기기의
콜백 로그가 없으므로 이번 재현 원인으로 확정하지는 않는다.

NetworkConnectionStatus가 NWPathMonitor를 직접 소유하고 root onAppear에서
중복 없이 시작하도록 변경했다. 화면 onDisappear와 task 취소로 중단하지 않는다.
앱 활성화 시 새 monitor로 갱신하고, 이전 monitor 이벤트는 세대 검사로 무시한다.
콜백은 weak self와 Bool만 사용해 MainActor에서 반영한다. 소유 객체 해제 시 취소한다.
NetworkStatus 로그에 시작/경로 이벤트를 남겨 재발 시 관찰 지속 여부를 확인한다.
재생 여부와 무관한 빨간 배너 정책은 유지한다.
PASS: 구조 검사. NOT TESTED: Swift 6/Xcode, 실제 전체 화면 중 연결 복구.

## 앱 공통 실시간 연결 배너 — 2026-10-15

사용자는 프로필 관리에서만 보이는 안내를 홈/검색/상세/플레이어에서도 원하며,
네트워크 변경을 화면 이동 없이 반영하도록 요청했다.
이 항목은 아래 플레이어 전용/재생 중 숨김 정책을 대체한다.

- AppRootView가 한 NetworkConnectionStatus를 소유하고 환경 객체로 전달한다.
- 프로필 선택과 CatalogTabs 각각에 배너를 배치해 NavigationStack 상세에도 유지한다.
- 전체 화면 PlaybackView도 동일 환경 객체의 배너를 표시한다.
- NWPathMonitor 경로 변경 콜백을 지속 관찰한다. 활성화 시 새 monitor로 갱신하며
  취소 시 해제/세대 검사로 이전 관찰의 업데이트를 차단한다.
- 경로 없음이면 재생 여부와 무관하게 빨간색, 복구면 해제한다. 영상 실패는 기존
  플레이어 오류/재시도에 맡긴다. 재생 중 배너를 강제로 숨기는 코드를 제거했다.
- 외부 인터넷/HLS 서버 접속 검사는 추가하지 않았다. 경로 감지의 한계와 실기기
  검증 절차는 NETWORK_STATUS_QA.md에 명시한다. 이전 잔류 배너의 원인은 미확정이다.
- PASS: 프로젝트 구조 검사. NOT TESTED: 새 코드 Xcode/Swift 6 빌드, UI 회귀,
  실제 연결 전환, 전체 화면 환경 객체 전달/레이아웃 및 접근성.

## 네트워크 배너와 실제 재생 상태 분리 — 2026-10-15

사용자는 기존 자동 회귀 TEST SUCCEEDED를 보고했으나 실제 영상 재생 중 빨간
배너가 남는다고 보고했다. 첨부 사진 시점에는 로딩 표시도 함께 보인다.
경로 감지 지연인지 버퍼 재생인지 사진만으로 원인을 확정하지 않는다.
정상 재생 중이며 seek 중이 아니면 배너를 숨긴다. 내부 경로 상태를 online으로
조작하지 않으며, 로딩/일시정지 중 경로 불가 안내는 중립색으로 표시한다.
빨간색은 실제 PlaybackModel 실패 상태에만 사용한다. 재생/재시도 정책은 유지한다.
PASS: 프로젝트 구조 검사. NOT TESTED: 수정 후 Xcode 빌드/UI/수동 재현 검증.

## HLS 네트워크 상태 배너 — 2026-10-15

- NWPathMonitor의 연결 경로 상태를 HLS 플레이어 상단 배너로 표시한다.
- 경로 사용 가능은 인터넷/HLS 서버 도달 보장이 아니다. 영상 실패 안내와 구분한다.
- 연결 끊김 중 버퍼 재생을 막지 않으며 복구 이벤트로 play/load/seek를 호출하지 않는다.
- 오류 재시도는 기존 재생 다시 시도 버튼을 사용한다. 일반 일시정지는 유지한다.
- 오프라인 데모에서는 관찰하지 않는다. 화면 task 취소 시 monitor를 해제하고,
  Sendable Bool 스트림과 MainActor 상태/세대 검사로 오래된 콜백을 차단한다.
- 배너는 safe-area inset으로 닫기 버튼과 겹치지 않도록 공간을 확보한다.
- PASS: Python 프로젝트 구조 검사. NOT TESTED: Xcode 빌드, Swift 6 타입 검사,
  UI 회귀, 새 배너의 VoiceOver/Dynamic Type/실제 네트워크 전환.
- 수동 절차: [NETWORK_STATUS_QA.md](NETWORK_STATUS_QA.md).

### 변경 전 사용자 수동 확인

일반 홈 전환 시 소리 중단, 복귀 시 일시정지, 수동 재생 정상: PASS (사용자 보고).
HLS 로딩 중 닫기 정상 및 실제 네트워크 복구 후 다시 재생 정상: PASS (사용자 보고).
연결 표시만 뜨고 실제 연결이 안 된 경우 재생되지 않았으며, 실제 연결 후 재생됐다.
실제 기기 PiP, 오류 상태 프로필 전환, 버튼 없는 자동 복구: NOT TESTED.

## PiP 버튼 가시성 및 준비 상태 — 2026-10-15

사용자 RESULTS(20261015-030013).txt에서 PASS pip-regression exit=0 확인.
이는 선택된 기존 재생 회귀 테스트 결과이며 실제 PiP 및 전체 회귀 PASS가 아니다.
이후 iPhone 18 Pro / iOS 27 시뮬레이터의 HLS 오디오 재생 화면에서 PiP 버튼이
없고 홈 진입 시 일시정지한다고 보고했다. 스크린샷에서도 버튼이 보이지 않는다.
이전 코드는 supported=false일 때 버튼을 숨겼다. 스크린샷만으로 API 반환값이나
실행 앱 버전을 확정하지 않으며, 새 화면에 지원 여부와 준비 상태를 명시한다.

버튼을 항상 표시하되 미지원/준비 전에는 비활성화하고 안내 문구를 추가했다.
지원 여부를 강제로 활성화하지 않는다. PiP를 시작하지 않은 일반 홈 진입의
일시정지는 기존 정책이며 자동 PiP는 이번 변경 범위가 아니다.
구조 검사 PASS. 이번 UI 수정의 Xcode 빌드·회귀·실제 PiP는 NOT TESTED.

## PiP Swift 6 프로토콜 격리 수정 — 2026-10-15

사용자 제공 RESULTS(20261015-023645).txt: FAIL pip-regression exit=65.
ui-tests 로그는 PlaybackPictureInPicture의 AVPictureInPictureControllerDelegate
conformance가 nonisolated 요구와 충돌해 빌드가 실패했음을 보여준다.
UI 테스트는 실행 전에 취소되었으므로 테스트 assertion 실패가 아니다.

컴파일러가 제시한 isolated conformance를 적용해 프로토콜 채택에도 @MainActor를
명시했다. 객체 상태와 delegate 설치는 계속 MainActor에 한정한다.
Swift 6 strict concurrency / warnings-as-errors를 유지하며 @preconcurrency나
@unchecked Sendable로 검사를 우회하지 않는다. isolated conformance 문법은
Swift 6.2 이상 컴파일러가 필요하며 사용자 도구는 Swift 6.4다.
수정 후 구조 검사 PASS. Xcode 재빌드·UI 테스트·PiP 런타임은 NOT TESTED.
같은 scripts/check-pip-mac.sh로 재검증한다.

## PiP 구현 추가 — 2026-10-15

- HLS에서 AVPictureInPictureController + 기존 AVPlayerLayer로 작은 화면 재생을 요청한다.
- 전체 화면 cover를 유지해 같은 플레이어로 복귀한다. PiP X는 일시정지/진행 저장,
  앱의 닫기·소스 변경·프로필 invalidate는 PiP와 기존 AVPlayer를 정리한다.
- 명시적 버튼으로만 시작한다. 일반 백그라운드 진입은 기존대로 일시정지한다.
- AVAudioSession playback/moviePlayback 및 Info.plist background audio를 추가했다.
- 네이티브 PiP의 재생/정지 상태를 샘플링하며 시작 지연 10초를 취소한다.
- 오프라인 데모 SRT는 SwiftUI overlay이므로 PiP 대상에서 제외했다.
- 구조 검사 PASS. Apple SDK가 없는 Linux 작성 환경에서 Xcode 빌드, Swift 6 타입 검사,
  UI 테스트, 실제 PiP/자막/오디오/복귀/메모리는 모두 NOT TESTED.
- 기존 자막 seek, 일반 백그라운드 일시정지, 이어보기 회귀 테스트를 묶은
  scripts/check-pip-mac.sh를 추가했다. 이 스크립트 PASS가 실제 PiP PASS를 의미하지 않는다.
- [ADR 0015](ADR/0015-hls-picture-in-picture.md), [수동 QA](PIP_QA.md) 참조.

### PiP 추가 전 사용자 HLS 수동 확인

2026-10-15 시뮬레이터에서 인터넷 끊김 시 오류 표시, 재연결 후 재시도 버튼으로
실제 영상 재생, 오류 상태에서 닫고 다시 열어 재생 성공을 보고했다: 해당 항목 PASS (사용자 보고).
오류 후 화면 방향 복원, 뒤에서 소리 없음, 로딩 중 닫기, 버튼 없는 자동 복구는 NOT TESTED.
이번 PiP 수정 후 재검증 결과와 혼동하지 않는다.

## 최신 검증 상태 — 2026-10-15

사용자 제공 `RESULTS(20261014-172104).txt`에서 fixtures, project-structure,
bootstrap, generated-project-structure, core, simulator-build, ui-tests,
warning-free 모두 exit=0 / PASS 확인. 작성 환경에서 실행한 결과가 아니다.
해당 요약 파일에는 실행 SHA와 테스트 개수가 없으므로 그 정보는 단정하지 않는다.
앞서 제공된 Core 개별 실행은 36개 PASS, 화면 왕복은 60회 PASS,
subtitle-seek-iKAhvy 자막 재검증은 1개/0 failures (72.348초) PASS이다.

기존 실패들은 후속 재검증 및 전체 자동 gate에서 통과했다. 간헐적
시뮬레이터 지연의 근본 원인을 특정하거나 재발 불가를 보장하지 않는다.
최신 전체 실행의 수동 VoiceOver, Dynamic Type, 런타임 경고, 기기별 화면,
Instruments는 NOT TESTED다. 이전 수동 확인은 별도 이력으로 유지한다.

다음 작업: [실제 HLS 네트워크 복구 검증](HLS_RECOVERY_QA.md).
이 문서 갱신에서 앱 코드는 바꾸지 않았다. Phase 2 전체 완료 선언은 아니다.

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

### 2026-10-13 슬라이더 제스처 간섭 가능성 제거
RESULTS(20261013-124816).txt / ui-tests(20261013-124817).log: 단일 UI FAIL(exit=65). 일시정지는 통과했으나 50% 슬라이더 조작 후 13~17초 표시 조건에서 실패했다. 실제 값은 로그에 없어 원인 확정은 불가하다. 홈 이어보기 및 회전 복원 단계는 미도달.
이전 변경의 상위 DragGesture를 제거하고 iOS 18+ onScrollPhaseChange로 스크롤 중 숨김을 제어한다. 슬라이더 입력에 별도 드래그 인식기를 추가하지 않는다. 기존 5초/13~17초 검사 기준을 유지하며 실패 시 실제 시간·슬라이더 값과 화면/계층 진단을 추가한다.
구조 검사 PASS, 수정 후 Xcode/UI/회전 복원 NOT TESTED.

### 2026-10-13 전체 화면 종료 후 회전 복원 시점 수정
단일 UI 로그(ui-tests(20261013-125623).log)는 최초 상세 재생의 일시정지/50% 시킹을 통과했지만 닫기 후 원래 프레임 402×874 복원에서 FAIL(exit=65)했다. 사용자 스크린샷에서도 상세 화면이 가로 방향으로 남았다.
회전 세션을 Home/Detail의 각 재생 presentation이 소유하도록 변경했다. 닫기/이탈 때는 늦은 회전 요청만 차단하고, fullScreenCover의 onDismiss에서 원래 방향을 한 번 복원한다. 새 재생마다 새 세션을 만든다.
10초 제한과 원래 프레임 비교는 유지하며, 최초 상세 재생 종료 실패에도 실제 프레임/닫기 버튼 상태/화면/계층을 남긴다.
구조 검사 PASS. 수정 후 Xcode 빌드·단일 UI·전체 회귀·실기기 회전은 NOT TESTED. 재검증: bash scripts/check-home-playback-mac.sh.

### 2026-10-13 재생 전 방향 저장 및 회전 진단 추가
312c901 재검증: RESULTS(20261013-131720).txt / ui-tests(20261013-131718).log에서 단일 UI FAIL(exit=65). 닫기 버튼은 사라졌지만 예상 402×874 대신 실제 874×402로 남았다. onDismiss 복원 변경만으로 해결되지 않았다.
기존 코드는 플레이어 브리지의 최초 요청에서 원래 방향을 저장하고, 재생 시 회전 객체를 교체했다. 이제 Home/Detail의 StateObject로 동일 객체를 유지하고, 해당 화면의 WindowScene을 연결해 재생 버튼에서 begin()으로 회전 전 방향을 저장한다. 복원은 onDismiss에서 실행한다. UIKit 브리지 업데이트도 현재 세션을 동기화한다.
정확한 이전 런타임 실패 원인은 아직 미확정이다. OSLog에 begin/capture/request/finish 및 거절 오류를 기록하고 단일 테스트 스크립트가 orientation.log로 수집한다. 테스트의 10초/정확한 프레임 조건은 유지한다.
PASS: 프로젝트 구조, 스크립트 bash 문법. NOT TESTED: 새 Swift 코드 컴파일, iOS 단일 UI, 전체 회귀 및 실제 회전.

## 2026-10-14 연속 재생 데모
영상 소스 메뉴에서 '연속 재생 데모 · 1화'를 선택하면 3화짜리 로컬 데모 시퀀스를 실행한다.
세 화는 같은 30초 무음 MP4/SRT를 재사용하며 실제 서로 다른 드라마 에피소드가 아니다.
기존 오프라인 데모와 HLS는 단일 영상 동작을 유지한다. 카탈로그에 실제 시즌/회차 데이터 연결은 후속 작업이다.

- 재생 의도가 활성화된 상태로 영상 종료 시 10초 카운트다운 후 다음 화로 전환한다.
- 자동 전환 취소 / 다음 화 지금 재생을 제공한다. 3화 종료 후에는 멈춘다.
- 백그라운드 진입과 소스·자막 메뉴 열기는 카운트다운을 취소한다. 취소 후 반복 샘플링으로 자동 재시작하지 않는다.
- 각 전환은 기존 load/stop 경로를 사용해 이전 Task를 취소하고 Repository에서 현재 프로필 권한을 재검사한다.
- 같은 작품이라도 화별 sourceID를 사용해 진행 기록을 분리한다. 홈 이어보기는 저장된 화의 소스를 복원한다.
- 다음 화 전환 시 자막 선택은 기존 소스 변경 정책에 따라 초기화된다. 자막 선호 저장/복원은 후속 작업이다.

검증: 구조 검사 및 셸 문법 PASS. 새 Core 테스트 3개, UI 테스트 2개, Swift 6 컴파일 및 실제 재생은 NOT TESTED(현재 실행 환경에 Swift/Xcode 없음).
Mac: bash scripts/check-episodes-mac.sh (UI 2개만 실행). Core: swift test --package-path Packages/StreamLabCore.

### 이전 코드 검증 증거
RESULTS(20261013-132842).txt: 홈 이어보기/방향 복원 단독 PASS.
RESULTS(20261013-140519).txt: fixtures/구조/bootstrap/Core/빌드/warning-free PASS, UI 21개 중 20 PASS/1 FAIL.
실패한 60회 왕복은 접근성 snapshot 수집 416.20초 지연을 동반했다. 사용자 수동 일시정지/잠자기 없음 보고. 근본 원인 미확정.
ui-tests(20261013-151947).log: 코드 변경 없는 단독 재실행에서 60/60회 완료, 1 test/0 failures, 502.977초 PASS.
전체 실행 실패와 단독 재실행 성공은 별도 기록이며 21개 동시 PASS 또는 간헐적 지연 해결로 해석하지 않는다.

## Profile language preferences (2026-10-14 KST)

- Added profile-scoped subtitle/audio persistence and restoration on item load,
  episode advance and re-entry. Missing language fallback does not erase preferences.
- Added audible-track selection to the existing subtitle sheet, loading/error/retry,
  and an explicit silent-demo message. Native subtitle mandatory selection is respected.
- Core resolver/store tests and UI restoration/profile isolation tests added.
  Old subtitle re-entry reset expectation now expects the saved selection.
- `scripts/check-languages-mac.sh` runs Core plus two focused UI tests and records
  exit codes. Core and Xcode products use a fresh `/private/tmp` build directory;
  evidence remains under Docs/Validation/languages-*. No source/xattr deletion.
- PASS: local project-structure validator and shell syntax check.
- NOT TESTED here: Swift type checking, Mac Core tests, Xcode simulator build/UI tests,
  Swift concurrency warnings, actual HLS alternative audio listening, full regression.
- Previous commit 87106fd evidence: supplied RESULTS(20261013-154820).txt reports
  PASS episode-playback exit=0. User screenshot confirms episode 3 ended with no
  next-episode button/countdown. This is not a full-suite PASS for this new change.
- Limitations: demo episodes reuse one silent video; language preferences do not
  distinguish multiple same-language SDH/commentary renditions. Real HLS QA remains required.

### Language validation follow-up (2026-10-14 KST)

Supplied RESULTS(20261013-162502).txt: Core PASS exit=0; language UI FAIL
exit=65 (2 tests, 2 failures). Both reached playing, then failed while finding
playback-source / playback-toggle. Failure hierarchy still contains
playback-reveal-controls; this does not establish a player dismissal. The four-second
control auto-hide can occur during the helper's snapshot/hittability waits.
The helper now rechecks reveal after a short wait, with the existing eight-attempt
bound and final hittability assertion. Cache the target identifier before it disappears
so diagnostics do not throw an additional missing-element error. No production
auto-hide behavior changed. Fix runtime result: NOT TESTED pending Mac rerun.
StreamLabUITests-Runner.app is the XCTest runner, not a duplicate production app.

### Visible playback controls hit targets (2026-10-14 KST)

- User rerun: Core PASS; two language UI tests FAIL. The bounded-wait change did
  not resolve the failure. Screenshot and hierarchy show source/pause inside
  the landscape viewport, with a full-screen playback-surface Button also present.
- Suspected accessibility hit-target overlap: remove the full-screen Button while
  controls are visible. Keep the reveal Button only in the hidden state; blank
  content background handles hide taps without becoming an accessibility element.
  Auto-hide timing, VoiceOver/large-text restrictions and actual button assertions
  remain unchanged. Existing language tests exercise source, pause and subtitle taps.
- PASS: project-structure validator. NOT TESTED here: Xcode compilation and runtime
  fix, language UI rerun, full regression, VoiceOver interaction. Mac verification
  with scripts/check-languages-mac.sh is required before claiming resolution.

### Full regression evidence and home large text follow-up (2026-10-14 KST)

- User RESULTS(20261013-231912).txt: Core and language-playback PASS after
  playback hit-target separation. Actual HLS alternate audio listening NOT TESTED.
- User RESULTS(20261013-235952).txt and ui-tests(20261014-000002).log:
  fixtures, structure, bootstrap, Core, simulator build and warning-free PASS;
  UI suite FAIL: 24 tests, 1 failure (23 passed). Language persistence and playback
  tests passed. testLargeTextAccessibilityAudit failed on home with Text clipped.
  XCTest supplied no element, so the exact offending label is not established.
- At accessibility text sizes, home categories now use a vertical list with
  wrapping labels; hero actions explicitly stack vertically, hero eyebrow/play
  labels take their full multiline height, and decorative top spacing is reduced.
  Accessibility audit assertions remain unchanged; no clipping issue is ignored.
- PASS local project-structure validation. NOT TESTED: this change's Xcode build,
  targeted large-text audit, full regression and manual accessibility/layout review.

### Automated regression baseline and real HLS audio QA source (2026-10-14 KST)

- User RESULTS(20261014-004947).txt: fixtures, both structure checks, bootstrap,
  Core, simulator-build, ui-tests and warning-free all PASS on the prior revision.
  The report leaves manual accessibility, runtime diagnostics, layouts and
  Instruments NOT TESTED for that run. It does not prove real HLS listening.
- Add a separate Apple trailer HLS source with English / English (DVS), a distinct
  progress key, and shared native HLS subtitle/audio loading and retry paths.
  Bundled SRT cues must never be used for either HLS source.
- PASS: master fetch and inspection (en-US regular + DVS); local structure check.
  NOT TESTED: new revision Xcode build/UI tests, audible switching, real multilingual
  HLS restoration. Same-language rendition persistence remains unimplemented.
- Docs/HLS_AUDIO_QA.md defines the manual comparison and prevents conflating track
  selection metadata with audible output or English DVS with another language.

### Custom language panel (2026-10-14 KST)

- User requested the supplied two-column dark language selector reference.
- Replace the native subtitle sheet with an in-player modal overlay: audio left,
  subtitles right, independent scrolling, leading checkmarks, muted unselected
  labels and a fixed top-right close button. Portrait/narrow layouts and
  accessibility text sizes use a single scrolling column. Underlying playback
  controls are excluded from touch/accessibility while the panel is open.
- Choices apply immediately and keep the panel open; close or VoiceOver escape
  returns to playback controls. No invented language tracks or decorative divider
  separating arbitrary languages. Loading/error/retry states remain available.
- Existing language UI tests now assert selected state and explicit close behavior.
- PASS: local structure validation. NOT TESTED here: Xcode build, focused UI tests,
  rendered layout, panel VoiceOver traversal and full regression on this revision.
- Prior source manual evidence: user reports audible English playback and added
  DVS narration after switching. PASS (user-reported manual listening), not an
  automated result. General HLS subtitle display has not yet been confirmed.

### Audio role persistence (2026-10-14 KST)

- User reports focused language UI TEST SUCCEEDED and custom panel manual layout,
  selection and close behavior normal on the previous revision (9a18389).
- Implement profile-scoped language + ordinary/audio-description preference.
  Existing v1 JSON without role decodes without losing subtitle/audio settings.
  Source fallback does not overwrite the preference; automatic clears role.
- Add three Core tests covering migration/persistence/profile isolation/reset,
  role matching after playlist reorder, and missing-role/language fallback.
- PASS: local project structure. NOT TESTED here: Swift compilation, new Core tests,
  Xcode/UI regression and actual HLS DVS restoration on this revision. No Swift or
  Xcode executable is available in this environment.
- ADR 0014 and HLS_AUDIO_QA steps 6–10 describe policy and manual acceptance checks.
  Same-language same-role commentary differentiation remains unimplemented.

## 2026-10-14 — Profile playback progress report and hardening

- User reports focused language tests succeeded after simulator restart; DVS
  selection survives player reopening and app relaunch (manual user evidence).
- OPEN / FAIL (user reported): a previously unwatched profile resumed HLS at
  another profile's position. Root cause is not established from static review.
- Bind cover player identity explicitly to session + title. New progress records
  include profile/title/source ownership, checked on both lookup and recent list.
  Legacy v1 records remain readable under their existing profile-scoped keys;
  this does not retroactively identify any incorrectly written legacy record.
- With no matching saved position, HLS VOD explicitly seeks to zero before play.
- Debug PlaybackProgress logs report fresh/restore, profile, title, source and
  restored seconds. No user records are deleted or reset by this update.
- Add Core tests for A/B independent positions after store recreation and rejection
  of a record copied under another profile's key.
- PASS: local project structure validator. NOT TESTED: new Swift tests, Xcode
  build, simulator regression and reported real HLS reproduction. Linux host has
  no Xcode. This is defensive hardening plus diagnostics, not a confirmed fix.

## 2026-10-14 — Playback time display

- User reports B starts near zero after the 6527114 update: manual PASS for that
  reported A-to-B reproduction only; original root cause and full regression
  remain unverified. No assertion that all profile-isolation cases are closed.
- Render elapsed/scrubbing time and duration as HH:MM:SS, with unbounded hours,
  zero-padding and safe handling of invalid/negative values. Slider VoiceOver
  value uses Korean hours/minutes/seconds. Skip and countdown labels stay seconds.
- Update existing UI test time expectations to the new display format.
- PASS: project structure validation. NOT TESTED: Xcode build, updated UI tests
  and device layout/VoiceOver for this revision (Xcode unavailable here).

## 2026-10-15 — Full regression failures and Core compile correction

- Uploaded run 20261014T114911Z-OQGZXr: fixtures, project structure, bootstrap,
  generated structure, simulator build and build-warning scan PASS.
- Core FAIL before tests ran: PlaybackProgressTests.swift nested #require in
  UserDefaults.set produced a redundant-require diagnostic with warnings-as-errors.
  Replace it with guard-let and Issue.record on missing setup data; retain all
  cross-profile rejection assertions. Do not disable warnings-as-errors.
- UI FAIL: 24 executed, 22 passed, 2 failed. Navigation soak failed at cycle 47/60
  waiting for detail-title to disappear, with roughly 1024-second stalls and an
  animation-completion notification timeout earlier in the trace. Root cause open.
- Subtitle selection/restoration failed finding playback-close after reopening.
  Control auto-hide/test synchronization is a hypothesis, not a confirmed cause.
- User manually confirmed playback landscape entry and original orientation
  restoration on exit. This is not a full automated regression PASS.
- Core correction: Xcode/Swift test execution NOT TESTED here (no Apple toolchain).
  Both UI failures remain unresolved; no full-suite PASS claimed.

## 2026-10-15 — UI synchronization corrections (runtime validation pending)

- User-uploaded Core rerun on 15b3168: PASS, 3 XCTest + 26 presentation +
  7 catalog tests; warnings-as-errors build completed.
- HUD lookup now rechecks the reveal button during the initial existence wait,
  rather than waiting 12 seconds for a control hidden by the four-second timer.
  Production auto-hide remains enabled and its dedicated test is unchanged.
- Home detail entry waits for loading to finish and the back button to become
  hittable before issuing another action. Back dismissal still must remove
  detail-title within five seconds; no repeated back taps or relaxed assertions.
- Back failures now attach screenshot and accessibility hierarchy. Long
  animation-notification stalls remain an unconfirmed app/runner issue.
- check-ui-recovery-mac.sh runs only the two failed tests, retains exit status
  and xcresult, and caps each test at 900 seconds using XCTest time allowances.
- PASS: local structure validation and shell syntax. NOT TESTED: Apple Swift
  compilation and corrected UI execution here. Both UI issues require Mac rerun.

## 2026-10-15 — Seek completion before subtitle assertions

- Uploaded ui-recovery-eBrLRn: navigation soak PASS, all 60 cycles (467.029 s).
  Subtitle test FAIL at forward-seek caption; close/reopen stage was not reached.
- Failure screenshot shows a loading indicator, target label 15 s, and old
  burned-in video frame. An optimistic target label is not completed seek evidence.
- Expose seek pending/success/error through playback-time accessibility value.
  Test waits for successful completion, sampled time, no loading/error, and paused
  state before exact caption assertions. Timeout still fails, with diagnostics.
- No change to AVPlayer seek policy or watchdog; simulator seek-stall cause remains
  unresolved until focused reproduction. No system Accessibility bundles modified.
- New check-subtitle-seek-mac.sh selects only the failing subtitle test.
- PASS: local structure and shell syntax. NOT TESTED: new Apple compilation,
  UI test and VoiceOver behavior; no claim that playback engine stall is fixed.
