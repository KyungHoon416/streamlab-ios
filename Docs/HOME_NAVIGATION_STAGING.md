# 탭 표시와 네비게이션 초기 구성 분리

> 2026-10-30 후속 결정: 실기기에서 홈 주요 레이아웃이 늦어져 기본 구성을 즉시 방식으로 복원했다.
> 아래 단계 구성은 `--trace-home-startup --startup-navigation=staged`로 켜는 진단 모드에만 적용된다.
> 현재 기본 실행은 `StartupNavigationImmediate`를 기록하며 `NavigationStageReady`는 발생하지 않는다.
> 당시 구현/검증 경위는 아래에 보존한다.

## 설계

기존 반복 기록에서 탭 구성과 네비게이션 배치가 약 100ms의 한 초기 갱신에 몰렸다.
이번 변경은 총 CPU 작업량 제거가 아니라, 먼저 네이티브 탭 바/준비 화면을 구성하고
다음 갱신에서 선택된 탭의 NavigationStack을 구성하여 긴 갱신을 분리하는 시도다.

CatalogTabs는 세 탭과 독립 path/visitedTabs를 그대로 소유한다. navigationReady가
false인 동안 CatalogTabRoot는 준비 화면을 표시한다. 화면에 연결된 UIView의
CADisplayLink 두 tick을 거친 뒤 메인 큐에서 한 번만 navigationReady를 활성화한다.
첫 tick과 다음 tick 사이에 탭 shell이 갱신될 기회를 주지만 물리적 표시 완료를
보장하는 표식은 아니다. Task.sleep이나 임의의 수백 ms 지연은 사용하지 않는다.

- 기존 native TabView, 탭 접근성, 탭별 상세 경로 및 방문한 화면 상태 유지.
- 준비 중 탭 선택과 알림 라우팅도 selectedTab/path에 반영되며 완료 후 해당 경로 구성.
- 알림 처리, 프로필 전환, 로그아웃의 권한/세션 검사는 기존 로직 유지.
- 프로필별 .id(session.id)가 gate 상태를 분리한다.
- 비활성/화면 이탈 시 display link 취소. 활성 복귀 후 재시작. 제거 시 명시적 해제.
- target은 view를 weak로 보유하고 완료 콜백도 weak로 캡처한다.
- 상태 활성화에는 애니메이션을 넣지 않는다. 전체 완료 시간이 더 늦어질 가능성은 측정 대상이다.

## 표식과 비교 제어

기존 HomeModePV / StartupChromeCompact와 함께 StartupNavigationStaged,
NavigationStageReady를 기록한다. ChromeTabsLayout과 ChromeHomeNavigationLayout 사이에
준비 단계가 추가되므로 두 layout 표식 사이 시간이 줄었는지만으로 성공 판정하지 않는다.

--trace-home-startup가 켜져 있을 때만 --startup-navigation=immediate로 이전 즉시 구성
방식을 선택할 수 있다. 현재 일반 실행은 즉시 구성이며 설정을 디스크에 저장하지 않는다. 단계 모드는
--startup-navigation=staged를 명시해야 한다. 중복/상충 인자는 즉시 구성으로 처리한다.
즉시 구성은 StartupNavigationImmediate를 기록한다.

## 실기기 확인

먼저 기능만 확인:
1. 같은 프로필 선택 후 탭 바/준비 화면에서 홈으로 자연스럽게 넘어가는지 확인.
2. 홈 상세 → 검색 상세 → 홈/검색 왕복 시 각 상세 경로가 유지되는지 확인.
3. 프로필 변경 후 이전 프로필 상세가 남지 않는지 확인.
4. 앱 진입 직후 백그라운드 → 복귀 시 준비 화면에 멈추지 않는지 확인.
5. 다운로드 알림으로 실행/복귀 시 현재 프로필의 다운로드 목록으로 이동하는지 확인.

성능 파일은 우선 한 개만 요청한다: home-pv-navigation-staged1.trace.
StreamLab-Home-PV-Trace → Product → Profile, 기존 Animation Hitches/Points of Interest와
CPU 도구 유지. 미러링 종료, 실기기 직접 조작, 동일 밝기/충전/네트워크 조건 유지.
Next Recording Arguments:

```
--startup-tab-style=bar-only --trace-home-chrome --home-render-experiment=PV --trace-home-startup --startup-chrome=baseline --startup-tab-builder=explicit
```

앱 새 프로세스로 시작 → 프로필 화면 약 2초 → 같은 성인 프로필 → 홈에서 무조작 10초 → 저장.
Run 하나만 저장. StartupNavigationStaged / NavigationStageReady 표식 확인.
이전 repeat 자료와 초기 최대 App Update/hitch, Running/Blocked/페이지 로딩,
ProfileSelection→HeroFirstLayout을 함께 비교한다. 초기 멈춤만 다른 시점으로 옮기거나
전체 홈 표시 시간이 크게 늘면 개선으로 판정하지 않는다.
표식은 화면을 실제로 본 시점과 동일하지 않으며 기능 테스트는 성능 개선 증거가 아니다.

## 검증 결과

- Release 기기용 빌드(서명 제외, Swift warnings-as-errors): 최종 경고 없이 통과.
- iOS 26.5 시뮬레이터 UI 테스트 6개 통과: 기본 PV 포스터/상세, 시작 알림의 프로필 대기,
  현재 프로필 다운로드 목록 이동, 즉시 구성 비교 모드, 진입 직후 백그라운드/복귀,
  홈·검색 상세 경로 유지와 프로필 전환 시 초기화.
- display-link target 메인 액터 명시 후 최종 빌드에서 시작 알림/백그라운드 복귀를
  재실행해 각각 24.641초/16.403초에 통과.
- git diff --check 통과. 실기기 지연 감소 및 준비 화면 체감은 미검증이다.
