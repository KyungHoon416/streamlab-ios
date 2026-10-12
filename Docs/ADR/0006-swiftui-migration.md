# ADR-0006 — SwiftUI로 과제 UI 요구사항 복원

Status: Accepted — 2026-10-12 사용자 요청. ADR-0004의 UIKit/Storyboard 결정을 대체한다.
Implementation: written; new iOS build/runtime NOT TESTED.

## 맥락

과제 원문 1페이지는 “Swift 6 엄격 동시성 검사, iOS 18+, SwiftUI + AVFoundation”을 지정한다. 이전 사용자 요청으로 UIKit을 채택했지만 최신 요청은 SwiftUI다. UI 프레임워크와 Core 변경을 분리하고 AVFoundation 재생은 Phase 2로 남긴다.

## 결정

1. @main App / WindowGroup, NavigationStack, TabView와 SwiftUI View로 화면을 구현한다. ViewController, Storyboard, IBOutlet, SceneDelegate, UIHostingController 래퍼를 사용하지 않는다.
2. Core의 actor 경계·generation·취소 검사를 재사용한다. UI의 @MainActor ObservableObject 어댑터가 명시적 ObservableObjectPublisher로 변경을 전달하며 화면은 @StateObject로 소유한다. Core에 Combine/SwiftUI 종속성을 추가하지 않는다.
3. 선택마다 새 세션 UUID를 사용한다. 이전 세션 invalidate 후 .id(session.id)로 화면 트리를 바꾼다. 약한 Store 레지스트리로 다른 탭/상세 요청도 취소하되 화면을 붙잡지 않는다.
4. 화면 이탈/비활성에서 suspend, 보이는 화면의 active 복귀에서 resume. 검색 페이지·커서는 보존하며 무효화된 세션은 요청을 재개할 수 없다.
5. LazyVStack/LazyHStack, 콘텐츠 내 HUD/재시도, 고정 프로필 toolbar를 사용한다. 커스텀 glassEffect나 UIKit appearance 전역 변경은 없다.

## 대안과 결과

- Core @Observable 전환은 어댑터를 줄이지만 기존 Foundation 테스트 경계를 바꾸므로 선택하지 않았다.
- UIHostingController는 두 수명주기를 유지해야 하므로 SwiftUI App 진입점으로 단순화했다.
- Lazy UI에서 UIKit cell 개수는 적절한 검증 기준이 아니다. 접근성 ID와 결과 수, 실제 이동/격리를 확인한다. 전체 페이지 중복/등급은 Core 테스트로 확인한다.
- UIKit 빌드·접근성·메모리 PASS는 SwiftUI 증거가 아니다. 새 실행 이전은 NOT TESTED다.

## 검증

Core 17개 정의 유지; UI 11개 정의(백그라운드 페이지 재개 추가).
구조/참조 검사는 Linux에서 가능하나 컴파일, 접근성, 메모리, 런타임 경고는 Mac에서 재검증한다.

참고:
https://developer.apple.com/documentation/swiftui/stateobject
https://developer.apple.com/documentation/swiftui/scenephase
