# ADR 0011 — 실제 기록 기반 계속 시청

프로필 고정 PlaybackProgressStore의 v1 키를 유지하고 선택적 updatedAt만 추가한다.
기존 데이터는 distantPast로 정렬하며 키 구성요소를 복호화해 작품·소스를 복원한다.
프로필 prefix로 제한하고, 유효한 미완료 항목을 최근순으로 정렬/작품 중복 제거 후 최대 20개 반환한다.

홈은 ID 기록을 그대로 신뢰하지 않고 Repository.detail(profile:) 및 canView로 최신 권한/작품 존재 여부를 확인한다.
SwiftUI .task(id:)와 Task cancellation, refresh UUID, session.isActive 검증을 함께 사용한다.
프로필이 달라지면 기존 HomeView 세션 identity도 교체된다. 키즈도 동일한 Repository 제한을 거친다.
카드는 마지막 소스를 초기 소스로 전달하며 PlaybackModel이 재생 직전 다시 권한과 복원 가능 시간을 검사한다.

진행률 저장은 기존 정책을 사용하고 UI 변경 알림 대신 홈 노출/플레이어 닫기/foreground 복귀 시 조회한다.
Core 조회 테스트와 UI 실제 홈 복원/프로필 분리 테스트를 추가했다. Xcode 실행 검증 대기.
