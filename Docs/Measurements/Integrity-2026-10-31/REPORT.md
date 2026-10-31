# 오프라인 데이터 충돌·복구 회귀 검증

2026-10-31. 초기 화면 성능 조사는 증거 한계를 기록하고, 다음 검증으로 현재 코어의 데이터 정합성 회귀를 실행했다. 테스트 대상 앱 코드 기준은 80dc849이며 이번 수정은 검증 스크립트/문서뿐이다.

## 결과

- Core 247개 PASS: XCTest 31개 + Swift Testing 209개 + Catalog 7개. seed 반복은 테스트 수에 더하지 않았다.
- 영속 큐 카오스: 1~1000 seed, seed당 24개 이벤트. 응답 유실/재실행/이벤트 순서에 따른 수렴 검증.
- 도메인 충돌 카오스: 1~1000 seed. My List·진도 restart·검색 삭제 정책, 변경 순서, 응답 유실/연결 오류, 큐·Mock 서버 재열기 검증.
- 가상 시계 재시도 카오스: 1~1000 seed. 429/503/timeout, Retry-After·jitter, backoff 도중 취소 등 기존 테스트의 불변식 검증.
- 컴파일 warnings-as-errors 및 strict-concurrency=complete. 실행 exit 0, 경고/에러 행 없음.

## 이번 보완

check-domain-chaos-mac.sh는 전체 코어를 실행하지만 기존 최종 판정은 도메인 충돌 suite/seed 완료만 확인했다. 이제 세 suite의 통과와 각각의 정확한 seed 완료 표식을 모두 요구한다. seed 수가 다르거나 테스트 exit가 실패면 PASS를 출력하지 않는다. 재현용 STREAMLAB_CHAOS_SEED 지정 시 각 suite 1개 seed 완료를 요구한다.

실제 전체 실행에서 새 판정 PASS. 추가로 완료 로그, 6개 필수 결과 각각 누락, 테스트 exit 실패, 잘못된 seed 수의 9가지 판정 확인을 통과했다. bash 문법 및 diff 검사도 통과했다.

## 검증 범위와 남은 항목

| 범위 | 상태 |
|---|---|
| 로컬 영속 큐·Mock 충돌·재시도 정책 | 이번 자동 회귀 PASS |
| 실제 HTTP/서버 장애 경계 | 해당 별도 스크립트 증빙을 다음 단계에서 확인·실행 필요 |
| iOS UI·OS 백그라운드 상태와 결합된 장애 | 이번 실행 범위 아님; 기존 개별 증빙 유지 |
| Part D F01~F10 전체 대응 | 원문 시나리오별 매핑/통합 증빙 미완료 |
| 원격 CI 실행 | 이번 로컬 실행으로 대체하지 않음 |
| 초기 성능 문제/C4 전체 합격 | 별도 미판정 유지 |

새 구현 범위나 과제 F 번호를 임의로 만들어 완료 처리하지 않는다. 다음은 실제 HTTP 전송 계층과 인증 만료/로그아웃 경계의 기존 검증 스크립트를 확인하는 순서다. 지금 사용자의 추가 실기기 측정은 필요 없다.

## 재현

`bash scripts/check-domain-chaos-mac.sh`

특정 seed 재현: `STREAMLAB_CHAOS_SEED=42 bash scripts/check-domain-chaos-mac.sh`.
전체 로그는 로컬 Docs/Validation/domain-chaos-Vjkfga/core.log에 있다. Git에는 요약 RESULTS.txt와 입력 해시 MANIFEST.json만 보존한다.
