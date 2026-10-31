## Mock 재생 권한 — 2026-10-31

재생 시작 전에 계정·프로필·작품·영상 소스별 권한, 만료, 키 상태를 확인합니다. 오류 안내와 수동 재시도를 연결했으며 실제 FairPlay/운영 라이선스 서버는 아닙니다.
[설계](Docs/ADR/0029-mock-playback-entitlement.md) · [검증](Docs/Measurements/Playback-Entitlement-2026-10-31/REPORT.md) · [실기기 확인](Docs/PLAYBACK_ENTITLEMENT_QA.md)

## 오프라인 HLS 다운로드 — 2026-10-20

상세 화면에서 Apple HLS 샘플을 Wi-Fi로 다운로드하고, 앱 재실행 후 저장한 파일을
재생하거나 고정/삭제할 수 있습니다. 실제 작품 영상은 아닙니다. 계정·프로필별 기록과
로그아웃 정리를 적용하며, 동시 2개·총 1GB 예산으로 비고정 오래된 파일을 정리합니다.
시스템 비동기 쓰기로 순간적인 디스크 사용량의 절대 상한까지 보장하지는 않습니다.

실제 다운로드·재실행·로컬 재생·삭제 테스트 PASS. Core 실제 실행 206개 PASS/10개 SKIP.
검증 상세: [PHASE2_REPORT](Docs/PHASE2_REPORT.md), 실기기 절차:
[DOWNLOADS_QA](Docs/DOWNLOADS_QA.md), 설계: [ADR 0028](Docs/ADR/0028-offline-hls-downloads.md).

```bash
caffeinate -i bash scripts/check-downloads-mac.sh
```

실기기 비행기 모드/백그라운드/공간 부족, DRM·운영 서버, 전체 UI 회귀는 별도 검증 대상입니다.
아래 날짜별 내용은 이전 이력입니다.


## 전체 회귀 3개 실패에 대한 스크롤 검증 수정 — 2026-10-16

사용자 RESULTS(20261016-034909): Fixture/구조/bootstrap/Core/빌드/경고 PASS,
UI FAIL(exit65). UI 로그: 33개 중 4개 외부 HLS opt-in skip, 실패 3개, 나머지 26개 PASS.
별도 실행에서 통과한 HLS 테스트를 이번 전체 실행의 PASS로 세지 않는다.

실패 지점: 자막 복원에서 offscreen 3화 소스, 나의 리스트에서 카테고리 전환 후 히어로,
최대 글자 크기에서 playback-toggle 접근. 소스 선택에 목록 내 양방향 스크롤 helper를 재사용하고,
추천 복귀 후 홈 스크롤 안에서 히어로를 찾는다. 플레이어 helper는 ScrollView 컨테이너 자체의
isHittable을 스크롤 선행조건으로 쓰지 않고 관측된 viewport 안에서만 드래그한다.
버튼 탭은 여전히 해당 버튼의 exists/isHittable 확인 후 수행한다. 실패 시 화면/트리를 첨부한다.
assertion 제거나 대기시간 연장은 하지 않았다. 실제 앱 UI 문제가 모두 없다고 단정하지 않는다.

구조/shell PASS. 수정 후 Swift/Xcode/UI NOT TESTED.
먼저 scripts/check-regression-fixes-mac.sh의 3개를 재검증한 뒤 전체 verify-mac.sh를 실행한다.


## 실기기 첫 프레임 측정 및 보고서 도구 — 2026-10-16

attempt_started/summary에 동일 attempt UUID와 source ID를 기록해 로컬/HLS 시도를 분리한다.
측정 정의는 기존 load 시작 → first-frame-ready 관측이며 실제 디스플레이 시각은 아니다.
Docs/TTFF_QA.md에 실기기 20회 절차, Docs/TTFF_REPORT_TEMPLATE.md에 미측정 보고서 양식을 추가했다.
scripts/summarize-ttff.py는 source별 원본 로그를 samples.csv/REPORT.md로 변환하고 nearest-rank
p50/p95, 실패/미관측/누락을 기록한다. 동일 attempt 중복 제거, 충돌/잘못된 숫자 거부.
성능 목표가 제공되지 않았으므로 성능 PASS를 자동 판정하지 않는다.
Python 집계 테스트 3개/구조 PASS. 변경된 Swift 빌드와 실기기 시간 측정 NOT TESTED.

사용자 실기기 PiP 보고: 홈 직접 이동 자동 진입, PiP 영상·음성 지속, X로 음성 중지 PASS.
아이폰 모델/iOS 미제공. 전체 화면 복귀/자동 시작 OFF/시스템 리셋은 이 보고로 검증되지 않았다.


## 실기기 자동 PiP 전환 수정 — 2026-10-16

사용자 실기기 확인: PiP 버튼 진입 시 끊김 없음. 시스템 자동 시작 설정이 켜져 있어도
홈으로 직접 이동하면 일시정지. 기존 코드가 canStartPictureInPictureAutomaticallyFromInline을
false로 설정하고 scene inactive 즉시 pause하던 동작을 확인했다.

재생 중인 HLS에 자동 시작을 허용한다. scene 전환 시 PiP가 가능하면 최대 2초간
AVKit의 자동 시작을 기다리고, 시작되지 않으면 pause한다. 앱이 직접 자동 start를 강제하지 않는다.
시스템 설정/지원 여부는 AVKit이 결정한다. 일반 로컬 재생/일시정지/시킹은 즉시 pause 경로를 유지한다.
전환 대기는 stop/프로필 세션 종료/소스 변경/앱 복귀에서 취소하고 generation 검사로 늦은 작업을 막는다.
PiP willStart부터 기존 10초 시작 watchdog을 적용한다. PiP 닫기/실패 시 음성도 중지한다.

구조 검사 PASS. 수정 후 Xcode/UI 및 실기기 자동 PiP는 NOT TESTED.
기존 수동 버튼 진입 성공은 사용자 보고 범위의 PASS이며 자동 진입 성공으로 확대하지 않는다.
시뮬레이터 회귀: scripts/check-pip-mac.sh. 실기기 재검증: Docs/PIP_QA.md 최신 항목.


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


## HLS 종료 알림 연결 및 회차 헤더 가시성 — 2026-10-16

사용자 RESULTS(20261016-010628): Core PASS, 회차별 진도 복원 PASS,
자동 회차 전환 FAIL(exit65), QoE 수집 PASS. 종료 직전 시킹/일시정지 검사는 통과했으나
2화 label 대기가 실패했다. 로그만으로 실제 종료 미감지와 화면 밖 label을 구분할 수 없다.

AVPlayerItem.didPlayToEndTimeNotification을 해당 item에 한정하여 관찰한다.
MainActor에서 재생 generation/seek generation/프로필 활성 상태를 확인하고 종료를 기록한다.
HLS 종료 시각과 duration 차이에 의존하지 않고 종료 상태 및 기존 카운트다운을 처리한다.
seek/stop에서 종료 상태와 observer를 해제하고 seek 완료/취소 watchdog 후 다시 등록한다.
기존 시간 비교 fallback은 유지한다. item_end 진단 로그를 추가했다.

UI 테스트는 footer에서 시킹한 후 컨트롤을 위로 스크롤해 회차 헤더의 가시성을 확인한다.
실패 시 status/time/source와 screenshot/접근성 트리를 남긴다. timeout 연장이나 assertion 제거는 없다.
수정 후 구조 검사 PASS. Swift 컴파일/Xcode/HLS UI 재실행 NOT TESTED.
재검증: `caffeinate -i bash scripts/check-hls-episodes-mac.sh`.

## HLS 자동 다음 회차 테스트 관측 보강 — 2026-10-16

사용자 RESULTS(20261016-004915): Core PASS, HLS 회차별 진도 복원 PASS,
자동 다음 회차 FAIL(재생 완료 label 대기 timeout), QoE 수집 PASS.
로그만으로 실제 종료 실패와 일시적인 UI 상태 미관측을 구분할 수 없다.

테스트를 일시정지 → 종료 10초 전 시킹 → 실제 잔여 1~25초 확인 → 재생으로 변경했다.
첫 회차는 잠깐 표시되는 종료 label 대신 실제 2화 자동 선택과 재생을 검증한다.
마지막 회차는 종료 상태와 다음 회차 버튼/카운트다운 부재를 그대로 검증한다.
DEBUG 전용 인자로 해당 테스트에서만 HUD 자동 숨김을 막는다. 재생 상태, 종료,
카운트다운, 외부 HLS URL은 조작하지 않는다. 실패 단계별 화면/접근성 트리도 첨부한다.

수정 후 프로젝트 구조 검사 PASS. Swift 컴파일/Xcode/HLS UI 재실행은 NOT TESTED.
`caffeinate -i bash scripts/check-hls-episodes-mac.sh`로 재검증한다.

> 상세 화면 업데이트: 대표 이미지의 데모 미리보기, 데모 시즌 1의 회차 1~3 목록,

## HLS 테스트 소스 목록 스크롤 수정 — 2026-10-16

사용자 RESULTS(20261016-003040): Core PASS, HLS UI 2개 FAIL(exit65).
두 테스트 모두 source-hls-series-episode-1-v1을 찾지 못해 실제 HLS 검증 전 중단됐다.
소스 ID는 일치한다. 기존 helper는 offscreen List 행의 존재만 기다려 스크롤하지 않았다.
영상 소스 List에 식별자를 추가하고 sheet 등장 확인 후 해당 목록 안에서 최대 8회
스크롤해 행의 존재/탭 가능 여부를 확인한다. 재생 검증 assertion과 timeout은 유지한다.
수정 후 구조 PASS. Xcode/UI 및 실제 HLS 재생은 NOT TESTED. check-hls-episodes-mac.sh로 재검증.


## 이미지 캐시 actor 호출 수정 — 2026-10-16

사용자 core(9).log에서 ArtworkDataCache.swift:46의 actor-isolated finish 호출에
await 누락이 확인되어 Core 컴파일 FAIL(exit=1). UI 테스트는 실행되지 않았다.
Task 완료 지점에서 await로 캐시 actor에 진입하도록 수정했다.
generation 검사/구독자 취소/캐시 제한은 기존대로 유지한다.
수정 후 구조 검사 PASS. Swift 컴파일/Core/UI 재실행은 NOT TESTED.
재검증: scripts/check-artwork-mac.sh.


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


## 오디오 세션 비동기 큐 처리 — 2026-10-15

사용자 제공 db001a0 검증 로그: Core 48개(15 XCTest + 26 + 7 Swift Testing),
UI 4개 PASS. QoE rejected transition 0. 단, UI 로그에서 AVAudioSession
메인 스레드 응답성 경고 4회 발견. 이 결과는 경고 없음 PASS가 아니다.

수정: process-wide PlaybackAudioSession 직렬 큐에서 category/activation/deactivation을
처리한다. 플레이어는 활성화 성공 후 MainActor에서 생성하며 generation/session/UUID를
검사한다. stop은 즉시 UI/플레이어를 정리하고 비동기 release를 제출한다.
이전 재생의 release는 소유 UUID가 다르면 새 재생을 비활성화하지 않는다.
iOS 18 호환 API를 유지하며 메인 큐를 동기 대기시키지 않는다.

check-media-recovery-mac.sh에 실제 UI 로그의 오디오 메인 스레드 경고 검사를 추가했다.
수정 후: 구조·shell 구문 PASS. Xcode 빌드, Core/UI, 런타임 경고 제거 NOT TESTED.
실제 OS 리셋/실기기 PiP/전체 회귀 및 HLS 회차 테스트도 아직 미검증이다.

> 회차별 이어보기 진행률을 연결했습니다. 세 회차는 같은 30초 무음 테스트 영상입니다.
> 미리보기는 전체 화면 재생이며 실제 예고편/다중 시즌은 아직 없습니다.
> 구조·스크립트 구문 PASS, Xcode/실제 UI NOT TESTED.
> `caffeinate -i bash scripts/check-detail-episodes-mac.sh`로 새 회귀와 최대 글자 검사를 실행하세요.

> 현재 오프라인 정책: 프로필 선택에만 연결 끊김 배너를 표시합니다.
> 홈·검색·상세는 배너 없이 번들 로컬 카탈로그를 사용합니다. SQLite/Core Data DB는 아직 미구현입니다.
> 플레이어 외부 HLS 실패는 취소/재시도 알림이며 취소 시 해당 작품 상세로 이동합니다.
> 구조 PASS, 이번 변경의 Xcode/실제 동작 NOT TESTED. 아래 내용은 이전 이력입니다.

> 현재 정책: 네트워크 배너를 제거했습니다. 외부 HLS 로딩 실패 시 취소/재시도 알림을 표시합니다.
> 취소는 해당 작품 상세로 이동하고 재시도는 동일 영상을 다시 요청합니다.
> 실제 오류 또는 로딩 제한까지 시간이 걸릴 수 있습니다. 구조 PASS, Xcode/실행 NOT TESTED.
> [현재 검증 절차](Docs/NETWORK_STATUS_QA.md). 아래 배너 관련 기록은 이전 이력입니다.

> 연결 감지 수명 보정: 전체 화면 플레이어가 열려도 관찰을 유지하도록 root 객체가
> NWPathMonitor를 직접 소유합니다. 구조 PASS, Xcode/실제 복구 검증 NOT TESTED.

> 현재 네트워크 정책: 프로필·홈·검색·상세·플레이어가 연결 상태를 공유합니다.
> 연결 경로가 없으면 빨간 배너를 유지하고 복구되면 숨깁니다. 재생 여부와 무관합니다.
> OS의 경로 변경 이벤트를 지속 관찰하며 앱 복귀 시 재확인합니다. 실제 인터넷/HLS 서버 도달 보장은 아닙니다.
> 구조 검사 PASS, 이번 변경의 Xcode/자동·수동 실행은 NOT TESTED입니다.
> [전체 화면 연결 QA](Docs/NETWORK_STATUS_QA.md). 아래 기록의 플레이어 전용 정책은 이전 이력입니다.

> 네트워크 배너 보정: 정상 재생 중에는 숨기고, 경로 불가 안내는 중립색,
> 실제 영상 실패만 빨간색으로 표시합니다. 수정 후 Xcode/수동 검증은 NOT TESTED입니다.

> HLS 네트워크 안내 추가 (2026-10-15): 연결 끊김/복구 및 영상 요청 실패를 상단에 표시합니다.
> 연결 복구로 자동 재생하지 않습니다. 구조 검사 PASS, 새 코드의 Xcode 빌드·UI/수동 검증은 NOT TESTED입니다.
> [네트워크 배너 검증](Docs/NETWORK_STATUS_QA.md)을 참고하세요. 아래 항목은 이전 변경 이력입니다.

> PiP 구현 추가 (2026-10-15): HLS 플레이어의 작은 화면 버튼, 복귀/종료, 백그라운드 오디오를 연결했습니다.
> **새 코드의 Xcode 빌드·UI 테스트·실제 PiP는 NOT TESTED**입니다. 아래 전체 PASS는 PiP 추가 전 결과입니다.
> 먼저 `caffeinate -i bash scripts/check-pip-mac.sh` 실행 후 [PiP 수동 검증](Docs/PIP_QA.md)을 진행합니다.
> 오프라인 데모의 SwiftUI SRT 자막은 PiP에서 제공하지 않으므로 해당 소스에서는 PiP 버튼을 비활성화합니다.

> 최신 검증 (2026-10-15): 사용자 제공 전체 RESULTS에서 Fixture·구조·생성·Core·
> Simulator 빌드·UI 테스트·빌드 경고 검사 모두 PASS. 아래 날짜별 기록은 당시 상태입니다.
> 실제 HLS 네트워크 복구는 [검증 절차](Docs/HLS_RECOVERY_QA.md)에 따라 별도 확인합니다.
> 이번 자동 실행에서 수동 접근성·기기별 화면·런타임 경고·Instruments는 NOT TESTED입니다.

# StreamLab — SwiftUI Phase 2 재생

비공식 학습·포트폴리오 프로젝트입니다. Netflix 공식 채용 과제나 제품이 아닙니다.

**Swift 6 / iOS 18+ / SwiftUI** 오프라인 카탈로그 앱입니다. 원문 Netflix_iOS_과제.docx의 SwiftUI 조건에 맞춰 2026-10-12 UIKit 버전을 전환했습니다. Phase 2 첫 구현으로 AVPlayer 데모 재생을 추가했습니다. 상세 → 데모 영상 재생에서 번들 영상 또는 HLS 스트리밍을 선택합니다. 동기화·다운로드·DRM·이어보기 저장은 아직 구현하지 않았습니다.

## Phase 2 재생 — 이번 변경

- SwiftUI `VideoPlayer` + `AVPlayer`: 재생/일시정지, 10초 탐색, 위치 슬라이더, 재생 완료/다시 재생.
- 기본 영상: 직접 생성한 30초 무음 MP4. 실제 작품 영상이 아니며 모든 카탈로그 항목에 같은 데모를 사용합니다.
- 소스 메뉴에서 Apple HLS 예제로 전환 가능. 인터넷이 필요하며 외부 서비스 가용성은 보장하지 않습니다.
- 로딩/실패/30초 로딩 시간 초과/재시도, 재생 직전 Repository 권한 재검사.
- 닫기/프로필 전환 시 요청 취소와 player 정리. 백그라운드 전환 시 일시정지, 복귀 후 수동 재생.
- 추가 UI 회귀 3개와 기존 재생 안내 테스트 교체. **iOS 빌드·15개 UI 테스트·Swift 6 경고 검사는 이번 코드에서 NOT TESTED**입니다.
- 범위와 검사 결과: [Phase 2 보고서](Docs/PHASE2_REPORT.md), [재생 ADR](Docs/ADR/0007-playback-lifecycle.md).

## 홈·상세 디자인 개선

홈에 추천/영화/시리즈 필터, 이미지 위 히어로 타이틀과 직접 데모 재생, 가로 계속 시청 카드/남은 시간, 세로 포스터 레일을 적용했습니다. 필터는 현재 프로필의 추천 스냅샷 안에서 동작하며 전체 2,000개 탐색은 검색에서 제공합니다. 상세는 대표 이미지 → 제목/메타정보 → 재생 → 소개 순서입니다. 상단 프로필 버튼에는 현재 프로필을 표시합니다.

참고 이미지의 사진 포스터 대신 기존 생성형 색상 Mock 아트워크를 사용합니다. 시즌/에피소드와 다운로드는 별도 기능 작업으로 남아 있습니다. 가로 커스텀 플레이어는 아래 후속 구현 상태를 참고하세요. 이전 기본 재생 버전의 Mac 자동 검사 PASS와 이번 레이아웃 변경의 미검증 상태는 [Phase 2 보고서](Docs/PHASE2_REPORT.md)에서 구분합니다.

## 현재 상태

- 구현: 프로필 3개, 히어로, 추천 레일 5개, 계속 시청, 검색, 상세, 커서 페이지네이션, 중앙 로딩.
- Core의 2,000개 fixture, Repository 수준 키즈 등급 제한, 요청 세대·프로필·취소 검사를 재사용합니다.
- 최신 사용자 Mac 결과: Fixture·구조·bootstrap·Core·Simulator 빌드·빌드 경고 검사 **PASS**.
- 검색 접근성 수정 후 사용자 RESULTS(20261012-013429).txt에서 UI gate **PASS(exit=0)**. 개별 테스트 수는 해당 요약 파일에 없습니다.
- 최대 글자·VoiceOver·작은 iPhone·iPad 세로/가로는 사용자 확인 범위 PASS. Allocations의 홈/상세 반복 후 Store/Model 각 1개 잔존, 21개 해제 확인.
- 메모리 전체 완료는 보류: Instruments 시작 구간 32바이트 1개 원인 미확인. 별도 Debug Memory Graph 누수 목록은 사용자 확인상 비어 있습니다.
- 이전 Release 60회 런타임 검사 PASS 이후 수동 Debug에서 glassEffect 경고가 재발했습니다. 사용자는 화면 이상 없이 콘솔에만 표시된다고 확인했습니다.
- UIKit PASS는 새 UI의 PASS가 아닙니다. [현재 보고서](Docs/PHASE1_REPORT.md)와 [이력](Docs/Archive/UIKIT_PHASE1_REPORT.md)을 구분합니다.
- Phase 1의 미확인 32B 항목과 수동 glassEffect 경고는 남겨두고, 사용자 승인으로 Phase 2를 시작했습니다. 아래 Phase 1 PASS는 새 재생 코드의 통과 증거가 아닙니다.

## 실행 및 검증

Mac, Swift 6 / iOS 18 SDK를 지원하는 Xcode와 XcodeGen이 필요합니다. 사용자 환경은 Xcode 27.0 / Swift 6.4입니다. 변경을 작성한 호스트에는 Xcode·Swift가 없습니다.

    brew install xcodegen
    ./scripts/bootstrap-mac.sh
    open StreamLab.xcodeproj

StreamLab scheme과 iPhone Simulator를 선택해 실행합니다. SwiftUI @main App → WindowGroup으로 시작하며 Storyboard/SceneDelegate가 없습니다. XcodeGen이 없으면 위 첫 명령으로 설치합니다.

전체 자동 검증:

    ./scripts/verify-mac.sh

Fixture → 구조 검사 → XcodeGen → 생성 프로젝트 검사 → Core 17개 → Simulator 빌드 → UI 17개 → 빌드 경고 검사 순서입니다. **개수는 소스 정의 수이며 현재 통과 수가 아닙니다.** 출력되는 Docs/Validation/.../RESULTS.txt 및 environment.txt를 보관하세요. UI 실패는 같은 폴더의 ui-tests.log / UITests.xcresult에서 확인합니다.

Release 및 런타임 회귀:

    ./scripts/check-runtime-mac.sh

새 Release 제품으로 상세 ↔ 홈 60회, 20/40/60회 스크린샷, 앱 로그와 glassEffect 진단을 수집합니다. **UI 반복은 누수 측정이 아닙니다.** 로그 수집 실패나 선택 테스트 미실행은 PASS로 처리하지 않습니다.

Debug에서만 재현되는 경고를 확인하려면:

    CONFIGURATION=Debug ./scripts/check-runtime-mac.sh

할당 호출 경로는 **StreamLab-Memory** Scheme으로 별도 수집합니다. `MallocStackLogging=1`이 Run/Profile에 적용됩니다. [메모리 진단 절차](Docs/MEMORY_DIAGNOSTICS.md)를 따르세요. 사용자는 새 진단 Scheme에서 상세 왕복 후 누수 필터 목록이 비어 있다고 확인했습니다. 해당 범위만 PASS이며 전체 메모리 검증 완료를 뜻하지 않습니다.

특정 Simulator는 SIMULATOR_ID=<UDID> 환경변수로 선택합니다. Debug에서만 --ui-test-slow-catalog 인자를 넣으면 Mock 응답을 4초로 늦춰 HUD·취소를 확인할 수 있습니다. 검사 뒤 제거하세요.

업데이트가 로컬 생성 프로젝트 변경으로 막히면 git status와 diff를 먼저 확인합니다. 소스를 일괄 discard하지 않습니다. 생성된 파일만 백업하려면:

    git stash push -m "Backup generated Xcode project before SwiftUI migration" -- StreamLab.xcodeproj/project.pbxproj StreamLab.xcodeproj/xcshareddata/xcschemes/StreamLab.xcscheme
    git pull --ff-only --no-rebase origin main
    ./scripts/bootstrap-mac.sh

이전 UIKit 프로젝트 설정을 새 프로젝트에 그대로 stash pop하지 말고 필요한 개인 설정만 확인해서 옮기세요.

## 폴더 구조

- App/Application/StreamLabApp.swift: SwiftUI 진입점.
- App/Scene/AppRootView.swift: 프로필, 세션 교체, 탭, NavigationStack.
- Packages/StreamLabUI/Sources/StreamLabProfileFeature/Profile/: 프로필.
- Packages/StreamLabUI/Sources/StreamLabCatalogFeature/: Home, Search, Detail, State.
- Packages/StreamLabUI/Sources/StreamLabDesignSystem/Theme/: 테마, 포스터, 버튼, HUD.
- Packages/StreamLabCore/: Domain, actor MockRepository, MainActor CatalogStore, fixture, 테스트.
- Tests/StreamLabUITests/: 화면·프로필·페이지·접근성·백그라운드·반복 이동.
- Docs/ADR/: 설계 결정. [ADR-0006](Docs/ADR/0006-swiftui-migration.md)이 UIKit ADR-0004를 대체합니다.

## 상태와 수명주기

화면마다 @StateObject CatalogScreenModel을 소유합니다. 어댑터가 Foundation 기반 CatalogStore의 변경을 SwiftUI에 전달합니다. Core는 SwiftUI/Combine에 의존하지 않습니다.

선택마다 새 UUID의 CatalogSession을 만듭니다. 프로필 전환 시 이전 세션의 살아 있는 Store를 먼저 동기적으로 무효화하고, .id(session.id)로 탐색 경로·검색어·화면을 새로 만듭니다. 세션 레지스트리는 Store를 약하게 참조합니다.

onDisappear/비활성 scenePhase에서 요청을 중단합니다. 현재 화면만 active 복귀 시 재개하며 받은 검색 페이지·커서는 유지합니다. 상세 조회도 Repository 권한 검사를 거칩니다.

## 남은 범위

- 포스터는 SF Symbols와 로컬 그라데이션. 네트워크 이미지 로더는 [ADR-0005](Docs/ADR/0005-image-loader-design.md)의 제안이며 미구현입니다.
- 계속 시청은 샘플 진도이며 영속 저장/멀티디바이스 동기화는 미구현입니다.
- AVPlayer 기본 재생은 구현했습니다. Download 상태 머신, DRM Mock, 인증, 오프라인 큐, 카오스 전체는 이후 범위입니다.
- 전체 과제의 필수 ADR: 충돌 처리 / 플레이어 수명주기 / 다운로드 캐시 정책은 후속 단계에서 작성합니다. 현재 문서 개수만으로 전체 산출물 완료라고 보지 않습니다.
- VoiceOver·최대 글자·기기 레이아웃의 사용자 확인 범위와 남은 메모리/런타임 항목을 구분합니다. [수동 QA](Docs/PHASE1_MANUAL_QA.md).

## 히어로 조작 / 나의 리스트

히어로 이미지·제목을 누르면 상세 화면으로 이동합니다. 하단 버튼은 데모 재생과 나의 리스트 추가/제거입니다. 홈의 나의 리스트 필터에서 저장된 작품을 열고, 상세에서도 추가/제거할 수 있습니다. 프로필별 UserDefaults에 로컬 저장하며 앱 재실행 후 유지합니다. 서버 동기화는 없고, 상세/재생은 Repository에서 다시 권한을 확인합니다. 새 UI 회귀 1개를 포함한 총 15개 테스트는 이번 변경에서 Mac 실행 대기입니다.

## 최대 글자 검사 상태 (2026-10-13)

전체 검사(d5efaff)는 빌드/Core/컴파일 경고 검사 PASS, UI 14/15 PASS입니다. 0da634b의 버튼 높이 수정 후 2026-10-13 08:35(KST) 선택 실행에서도 상세 화면 Text clipped 1개로 FAIL(1개 실행, 1개 실패)했습니다. 후속 변경은 접근성 글자 크기에서 대표 이미지 문구를 분리하고 메타정보를 항목별 세로 배치하며, 화면별 실패 요소 로그와 상세 스크롤 검사를 추가합니다. 후속 변경의 Xcode 빌드·접근성 검사는 NOT TESTED입니다. 전체 통과로 간주하지 않습니다. 상세 근거는 Docs/PHASE2_REPORT.md를 참고하세요.


### 최대 글자 재검사 후속 상태 (2026-10-13 08:52 KST)

4eca380 선택 UI 검사는 마지막 상세 버튼 도달성 assertion 1개로 FAIL입니다. 후속 변경은 상세 스크롤 영역을 지정하고 목표 버튼의 위치를 확인하며 이동하도록 테스트를 보완합니다. 접근성 검사는 버튼 도달 후 실행하며, 실패는 그대로 기록합니다. 실제 스크롤 버그와 테스트 이동 문제의 원인은 아직 확정하지 않았습니다. 후속 빌드·UI 검증은 NOT TESTED입니다.


## 커스텀 전체 화면 플레이어 (2026-10-13)

데모 재생을 누르면 영상 위에 재생/일시정지, 10초 앞뒤, 시킹, 시간, 닫기와 소스 선택을 표시합니다. 진입 시 가로 회전을 요청하며, 회전 버튼으로 세로/가로를 요청할 수 있습니다. 닫을 때 이전 방향으로 복원을 요청합니다. 회전이 제한된 iPad 멀티태스킹에서도 가용 크기로 배치합니다. 화면 채우기는 일부 영상을 잘라 표시할 수 있고 다시 누르면 전체 영상을 봅니다.

재생 중 4초 무조작이면 컨트롤을 숨기고 화면을 누르면 다시 표시합니다. 일시정지/로딩/VoiceOver/접근성 글자 크기에서는 컨트롤을 유지합니다. 기본 영상은 30초 무음, HLS는 소스 메뉴에서 선택합니다. 소스 변경 시 처음부터 재생합니다.

사용자 제공 RESULTS(20261013-004227).txt의 변경 직전 자동 gate는 모두 PASS입니다. **이번 커스텀 플레이어의 구조 검사만 PASS이며 Xcode 빌드·UI·회전·VoiceOver·메모리는 NOT TESTED**입니다. Mac에서 ./scripts/verify-mac.sh 후 [Phase 2 보고서](Docs/PHASE2_REPORT.md)의 수동 항목을 확인하세요. 설계는 [ADR 0008](Docs/ADR/0008-custom-player-presentation.md)에 기록했습니다.

자막 선택·재생 시간 복원·자동 다음 에피소드·다운로드·DRM은 아직 구현하지 않았습니다.

### 커스텀 플레이어 첫 Mac 결과와 후속 테스트 수정

RESULTS(20261013-012609).txt 및 ui-tests(4).log에서 빌드/Core/빌드 경고 PASS, UI 17개 중 15개 PASS입니다. 가로 플레이어와 큰 글자 테스트는 통과했고, 재생 종료 후 뒤로가기/프로필 전환 2개 테스트가 실패했습니다. 닫기와 세로 회전이 겹치는 로그를 근거로 테스트가 cover 종료·원래 window frame 복원·뒤로가기 완료를 기다리도록 보완했습니다. 이 테스트 수정의 Xcode/UI 재검증은 NOT TESTED입니다. 수동 항목과 전체 완료는 별도입니다.


### Phase 2: 자막 선택 (2026-10-13)

플레이어 하단 말풍선 자막 버튼 → 끄기 / 한국어·영어 데모 자막을 선택합니다.
오프라인 MP4에는 30초 안내용 SRT 2종이 동봉되며 실제 작품 대사 번역이 아닙니다.
HLS에서는 스트림의 legible 트랙만 표시합니다. 자막이 없으면 안내하고, 필수 자막은 끄기를 비활성화합니다.
SRT는 재생 시간 기준으로 표시하고 시킹 중 숨긴 뒤 완료 위치에서 다시 계산합니다.
소스 변경·닫기·프로필 무효화 시 선택과 비동기 작업을 초기화합니다. 외부 SRT 파일 가져오기 UI와 선택 영구 저장은 이번 범위에 없습니다.

기존 사용자 제출 `RESULTS(20261013-022429).txt`의 자동 검증 8개 게이트는 모두 PASS입니다.
이번 자막 코드: 프로젝트 구조 검사 PASS, 새 Core 4개/UI 1개 테스트 및 Xcode 빌드·경고 검사는 NOT TESTED입니다.
Mac에서 `./scripts/verify-mac.sh`로 다시 검증하세요. UI 테스트 정의는 총 18개입니다.


### 2026-10-13 일시 정지 중 시킹 대기 복구

사용자가 일시 정지 후 10초 이동 시 로딩과 버튼 비활성화가 계속되는 현상을 보고했다.
코드에서 시킹 완료 대기에 별도 제한이 없는 경로를 확인했다. 사용자 환경에서의 정확한 원인은 아직 재현하지 못했다.
8초 watchdog이 시킹 요청을 무효화/취소하고 실제 재생 위치로 돌아가 안내와 조작 버튼을 복구한다.
시킹별 generation으로 늦은 완료를 무시하고, 일시 정지 의도를 유지한다.
일시 정지 중의 waitingToPlayAtSpecifiedRate를 재생 버퍼링으로 표시하지 않는다.
시킹 허용 오차는 ±0.1초이며 자막은 완료 후 실제 currentTime으로 계산한다.
Debug 전용 완료 지연 주입으로 시간 초과 후 앞뒤 반복 이동/재생 재개 UI 테스트를 추가했다(총 UI 19개 정의).

- 이전 제출 RESULTS(20261013-040411).txt: 자동 검증 8개 게이트 PASS.
- 이번 변경 프로젝트 구조: PASS.
- 이번 변경 Xcode 빌드/Swift 6/UI 테스트/실제 증상 재검증: NOT TESTED (Mac 필요).


### 2026-10-13 — 재생 위치 저장·이어보기

- 프로필 ID + 작품 ID + 버전이 있는 영상 소스 ID별 UserDefaults 저장.
- 5초마다, 닫기/소스 변경/백그라운드/프로필 전환 직전에 실제 currentTime 저장.
- 권한 확인 및 영상 준비 후 저장 위치로 먼저 이동하고 재생. 복원 완료 전에는 기존 기록을 덮어쓰지 않음.
- 이어보기 안내와 처음부터 보기 버튼 제공. 1초 미만 또는 끝에서 min(5초, 전체 5%) 이내는 다음 진입 시 처음부터 재생.
- 비정상 수치와 크게 변경된 영상 길이는 복원하지 않음. 자막은 실제 복원 위치 기준으로 동기화.
- 기존 테스트에는 Debug 전용 이어보기 비활성 인자를 적용해 테스트 간 기록 영향을 차단.
- 신규 UI 테스트는 고유 UserDefaults suite를 사용하여 앱 재실행 뒤 복원/처음부터 보기를 검증.
- 홈의 기존 계속 시청 Fixture 레일은 이번 변경 대상이 아니며, 이번 범위는 플레이어 재진입 위치 복원이다.
- 서버 동기화, 종료 순간 강제 종료의 무손실 저장, 라이브/무한 길이 스트림 복원은 지원하지 않는다.

검증: 프로젝트 구조 PASS. 새 Core 3개 테스트 및 UI 1개 추가(총 UI 20개 정의).
새 코드의 Xcode 빌드/Swift 6 경고/Core/UI 실행은 NOT TESTED — Mac verify-mac.sh 필요.
이전 RESULTS(20261013-044301).txt는 자동 8개 게이트 PASS이며, 사용자도 로딩 해제/앞뒤 이동/자막 변경을 정상 확인했다.

수동 확인: 데모 15초에서 닫기 → 같은 작품 재생 → 약 15초부터 시작.
앱을 종료하고 다시 열어도 유지되는지, 다른 프로필에는 해당 위치가 노출되지 않는지,
처음부터 보기 후 0초로 이동하는지 확인한다.


### 2026-10-13 — 가로 플레이어 자막 버튼 접근성 보완

제출 ui-tests(5).log: 18개 테스트 실행, 16개 통과/2개 실패, 실패 이벤트 9건.
이 로그에는 새 이어보기 및 시킹 timeout 테스트가 없으므로 최신 20개 회귀 검증 근거로 사용하지 않는다.
자막 테스트는 한국어 표시/앞뒤 동기화까지 통과했으나 이후 playback-subtitles isHittable=false로 연쇄 실패했다.
코드상 화면 높이 300pt 이상에서 고정 VStack을 사용해 자막/복구 문구 증가 시 footer가 화면 밖으로 밀릴 위험이 있었다.
항상 콘텐츠 높이를 수용하는 ScrollView로 변경하고 테스트는 해당 컨트롤 ScrollView를 직접 스크롤한다.
최초 실패에서 테스트를 중단하고 접근 불가 시 hierarchy/screenshot을 보존한다.

왕복 테스트는 27.76초 기록 뒤 951.45초 기록으로 약 15분 공백이 있고 BackButton 대기 실패 1건이 있다.
원인(앱 응답/시뮬레이터/호스트 중단)은 이 로그만으로 확정할 수 없다. 통과 처리하거나 대기 시간을 늘리지 않았다.
왕복 회차/시각 및 실패 화면 진단을 보강했으며 재실행이 필요하다.

이번 구조 검사 PASS. Xcode 빌드/수정 후 UI 테스트 및 왕복 실패 원인 확인 NOT TESTED.


### 2026-10-13 — 홈 실제 계속 시청

홈의 Fixture 기반 계속 시청 레일을 프로필별 실제 저장 기록으로 교체했다.
최근 20개 작품을 표시하며 작품별 가장 최근 소스 하나를 선택한다. 카드에 실제 진행률/초 단위 재생 시간/소스를 표시하고
누르면 상세 화면을 거치지 않고 해당 소스의 저장 위치에서 재생한다.
Repository.detail 및 canView로 현재 프로필 권한을 다시 확인하고, 취소/세션/갱신 세대를 검사해 이전 응답을 차단한다.
홈 재진입, 플레이어 닫기, foreground 복귀 시 갱신한다. 없는 작품/알 수 없는 소스는 제외하며 로드 오류는 재시도 버튼을 제공한다.
완료된 기록은 기존 완료 정책으로 삭제된다. 이전 v1 기록은 updatedAt이 없어도 읽으며 오래된 기록으로 정렬한다.
동일 작품의 여러 소스 기록 중 하나가 완료되면 다른 소스의 미완료 기록은 남을 수 있다.

검증: validate-project.py PASS. Core 목록 검증 1개/UI 홈 이어보기 및 프로필 분리 1개 추가(총 UI 21개 정의).
이번 변경 Xcode 빌드/Swift Concurrency/자동 테스트 실행은 NOT TESTED.
이전 제출 RESULTS(20261013-080817).txt는 자동 게이트 모두 PASS, ui-tests(6).log는 20개/실패 0건.
별도 SpringBoard 크래시는 테스트 종료 직후 XCTAutomationSupport에서 발생했고 일반 실행은 사용자 정상 보고. 근본 원인은 미확정.

수동 검증: 작품 A 15초 재생 → 닫기 → 홈 계속 시청 카드/진행률 확인 → 카드 선택 시 이어보기.
다른 프로필에서 A 기록 미노출, 원래 프로필 복귀 시 유지, 영상 끝까지 재생 후 목록 제거 확인.

## 2026-10-13 홈 이어보기 회전 복원 수정

사용자 제출 RESULTS(20261013-114236).txt: Core/빌드/경고 검사 PASS, UI FAIL.
ui-tests(7).log: 21개 중 20개 PASS, testHomeContinueWatchingUsesSavedProgress 1개 FAIL.
카드 표시와 저장 위치 복원/재생은 통과했으나 닫은 뒤 원래 402×874 프레임 복원이 10초 내 완료되지 않았다.
홈 재생 중 Portrait/Landscape가 반복되었다. 정확한 UIKit 콜백 순서는 추가 실행 확인이 필요하다.
회전 소유권을 PlaybackView의 StateObject로 이동하고 중복 요청을 차단했다.
브리지 dismantle에서는 회전을 복원하지 않으며, 닫기/플레이어 이탈 시 한 번만 복원한다.
종료한 세션의 늦은 콜백은 무시한다. 기존 프레임 복원 테스트 조건/10초 제한은 유지하고 실패 시 화면/계층을 첨부한다.
수정 후 구조 검사 PASS. 수정 후 Xcode 빌드·UI·실기기 회전 검증 NOT TESTED (이 환경에 Xcode 없음).

## 2026-10-13 플레이어 컨트롤 조작 중 숨김 및 UI 테스트 진단

ui-tests(10).log는 최초 상세 재생 후 일시정지 버튼 접근에서 실패했다. 홈 카드/회전 복원 단계까지 도달하지 못했으므로 이전 회전 수정의 결과는 미확정이다.
32~40초 컨트롤 스크롤 반복 중 컨트롤이 사라졌고, 테스트의 앱 전체 swipe fallback 이후 detail-scroll만 노출되었다. 자동 숨김과 조작의 경합 가능성을 수정하되, 전체 화면 소실의 원인은 아직 확정하지 않는다.
플레이어 컨트롤 드래그 동안 자동 숨김을 중단하고 제스처 종료 시 타이머를 갱신한다. 테스트는 매 시도마다 숨겨진 컨트롤을 다시 표시하고 실제 뷰포트/버튼 프레임을 검사한다. 플레이어 대상에는 앱 전체 스와이프를 보내지 않는다. 화면 안의 버튼이 가려져 있으면 임의 스크롤 대신 진단을 첨부하고 실패한다.
단일 재검증: `bash scripts/check-home-playback-mac.sh` (선택 사항: SIMULATOR_ID=실제UUID). 새 DerivedData, environment.txt, RESULTS.txt, ui-tests.log, xcresult를 생성한다.
구조 검사 및 bash 문법 검사 PASS. 수정 후 Xcode/단일 UI/전체 회귀/제스처 실기기 검증 NOT TESTED.

### 2026-10-13 슬라이더 제스처 간섭 가능성 제거
RESULTS(20261013-124816).txt / ui-tests(20261013-124817).log: 단일 UI FAIL(exit=65). 일시정지는 통과했으나 50% 슬라이더 조작 후 13~17초 표시 조건에서 실패했다. 실제 값은 로그에 없어 원인 확정은 불가하다. 홈 이어보기 및 회전 복원 단계는 미도달.
이전 변경의 상위 DragGesture를 제거하고 iOS 18+ onScrollPhaseChange로 스크롤 중 숨김을 제어한다. 슬라이더 입력에 별도 드래그 인식기를 추가하지 않는다. 기존 5초/13~17초 검사 기준을 유지하며 실패 시 실제 시간·슬라이더 값과 화면/계층 진단을 추가한다.
구조 검사 PASS, 수정 후 Xcode/UI/회전 복원 NOT TESTED.

### 2026-10-13 전체 화면 종료 후 회전 복원 시점 수정
단일 UI 로그(ui-tests(20261013-125623).log)는 최초 상세 재생의 일시정지/50% 시킹을 통과했지만 닫기 후 원래 프레임 402×874 복원에서 FAIL(exit=65)했다. 사용자 스크린샷에서도 상세 화면이 가로 방향으로 남았다.
회전 세션을 Home/Detail의 각 재생 presentation이 소유하도록 변경했다. 닫기/이탈 때는 늦은 회전 요청만 차단하고, fullScreenCover의 onDismiss에서 원래 방향을 한 번 복원한다. 새 재생마다 새 세션을 만든다.
10초 제한과 원래 프레임 비교는 유지하며, 최초 상세 재생 종료 실패에도 실제 프레임/닫기 버튼 상태/화면/계층을 남긴다.
구조 검사 PASS. 수정 후 Xcode 빌드·단일 UI·전체 회귀·실기기 회전은 NOT TESTED. 재검증: bash scripts/check-home-playback-mac.sh.

### 2026-10-13 재생 전 방향 저장 및 회전 진단 추가
312c901 재검증: RESULTS(20261013-131720).txt / ui-tests(20261013-131718).log에서 단일 UI FAIL(exit=65). 닫기 버튼은 사라졌지만 예상 402×874 대신 실제 874×402로 남았다. onDismiss 복원 변경만으로 해결되지 않았다.
기존 코드는 플레이어 브리지의 최초 요청에서 원래 방향을 저장하고, 재생 시 회전 객체를 교체했다. 이제 Home/Detail의 StateObject로 동일 객체를 유지하고, 해당 화면의 WindowScene을 연결해 재생 버튼에서 begin()으로 회전 전 방향을 저장한다. 복원은 onDismiss에서 실행한다. UIKit 브리지 업데이트도 현재 세션을 동기화한다.
정확한 이전 런타임 실패 원인은 아직 미확정이다. OSLog에 begin/capture/request/finish 및 거절 오류를 기록하고 단일 테스트 스크립트가 orientation.log로 수집한다. 테스트의 10초/정확한 프레임 조건은 유지한다.
PASS: 프로젝트 구조, 스크립트 bash 문법. NOT TESTED: 새 Swift 코드 컴파일, iOS 단일 UI, 전체 회귀 및 실제 회전.

## 2026-10-14 연속 재생 데모
영상 소스 메뉴에서 '연속 재생 데모 · 1화'를 선택하면 3화짜리 로컬 데모 시퀀스를 실행한다.
세 화는 같은 30초 무음 MP4/SRT를 재사용하며 실제 서로 다른 드라마 에피소드가 아니다.
기존 오프라인 데모와 HLS는 단일 영상 동작을 유지한다. 카탈로그에 실제 시즌/회차 데이터 연결은 후속 작업이다.

- 재생 의도가 활성화된 상태로 영상 종료 시 10초 카운트다운 후 다음 화로 전환한다.
- 자동 전환 취소 / 다음 화 지금 재생을 제공한다. 3화 종료 후에는 멈춘다.
- 백그라운드 진입과 소스·자막 메뉴 열기는 카운트다운을 취소한다. 취소 후 반복 샘플링으로 자동 재시작하지 않는다.
- 각 전환은 기존 load/stop 경로를 사용해 이전 Task를 취소하고 Repository에서 현재 프로필 권한을 재검사한다.
- 같은 작품이라도 화별 sourceID를 사용해 진행 기록을 분리한다. 홈 이어보기는 저장된 화의 소스를 복원한다.
- 다음 화 전환 시 자막 선택은 기존 소스 변경 정책에 따라 초기화된다. 자막 선호 저장/복원은 후속 작업이다.

검증: 구조 검사 및 셸 문법 PASS. 새 Core 테스트 3개, UI 테스트 2개, Swift 6 컴파일 및 실제 재생은 NOT TESTED(현재 실행 환경에 Swift/Xcode 없음).
Mac: bash scripts/check-episodes-mac.sh (UI 2개만 실행). Core: swift test --package-path Packages/StreamLabCore.

### 이전 코드 검증 증거
RESULTS(20261013-132842).txt: 홈 이어보기/방향 복원 단독 PASS.
RESULTS(20261013-140519).txt: fixtures/구조/bootstrap/Core/빌드/warning-free PASS, UI 21개 중 20 PASS/1 FAIL.
실패한 60회 왕복은 접근성 snapshot 수집 416.20초 지연을 동반했다. 사용자 수동 일시정지/잠자기 없음 보고. 근본 원인 미확정.
ui-tests(20261013-151947).log: 코드 변경 없는 단독 재실행에서 60/60회 완료, 1 test/0 failures, 502.977초 PASS.
전체 실행 실패와 단독 재실행 성공은 별도 기록이며 21개 동시 PASS 또는 간헐적 지연 해결로 해석하지 않는다.

### Profile subtitle / audio preferences

The subtitle button now opens **자막 및 오디오**. Subtitle off/language and audio
language are saved per profile and restored when reopening playback or advancing
episodes. If a video lacks the language, a default available track (or subtitles off)
is used without discarding the preference. Silent demos do not offer fake audio tracks.

Focused validation (Mac; Core + two UI tests):

```bash
cd ~/Desktop/streamlab-ios &&
git pull --ff-only --no-rebase origin main &&
caffeinate -i bash scripts/check-languages-mac.sh
```

Results: `Docs/Validation/languages-*/RESULTS.txt`, `core.log`, `ui-tests.log`,
`UITests.xcresult`. Build products use a fresh `/private/tmp` directory; its path is
recorded in `environment.txt`. Local structure/shell checks PASS; new Mac tests and
real HLS alternate-audio playback are NOT TESTED until executed.
See ADR 0013. Real audio QA: choose an available HLS audio language, close/reopen,
check selection and listen; switch profile; try a video without that language, then
return to one that supports it. Do not count silent demo tests as audio validation.

### Real HLS alternate audio check

Run the app normally, then **데모 재생 → … → HLS 오디오 비교 · 영어 / 화면 해설**.
In **자막 및 오디오**, compare English with English (DVS). This Apple sample has
English and audio description, not two spoken languages. See [listening steps and
limitations](Docs/HLS_AUDIO_QA.md). Audio description versus ordinary audio is saved with the profile language.
Different commentary tracks sharing both language and role are not distinguished.

User-supplied 2026-10-14 full verification reports all automated stages PASS
(RESULTS(20261014-004947).txt), before this new source was added. New source Xcode
build and actual HLS listening remain NOT TESTED here.

### Language selector layout

The player now shows a dark rounded panel with **음성** on the left and **자막**
on the right. Each column scrolls independently; narrow screens and accessibility
text sizes use one column. Choices apply immediately; use the top-right close
button to return. Only tracks available in the current media are listed.
Run `caffeinate -i bash scripts/check-languages-mac.sh` for the updated selection
and close-flow tests. New panel Xcode/runtime validation is pending.

### Audio description preference restoration

Audio selection now persists language plus ordinary/audio-description role per
profile. Missing roles temporarily fall back without overwriting the preference;
기본 오디오 clears the explicit role. Legacy language-only settings remain readable.
Run `caffeinate -i bash scripts/check-languages-mac.sh` for Core and existing language
UI regression, then follow steps 6–10 in Docs/HLS_AUDIO_QA.md for real DVS restoration.
The new role-specific Core tests and actual HLS restoration are NOT TESTED here.

### Profile playback position diagnostics

A profile-isolation report remains open. Player covers now use session/title
identity; new saved records validate ownership; HLS VOD without a saved position
explicitly starts at zero. Existing records remain intact. In a Debug run, filter
Xcode console by `fresh profile=` or `restore profile=` (OSLog category
`PlaybackProgress`) to identify the selected profile, title, source and position.
After updating, run `caffeinate -i ./scripts/verify-mac.sh`, then reproduce with the
same title and HLS source across Alex and Jamie. New code is not yet Xcode-tested.

Playback elapsed time and duration use `HH:MM:SS / HH:MM:SS` (for example,
`00:00:20 / 00:01:38`); scrubbing previews use the same format.

### Focused UI regression recovery

Run `caffeinate -i bash scripts/check-ui-recovery-mac.sh` to check subtitle
restoration and the 60-cycle navigation soak. Results, logs and xcresult are
written to `Docs/Validation/ui-recovery-*`. Each test has a 900-second allowance;
a timeout remains a failure, never a pass or an automatic retry. Core tests
passed in the separately supplied 15b3168 run; this script does not rerun them.

For the remaining subtitle seek failure, run
`caffeinate -i bash scripts/check-subtitle-seek-mac.sh`. This checks actual seek
completion before time and caption assertions, retaining failure diagnostics in
`Docs/Validation/subtitle-seek-*`. A seek timeout still fails the test.


### A2 재생 상태 관측 및 QoE 검증

```bash
caffeinate -i bash scripts/check-playback-qoe-mac.sh
```

Core 전이/계측 테스트와 회차·재시도·빠른 닫기·seek timeout UI 테스트를 실행합니다.
출력 폴더의 RESULTS.txt, core.log, ui-tests.log, qoe.log를 확인하세요.
QoE summary 수집 성공은 성능 임계치 통과를 뜻하지 않습니다.
first_frame_ready_seconds는 250ms 주기의 레이어 render-ready 관측값이며 정밀 TTFF가 아닙니다.
실기기 HLS 20회 p50/p95와 네트워크 stall 계측은 별도 진행해야 합니다.
설계/한계: Docs/ADR/0017-playback-observation-and-qoe.md.


### 선택할 수 없는 자막·음성 대체 처리

```bash
caffeinate -i bash scripts/check-track-fallback-mac.sh
```

Core 및 자막 fallback/복원/프로필 격리 UI 테스트를 실행합니다.
RESULTS.txt, core.log, ui-tests.log를 확인하세요.
UI 누락 언어 fixture는 Debug 번들 데모 전용입니다. 실제 HLS의 트랙 로딩 장애
검증을 대체하지 않습니다. 정책은 Docs/ADR/0018-track-fallback.md에 기록합니다.


### 실제 HLS 테스트 시즌 (2화)

플레이어 영상 소스에서 HLS 테스트 시즌 1화/2화를 선택하세요.
기존 공개 샘플을 연결한 검증용 시즌이며 실제 작품 회차는 아닙니다.
인터넷 연결 후 아래 명령을 실행합니다.

```bash
caffeinate -i bash scripts/check-hls-episodes-mac.sh
```

RESULTS.txt, ui-tests.log, qoe.log를 확인하세요.
일반 회귀에서는 실 네트워크 테스트를 skip합니다. 이 전용 스크립트에서만 실행하며,
두 테스트가 실제 passed인지도 확인합니다. 수동 항목: Docs/HLS_EPISODES_QA.md.


### 미디어 서비스 리셋·재시도 한도 검증

```bash
caffeinate -i bash scripts/check-media-recovery-mac.sh
```

리셋 알림 주입/사용자 복구와 최대 3회 재시도 정책을 확인합니다.
RESULTS.txt, core.log, ui-tests.log, qoe.log를 수집합니다.
실제 OS 데몬 재시작이나 실기기 검증을 대신하지 않습니다.
정책 및 수동 검증: Docs/ADR/0019-media-reset-and-bounded-retry.md.

### 2026-10-16 대상 회귀 재검증

최근 3개 대상 중 자막 복원/큰 글자 플레이어는 PASS, 나의 리스트는 FAIL입니다.
카테고리별 홈 스크롤 identity를 분리해 추천 복귀 시 상단과 히어로를 다시 구성합니다.
수정 후 Xcode/UI는 NOT TESTED이며 `bash scripts/check-regression-fixes-mac.sh`로 확인합니다.
