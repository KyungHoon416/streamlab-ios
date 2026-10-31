> 기존 실기기 분석 보존본. 본문에 나오는 원시 XML·분석 스크립트는 로컬 outputs 폴더에 있으며 Git에는 보고서·요약·입력 해시만 보존합니다.

# C4 현재 홈 진입·스크롤 분석

원본: c4-current-home-scroll-1.trace, Run 1. 2026-10-31 09:39:29 KST 시작, 35.876725초, Animation Hitches, Deferred. iPhone 15 Pro / iOS 26.6.1. 전체 Nominal 열 상태. Built-In Display 1개(최대 120Hz), 무선 디스플레이 기록 없음. 최대 120Hz는 실제 모든 프레임이 120Hz임을 뜻하지 않는다.

## 데이터 품질

- 프레임 자료 정상 존재: Frame Lifetimes 2,368행, Render 2,369행, App Update 원시 1,003행. 이 수치는 화면 전체 원시 데이터이며 모두 앱 프레임이라고 간주하지 않는다.
- 앱 대상 Hitch 7건, Hang 3건. CPU 앱 표본 4,604개, 메인 4,175개.
- 앱 표식 부분 수집: 완결 interval 28개, event 5개, 시작 없는 HomeBodyValue End 1개. HomeAppeared / ChromeTabsLayout / ChromeHomeNavigationLayout / HomeDataReady / HeroFirstLayout은 존재한다.
- RootInit, ProfileSelection, StartupChromeCompact, StartupNavigationImmediate는 os-signpost뿐 아니라 PointsOfInterestEvents/OSSignpostIntervals에도 없다. 첫 앱 signpost는 3.945초의 End다. 초반 표식 누락 원인은 이 파일만으로 확정하지 않는다.
- 실행 인자는 기존 6개가 맞고 staged 인자는 없다. 즉시 구성과 일치하는 인자이지만 Immediate 표식과 바이너리 커밋은 독립 확인 불가다. 완전한 계측 성공이라고 표시하지 않는다.

## 초기 진입

| 구간 | 관측 |
|---|---:|
| 1.582초, 홈 이전 UI Hang | 38.044ms |
| 3.849초, 홈 최초 구성 Hang | 153.257ms |
| 같은 구간 최상위 App Update | 152.407ms |
| 초기 Hitch (3.887초) | 150.032ms |
| 4.136초, 홈 데이터 반영 Hang | 37.548ms |
| 해당 Update | 37.393ms |
| HomeAppeared → HeroFirstLayout | 218.126ms |

주요 초기 Hang의 Running 94.707ms / Blocked 56.783ms. CPU 표본에는 CA commit/layout, UIView layout, SwiftUI hosting layout, CatalogSession 생성과 일부 저장소 초기화가 함께 보인다. 표본 수는 함수별 실행 시간 비율이 아니며 중첩 호출을 합산하지 않는다. Blocked의 세부 대기 원인은 이번 결과로 확정하지 않았다.

entry3 초기 Update 117.844ms, compact1 172.148ms, compact2 675.559ms, repeat1~3 107.833~118.062ms, staged1 90.264ms와 비교하면 현재 152.407ms는 큰 676ms 이상치보다 작지만 공통 초기 비용이 제거됐다는 근거는 아니다. 이전 기록의 열/페이지 로딩 조건과 구성이 달라 개선율을 계산하지 않는다. 특히 ProfileSelection이 없어 이전의 프로필→Hero 277~343ms와 이번 HomeAppeared→Hero 218ms를 직접 비교하면 안 된다.

## 15초 이후 스크롤 및 마지막 대기 구간

사용자 안내의 15초 시작을 기준으로 [15,35.876725) 집계. 갱신은 주로 15~29초에 집중되고 30초에 1회가 있다. 손을 뗀 정확한 시각 표식은 없으므로 마지막 대기도 포함한 구간이다.

- 최상위 앱 Update 982개: p50 3.103ms / p95 7.557ms / 최대 22.109ms.
- 앱 Hitch 3개: 합계 25.005ms, 각 약 8.335ms.
- 33ms 초과 기준의 메인 스레드 Hang은 이 구간 0건.
- 이 p95는 Update 소요 시간이며 표시 프레임 간격이나 FPS가 아니다. 33ms 미만 갱신 지연이나 Hitch가 없다는 뜻도 아니다.

| Hitch 시각 | Hitch ms | 연결 Update ms | 연결 Render ms |
|---|---:|---:|---:|
| 18.936초 | 8.335 | 14.426 | 4.627 |
| 21.783초 | 8.335 | 15.309 | 5.267 |
| 27.209초 | 8.335 | 11.815 | 5.483 |

동일 swap ID로 Update/Render를 연결했다. Instruments는 세 건 모두 Potentially expensive app update(s)로 분류한다. 해당 Update의 메인 표본 14/15/12개에서 공통적으로 CA layer layout, UIView/SwiftUI hosting layout이 나타나고 일부 navigation bar/scroll observer 갱신이 섞인다. 특정 포스터 디코딩이나 DB 작업이 세 Hitch의 원인이라는 근거는 없다. 최초 추가 ArtworkDecode는 15.601/15.720초에 있어 세 Hitch와 시각이 다르다. 현재로서는 짧은 레이아웃 갱신 비용이 겹친다는 관측까지가 타당하다.

## 판정 및 다음 순서

파일은 초기 지연과 스크롤 Hitch 분석에 유효하므로 재측정을 즉시 요청하지 않는다. 스크롤 중 긴 Hang은 관측되지 않았지만 약 8.3ms Hitch 3건이 남아 있다. 초기 구성 지연은 약 153ms로 남아 있고, 초반 표식 누락 때문에 홈 진입 전체 개선 여부는 미판정이다. 기존 스크롤 trace와 동작 속도/빌드/구간이 같다고 보장할 수 없어 감소율이나 전체 C4 PASS는 주장하지 않는다.

다음 원인 조사는 기존 파일의 초기 대기와 레이아웃 스택 및 표식 수집 경로를 좁히는 작업이다. 이번 결과 때문에 HLS/Leaks 또는 동일 스크롤을 다시 반복할 필요는 없다. 별도 에너지·디스크 검증 계획은 유지한다.

## 재현 자료

events.xml / extra.xml은 로컬 export, analyze.py는 표식·스택 분석, summary.json / stages.csv는 상세 값, entry-summary.json / scroll-summary.json은 기존 summarize-frames.py 결과, thread-windows.json은 Hang 구간과 교차한 메인 스레드 상태 합계다. 초기 집계는 프로필 표식이 없어 [3.848871208,4.220192) 구간을 사용했다. 원본 trace 수정 없음, 앱 코드 수정/커밋/푸시 없음.
