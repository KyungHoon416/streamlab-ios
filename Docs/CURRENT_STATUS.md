# 현재 구현·검증 상태

기준일: 2026-11-01. 이 문서를 현재 상태의 시작점으로 사용한다. `ASSIGNMENT_PROGRESS.md`의 날짜별 내용은 작업 이력이며 과거의 ‘미구현’ 표가 현재 상태를 뜻하지 않는다.

2026-11-02 추가: 사용자 Blaze 전환 후 관리자 MP4 직접 업로드·진행률·취소·500MB 제한과 Storage 보안 규칙을 배포했다. 단위 테스트 9개·Storage 규칙 2개 및 업로드 CI 통과. 실제 데모 파일 업로드·공개 저장·HTTP 206 부분 전송·원본 SHA-256 일치 확인 완료. 사용자가 드롭 업로드·저장 및 StreamLab-Firebase 실기기 MP4 재생·하단 시간 증가·탐색을 확인했다. [사용 순서와 제한](FIREBASE_CATALOG.md).

공개 작품을 기존 업로드 영상으로 교체한 뒤 실기기에서 변경된 영상 재생을 사용자 확인했다. 실기기에서 교체한 B는 처음부터, 복원한 A는 기존 위치에서 재생됨을 확인했다. 4K MP4도 관리자의 기존 업로드 연결·공개 저장 후 앱 홈 표시와 iPhone 재생까지 사용자 확인 완료.

이 표는 저장소의 A/B/C/D 요구사항 매핑과 최신 증빙을 통합했다. 원문 채점표 전체를 새로 대조한 합격 판정이나 완료율은 아니다. 테스트 종류·실기기 보고·측정 한계를 구분한다.

## 구현과 증빙

| 영역 | 구현 상태 | 확인 근거와 남은 범위 |
|---|---|---|
| A1 홈·검색·프로필 | 기존 Mock 및 별도 Firebase 공개 카탈로그 Scheme, 관리자 작품 등록·공개 설정 구현 | [Firebase 연결 범위·검증](FIREBASE_CATALOG.md): 실제 관리자 로그인·저장·공개/비공개 및 REST 조회 확인, CI 성공. 업로드 MP4와 공개 Apple HLS 샘플 모두 실기기 재생·하단 시간·탐색 확인 완료. 홈 화면 아이콘 재실행 후 두 공개 작품 표시도 사용자 확인 완료. [프로필 UI 5개](Measurements/Profile-Seek-2026-11-01/REPORT.md), [F01 역순 응답](CHAOS_ACCEPTANCE.md) |
| A2 재생·복구 | 번들/HLS, 탐색, 자막·음성, 이어보기, 재시도, 오디오/회전/종료 경계 구현 | [iOS 패키지 25개](Measurements/Observer-Lifecycle-2026-11-01/REPORT.md). 실제 OS 리셋·모든 블루투스 조건과 동일하지 않음 |
| A3 진도 동기화 | revision·idempotency·명시적 restart를 사용하는 서버 Mock 및 가상 A/B 구현 | [F08 충돌/수렴](CHAOS_ACCEPTANCE.md). 실제 여러 기기의 운영 서버 동기화는 아님 |
| B 로컬 우선·정합성 | 원자적 파일 영속 큐, 찜/검색/진도, 프로필·계정 격리, 충돌/재시도/취소 구현 | [실제 HTTP·인증 경계](Measurements/HTTP-Boundaries-2026-10-31/REPORT.md), [100건 SIGKILL 복구](Measurements/Mutation-Process-2026-11-01/REPORT.md). SwiftData DB를 사용한 구조는 아님 |
| C1 다운로드 | 홈 이어보기의 유효 다운로드 우선 선택, 네이티브 HLS, 백그라운드, 동시 2개, 관리 예산 1GB, 고정/LRU, 일시정지·재개·재시도·만료·공간 부족 정리 구현 | [홈 다운로드 우선 재생·실기기 확인](Measurements/Offline-Continue-2026-11-01/REPORT.md), [복합 자동 검증](Measurements/Combined-Failures-2026-10-31/REPORT.md), [실기기 이력](DOWNLOADS_QA.md). 실제 OS ENOSPC는 주입 시험과 구분 |
| C2 인증·권한 | Keychain 복원/잠금·로그아웃, 재생 grant 만료·키 상태 Mock, 진단 로그 최소화 | [로그인/잠금](Measurements/Auth-Unlock-Restore-2026-10-31/REPORT.md), [실행 중 만료 및 실기기 복구](Measurements/Runtime-Entitlement-2026-11-01/REPORT.md), [로그](Measurements/Diagnostic-Privacy-2026-10-31/REPORT.md). 실제 FairPlay/신뢰 시계 아님 |
| C3 접근성 | Dynamic Type, VoiceOver 정보, 고대비·Reduce Motion 대응 및 사용자 확인 이력 | [작업 이력](ASSIGNMENT_PROGRESS.md). 최신 모든 화면/오류 조합을 통합 감사했다는 뜻은 아님 |
| C4 성능 | HLS 22회·프레임/Hang/Hitch·메모리/Leaks·전력·파일 I/O 증빙 확보 | [통합 보고서](Measurements/C4-2026-10-31/REPORT.md). 실제 표시 프레임 간격·반복 잔존량 추세·원문 수치 기준의 합격은 미판정 |
| D 장애/재현 | F01~F10별 자동 근거, 카오스 고정 seed, HTTP fixture, CI 및 재현 스크립트 | [시나리오별 범위](CHAOS_ACCEPTANCE.md). 모든 OS 장애 조합/실기기 F01~F10 전체 완료는 아님 |
| 제출 자료 | README, ADR, 아키텍처 PDF, 검증·성능 보고서 존재 | [제출 점검표](SUBMISSION_CHECKLIST.md), [5분 시연 대본](DEMO_SCRIPT.md). 실제 시연 영상 녹화는 아직 없음 |

## 남은 작업 — 우선순위와 완료 조건

1. **제출용 시연 영상**: 대본에 따라 정상 흐름과 장애 2개를 녹화한다. 현재 대본 준비만 완료했으며 영상 파일이 생기기 전 ‘제출 완료’로 표시하지 않는다.
2. **C4 판정**: 기존 보고서에서 실제 표시 프레임 간격 및 회차별 잔존 메모리 증빙이 부족하다. 원문 목표 수치/지표 정의를 확인한 다음 기존 자료에서 추출 가능한 것부터 확인한다. App Update p95를 화면 프레임 p95로 바꾸거나 합격선을 임의로 정하지 않는다. 새 trace 일괄 측정을 요청하지 않는다.
3. **아직 보고받지 않은 실기기 조합**: F09 다운로드 파일+비행기 모드+Mock 만료/갱신 불가, F10 자막 변경+실제 연결 차단 후 닫기/새 재생은 [정확한 순서](CHAOS_ACCEPTANCE.md)를 따른다. 기존 정상 오프라인 재생·일반 권한 만료 복구 확인을 이 조합의 완료로 대신하지 않는다.
4. **최종 제출 버전 고정**: 제출 커밋과 앱 빌드, 사용한 CI/시뮬레이터/실기기 증빙 버전을 점검표에 기록한다. 날짜가 다른 성능 측정이 최신 빌드와 같다고 주장하지 않는다.

Firebase 공개 카탈로그와 관리자 웹은 별도 Scheme으로 연결했다. 실제 운영 사용자 로그인·진도 동기화·DRM 서버와 SwiftData 전환은 현재 데모 구현 범위와 별개다. 단지 SwiftData를 사용하지 않는다는 이유만으로 구현된 로컬 영속성을 ‘미구현’으로 표시하지 않는다. 원문에서 추가 필수 조건이 확인되면 별도 작업으로 반영한다.

## 현재 근거 읽는 순서

1. [아키텍처](ARCHITECTURE_CURRENT.md) — PDF는 2026-11-01 코드 44f5eb1 기준이며 실행 중 권한 검사와 홈 다운로드 우선 재생·실기기 확인을 반영했다.
2. [원격 CI와 재현](CI_VALIDATION.md) — 현재 iOS 패키지 25개, 앱 UI는 별도 로컬 suite.
3. [F01~F10](CHAOS_ACCEPTANCE.md) — 각 PASS가 실제로 검사한 범위.
4. [C4](Measurements/C4-2026-10-31/REPORT.md) — 수치·조건·미판정 항목.
5. [제출 점검표](SUBMISSION_CHECKLIST.md)와 [시연 대본](DEMO_SCRIPT.md).
