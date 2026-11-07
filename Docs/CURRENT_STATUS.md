# 현재 구현·검증 상태

기준일: 2026-11-06 과제 점검의 후속 검증 · 앱 코드 `9a4d395`. 이 문서를 현재 상태의 시작점으로 사용한다. 날짜별 `ASSIGNMENT_PROGRESS.md`와 기존 제출 태그는 이력이며 과거의 ‘미구현’ 표가 현재 상태를 뜻하지 않는다.

**과제 확인 단위 78/79 완료(98.7%), 1/79 실기기 결과 대기(1.3%)다.** 최초 잔여 8개 중 SQLite DB·전체 자동 CI·README 재현·상태도·샘플 사용조건 5개를 마쳤다. VoiceOver 전체 경로도 실기기에서 통과했다. 배점·작업 시간·운영 준비 비율이 아니다. [79항목 근거와 계산](ASSIGNMENT_AUDIT_2026-11-06.md).

[원격 실행 42239749042](https://github.com/KyungHoon416/streamlab-ios/actions/runs/42239749042)에서 Core·재생·앱 인수·네이티브 다운로드 네 job 모두 성공했다. Core·재생·앱 UI는 attempt 1, native 다운로드는 한 번 재실행한 attempt 2의 근거다. [이번 보완 보고서](Measurements/Final-Gaps-2026-11-06/REPORT.md)와 [CI 범위](CI_VALIDATION.md)에 실제 환경·수량·시간·한계를 기록했다.

## 구현과 증빙

| 영역 | 현재 구현·검증 | 남은 범위와 근거 |
|---|---|---|
| A1 홈·검색·프로필 | Mock 2,000개 및 Firebase 공개 카탈로그, 프로필 분리, 관리자 공개/수정 반영 | [Firebase](FIREBASE_CATALOG.md). 업로드 MP4·공개 HLS·영상 교체·아이콘 재실행은 기존 실기기 확인 |
| A2 재생·복구 | HLS/MP4/번들, 탐색·자막·음성·이어보기·유한 재시도, 회전·콜백 정리 | iOS 패키지 25개와 앱 UI 통과. [재생 상태도](States/PLAYER.md). 모든 OS/블루투스 조합 보장은 아님 |
| A3 진도 동기화 | revision/idempotency/명시적 restart, Mock A/B 수렴 | [F08](CHAOS_ACCEPTANCE.md). 운영 다기기 서버는 아님 |
| B 로컬 우선·정합성 | 프로필별 SQLite에 찜·최근 검색·이어보기 projection과 outbox 원자 커밋. 기존 JSON 이전 | [ADR 0030](ADR/0030-sqlite-local-projection-outbox.md), HTTP·SIGKILL 100건 복구. SwiftData가 아닌 SDK SQLite |
| C1 다운로드 | HLS/MP4, 유효 저장 영상 우선, 백그라운드, 동시 2개, 전체 1GB, 고정/LRU·일시정지·재개·만료·정리 | [상태도](States/DOWNLOAD.md), [기존 실기기 이력](DOWNLOADS_QA.md). F06/F09·정상 HLS UI 3개 원격 성공. 실제 ENOSPC는 주입과 구분 |
| C2 인증·권한 | Keychain·잠금/해제·로그아웃, grant 만료·키 오류 Mock, 진단 최소화 | [로그인/잠금](Measurements/Auth-Unlock-Restore-2026-10-31/REPORT.md), [실행 중 만료](Measurements/Runtime-Entitlement-2026-11-01/REPORT.md). FairPlay·신뢰 시계 아님 |
| C3 접근성 | Dynamic Type·고대비·Reduce Motion, 플레이어 설명 및 설명/터치 영역 자동 감사 | iPhone 15 Pro · iOS 26.6.1 전체 경로 PASS |
| C4 성능 | HLS 22회·메모리·Leaks·프레임·Hitch·HLS 전력·파일 I/O 근거 | [통합 보고서](Measurements/C4-2026-10-31/REPORT.md). 백그라운드 다운로드 전력 확인. C1·PV1·C2 비교 확보. PV2 재측정 대기 |
| D 장애/재현 | Core 31+247, chaos 3종 각 1,000 seed, SIGKILL, iOS 25, 앱 UI 9, HLS UI 3 원격 성공 | [F01~F10](CHAOS_ACCEPTANCE.md). F09/F10 기존 실기기 확인은 별도. 모든 실기기 OS 장애 조합 완료를 뜻하지 않음 |
| 문서/재현 | README 새 runner smoke 424초, Player/Download 상태도, 샘플 URL·사용조건, 14쪽 아키텍처 PDF | Xcode/runtime 사전 설치 조건. 과거 3분 32초 영상·태그·ZIP과 현재 앱을 구분 |

## 남은 1개 — 실행 순서

1. **동일 조건 C/PV 비교**: `StreamLab-C4-Scroll-C` / `StreamLab-C4-Scroll-PV`, 10초 준비·자동 30초 5왕복. `c4-controlled-C1.trace`, `c4-controlled-PV1.trace`, `c4-controlled-PV2.trace`, `c4-controlled-C2.trace`.

[Xcode 설정·조건·표식·판정 기준](FINAL_DEVICE_QA.md)을 따른다. 실제 표시 프레임을 집계하며 CADisplayLink 횟수를 FPS로 바꾸지 않는다. 결과가 개선되지 않았으면 그대로 보고한다. 새 데이터 없이 전후 개선이나 배터리 절감을 주장하지 않는다.

기존 앱의 데이터 이전은 앱을 삭제하지 않고 설치한 뒤 같은 프로필의 찜·최근 검색·이어보기를 확인한다. 로그아웃은 의도적으로 해당 계정 기록을 삭제하므로 이전 확인 전에 누르지 않는다.

## 관리자 확장과 제출 스냅샷

Firebase 관리자 Google 인증·Firestore 공개 카탈로그·Storage MP4 업로드를 연결했다. 현재 관리자 한도는 파일당 5GB, 앱 오프라인 전체 예산은 1GB다. 2GB 이상 파일의 압축 계획(원본 40%·1GB 목표·화질 우선·원본 업로드)은 예상 안내이며 실제 압축은 Mac에서 한다. 서버 자동 압축·HLS 변환·운영 사용자 동기화·DRM 서버는 없다. 사용자 장시간 영상은 과제 기본 fixture에서 제외한다. [정책](FIREBASE_CATALOG.md) · [관리자 검증](Measurements/Admin-Compression-2026-11-06/REPORT.md).

[현재 PDF](Architecture/streamlab-architecture-ko.pdf)는 9a4d395의 SQLite와 Firebase·재생·다운로드 구조를 그림으로 설명하는 14쪽 문서다. [기존 제출 기록](SUBMISSION_RECORD.md)의 `submission-2026-11-06` 태그·3분 32초 영상·ZIP 속 6쪽 PDF는 당시 버전으로 보존했다. 현재 앱 변경을 기존 촬영 빌드에 포함됐다고 설명하지 않는다. 촬영 바이너리의 직접 SHA 각인은 미확보이며 그 한계는 기존 기록에 유지한다.

## 근거 읽는 순서

1. [완료·잔여 79항목](ASSIGNMENT_AUDIT_2026-11-06.md)
2. [구조 설명](ARCHITECTURE_CURRENT.md)와 [이번 구현·검증](Measurements/Final-Gaps-2026-11-06/REPORT.md)
3. [원격 CI](CI_VALIDATION.md), [F01~F10](CHAOS_ACCEPTANCE.md), [C4](Measurements/C4-2026-10-31/REPORT.md)
4. [남은 실기기 순서](FINAL_DEVICE_QA.md)
