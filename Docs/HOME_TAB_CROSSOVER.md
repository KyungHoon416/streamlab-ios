# 동일 빌드의 기존/명시적 탭 교차 비교

## 목적과 구성

`home-chrome-explicit-tabs-1.trace`는 기존 baseline보다 초기 hang이127.299→182.436ms,
프로필 선택~첫 홈 layout이304.235→366.401ms로 늘었다. 열 상태도Nominal→Fair로 달라
코드만의 효과를 확정할 수 없다. 추가 구조 변경 전에 같은 바이너리에서 두 구현을 비교한다.

두 구현은 동일 StreamLab 타깃/Release 바이너리에 함께 컴파일된다.
Scheme의 런타임 인자만 다르며 전처리 플래그/소스/데이터 구현은 공유한다.
`--trace-home-startup` 활성 상태에서만 `--startup-tab-builder=legacy|explicit`을 적용한다.
인자가 없거나 잘못됐거나 중복이면 explicit을 사용하며 값을 저장하지 않는다.
일반 실행 기본값은 현재 구현(explicit)을 유지한다.
기존은 ForEach+tabItem+tag, 새 구현은 명시적 Tab 선언이다.
NavigationStack, 각 탭 path, 방문한 화면 상태, 툴바, 지연 생성 조건은 공유한다.
모드별 StartupTabsLegacy / StartupTabsExplicit 표식으로 실제 실행 분기를 확인한다.

## 실기기 측정: A1 → B1 → B2 → A2

| 순서 | 모드/Scheme | 바탕화면 저장 이름 |
| --- | --- | --- |
| 1 | A / StreamLab-Tabs-Legacy | home-tabs-cross-A1.trace |
| 2 | B / StreamLab-Tabs-Explicit | home-tabs-cross-B1.trace |
| 3 | B / StreamLab-Tabs-Explicit | home-tabs-cross-B2.trace |
| 4 | A / StreamLab-Tabs-Legacy | home-tabs-cross-A2.trace |

1. 최신 main을 한 번 pull한다. 이후 네 측정 사이 코드/빌드 설정을 바꾸지 않는다.
2. 앱 삭제/데이터 초기화/Clean Build Folder를 하지 않는다. 같은 프로필/시청 기록을 유지한다.
3. 각 회차 사이 기기를 식히고 밝기·충전·저전력 모드 조건을 맞춘다.
4. 표의 Scheme 선택 → Product → Profile. 두 Scheme은 동일 Release 제품을 사용한다.
   앱 프로세스는 매번 새로 시작한다. B2도 B1 앱 세션을 이어 녹화하지 않는다.
5. 매 회차 새 Instruments 문서에서 Animation Hitches + Points of Interest + Time Profiler로
   앱 시작부터 기록한다. 여러 Run을 한 파일에 누적하지 않는다.
6. 프로필 화면에서 약2초 기다린 뒤 같은 성인 프로필 선택.
7. 홈에서 스크롤/재생/탭 전환 없이10초 대기하고 중지한다.
8. 표의 이름으로 저장한다. 이전 측정 파일은 덮어쓰지 않는다.

ABBA 순서는 실행 순서에 따른 단순한 시간 경향을 양쪽에 나눠보려는 배치다.
캐시/온도 차이를 완전히 통제하거나 반복2회만으로 통계적 유의성을 보장하지 않는다.
이전 no-tabs/no-toolbar Scheme은 이번에 사용하지 않는다.

## 분석 기준

모드 표식과 공통 C/trace/baseline 인자, 실제 열 상태, 기록 유효성을 먼저 확인한다.
프로필 선택 시점 기준으로 첫 hang/app update, SessionInit, 세션~홈 모델 구간,
HeroFirstLayout, 홈 데이터 및 이어보기 후속 갱신을 비교한다.
A/B 각각 두 기록의 범위와 중앙값을 보여주되 전체 합계를 단순 속도 개선율로 쓰지 않는다.
실행 순서/열 상태/세션 준비 시간 차이를 함께 보고 이득·회귀·판정 유보를 구분한다.
HeroFirstLayout은 실제 표시 완료가 아니며, async 대기는 main hang이 아니다.
영상 탐색 관련 미해결 UI 실패는 이번 비교와 별개다.

## 자동 검증 결과 (2026-10-29)

- 두 Scheme의 Launch/Profile Release 및 공통/모드별 인자 검사 통과.
- Legacy 및 Explicit Release 기기용 빌드 통과(warnings-as-errors, 서명 제외).
- 같은 DerivedData에서 두 Scheme을 순서대로 빌드한 StreamLab 실행 파일 SHA-256 일치:
  `39c9fec6f54ef316c3303711800c512fc54f7d93ebc6a62f3b705d800e85dbfb`.
  이 해시는 로컬 검증 바이너리의 값으로, 사용자 기기 빌드에 동일 해시를 요구하지 않는다.
- iOS 26.5 UI: Legacy 통과. Explicit은 첫 시도에서 탭 화면 진입 전 데모 로그인 대기 실패,
  같은 빌드 단독 재실행에서 통과. 상세 왕복 및 홈/검색/다운로드 전환 검증.
- 두 테스트가 최초 묶음 실행에서 모두 통과한 것은 아니다.
- 이전 7개 탭 회귀 검증에 더해 새 옵션 경로를 검증했다. 실기기 성능 판정은 미완료다.
