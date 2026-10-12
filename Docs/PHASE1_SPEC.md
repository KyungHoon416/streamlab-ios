# Phase 1 — SwiftUI 인수 기준

2026-10-12 원문 SwiftUI 조건 복원. ADR-0006이 UIKit 예외를 대체한다.
Swift 6 / iOS 18+ / SwiftUI. 전체 과제와 Phase 1 탐색 범위를 구분한다.

| 요구사항 | 구현 | 현재 검증 |
|---|---|---|
| SwiftUI 진입점·4화면 | App/WindowGroup, 프로필/홈/검색/상세 | 구조 PASS, iOS NOT TESTED |
| 프로필 3개·키즈 권한 | Repository와 세션 트리 | 기존 Core 이력 PASS, 새 실행 NOT TESTED |
| 2,000 고유 ID | fixture 재사용 | 로컬 PASS |
| 히어로·5레일·계속 시청 | LazyVStack/LazyHStack | UI NOT TESTED |
| 검색·커서·중복 방지 | CatalogStore/Repository | 새 UI NOT TESTED |
| HUD·재시도·Phase 2 안내 | SwiftUI 콘텐츠/alert | NOT TESTED |
| 역전·프로필 중 요청 완료 | generation/profile/cancellation | 기존 Core 유지, 새 실행 NOT TESTED |
| 화면·앱 수명주기 | StateObject, session UUID, onDisappear, scenePhase | NOT TESTED |
| 접근성·큰 글자·모션·기기 | semantic font, native controls, scroll | NOT TESTED |
| Strict Concurrency 경고 0 | Swift 6 complete + warnings-as-errors | 새 Xcode NOT TESTED |
| 메모리·런타임 | Release 반복/로그, Instruments 절차 | NOT TESTED |
| 원격 이미지 | 설계 제안, 로컬 아트만 구현 | 원격 로더 미구현 |

원격 이미지 lazy loading은 원문 A1 항목이다. Lazy 컨테이너/로컬 아트를 네트워크 로더 구현으로 보지 않는다. 재생·동기화·다운로드·카오스 전체는 후속 범위다. Phase 1 전체 완료는 미해결 범위 정리와 실제 검증 뒤 판정한다.
