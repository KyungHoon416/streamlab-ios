# 탭 초기 구성 비용: 명시적 탭 바 스타일

## 변경과 한계

상세 trace에서 탭 값 구성은 0.58~2.01ms였지만, 이후 Navigation 구성 시작까지 45.3~74.1ms가 걸렸다.
이 구간에는 UITabBarController 생성, 시스템 심볼/글꼴, SwiftUI 메타데이터 준비가 포함됐다.
이번 변경은 TabView에 `.tabViewStyle(.tabBarOnly)`를 명시해 앱이 사용할 표현을 고정한다.
홈/검색/다운로드, 독립 navigation path, 방문 화면 보존, 알림 이동, 프로필 변경 로직은 공유한다.
지연 표시나 워밍업으로 작업을 다른 시점으로 옮기지 않는다.

Apple은 tabBarOnly를 가능한 경우 탭 바를 표시하는 스타일로 설명한다.
https://developer.apple.com/documentation/swiftui/tabbaronlytabviewstyle
이 API가 iPhone에서 automatic보다 빠르다고 보장하지는 않는다. 내부적으로 동일한 구현을 사용할 수도 있다.
따라서 기능 검증과 성능 검증을 구분한다. 탭/심볼/글꼴 비용이 제거됐다고 주장하지 않는다.

일반 앱은 bar-only를 사용한다. 기존 trace Scheme은 automatic을 명시해 이전 실험 조건을 보존한다.
새 A/B Scheme은 같은 코드와 상세 계측을 사용하며 `--startup-tab-style=automatic|bar-only`만 다르다.
스타일 인자는 --trace-home-startup 활성 시에만 적용하고, 잘못되거나 중복이면 bar-only를 사용한다.
프로세스 시작 시 고정되며 저장하지 않는다.
StartupTabStyleAutomatic / StartupTabStyleBarOnly 표식으로 실제 경로를 확인한다.

## 실기기 측정

기존 3회는 모두 Serious였고 프레임 테이블이 비어 있었다. 새 측정은 기기가 충분히 식은 상태에서 시작한다.
같은 Wi-Fi/밝기/충전/저전력 조건과 프로필을 유지한다. 앱 삭제/데이터 초기화/Clean Build Folder는 하지 않는다.
최신 main을 pull한 뒤 아래 네 회차 사이 코드를 변경하지 않는다.

| 순서 | Scheme | 바탕화면 파일 |
| --- | --- | --- |
| A1 | StreamLab-TabStyle-Automatic | home-tabstyle-A1.trace |
| B1 | StreamLab-TabStyle-BarOnly | home-tabstyle-B1.trace |
| B2 | StreamLab-TabStyle-BarOnly | home-tabstyle-B2.trace |
| A2 | StreamLab-TabStyle-Automatic | home-tabstyle-A2.trace |

1. 각 회차 앱을 종료하고 해당 Scheme → Product → Profile(Release)로 새 프로세스를 시작한다.
2. 새 Instruments 문서에서 Animation Hitches + Points of Interest + Time Profiler를 사용한다.
   Time Profiler 대신 CPU Profiler가 제공되면 그것을 사용하되 네 회차 동일하게 구성한다.
3. 앱 시작부터 녹화한다. 프로필 화면에서 약 2초 기다린 뒤 동일 성인 프로필을 선택한다.
4. 홈에서 조작 없이 10초 대기한다. 스크롤/재생/탭 전환은 하지 않는다.
5. 중지 후 처리가 끝나면 Run 하나만 들어 있는 파일로 저장한다. 회차 사이 기기를 식힌다.
6. 첫 A1에서 Hangs, Points of Interest, CPU 스택과 프레임 관련 타임라인에 자료가 보이는지 확인한다.
   프레임 테이블이 계속 비어 있으면 A1만 먼저 전달해 수집 구성을 확인한다. 빈 표를 끊김 0건으로 판단하지 않는다.

분석은 모드/동일 바이너리/열 상태 확인 후 탭→Navigation 간격, 초기 potential hang,
Hero 첫 layout, 프레임 갱신과 호출 스택을 비교한다. Value/레이아웃 구간은 겹칠 수 있고,
HeroFirstLayout은 실제 화면 표시 완료가 아니므로 합산하거나 단순 개선율로 오해하지 않는다.
같은 Serious라도 성능 조건이 같다는 뜻은 아니다. 측정에 따라 효과가 없으면 성능 개선 판정은 보류한다.

## 검증 결과 (2026-10-29)

- Automatic / BarOnly Release 기기용 빌드 통과 (서명 제외, warnings-as-errors).
- 같은 DerivedData에서 순차 빌드한 실행 파일 SHA-256 일치:
  `ae635f13df2962a11d305e139b8000bd743e0da5943a8a2eaf486d62284fa29d`.
- Launch/Profile 인자 검사: Release 및 상세 계측 공통, 스타일 인자만 다름.
- iOS 26.5 UI 4개 모두 통과: Automatic/BarOnly 상세 왕복과 3개 탭 전환,
  다운로드 알림의 현재 프로필 목록 이동, 검색 페이지의 상세/탭 왕복 상태 보존.
- git diff --check 통과. 실기기 성능 향상은 아직 검증하지 않았다.
