# 단계 구성의 추가 지연 제거

## 확인한 문제

staged1에서는 탭 shell 구성 후 navigationReady 변경으로 CatalogTabsBodyValue가
다시 평가되고, HomeView가 만들어진 뒤 appear → CatalogScreenModel.setPhase(.active)
경로에서 HomeInitialLoadWait/실제 홈 요청이 시작됐다.
단계 구성은 홈 요청을 앞당기지 않은 채 화면 진입을 늦추므로 데이터 로딩 시작도 늦춘다.

실측: 초기 hang 91ms + 별도 navigation hang 42ms.
프로필→HeroFirstLayout 343ms로 이전 반복 277~299ms보다 길었다.
페이지 로딩/열 조건이 달라 증가분 전부가 gate 때문이라고 단정하지 않지만,
추가 gate 갱신과 늦은 요청 시작은 소스 및 표식에서 직접 확인된다.

## 수정

기본 navigationReady를 true로 시작하도록 단계 구성 정책을 opt-in으로 바꿨다.
기본 경로에서 CADisplayLink gate를 생성하지 않으므로 해당 준비 대기와
navigationReady 전환에 따른 추가 탭 갱신이 발생하지 않는다.
홈 모델은 기존대로 활성/가시 상태에서 한 번 요청하며, 별도 선조회나 공유 캐시를
추가하지 않아 중복 요청·다른 프로필 데이터 노출 위험을 만들지 않는다.

진단 모드는 --trace-home-startup와 정확히 하나의 --startup-navigation=staged를
함께 지정할 때만 켜진다. 인자 없음/immediate/잘못된 값/중복 인자는 즉시 구성이다.
기존 탭, 상세 경로, 프로필 격리 및 알림 라우팅 코드는 변경하지 않았다.

## 실기기 확인

추가 trace를 지금 요청하지 않는다. 최신 코드에서 다음 기능 확인을 우선한다.
- 프로필 선택 후 추가 준비 단계 없이 홈 로딩 화면으로 진입.
- 홈/검색 상세를 열어 탭 왕복 시 경로 유지.
- 프로필 변경/로그아웃 후 이전 상세 경로가 남지 않음.
- 알림 선택 시 현재 프로필 다운로드 목록으로 이동.

기존 StreamLab-Home-PV-Trace Scheme과 6개 Arguments를 그대로 사용하면 즉시 구성이다.
Instruments에 --startup-navigation=staged를 직접 추가했던 경우만 제거한다.
계측을 진행한다면 StartupNavigationImmediate가 있고 NavigationStageReady가 없는 것이 정상이다.
초기 약 100ms CPU 비용 해결이나 실기기 전체 로딩 시간 감소는 이번 수정만으로 보장하지 않는다.

## 검증 결과

- Release 기기용 빌드: 서명 제외, Swift warnings-as-errors, 경고 없이 통과.
- iOS 26.5 시뮬레이터 5개 UI 테스트 통과:
  기본 PV 상세 이동(25.359초), 시작 알림/프로필 대기(24.846초),
  현재 프로필 다운로드 알림(27.665초), 명시적 staged 모드 백그라운드 복귀(16.423초),
  홈/검색 상세 경로 유지 및 프로필 초기화(43.278초).
- git diff --check 통과. 실기기 시간 개선 수치는 아직 측정하지 않았다.
