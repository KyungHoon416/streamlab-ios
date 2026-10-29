# 탭·네비게이션 초기 구성 단순화

## 근거와 범위

2026-10-29 home-pv-direct-entry3.trace에서 PV/explicit/bar-only 및 앱 표식 수집을 확인했다.
초기 App Update 117.844ms에 연결된 hitch는 100.021ms였다. 탭 값 구성 시작부터
네비게이션 값 구성까지 51.874ms 구간에서 43개 메인 스레드 샘플 중 34개에 탭 경로가
있었고, 이후 네비게이션 layout 표식까지 27.418ms 구간에서 24개 중 22개에
네비게이션 경로가 있었다. 이 간격은 특정 API 단독 실행 시간이 아니다.
데이터 도착 후 App Update 33.933ms/hitch 16.670ms는 별도 콘텐츠 배치 구간이다.

이번 변경은 초기 타입 구성 비용을 줄이기 위한 후보 수정이다. UIKit 탭 컨트롤러나
네비게이션 바 자체를 제거하지 않으며, 실기기 개선 수치는 아직 확정하지 않는다.

- 탭 컨테이너의 진단 분기를 한 번의 AnyView 경계에서 분리한다. 기본 explicit/bar-only
  경로는 legacy/no-tabs/automatic을 모두 포함한 중첩 conditional 타입을 만들지 않는다.
  선택한 컨테이너 타입은 실행 중 고정이며 탭별 화면 루트와 path 상태는 그대로 유지한다.
- NavigationStack 콘텐츠를 CatalogNavigationScreen이라는 명명된 뷰로 분리한다.
  상세 destination/toolbar 조합을 NavigationStack의 제네릭 타입에서 분리한다.
- 화면 제목은 이미 inline이므로 변경하지 않는다. 툴바/프로필/로그아웃, 독립 탭 경로,
  최초 선택 시 화면 구성, 알림의 다운로드 목록 이동을 유지한다.
- 계측 실행에서 StartupChromeCompact 표식을 추가하여 수정 빌드인지 식별한다.
- body 값 구간은 실제 UIKit 구성/레이아웃 전체 시간이 아니다. 기존 layout/프레임 표식을
  함께 비교하며, 다른 뷰로 분리된 ChromeScreenValue의 자체 시간만 전후 비교하지 않는다.

## 실기기 측정

1. 최신 main을 받고 StreamLab-Home-PV-Trace 선택 → Product → Profile.
2. 미러링/AirPlay 종료, USB 연결한 iPhone 직접 조작. 기기를 식히고 동일한 네트워크,
   밝기, 충전, 저전력 상태를 유지한다. 앱 데이터 삭제나 Clean은 하지 않는다.
3. 새 Animation Hitches 문서에 Points of Interest 및 CPU 샘플링 도구를 포함한다.
4. Next Recording → Arguments에 다음 전체 문자열을 확인한다.

```
--startup-tab-style=bar-only --trace-home-chrome --home-render-experiment=PV --trace-home-startup --startup-chrome=baseline --startup-tab-builder=explicit
```

5. 앱 시작부터 녹화한다. 프로필 화면에서 약 2초 대기 → 같은 성인 프로필 선택 →
   홈에서 10초 대기. 스크롤/탭 이동/재생 없이 중지하고 처리 완료 후 저장한다.
6. 파일명은 home-pv-chrome-compact1.trace. 가능하면 기기를 식혀 같은 조건으로
   home-pv-chrome-compact2.trace도 저장한다. 각 파일에는 새 실행의 Run 하나만 남긴다.
7. HomeModePV, StartupChromeCompact, SessionInit, ChromeTabsLayout,
   ChromeHomeNavigationLayout, HomeDataReady 표식과 프레임 데이터가 있는지 확인한다.

entry3와 비교할 항목: ProfileSelection부터 첫 layout까지, 초기 App Update/hitch,
탭/네비게이션 CPU 경로, 데이터 도착 후 콘텐츠 배치. 녹화 시작 타임스탬프 자체와
사용자의 프로필 선택 대기 시간을 성능 개선 수치로 쓰지 않는다.
시뮬레이터 기능 검증 통과는 실기기 지연 감소를 입증하지 않는다.

## 검증 결과

- Release 기기용 빌드: 서명 제외, Swift warnings-as-errors 적용, 경고 없이 통과.
- iOS 26.5 시뮬레이터: 기본 PV 상세 진입, 알림의 현재 프로필 다운로드 목록 이동,
  검색 페이지/탭 상태 유지, legacy 탭, automatic 스타일, 탭별 상세 경로 유지 및
  프로필 전환 시 경로 초기화의 6개 시나리오 통과.
- 최종 변경본 첫 UI 실행에서 automatic/상세 경로 테스트 2개가 실패했다.
  이때 일부 테스트가 492~1356초로 늘어났으며 환경 지연 원인은 확정하지 않았다.
  코드 변경 없이 caffeinate -i로 실패한 2개만 재실행하여 각각 33.853초/45.248초에 통과했다.
- git diff --check 통과. 실기기 성능 개선 여부는 새 trace로 검증해야 한다.
