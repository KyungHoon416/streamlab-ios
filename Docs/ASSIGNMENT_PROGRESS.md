# 원본 과제 진행 체크리스트 — 2026-10-15

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

## 최신 재실행 — 2026-10-15 18:30 KST

RESULTS(20261015-093039).txt: FAIL, 2개 중 2개 실패.
회차 식별자 조회는 해결됐지만 2화 재생 소스 검사 실패.
최대 글자 감사는 홈 추천 버튼 dynamicType 검사 실패.
이전 표의 최신 최대 글자 PASS는 아래 과거 실행에 해당하며 이번 결과를 우선한다.
Source 기반 cover 및 카테고리 적응형 레이아웃 수정 후 Mac 재검증 NOT TESTED.

## 이전 실행 증거

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
