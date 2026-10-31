# C2 재생·다운로드 진단 로그 최소화

기준 a2b6e94. 과제 C2의 회원 식별자·시청 이력·Playback URL 로그 보호 요구에 따라 실제 출력 지점을 점검했다.

## 확인한 문제와 변경

- PlaybackProgress의 프로필/작품 ID 및 복원 초는 OSLog private 지정이 있었지만 디버거 환경에서는 값이 보일 수 있다. 값을 Logger에 전달하지 않고 restore/fresh와 저장 위치 존재 여부만 기록한다.
- 회전/복원 거부 콜백의 localizedDescription 전체 공개 출력을 없앴다. nonisolated Sendable 콜백 구조는 유지한다.
- HLS 패키지 거부의 Debug 컨테이너 home/parent/확장자 출력 자체를 제거했다. 고정 거부 이벤트는 유지한다.
- HLS 실패의 임의 오류 도메인 출력을 공통 SafeDiagnosticError 요약으로 바꿨다.

SafeDiagnosticError는 Foundation/AVFoundation/UIWindowScene의 허용된 도메인과 숫자 코드만 출력하며, 알 수 없는 도메인은 other로 처리한다. localizedDescription, userInfo, underlying error, URL, 파일 경로를 요약에 포함하지 않는다. UI에 보여주는 안내와 저장 데이터, 다운로드 처리 정책은 변경하지 않는다.

## 유지하는 관측 정보

랜덤 재생 attempt ID, 고정 공개 샘플 source 코드, TTFF/rebuffer/failure 등 QoE와 기존 익명 전송/탐색 상태 로그는 유지한다. 현재 source 코드는 고정 enum이며 실제 작품 ID/URL이 아니다. 향후 임의 콘텐츠 source ID를 도입하면 별도 허용 목록이 필요하다. 기존 TTFF 집계 형식을 변경하지 않았다.

## 검증 범위

Core formatter 테스트는 토큰이 포함된 URL, 사용자 식별 문자열, 파일 경로, 중첩 오류, 줄바꿈 포함 임의 도메인을 입력하고 출력 문자열 전체가 안전한 고정 분류/코드와 일치하는지 확인한다. 앱의 모든 로그/외부 Apple 프레임워크 로그에 대한 전면 보안 감사를 완료했다는 의미는 아니다. 과거 수집 로그와 바탕화면 파일은 삭제하거나 변경하지 않는다.

## 실기기 확인

새 Instruments 측정은 필요 없다. 최신 코드를 새로 빌드하고 모든 entitlement 진단 인수를 끈 뒤 데모를 몇 초 재생하고 닫는다. 같은 작품을 다시 열어 이어보기와 하단 시간 진행을 확인한다. Xcode에서 PlaybackProgress 로그는 restore/fresh와 saved_position_available만 보여야 하며 profile/title/seconds 값은 없어야 한다. 다운로드를 한 번 완료·삭제해 기존 동작도 확인할 수 있다. 권한/회전 오류를 일부러 재현할 필요는 없다. 자동 테스트와 실기기 사용자 확인은 별도이며 이번 변경의 실기기 확인은 아직 미실시다.

## 최종 검증

- Core 오류 요약 테스트 3개 PASS (strict concurrency / warnings-as-errors).
- iOS 재생·권한 경계·회전 콜백 16개 PASS. 실제 로그에서 fresh 이벤트의 식별자/위치 제거와 회전 거부의 domain/code 요약을 관찰했다. restore는 코드 경로를 검토했으며 이번 테스트 로그에서 별도로 관찰하지 않았다.
- 기존 TTFF 집계 테스트 6개 PASS.
- 실기기 대상 Release 빌드 PASS. Xcode 27.0 / iOS 26.4 simulator.
- git diff 공백 검사 PASS. 실제 다운로드 오류/패키지 거부를 강제로 일으키는 실기기 검증은 이번에 하지 않았다.

## 실기기 후속 확인 — 2026-10-31

사용자가 최신 코드에서 이어보기·하단 시간 진행·다운로드 완료·삭제 정상 동작을 확인했다. 해당 기능 회귀는 사용자 보고 기준 완료로 기록한다. 실제 오류 로그의 개인정보 제거까지 사용자가 검사했다고 확대하지 않는다. 원시 로그/캡처는 별도 미제공.
