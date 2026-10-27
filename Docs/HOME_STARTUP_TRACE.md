# 초기 화면 준비 구간 계측

## 목적

C/P/V/PV 비교에서 초기 지연의 일관된 개선/악화 효과가 입증되지 않았다.
공통 초기 준비와 레이아웃을 시간축에서 구분할 수 있도록 선택형 os_signpost 계측을 추가한다.
이는 성능 개선 코드가 아니며, 기기에서의 원인/개선 완료를 선언하지 않는다.

`StreamLab-Startup` Scheme의 Product → Profile은 Release에서
`--trace-home-startup --home-render-experiment=C`를 사용한다. 기존 데이터는 유지한다.
일반 Scheme과 아이콘 실행은 계측이 꺼지고, 로그/레이아웃 probe를 추가하지 않는다.
계측 자체의 비용이 있으므로 이전 비계측 trace와 절대 시간만으로 성능 개선률을 계산하지 않는다.

## 구간 의미

subsystem: `com.example.streamlab.demo`, category: `PointsOfInterest`.
계정/프로필 ID, 콘텐츠명, URL, 로컬 경로를 signpost에 넣지 않는다.
각 interval은 고유 signpost ID를 사용한다. 동기 구간은 scope 종료/throw 때,
비동기 대기는 완료/실패/취소 또는 소유 객체 해제 때 종료된다.

| 구간/이벤트 | 의미 및 제한 |
| --- | --- |
| RootInit | AppRootView 초기화의 명시적 본문. 프로세스 시작 전체나 저장 프로퍼티 초기화 전체는 아님 |
| RootAppeared | SwiftUI root onAppear. 첫 화면 표시 완료 시각은 아님 |
| AccountInit | 계정 저장소/키체인 객체의 동기 생성. RootInit보다 먼저 발생할 수 있음 |
| AccountPrepare | 계정 복원 prepare의 벽시계 시간. await 대기 포함 |
| ProfileSelection | 프로필 선택 콜백 중 동기 Session 생성 |
| SessionInit | CatalogSession의 지정 초기화 본문 |
| RestoreMyList / RestoreLanguages / RestoreProgress / RestoreSearches | 각 로컬 상태 저장소의 동기 생성. 파일 읽기만의 시간은 아님 |
| ScreenModelInit | 화면 모델 및 CatalogStore 생성 |
| HomeInitialLoadWait | 최초 홈 요청 시작부터 loading 해제 발행까지. 네트워크/mock/스케줄링 대기 포함. 화면 이탈/비활성화 시 조기 종료되므로 HomeDataReady와 함께 확인 |
| MyListRefresh | 홈 표시/동기화 등에 따른 로컬 목록 새로 읽기와 발행 |
| HomePublish | 홈 상태 변경을 Combine에 발행하는 동기 비용 |
| HomeDataReady | 해당 모델에서 첫 홈 데이터 준비가 관찰됨. 이미지 준비/화면 표시 완료는 아님 |
| HomeBodyValue | inline/split 홈의 body 값 생성. SwiftUI의 전체 layout/render 시간이 아님 |
| HomeRecentWait | 이어보기 목록 refresh의 벽시계 시간. 중복 refresh/취소 가능 |
| HomeAppeared | 홈 onAppear |
| HeroFirstLayout | hero-detail 배경의 투명 probe가 window 안에서 양의 크기로 처음 layout된 지점. 실제 첫 표시 프레임 또는 전체 레이아웃 종료를 보장하지 않음 |
| ArtworkDataWait | 이미지 byte cache/로드 대기. decoded cache hit에는 나타나지 않음 |
| ArtworkDecode | cache miss의 이미지 디코딩·디코딩 캐시 삽입. ArtworkPipeline actor에서 실행되며 메인 스레드 작업으로 단정하지 않음 |
| ScreenDisappeared | 화면 모델 이탈 이벤트. 홈 이외 화면에서도 발생 가능 |

비동기 대기를 메인 스레드 점유로 읽거나 중첩 interval을 합산하지 않는다.
HeroFirstLayout probe는 계측 활성화 시에만 생성되며 터치/접근성을 받지 않는다.
모든 포스터마다 probe를 생성하지 않는다. body/디코딩 구간은 실행 횟수만큼 표시된다.

## 실기기 측정 — 먼저 1개만

1. 최신 main을 pull하고 Xcode Scheme을 **StreamLab-Startup**으로 선택한다.
2. 같은 iPhone, 기존 계정/프로필/데이터를 유지한다. 앱 삭제나 데이터 초기화는 하지 않는다.
   기기를 식히고 측정 중 밝기/충전/저전력 설정을 바꾸지 않는다.
3. 앱을 종료한 상태에서 **Product → Profile**. Animation Hitches 템플릿을 선택한다.
4. Instruments 트랙에서 **Points of Interest**가 있는지 확인한다. 없으면 `+`로 추가한다.
   Time Profiler/CPU 표본과 Animation Hitches 트랙도 유지한다.
   Allocations/Leaks/MallocStackLogging은 이번 측정에 추가하지 않는다.
   트랙을 추가하기 전에 녹화가 시작됐다면 그 기록을 본 측정으로 쓰지 말고,
   설정 완료 후 앱 시작부터 새 문서에서 기록한다.
5. 프로필 화면이 나타나면 약 2초 뒤 같은 성인 프로필을 한 번 선택한다.
6. 홈에서 **스크롤/재생/탭 전환 없이 10초 대기**하고 녹화를 끝낸다.
   홈 진입이 늦으면 기다려 완료 후 10초를 확보하고, 전체 시각을 메모한다.
7. 처리가 끝나면 바탕화면에 **home-startup-stages-1.trace**로 저장한다.
   한 문서에 Run을 여러 번 누적하지 않는다.
8. 다시 열어 Points of Interest에서 ProfileSelection, SessionInit, HomeDataReady,
   HeroFirstLayout 등이 보이고 Animation Hitches에 프레임 트랙이 있는지 확인한다.
   계측 표식이 없거나 thermal이 Unknown이고 프레임도 비어 있으면 추가 반복을 멈추고
   이 파일을 먼저 전달한다. 드문 마커 누락을 임의로 성공으로 처리하지 않는다.

첫 파일의 수집 상태를 확인한 다음 필요할 때 동일 조건으로
home-startup-stages-2.trace를 추가한다. 이번에는 C/P/V/PV 8개를 다시 만들 필요 없다.
초기 단계만 분석하므로 15초 스크롤 규칙은 이번 측정에 적용하지 않는다.

## 분석 순서

프로필 선택 → Session/저장소 초기화 → HomeInitialLoadWait/DataReady →
HomeBodyValue/HeroFirstLayout의 위치를 hitch/hang 및 CPU 스택과 맞춘다.
동기 준비가 긴지, 데이터 대기인지, 데이터 이후 UIKit/SwiftUI layout/commit이 긴지를
먼저 분리한다. 자동 로그만으로 전체 첫 프레임 시간이나 최적화 성공을 판단하지 않는다.

## 준비 검증 (2026-10-28)

- 최종 기기용 Release 빌드 성공. Swift 경고를 오류로 처리, 코드 서명은 생략.
- StreamLab-Startup의 Run/Profile 모두 Release 및 두 시작 인자가 명시됨을 확인.
- iOS 27의 별도 검증 시뮬레이터에서 UI 3개 통과: 계측 OFF 기준, 계측 ON C/PV.
  홈 스크롤, 포스터 탭 상세 이동, 검색 썸네일 상세 이동을 확인했다.
- Logging + Points of Interest로 실제 signpost를 수집했다. ProfileSelection,
  SessionInit, Restore* 4종, HomeInitialLoadWait, HomePublish, HomeBodyValue,
  HomeRecentWait, ArtworkDataWait/Decode 등 주요 interval의 begin/end 쌍을 확인했고,
  HomeDataReady 및 HeroFirstLayout 이벤트도 존재했다. 미종료 begin은 없었다.
  이 기록은 시뮬레이터 발행 확인용이며 기기 성능 측정으로 사용하지 않는다.
- 기존 iOS 26.4 시뮬레이터의 첫 UI 시도는 접근성 초기화 시간 초과로 테스트 시작 전
  실패했다. 해당 검증 실패를 숨기거나 앱 테스트 통과로 계산하지 않았으며 새 환경에서
  재검증했다. 최초 CPU+signpost 수집 시도는 유효한 앱 계측 검증으로 사용하지 않았다.
- 실기기 수집 결과와 성능 원인 판단은 아직 미완료이다.
- 최종 소스로 iOS 패키지 회귀 테스트 4개 통과: ArtworkMemory 2개,
  ArtworkSurface 1개, HomeRenderExperiment 1개. 최종 계정/목록 계측 컴파일 포함.
