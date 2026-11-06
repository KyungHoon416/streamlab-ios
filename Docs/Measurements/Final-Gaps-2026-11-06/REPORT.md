# 잔여 8항목 보완 결과

2026-11-06 시작 · 2026-11-07 갱신 · 앱 코드 `9a4d39539bf7afaad759bacf8966d650b0477970`.

**8개 중 5개를 완료했고, 실기기 결과가 필요한 3개는 도구·화면·계측 준비를 마쳤다.** 같은 79개 확인 단위 기준 76개 완료(96.2%), 3개 대기(3.8%)다. 배점이나 공수 비율이 아니다. [전체 점검표](../../ASSIGNMENT_AUDIT_2026-11-06.md).

| 항목 | 구현·검증 결과 | 판정 |
|---|---|---|
| B1 로컬 DB | 프로필별 SQLite projection/outbox/metadata 원자 커밋. JSON 값·ID·FIFO 이전, 중간 실패 롤백, 손상/schema 거부, 로그아웃 뒤 쓰기 차단 | 완료 |
| C3 VoiceOver | 이름 없는 플레이어 컨테이너 설명 보완. 설명·터치 영역과 재생·자막 경로 자동 감사 | 실제 음성·초점 전체 경로 대기 |
| C4 다운로드 전력 | 전송·백그라운드·완료·삭제 표식, FirebaseRelease Scheme | Power Profiler 기록 대기 |
| C4 전후 비교 | 동일 빌드 C/PV, 10초 준비·30초 자동 5왕복, 거리·열·저전력 상태 표식 | 실제 표시 프레임 비교 대기 |
| D 자동 CI | Core·iOS 재생·앱 UI·네이티브 HLS를 같은 커밋에서 원격 실행 | 완료 |
| E2 README 재현 | 초기 실행·Mock·Firebase·테스트 명령을 분리. 새 hosted runner·새 시뮬레이터 smoke 424초 | 명시한 환경에서 완료 |
| E4 상태도 | Player/Download Mermaid와 PDF 대표 상태도. 오류·취소·복구·수명 경계 대조 | 완료 |
| DATA1 샘플 사용조건 | 자체 fixture, 외부 Apple URL·공식 출처·용도·대체 번들 정리 | 완료 |

## 원격 CI

현재 앱 구현은 `9a4d395`, 테스트·workflow와 원격 문서를 합친 최종 검증 커밋은 `9a4d39539bf7afaad759bacf8966d650b0477970`다.

[실행 42239749042](https://github.com/KyungHoon416/streamlab-ios/actions/runs/42239749042)의 `core-chaos`, `ios-playback`, `ios-app-acceptance`, `ios-native-downloads` 네 job이 성공했다. Core·재생·앱 UI는 attempt 1, native 다운로드는 attempt 2다. Xcode 26.6 / Swift 6.3.3 / macos-26 hosted runner다.

| 검증 | 결과 |
|---|---|
| Core·실제 loopback HTTP·더미 Keychain | XCTest 31 + Swift Testing 247 통과 |
| 결정적 chaos | 세 suite 각각 1,000 seed 통과 |
| 별도 프로세스 복구 | SIGKILL 2회·재시작 3회·100건, 효과 중복/손실 0 |
| TTFF 집계 parser | 6개 통과 |
| iOS 재생·권한·F10 콜백 경계 | 25개 통과 |
| Release 앱 | 서명 정보 없이 빌드 성공 |
| 새 simulator 앱 인수 | smoke 2 + 저장/프로필/접근성 5 + C/PV 자동 스크롤 2 통과 |
| 실제 HLS UI | F06 복합 실패/공간/고정 복구, F09 저장 영상 만료, 정상 다운로드·재실행·재생·삭제 3개 통과 |

10분 gate는 **Xcode와 simulator runtime이 준비된 환경에서 새 checkout의 빌드·Mock 로그인·재생 smoke 2개**에 적용한다. 원격 424초, 이전 로컬 전체 smoke는 154초였다. 전체 UI 회귀와 다운로드 suite는 더 오래 걸리며, Xcode 설치·실기기 서명 계정 준비·운영 Firebase 인증 시간을 포함한 모든 환경의 10분 보장이 아니다.

요약과 원본 로그 해시: [evidence.json](evidence.json), [CI 주요 로그](ci-excerpts.txt), [로컬 근거](local-evidence.json). CI artifact의 전체 로그는 14일 보존되므로 핵심 결과와 해시를 저장소에 남겼다. 테스트 누락·skip·외부 HLS 실패를 PASS로 간주하지 않는다.

## 첫 원격 실패와 검사 보완

최초 실행 `42199580219`에서 앱 UI 9개·Core·iOS 재생은 성공했고 네이티브 F06·정상 다운로드도 통과했다. F09는 권한 검사에 들어가기 전, 한 번 스크롤한 뒤 재생 버튼이 생기기를 180초 기다리는 단계에서 실패했다. 그 로그에는 완료 시점 snapshot이 없어 외부 전송 지연과 LazyVStack의 화면 밖 요소를 구분할 수 없었다.

F09를 실제 완료 기록 1개·저장 파일 1개 확인 → 목록 버튼 노출 → 만료/갱신 실패/닫기 검증으로 바꿨다. 완료 대기 180초는 늘리지 않았고 자동 재시도로 실패를 숨기지 않았다. 실패 시 native snapshot과 화면 계층도 남긴다. 앱 동작은 바꾸지 않았다. CI는 앱 UI와 native 다운로드를 독립 job으로 나눠 같은 커밋에서 실행했다. 최초 원격 실패를 제품 결함이나 특정 네트워크 원인으로 확정하지 않는다. 로컬 후속 `download-combined-oQvxoW`에서는 시작 26초 후 실제 네트워크 끊김 배너가 나타났고, 다음 검사도 오프라인 다운로드 화면으로 진입했다. 그 실패와 원본 앱 로그 해시를 `first-ci-failure.json`에 보존했다. 연결 복구와 HLS 주소의 HTTP 200을 확인한 뒤 새 시뮬레이터로 재검증했다.

두 번째 실행 `42225453235`에서는 Core·재생과 네이티브 F06·F09가 통과했지만 앱 smoke의 탐색 후 시간 관측과 별도 정상 다운로드가 실패했다. 전자는 실패 시 실제 시간 값, 후자는 다운로드 실패 문구가 텍스트 artifact에 없어 제품 원인을 확정할 수 없었다. smoke는 HUD 자동 숨김과 분리하고 실제 탐색 완료를 먼저 검사하도록 보완했다. 실패 상태 문구와 xcresult도 CI에 보존하도록 추가했다. 앱 코드는 바꾸지 않았고 대기 연장·자동 재시도로 성공 처리하지 않았다. 두 번째 실패와 원본 로그 해시는 `second-ci-failure.json`에 남겼다. 이후 성공을 이 두 실패의 원인 규명으로 해석하지 않는다.

세 번째 실행 `42228526327`의 attempt 1에서는 smoke의 첫 로그인 화면 진입과 F09의 가로 회전 확인이 실패했다. 정상 다운로드·재생·삭제와 F06은 통과했다. F09의 저장 완료와 만료 안내는 확인됐고, 앱 진단에는 UIKit 회전 요청 거부(code 101), 화면에는 세로 오류 카드가 남았다. 그래서 권한 갱신·닫기 단계는 실행되지 않았다. 첫 로그인에서는 탭 이벤트가 전달됐지만 프로필 화면이 나타나지 않았으며 인증 오류는 보이지 않았다. 각각의 원인은 아직 확정하지 않는다. `third-ci-failure.json`과 `third-ci-diagnostics.txt`에 실패 근거를 보존했다.

실패한 두 job만 같은 커밋으로 한 번 명시적으로 재실행한 attempt 2에서 앱 UI 9개는 통과했고 새 시뮬레이터 smoke는 435초였다. 네이티브 F06은 통과했지만 F09는 같은 회전 확인에서 다시 실패했다. 정상 HLS 전송도 CoreMediaErrorDomain -12884로 실패했다. 이 오류에는 기저 원인이나 HTTP 상태가 제공되지 않아 네트워크·파일·앱 중 하나로 확정하지 않았다. attempt 2 역시 실패로 보존했다.

코드 대조에서 representable 갱신이 window를 확보한 직후, full-screen 표시 완료 전에 회전을 요청할 수 있음을 확인했다. 세션은 같은 요청을 중복 제거하므로 일찍 거부된 요청이 `viewDidAppear`에서 다시 실행되지 않는 경로가 있었다. `526c2aa`는 첫 요청을 `viewDidAppear` 이후로 제한하고 닫기 시작 후 갱신 요청을 막았다. 테스트 실패 시에도 플레이어를 먼저 닫고 실제 로그아웃으로 정리해 후속 검사와 파일 lease를 분리했다. 검사 삭제·자동 재시도·시간 제한 확대는 하지 않았다. 이 변경이 모든 UIKit 거부나 CoreMedia -12884의 원인을 설명한다는 뜻은 아니다.

네 번째 실행 `42234656187`에서 Core·iOS 재생과 네이티브 F06/F09/정상 다운로드 3개는 모두 통과했다. 앱 smoke는 원격 UI 조회가 지연되는 사이 30초 데모가 끝난 뒤, 테스트가 재생 버튼을 일시 정지로 예상하고 눌러 실패했다. 앱 로그의 `playing → ended`, `transport_action=play position=30`, `ended → seeking`으로 확인했다. 이는 앱의 pause 실패가 아닌 테스트 선행 조건 오류다. `fourth-ci-failure.json`과 `fourth-ci-diagnostics.txt`에 보존했다.

후속 `9a4d395`는 프로젝트 자체 데모를 재인코딩 없이 반복한 600초·약 1.4MB 파일을 추가했다. Debug에서 명시한 UI 검사 4개만 긴 영상을 선택하며, 기본 영상과 회차·종료 검사는 30초를 유지한다. smoke는 관측한 일시 정지 위치에서 10초 이동했는지 확인한다. 자막 검사는 실제 편집 이벤트가 생기도록 중간 이동을 관측한 뒤 시작으로 드래그하고, 10초 앞뒤 이동으로 두 자막 구간을 검증한다. 실제 재생·탐색·종료 처리나 제한 시간은 바꾸지 않았다.

최종 검증 커밋 `9a4d395`의 실행 `42239749042`에서 Core·재생·앱 UI 9개는 attempt 1에 통과했고 새 시뮬레이터 smoke는 424초였다. 같은 attempt의 네이티브 F06은 다운로드를 시작하기 전 `app.launch()`에서 Xcode 실행 시간 초과로 실패했다. 후속 F09는 120.673초, 정상 다운로드·재생·삭제는 133.278초에 통과했다. 앱 실행 지연의 정확한 원인은 확정하지 않았다. `fifth-ci-failure.json`에 보존했다.

다운로드 job만 동일 커밋으로 한 번 명시적으로 재실행했다. Core·재생·앱 UI는 attempt 1의 근거를 유지하고, 최종 native 결과는 attempt 2의 artifact를 사용한다. `evidence.json`의 job별 실행 차수와 artifact 이름으로 구분한다. 한 번에 모든 검사가 성공했다거나 과거의 간헐 실패 원인이 모두 해결됐다는 뜻은 아니다.

## 로컬 검증과 발견한 문제

- `http-boundaries-CuyohB`: XCTest 31 + Swift Testing 247, 세 chaos 각 1,000 seed.
- `mutation-process-UEQ6dM`: 두 번 SIGKILL, 세 번 재시작, 100건 중복/손실 0.
- `submission-app-cTbBNX`: 앱 9개 통과. 빌드·로그인·재생 smoke 154초.
- `download-combined-OmIQzN`: 초기 실제 HLS UI 3개 통과.
- `download-combined-IRqmqG`: F09 완료 관측 보완 후 3개 재검증 통과. F06 149.698초, F09 112.326초, 정상 다운로드 103.684초.
- `observation-OSlONs`: 시간 관측·실패 진단 보완 후 실제 HLS 회귀 120.823초, 일시 정지 탐색 smoke 41.857초 통과. 이후 `7a5221f`로 확정.
- `rotation-m6EEkz`: 화면 표시 후 회전 변경을 적용한 F09 가로 전환·재시도·닫기 81.595초, 정상 HLS 다운로드·재생·삭제 100.459초 및 탐색 smoke 통과. 최종 커밋 `526c2aa`의 원격 CI는 추가한 teardown 정리까지 포함해 검사했다.

Core와 앱 9개는 `de1542f` 위 작업 변경을 검사한 뒤 `6642b7c`로 확정했다. 환경 파일의 실제 HEAD/dirty 목록을 보존했다. 기존 네이티브 회귀는 `6642b7c`에서, 최종 원격 CI는 위에 기록한 테스트·workflow 커밋에서 실행했다.

초기 iOS 빌드에서 macOS Homebrew SQLite가 연결되는 문제를 발견해 pkg-config를 제거하고 대상 SDK의 SQLite만 링크하도록 고쳤다. 접근성 감사에서는 이름 없는 플레이어 컨테이너를 발견해 작품명·영상 플레이어 설명을 추가했다. 검사를 제외하지 않고 같은 감사가 통과하는 것을 확인했다.

- 긴 검사 영상 보완: `extended-smoke-D6L2aG`에서 재생·접근성 2개, `extended-boundaries-aO9vAc`에서 F04 64.899초, `extended-subtitles-cW40k4`에서 자막·탐색·복원 102.277초 통과. 중간의 자막 검사 실패 2회와 편집 이벤트가 없었던 진단도 `local-evidence.json`에 보존했다.

## 아키텍처 PDF

[8쪽 요약본](../../Architecture/streamlab-architecture-summary-2026-11-07.pdf)을 먼저 구성했다. 이후 2026-11-07 [현재 PDF](../../Architecture/streamlab-architecture-ko.pdf)를 사용자 통합본의 14쪽 순서와 카드형 디자인으로 개정했다. 시스템 경계·모듈·SQLite 트랜잭션과 이전·재생 경로·재생 상태·다운로드 상태와 예산·관리자 업로드·검증 범위를 담았다. 모든 페이지를 이미지로 렌더링해 글자 잘림과 연결선을 확인했다. PDF 생성기는 Markdown을 덮어쓰지 않는다.

기존 제출 태그·영상·ZIP은 그대로다. 원격에서 추가된 [전체 Mermaid 다이어그램](../../Architecture/ARCHITECTURE_DIAGRAMS_2026-11-06.md)도 보존해 연결했다. 현재 PDF를 기존 촬영 빌드의 구조라고 섞어 설명하지 않는다. 사용자가 올릴 장시간 영상은 이번 작업에서 업로드하지 않았다.

## 남은 실기기 3항목

[순서와 파일명](../../FINAL_DEVICE_QA.md): VoiceOver 전체 경로 1회, 백그라운드 다운로드 전력 1파일, 자동 C/PV 비교 4파일. 측정 전에는 성능 개선·배터리 절감·VoiceOver 전체 완료를 주장하지 않는다.

SQLite 쓰기는 MainActor에서 동기 실행하며 projection/outbox를 트랜잭션으로 교체한다. 이 변경을 성능 최적화라고 설명하지 않는다. C/PV 비교는 같은 DB·탭 구성을 유지하고 홈 렌더링만 바꾼다. 기존 I/O·HLS 전력·메모리 기록은 해당 조건의 근거로 유지한다.
