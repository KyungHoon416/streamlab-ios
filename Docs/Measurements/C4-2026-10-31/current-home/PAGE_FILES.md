# 초기 페이지 로딩의 코드 소속 분석

2026-10-31, c4-current-home-scroll-1.trace Run 1. 초기 Hang 3.848855041~4.002111791초.

## 식별 결과

| 페이지에 대응한 코드 이미지 | 이벤트 수 | Blocked와 겹친 시간 |
|---|---:|---:|
| SwiftUI.framework/SwiftUI | 163 | 19.480ms |
| UIKitCore.framework/UIKitCore | 29 | 4.465ms |
| SwiftUICore.framework/SwiftUICore | 32 | 3.636ms |
| CoreGraphics.framework/CoreGraphics | 14 | 1.006ms |
| 앱 실행 파일 StreamLab | 19 | 1.313ms |
| 파일/이미지 미식별 | 130 | 18.921ms |
| 합계 | 387 | 48.821ms |

시스템 코드로 대응한 대기는 28.587ms, 앱 실행 코드로 대응한 대기는 1.313ms다. 이것은 전체 대기 56.783ms 중 페이지 로딩과 교차한 48.821ms의 세부 구성이다. 전체 초기 Hang/CPU 시간과 혼동하지 않는다.

## 대응 방법과 신뢰 범위

VM 이벤트에는 fault 주소와 크기(대부분 16KiB), 호출 스택이 있다. 각 스택 프레임의 PC가 해당 fault 페이지 주소 범위 안에 있을 때만 프레임의 binary metadata로 코드 소속을 대응했다. 단순히 가까운 load address나 최상위 호출자를 페이지 소유자로 사용하지 않았다. 모든 일치 프레임이 같은 이미지 경로인 경우에만 식별했다.

387개 구간은 서로 중첩되지 않았으며 이미지별 Blocked 교차 합계가 기존 합집합 분석의 48.821460ms와 일치한다. 257개는 코드 이미지와 대응했고 130개는 미식별이다. dyld-library-load export는 스키마만 있고 행이 0개라 이를 주소 범위 증빙으로 사용하지 않았다.

이는 **논리적 코드 이미지 식별**이며 실제 물리 backing 파일 경로를 모두 식별한 것은 아니다. 시스템 프레임워크 코드는 dyld 공유 캐시를 통해 제공될 수 있다. 이 trace의 VM export에는 fault별 파일 경로/offset이 없어 특정 shared-cache 파일이나 Assets.car 파일 이름까지 단정하지 않는다. 스택에 나타난 코드 이미지와 물리 디스크 파일은 구분한다.

## 확인된 호출 경로

- SwiftUI 쪽에는 _UIHostingView 초기화, focus/환경/뷰 metadata 및 여러 내부 SwiftUI 경로가 있다.
- UIKitCore 쪽에는 UITabBarController 초기화와 visual style 구성 코드가 있다.
- SwiftUICore 쪽에는 animation state, LazyStack layout/metadata 관련 코드가 있다.
- 앱 쪽에는 MyListStore, PlaybackProgressStore, RecentSearchStore 초기화 및 CatalogTabs/HomeView metadata가 있다. 앱 코드 페이지가 로딩됐다는 뜻이며 DB 파일을 읽는 데 1.313ms가 들었다는 뜻은 아니다.

미식별 페이지의 최상위 호출 문맥에는 CoreUI lookupAssetForKey 약 5.257ms, Swift witness-table 조회 약 2.175ms, dyld와 폰트 파서 등이 있다. 이는 호출 문맥별 관측으로, 해당 값만으로 SF Symbols/포스터/특정 폰트 파일을 소유 파일로 판정하지 않는다. 무스택 구간도 약 3.110ms 남아 있다.

## 수정 판단

대기의 큰 부분은 초기 화면 구성에 필요한 시스템 코드/리소스 접근과 연결되며, 앱의 중복 파일 읽기·잘못된 반복 요청·불필요한 초기화로 제거 가능하다는 증거는 이번 자료에서 확인하지 못했다. 앱 코드로 대응한 페이지 대기 1.313ms를 줄이려고 저장소 초기화/탭 경로를 다시 변경할 근거도 부족하다.

따라서 앱 코드는 변경하지 않았다. 예열을 넣거나 탭 생성을 미뤄 비용을 다른 시점으로 옮기는 것을 해결로 간주하지 않는다. 특정 리소스의 물리 파일 식별과 초기 표식 수집 누락 원인은 미해결 상태다. 추가 실기기 측정은 지금 요청하지 않는다.

## 증빙

page-file-summary.json은 이미지별 값·검증 결과·입력 해시다. 재현용 로컬 분석 스크립트는 outputs/c4-current-home-scroll-1/page-files.py, 이벤트별 주소/프레임 결과는 같은 폴더 page-files.json에 있다. 원시 trace/XML은 수정하거나 Git에 넣지 않았다. 수치 합계·겹침 여부·기존 분석과의 일치를 검증했고 앱 코드 변경이 없어 Xcode 빌드를 반복하지 않았다.
