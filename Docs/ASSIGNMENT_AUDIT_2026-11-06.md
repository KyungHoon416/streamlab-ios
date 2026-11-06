# 과제 원문 기준 완료·잔여 점검 — 2026-11-06

**확인 기준으로 약 90% 완료, 약 10% 보완이 남았다. 아직 원문 전체 완료로 판정하지 않는다.** 핵심 앱 동작과 제출 영상·PDF는 준비됐으며, 남은 일은 저장 계층의 요구 해석/보완, 제한된 추가 검증, 제출 문서 정리다.

원본 `Netflix_iOS_과제.docx`를 직접 대조했다. SHA-256은 `5f2227f658aa52f16a2429c68c4ee3b729fc8e49c17883441cb455622d058250`이다. 앱 코드는 `04bb985`와 동일한 범위, 검토 시작 저장소는 `b10bb7e`다. 이번 관리자 압축 계획 기능은 별도 확장이므로 과제 완료율에 가산하지 않는다. 제출 태그 `submission-2026-11-06`·영상·ZIP/PDF는 재작성하지 않았다.

## 계산 기준

원문의 기능 항목·검증 표·제출물에서 79개 확인 단위를 만들었다. 묶여 있는 한 요구는 한 단위로 유지했다. 이미 확인된 범위는 1, 구현 일부 또는 검증 미확보는 0으로 두었다. **71 ÷ 79 = 89.9%, 남은 8 ÷ 79 = 10.1%**다. 작업 시간 비율이나 원문의 배점으로 채점한 점수가 아니다. 이 수치로 과제의 90점 이상 등급·합격·운영 준비를 주장하지 않는다. 같은 기능의 구현 요구와 필수 테스트가 각각 원문에 있어 둘 다 집계되는 경우가 있다.

완료는 연결된 근거의 환경과 주입 범위에 한정한다. 실제 운영 서버·FairPlay·실제 iOS jetsam·물리 ENOSPC까지 모두 통과했다는 의미가 아니다. 원문이 허용한 서버/DRM Mock은 미구현으로 세지 않았다. SwiftData 자체는 지정 기술이 아니지만 B1의 **로컬 DB** 표현은 별도로 남겼다.

| 구분 | 완료 | 남음 | 완료율 | 남은 범위 |
|---|---:|---:|---:|---|
| 공통·핵심 테스트 | 6/6 | 0 | 100.0% | — |
| A 홈·재생·복원 | 16/16 | 0 | 100.0% | — |
| B 오프라인 정합성 | 16/17 | 1 | 94.1% | 로컬 DB 요구와 JSON journal의 차이 |
| C 다운로드·보안·품질 | 15/18 | 3 | 83.3% | VoiceOver 전체 경로, 백그라운드 다운로드 에너지, 통제된 전후 비교 |
| D 장애 주입·재현 | 12/13 | 1 | 92.3% | 전체 시나리오 원격 자동 검증 증빙 |
| 제출물·사용 데이터 | 6/9 | 3 | 66.7% | 10분 재현 확인, 상태도 2개, 샘플 URL·사용조건 |
| **전체** | **71/79** | **8** | **89.9%** | **잔여 10.1%** |


## 남은 8개와 완료 조건

| 항목 | 현재 상태 | 완료 조건 |
|---|---|---|
| B1 로컬 DB | 저장·재실행·충돌 복구는 atomic JSON journal로 구현 | DB 엔진 도입 또는 과제 검토자가 대안 인정. 파일 저장 기능을 전부 미구현으로 보지는 않음 |
| C3 VoiceOver | 탐색/상세·로그인 등 부분 확인 | 현재 앱에서 탐색→상세→재생→자막→중단을 VoiceOver만으로 한 번 이어서 확인하고 기록 |
| C4 다운로드 에너지 | HLS 재생 전력과 앱 다운로드/삭제 I/O 확보 | 백그라운드 다운로드 구간·조건을 명확히 표시한 전력 실험. 기존 I/O 자료를 폐기할 필요는 없음 |
| C4 전후 개선 | 실제 표시 간격 p50/p95 확보 | 같은 기기·네트워크·열 상태·빌드 조건·동작에서 변경 전후 비교. 개선이 없으면 그대로 보고 |
| D 전체 CI 근거 | Core/재생 CI와 별도 네이티브 UI 스크립트 존재 | F06/F09 복합 UI를 포함한 자동 실행 경로/결과를 한곳에 연결. 현재 원격 CI에 해당 UI suite는 없음 |
| README 재현 | 안내·CI 무서명 빌드 있음 | 과거 이력과 현재 실행법을 분리하고 새 환경에서 빌드·서명·실행/Mock 전환을 시간 기록과 함께 확인 |
| Player/Download 상태도 | 상태 모델·테스트·텍스트 정책 있음 | 오류·취소·복구 경로를 코드와 대조한 상태도 2개 추가 |
| 데이터 사용조건 | 공개 샘플 연결 있음 | 제출용 샘플 URL·출처·사용조건·대체 fixture를 README에 명시 |

D 항목은 ‘CI에서 실행 가능한 코드가 없다’는 판단이 아니다. 원문이 요구하는 실행 가능성은 로컬 스크립트로 상당 부분 확보했지만, 전체 원격 성공 증빙까지 완료로 합산하지 않는 보수적 분류다. README도 이미 문서가 없다는 뜻이 아니라 제3자 재현 확인이 남았다는 뜻이다.

## 이미 확보한 대표 근거

- 기능: 홈·검색·프로필, HLS/MP4 재생·탐색·이어보기·자막·복구, 오프라인 다운로드·만료·고정/LRU·로그아웃 격리.
- 메모리: 20회 재생 후 footprint 28.92→36.75 MiB. 5~20회는 36.64~36.86 MiB로 지속 증가가 보이지 않음. Allocations/retained·Leaks는 별도 근거이며 절대 누수 없음의 증명은 아님.
- 성능: HLS 22회 p50 0.742초 / p95 1.269초. 실제 홈 표시 간격 p50 12.503ms / p95 25.005ms. 조건이 다른 기록끼리 개선 수치로 합치지 않음.
- 장애: F01~F10별 자동 검증 범위와 F09·F10 실기기·촬영 확인. Core XCTest 31 + Swift Testing 243, 카오스 3종 각 1,000 seed, iOS 패키지 25개 및 Release 빌드의 제출 코드 CI 근거.
- 제출: 29개 ADR, 6쪽 아키텍처 PDF, 3분 32초 영상, 제출 태그·파일 해시. 촬영 바이너리 SHA의 직접 각인은 미확보이나 별도 원문 필수 점수 항목으로 추가하지 않음.

Firebase 관리자·MP4 직접 업로드·앱 공개 카탈로그 연결, 이번 Mac 압축/예상 안내는 과제 외 확장이다. 서버 자동 압축·실제 FairPlay·운영 다기기 동기화는 이 확장의 현재 완료 범위에도 포함하지 않는다.

## 79개 확인 단위와 근거

구조화 원본: [checklist.json](Measurements/Assignment-Audit-2026-11-06/checklist.json). 코드/테스트와 과거 실행 근거를 대조했다. 이번 관리자 변경 `923d3a6`의 원격 CI에서도 Core 31+243개·3종 1,000 seed·iOS 패키지 25개·Release 빌드가 통과했다. 앱 전체 UI suite를 새로 실행한 것은 아니다. [이번 CI 결과](Measurements/Admin-Compression-2026-11-06/app-ci.json).


### 공통·핵심 테스트

| ID | 요구사항 | 판정 | 근거 |
|---|---|---|---|
| G1 | 대체 가능한 프로토콜과 재현 Mock | 완료 | [ARCHITECTURE_CURRENT.md](ARCHITECTURE_CURRENT.md) · [0001-feature-modules.md](ADR/0001-feature-modules.md) |
| G2 | 취소·화면 이탈·백그라운드·프로필 수명 정의 | 완료 | [0007-playback-lifecycle.md](ADR/0007-playback-lifecycle.md) · [REPORT.md](Measurements/Observer-Lifecycle-2026-11-01/REPORT.md) |
| G3 | 기술 제약과 미확인 범위를 성공으로 포장하지 않고 문서화 | 완료 | [CURRENT_STATUS.md](CURRENT_STATUS.md) · [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| T1 | 상태 유효/무효 전이·중복·cancellation assertion | 완료 | [PlaybackDiagnosticsTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackDiagnosticsTests.swift) · [PlaybackSessionLifecycleTests.swift](../Packages/StreamLabUI/Tests/StreamLabCatalogFeatureTests/PlaybackSessionLifecycleTests.swift) |
| T2 | 격리·409·401·429·100건 복구 assertion | 완료 | [HTTPMutationQueueTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/HTTPMutationQueueTests.swift) · [AssignmentChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/AssignmentChaosTests.swift) · [HTTPAuthenticationTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/HTTPAuthenticationTests.swift) |
| T3 | fake clock로 시간 기반 flaky test 최소화 | 완료 | [RetryClockChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/RetryClockChaosTests.swift) · [MutationRetryTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/MutationRetryTests.swift) |

### A 홈·재생·복원

| ID | 요구사항 | 판정 | 근거 |
|---|---|---|---|
| A1-1 | 성인 2·키즈 1 프로필 및 콘텐츠·진도·다운로드 분리 | 완료 | [REPORT.md](Measurements/Profile-Seek-2026-11-01/REPORT.md) · [AccountLocalDataTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/AccountLocalDataTests.swift) |
| A1-2 | 히어로·추천 레일 5개·이어보기·검색·상세 | 완료 | [PHASE1_MANUAL_QA.md](PHASE1_MANUAL_QA.md) · [CatalogStoreTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/CatalogStoreTests.swift) |
| A1-3 | 2,000개 fixture·커서·중복 제거·이미지 lazy loading | 완료 | [MockCatalogRepositoryTests.swift](../Packages/StreamLabCore/Tests/StreamLabCatalogDataTests/MockCatalogRepositoryTests.swift) · [ArtworkDataCacheTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/ArtworkDataCacheTests.swift) |
| A1-4 | 빠른 검색·스크롤·화면 왕복의 오래된 응답 배제 | 완료 | [CatalogStoreTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/CatalogStoreTests.swift) · [AssignmentChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/AssignmentChaosTests.swift) |
| A2-1 | HLS·일시정지·탐색·10초 이동·다음 회차·연속 재생·복원 | 완료 | [HLS_EPISODES_QA.md](HLS_EPISODES_QA.md) · [PHASE2_REPORT.md](PHASE2_REPORT.md) |
| A2-2 | HLS 음성·자막 조회/선택·복원·대체 | 완료 | [TrackFallbackTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/TrackFallbackTests.swift) · [PlaybackLanguageTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackLanguageTests.swift) · [PHASE2_REPORT.md](PHASE2_REPORT.md) |
| A2-3 | 오류·stall·timeout·media reset의 유한 재시도와 안내 | 완료 | [PlaybackRetryBudgetTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackRetryBudgetTests.swift) · [0019-media-reset-and-bounded-retry.md](ADR/0019-media-reset-and-bounded-retry.md) |
| A2-4 | 플레이어 상태 전이와 불변식 | 완료 | [PlaybackDiagnosticsTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackDiagnosticsTests.swift) |
| A2-5 | TTFF·rebuffer·failure·bitrate 지표 | 완료 | [PlaybackDiagnosticsTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackDiagnosticsTests.swift) · [REPORT.md](Measurements/HLS-2026-10-25/REPORT.md) |
| A3-1 | Mock A→B 25:40 재개 | 완료 | [PlaybackSyncCoordinatorTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackSyncCoordinatorTests.swift) |
| A3-2 | revision으로 과거 진도 거부 | 완료 | [ProgressConflictTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/ProgressConflictTests.swift) |
| A3-3 | 명시적 처음부터 보기 의미 보존 | 완료 | [PlaybackSyncCoordinatorTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackSyncCoordinatorTests.swift) · [ProgressConflictTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/ProgressConflictTests.swift) |
| AM-1 | 준비 중 연속 3회 이탈·Task/observer 정리 | 완료 | [PHASE2_REPORT.md](PHASE2_REPORT.md) · [REPORT.md](Measurements/Observer-Lifecycle-2026-11-01/REPORT.md) |
| AM-2 | seek 중 단절 후 복구·유효 상태/오류 UI | 완료 | [HLS_RECOVERY_QA.md](HLS_RECOVERY_QA.md) · [PlaybackSessionLifecycleTests.swift](../Packages/StreamLabUI/Tests/StreamLabCatalogFeatureTests/PlaybackSessionLifecycleTests.swift) |
| AM-3 | 즉시 프로필 전환 시 이전 진도/최근 시청 차단 | 완료 | [REPORT.md](Measurements/Profile-Seek-2026-11-01/REPORT.md) · [CatalogStoreTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/CatalogStoreTests.swift) |
| AM-4 | 20회 재생/종료 메모리·observer 추세 근거 | 완료 | [MEMORY_EVIDENCE.md](Measurements/C4-2026-10-31/MEMORY_EVIDENCE.md) · [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) · [REPORT.md](Measurements/Observer-Lifecycle-2026-11-01/REPORT.md) |

### B 오프라인 정합성

| ID | 요구사항 | 판정 | 근거 |
|---|---|---|---|
| B1-1 | 찜·이어보기·최근 검색을 로컬 DB에 먼저 기록 | 보완/미확인 | [DurableMutationStore.swift](../Packages/StreamLabCore/Sources/StreamLabPresentation/Sync/DurableMutationStore.swift) · [ARCHITECTURE_CURRENT.md](ARCHITECTURE_CURRENT.md) |
| B1-2 | 강제 종료 후 영속 큐 재처리 | 완료 | [REPORT.md](Measurements/Mutation-Process-2026-11-01/REPORT.md) · [DurableMutationTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/DurableMutationTests.swift) |
| B1-3 | idempotencyKey·sequence·revision | 완료 | [DurableMutationTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/DurableMutationTests.swift) · [MutationConflictTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/MutationConflictTests.swift) |
| B1-4 | 계정/프로필 격리와 로그아웃 삭제 | 완료 | [AccountLocalDataTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/AccountLocalDataTests.swift) · [DurableAuthenticationLogoutTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/DurableAuthenticationLogoutTests.swift) |
| B2-1 | A/B 찜 동시 설정/해제 수렴 | 완료 | [MyListMergeTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/MyListMergeTests.swift) |
| B2-2 | 30초→1,400초 역순 진도 보호 | 완료 | [ProgressConflictTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/ProgressConflictTests.swift) |
| B2-3 | 오프라인 restart 의미 보존 | 완료 | [ProgressConflictTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/ProgressConflictTests.swift) · [DurablePlaybackProgressTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/DurablePlaybackProgressTests.swift) |
| B2-4 | 409 UI 조정·재동기화 | 완료 | [MutationConflictTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/MutationConflictTests.swift) · [HTTPMutationQueueTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/HTTPMutationQueueTests.swift) |
| B2-5 | 429 Retry-After·jitter·상한·취소 | 완료 | [MutationRetryTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/MutationRetryTests.swift) · [RetryClockChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/RetryClockChaosTests.swift) |
| B3-1 | Swift 6 strict 경고 오류 처리·공유 상태 격리 | 완료 | [validation.yml](../.github/workflows/validation.yml) · [CI_VALIDATION.md](CI_VALIDATION.md) |
| B3-2 | 프로필 전환 후 in-flight 응답 차단 | 완료 | [CatalogStoreTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/CatalogStoreTests.swift) · [REPORT.md](Measurements/Profile-Seek-2026-11-01/REPORT.md) |
| B3-3 | 401 8건 single-flight | 완료 | [HTTPAuthenticationTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/HTTPAuthenticationTests.swift) · [REPORT.md](Measurements/HTTP-Boundaries-2026-10-31/REPORT.md) |
| B3-4 | Task 취소·AsyncSequence·MainActor 경계 테스트 | 완료 | [HomeRecentTests.swift](../Packages/StreamLabUI/Tests/StreamLabCatalogFeatureTests/HomeRecentTests.swift) · [PlaybackEntitlementBoundaryTests.swift](../Packages/StreamLabUI/Tests/StreamLabCatalogFeatureTests/PlaybackEntitlementBoundaryTests.swift) · [HomeRecentModel.swift](../Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Home/HomeRecentModel.swift) |
| BI-1 | 범위별 mutation 효과 최대 1회 | 완료 | [MutationChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/MutationChaosTests.swift) · [AssignmentChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/AssignmentChaosTests.swift) |
| BI-2 | UI/응답 프로필 불일치 렌더링 금지 | 완료 | [CatalogStoreTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/CatalogStoreTests.swift) · [AssignmentChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/AssignmentChaosTests.swift) |
| BI-3 | 재실행 후 큐 유실/중복 없이 수렴 | 완료 | [REPORT.md](Measurements/Mutation-Process-2026-11-01/REPORT.md) · [MutationChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/MutationChaosTests.swift) |
| BI-4 | 불가 오류 무한 루프 금지·수동 복구 | 완료 | [RetryClockChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/RetryClockChaosTests.swift) · [PlaybackRetryBudgetTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackRetryBudgetTests.swift) · [CI_VALIDATION.md](CI_VALIDATION.md) |

### C 다운로드·보안·품질

| ID | 요구사항 | 판정 | 근거 |
|---|---|---|---|
| C1-1 | AVAssetDownloadURLSession 및 지원 한계 | 완료 | [0028-offline-hls-downloads.md](ADR/0028-offline-hls-downloads.md) · [DOWNLOADS_QA.md](DOWNLOADS_QA.md) |
| C1-2 | 대기/전송/일시정지/재개/완료/실패/만료/삭제 | 완료 | [OfflineDownloadExpiryTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/OfflineDownloadExpiryTests.swift) · [DOWNLOADS_QA.md](DOWNLOADS_QA.md) |
| C1-3 | 동시 2개·전체 1GB 예산 | 완료 | [OfflineDownloadBudgetTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/OfflineDownloadBudgetTests.swift) · [DOWNLOADS_QA.md](DOWNLOADS_QA.md) |
| C1-4 | 공간 부족·고정 보호·비고정 LRU | 완료 | [OfflineDownloadDiskPressureTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/OfflineDownloadDiskPressureTests.swift) · [REPORT.md](Measurements/Combined-Failures-2026-10-31/REPORT.md) |
| C1-5 | 백그라운드/재실행/취소의 orphan·중복 태스크 방지 | 완료 | [OfflineDownloadFailureTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/OfflineDownloadFailureTests.swift) · [DOWNLOADS_QA.md](DOWNLOADS_QA.md) |
| C1-6 | 오프라인 프로필 권한 교차 차단 | 완료 | [CatalogDownloadTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/CatalogDownloadTests.swift) · [DOWNLOADS_QA.md](DOWNLOADS_QA.md) |
| C2-1 | Keychain 토큰·비밀 평문 로그 방지 | 완료 | [KeychainTokenStoreTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/KeychainTokenStoreTests.swift) · [REPORT.md](Measurements/Diagnostic-Privacy-2026-10-31/REPORT.md) |
| C2-2 | 프로필/로그아웃에서 재생·prefetch·다운로드 무효화 | 완료 | [DurableAuthenticationLogoutTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/DurableAuthenticationLogoutTests.swift) · [REPORT.md](Measurements/Profile-Seek-2026-11-01/REPORT.md) |
| C2-3 | 진단 URL·계정·시청 이력 최소화/마스킹 | 완료 | [REPORT.md](Measurements/Diagnostic-Privacy-2026-10-31/REPORT.md) · [SafeDiagnosticErrorTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/SafeDiagnosticErrorTests.swift) |
| C2-4 | DRM 키·권한·갱신 Mock, 우회 없음 | 완료 | [PlaybackEntitlementTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/PlaybackEntitlementTests.swift) · [REPORT.md](Measurements/Runtime-Entitlement-2026-11-01/REPORT.md) |
| C3-1 | VoiceOver 탐색→상세→재생→자막→중단 전체 독립 조작 | 보완/미확인 | [PHASE1_MANUAL_QA.md](PHASE1_MANUAL_QA.md) · [ASSIGNMENT_PROGRESS.md](ASSIGNMENT_PROGRESS.md) |
| C3-2 | Dynamic Type·고대비/다크·Reduce Motion | 완료 | [ASSIGNMENT_PROGRESS.md](ASSIGNMENT_PROGRESS.md) · [PHASE1_MANUAL_QA.md](PHASE1_MANUAL_QA.md) |
| C3-3 | 44pt 터치·focus order·접근성 label | 완료 | [ASSIGNMENT_PROGRESS.md](ASSIGNMENT_PROGRESS.md) · [PHASE2_REPORT.md](PHASE2_REPORT.md) |
| C4-1 | 2,000 fixture 실제 표시 프레임 p50/p95 | 완료 | [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) · [display-intervals.json](Measurements/C4-2026-10-31/display-intervals.json) |
| C4-2 | 20회 allocation·retained·메모리 추세 | 완료 | [MEMORY_EVIDENCE.md](Measurements/C4-2026-10-31/MEMORY_EVIDENCE.md) · [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) |
| C4-3 | HLS 20회 이상 TTFF p50/p95·네트워크 조건 | 완료 | [REPORT.md](Measurements/HLS-2026-10-25/REPORT.md) |
| C4-4 | 백그라운드 다운로드 에너지/디스크와 캐시 근거 | 보완/미확인 | [REPORT.md](Measurements/C4-2026-10-31/power/REPORT.md) · [REPORT.md](Measurements/C4-2026-10-31/fileio/REPORT.md) · [0028-offline-hls-downloads.md](ADR/0028-offline-hls-downloads.md) |
| C4-5 | 동일 조건의 전후 개선 증거 | 보완/미확인 | [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) |

### D 장애 주입·재현

| ID | 요구사항 | 판정 | 근거 |
|---|---|---|---|
| F01 | 홈 5회 역순 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F02 | 401×8와 refresh 500 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F03 | 오프라인 100건 강제 종료 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F04 | seek 중 A→B | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F05 | 백그라운드 10회/메모리 압박 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F06 | 전송 2개 중 1실패/공간 부족 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F07 | 429/503/timeout 혼합 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F08 | A/B 진도 경쟁 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F09 | 만료 권한/오프라인 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| F10 | 자막·단절·종료 순열 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| DH-1 | 고정 seed·이벤트 순서 재현·fake clock·mock transport | 완료 | [MutationChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/MutationChaosTests.swift) · [RetryClockChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/RetryClockChaosTests.swift) · [AssignmentChaosTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/AssignmentChaosTests.swift) |
| DH-2 | 시나리오별 비동기 race 및 CI 자동 실행 증빙 | 보완/미확인 | [CI_VALIDATION.md](CI_VALIDATION.md) · [REPORT.md](Measurements/Combined-Failures-2026-10-31/REPORT.md) · [check-download-combined-mac.sh](../scripts/check-download-combined-mac.sh) |
| DH-3 | 시나리오 조건·관측 로그·최종 불변식 근거 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) · [REPORT.md](Measurements/Combined-Failures-2026-10-31/REPORT.md) · [CI_VALIDATION.md](CI_VALIDATION.md) |

### 제출물·사용 데이터

| ID | 요구사항 | 판정 | 근거 |
|---|---|---|---|
| E1 | 구동 가능한 앱·비공개 API 없이 Mock 실행 | 완료 | [README.md](../README.md) · [SUBMISSION_RECORD.md](SUBMISSION_RECORD.md) |
| E2 | README만으로 10분 내 제3자 빌드/실행/Mock/테스트 | 보완/미확인 | [README.md](../README.md) · [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md) |
| E3 | 충돌·플레이어 수명·다운로드 정책 ADR 3개 이상 | 완료 | [0021-multi-device-progress-revisions.md](ADR/0021-multi-device-progress-revisions.md) · [0007-playback-lifecycle.md](ADR/0007-playback-lifecycle.md) · [0028-offline-hls-downloads.md](ADR/0028-offline-hls-downloads.md) |
| E4 | Player/Download 상태도 2개, 오류·취소 경로 | 보완/미확인 | [0017-playback-observation-and-qoe.md](ADR/0017-playback-observation-and-qoe.md) · [0028-offline-hls-downloads.md](ADR/0028-offline-hls-downloads.md) · [ARCHITECTURE_CURRENT.md](ARCHITECTURE_CURRENT.md) |
| E5 | 2,000 catalog·3profile·URL Mock·fault fixtures | 완료 | [MockCatalogRepositoryTests.swift](../Packages/StreamLabCore/Tests/StreamLabCatalogDataTests/MockCatalogRepositoryTests.swift) · [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| E6 | unit/integration/UI/concurrency/chaos 테스트 구분 | 완료 | [CI_VALIDATION.md](CI_VALIDATION.md) · [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) · [README.md](../README.md) |
| E7 | TTFF·stall·메모리·frame time 계측 보고서 | 완료 | [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) · [REPORT.md](Measurements/HLS-2026-10-25/REPORT.md) |
| E8 | 5분 이내 영상·장애 2개 주입 | 완료 | [SUBMISSION_RECORD.md](SUBMISSION_RECORD.md) · [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md) |
| DATA1 | 샘플 URL과 사용권 조건을 README에 명시 | 보완/미확인 | [README.md](../README.md) · [FIREBASE_CATALOG.md](FIREBASE_CATALOG.md) |

