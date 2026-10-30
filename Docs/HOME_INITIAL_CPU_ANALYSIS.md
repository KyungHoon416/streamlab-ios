# 반복 실행의 초기 CPU 비용 분석 (2026-10-30)

## 결론과 변경 범위

home-pv-pages-repeat1/2/3의 프로필 선택을 포함하는 초기 hang에서 Running은
104.697/103.788/104.755ms다. 공통 비용은 시스템 탭/네비게이션의 최초 구성,
SwiftUI 레이아웃, 심볼 리소스 처리 및 타입 메타데이터 초기화에 분산된다.
단일 앱 함수가 100ms를 소비하거나 불필요하게 반복 초기화된다는 근거는 확인되지 않았다.
이번 요청의 '원인이 확인되면 수정'에 해당하는 안전한 코드 수정 지점은 아직 특정하지 못했다.
따라서 앱 코드는 변경하지 않고 검증 가능한 분석만 기록한다. 성능 개선 완료가 아니다.

## 시간 구간 비교

| 구간(ms) | repeat1 | repeat2 | repeat3 |
| --- | ---: | ---: | ---: |
| 초기 hang | 109.413 | 118.791 | 111.701 |
| SessionInit | 10.15 | 5.45 | 11.07 |
| ChromeTabsValue 시작 → ChromeNavigationValue 시작 | 46.36 | 57.71 | 46.17 |
| ChromeNavigationValue 시작 → ChromeHomeNavigationLayout | 27.40 | 30.90 | 28.90 |

표식 사이 경과 시간은 특정 API 단독 실행 시간이 아니다. layout 표식은 실제 첫 표시
완료를 보장하지 않는다. 세 기록 모두 Fair 상태이며 이전 entry3의 Nominal과 다르다.

## CPU 표본의 공통 호출 경로

초기 hang의 메인 스레드 표본 수는 106/104/104개다.
아래 수치는 해당 경로를 포함한 표본 수이며 서로 중복된다. 합산하여 시간/비율로 쓰지 않는다.

| 경로 | repeat1 | repeat2 | repeat3 |
| --- | ---: | ---: | ---: |
| layout/Layout | 79 | 84 | 81 |
| UITabBar / UIKitAdaptableTabView / AdaptableTabViewRoot | 22 | 24 | 26 |
| UINavigation / NavigationStackRepresentable / toolbar bridge | 27 | 26 | 29 |
| 심볼/벡터 글리프/이미지 에셋 | 14 | 12 | 13 |
| Swift 타입 메타데이터/witness 조회 | 19 | 18 | 17 |
| CatalogSession.init | 9 | 4 | 9 |
| 홈 body | 1 | 1 | 1 |
| ImageIO / CGImageSourceCreate | 0 | 0 | 0 |

대표 경로:
- UITabBarController.setViewControllers → _rebuildTabBarItemsAnimated → UITabBar.setItems/layoutSubviews
- NavigationStackRepresentable.makeUIViewController
- UINavigationController._positionNavigationBarHidden / __viewWillLayoutSubviews
- UIHostingController.prepareNavigationBar / UIKitToolbarStrategy.updateNavigationBarTrailing
- CUICatalog.namedVectorGlyph / CUINamedVectorGlyph 처리
- Swift 타입 메타데이터 조회 및 AttributeGraph 갱신

ImageIO 경로가 관찰되지 않았다는 것은 모든 이미지 처리 비용이 0이라는 뜻이 아니다.
시스템 심볼 처리 비용은 별도로 관찰된다. 표본에 나타난 시스템 생성 경로만으로
컨트롤러 생성 횟수나 중복 생성 버그를 확정하지 않는다.

## 소스 검토

CatalogTabs의 selectedTab/visitedTabs 및 탭별 path는 유지되고 있다.
선택하지 않은 탭의 NavigationStack은 isLoaded 조건으로 지연 생성된다.
CatalogNavigationScreen은 화면별 상세 경로와 툴바를 담는다.
각 화면은 이미 inline 제목을 사용한다.
CatalogSession의 로컬 목록/진행률/최근 검색 복원은 초기 CPU의 일부지만,
SessionInit 5~11ms를 전체 100ms 병목으로 표현하지 않는다.
이 복원을 비동기로 바꾸는 작업은 즉시 표시되는 오프라인 상태와 프로필 격리에 영향을
줄 수 있으므로, 이번 표본만으로 성급하게 수행하지 않는다.

## 판단과 검증

- 동일 분석 스크립트로 세 trace의 초기 구간과 스택 포함 표본 수를 다시 집계했다.
- 각 분류 수가 해당 구간 표본 수 이하인지 검증했다.
- 문서 git diff --check를 통과했다.
- 앱 코드가 바뀌지 않아 빌드/UI 테스트를 반복하지 않았다.
- 3476d34의 실제 지연 감소는 입증되지 않았다. 기존 약 100ms CPU 비용이 남아 있다.
- 지금은 추가 실기기 trace를 요청하지 않는다.

큰 감소를 목표로 한다면 네이티브 탭/네비게이션 구성을 교체하거나 준비 시점을 변경하는
설계가 필요할 수 있다. 이는 현재 스택만으로 효과가 입증된 수정이 아니며, 탭 상태,
접근성, 알림 라우팅 및 최초 화면 표시를 함께 검증해야 하는 별도 변경이다.
기존 UI를 유지한 채 비용이 제거됐다고 주장하지 않는다.
