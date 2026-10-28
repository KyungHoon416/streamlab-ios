# 초기 화면 공통 구성 분리 측정

목적: 남은 초기 106~145ms 지연에 탭 컨테이너와 프로필 툴바가 얼마나 관여하는지 비교한다.
성능 개선 배포가 아니라 진단용 비교 설정이다. 일반 실행의 기본 동작은 baseline이다.
`--trace-home-startup`과 유효한 단일 `--startup-chrome=` 인자가 함께 있어야 제외 모드를 적용한다.
값을 저장하지 않으며, 잘못된 값/중복 인자/trace 없는 실행은 baseline으로 돌아간다.

| 순서 | Scheme | 구성 | 바탕화면 파일명 |
| --- | --- | --- | --- |
| 1 | StreamLab-Startup-Baseline | 현재 탭·네비게이션·프로필 툴바 | home-chrome-baseline-1.trace |
| 2 | StreamLab-Startup-NoToolbar | 탭·네비게이션 유지, 로그아웃/프로필 툴바 항목 제외 | home-chrome-no-toolbar-1.trace |
| 3 | StreamLab-Startup-NoTabs | 탭 컨테이너 제외, 홈·네비게이션·툴바 유지 | home-chrome-no-tabs-1.trace |

세 Scheme은 모두 Release, `--home-render-experiment=C`, `--trace-home-startup`을 사용한다.
Launch와 Profile에 인자를 각각 지정한다. 일반 StreamLab 및 기존 StreamLab-Startup Scheme은 유지한다.
각 모드의 진입을 StartupChromeBaseline / StartupChromeNoToolbar / StartupChromeNoTabs 표식으로 남긴다.

## 측정 절차

1. 최신 main을 pull한다. 앱을 삭제하지 않고 같은 계정·프로필·시청 기록을 유지한다.
2. 기기를 식히고 밝기/충전/저전력 모드 조건을 일정하게 맞춘다.
3. 표 순서대로 Scheme을 바꾸고 매번 Product → Profile로 다시 실행한다.
4. 매번 새 Instruments 문서에서 Animation Hitches + Points of Interest + Time Profiler로 기록한다.
5. 앱 시작부터 기록하고, 프로필 화면에서 약 2초 기다린 뒤 같은 성인 프로필을 선택한다.
6. 홈에서 스크롤·재생·탭 전환 없이 10초 대기하고 중지한다.
7. 표의 이름으로 저장한다. 각 측정 사이 기기를 식힌다. 기존 파일은 덮어쓰지 않는다.

총 3개 파일로 먼저 비교한다. no-toolbar에서는 프로필 변경/로그아웃 버튼이 없고,
no-tabs에서는 하단 탭이 없는 것이 정상이다. 다음 측정은 앱을 종료하고 새 Scheme으로 실행한다.
측정이 끝나면 일반 사용용 StreamLab Scheme으로 돌아간다.

## 해석 범위

- 같은 코드의 세 기록을 프로필 선택 시점에 정렬하고 실제 thermal을 확인한다.
- no-toolbar는 사용자 정의 툴바 항목만 제거한다. 네비게이션 바와 제목/상세 뒤로가기는 유지한다.
- no-tabs는 탭 바를 숨기는 옵션이 아니라 TabView 자체를 제거한다.
  가용 높이와 화면에 보이는 콘텐츠 양이 달라질 수 있어 순수 탭 아이콘 비용으로 해석하지 않는다.
- 홈 저장 데이터/조회 지연/콘텐츠 구현은 동일하다. 뷰포트 변화에 따른 lazy 생성량 차이는 가능하다.
- 초기 main hang, app update, HomeDataReady/HeroFirstLayout, 이어보기 후속 갱신을 함께 본다.
- 첫 레이아웃 표식은 실제 표시 완료 시각이 아니다. async 대기를 메인 정지 시간으로 합산하지 않는다.
- 한 번씩의 차이는 원인 후보를 좁히는 자료다. 통계적 개선 보장이나 개별 함수의 독점 원인 증명이 아니다.
- 이전의 영상 탐색 완료 대기 UI 실패는 이 실험과 별도로 남아 있다.

## 자동 검증 (2026-10-28)

- Release 기기용 빌드 통과(warnings-as-errors, 서명 제외).
- 세 Scheme의 Launch/Profile 모두 Release 및 C/trace/각 모드 인자 일치 검사 통과.
- iOS 26.5 시뮬레이터 UI 4개 통과: baseline, no-toolbar, no-tabs,
  trace 없는 no-tabs 인자 무시. 홈 콘텐츠 표시, 버튼 구성, 상세 진입/복귀 확인.
- iOS 27 시도는 접근성 초기화 시간 초과 및 테스트 런너 시스템 오류로 테스트 시작 전에 실패했다.
  해당 시도는 앱 기능 검증 통과/실패 건수에 포함하지 않았다.
- 실기기 성능 차이는 아직 미측정이다.

## 실기기 비교 결과와 후속 변경 (2026-10-29)

세 trace는 모두 모드 인자와 표식이 일치했고 열 상태가 전 구간 Nominal이었다.

| 항목(ms) | baseline | no-toolbar | no-tabs |
| --- | ---: | ---: | ---: |
| 초기 main hang | 127.299 | 99.784 | 92.846 |
| 세션 종료~홈 모델 생성 | 62.395 | 59.337 | 21.470 |
| 프로필 선택~HeroFirstLayout | 304.235 | 270.175 | 264.004 |
| 이어보기 후 app update | 14.889 | 14.545 | 14.193 |

탭 제외에서 홈 모델 시작 전 구간이 가장 뚜렷하게 줄었다. 다만 1회씩의 순차 측정이고
SessionInit도 각각 15.551/7.774/10.150ms로 달라, 차이 전체가 탭/툴바의 순수 비용은 아니다.
탭 제외 시 뷰포트 변화도 포함된다. 툴바 제외의 총 hitch는 기준보다 늘었다.

### 명시적 Tab 구성

기존 ForEach가 생성하는 View에서 tabItem/tag를 붙이던 방식 대신,
홈/검색/다운로드를 각각 SwiftUI `Tab(title, systemImage, value)`로 선언한다.
탭 메타데이터와 콘텐츠의 구조를 분리해 TabContent builder에 직접 전달한다.
앱의 최소 배포 대상 iOS 18에서 지원되는 API임을 설치 SDK로 확인했다.

- TabView 및 네이티브 탭 기능을 유지한다. 제목·아이콘·선택 값·순서는 같다.
- 탭별 독립 navigation path, 미방문 콘텐츠의 지연 생성, 방문한 콘텐츠 상태를 유지한다.
- 알림 이동 시 경로 초기화와 다운로드 선택, 프로필 전환/로그아웃 동작을 유지한다.
- 진단용 no-toolbar/no-tabs는 유지하며 일반 실행은 탭이 있는 구성이다.
- trace가 활성화된 탭 구성에서 `StartupTabsExplicit` 표식을 남긴다.
- SwiftUI 내부에서 정확히 얼마의 초기 구성이 생략되는지 이 코드만으로 보장하지 않는다.
  앞 실험은 TabView 전체를 제거한 결과이므로 그 감소량을 이번 변경의 예상 개선율로 쓰지 않는다.

### 수정 후 측정

최신 코드에서 **StreamLab-Startup-Baseline** 하나만 측정한다.
기존 계정/프로필/시청 기록을 유지하고, 기기를 식힌 뒤 Product → Profile.
Animation Hitches + Points of Interest + Time Profiler에서 앱 시작부터 기록한다.
프로필 화면에서 약 2초 후 같은 프로필 선택 → 홈 조작 없이 10초 대기 → 중지.
바탕화면에 **home-chrome-explicit-tabs-1.trace**로 저장한다.
기존 **home-chrome-baseline-1.trace**를 덮어쓰지 않는다. 나머지 두 모드는 우선 재측정하지 않는다.

새 표식/thermal/첫 hang/Session 종료~홈 모델/첫 레이아웃/후속 갱신을 함께 비교한다.
영상 탐색 후 재생 버튼 비활성화 UI 실패는 이번 탭 구성 수정 범위에 포함되지 않는다.

### 명시적 Tab 변경 검증 결과

- Release 기기용 Baseline Scheme 빌드 통과(warnings-as-errors, 서명 제외).
- iOS 26.5 시뮬레이터 UI 7개, 실패 0개:
  알림 실행 후 프로필 선택/다운로드 이동, 프로필별 목록 분리,
  검색 페이지의 상세·탭 왕복 상태 보존, baseline/no-toolbar/no-tabs,
  trace 없는 진단 옵션 무시 및 상세 왕복.
- 기존 영상 탐색 테스트 실패는 이번 회귀 항목에 포함하지 않았으며 해결로 표시하지 않는다.
- 실제 초기 지연 감소 여부는 새 실기기 trace를 받은 뒤 평가한다.
