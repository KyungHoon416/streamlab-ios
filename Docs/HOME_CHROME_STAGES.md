# 초기 화면 구성 상세 계측

## 목적

기존 ABBA 측정에서는 명시적 탭의 성능 우위를 확정하지 못했다.
B2의 116.691ms hitch는 별도의 홈 진입 후 끊김이 아니라 초기 앱 update
(3.445439~3.563739초, 118.301ms)와 연결된다. 첫 Hero layout은 3.740843초였다.
초기 update 안에서 탭/네비게이션, 타입 메타데이터, 심볼, 글꼴 준비가 함께 관측됐다.
이번 변경은 원인 분류용 계측이며 성능 수정이 아니다.

## 추가 표식

`--trace-home-startup`과 `--trace-home-chrome`을 함께 지정해야 활성화된다.
프로필/작품/URL/개인 정보를 기록하지 않는다. 기본 앱에서는 꺼져 있다.

| 표식 | 의미 |
| --- | --- |
| ChromeTabsValue | 탭 컨테이너 SwiftUI 값 구성 |
| ChromeHomeRootValue / ChromeSearchRootValue / ChromeDownloadsRootValue | 각 탭의 루트 값 구성 |
| ChromeNavigationValue | 탭 루트의 조건부 NavigationStack 값 구성 |
| ChromeScreenValue | 화면 분기 값 구성 |
| ChromeToolbarValue | ToolbarContent 값 구성 |
| ChromeTabsAppeared | 컨테이너 onAppear 콜백 |
| ChromeTabsLayout | 탭 배경 probe의 첫 양수 크기 레이아웃 |
| ChromeHomeNavigationLayout | 홈 NavigationStack 배경 probe의 첫 양수 크기 레이아웃 |

Value 구간은 이후 SwiftUI reconciliation, 플랫폼 뷰 생성, 전체 레이아웃을 포함하지 않는다.
구간은 중첩될 수 있어 합산하지 않는다. 검색 루트 값/타입 생성만으로 실제 검색 화면 로딩을 뜻하지 않는다.
Layout은 probe 자신이 window에 연결되고 양수 크기를 얻은 시점이며 화면 표시 완료를 뜻하지 않는다.
Appear와 Layout의 순서를 고정 가정하지 않는다. 기존 HeroFirstLayout과 함께 앱 update/CPU 스택에 맞춰 본다.
두 probe는 hit testing과 접근성에서 제외되며 상태/타이머/비동기 지연을 추가하지 않는다.
계측에도 비용이 있고 래퍼 타입이 변경되므로 이전 바이너리와 직접 개선율을 계산하지 않는다.

## 실기기 측정 순서

최신 main을 pull한 뒤 동일 코드와 데이터로 아래 3회만 먼저 진행한다.
기존/새 탭 비교가 아니라 동일 explicit 탭에서 상세 계측 OFF/ON을 확인한다.

| 순서 | Scheme | 바탕화면 파일 이름 |
| --- | --- | --- |
| 1 | StreamLab-Tabs-Explicit | home-chrome-stages-control1.trace |
| 2 | StreamLab-Chrome-Stages | home-chrome-stages-detail1.trace |
| 3 | StreamLab-Chrome-Stages | home-chrome-stages-detail2.trace |

1. 같은 기기, Wi-Fi, 밝기, 충전/저전력 조건을 유지하고 회차 사이 기기를 식힌다.
2. 앱 삭제, 데이터 초기화, Clean Build Folder를 하지 않는다. 동일 성인 프로필을 선택한다.
3. 매 회차 앱 프로세스를 종료한 뒤 해당 Scheme에서 Product → Profile로 새로 시작한다.
   Profile은 Release다. 실행 중 앱에 중간부터 attach하지 않는다.
4. 새 Instruments 문서에 Animation Hitches + Points of Interest + Time Profiler를 사용한다.
   Time Profiler가 없고 CPU Profiler가 제공되는 환경에서는 CPU Profiler로 호출 스택을 수집한다.
   한 회차에 샘플러 두 개를 함께 추가하지 말고 세 회차 모두 같은 도구 구성을 쓴다.
5. 앱 시작부터 녹화하고 프로필 선택 화면에서 약 2초 기다린 뒤 같은 프로필을 선택한다.
6. 홈에서 10초 기다린다. 스크롤/탭 이동/영상 재생은 하지 않는다.
7. 녹화를 멈추고 처리가 끝나면 표의 이름으로 바탕화면에 저장한다.
   한 파일에 Run 하나만 저장한다. 다음 회차는 새 문서를 쓴다.
8. 3개 파일이 저장됐다고 알려준다. 계측 유효성, 열 상태, 구간과 CPU 스택을 함께 분석한다.

Control에는 Chrome* 상세 표식이 없어야 하고 기존 SessionInit/ScreenModelInit/HeroFirstLayout은 남아야 한다.
Detail에는 Chrome* 값 구간과 레이아웃 표식이 있어야 한다.
실기기 결과를 받기 전에는 원인 확정 또는 개선 완료로 판정하지 않는다.

## 자동 검증 (2026-10-29)

- StreamLab-Chrome-Stages Release 기기용 빌드 통과 (서명 제외, warnings-as-errors, 경고 없음).
- iOS 26.5 시뮬레이터: testStartupChromeDetailedProbes / testStartupTabsExplicit 2개 모두 통과.
  상세 계측 ON/OFF에서 홈 상세 왕복, 검색/다운로드/홈 전환 확인.
- 두 Scheme의 Launch/Profile Release 및 인자 차이 검사 통과: 상세 계측 플래그만 다름.
- git diff --check 통과.
- 기존 validate-project.py는 수정하지 않은 ArtworkSurfaceTests.swift의 UIKit 허용 목록 검사에서 실패.
  해당 파일이 HEAD와 동일함을 확인했으며 이 검사를 통과했다고 보고하지 않는다.
- 실기기 signpost 수집과 성능 원인 판정은 위 3개 trace를 받은 뒤 진행한다.
