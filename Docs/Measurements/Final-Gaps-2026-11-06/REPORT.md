# 잔여 8항목 보완

2026-11-06. [과제 점검표](../../ASSIGNMENT_AUDIT_2026-11-06.md)의 8개 미완료 단위를 대상으로 구현과 검증 근거를 추가했다. 구현 완료와 실기기 검증 완료를 분리한다. 제출 태그와 이미 만든 영상·ZIP·PDF는 당시 버전으로 보존한다.

| 항목 | 이번 변경 | 판정 근거 |
|---|---|---|
| B1 로컬 DB | 프로필별 SQLite, projection/outbox/metadata 원자 커밋, 기존 JSON 이전 | Core·실제 HTTP·100건 SIGKILL 회귀 통과, 기존 API 유지 |
| C3 VoiceOver | 플레이어 컨테이너 설명 보완, 재생·자막 경로 접근성 자동 감사 | 설명·터치 영역 검사 통과. 실제 iPhone의 음성/초점 전체 경로는 대기 |
| C4 백그라운드 다운로드 전력 | 전송·백그라운드·완료·삭제 표식과 전용 FirebaseRelease Scheme | 측정 도구 준비. 실제 백그라운드 전력 결과는 대기 |
| C4 동일 조건 전후 비교 | 같은 빌드의 C/PV, 10초 준비·30초 5왕복 자동 스크롤 | 두 화면 왕복 UI 검증 통과. 실제 표시 프레임 비교는 대기 |
| D 자동 CI 근거 | 앱 인수 9개와 F06/F09·정상 HLS 다운로드 3개를 원격 workflow에 연결 | 원격 실행 결과를 확인 후 기록 |
| E2 README 재현 | 첫 실행/Mock/Firebase/검증 명령 분리, 새 시뮬레이터 smoke 600초 gate | 로컬 새 DerivedData + 시뮬레이터 150초, 최종 회귀 154초. 원격 새 checkout 결과 확인 예정 |
| E4 상태도 | Player/Download Mermaid, 오류·취소·복구·수명 경계 | 실제 reducer/adapter 코드와 대조 |
| DATA1 샘플 사용조건 | 자체 생성 fixture와 Apple 예제 URL·출처·이용 범위 명시 | 외부 영상 바이너리 재배포/상업 이용 허가와 구분 |

## 로컬 근거

- Core: XCTest 31개 + Swift Testing 247개(234 Presentation + 13 Catalog), 세 카오스 suite 각각 1,000 seed. `Docs/Validation/http-boundaries-CuyohB`.
- F03: 두 번 SIGKILL, 세 번 재시작, 100건의 효과 중복/손실 0. `Docs/Validation/mutation-process-UEQ6dM`.
- SQLite 신규 4개: 기존 값/ID/FIFO 이전, INSERT 중 실패 전체 롤백, 손상/미지원 schema 거부, 두 저장소 인스턴스와 삭제 뒤 쓰기 거부. 전체 회귀에서 함께 실행.
- 집중 UI: C/PV 자동 스크롤과 접근성 경로 3개 통과. `/private/tmp/streamlab-final-focused.xcresult`와 로그는 로컬 원본이며 저장소에는 요약·해시를 보관한다.
- 새 시뮬레이터 빌드·로그인·재생 smoke 2개 통과. 전체 앱 인수/네이티브 다운로드 회귀는 실행 결과를 추가한다.

초기 iOS 빌드에서 macOS Homebrew SQLite가 연결되는 문제를 발견해 pkg-config를 제거하고 대상 SDK의 SQLite만 링크하도록 고쳤다. 플레이어 접근성 감사에서는 이름 없는 화면 컨테이너가 발견돼 작품명·영상 플레이어라는 설명을 추가했다. 검사를 제외하지 않고 같은 감사의 통과를 확인했다.

## 남아 있는 실기기 증빙

[실기기 순서](../../FINAL_DEVICE_QA.md)에 VoiceOver 1경로, 백그라운드 다운로드 전력 1파일, 자동 C/PV 비교 4파일을 정리했다. 기존 I/O·HLS 전력·메모리 기록은 유효 범위에서 유지한다. 새 측정 전에는 성능 개선, 배터리 절감, VoiceOver 전체 경로 완료를 주장하지 않는다.

SQLite 쓰기는 현재 MainActor에서 동기 실행하며 모든 projection/outbox를 트랜잭션으로 교체한다. 이 변경 자체를 성능 최적화로 설명하지 않는다. 새 C/PV 비교에는 같은 DB 구현을 적용해 렌더링 조건만 바꾼다.
