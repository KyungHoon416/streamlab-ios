# 현재 구현·검증 상태

기준일: 2026-11-06. 이 문서를 현재 상태의 시작점으로 사용한다. `ASSIGNMENT_PROGRESS.md`의 날짜별 내용은 작업 이력이며 과거의 ‘미구현’ 표가 현재 상태를 뜻하지 않는다.

과제 원문을 다시 대조한 [79항목 완료·잔여 점검](ASSIGNMENT_AUDIT_2026-11-06.md)을 추가했다. 확인 단위 71개 완료(89.9%), 8개 보완/미확인(10.1%)이다. 배점으로 산정한 점수나 작업 시간 비율이 아니며, 과제 전체 완료 판정은 아니다. 현재 남은 항목은 이 점검표를 우선한다.

제출 자료를 `submission-2026-11-06` 태그로 묶었다. 3분 32초 영상의 핵심 재생·F09·F10 장면을 확인하고 개인 알림을 가렸다. Firebase 관리자·업로드·전체 다운로드 예산을 반영한 아키텍처 PDF를 6쪽으로 갱신했다. 앱 코드·촬영 소스 근거·CI 실행과 남은 한계는 [제출 기록](SUBMISSION_RECORD.md)에 정리했다.

제출 이후 관리자 확장: MP4 업로드 한도 5GB, GB 전송량·4시간(240분) 입력 안내에 이어 2GB 이상 파일의 압축 계획을 추가했다. 원본 40% 크기·1GB 목표·화질 우선/샘플 환산·원본 업로드를 선택한다. 관리자 22개·Firestore 규칙 8개·Storage 규칙 2개, 브라우저 경계 9개 및 웹 빌드를 통과했다. 실제 압축은 Mac에서 수행하며 웹/서버 자동 압축은 없다. 관리자 Hosting 배포 및 관리자/앱 원격 CI가 성공했다(`923d3a6`). 실제 수 GB 전송 검증과 구분한다. iOS 다운로드 예산 1GB와 제출 태그·ZIP/PDF는 유지한다. [현재 업로드 정책](FIREBASE_CATALOG.md) · [압축 계획 검증](Measurements/Admin-Compression-2026-11-06/REPORT.md).

2026-11-02 추가: 사용자 Blaze 전환 후 관리자 MP4 직접 업로드·진행률·취소·500MB 제한과 Storage 보안 규칙을 배포했다. 단위 테스트 9개·Storage 규칙 2개 및 업로드 CI 통과. 실제 데모 파일 업로드·공개 저장·HTTP 206 부분 전송·원본 SHA-256 일치 확인 완료. 사용자가 드롭 업로드·저장 및 StreamLab-Firebase 실기기 MP4 재생·하단 시간 증가·탐색을 확인했다. [사용 순서와 제한](FIREBASE_CATALOG.md).

공개 작품을 기존 업로드 영상으로 교체한 뒤 실기기에서 변경된 영상 재생을 사용자 확인했다. 실기기에서 교체한 B는 처음부터, 복원한 A는 기존 위치에서 재생됨을 확인했다. 4K MP4도 관리자의 기존 업로드 연결·공개 저장 후 앱 홈 표시와 iPhone 재생까지 사용자 확인 완료.

Firebase HLS 작품 다운로드와 다운로드 탭 오프라인 재생 경로를 연결했다. 사용자가 iPhone에서 비행기 모드로 앱을 다시 열고 저장한 HLS 작품의 재생과 탐색 후 하단 시간 진행을 확인했다.

Firebase MP4 다운로드와 로컬 재생 경로를 추가했다. 사용자가 iPhone에서 4K MP4 다운로드 후 비행기 모드 재실행·재생·탐색과 하단 시간 진행을 확인했다.

아래 표는 저장소의 A/B/C/D 요구사항 매핑과 최신 증빙을 요약한다. 원문과 대조한 완료율의 계산 방식과 제한은 위 79항목 점검에 있다. 테스트 종류·실기기 보고·측정 한계를 구분한다.

2026-11-06 추가: 다운로드 작업의 500MB 고정 제한을 전체 1GB 예산과 다른 작업의 예약량을 반영하는 방식으로 수정했다(`04bb985`). 관련 자동 테스트 31개와 Firebase 앱 빌드를 통과했다. 이후 사용자가 최신 코드에서 F09·F10 샘플 다운로드 완료 및 비행기 모드 재생·하단 시간 진행·탐색을 확인했다. [다운로드 검증 기록](DOWNLOADS_QA.md#2026-11-06-다운로드-예약량과-작업별-허용량).

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
| C4 성능 | HLS 22회·프레임/Hang/Hitch·메모리/Leaks·전력·파일 I/O 증빙 확보 | [통합 보고서](Measurements/C4-2026-10-31/REPORT.md). HLS 20회 후 메모리 추세 확인. 실제 홈 표시 간격 p50 12.503ms / p95 25.005ms. 전후 개선은 미입증 |
| D 장애/재현 | F01~F10별 자동 근거, 카오스 고정 seed, HTTP fixture, CI 및 재현 스크립트 | F09 만료·갱신 실패·목록 복귀 및 F10 자막 변경·오프라인 닫기·재연결 후 10초 재생을 실기기에서 확인했다. [시나리오별 범위](CHAOS_ACCEPTANCE.md). 모든 OS 장애 조합/실기기 F01~F10 전체 완료는 아님 |
| 제출 자료 | README, ADR, 최신 6쪽 아키텍처 PDF, 검증·성능 보고서, 3분 32초 영상 | [제출 점검표](SUBMISSION_CHECKLIST.md), [실제 영상·버전 기록](SUBMISSION_RECORD.md). 촬영 바이너리 SHA는 직접 확인되지 않았으며 C4 개선 입증은 남음 |

## 남은 작업 — 우선순위와 완료 조건

1. **C4 전후 개선 증거**: 수치 확보와 보고는 끝났으나 변경 전후 개선은 미입증이다. 기존 A/B의 열 상태·손동작 차이와 초기 대기의 미확정 원인을 명시했다. [제출 시점 결론](Measurements/C4-2026-10-31/REPORT.md#2026-11-06-제출-시점의-결론).
2. **재현 환경**: 다른 Mac의 새 체크아웃·서명·실행 확인은 미실시다. 촬영 직전 소스 상태와 안내한 Scheme은 기록했으나 설치 바이너리의 정확한 SHA를 인증하지는 못한다.
3. **제출 범위 확인**: 영상에는 핵심 재생과 장애 2개가 담겼다. 검색·찜 추가·전송 진행/삭제 등 원안 대본의 일부 장면은 없고 기존 테스트·실기기 문서로 보완한다. 최종 영상과 PDF는 준비됐으며 전체 과제 합격을 선언하지 않는다.

Firebase 공개 카탈로그와 관리자 웹은 별도 Scheme으로 연결했다. 실제 운영 사용자 로그인·진도 동기화·DRM 서버는 현재 데모 구현 범위와 별개다. 원문 B1에는 ‘로컬 DB’가 명시돼 있으므로 atomic JSON journal 대안의 인정 여부 또는 DB 엔진 도입을 보완 항목으로 남겼다. SwiftData 자체가 지정된 것은 아니며, 이미 구현된 로컬 우선 저장·영속 큐를 전부 미구현으로 취급하지 않는다.

## 현재 근거 읽는 순서

1. [아키텍처](ARCHITECTURE_CURRENT.md) — 2026-11-06 앱 코드 04bb985 기준. Firebase 관리자·업로드·재생·파일 영속성·최신 다운로드 예산을 반영했다.
2. [원격 CI와 재현](CI_VALIDATION.md) — 현재 iOS 패키지 25개, 앱 UI는 별도 로컬 suite.
3. [F01~F10](CHAOS_ACCEPTANCE.md) — 각 PASS가 실제로 검사한 범위.
4. [C4](Measurements/C4-2026-10-31/REPORT.md) — 수치·조건·미판정 항목.
5. [제출 점검표](SUBMISSION_CHECKLIST.md)와 [시연 대본](DEMO_SCRIPT.md).
