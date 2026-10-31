# 초기 대기 및 누락 표식 조사 · 2026-10-31

대상: c4-current-home-scroll-1.trace Run 1. 새로운 실기기 측정 없이 기존 기록을 추가 export했다.

## 약 57ms 대기의 구성

분석 구간은 3.848855041~4.002111791초, 메인 스레드 Hang 153.256750ms다. 같은 StreamLab 메인 스레드의 thread-state 및 virtual-memory interval을 구간 경계에서 잘랐다. File Backed Page In 구간을 합집합으로 만든 뒤 Blocked 구간과 교차해 중복 시간을 제거했다.

| 지표 | 결과 |
|---|---:|
| Blocked | 56.782504ms |
| File Backed Page In 이벤트 | 387개 |
| 페이지 로딩 구간 합집합 | 61.914749ms |
| 페이지 로딩 ∩ Blocked | 48.821460ms |
| Blocked 중 위 교차 비율 | 85.98% |
| 교차에 포함되지 않는 Blocked | 7.961044ms |

페이지 로딩 전체 61.9ms가 모두 대기인 것은 아니다. 같은 시간대에 발생한 VM/시스템 호출/스레드 상태를 더해서 총 지연을 만들지 않는다. 대기의 대부분이 파일 기반 페이지 로딩과 겹친다는 사실은 확인했다. 이를 특정 SwiftData/다운로드 파일/한 리소스의 읽기 때문이라고 좁힐 파일 식별 증거는 없다.

같은 구간 시스템 호출 합계는 open 약 7.752ms, getattrlist 약 2.100ms, read 약 0.638ms. sys_ulock_wait2 약 0.031ms, sys_ulock_wait 약 0.014ms, psynch_mutexwait 약 0.016ms로 단일 장기 앱 잠금을 뒷받침하지 않는다. 호출 합계는 대기 시간이나 순수 디스크 시간과 동일하지 않고 페이지 로딩과 중첩될 수 있다.

나머지 초기 비용에는 Running 94.707ms가 존재하며 기존 CPU 표본의 CA commit/layout, UIView/SwiftUI hosting layout, 세션 초기화가 함께 나타난다. 약 57ms만 없애면 초기 153ms가 모두 사라지는 구조는 아니다. 이전 compact2와 마찬가지로 페이지 로딩 조건에 따른 변동이 있어 최초 로딩을 사전 수행하는 임의의 warm-up은 비용을 다른 시점으로 옮길 수 있다.

## 표식 누락

- AppRootView.init의 RootInit, 프로필 선택 콜백의 ProfileSelection, CatalogTabs.onAppear의 StartupNavigationImmediate 호출을 소스에서 확인했다.
- HomeStartupTrace.enabled는 프로세스 인자에서 한 번 결정된다. trace 인자에는 --trace-home-startup이 있고 뒤쪽 표식도 존재한다. 계측을 3.945초에 켜는 앱 타이머나 지연 분기는 없다.
- Interval은 생성 시 begin, 해제 시 같은 ID의 end를 기록한다. 이번 파일의 첫 앱 표식은 3.945323666초 HomeBodyValue End이며 대응 Begin이 없다. OS signpost와 가공된 POI/Interval 표 모두 동일하게 초반 표식이 없다.
- 따라서 분석기의 이름 필터만 잘못되어 시작 표식이 빠진 경우는 아니다. 다만 파일 자체의 수집 시작/버퍼 손실/OSLog 활성화 시점 중 무엇이 원인인지 판정할 증거는 확보되지 않았다. 실제 측정 바이너리의 정확한 커밋도 trace만으로 확정하지 않는다.

초반 표식이 기록되지 않았다는 것과 해당 코드가 실행되지 않았다는 것은 다르다. 나중에 같은 이름의 표식을 다시 발행해 초기 시각처럼 표시하거나, 나머지 측정값으로 누락 시간을 보간하지 않는다.

## 수정 판단 및 다음 단계

이번 조사로 대기의 주요 연관 요인(파일 기반 페이지 로딩)은 확인했지만 제거할 수 있는 특정 앱 버그/불필요한 파일 요청을 확정하지 못했다. 표식 누락도 앱 코드 결함으로 확정되지 않았다. 따라서 앱 동작·탭 구조·로깅 API를 추측으로 변경하지 않았다. 성능 수정 완료나 문제 해결로 기록하지 않는다.

추가 실기기 측정은 현재 요청하지 않는다. 추가로 좁히려면 기존 VM/호출 스택에서 파일·메모리 매핑을 연결하거나 수집 손실 증빙이 필요하다. 현재 자료로 확보되지 않는 세부 원인은 미확정으로 남긴다. 임의의 warm-up, 첫 화면 지연, 세션 강제 재생성은 적용하지 않는다.

## 검증

wait-analysis.json에 정확한 수치와 원시 입력 해시를 보존했다. 교차시간 ≤ Blocked ≤ Hang 확인. 기존 thread-windows.json의 Blocked 56.782504ms와 일치한다. 원시 XML은 로컬 outputs에 보존하고 Git에 올리지 않는다. 앱 코드 변경 없음으로 Xcode 빌드를 반복하지 않았다.
