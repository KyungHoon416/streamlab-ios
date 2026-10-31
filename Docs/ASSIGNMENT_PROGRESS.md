## 2026-10-31 — 실기기 잠금 PASS 및 잠금 해제 후 로그인 복원

- 사용자 확인: 최신 코드의 실기기 잠금 진단 PASS. 잠금 중 읽기 거부·해제 후 복구·더미 삭제 확인을 사용자 보고 기준 완료로 기록했다. 원시 캡처/로그는 별도 미제공.
- 다음 경계 보완: 잠금 상태 앱 시작 시 계정 저장소 접근을 미루고 복원 대기 표시. 잠금 해제/foreground 알림으로 기존 로그인 복원을 재시도하며 이미 복원한 프로필은 유지한다.
- 기존 UI 5개 PASS. 새 대기 화면 식별자 실패를 수정한 뒤 새 잠금 복원 및 일반 로그인 복원 2개 집중 재검증 PASS. 최종 Release 빌드 PASS.
- [변경·실패 이력·검증 범위](Measurements/Auth-Unlock-Restore-2026-10-31/REPORT.md). 실제 OS 잠금 cold launch/재부팅 후 최초 잠금 해제 전 상태 및 운영 서버/TLS는 별도 범위다.

## 2026-10-31 — 앱 데모 인증 연결·실기기 잠금 진단

- iPhone 17 Pro / iOS 26.4 simulator UI 5개 PASS: 최대 글자 로그인, 로그인 복원/로그아웃 재실행, 전체 프로필 정리, 오프라인 변경 정리, 잠금 진단 더미 중단/정리 반복.
- 앱 인증 연결 결함은 발견되지 않았다. Debug 전용 더미 Keychain 잠금 진단을 추가하고 Release 제외까지 확인했다.
- 실기기용 Release 컴파일 PASS. 자동 검증 당시 실제 잠금 중 읽기 차단은 미판정이었고, 이후 사용자 실기기 PASS 확인은 아래 보고서에 추가했다.
- [검증 결과](Measurements/App-Auth-Lock-2026-10-31/REPORT.md) · [실기기 순서](Measurements/App-Auth-Lock-2026-10-31/DEVICE_CHECK.md). 운영 서버 인증/TLS·잠금 상태 cold launch는 별도 범위다.

## 2026-10-31 — 실제 HTTP·인증 만료·로그아웃 경계

- Core 248개 PASS. 실제 HTTP 10개와 시스템 Keychain 1개를 활성화해 검증했다.
- HTTP 성공 응답이 로그아웃 뒤 도착해도 차단되고 후속 요청이 서버로 나가지 않는 회귀 테스트를 추가했다. 앱 구현 결함은 발견되지 않았다.
- 통합 실행 스크립트와 필수 suite/표식 판정 보강, 판정 검증 22개 PASS.
- [결과와 남은 범위](Measurements/HTTP-Boundaries-2026-10-31/REPORT.md). 운영 서버/TLS·iOS 잠금 보호·앱 인증 연결/과제 전체 완료와 구분한다.

## 2026-10-31 — 데이터 충돌·복구 회귀 검증

- Core 247개 및 영속 큐/도메인 충돌/가상 시계 재시도 카오스 각각 1,000 seed PASS.
- 최종 판정을 세 카오스 suite 모두의 seed 완료 확인으로 강화했다. 완료/누락/실패/seed 불일치 판정 9개 확인 PASS.
- [검증 결과와 남은 범위](Measurements/Integrity-2026-10-31/REPORT.md). 실제 HTTP·iOS 통합 장애·전체 F01~F10/CI 완료를 뜻하지 않는다.

## 2026-10-31 — 미식별 페이지 추가 분석과 증거 한계

- 남은 130개/18.921ms를 벡터 아이콘 6.426ms, 런타임 문맥 5.832ms, 글꼴 등으로 분류했다. 파일 소유권 식별과 구분했다.
- 62개는 mmap 주소 범위와 대응하지만 fd/path가 없어 정확한 파일명은 미확정이다. 기존 trace의 세부 파일 식별 한계를 기록했다.
- 수정 가능한 앱 결함이 확인되지 않아 앱 코드는 변경하지 않았다. [근거](Measurements/C4-2026-10-31/current-home/UNMAPPED_PAGES.md).

## 2026-10-31 — 초기 페이지 로딩 소속 세분화

- fault 페이지와 스택 PC를 대조해 387개 중 257개를 코드 이미지에 대응했다. 시스템 이미지 대기 28.587ms, 앱 실행 코드 1.313ms, 미식별 18.921ms.
- 논리 이미지와 실제 backing 파일을 구분했다. 제거 가능한 앱 결함이 확인되지 않아 앱 코드는 변경하지 않았다.
- [페이지 소속 분석과 한계](Measurements/C4-2026-10-31/current-home/PAGE_FILES.md).

## 2026-10-31 — 초기 대기·표식 누락 조사

- 기존 trace의 Blocked 56.78ms 중 48.82ms(약 86%)가 파일 기반 페이지 로딩과 겹침을 확인했다.
- 초기 표식은 원시/가공 표 모두 누락됐으며 앱의 지연 활성화 분기는 없다. 정확한 수집 누락 원인은 미확정이다.
- 특정 앱 버그가 확인되지 않아 동작 변경은 하지 않았다. [조사 근거와 수정 판단](Measurements/C4-2026-10-31/current-home/WAIT_AND_MARKERS.md).

## 2026-10-31 — C4 후속 실기기 증빙 반영

- 현재 홈/스크롤, 다운로드·삭제 File Activity, power-2 앱별 전력 영향 결과를 [C4 보고서](Measurements/C4-2026-10-31/REPORT.md)에 보존했다.
- 셀룰러 다운로드 정상 동작 사용자 확인 완료. 다운로드 영상 재생 생략은 실패로 기록하지 않는다.
- 에너지·디스크는 증빙 확보로 갱신하되 전체 C4 목표 PASS와 구분했다. 충전 중 기기 전체 소모율과 Serious 열 상태의 디스크 시간 해석에 제한이 있다.
- 다음은 기존 자료 기반의 초기 표식 누락/Blocked 대기 원인 조사다. 추가 실기기 측정은 현재 요청하지 않는다.

## 2026-10-31 — C4 기존 측정 통합 집계

- 새 도구로 최근 초기 진입 7개 기록을 표식 기준 구간으로 재집계했다.
- HLS 22회, Allocations 및 고유 4 Run Leaks 증빙과 남은 검증 항목을 통합했다.
- [C4 성능 보고서·수치·한계](Measurements/C4-2026-10-31/REPORT.md). 기능 검증 완료와 성능 목표 미판정을 구분한다.

## 2026-10-31 — 기본 즉시 구성 복원 실기기 검증 완료

- 사용자 확인: 최신 코드로 홈 진입, 탭 왕복, 프로필 변경, 다운로드 알림 이동 모두 정상.
- 77681bf의 기능 회귀 확인 완료. 약 100ms 초기 CPU 비용이나 C4 성능 목표 달성을
  확인한 것은 아니다. [구현 및 검증 범위](HOME_NAVIGATION_FOLLOWUP.md).
- 다음 C4 산출물 보완으로 프레임 갱신/끊김 보고 자동화를 구현했다.
  [사용법과 한계](FRAME_SUMMARY.md). 추가 실기기 측정 없이 기존 trace로 검증했다.

## 2026-10-27 — 홈 레이아웃 분리·포스터 단일 이미지 레이어

- 냉각 후 새 Run의 초기/스크롤 hitch를 swap ID별 update/render와 대조했다.
  초기 레이아웃 비용과 스크롤 프레임의 offscreen pass가 남아 있음을 확인했다.
- 로드된 포스터의 GeometryReader/SwiftUI 마스크를 단일 contents 레이어로 교체하고
  추천/가로 목록을 독립 View로 분리했다. 표시 비율·모서리·터치 의미를 유지했다.
- 접근성 검사에서 발견한 상단 로그아웃 버튼을 접근성 이름이 있는 44pt 아이콘으로
  보완했다. 긴 상세 화면의 테스트 스크롤 한도를 늘리고 감사 기준은 유지했다.
- 픽셀/캐시 3개, 관련 UI 4개 및 최종 Release 빌드 통과. 실제 포스터 캡처 확인.
- [분석·변경·검증 범위](HOME_FRAME_OPTIMIZATION.md). 실기기 성능 개선량은 재측정 필요.

## 2026-10-27 — 초기 진입 반복 조회·저장 및 미사용 탭 구성 비용 축소

- 후속 trace의 초기 구간에서 다운로드 복원 시 저장, 기본 저장 경로 조회,
  포스터 번들 경로 조회와 첫 SwiftUI 레이아웃 경로를 확인했다.
- 미사용 검색/다운로드 탭은 첫 선택 때 생성하고 이후 상태를 유지한다.
  미전송 검색 기록 동기화와 백그라운드 다운로드 복원 시점은 유지한다.
- 저장소/번들 경로를 재사용하고 변경 없는 다운로드 journal 저장을 생략했다.
- Core 216개, 이미지 캐시 2개, 관련 UI 3개 및 기기용 Release 빌드 통과.
- [분석·변경·검증 범위](HOME_FRAME_OPTIMIZATION.md). 동기 journal 복원과
  시스템 첫 레이아웃 비용은 일부 남아 있으며 초기 지연 제거 완료는 미판정.

## 2026-10-27 — 홈 초기 동기화 및 포스터 렌더링 비용 개선

- 초기 지연 샘플의 mock 서버 JSON 해석 경로를 별도 actor로 이동했다.
- 동일 My List 스냅샷의 중복 발행과 로드된 포스터의 대체 화면 중복 그리기,
  겹친 사각형 클리핑을 제거했다. 파일별 단일 서버 소유권과 취소 검사를 유지한다.
- Core 216개, iOS package 5개, 관련 UI 3개 통과. 마지막 목록 갱신 보완 후
  영향받는 UI 2개 재검증 통과. 기기용 Release 빌드 성공(경고=오류).
- [변경 근거·검증·실기기 재측정 절차](HOME_FRAME_OPTIMIZATION.md).
  실기기 개선 폭과 C4 성능 통과는 아직 확인하지 않았다.

## 2026-10-25 — 실기기 HLS 반복 측정 완료 (22회)

- 사용자 확인 조건: iPhone 15 Pro, iOS 26.6.1, Release, Debug executable 해제,
  Wi-Fi, 같은 앱 세션. 측정 앱 커밋은 미확인이며 결과 기록 커밋으로 대체하지 않는다.
- take2 15회 + 추가 파일 7회 = 고유 HLS 22회. 모든 시작/종료 요약 및 지표 존재,
  중복/시작 누락/종료 누락 0. 20회 이상 측정·수집 완전성 PASS.
- 첫 프레임 준비 시간 p50 0.742초, p95 1.269초, 최소 0.474초/최대 2.092초.
  nearest-rank이며 실제 화면 표시 시각과 구분한다.
- 기록된 재버퍼링 0회/0초, 실패 0, 무효 상태 전이 0. 장시간 안정성을 보증하지 않는다.
- [보고서 및 증빙](Measurements/HLS-2026-10-25/REPORT.md): 회차별 CSV,
  HLS/번들 데모의 시작·종료 메시지 추출본, 원본 파일 해시를 보존한다.
  다른 앱 메시지가 포함된 전체 기기 로그는 저장소에 올리지 않는다.
- 성능 목표 판정은 미수행. C4의 Instruments 메모리/프레임/에너지·디스크 검증은 남아 있다.

## 2026-10-22 — HLS 재생 중 탐색 바 시간 표시 실기기 검증 완료

- 사용자 확인: 실기기에서 재생 중 탐색 바를 중간과 처음으로 옮긴 뒤에도 하단 시간이
  정상적으로 증가한다. 기존 시간 표시 멈춤에 대한 해당 경로의 실기기 재확인 완료.
- 확인 범위는 재생 중 타임라인 이동이다. 별도 처음부터 보기 버튼, 일시정지 상태의 탐색,
  모든 기기/OS 조합을 이번 사용자 확인에 포함하지 않는다.
- HLS 20회 측정 보류를 해제한다. 새 로그로 같은 프로필/작품/네트워크/이어보기 조건을
  유지하고 HLS 선택→첫 영상 후 약 5초 재생→X로 종료를 20회 반복한다.
  측정 중 수동 탐색/처음부터 보기/백그라운드 이동을 섞지 않으며 실패 시도도 보존한다.
- 이번 기록은 사용자 기능 검증이며 실측 TTFF 수치 또는 C4 성능 PASS가 아니다.
  시작 및 종료 요약이 포함된 원본 로그를 받은 후 별도로 집계한다.

## 2026-10-22 — 재생 중 탐색 바만 조작하는 HLS 회귀

- 사용자 요청에 따라 10초 앞/뒤, 처음부터 보기, 일시정지 버튼을 사용하지 않고
  실제 Apple HLS 재생 중 타임라인을 중간→처음으로 옮기는 UI 테스트를 추가했다.
- `testHLSPlayingSliderMiddleThenBeginningClockAdvances` PASS 44.707초.
  중간 이동 후 00:15:20→00:15:22, 처음 이동 후 00:00:01→00:00:04로 증가했다.
  각 탐색 후 재생 중 상태, 목적 구간 도달, seek 오류 없음도 확인했다.
- iPhone 18 Pro / iOS 27 Simulator / Debug. HUD 노출 유지 플래그만 사용하며
  실제 기기의 기존 멈춤 현상 해결 확인이나 TTFF 성능 측정으로 간주하지 않는다.
- 로그: `/private/tmp/streamlab-hls-playing-slider-final.log`.
  증빙 스크린샷은 해당 로그 끝에 표시된 xcresult의 테스트 첨부물에서 확인한다.
- 앱 구현은 이전 `200bb64`와 동일하며 이번 변경은 회귀 테스트와 검증 기록이다.

## 2026-10-22 — HLS 탐색 후 시간 표시 보완 (실기기 재확인 대기)

- 사용자 보고: 처음부터 보기/탐색 바를 처음으로 옮긴 뒤 영상은 움직이지만 하단 시간이
  0초에 머물고, 재생 버튼을 눌러도 표시가 증가하지 않음. HLS 20회 성능 측정은 보류한다.
- Slider의 값 setter가 editing=true보다 먼저 전달돼도 새 위치를 이전 모델 시간으로
  덮어쓰지 않도록 수정했다. 중복 종료 콜백의 재탐색을 막고, 실제 seek 시작 및 재생/재시작
  버튼에서 드래그 미리보기 상태를 해제한다.
- `seek_started`, `seek_completed`, `hud_action` 로그에 목표/실제/모델/표시 시간과
  rate·scrubbing·seeking을 기록해 플레이어 시계와 HUD 상태를 구분한다. 주기적 추가 로그는 없다.
- 자동 UI: 실제 Apple HLS로 저장 위치 복원→처음부터 보기→시간 증가,
  탐색 바 이동→시간 증가, 일시정지 상태에서 먼 위치→0초 탐색→재생→시간 증가를 검증한다.
- 수정 후 HLS UI 78.966초 PASS, 기존 탐색 타임아웃 복구 UI 67.854초 PASS:
  `/private/tmp/streamlab-hls-clock-after.log`.
- 최종 진단 로그 포함 HLS UI 재검증 PASS 79.026초: `/private/tmp/streamlab-hls-clock-final.log`.
- 최종 진단 로그 포함 Release warnings-as-errors 빌드 PASS:
  `/private/tmp/streamlab-hls-clock-release.log`.
- 최초 무서명 시뮬레이터 실행은 Keychain -34018로 로그인에 실패했고 임시 서명으로 재실행했다.
  수정 전 검증에서는 재시작 후 시계 증가가 확인됐으나, 30분 영상의 시작 근처에서 slider=0을
  지정한 검증이 9초에 머물렀다. 이후 먼 위치에서 0으로 이동하도록 테스트를 명확히 했다.
  이 결과를 실기기의 지속적인 시계 멈춤을 재현한 증거로 사용하지 않는다.
- 실기기 프로파일 연결은 실행 프로세스를 찾지 못해 수집하지 못했다. 따라서 근본 원인 확정,
  실기기 해결 완료 및 HLS 성능 PASS로 표시하지 않는다. 최신 빌드에서 재확인이 필요하다.

## 2026-10-22 — 포스터·상세 진입 실기기 확인 및 C4 보고서 보완

- 사용자 확인: 백그라운드에서 돌아온 뒤 포스터 표시와 상세 진입이 정상 동작한다.
  이는 `a0e71e3` 이미지 캐시 변경에 대한 사용자 실기기 확인이며, 실제 OS 메모리 압박이나
  Instruments retained 객체 측정 완료를 의미하지 않는다.
- 재생 품질 집계기에 재버퍼링 총 횟수/대기 시간, 발생 시도 비율, 시도별 누적 대기 시간
  p50/p95, 실패 비율과 입력 로그 SHA-256을 추가했다. 회차별 CSV에도 지표를 보존한다.
- 구버전의 누락된 재버퍼링 필드는 0으로 대체하지 않는다. 부분 지표/비정상 값/상충하는
  중복 요약은 거부한다. `--require-complete`는 불완전한 보고서를 남긴 뒤 종료 코드 2를 반환한다.
  로그 완전성 판정은 성능 목표 또는 무오류 통과 판정이 아니다.
- Python 회귀 6개 PASS: 집계 수학, 소스 분리/중복/누락, 값 검증, CLI 보고서·CSV·해시,
  누락 시 종료 코드와 기존 보고서 덮어쓰기 방지. 합성 데이터이며 실측 근거로 사용하지 않는다.
- 재현: `python3 scripts/test-ttff-summary.py`. 실기기 절차는 `Docs/TTFF_QA.md`.
- 앱 동작 변경은 없다. C4의 실기기 HLS 20회 측정, Instruments 프레임/메모리/에너지 측정은
  여전히 미완료이며 이번 작업은 제출용 보고서 도구 보완이다.

## 2026-10-22 — 이미지 캐시 메모리 압박 대응

- 앱 루트 한 곳에서 메모리 경고와 백그라운드 진입을 받아 디코딩 이미지 캐시(24MB 한도)와
  원본 데이터 캐시(16MB 한도)의 보유 항목을 해제한다. 화면별 옵저버를 추가하지 않는다.
- 캐시 정리 세대를 분리해 정리 전에 시작된 비동기 요청이 늦게 완료되어도 캐시를 다시 채우지 않는다.
  요청 구독자에게는 정상 결과를 반환하고, 화면이 이미 보유한 이미지는 유지한다.
  정리 후 새 요청은 다시 로드하고 정상 캐싱할 수 있다.
- Core 캐시 테스트 7개 PASS: 공동 요청/취소, LRU, 잘못된 응답, 정리와 완료 경쟁,
  10회 정리·재로딩. `/private/tmp/streamlab-artwork-memory-core.log`.
- iOS 패키지 테스트 2개 PASS: 실제 PNG 디코딩 캐시/바이트 캐시 10회 해제·재로딩,
  늦은 디코딩 결과가 두 캐시에 재적재되지 않음. 화면 보유 이미지가 유효함도 검사.
  `/private/tmp/streamlab-artwork-memory-ui.log` (0.101초).
- warnings-as-errors Release 앱 빌드 PASS: `/private/tmp/streamlab-artwork-memory-release.log`.
  구조 검사에는 시스템 메모리 경고만 사용하는 UIKit 어댑터를 명시했다.
- 재현: `caffeinate -i bash scripts/check-artwork-memory-mac.sh`.
- 제한: 10회는 캐시의 정리·재로딩 반복 단위 검증이다. 실기기 백그라운드 10회,
  실제 OS 메모리 압박, 프로세스 전체 메모리/retained 객체 및 C4 Instruments 계측 완료를 뜻하지 않는다.

## 2026-10-22 — 저장 공간 부족 대응 실기기 검증 완료

- 사용자 확인: `4f81e53` 적용 후 실기기에서 공간 부족 안내, 임시 파일 정리,
  공간 부족 해제 후 다시 다운로드가 정상 동작함.
- DEBUG 용량 측정값 주입으로 확인한 범위다. 기기를 실제로 가득 채운 OS ENOSPC
  또는 전체 F06 조합을 완료한 것으로 확대하지 않는다.

## 2026-10-22 — F06 전송 중 공간 부족 안내 및 후속 파일 정리

- 용량 부족/파일 예약량 초과로 취소할 때 원인을 먼저 저널에 저장한다.
  OS 취소 오류(-999)가 와도 원인 안내를 보존하며, OS Cocoa/중첩 POSIX ENOSPC도 구분한다.
  취소만 발생한 경우를 임의로 공간 부족으로 분류하지 않는다.
- 취소 콜백보다 늦게 생기는 패키지가 통합 검증에서 발견되어 후속 정리를 추가했다.
  실패 경로와 용량 예약을 유지한 채 1초 간격으로 세 번 확인/삭제한다.
  그동안 재시도·새 작업 시작·백그라운드 완료 통지를 보류한다. UI에는 임시 파일 정리 중으로 표시한다.
  삭제 실패 시 파일 크기를 계속 계상하고 경로를 유지하며, 다음 실행에도 실패 경로를 재정리한다.
- 공간 확인은 시작·재개·진행 중 공통 경로를 사용한다. 보호 중단 기록은 재실행해도 자동 재개하지 않는다.
- 단위 테스트 29개 PASS: 새 오류 분류 4개와 기존 예산/경로/만료/물리 용량 정책 25개.
  `/private/tmp/streamlab-transfer-pressure-core.log`.
- 실제 HLS 동시 전송 UI PASS 94.143초: 두 OS 작업 생성 및 패키지 경로 수신 후 용량 0 주입,
  두 작업의 공간 부족 안내, 대기 작업의 시작 차단, native/active/queued/cleaning/files 모두 0,
  저널 기록 3개 유지, 잘못된 완료 알림 0, 해제 후 재다운로드 완료 확인.
  `/private/tmp/streamlab-transfer-pressure-ui-settled.log`,
  `Test-StreamLab-2026.10.22_00-50-39-+0900.xcresult`.
- 기존 고정 파일 보존/공간 부족 후 재시도 UI PASS 127.944초:
  `/private/tmp/streamlab-transfer-pressure-ui-verified.log`의 해당 테스트.
  이 실행의 새 테스트는 화면 밖 lazy row를 기다려 실패했고, 최종 별도 실행에서 수정·통과했다.
- 1GB 예산에서 고정 파일 + 500MB 예약 두 개는 함께 허용되지 않으므로 고정 보존과
  동시 전송 취소를 별도 시나리오로 검증한다. 예산 제한을 우회하지 않는다.
- warnings-as-errors Debug 테스트 및 최종 Release 기기 대상 빌드 PASS:
  `/private/tmp/streamlab-transfer-pressure-release-final.log`. 구조·diff·스크립트 문법 검사 PASS.
- 재현: `caffeinate -i bash scripts/check-download-transfer-pressure-mac.sh`.
- 제한: DEBUG 용량 측정값만 주입하고 native HLS 작업/취소/파일 정리는 실제 실행한다.
  물리 기기를 가득 채우거나 앱 정지 중 OS ENOSPC를 재현한 것은 아니다.
  F06의 모든 조합 및 전체 F01~F10 완료로 표시하지 않는다.

## 2026-10-22 — 고대비·동작 줄이기 실기기 검증 완료

- 사용자 확인: `95041dc` 적용 후 실기기에서 고대비와 동작 줄이기가 정상 적용됨.
- 이 확인은 해당 설정 대응의 실기기 검증으로 기록한다. 전체 VoiceOver 이동 순서,
  모든 화면의 대비 감사 및 모든 OS 전환 효과 검증까지 완료했다는 의미는 아니다.
- 다음 개발 범위: F06 다운로드 전송 도중 저장 공간 부족 원인 보존과 동시 작업 정리/재시도 검증.

## 2026-10-22 — C3 고대비 및 동작 줄이기 대응

- 시스템 대비 증가 설정을 읽어 공통 주요 버튼을 진한 빨강/흰 테두리로 표시한다.
  흰 글자와 고정 배경 RGB(0.65, 0.02, 0.06)의 계산상 대비는 약 7.94:1이다.
  홈 카드 테두리, 포스터 종류 배지, 나의 리스트 버튼, 네트워크 배너 및 재생 컨트롤도 강화했다.
  영상 위 재생 버튼은 불투명 검정 배경/흰 테두리를 사용하고 보조 문구의 투명도를 제거한다.
- 시스템 동작 줄이기 설정에서는 SwiftUI transaction 애니메이션을 비활성화하고,
  무한 로딩 회전을 정적 모래시계와 기존 설명으로 대체한다. 수치가 있는 진행률은 유지한다.
  재생 시작 시 자동 가로 회전을 생략한다. 영상 재생, 탐색, 직접 선택하는 화면 회전은 유지한다.
- DEBUG에서만 설정 분기를 재현하는 인자를 제공한다. Release는 시스템 환경값만 사용한다.
- 검증 PASS: 고대비/동작 줄이기 재생 UI 38.671초. 세로 유지, 44pt 이상의 주요 조작 영역,
  일시정지·재개·탐색·수동 가로 회전·홈 복귀, 일시정지 화면 XCTest contrast audit(예외 필터 없음).
  `/private/tmp/streamlab-accessibility-display-final.log`,
  `Test-StreamLab-2026.10.22_00-07-42-+0900.xcresult`.
- 일반 설정 홈 자동 재생/HUD 표시 회귀 PASS 41.925초:
  `/private/tmp/streamlab-accessibility-display.log`.
  최초 실행의 새 테스트는 홈 복귀 후 상세 화면을 기대한 테스트 helper 오류로 실패했고,
  홈을 확인하도록 수정한 최종 실행이 통과했다.
- warnings-as-errors Debug 테스트 및 Release 기기 대상 빌드 PASS:
  `/private/tmp/streamlab-accessibility-release.log`. 화면 캡처에서 버튼 테두리·문구 배치를 확인했다.
- 재현: `caffeinate -i bash scripts/check-accessibility-display-mac.sh`.
- 실기기 확인 대기: 대비 증가와 동작 줄이기 각각 켜기/끄기 및 실행 중 설정 변경,
  로딩 안내/다운로드 진행률 유지, 자동 회전 생략과 수동 회전, 배너 가독성.
  전체 화면의 대비 감사, VoiceOver 전체 이동 순서, 모든 OS 전환 애니메이션의 실기기 검증 완료를 뜻하지 않는다.

## 2026-10-21 — C3 숨겨진 재생 컨트롤 터치 영역 보완

- 영상 영역의 GeometryReader 크기를 컨트롤 표시 버튼에 명시해 투명 라벨이
  터치/접근성 영역을 잃지 않도록 수정했다. 한 번 누르기는 표시, 두 번 누르기 탐색 처리 유지.
- 이전 홈 HUD 접근성 좌표 실패를 수정 후 재검증했다. 홈 테스트가 더 이상 앱 강제 종료로
  정리를 대체하지 않고, 실제 표시 버튼의 44pt 이상 영역·hittable·재생 유지·닫기를 확인한다.
- UI 2개 PASS, 76.353초, warnings-as-errors Debug 빌드/테스트 exit 0:
  `/private/tmp/streamlab-hud-accessibility.log`,
  `Test-StreamLab-2026.10.21_21-20-21-+0900.xcresult`.
- 구조 검사, diff 검사, 검증 스크립트 문법 PASS.
- 재현: `caffeinate -i bash scripts/check-playback-controls-mac.sh`.
- 실기기에서는 홈/상세 데모 재생 → 약 4초 기다려 버튼 숨김 → 영상 한 번 터치 →
  버튼이 다시 표시되고 영상은 계속 재생되는지 → 닫기 순서로 확인한다.
- 이번 범위는 C3 일부 보완이다. 실기기 VoiceOver, 고대비, Reduce Motion,
  전체 접근성 감사 및 전체 회귀 완료로 표시하지 않는다.

## 2026-10-21 — 실기기 데모 재생 검증 완료

- 사용자 확인: 커밋 `0778b26` 적용 후 홈 → 데모 재생, 홈 → 상세 → 데모 재생 모두 정상.
- 두 경로에서 보고했던 시작 직후 자동 일시정지 증상은 해당 실기기 확인 범위에서 해결로 기록한다.
- HLS/PiP/잠금 화면/외부 기기 제어 전체 실기기 회귀를 완료했다는 의미는 아니다.
- 다음 작업: 과제 C3의 재생 컨트롤 접근성. 홈에서 HUD가 숨겨진 뒤 표시 버튼의 터치 영역을 보완하고 재검증한다.

## 2026-10-21 — Physical capacity admission and protected-file recovery

- User confirmed expiration on a physical device.
- Fixed admission reclaim planning: consider both the 1GB app budget and actual
  device capacity. Select complete/expired unpinned, unleased files by LRU. If the
  full reclaim target cannot be met, fail before deleting any candidate. Recheck
  actual disk capacity after removal before creating a native task.
- Added opt-in DEBUG zero-capacity switch for admission only; real native HLS
  downloads and files remain in use. Disabled in Release and reset on process restart.
- Core 25 tests PASS (4 disk pressure + 21 budget/usage/expiry), strict concurrency
  and warnings-as-errors: `/private/tmp/streamlab-low-disk-core.log`.
- Actual HLS integration 1 PASS, 62.394 seconds, exit 0:
  `/private/tmp/streamlab-low-disk-ui.log`,
  `Test-StreamLab-2026.10.21_16-50-02-+0900.xcresult`.
  Download/pin -> inject zero admission capacity -> two new items fail with no new
  native tasks -> pinned package remains -> clear injection -> retry completes;
  pinned package still present. Teardown logs out.
- Generic iOS Release warnings-as-errors build PASS, exit 0:
  `/private/tmp/streamlab-low-disk-release.log`. Structure/shell syntax/diff checks PASS.
- Added `scripts/check-download-disk-pressure-mac.sh` and physical walkthrough in QA.
- NOT TESTED: physical disk exhaustion, actual mid-write ENOSPC, combined two-active
  transfers plus OS disk exhaustion (full F06), or full regression. LRU selection is
  unit-tested; UI integration exercises insufficient-candidate protection/recovery.

## 2026-10-21 — 다운로드 만료 처리

- 사용자 실기기 확인: 일시정지→백그라운드→재개→완료 정상.
- 과제용 7일 Mock 이용 기한, 만료 상태 저장, 새 오프라인 재생 차단, 재다운로드/삭제 지원.
- 기존 완료 파일은 최초 적용 때 7일을 부여한다. 재실행으로 기간을 연장하지 않는다.
- 만료 파일의 저장량은 유지하며 고정/재생 중 보호와 비고정 LRU 정책을 적용한다.
- 정책 21개 PASS, 실제 HLS 저장·만료·플레이어 차단·재실행·재다운로드 통합 검사 PASS,
  iPhone Release 빌드 PASS. 실제 7일 경과/실기기 만료 및 전체 회귀는 별도 확인 대상이다.
- 재현: `scripts/check-download-expiry-mac.sh`. 실제 DRM/서버 라이선스 구현은 아니다.

## 2026-10-21 — 다운로드 일시정지·재개

- 사용자 실기기 확인: 완료 알림 클릭 크래시 해결 및 다운로드 목록 이동 정상.
- 상세/다운로드 탭에서 같은 시스템 작업을 일시정지·재개한다. 상태를 저장하고,
  앱 재실행 시 작업이 남아 있으면 정지 상태로 복원한다. 작업이 사라지면 재다운로드 안내.
- 정지 중 예약량과 동시 작업 자리를 유지해 부분 파일을 보호한다. 두 개 정지 시 다음 작업은 대기.
- 정책 16개 PASS, 실제 HLS UI 3개 PASS(두 번의 실행): 재개 완료, 로그아웃 정리,
  앱 재실행 후 정지 상태 유지·취소. iPhone Release 빌드 PASS.
- 실기기 일시정지·재개 확인 및 만료 처리는 남아 있다. 상세 근거는 PHASE2_REPORT.md.
- 재현: `scripts/check-download-pause-mac.sh`.

## 2026-10-21 — 완료 알림 클릭 메인 스레드 크래시 수정

- 사용자 실기기 알림 클릭 크래시 보고 반영. 비동기 delegate 대신 명시적 완료 콜백을 사용해
  이동 처리와 시스템 완료 응답을 모두 메인 스레드에서 실행한다.
- 실제 시뮬레이터 시스템 알림 클릭→앱 복귀→다운로드 목록 검사 PASS(57.950초).
  HLS 완료를 기다리는 대신 테스트 로컬 알림을 예약했으며, 클릭은 실제 OS 배너에서 수행했다.
- iPhone Release 빌드 PASS. 수정 후 실기기 재확인은 남아 있다.
- 재현 스크립트: `scripts/check-download-notification-route-mac.sh` (OS 클릭 검사 추가).

## 2026-10-21 — 알림 선택 후 상세 화면 잔류 보완

- 사용자 실기기 문제 보고를 반영: 활성화 전에 이동 요청을 소비하지 않고, 복귀 시
  홈·검색·다운로드 상세 경로를 정리한 뒤 현재 프로필 다운로드 목록으로 이동한다.
- 상세→백그라운드→복귀 검사를 추가해 알림 이동 UI 3개 PASS(83.276초).
- iPhone Release 빌드 PASS. 실제 시스템 알림 클릭 재확인은 남아 있다.
- 재현: `scripts/check-download-notification-route-mac.sh`.

## 2026-10-21 — 완료 알림에서 다운로드 탭으로 이동

- 사용자 실기기 확인: 다운로드 시작·완료·삭제 시 저장 공간 표시 정상.
- 완료 알림을 누르면 현재 프로필의 다운로드 탭으로 이동한다. 새 실행에서는 로그인과
  프로필 선택을 거친다. 계정·프로필 자동 변경이나 자동 재생은 하지 않는다.
- 처리한 요청은 소비하며 로그아웃 시 대기 이동을 지운다. 재생 창은 강제 종료하지 않는다.
- UI 2개 PASS(59.243초), iPhone Release 빌드 PASS. 검사는 이동 요청 주입 방식이다.
- 실제 시스템 완료 알림 클릭·앱이 종료된 상태에서의 알림 실행은 실기기 확인 대상이다.
- 재현: `scripts/check-download-notification-route-mac.sh`.
- 이후 우선순위: 저장 공간 부족/시스템 종료 후 다운로드 복구 경계 검증과 보완,
  다운로드 변경을 포함한 전체 회귀. 운영 서버·DRM·실기기 성능 계측은 별도 남은 범위다.

## 2026-10-21 — 다운로드 저장 공간 안내

- 사용자 실기기 확인: 다운로드·영상 재생 중 연결 끊김/재연결 배너 정상.
- 기기 전체 다운로드 예산 카드 추가: 저장 완료·기타 파일·전송 예약·남은 예산 표시.
- 모든 프로필의 저장량을 합산하되 작품 목록과 프로필별 저장량은 기존처럼 분리한다.
- 예약량 중복 계산을 방지하고 실패한 작업의 남은 파일도 포함한다. 공간 부족 안내 추가.
- 정책 16개, 일반/최대 글자 UI 2개, iPhone Release 빌드 PASS.
- 실제 기기의 디스크 부족 스트레스는 남아 있다. 1GB 예산은 기기의 실제 여유 공간과 다르다.
- 재현: `scripts/check-download-storage-mac.sh`.

## 2026-10-21 — 다운로드·영상 재생 중 연결 끊김 안내

- 로그인 후 다운로드 화면과 전체 화면 플레이어에 연결 끊김 상단 배너 표시.
- 복구 시 기존 재연결 안내를 5초 표시하고 숨긴다. 저장된 영상 재생을 강제 중단하지 않는다.
- 다운로드 화면에서 탐색 버튼과 겹치던 배치를 수정하고 스크린샷으로 확인했다.
- 최종 UI 2개 PASS(95.642초), iPhone Release 빌드 PASS.
- 자동 검사는 경로 이벤트 주입·빈 다운로드 목록·로컬 데모 재생이다.
  실기기 HLS 전송/온라인 재생 중 실제 연결 끊김은 별도 확인한다.
- 재현: `scripts/check-offline-banner-mac.sh`. 상세 근거는 PHASE2_REPORT.md.

## 2026-10-21 — 실패한 다운로드 다시 받기

- 사용자 실기기 확인: 완료 알림·네트워크 재연결 배너 정상, 취소·로그아웃 후 알림 없음.
- 상세/다운로드 탭의 실패 항목에 ‘다시 다운로드’ 추가. 기존 기록을 직접 삭제하지 않아도
  새 작업으로 처음부터 다시 받는다. 고정 상태와 기존 저장 용량·동시 전송 제한을 유지한다.
- 중복 클릭 방지, 권한 재조회, 대기 중 프로필 전환·로그아웃·삭제 시 재시도 차단.
- 실제 HLS 실패→앱 재실행→재시도→저장·재생 및 프로필 전환 경합 UI 두 항목을
  각각 통과했다. 최초 검사의 계정/프로필 집계 기대값 수정 이력은 PHASE2_REPORT.md 참고.
- iPhone Release 빌드 통과. 실기기 실제 네트워크 오류 후 재시도는 별도 확인 대상이다.
- 재현: `scripts/check-download-retry-mac.sh`.

## 2026-10-20 — 다운로드 진행률·완료 알림·네트워크 복구 안내

- 사용자 실기기 확인: 백그라운드 다운로드와 전송 중 로그아웃 정상 동작.
- 다운로드 탭/상세에 퍼센트와 진행 막대 표시. 저장 검증 전에는 완료로 표시하지 않는다.
- 사용자가 알림을 허용하면 백그라운드 완료 시 로컬 알림. 취소·삭제·로그아웃은 대기 및
  전달된 알림을 제거하고 비동기 예약 중 경합도 차단한다. 거절해도 다운로드는 가능하다.
- 네트워크 단절 후 복구 시 상단 안내를 5초 표시. 최초 온라인에는 표시하지 않는다.
  루트와 플레이어가 상태를 공유하며 연결 힌트로 재생을 차단하지 않는다.
- 검증: 정책 19개, 다운로드/알림/취소/로그아웃/배너/큰 글자 UI 통과. 상세는 PHASE2_REPORT.md.
- 새 알림의 실기기 표시·집중 모드와 실제 네트워크 토글 후 배너는 별도 확인 항목이다.
- 재현: `scripts/check-download-notifications-mac.sh`.

## 2026-10-20 — 백그라운드·동시 전송·로그아웃 검증

- 사용자 실기기 확인 추가: 새 다운로드 보관함에서도 프로필별 목록 분리 정상.
- 시뮬레이터 실제 HLS: 홈 화면으로 이동해 45초 대기 후 복귀·저장 완료 확인.
- 네이티브 작업 2개 + 대기 1개 + 저장 패키지 2개를 관찰했다. 전송 중 로그아웃 후
  OS 작업/메모리 기록/JSON 기록/관찰 파일 모두 0개, 재실행 후에도 작업과 기록 0개 확인.
- 다운로드 정책 11개 및 iPhone Release 빌드 PASS. 자세한 실행 근거는 PHASE2_REPORT.md.
- 자동 검증은 앱의 동시 작업 제한과 복귀 시 저장 완료를 확인한다. 실기기 백그라운드,
  시스템 종료 후 깨우기, 지속적인 병렬 전송 속도와 저용량 스트레스 검증은 남아 있다.
- 재현: `scripts/check-download-lifecycle-mac.sh`.

## 2026-10-20 — 다운로드 보관함 추가 및 실기기 오프라인 확인

- 사용자 확인: 경로 별칭 수정 후 실기기 다운로드 성공. 비행기 모드에서 앱 재실행 후 재생·앞뒤 탐색 성공.
- 추가 구현: 다운로드 탭, 현재 계정·프로필별 목록/저장 용량, 보관함 직접 재생, 고정/삭제 및 상세 연결.
- 상세와 보관함은 동일한 상태/동작을 공유한다. 메타데이터는 기존 JSON, 영상은 시스템 HLS 패키지이며 SwiftData 도입은 아니다.
- 검증 범위 및 결과는 PHASE2_REPORT.md의 최신 항목을 참고한다.
- 실기기 새 보관함 UI, OS 백그라운드 깨우기, 실제 공간 부족·동시 전송·전송 중 로그아웃, 전체 회귀는 별도 확인한다.
- 아래 항목은 당시 이력이며 실기기 비행기 모드 미확인 표시는 위 사용자 확인으로 갱신된다.

## 2026-10-20 — 오프라인 다운로드 구현 및 실제 저장 검증

- 구현: Apple HLS 샘플 다운로드, 진행 표시, 앱 재실행 복원, 로컬 재생, 고정/삭제,
  프로필·계정 분리, 로그아웃 정리, 동시 2개, 1GB 예산과 비고정 파일 LRU 정리.
- 실제 다운로드 → 고정 → 재실행 → 저장 파일 재생 → 삭제 UI: PASS (최종 58.511초).
- Core: 실제 실행 206개 PASS, 별도 환경을 요구하는 10개 SKIP. 다운로드 정책 8개 포함.
- 최종 영향 범위 UI: 7개 PASS, 실패 0개, 408.954초, exit 0.
- 실제 iPhone 비행기 모드·백그라운드·저장 공간 부족 검증은 남아 있다.
  DRM/운영 서버 연동 및 전체 UI 회귀 완료를 뜻하지 않는다.
- 자세한 근거는 PHASE2_REPORT.md, 실기기 순서는 DOWNLOADS_QA.md를 참고한다.

## 2026-10-20 — 언어 회귀 확인 및 전체 회귀 재개

c0bc5c6 사용자 제공 languages-DEZELf 로그: 정책/저장 10개와 언어 UI 2개 모두 PASS.
회차 전환·재실행·프로필 분리까지 확인했다. 실행 환경에 프로젝트/스킴 로컬 변경이
기록돼 있어 해당 환경의 결과로 한정한다. 전체 Core/UI 및 새 커밋 결과와 혼동하지 않는다.
전체 검증의 서명·빌드 경로와 Now Playing UIKit 구조 검사 허용 목록을 수정했다.
전체 UI 실행은 재생 UI 실패 재현 후 중단했다. 아래 내용은 당시 이력이며 최신 결과는 위 항목을 우선한다.

# 원본 과제 진행 체크리스트

## 최신 확인 — 2026-10-20

- 실기기 사용자 확인: 영어 직접 표시, 음량 0 자동 자막, 음량 복원 시 자막 끄기, 로그인 화면 VoiceOver 완료.
- 0e7b1a8: 자막 정책/저장 8개 테스트와 시뮬레이터 빌드 로그 통과 확인.
- 6aa0ff2: Forced 영어 대신 전체 자막 선택 수정. 실기기 확인 완료, 자동 테스트 10개 및 빌드 로그는 미수신.
- 다음 검증: scripts/check-languages-mac.sh — 정책/저장 10개와 기존 자막 seek/회차/재실행/프로필 분리 UI 2개. 실행 전이므로 완료 처리하지 않는다.
- 아래 날짜별 표는 당시 이력이다. 이후 구현과 검증은 PHASE2_REPORT.md 최신 항목을 우선하며 전체 과제 완료율로 환산하지 않는다.


## 현재 작업 기준 — 2026-10-16 재개

아래 표가 과거의 단계별 표보다 최신이다. 구현과 실행 검증을 구분한다.

| 영역 | 구현 및 확인된 상태 | 남은 항목 |
|---|---|---|
| A1 홈/탐색 | 3프로필, 2,000 fixture, 페이지네이션/검색, 비동기 이미지 캐시, 찜 | 나의 리스트→추천 실패 보정 후 Mac 재검증 |
| A2 플레이어 | HLS/로컬 재생, seek, 트랙 선호/대체, 회차, 복원, 복구 한도, QoE | native 오디오 대체 실행 증거, OS 리셋, 전체 상태 효과/회귀 검증 |
| A3 복원 Mock | revision/idempotency/restart 서버 Mock와 플레이어 연결 구현 | 실제 네트워크/서버 영속성/홈 서버 동기화 미구현 |
| B 정합성 | 프로필 격리 및 취소 기반, UserDefaults 로컬 저장 | 영속 mutation DB/큐, 409/429, 401 single-flight, 재실행 100건 복구 |
| C 다운로드/보안 | 프로필 제한, 일부 진단 익명화 | 다운로드 매니저/예산/LRU, Keychain 인증, entitlement/DRM Mock |
| C 접근성/성능 | 큰 글자 플레이어 최신 로그 PASS, TTFF 수집/집계 도구 | 전체 접근성 경로, 실기기 20회 TTFF/메모리/스크롤/에너지 보고 |
| D/제출 | ADR/개별 race 테스트/검증 스크립트 존재 | F01–F10 통합 재현, 최종 성능 보고, 5분 시연 |

실기기 자동 PiP는 기존 사용자 보고 범위에서 PASS 이력이 있다. 기기/iOS 조건 및
전체 PiP 회귀는 별도 확인해야 한다. 과제 전체 완료로 표시하지 않는다.
현재 중단 지점은 나의 리스트 회귀 실패이며 변경/근거는 PHASE2_REPORT.md 최신 항목 참조.


## 자막 대체 검증 PASS · 다음 검증: 실제 HLS 오디오 역할 대체 — 2026-10-16

사용자 RESULTS(20261016-013618): Core/HLS 자막 대체/QoE 수집 PASS.
근거: Docs/Validation/hls-tracks-20261016/RESULTS.txt. 요약 제공 기준이며 원본 xcresult는 미첨부.
기존 자막 누락/복원/프로필 격리 테스트와 실제 HLS 자막 선호 유지 테스트가 통과한 결과다.

일반 영어만 제공하는 Apple HLS 소스를 추가했다. 원격 master 조회에서 en 일반 음성만
선언되고 DVS characteristic이 없음을 확인했다. 기존 DVS 소스는 en-US와 화면 해설을 선언한다.
manifest 조회는 재생 PASS를 의미하지 않는다. 오디오 행에는 실제 AVFoundation 역할에 따라
'일반 음성'/'화면 해설'을 표시한다. 저장 및 fallback 로직은 기존 구현을 재사용한다.

새 UI 테스트: DVS 선택 → 일반 영어 소스의 같은 언어/다른 역할 대체 안내와 선택 확인 →
DVS 소스로 복귀 시 복원 → 앱 재실행 복원 → 새 프로필 B의 기본 오디오 확인.
실제 native 트랙을 사용하며 목록을 제거하는 주입 플래그는 사용하지 않는다.
기존 HLS 자막 테스트와 함께 실행한다. Core에는 en-US DVS → en 일반 음성 사례를 추가했다.
검증 명령: `caffeinate -i bash scripts/check-hls-audio-fallback-mac.sh`.

구조/shell PASS. 새 Core/Xcode/UI 테스트 NOT TESTED.
자동 검증은 목록/선택/재생 상태를 확인하며 실제 해설 청취 증명은 아니다.
재생 불가 트랙, 실제 OS 리셋, 실기기 QoE/PiP, 전체 회귀는 NOT TESTED 유지.


## HLS 회차 검증 통과 · 다음 검증: 네이티브 자막 누락 — 2026-10-16

사용자가 제공한 RESULTS(20261016-011640).txt를 근거로 Core/HLS 회차 UI/QoE 수집 PASS.
HLS 전용 스크립트는 자동 다음 회차·최종 종료와 회차별 진도 복원 두 테스트가 실제 passed인지 검사한다.
근거 보관: Docs/Validation/hls-episodes-20261016/RESULTS.txt (사용자 제공 요약, 원본 xcresult 미첨부).
QoE PASS는 수집 및 관측된 상태 전이 오류 없음이며 성능 목표 달성을 뜻하지 않는다.
이 결과가 위 항목에 대한 이전 NOT TESTED/FAIL 이력을 대체한다. 전체 회귀 PASS는 아니다.

다음 자동 테스트는 로컬에서 한국어 선호 저장 → 실제 외부 HLS의 네이티브 자막 목록 조회 →
한국어 미제공 안내 및 단일 대체 선택 → 실제 재생 유지 → 로컬 복귀 후 한국어 복원을 검사한다.
트랙 조회 실패를 대체 성공으로 인정하지 않는다. 자막 제거 주입 플래그는 사용하지 않는다.
기존 로컬 누락/복원/프로필 격리 테스트도 함께 실행하고 두 테스트의 passed를 확인한다.
외부 Apple HLS의 제공 트랙이 변경되면 Fixture 전제 실패로 조사하며 skip/PASS로 우회하지 않는다.

추가 파일: scripts/check-hls-tracks-mac.sh. 실행은 인터넷 연결 후:
`caffeinate -i bash scripts/check-hls-tracks-mac.sh`
새 코드 구조/shell 검사 PASS. 새 Swift/Xcode/HLS 자막 UI 검증 NOT TESTED.
네이티브 재생 불가 트랙 및 오디오 역할 대체, 실기기 QoE/실제 OS 리셋/PiP/전체 회귀는 여전히 NOT TESTED.


## A1 이미지 비동기 로딩·메모리 캐시 — 2026-10-16

CatalogArtwork가 실제 PNG를 비동기로 읽고 ImageIO로 최대 720px 다운샘플링한다.
6개 자체 생성 추상 PNG Fixture를 2,000개 콘텐츠의 visualSeed로 재사용한다.
선택적 artworkURL이 있으면 HTTPS 로더를 사용하고 없으면 번들 이미지로 오프라인 동작한다.
로딩/실패 시 기존 그라데이션·아이콘 placeholder를 유지한다.

원본 16MiB LRU, 이미지 1개 최대 8MiB, 디코딩 이미지 24MiB LRU.
동일 URL 요청은 합치며 마지막 구독자 취소 시 작업을 취소한다. 이전 세대의 완료는 무시한다.
SwiftUI task(id:)와 generation 검사로 화면 이탈/이미지 변경 후 늦은 UI 반영을 막는다.
이 수치는 캐시 자체의 한도이며 표시 중 이미지, URLSession 캐시 등 전체 프로세스 메모리 한도는 아니다.

Core 캐시/취소 테스트 5개 추가. 구조/shell PASS. Swift/Core/Xcode/UI NOT TESTED.
실제 HTTPS 서버/시각 QA/Instruments 메모리 측정도 NOT TESTED.
검증: `caffeinate -i bash scripts/check-artwork-mac.sh`
직전 4836ed2 사용자 로그: Core 59개 + A3 실제 플레이어 UI 1개 PASS.


## A3 플레이어 연동 · 가상 기기 A/B — 2026-10-16

직전 30b9e54의 Core 56개와 A3 시뮬레이션 8개는 사용자 Mac 로그에서 PASS 확인.
이번 변경은 Debug 상세 화면의 가상 기기 A/B 선택을 실제 AVPlayer 진도 저장/복원에 연결한다.
로컬 저장은 기존 UserDefaults 경로를 유지하고 Mock 모드는 서버 값만 사용한다.
앱 내 두 가상 기기는 프로세스 공용 Mock을 공유하며 프로필/작품/회차 키를 분리한다.
닫기 저장 후 다음 열기 순서, FIFO 체크포인트→restart, 충돌 이후 저장 차단 Core 테스트 3개와
A 재생→B 복원→restart→A 초기화 UI 테스트 1개를 추가했다.

이번 변경: 구조/shell PASS. Swift/Core/Xcode/UI NOT TESTED.
실제 기기 간 네트워크, 서버 영속 저장, 홈 계속 시청 레일의 서버 연동은 아직 미구현.
30초 로컬 영상으로 UI 검증하며 정확한 25:40은 기존 Core 테스트에서 검증한다.
실행: `caffeinate -i bash scripts/check-progress-playback-mac.sh`


## A3 기기 간 진도 복원 Mock — 2026-10-16

- 도메인 계약, actor 서버 Mock, 기기별 클라이언트 구현.
- 25:40 복원, revision 충돌 거절, restart=0 새 revision, UUID 중복 처리.
- 지연/역전 응답, 같은 revision 동시 쓰기, 프로필/콘텐츠/회차 격리 자동 테스트 8개 추가.
- 구조/shell 검사 PASS. Swift/Core 실행은 NOT TESTED.
- 기존 AVPlayer/UserDefaults에 연결한 것은 아님. 실제 기기 간 네트워크와 영속 서버는 미구현.
- 실행: `caffeinate -i bash scripts/check-progress-sync-mac.sh`
- 설계: Docs/ADR/0021-multi-device-progress-revisions.md

직전 af5a25e 사용자 로그: Core PASS, 미디어 복구 UI 4개 PASS,
오디오 메인 스레드 경고 미관측 PASS. 실제 OS 리셋/실기기 성능/전체 회귀는 NOT TESTED.


## 미디어 리셋·재시도 한도 — 2026-10-15

리셋 알림의 generation/session 검사, 기존 플레이어/Task/PiP 정리,
사용자 재시도 시 새 플레이어/오디오 세션 준비 추가. 자동 재시도는 0회,
사용자 요청은 같은 표시/소스에서 최대 3회. 소진 UI에 남은 횟수를 표시한다.
리셋된 객체의 현재 위치를 저장하지 않고 마지막 정상 진도를 유지한다.
Core 예산 테스트 3개, 리셋 주입/한도 소진 UI 2개와 회귀 2개를 전용 스크립트로 실행.

PASS: 프로젝트 구조/스크립트 구문. NOT TESTED: 수정 후 Xcode/Core/UI,
실제 OS 미디어 서비스 재시작, 리셋-프로필/seek 경쟁, 실기기 PiP.
앞서 014a074의 실제 HLS 회차 테스트 결과도 아직 받지 않아 NOT TESTED 유지.
이번 코드는 관측 reducer 전체를 AVPlayer 명령 상태 머신으로 바꾼 것은 아니다.
검증: scripts/check-media-recovery-mac.sh, ADR 0019.



## HLS 테스트 시즌 연결 — 2026-10-15

이전 48ec545 검증: 사용자 core(5).log XCTest 12개 + Swift Testing 33개 PASS,
트랙 fallback/자막 UI 2개 PASS. 실제 HLS 누락 트랙은 여전히 NOT TESTED.

새 구현: 플레이어 소스 메뉴에 HLS 테스트 시즌 1~2화. 기존 Apple 공개 샘플
bipbop 및 오디오 비교 URL을 재사용하되 고유 progressID로 로컬 진도를 분리.
1화 종료 시 기존 10초 카운트다운/취소/지금 재생을 거쳐 2화 이동.
2화에는 nextEpisode가 없으므로 마지막 종료. HLS 실패 알림/PiP 정책도 재사용.
실제 작품 회차/신규 콘텐츠 업로드/상세 회차 목록 서버화는 이번 범위가 아니다.

새 opt-in UI 2개: 실제 HLS 종료 seek/자동 이동/마지막 종료,
회차 간 새 진도/저장 위치 복원. 외부 서버 접속 실패는 실패로 남긴다.
전용 스크립트는 두 테스트의 passed 로그까지 확인하여 skip을 성공 처리하지 않는다.
PASS 구조/스크립트 구문. NOT TESTED 새 Swift 빌드/UI 실재생, 장시간 자연 종료,
실기기/네트워크 단절 중 회차 전환. Docs/HLS_EPISODES_QA.md 참조.



## A2 트랙 대체 처리 보강 — 2026-10-15

이전 bf55787 사용자 첨부 검증: Core XCTest 8개 + Swift Testing 7개 PASS,
선택 UI 4개 PASS, QoE 요약/invalid_transitions=0 확인.
이는 이번 변경의 통과 근거가 아니라 이전 버전 검증 이력이다.

이번 변경: native 선택 직전 isPlayable 확인, 빈 playable 목록 안내, 재요청 시
이전 그룹/목록 제거. 선호 언어는 fallback으로 덮어쓰지 않는다.
TrackFallbackTests 4개 및 없는 한국어→복원→재실행→B 프로필 분리 UI 테스트 추가.
PASS 구조 검사/스크립트 구문. NOT TESTED Swift/Core/UI 실행, 실제 HLS 트랙 장애 통합 검증.

남은 A 순서: 트랙 대체 검증 → 실제 HLS 회차 → 네트워크 재시도 한도/미디어 서비스
리셋 → 상태 전이 효과 통합/QoE 실측 → A1 이미지 로더 → A3 revision 서버 Mock.
A 전체 완료로 표시하지 않는다.



## A2 계측 추가 — 2026-10-15

사용자 보고: check-detail-episodes-mac.sh TEST SUCCEEDED, 이후 프로필 전용 오프라인
배너/홈·상세 로컬 탐색/HLS 취소·재시도 5개 수동 항목 정상. 사용자 보고 PASS로 기록하며
새 계측 코드나 전체 회귀가 통과했다는 근거로 사용하지 않는다.

구현: PlaybackDiagnostics 관측 상태 reducer, 초기 대기/seek 제외 rebuffer 횟수·시간,
first-frame-ready 관측 지연, 실패/무효 전이, access-log observed bitrate,
종료 시 익명 attempt 요약. 실제 AVPlayer 명령 전체의 상태 머신 재구성은 아직 아니다.
Core 결정적 테스트 5개 및 scripts/check-playback-qoe-mac.sh 추가.
PASS: 프로젝트 구조 검사, 스크립트 구문 검사.
NOT TESTED: Swift 컴파일/Core/UI 테스트, 실기기 HLS 계측, 최신 전체 회귀.
A2 전체 완료 아님: 미디어 서비스 리셋, 정밀 성능 보고 및 전체 상태 효과 검증은 남아 있다.



## 최신 결과 — 2026-10-15 18:35 KST

RESULTS(20261015-093546).txt 및 ui-tests(20261015-093546).log:
- PASS testDetailEpisodeSelectionAndProgress (43.434초): 2화 선택, seek, 진행 표시,
  다른 회차 기록 분리 및 재진입 복원 검사 통과.
- FAIL testLargeTextAccessibilityAudit (11.800초): 홈 home-category-나의 리스트,
  Text clipped. 총 2개 중 1개 실패, exit=65.
- ViewThatFits 후보 측정 대신 AnyLayout으로 동일 카테고리 버튼의 축을 전환하고
  접근성 크기에서 가용 너비/다중 행/내용 높이를 사용하도록 보정.
- 수정 후 구조 검사 PASS. Mac 컴파일/접근성 재실행 NOT TESTED.
- 전체 회귀, HLS 알림/네트워크 변화, 실기기 PiP는 이번 실행 범위 밖이다.



기준: Netflix_iOS_과제.docx 8쪽 원문. Phase 번호와 과제 A/B/C/D는 서로 다른 구분이다.
아래는 구현/검증 현황이며 루브릭 점수나 전체 완료율이 아니다. 세부 요구사항 전체를
충족하고 최신 코드에서 검증한 영역만 완료로 취급한다. 과거 PASS는 최신 회귀 PASS가 아니다.

| 범위 | 구현 현황 | 검증 근거 및 남은 작업 |
|---|---|---|
| A1 홈·탐색 | 대부분 구현 | 3프로필, 2,000개 fixture, 검색/페이지네이션/키즈 제한. 과거 Core/UI PASS. 네트워크 이미지 로더는 설계 단계; 다운로드 가시성 미구현 |
| A2 재생·트랙 | 주요 기능 구현 | HLS, 제어, 자막/음성, 위치 복원, 자동 다음 화 사용자/자동 테스트 PASS 이력. 동일 30초 영상 3회차 데모이며 실제 시즌 데이터 아님 |
| A2 상세 회차 UI | 구현 후 보정 중 | 최신 최대 글자 테스트 PASS. 회차 선택 테스트 FAIL: detail-episode-2 식별자 없음. 수정 후 재실행 NOT TESTED |
| A2 복구·상태·QoE | 부분 구현 | 네트워크 복구 사용자 확인. 새 취소/재시도 알림은 NOT TESTED. 전체 상태 전이 불변식, 미디어 리셋 및 QoE 지표 검증 미완료 |
| A3 멀티 기기 복원 | 미구현 | 현재 프로필별 로컬 진도. 서버 revision, 기기 간 경쟁, 처음부터 보기 action 계약 필요 |
| B1 Local-first | 부분 기반 | 번들 JSON 및 UserDefaults는 영속 mutation DB/큐가 아님. 최근 검색/찜/진도 DB, 계정 격리, 재실행 큐 복구 필요 |
| B2 충돌 해결 | 미구현 | 409, idempotency, revision, Retry-After/backoff/jitter 필요 |
| B3 동시성 | 부분 구현 | Strict Concurrency 빌드 PASS 이력, 취소/세대/프로필 격리. 401 8건 single-flight 및 전체 불변식 검증 필요 |
| C1 다운로드 | 미구현 | HLS 다운로드, 최대 2개, 1GB 예산, pinned/LRU, 디스크 부족/재실행 복구 필요 |
| C2 보안 | 부분 기반 | 키즈/프로필 접근 제한 있음. Keychain 인증, entitlement/DRM Mock, 로그 마스킹 및 로그아웃 정책 필요 |
| C3 접근성 | 구현 및 부분 검증 | VoiceOver/Dynamic Type 사용자 확인, 최신 최대 글자 UI PASS. 새 회차 및 고대비/Reduce Motion 전체 경로 확인 필요 |
| C4 성능 계측 | 미완료 | 누수 없음 사용자 관찰 이력. 실기기 HLS 20회 TTFF p50/p95, 프레임 p50/p95, retained 비교, 에너지/디스크 보고 필요 |
| D 카오스 10종 | 미완료 | 일부 race/취소/네트워크 테스트가 있어도 F01~F10 전체 seed/fake clock/로그/CI 통과 근거는 없음 |
| 제출 산출물 | 부분 완료 | 프로젝트, README, ADR, 테스트 있음. 충돌/다운로드 ADR 및 상태도, 성능 보고서, 장애 2개 포함 5분 영상 필요 |

## 최신 재실행 — 2026-10-15 18:30 KST

RESULTS(20261015-093039).txt: FAIL, 2개 중 2개 실패.
회차 식별자 조회는 해결됐지만 2화 재생 소스 검사 실패.
최대 글자 감사는 홈 추천 버튼 dynamicType 검사 실패.
이전 표의 최신 최대 글자 PASS는 아래 과거 실행에 해당하며 이번 결과를 우선한다.
Source 기반 cover 및 카테고리 적응형 레이아웃 수정 후 Mac 재검증 NOT TESTED.

## 이전 실행 증거

- RESULTS(20261015-080516).txt: FAIL detail-episodes exit=65.
- ui-tests(20261015-080516).log: 2개 실행, 1개 실패.
- PASS testLargeTextAccessibilityAudit (68.735초).
- FAIL testDetailEpisodeSelectionAndProgress (28.483초), 재생 이전 회차 버튼 조회 실패.
- 식별자를 Button에 직접 부여하도록 수정; 수정 후 Mac 빌드/UI는 NOT TESTED.
- 실제 기기 PiP, 최신 전체 회귀, 새 HLS 알림/프로필 배너는 NOT TESTED.

## 다음 순서

1. 회차 선택·진도 테스트 재실행 및 새 오프라인 정책 수동 확인.
2. A2 상태 머신/복구 경계와 QoE 계측을 보완하고 실기기 확인.
3. A3 서버 Mock/revision 기반 멀티 기기 복원을 완료.
4. B 영속 DB/큐/충돌 → C 다운로드/보안 → D 통합 카오스 및 제출 계측.

원문은 다운로드 압축률이나 Firebase 관리자 웹을 필수로 지정하지 않는다.
이 두 항목과 4K 저장 전략은 사용자 추가 범위이며 원본 A~D 완료와 별도 관리한다.
전체 백분율은 검증되지 않은 기능을 완료로 계산하지 않기 위해 현재 확정하지 않는다.
