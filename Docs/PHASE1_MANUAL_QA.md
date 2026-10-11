# Latest manual evidence — 2026-10-12 08:36 KST

This summary supersedes pending statuses in the historical checklist below.

- **PASS (user report):** VoiceOver profile selection, home exploration, search → detail, pagination and profile isolation. Playback/Phase 2 notice had earlier user confirmation.
- **PASS (user report):** maximum Dynamic Type retry text and loading message without clipping/overlap; earlier search/detail text checks confirmed.
- **PASS (user report):** compact iPhone/iPad layout checklist; exact device names not supplied.
- **PASS (limited):** 20 home/detail/back cycles after clean Profile build; CatalogStore persistent 2, transient 36, total 38 in Allocations screenshot. DetailViewController name-filtered persistent list empty.
- **NOT TESTED:** 40/60-cycle comparison, profile-switch memory series, successful Leaks scan, complete memory/performance acceptance.
- **FAIL:** runtime warning-free; top-left back can emit glassEffect warning, with no reported freeze/flicker.
- **PASS:** all automated gates in RESULTS(7).txt. Automated results do not certify manual tests.

Received trace archive and SHA-256, screenshot measurements, earlier Profile crash and analysis limitations are recorded in [PHASE1_REPORT.md](PHASE1_REPORT.md). Native Instruments replay was not performed by the assistant. Keep the saved trace; no need to repeat completed checks merely to reproduce these screenshots.

---

# Historical checklist and evidence

# Phase 1 수동 검증

Core 17개·UI 8개는 이전 실행 PASS다. 현재 UI 테스트는 9개이며 최신 전체 실행은 NOT TESTED다. 아래 표는 제한된 수동 확인과 미검증 범위를 구분한다. 실측 없이 PASS로 바꾸지 않는다.

기록: Git SHA / 날짜 / Xcode / iOS / 기기 / 검사자 / 증거 파일 경로.

## 1. VoiceOver — 실제 iPhone 권장

설정 > 손쉬운 사용 > VoiceOver를 켠다. 오른쪽 쓸기로 다음 요소, 두 번 탭으로 실행한다. 자동 접근성 감사 통과는 이 수동 검사를 대체하지 않는다.

| ID | 순서 | 통과 기준 | 결과 |
|---|---|---|---|
| VO-01 | 프로필 화면을 순서대로 탐색 | Alex, Jamie, Kids 이름과 버튼 역할을 읽고 각 프로필 선택 가능 | NOT TESTED |
| VO-02 | 홈에서 히어로와 레일 탐색 | 제목을 읽고 스크롤로 화면 밖 콘텐츠에 접근 가능, 초점 갇힘 없음 | NOT TESTED |
| VO-03 | 검색 탭에서 검색어 입력 후 결과 선택 | 검색 필드 이름, 콘텐츠 제목·등급을 읽고 상세로 이동 가능 | NOT TESTED |
| VO-04 | 더 보기 실행 | 로딩 안내를 읽고 완료 후 결과 탐색 가능, 초점이 사라지거나 갇히지 않음 | NOT TESTED |
| VO-05 | 상세에서 재생 버튼 실행 후 안내 닫기 | Phase 2 안내를 읽고 닫은 뒤 화면 조작 가능 | PASS: 사용자 보고, 이전 상세 화면 기준 |
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

## 4. 빌드 및 런타임 경고

114d734에서 제공된 RESULTS(6).txt: **PASS simulator-build exit=0**, **PASS warning-free count=0**. AppIntents 명시적 링크 이후 해당 Mac Debug Simulator 빌드에서 경고가 사라졌다.

실행 중 glassEffect 경고는 최초 1회 후 반복되지 않았고, 멈춤·깜빡임 없이 상세가 바로 열린다고 사용자가 확인했다. 기능 전환은 제한된 수동 PASS, 경고 자체는 미해결이다. OS 원인으로 확정하거나 전체 런타임 경고 0개로 표시하지 않는다.

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

## 최신 완료 조건 — 2026-10-12 01:23 KST

- 남은 VO-01~04/06을 수행하고 읽힌 문구·초점 이동·실행 결과를 기록한다.
- DT-01의 검색 입력까지 확인한다. 기존 스크롤/페이지네이션/상세 캡처는 제한된 PASS다.
- DT-02는 느린 Mock으로 확인하고, 새 상세 재시도 버튼도 최대 글자로 확인한다.
- 작은 iPhone 및 iPad 화면은 NOT TESTED다. 레일/검색/상세의 잘림과 회전을 확인한다.
- Instruments 표를 측정한다. 기존 Leaks 수집 실패는 도구 오류이므로 NOT TESTED로 유지한다.
- 빌드 경고 검사는 통과했다. 새 UI 9개는 verify-mac.sh로 실행한다.
- 위 과정을 완료해도 최초 glassEffect 경고의 해결 또는 명시적 예외 승인이 없으면 경고 없는 런타임 완료로 표시하지 않는다.
