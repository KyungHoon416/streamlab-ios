# StreamLab | 최신 아키텍처 다이어그램

> 기준: 2026-11-06, 앱/관리자 코드 기준 커밋 \`6642b7c\` (문서 추가 전). **구현 구조와 계획을 구분**한다.
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

## 3. Local-first 저장 / 정합성 경로

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
    Q->>L: ACK/계정·프로필 scope 상태 반영
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

## 4. Player 수명주기 / 경계

~~~mermaid
stateDiagram-v2
  [*] --> idle
  idle --> preparing: 새 세션 / entitlement 검사
  preparing --> ready: AVPlayerItem 준비
  ready --> playing: 실제 재생 관측
  playing --> paused: pause
  paused --> playing: resume
  playing --> buffering: stall / 버퍼 대기
  buffering --> playing: 복구
  playing --> seeking: seek
  paused --> seeking: seek
  seeking --> playing: 최신 generation / 재생 의도
  seeking --> paused: 최신 generation / 정지 의도
  playing --> ended: 종료
  preparing --> failed: 권한 / 미디어 오류
  ready --> failed: 오류
  playing --> failed: 오류
  buffering --> failed: 오류
  failed --> preparing: 새 세션 재시도 (최대 3회)
  ended --> idle: 닫기
  failed --> idle: 닫기
  paused --> idle: 닫기 / 전환
  playing --> idle: 닫기 / 전환
  buffering --> idle: 닫기 / 전환
~~~

- 이 그림은 **설명용 축약**. 실제 관측 상태는 [Player state](../States/PLAYER.md)를 기준으로 한다.
- PlaybackModel이 요청 수명·세대(generation)·권한 grant·seek completion·observer/Task/Now Playing 정리를 통제.
- 자막·오디오 선택, PiP, 10초 이동, 이어보기, QoE 계측은 AVPlayer 및 별도 Store/Observer와 연동.
- 권한 만료와 키 오류는 **Mock**. FairPlay 키 교환, 운영 라이선스 서버, 신뢰 시계·실제 DRM은 구현되지 않음.

## 5. Download 수명주기 / 저장 경계

~~~mermaid
stateDiagram-v2
  [*] --> queued: 권한 / 소유자 확인
  queued --> downloading: 슬롯 + 예산 예약
  downloading --> paused: suspend
  paused --> downloading: resume
  downloading --> complete: 파일 검증/기록
  downloading --> failed: 네트워크/용량 오류
  paused --> failed: 복원 실패
  complete --> expired: 7일 만료
  failed --> queued: 새 시도 UUID
  expired --> queued: 재다운로드
  downloading --> removing: 취소 / 로그아웃
  paused --> removing: 취소 / 로그아웃
  removing --> [*]: 파일/OS 작업 정리
  complete --> [*]: 수동 삭제 / LRU
  expired --> [*]: 삭제 / LRU
~~~

- HLS: AVAssetDownloadURLSession + .movpkg / MP4: URLSession + 로컬 미디어 파일.
- **동시 다운로드 2개 · 전체 관리 예산 1,000,000,000바이트 (1GB)**. 전송 초기 예약 500MB는 개별 파일 크기 제한이 아니다.
- 사용자가 고정한 파일 또는 재생 중 lease가 있는 파일은 자동 LRU 제거 대상이 아니다. 사용권·계정·프로필을 확인한다.
- 백그라운드/복원/완료 알림은 OS 콜백의 지연과 로그아웃 epoch를 검사한다. 1GB는 앱의 관리 정책이며 OS의 순간 물리 디스크 상한이 아니다.
- [정확한 전이·실패·취소 경계](../States/DOWNLOAD.md).

## 6. 과제 요구 충족 범위 / 미확인 사항

| 범위 | 현재 구현·검증 | 과장하지 않을 항목 |
|---|---|---|
| A1 홈/탐색 | 3프로필, Mock 2,000개, Firebase 선택 Scheme | Firebase 공개 조회는 최대 200개; 서버 대규모 페이지네이션은 남음 |
| A2 Player | AVPlayer/HLS/MP4, PiP, 자막, 탐색/복원, 오류·QoE | 모든 실제 OS media reset과 운영 DRM 보장 아님 |
| A3/B 정합성 | revision/idempotency, Mock 다중 디바이스, SQLite projection+outbox, SIGKILL 시험 | 실서비스 계정/멀티디바이스 백엔드 아님 |
| C1 다운로드 | 네이티브 전송, 오프라인, 예산/LRU/만료, F06/F09 경계 | 실제 OS ENOSPC·모든 jetsam 조건 보장 아님 |
| C2 보안 | Keychain, 로그 최소화, Mock entitlement, 세션 무효화 | FairPlay/DRM/유료콘텐츠 보호 없음 |
| C3/C4 품질 | 자동 접근성 감사, 계측·회귀 스크립트 | 실제 VoiceOver 전체 경로·배터리 전력·동일 조건 개선 측정은 추가 증빙 필요 |
| D 카오스 | seed 고정, Mock HTTP/연결 복구/실제 iOS 일부 경계 | 모든 OS 장애를 실제 단말에 재현했다는 의미 아님 |

### 코드·증거 위치
- Package 의존성: Packages/StreamLabCore/Package.swift, Packages/StreamLabUI/Package.swift
- 실제 진입/세션: App/Scene/AppRootView.swift, StreamLabCatalogFeature/State/CatalogSession.swift
- Player/Download: StreamLabCatalogFeature/Playback/PlaybackModel.swift, Downloads/OfflineDownloadStore.swift
- SQLite: StreamLabPresentation/Sync/SQLiteMutationDatabase.swift, DurableMutationStore.swift, ADR/0030
- 테스트/재현: Docs/CI_VALIDATION.md, Docs/CHAOS_ACCEPTANCE.md, Docs/Measurements/Final-Gaps-2026-11-06/REPORT.md

### 문서 버전
- Docs/Architecture/streamlab-architecture-ko.pdf (기존 6쪽)은 **이전 제출 시점 스냅샷**이다.
- 본 문서가 SQLite/5GB 정책까지 반영한 **현재 구현의 시각화**다.
- 새로운 PDF를 제출할 때는 생성 시점의 앱 코드 SHA, 검증 범위, 미완료 항목을 함께 기록한다.
