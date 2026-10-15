# ADR 0016 — 상세 화면 데모 회차 목록

상태: 구현, Apple SDK 실행 검증 대기 (2026-10-15)

## 결정

상세 화면은 메타정보/회차 선택만 담당하며 기존 PlaybackView/PlaybackModel로
재생을 위임한다. 별도 AVPlayer를 상세에 만들지 않는다. 대표 이미지 미리보기도
같은 전체 화면 플레이어를 열어 중복 오디오/수명 관리 문제를 피한다.

DetailEpisodeSection은 표시 데이터와 선택 콜백을 받는다. 현재는 고정된
데모 시즌 1의 세 Source를 사용한다. 실제 콘텐츠 회차/예고편인 것처럼 표시하지 않는다.
기존 titleID + sourceID + profileID 저장 키를 유지해 회차별 진행률을 읽는다.
상세에서 닫기 및 활성화 시 다시 읽고, 권한 재검사는 기존 재생 load에서 수행한다.
완료 기록은 현행 저장소에서 제거되므로 완료 배지를 새로 추론하지 않는다.

## 향후 데이터 연결

관리자 업로드 연동 시 안정적인 episodeID, seasonID, duration, thumbnail,
media URL을 Repository가 제공하도록 확장한다. Source의 데모 메타정보와
30초 길이 가정은 실제 모델로 교체해야 한다. 이 단계에서 원격 API, 로컬 DB,
영상 파일 업로드, 다중 시즌은 구현하지 않는다.

## 검증

새 UI 테스트는 2화 선택/seek/진행 갱신/다른 회차 기록 분리/재진입을 검사한다.
기존 자동 다음 화 테스트는 유지한다. 최대 글자 감사와 실제 VoiceOver도 필요하다.
Linux 구조 검사와 스크립트 구문만 PASS이며 Xcode/UI 실행은 NOT TESTED다.
