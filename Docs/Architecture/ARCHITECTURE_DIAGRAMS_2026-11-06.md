# StreamLab | 소스 검증 기반 통합 아키텍처 다이어그램 (개정판)

> 기준: **2026-11-07**. 앱·관리자 소스 기준 커밋 `9a4d395`; 이후 문서 업데이트는 별도 커밋이다. **실제 구현 / Mock 테스트 / 추가 검증**을 구분한다.
>
> 원문 과제는 교육·포트폴리오용 비공식 시뮬레이션이며 실제 Netflix 내부 과제나 채용 판정이 아니다.
> [현재 구조 설명](../ARCHITECTURE_CURRENT.md) · [원문별 감사](../ASSIGNMENT_AUDIT_2026-11-06.md) · [잔여 증빙](../Measurements/Final-Gaps-2026-11-06/REPORT.md)

## 1. 서비스 / 배포 경계 (데이터 흐름)

~~~mermaid
flowchart LR
  subgraph A["관리자 웹 · Firebase Hosting"]
    ADM["Google 관리자 로그인<br/>작품 편집/공개/업로드<br/>2GB+ 압축 계획 UI"]
  end
  subgraph F["Firebase (운영 콘텐츠 인프라)"]
    AUTH["Firebase Auth<br/>관리자 권한"]
    DB["Firestore<br/>공개 카탈로그·영상 주소"]
    STO["Cloud Storage<br/>MP4 원본/업로드본"]
  end
  subgraph IOS["iOS 18+ / StreamLab"]
    APP["SwiftUI 앱 / AppRootView<br/>Mock 또는 Firebase Scheme"]
    PLY["AVPlayer · PiP<br/>HLS / MP4"]
    OFF["오프라인 저장<br/>SQLite / JSON / 미디어 파일"]
  end
  MOCK["독립 Mock/loopback HTTP<br/>계정·진도·mutation·entitlement"]
  ADM --> AUTH
  ADM --> DB
  ADM --> STO
  APP -->|"공개 작품 REST 조회"| DB
  APP -->|"재생 주소·다운로드"| STO
  APP --> PLY
  APP <--> OFF
  APP <-.->|"시뮬레이션 / 테스트"| MOCK
~~~

- **실제 배포**: Firebase Hosting 관리자, Google 관리자 인증, Firestore 공개 카탈로그, Storage MP4. 관리자 업로드 최대 5GB. 압축 방식은 브라우저에서 *계획*하고 실제 변환은 Mac에서 수행; 서버 인코딩/MP4→HLS 자동 변환은 없음.
- **앱 선택 경로**: 기본 StreamLab Scheme은 2,000개 합성 Mock 카탈로그, StreamLab-Firebase Scheme은 공개 Firebase 카탈로그.
- **서버 구현으로 오해하지 말 것**: 일반 앱 사용자 인증·멀티 디바이스 진도 서버·DRM 권한 검증은 Mock/loopback 시뮬레이션. Firestore가 오프라인 outbox 서버 역할을 하지 않는다.
- 공개 취소는 이미 알려진 다운로드 토큰 URL을 소급 폐기하지 않는다. 실제 유료 콘텐츠 배포/DRM 보호로 취급하지 않는다.

## 2. 실제 Swift Package 의존성

화살표는 **컴파일 타임 의존**이다. 기능 설계 그림과 달리 Package.swift에 명시된 의존성만 나타낸다.

~~~mermaid
flowchart TB
  APP["App 타깃<br/>AppRootView · Scene/Background delegate"]
  CF["StreamLabCatalogFeature<br/>Home/Search/Detail · PlaybackModel<br/>OfflineDownloadStore"]
  PF["StreamLabProfileFeature"]
  DS["StreamLabDesignSystem"]
  PR["StreamLabPresentation<br/>Auth · Stores · Sync · SQLite"]
  CD["StreamLabCatalogData<br/>Mock/Firestore Repository · Artwork"]
  DM["StreamLabDomain<br/>Models · Invariants · Policy"]
  SQL["CSQLite (시스템 SQLite)"]
  APP --> CF
  APP --> PF
  APP --> DS
  APP --> CD
  APP --> DM
  CF --> DS
  CF --> PR
  CF --> CD
  CF --> DM
  PF --> DS
  PF --> DM
  DS --> CD
  DS --> DM
  PR --> DM
  PR --> SQL
  CD --> DM
~~~

- Swift 6 / iOS 18+; UI는 SwiftUI이며 플레이어·회전·PiP·네이티브 다운로드는 AVFoundation/UIKit 시스템 API를 사용.
- **현실적인 주의**: PlaybackModel과 OfflineDownloadStore는 별도 SPM Feature 타깃이 아니라 **StreamLabCatalogFeature** 안에 구현되어 있다. 구조 개선 제안을 *이미 구현된 타깃*으로 표현하지 않는다.
- Domain 타깃은 UI·AVPlayer에 의존하지 않는다. Presentation에서 SQLite 저장소를 소유한다.

## 3. 앱 런타임 구성과 프로필/세션 소유권

이 그림은 **컴파일 의존성 그래프가 아닌 객체 소유권·요청 수명 흐름**이다. AppRootView가 Repository 및 Account를 준비하고 프로필을 선택할 때마다 새 CatalogSession ID를 생성한다.

~~~mermaid
flowchart TB
  AR["AppRootView (SwiftUI / @MainActor)<br/>계정 복원 · Scheme/Repository 선택"]
  CA["CatalogAccount<br/>인증/계정 상태"]
  CS["CatalogSession (선택마다 UUID 갱신)<br/>accountID · profileID · isActive"]
  UI["Home / Search / Detail / Downloads<br/>프로필에 귀속된 화면"]
  PLAY["PlaybackModel<br/>1개 재생 프레젠테이션의 player 소유"]
  STORES["MyList / Progress / RecentSearch / Language Stores"]
  SYNC["ConnectionRecoveryCoordinator<br/>기존 요청 취소 · 늦은 응답 배제"]
  REP["CatalogRepository<br/>MockCatalogRepository 또는 FirestoreCatalogRepository"]
  AR --> CA
  AR --> CS
  AR --> REP
  CS --> UI
  CS --> PLAY
  CS --> STORES
  CS --> SYNC
  UI --> REP
  PLAY --> STORES
  CS -.->|"deactivate 후 새로운 세션"| CS
~~~

- **프로필 경계**: CatalogSession의 UUID 및 account/profile scope와 actor/task 유효성을 검사한다. 지난 세션의 비동기 응답과 재생 콜백을 새 화면에 반영하지 않는다.
- **플레이어/다운로드 소유권은 다르다**: `PlaybackModel`은 플레이어 1회 presentation의 수명을 관리한다. `OfflineDownloadStore.shared`는 OS 백그라운드 세션에 재연결하기 위한 프로세스 단위 소유자이며 각 항목을 계정·프로필로 격리한다.
- **데이터 저장 범위**: SQLite는 찜·최근 검색·재생 진도와 outbox용. 다운로드 메타데이터는 `offline-downloads.json`을 유지하며 실제 미디어는 파일로 저장한다.

## 4. Local-first 저장 / 정합성 경로

~~~mermaid
sequenceDiagram
  autonumber
  participant U as SwiftUI / User
  participant S as @MainActor Store
  participant L as SQLite (profile.sqlite)
  participant Q as RetryingMutationTransport
  participant M as Mock 또는 loopback HTTP 서버
  U->>S: 찜/진도/최근검색 변경
  S->>L: BEGIN IMMEDIATE
  S->>L: local_values + outbox + metadata 갱신
  L-->>S: COMMIT 성공
  S-->>U: optimistic 상태 표시
  S->>Q: pending mutation (same idempotencyKey)
  Q->>M: 전송 + revision/sequence
  alt 정상 응답
    M-->>Q: ACK + 새 revision
    Q-->>S: ACK/새 revision 전달
    S->>L: scope 검사 후 ACK/outbox 트랜잭션
  else 409 충돌
    M-->>Q: Conflict + server snapshot
    Q->>S: conflict reconcile → 재동기화
  else 429/503/timeout
    Q->>Q: bounded retry + Retry-After/backoff+jitter
  end
  Note over S,L: 기존 JSON은 최초 열기에서 검증 후 SQLite로 이전
  Note over Q,M: 앱 종료 전 송신 불확실성은 동일 요청 ID로 재시도
~~~

- 계정별 디렉터리/프로필별 SQLite. 하나의 트랜잭션에 화면 projection·outbox·revision/metadata를 함께 커밋한다. COMMIT 실패 시 성공 UI로 처리하지 않는다.
- 동일 범위 idempotencyKey, 서버 revision, sequence로 중복 효과를 막는다. 실제 서버 다중 단말 동기화는 Mock 검증이다.
- MainActor가 쓰기를 직렬화하지만 **현재 SQLite는 동기 디스크 I/O**. 이를 프레임 성능 최적화라고 주장하지 않는다.
- 프로필 전환 시 CatalogSession ID/계정·프로필 경계가 달라지고 이전 in-flight 응답/콜백은 적용하지 않는다. 로그아웃은 저장소와 지연 알림을 무효화한다.
- SQLite는 찜/검색/진도용이다. 다운로드 상태는 별도 offline-downloads.json 파일 저널이며 미디어 본체는 파일로 보관한다.

## 5. Player 관측 상태 / 실행 수명 경계

~~~mermaid
stateDiagram-v2
    direction LR
    [*] --> idle
    idle --> active: load와 새 generation
    state active {
        [*] --> preparing
        preparing --> ready: item 준비
        ready --> playing: 재생 관측
        ready --> paused: 일시정지 관측
        ready --> buffering: 데이터 대기
        ready --> seeking: 저장 진도 복원
        playing --> paused: pause
        paused --> playing: play
        playing --> buffering: stall
        paused --> buffering: 재개 대기
        buffering --> playing: 데이터 도착
        buffering --> paused: pause
        playing --> seeking: 탐색
        paused --> seeking: 탐색
        buffering --> seeking: 탐색
        seeking --> playing: 탐색 완료와 재생 의도
        seeking --> paused: 탐색 완료와 정지 의도
        seeking --> buffering: 탐색 후 데이터 대기
    }
    playing --> ended: 재생 종료
    paused --> ended: 종료 관측
    buffering --> ended: 종료 관측
    seeking --> ended: 종료 관측
    ended --> seeking: 처음부터 보기
    active --> failed: 권한 또는 player 오류
    active --> idle: 닫기 또는 세션 취소
    ended --> idle: 닫기
    failed --> idle: 닫기 또는 재시도 준비
    idle --> [*]: 화면 수명 종료
~~~

- 이 상태도는 저장소의 [Player 상태도](../States/PLAYER.md)와 동일한 전이이다. `active`는 설명용 상위 상태이며 Swift enum 케이스가 아니다. 장애/버퍼 이벤트와 실제 권한 오류를 구분한다.
- PlaybackModel이 요청 수명·세대(generation)·권한 grant·seek completion·observer/Task/Now Playing 정리를 통제.
- 자막·오디오 선택, PiP, 10초 이동, 이어보기, QoE 계측은 AVPlayer 및 별도 Store/Observer와 연동.
- 권한 만료와 키 오류는 **Mock**. FairPlay 키 교환, 운영 라이선스 서버, 신뢰 시계·실제 DRM은 구현되지 않음.

## 6. Download 실제 상태 전이 / 저장 경계

~~~mermaid
stateDiagram-v2
    direction LR
    [*] --> queued: 권한 확인과 기록 저장
    queued --> downloading: 동시 작업 자리와 예산 확보
    queued --> failed: 시작 실패 또는 공간 부족
    downloading --> paused: 저장 후 task suspend
    paused --> downloading: 여유 공간 확인 후 resume
    downloading --> complete: 파일과 예산 검증 및 기록 저장
    paused --> complete: 이미 진행 중이던 완료 콜백
    downloading --> failed: 전송 실패 또는 공간 부족
    paused --> failed: 복원 시 OS 작업 소실
    complete --> failed: 저장 파일 유실 또는 손상
    complete --> expired: 이용 기한 경과
    failed --> queued: 정리와 재승인 후 새 UUID
    expired --> queued: 정리와 재승인 후 새 UUID
    complete --> queued: 새 영상 교체 승인 후 새 UUID
    downloading --> removing: 취소 또는 로그아웃
    paused --> removing: 취소 또는 로그아웃
    removing --> failed: 삭제 실패
    removing --> [*]: 취소 콜백과 파일 정리 완료
    queued --> [*]: OS 작업 없는 기록 삭제
    failed --> [*]: 잔여 파일과 기록 삭제
    complete --> [*]: 수동 삭제 또는 LRU
    expired --> [*]: 수동 삭제 또는 LRU
~~~

- HLS: AVAssetDownloadURLSession + .movpkg / MP4: URLSession + 로컬 미디어 파일.
- **동시 다운로드 2개 · 전체 관리 예산 1,000,000,000바이트 (1GB)**. 전송 초기 예약 500MB는 개별 파일 크기 제한이 아니다.
- 사용자가 고정한 파일 또는 재생 중 lease가 있는 파일은 자동 LRU 제거 대상이 아니다. 사용권·계정·프로필을 확인한다.
- 백그라운드/복원/완료 알림은 OS 콜백의 지연과 로그아웃 epoch를 검사한다. 1GB는 앱의 관리 정책이며 OS의 순간 물리 디스크 상한이 아니다.
- [정확한 전이·실패·취소 경계](../States/DOWNLOAD.md).

## 7. 과제 요구 충족 범위 / 미확인 사항

| 범위 | 현재 구현·검증 | 과장하지 않을 항목 |
|---|---|---|
| A1 홈/탐색 | 3프로필, Mock 2,000개, Firebase 선택 Scheme | Firebase 공개 조회는 최대 200개; 서버 대규모 페이지네이션은 남음 |
| A2 Player | AVPlayer/HLS/MP4, PiP, 자막, 탐색/복원, 오류·QoE | 모든 실제 OS media reset과 운영 DRM 보장 아님 |
| A3/B 정합성 | revision/idempotency, Mock 다중 디바이스, SQLite projection+outbox, SIGKILL 시험 | 실서비스 계정/멀티디바이스 백엔드 아님 |
| C1 다운로드 | 네이티브 전송, 오프라인, 예산/LRU/만료, F06/F09 경계 | 실제 OS ENOSPC·모든 jetsam 조건 보장 아님 |
| C2 보안 | Keychain, 로그 최소화, Mock entitlement, 세션 무효화 | FairPlay/DRM/유료콘텐츠 보호 없음 |
| C3/C4 품질 | 자동 접근성 감사, 계측·회귀 스크립트 | 실제 VoiceOver 전체 경로·배터리 전력·동일 조건 개선 측정은 추가 증빙 필요 |
| D 카오스 | seed 고정, Mock HTTP/연결 복구/실제 iOS 일부 경계 | 모든 OS 장애를 실제 단말에 재현했다는 의미 아님 |


## 8. 동시성, 오류 복구, 책임 경계

~~~mermaid
flowchart LR
  VIEW["SwiftUI @MainActor<br/>View / Store"] --> SESSION["CatalogSession<br/>UUID/Task cancellation"]
  SESSION --> AUTH["AuthenticationSession actor<br/>single-flight token refresh"]
  SESSION --> REPO["CatalogRepository protocol<br/>Mock / Firestore"]
  SESSION --> LOCAL["DurableMutationStore @MainActor<br/>SQLite BEGIN IMMEDIATE + COMMIT"]
  LOCAL --> RETRY["RetryingMutationTransport<br/>bounded retry/backoff"]
  RETRY -.-> MOCK["MockMutationServer / loopback HTTP<br/>409 / 429 / 503 / timeout"]
  SESSION --> PLAYER["PlaybackModel @MainActor<br/>AVPlayer observer / generation"]
  SESSION --> DOWNLOAD["OfflineDownloadStore.shared @MainActor<br/>OS background transfer owner"]
~~~

- **인증과 미디어 권한을 구분**: 앱 인증에는 Keychain 및 `AuthenticationSession` actor의 single-flight refresh 테스트가 있고, 콘텐츠 이용권 grant/DRM은 Mock이다. Firebase Auth는 관리자에 적용하며 사용자 오프라인 동기화 서버가 아니다.
- **SQLite ACK 경로**: transport가 DB를 직접 소유하지 않는다. store가 idempotency/revision/owner를 검증한 후 SQLite projection·outbox·metadata에 원자적으로 반영한다.
- **다운로드 상한**: 기기 전체 관리 예산 **1,000,000,000 bytes**, 동시 작업 **2개**. 초기 500MB 예약은 개별 미디어의 고정 상한이 아니다. 관리자 MP4 업로드 **5GB**와는 무관하다.
- **진단/성능**: 실제 TTFF 화면 표시와 HLS 준비 시간의 메트릭을 혼동하지 않는다. SQLite의 MainActor 동기 I/O를 개선 완료로 보고하지 않는다.

## 9. 문서-코드 교차 확인표

| 도표/정책 | 근거 코드·문서 |
| --- | --- |
| 앱 시작/선택 | `App/Scene/AppRootView.swift`, `CatalogSession.swift` |
| 실제 SPM edge | `Packages/StreamLabCore/Package.swift`, `Packages/StreamLabUI/Package.swift` |
| SQLite projection/outbox | `StreamLabPresentation/Sync/DurableMutationStore.swift`, `SQLiteMutationDatabase.swift`, `Docs/ADR/0030-*` |
| Player 수명/관측 | `StreamLabCatalogFeature/Playback/PlaybackModel.swift`, `StreamLabDomain/Models/PlaybackDiagnostics.swift`, `Docs/States/PLAYER.md` |
| Native 다운로드 | `StreamLabCatalogFeature/Downloads/OfflineDownloadStore.swift`, `App/Application/DownloadBackgroundDelegate.swift`, `Docs/States/DOWNLOAD.md` |
| 테스트/남은 근거 | `Docs/CI_VALIDATION.md`, `Docs/CHAOS_ACCEPTANCE.md`, `Docs/Measurements/Final-Gaps-2026-11-06/REPORT.md` |

> 이번 다이어그램 업데이트는 **문서 개정**이며 새 Xcode 빌드, 실기기 VoiceOver 전체 경로, 에너지 계측, 운영 DRM 구현을 뜻하지 않는다. 이전 6페이지 PDF와 `submission-2026-11-06` 태그는 기록용 스냅샷으로 남긴다.

### 코드·증거 위치
- Package 의존성: Packages/StreamLabCore/Package.swift, Packages/StreamLabUI/Package.swift
- 실제 진입/세션: App/Scene/AppRootView.swift, StreamLabCatalogFeature/State/CatalogSession.swift
- Player/Download: StreamLabCatalogFeature/Playback/PlaybackModel.swift, Downloads/OfflineDownloadStore.swift
- SQLite: StreamLabPresentation/Sync/SQLiteMutationDatabase.swift, DurableMutationStore.swift, ADR/0030
- 테스트/재현: Docs/CI_VALIDATION.md, Docs/CHAOS_ACCEPTANCE.md, Docs/Measurements/Final-Gaps-2026-11-06/REPORT.md

### 문서 버전
- [현재 PDF](streamlab-architecture-ko.pdf)는 앱 코드 `9a4d395` 기준 8쪽 그림 문서다. 기존 6쪽 PDF는 [제출 태그](https://github.com/KyungHoon416/streamlab-ios/blob/submission-2026-11-06/Docs/Architecture/streamlab-architecture-ko.pdf)와 기존 ZIP에 보존했다.
- 본 문서는 PDF보다 상세한 Package 의존성·객체 소유권·전체 상태 전이를 제공한다. 두 문서 모두 SQLite/5GB 정책과 실제 구현을 기준으로 한다.
- 새로운 PDF를 제출할 때는 생성 시점의 앱 코드 SHA, 검증 범위, 미완료 항목을 함께 기록한다.
