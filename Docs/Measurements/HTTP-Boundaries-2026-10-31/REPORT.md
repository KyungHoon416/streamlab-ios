# 실제 HTTP·인증 만료·로그아웃 경계 검증

2026-10-31. 기준 커밋 091db6c에 검증용 테스트·fixture·실행 스크립트를 추가했다. 앱 런타임 코드는 변경하지 않았다.

## 결과

Core 248개 PASS: XCTest 31개, Swift Testing 210개, Catalog 7개. 실제 HTTP 10개와 시스템 Keychain 1개를 활성화했고 필수 suite/완료 표식 모두 확인했다. warnings-as-errors, strict-concurrency=complete로 빌드·실행 exit 0, 컴파일 경고/오류 없음.

| 검증 | 결과 |
|---|---|
| URLSession 실제 loopback HTTP | redirect 미추종, chunked 크기 제한, 스트리밍 취소 PASS |
| 영속 큐 + 실제 HTTP | 응답 유실 후 재열기/중복 효과 방지, 충돌 snapshot 반영, 동일 body 재시도/예산, backoff 취소 PASS |
| 만료된 인증 + 실제 HTTP | 8개 401 요청이 갱신 1회를 공유하고 동일 body/id로 재전송 PASS |
| 갱신 HTTP 500 | 8개 요청 종료 및 후속 요청의 추가 갱신 차단 PASS |
| 로그아웃 + 실제 HTTP (추가) | 서버 수신 후 응답 보류 → invalidate → 성공 응답 해제. 결과는 invalidated, 후속 요청도 차단, 서버 수신 1회/갱신 0회 PASS |
| 인증 경계 단위 테스트 | 늦은 refresh, 만료 시간 초과, 재시도 401, 저장 실패, 로그아웃 호출자 취소, 오래된 세션 쓰기·삭제 차단 PASS |
| 영속 로그아웃 | 삭제 실패/재시작 후 차단 유지, 손상된 marker fail-closed, 명시적 재로그인/계정 분리 PASS |
| macOS 시스템 Keychain | 고유 서비스의 더미 항목 저장/재열기/갱신/계정 분리/삭제 및 정리 PASS |

실제 HTTP 테스트는 127.0.0.1의 3개 Python fixture와 URLSession을 사용한다. 인증 클라이언트의 URL만 loopback으로 라우팅하며 헤더·body·응답은 실제 HTTP를 통과한다. 인증·영속화 단위 테스트의 강제 오류는 제어된 테스트 대역을 사용한다. 모든 경계가 운영 서버와 연결된 하나의 종단 간 시나리오라는 뜻은 아니다.

## 변경

- 실제 HTTP 응답이 로그아웃 뒤 도착하는 회귀 테스트를 추가했다. 기존 구현은 정상 차단하므로 앱 코드 수정은 하지 않았다.
- check-http-auth-mac.sh도 새 로그아웃 완료 표식을 필수로 요구한다.
- check-http-auth-boundaries-mac.sh는 3개 fixture와 Keychain 검증을 한 번의 Core 실행으로 활성화한다. 종료 시 서버를 정리하며 9개 suite와 11개 표식을 모두 요구한다.
- 결과 판정 검증 22개 PASS: 완전한 결과, Swift 실패 exit, 20개 필수 행 각각 누락. bash 문법과 diff 검사 PASS.

## 재현 및 증거

`bash scripts/check-http-auth-boundaries-mac.sh`

macOS/Apple toolchain/Python 및 로컬 listener/더미 Keychain 접근이 필요하다. 기존 사용자 자격증명은 조회하지 않는다. 원시 로그는 로컬 `Docs/Validation/http-boundaries-M7PKHp/`에 보존하고 Git에는 요약과 SHA-256을 기록한다.

## 남은 범위

운영 인증 endpoint·TLS, iOS 잠금 상태 Keychain 보호, 앱 화면의 로그인/로그아웃과 연결된 전체 흐름은 이번 검증 범위가 아니다. Part D F01~F10 전체 및 원격 CI 합격으로 확대하지 않는다. 이 결과를 위해 추가 실기기 측정은 필요 없다. 다음 통합 단계는 실제 앱 인증 연결과 과제 원문 시나리오별 증빙 매핑이며, 운영 서버가 필요한 항목은 서버 준비 여부를 먼저 확인한다.
