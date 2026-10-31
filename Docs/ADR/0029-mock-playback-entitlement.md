# ADR 0029 — 재생 권한·키 상태 Mock 경계

2026-10-31 · 구현

## 배경

제공된 Netflix iOS 과제의 A2/C2는 실제 FairPlay 서버 구축 대신 키 상태·권한 만료·오류 흐름의 Mock 인터페이스를 요구한다. 기존 카탈로그 프로필 제한과 다운로드 파일 만료만으로 이 인터페이스를 대신하지 않는다.

## 결정

Domain의 PlaybackEntitlementProvider는 계정·프로필·작품·미디어별 grant를 반환한다. PlaybackEntitlement는 범위 일치, 허용 여부, 유효한 발급/만료 시각, 키 사용 가능 여부를 검사한다. 만료 시각과 같으면 거부한다. 취소 전후와 PlaybackModel의 요청 세대·활성 세션을 검사하여 늦은 응답을 적용하지 않는다. 선택적 진도 조회 이후 AVPlayer 생성 직전에도 유효기간을 재검사한다.

Presentation의 actor Mock은 valid/expired/denied/keyUnavailable/renewalFailed를 순서대로 주입할 수 있다. 기본 grant는 요청 시점부터 5분 동안 유효한 데모 값이며 과제가 정한 정책이 아니다. 실패 시 플레이어를 만들지 않고 기존 오류 UI와 제한된 수동 재시도를 사용한다. 재시도는 새 grant 요청이며 자동 무한 갱신은 없다. 기존 다운로드 만료·파일 lease 검사는 별도로 유지된다.

## 한계

이 Mock은 실제 인증 서버, HTTP playback/session, FairPlay 키 취득·복호화, 영속 라이선스, 신뢰 시계가 아니다. 로컬 Mock 재시도 성공은 오프라인에서 실제 라이선스를 갱신했다는 의미가 아니다. 시작 시점 검증만 하며 재생 중 만료 타이머는 제공하지 않는다. F09 전체(실제 저장 HLS와 오프라인 만료 조합)는 이번 테스트만으로 완료 처리하지 않는다. 실제 파일 만료는 이 grant로 해제할 수 없다.

## 검증

[검증 보고서](../Measurements/Playback-Entitlement-2026-10-31/REPORT.md), [실기기 확인](../PLAYBACK_ENTITLEMENT_QA.md).
