# 초기 진입 Blocked 대기 분석 (2026-10-30)

## 결론

compact2의 큰 초기 지연은 파일 기반 메모리 페이지 로딩과 겹치는 대기가 지배적이다.
특정 앱 락/세마포어 또는 동기 네트워크 호출이 599ms를 차지한다는 근거는 없다.
다만 파일 페이지 로딩 증가의 배경(캐시 상주 상태, 저장장치/시스템 부하, 코드 변경에
따른 접근 페이지 차이, 계측 영향)은 이 세 실행만으로 분리할 수 없다.
3476d34 변경의 성능 개선 완료 판정은 계속 보류한다. CPU 실행 시간 감소만으로도
개선이라고 단정하지 않는다. 이번에는 앱 코드 변경 없이 분석 결과만 기록한다.

## 검증 방법

각 trace의 Run 1에서 가장 큰 초기 potential hang 구간을 선택했다.
thread-state의 Main Thread Blocked 구간과 virtual-memory의 File Backed Page In
구간을 같은 시간 창으로 자르고, 겹치는 페이지 구간을 병합한 뒤 교집합을 합산했다.
따라서 시스템 호출 시간과 VM 시간을 더해 중복 집계하지 않았다.
syscall 및 context-switch-sample의 사용자 스택도 대조했다.

| 항목 | entry3 | compact1 | compact2 |
| --- | ---: | ---: | ---: |
| 초기 hang (ms) | 119.177 | 173.321 | 684.193 |
| Running (ms) | 102.354 | 94.269 | 83.008 |
| Blocked (ms) | 15.906 | 77.733 | 599.214 |
| File Backed Page In 건수 | 96 | 639 | 423 |
| 페이지 로딩 경과 시간 (ms) | 18.257 | 86.561 | 589.692 |
| 페이지 로딩 ∩ Blocked (ms) | 14.028 | 68.559 | 577.688 |

compact2의 Blocked 약 96.4%가 페이지 로딩 구간과 겹친다.
compact1보다 페이지 로딩 건수는 적지만 소요 시간이 훨씬 길다.
따라서 단순히 호출 횟수나 코드 연산량 증가만으로 지연을 설명할 수 없다.
세 기록 모두 전체 열 상태 Nominal이며 내장 디스플레이만 수집됐다.
Nominal은 저장장치/캐시/시스템/계측 조건이 동일함을 보장하지 않는다.

## 스택 근거

compact2 초기 창 2.429659375–3.113852458초의 대표 페이지 로딩:

- 약 10.433ms: RB::Path / RB::Symbol::Glyph의 심볼 도형 처리.
- 약 7.305ms: Binding.projectingTagIndex → AdaptableTabViewRoot의 탭 구성.
- 약 7.281ms: SwiftUI AnimatorState 및 그래프 갱신.
- 약 7.280ms: AnyNavigationPath / NavigationColumnState / NavigationAuthority.
- 약 7.114ms: CA::Render::Filter / CALayer / CABackdropLayer의 화면 합성.

syscall 대기에서는 madvise 약 26.037ms, read 약 7.400ms,
getattrlist 약 6.796ms가 관찰됐다. 이 수치는 VM 시간과 중복될 수 있어 합산하지 않는다.
madvise 스택은 BOM/CUI 자산 탐색 → UIImage 심볼 설정 → UITabBar.setItems로 이어진다.
일부 read 스택은 DurableMutationStore.read → MyListStore → CatalogSession.init이다.
로컬 목록 동기 복원은 후속 검토 대상이지만 SessionInit 전체 19.452ms이므로
약 684ms의 주원인이라고 표현하지 않는다.

context-switch-sample에는 대기 전환 스택 411개가 해당 초기 창에서 확인됐다.
일부 이벤트에는 스택이 없으므로 모든 대기의 세부 원인을 확정하지 않는다.
일반 Blocked 표식만 보고 앱의 락 경합이나 CPU 스케줄링 부족으로 단정하지 않는다.
File Backed Page In 역시 앱의 영상/포스터 파일 읽기만을 뜻하지 않으며,
프레임워크 코드·시스템 에셋 등 파일 기반 페이지 접근을 포함한다.

## 다음 조치

같은 계측을 무작정 반복하거나 근거 없이 AnyView 제거/예열/동기화 변경을 하지 않는다.
실제 수정 효과를 판정하려면 기존 빌드와 수정 빌드를 동일 조건에서 교차 비교하면서
Running뿐 아니라 페이지 로딩 건수·시간과 Blocked 교집합을 함께 봐야 한다.
현재 자료로는 앱 결함을 특정하여 수정할 근거가 부족하므로 코드 수정·회귀 테스트는
실행하지 않았다. 분석 산술 및 구간 병합/교집합 검증과 문서 diff 검증을 수행했다.
원본 trace/XML은 장치 정보가 포함될 수 있어 Git에 넣지 않는다.
