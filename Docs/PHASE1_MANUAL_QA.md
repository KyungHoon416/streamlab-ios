# Phase 1 수동 검증

자동 테스트 Core 17개 및 UI 8개 PASS와 별도로 수행한다. 아래 상태는 실행 전이므로 모두 NOT TESTED다. 실측 없이 PASS로 바꾸지 않는다.

기록: Git SHA / 날짜 / Xcode / iOS / 기기 / 검사자 / 증거 파일 경로.

## 1. VoiceOver — 실제 iPhone 권장

설정 > 손쉬운 사용 > VoiceOver를 켠다. 오른쪽 쓸기로 다음 요소, 두 번 탭으로 실행한다. 자동 접근성 감사 통과는 이 수동 검사를 대체하지 않는다.

| ID | 순서 | 통과 기준 | 결과 |
|---|---|---|---|
| VO-01 | 프로필 화면을 순서대로 탐색 | Alex, Jamie, Kids 이름과 버튼 역할을 읽고 각 프로필 선택 가능 | NOT TESTED |
| VO-02 | 홈에서 히어로와 레일 탐색 | 제목을 읽고 스크롤로 화면 밖 콘텐츠에 접근 가능, 초점 갇힘 없음 | NOT TESTED |
| VO-03 | 검색 탭에서 검색어 입력 후 결과 선택 | 검색 필드 이름, 콘텐츠 제목·등급을 읽고 상세로 이동 가능 | NOT TESTED |
| VO-04 | 더 보기 실행 | 로딩 안내를 읽고 완료 후 결과 탐색 가능, 초점이 사라지거나 갇히지 않음 | NOT TESTED |
| VO-05 | 상세에서 재생 버튼 실행 후 안내 닫기 | Phase 2 안내를 읽고 닫은 뒤 화면 조작 가능 | NOT TESTED |
| VO-06 | 프로필 변경 후 Kids 선택 | 이전 프로필 검색 결과·계속 시청이 노출되지 않고 키즈 화면 탐색 가능 | NOT TESTED |

로딩이 너무 짧아 확인할 수 없으면 Debug 실행의 Scheme > Run > Arguments에 `--ui-test-slow-catalog`를 잠시 추가한다. 검사 후 제거한다. 개인정보가 없는 화면 녹화 또는 실패 단계와 읽힌 문구를 기록한다.

## 2. 큰 글자 수동 보완

설정의 더 큰 텍스트에서 손쉬운 사용 크기를 켜고 최대로 설정한다. 자동 감사는 프로필·홈·상세에서 통과했지만 검색과 로딩 카드까지 모두 검증한 것은 아니다.

| ID | 순서 | 통과 기준 | 결과 |
|---|---|---|---|
| DT-01 | 검색 입력, 결과 스크롤, 더 보기 | 제목·등급·버튼 잘림이나 겹침 없이 조작 가능 | NOT TESTED |
| DT-02 | 느린 Mock으로 로딩 카드 표시 | 안내 글자 잘림 없이 표시되고 화면 이동 가능 | NOT TESTED |

## 3. Instruments — Allocations와 Leaks

1. Xcode에서 StreamLab scheme과 기기를 선택하고 Product > Profile을 실행한다. 먼저 Release 설정/기기/OS를 기록한다. 측정 시 느린 Mock 인자는 제거한다.
2. Allocations로 앱을 실행하고 프로필 선택, 홈·검색·상세를 한 번씩 연 뒤 홈으로 돌아와 10초 안정화한다. 초기 캐시 예열을 위해 이 동작을 5회 반복한다.
3. Mark Generation으로 기준을 남긴다. 상세 진입 → 뒤로 가기를 20회 수행하고 홈에서 10초 기다린 후 다시 마킹한다. 이를 3묶음 반복한다.
4. 살아 있는 DetailViewController와 관련 CatalogStore 인스턴스 수, Persistent Bytes, 앱 메모리를 기록한다. 홈·검색 store는 화면 유지 목적상 살아 있을 수 있다. 상세 종료 후 상세 소유 객체가 반복 횟수에 비례해 누적되는지 확인한다.
5. 검색 더 보기 중 프로필 변경을 10회 반복하고 이전 프로필 화면/store가 누적되는지 확인한다. 회수되지 않는 객체는 Memory Graph/참조 경로로 확인한다.
6. Leaks로 같은 흐름을 검사하고 `.trace`를 저장한다. Leaks의 0건만으로 모든 retain cycle이 없다고 판정하지 않는다.

| 측정 | 기준 | 20회 | 40회 | 60회 |
|---|---|---|---|---|
| 살아 있는 상세 VC 수 | 미측정 | 미측정 | 미측정 | 미측정 |
| 상세 소유 store 수 | 미측정 | 미측정 | 미측정 | 미측정 |
| Persistent Bytes | 미측정 | 미측정 | 미측정 | 미측정 |
| 앱 메모리 | 미측정 | 미측정 | 미측정 | 미측정 |

판정: NOT TESTED. 반복에 비례하는 잔존 객체 증가 또는 앱 코드의 누수가 발견되면 FAIL로 기록하고 참조 경로를 첨부한다. 단순 메모리 수치의 일시 증가만으로 누수라고 단정하지 않는다.

## 4. App Intents 경고

현재 앱은 AppIntent/AppShortcut 구현과 AppIntents 의존성이 없다. 제공된 로그에서 메타데이터 추출 단계가 의존성 부재를 경고하며 건너뛰고, 앱 빌드와 UI 테스트는 성공했다. 이것은 Swift concurrency 진단과 구분해야 한다. Xcode 27에서 해당 경고를 제거하는 공식 지원 설정은 이번 조사에서 확인되지 않았다. 미확인 빌드 플래그나 사용하지 않는 프레임워크를 추가하지 않았다.

상태: 경고 잔존 / warning-free 판정 미충족. `scripts/check-build-warnings-mac.sh`로 별도의 새 빌드와 경고 목록을 보존할 수 있다. 빌드 성공과 경고 0개 여부를 별도로 기록한다. 실제 해결 또는 명시적인 허용 판단 전까지 미해결 항목으로 유지한다.

## 결과 공유 양식

- SHA / 기기 / OS:
- VO-01~06: PASS / FAIL / NOT TESTED
- DT-01~02: PASS / FAIL / NOT TESTED
- Instruments: PASS / FAIL / NOT TESTED, trace 경로:
- 발견한 문제와 재현 순서:
- 빌드 경고: 개수 / 로그 경로:

Phase 2는 위 미해결 사항을 정리한 뒤 진행한다.

## Subsequent user evidence and remaining scope — 2026-10-12

The earlier NOT TESTED table is the initial baseline. User follow-up confirms visible large-text search rows, detail text and Phase 2 alert (**PASS** for those captured layouts); pagination and HUD appearance also work (**PASS**, user report). Maximum-text HUD clipping remains **NOT TESTED**. Playback VoiceOver/alert interaction has limited user confirmation; do not mark all VO routes passed.

Leaks collection failed in Simulator (**NOT TESTED**, not PASS). No persistent DetailViewController after returning was reported by the user; full repeated-cycle memory measurements remain outstanding.

After the warning mitigation, run the warning audit again and check content push/pop, rapid back, retry during loading, and a cancelled swipe-back gesture. Both actual warning removal and these post-change runtime checks are **NOT TESTED** until performed on Mac.
