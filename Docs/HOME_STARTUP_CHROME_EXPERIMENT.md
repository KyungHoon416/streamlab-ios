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
