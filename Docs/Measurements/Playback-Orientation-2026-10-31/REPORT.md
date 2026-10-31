# 실기기 권한 오류 후 화면 회전 콜백 크래시

기준 0227379. 사용자가 expired-once 인수로 데모 재생 시 재시도 불가/앱 중단을 보고했다. 스크린샷 호출 스택은 `_dispatch_assert_queue_fail` → Swift actor 격리 검사 → `closure #1 in PlaybackOrientationSession.request(in:landscape:)` → UIWindowScene geometry error handler다. preparing→failed는 의도한 권한 거부이며 그 이후 회전 요청 오류 콜백의 큐 불일치가 별도 결함이다. Fig 경고만으로 원인을 판단하지 않았다.

## 수정

MainActor 클래스 메서드 내부에서 만든 오류 클로저가 MainActor 실행 전제를 상속했다. 실기기의 UIKit 오류 콜백은 이 전제와 다른 큐에서 호출되었다. 회전 요청과 원래 방향 복원 모두 nonisolated factory에서 만든 Sendable 로그 전용 클로저를 전달하도록 변경했다. 클로저는 세션이나 UI 상태를 캡처하지 않는다. UI 회전 요청 자체와 세션 상태는 MainActor에 유지한다.

## 검증 범위

새 회귀 테스트는 MainActor에서 콜백을 얻은 다음 DispatchQueue.global에서 회전 거부/복원 거부를 각각 호출하여 크래시 없이 반환하고 실제 백그라운드 스레드였음을 확인한다. iOS의 실제 회전 거부 상황 자체를 강제한 테스트와 구분한다. 기존 entitlement UI 오류→재시도와 재생 세션 회귀도 재실행한다.

첫 테스트 작성에서 async 컨텍스트의 Thread.isMainThread 사용이 컴파일 거부되어 동기 Dispatch 콜백 안에서 확인하도록 보완했다. 런타임 수정의 Release 컴파일과는 별도 테스트 작성 오류다.

## 실기기 재확인

최신 main을 pull하고 StreamLab Scheme / Debug / 연결된 iPhone에서 새로 빌드·실행한다. `--ui-test-entitlement-expired-once` 하나만 켜고 상세→데모 재생→만료 안내→재시도→정상 재생→닫기를 확인한다. 키 오류/갱신 실패 인수도 각각 별도 실행한다. 디버거를 끄거나 중단점을 숨겨 우회하지 않는다. 수정본 실기기 재검증 결과는 아직 대기다.

## 최종 결과

- iOS 재생/Now Playing/회전 콜백 테스트 12개 PASS. 백그라운드 큐 거부 콜백 2개 포함.
- 권한 UI 회귀 4개 PASS: 만료·키 오류·갱신 실패 후 재시도 재생, 승인 대기 닫기/키즈 재열기.
- 실기기 대상 Release 컴파일 PASS. Xcode 27.0, simulator iOS 26.4, warnings-as-errors 적용.
- 스크립트 판정 6개 PASS, bash 문법/diff 검사 PASS.
- 실제 기기 수정본의 회전 거부/재시도 재확인은 사용자 확인 대기. 이번 테스트는 기존 사용자 크래시를 완료로 바꾸는 증빙이 아니다.

## 실기기 후속 확인 — 사용자 보고

2026-10-31 최신 수정 코드에서 만료 안내 후 재시도 시 앱 중단 없음, 영상 및 하단 시간 진행, 재생 화면 닫기 정상이라는 사용자 확인을 받았다. 이 시나리오는 실기기 검증 완료로 기록한다. 이번 보고에 키 오류/갱신 실패, 실제 FairPlay, 모든 회전 거부 상황이 포함됐다고 확대하지 않는다. 추가 원시 로그나 캡처는 제공되지 않았다.
