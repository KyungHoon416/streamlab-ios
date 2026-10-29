# 기본 PV 화면 실기기 계측

## 목적과 구성

최근 직접 조작 기록은 프레임 수집은 복구됐지만 비교용 C(InlineHomeView/SwiftUI 포스터)였다.
새 StreamLab-Home-PV-Trace는 기본 화면과 같은 PV(ExtractedHomeView/레이어 포스터),
explicit 탭, bar-only 스타일, baseline chrome을 사용한다. Release Launch/Profile 모두 동일하다.
--trace-home-startup / --trace-home-chrome으로 기존 단계 계측을 켜고 RootAppeared와 함께
HomeModePV를 기록한다. 일반 실행에서는 추가 표식을 기록하지 않는다.
이것은 진단 준비이며 성능 개선 패치가 아니다. 추가 layout probe의 비용도 포함된다.
이전 C 기록은 automatic 스타일이므로 PV/bar-only와의 차이를 홈 분리 효과 하나로 해석하지 않는다.

## 측정 설정

- 최신 main을 받고 원본 StreamLab.xcodeproj에서 StreamLab-Home-PV-Trace 선택.
- iPhone 미러링/AirPlay 종료, USB 연결, 잠금 해제한 아이폰에서 직접 조작.
- 기기를 식히고 밝기/충전/저전력/Wi-Fi 조건을 유지. 앱/데이터 삭제나 Clean 불필요.
- Product → Profile. 새로운 기본 Animation Hitches 템플릿을 사용하고 기본 트랙 유지.
- Points of Interest를 반드시 포함한다(없으면 +에서 추가). 필요하면 Time Profiler 또는
  해당 환경의 CPU Profiler 하나를 추가한다. Hangs와 Hitches는 서로 다른 도구다.
- 대상은 연결된 iPhone의 StreamLab. 앱 시작부터 새 프로세스로 기록한다.
- 매 파일은 새 문서의 Run 하나만 저장한다.
- 녹화 후 처리가 끝나면 Points of Interest에서 com.example.streamlab.demo의
  HomeModePV, SessionInit, HomeDataReady, HeroFirstLayout, ChromeTabsLayout을 확인한다.
  보이지 않으면 필터/선택 구간을 해제해 전체 기록을 확인하고 파일을 전달한다.
  실행 인자가 있다는 것만으로 앱 표식 수집 성공이라고 판단하지 않는다.
- Hitches가 비더라도 Commits/App Updates, Renders, Frame Lifetimes에 데이터가 있는지 확인한다.

## 파일 1: 초기 진입

바탕화면 home-pv-direct-entry1.trace
1. 프로필 화면에서 약 2초 대기 → 동일 성인 프로필 선택.
2. 홈에서 스크롤/탭 전환/재생 없이 10초 대기.
3. 중지 → 처리 완료 → 저장.

우선 이 파일에서 프레임과 앱 표식이 모두 수집됐는지 확인한다.
앱 표식이 보이지 않거나 확인하기 어려우면 entry1만 먼저 전달해도 된다.

## 파일 2: 스크롤 (첫 파일 수집 구성이 정상일 때)

바탕화면 home-pv-direct-scroll1.trace
1. 기기를 식힌 뒤 같은 Scheme, 같은 도구로 앱을 새로 시작한다.
2. 동일 프로필 선택 → 홈 5초 대기.
3. 홈 세로 스크롤을 아래→위로 3왕복한다. 탭 전환이나 영상 재생은 하지 않는다.
4. 3초 대기 → 중지 → 처리 완료 → 저장.

기존 직접 조작 확인과 유사한 동작이지만 두 파일의 성능 차이를 특정 코드 효과라고 단정하지 않는다.
초기 진입과 스크롤 창을 분리해 해당 프레임 ID와 앱 update/render/CPU 스택을 분석한다.
실기기 성능 판정은 미완료다.

## 검증 (2026-10-29)

- PV 전용 Scheme의 Release 기기용 빌드 통과(서명 제외, warnings-as-errors, 경고 없음).
- Launch/Profile의 PV/explicit/bar-only/baseline 및 두 trace 인자 검사 통과.
- iOS 26.5 시뮬레이터 testDefaultPVStartupDetailedTrace 통과:
  PV(layer/split) 실행 확인, 홈 스크롤, 포스터 영역 상세 진입, 검색 탭 및 썸네일 상세 진입.
- git diff --check 통과. 실기기 표식 수집 및 성능은 아직 검증 전.
