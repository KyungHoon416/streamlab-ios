# 초기 화면 공통 구성 및 이어보기 갱신 개선

## 근거

`home-startup-stages-1.trace`에서 프로필 선택 직후 메인 지연 154.487ms가
홈 데이터와 포스터 로드보다 먼저 발생했다. 세션 생성은 약 15.8ms였고,
나머지 구간에서 탭/네비게이션 및 SwiftUI/UIKit layout/commit이 관찰됐다.
이어보기는 초기 두 조회가 겹쳤고 두 번째 조회 종료 후 약 42ms의 후속 레이아웃이 있었다.
단일 함수가 전체 지연을 유발했다고 확정한 것은 아니다.

## 변경

- 서로 다른 형태로 반복되던 세 탭의 NavigationStack/toolbar 트리를
  `CatalogTabRoot`와 `CatalogProfileToolbar` 공통 타입으로 구성했다.
  TabView의 항목도 동일 타입의 ForEach로 만든다. 초기 구체 타입의 중복을 줄이려는
  구조적 변경이며, 시스템 레이아웃 비용 감소는 실기기 재측정 전에는 미확정이다.
- 탭별 독립 path, 검색/다운로드 첫 방문 시 생성, 재방문 상태 보존,
  프로필 이름/접근성/로그아웃/알림 이동 동작은 유지한다.
- 이어보기 모델과 결과 상태를 `ContinueWatchingSection`으로 옮겼다.
  이어보기 결과가 홈 전체의 State를 갱신하던 연결을 제거한다.
- 초기 onAppear에서 refresh UUID를 바꾸던 동작을 제거했다.
  섹션 task의 시작/재등장, 활성 상태 전환, 플레이어 종료 또는 재시도로 갱신한다.
  비활성화/화면 이탈 시 SwiftUI task 취소와 모델의 취소·generation·session 검사로
  오래된 결과를 차단한다.
- repository.detail 조회는 중복 title ID를 제거하고 최대 4개 동시 요청으로 제한한다.
  응답 도착 순서와 무관하게 저장된 시청 기록 순서로 조립한다. 같은 프로필로
  repository authorization을 수행하고 반환 title의 프로필 허용 여부도 확인한다.
- 항목/오류를 하나의 Snapshot으로 한 번에 발행한다. 동일한 화면 내용은 재발행하지 않는다.
  일부 조회 실패 시 성공 항목은 남기고 기존 재시도 UI를 제공한다.
- HLS와 다운로드 HLS가 같은 progress ID를 공유하는 경우 기존 첫 매칭 정책을 유지한다.
- mock의 120ms 지연을 제거하지 않았다. 저장 데이터나 프로필별 시청 위치도 초기화하지 않는다.

## 계측 변화

기존 `StreamLab-Startup` Scheme(C + trace 활성)을 그대로 사용한다.
`CatalogTabsBodyValue`는 탭 뷰 값 계산, `HomeRecentPublish`는 이어보기 섹션의
Snapshot 발행을 표시한다. 전체 UIKit layout 시간으로 해석하지 않는다.
`HomeRecentWait`는 섹션 task 단위로 표시된다. LazyVStack에 따른 섹션 생성 시점이
달라질 수 있으므로, 화면 밖 섹션이 아직 생성되지 않았다면 표식 부재만으로 수집 실패라
판정하지 않는다. Root/Session/HomeDataReady/HeroFirstLayout과 CPU/frame 존재도 확인한다.

## 실기기 측정

1. 최신 main을 pull하고 기존 계정·프로필·시청 기록을 유지한다. 앱 삭제 금지.
2. 기기를 식히고 같은 밝기/충전/저전력 조건에서 앱을 종료한다.
3. Scheme **StreamLab-Startup** → Product → Profile → **Animation Hitches**.
4. **Points of Interest**와 CPU 트랙을 포함한 상태에서 앱 시작부터 새 문서로 기록한다.
5. 프로필 화면에서 약 2초 후 이전과 같은 성인 프로필을 선택한다.
6. 홈 진입 후 **스크롤·재생·탭 전환 없이 10초 대기**하고 중지한다.
7. 바탕화면에 **home-startup-stages-fixed1.trace**로 저장한다. 기존 파일은 보존한다.

우선 한 파일만 확인한다. 이 측정에서는 스크롤 5왕복이나 C/P/V/PV 8회 반복을 하지 않는다.
이전 `home-startup-stages-1.trace`와 동일 구간으로 비교하고 실제 thermal을 확인한다.
화면 밖 이어보기의 동작 검증이 별도로 필요하면 초기 측정과 섞지 않고 안내한다.

## 해석할 항목

- ProfileSelection/SessionInit 이후 첫 app update와 main hang이 줄었는가.
- HomeRecentWait가 초기 시작 직후 재시작하지 않는가. 화면 이탈/재등장은 별도 구분한다.
- 이어보기 완료 시 HomeRecentPublish가 발생하고 홈 전체 HomeBodyValue 반복이 줄었는가.
- 응답 대기 시간 감소와 main-thread hang 감소를 구분한다.
- 레이아웃 비용을 뒤로 옮겼을 뿐인지, 후속 구간에도 긴 hang이 생기는지 함께 확인한다.

자동 기능 테스트 통과는 초기 지연 감소나 C4 성능 검증 완료를 뜻하지 않는다.

## 자동 검증 결과 (2026-10-28)

- 최종 기기용 Release 빌드 통과 (`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, 서명 제외).
- `HomeRecentTests` 4개 통과: 중복 제거/최대 동시 조회/취소, 부분 실패,
  동일 결과 발행 억제/프로필 분리, 세션 무효화 뒤 늦은 응답 차단.
- iOS 27 iPhone 17 Pro 시뮬레이터 UI 6개 항목 통과: C/PV 초기 계측 화면,
  검색 페이지·탭 상태 보존, 알림에서 다운로드 이동, 프로필별 목록, 이어보기 재생 위치.
- 공통 탭 구조의 빈 분기가 미방문 탭 항목을 없애는 회귀를 검출해 `Color.clear`
  자리표시자로 수정했다. 검색 및 두 초기 진입 테스트는 수정 후 통과했다.
- 최종 UI 묶음은 5개 통과/1개 실패였다. 이어보기 테스트의 50% 탐색 완료 대기가
  1회 실패했지만 표시 시간은 15초였다. 같은 빌드로 해당 테스트를 단독 재실행해
  통과했다. 일괄 실행 전체가 한 번에 통과했다고 기록하지 않는다.
- 실기기 초기 지연 개선 여부는 `home-startup-stages-fixed1.trace` 수집 후 판정한다.
