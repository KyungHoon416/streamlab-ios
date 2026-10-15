# 원본 과제 진행 체크리스트 — 2026-10-15

기준: Netflix_iOS_과제.docx 8쪽 원문. Phase 번호와 과제 A/B/C/D는 서로 다른 구분이다.
아래는 구현/검증 현황이며 루브릭 점수나 전체 완료율이 아니다. 세부 요구사항 전체를
충족하고 최신 코드에서 검증한 영역만 완료로 취급한다. 과거 PASS는 최신 회귀 PASS가 아니다.

| 범위 | 구현 현황 | 검증 근거 및 남은 작업 |
|---|---|---|
| A1 홈·탐색 | 대부분 구현 | 3프로필, 2,000개 fixture, 검색/페이지네이션/키즈 제한. 과거 Core/UI PASS. 네트워크 이미지 로더는 설계 단계; 다운로드 가시성 미구현 |
| A2 재생·트랙 | 주요 기능 구현 | HLS, 제어, 자막/음성, 위치 복원, 자동 다음 화 사용자/자동 테스트 PASS 이력. 동일 30초 영상 3회차 데모이며 실제 시즌 데이터 아님 |
| A2 상세 회차 UI | 구현 후 보정 중 | 최신 최대 글자 테스트 PASS. 회차 선택 테스트 FAIL: detail-episode-2 식별자 없음. 수정 후 재실행 NOT TESTED |
| A2 복구·상태·QoE | 부분 구현 | 네트워크 복구 사용자 확인. 새 취소/재시도 알림은 NOT TESTED. 전체 상태 전이 불변식, 미디어 리셋 및 QoE 지표 검증 미완료 |
| A3 멀티 기기 복원 | 미구현 | 현재 프로필별 로컬 진도. 서버 revision, 기기 간 경쟁, 처음부터 보기 action 계약 필요 |
| B1 Local-first | 부분 기반 | 번들 JSON 및 UserDefaults는 영속 mutation DB/큐가 아님. 최근 검색/찜/진도 DB, 계정 격리, 재실행 큐 복구 필요 |
| B2 충돌 해결 | 미구현 | 409, idempotency, revision, Retry-After/backoff/jitter 필요 |
| B3 동시성 | 부분 구현 | Strict Concurrency 빌드 PASS 이력, 취소/세대/프로필 격리. 401 8건 single-flight 및 전체 불변식 검증 필요 |
| C1 다운로드 | 미구현 | HLS 다운로드, 최대 2개, 1GB 예산, pinned/LRU, 디스크 부족/재실행 복구 필요 |
| C2 보안 | 부분 기반 | 키즈/프로필 접근 제한 있음. Keychain 인증, entitlement/DRM Mock, 로그 마스킹 및 로그아웃 정책 필요 |
| C3 접근성 | 구현 및 부분 검증 | VoiceOver/Dynamic Type 사용자 확인, 최신 최대 글자 UI PASS. 새 회차 및 고대비/Reduce Motion 전체 경로 확인 필요 |
| C4 성능 계측 | 미완료 | 누수 없음 사용자 관찰 이력. 실기기 HLS 20회 TTFF p50/p95, 프레임 p50/p95, retained 비교, 에너지/디스크 보고 필요 |
| D 카오스 10종 | 미완료 | 일부 race/취소/네트워크 테스트가 있어도 F01~F10 전체 seed/fake clock/로그/CI 통과 근거는 없음 |
| 제출 산출물 | 부분 완료 | 프로젝트, README, ADR, 테스트 있음. 충돌/다운로드 ADR 및 상태도, 성능 보고서, 장애 2개 포함 5분 영상 필요 |

## 최신 실행 증거

- RESULTS(20261015-080516).txt: FAIL detail-episodes exit=65.
- ui-tests(20261015-080516).log: 2개 실행, 1개 실패.
- PASS testLargeTextAccessibilityAudit (68.735초).
- FAIL testDetailEpisodeSelectionAndProgress (28.483초), 재생 이전 회차 버튼 조회 실패.
- 식별자를 Button에 직접 부여하도록 수정; 수정 후 Mac 빌드/UI는 NOT TESTED.
- 실제 기기 PiP, 최신 전체 회귀, 새 HLS 알림/프로필 배너는 NOT TESTED.

## 다음 순서

1. 회차 선택·진도 테스트 재실행 및 새 오프라인 정책 수동 확인.
2. A2 상태 머신/복구 경계와 QoE 계측을 보완하고 실기기 확인.
3. A3 서버 Mock/revision 기반 멀티 기기 복원을 완료.
4. B 영속 DB/큐/충돌 → C 다운로드/보안 → D 통합 카오스 및 제출 계측.

원문은 다운로드 압축률이나 Firebase 관리자 웹을 필수로 지정하지 않는다.
이 두 항목과 4K 저장 전략은 사용자 추가 범위이며 원본 A~D 완료와 별도 관리한다.
전체 백분율은 검증되지 않은 기능을 완료로 계산하지 않기 위해 현재 확정하지 않는다.
