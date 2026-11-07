# 과제 원문 기준 완료·잔여 점검 — 2026-11-06

**78/79 확인 단위 완료(98.7%), 1/79 실기기 검증 대기(1.3%)다.** 최초 점검의 8개 잔여 중 로컬 DB·전체 자동 CI 근거·README 재현·상태도·샘플 사용조건 5개를 보완했다. VoiceOver 전체 경로는 사용자 실기기 확인으로 완료했다. 백그라운드 다운로드 전력 측정을 완료했다. 통제된 프레임 비교가 남았다.

앱 기준은 `9a4d395`다. [원격 CI](https://github.com/KyungHoon416/streamlab-ios/actions/runs/42239749042)의 네 job이 모두 성공했다. Core·재생·앱 UI는 attempt 1, native 다운로드는 실패 후 한 번 재실행한 attempt 2의 결과다. 원본 `Netflix_iOS_과제.docx` SHA-256: `5f2227f658aa52f16a2429c68c4ee3b729fc8e49c17883441cb455622d058250`. 최초 71/79 판정은 [이전 점검표](Measurements/Assignment-Audit-2026-11-06/checklist-before-final-gaps.json)에 보존한다. 관리자 확장 기능은 과제 완료율에 가산하지 않는다.

## 계산 기준

원문의 기능·검증·제출물에서 만든 동일한 79개 단위를 유지했다. 완료는 1, 일부 구현 또는 근거 미확보는 0이다. **78 ÷ 79 = 98.7%, 1 ÷ 79 = 1.3%**이며 배점·합격 점수·작업 시간·운영 준비 비율이 아니다. 원문이 허용한 서버/DRM Mock은 미구현으로 세지 않되 실제 운영 서버·FairPlay·jetsam·물리 ENOSPC까지 확인했다고 확대하지 않는다.

| 구분 | 완료 | 남음 | 완료율 | 남은 범위 |
|---|---:|---:|---:|---|
| 공통·핵심 테스트 | 6/6 | 0 | 100.0% | — |
| A 홈·재생·복원 | 16/16 | 0 | 100.0% | — |
| B 오프라인 정합성 | 17/17 | 0 | 100.0% | — |
| C 다운로드·보안·품질 | 17/18 | 1 | 94.4% | 동일 조건 C/PV 비교 |
| D 장애 주입·재현 | 13/13 | 0 | 100.0% | — |
| 제출물·사용 데이터 | 9/9 | 0 | 100.0% | — |
| **전체** | **78/79** | **1** | **98.7%** | **잔여 1.3%** |

## 처음 남았던 8개 처리 결과

| 항목 | 결과 | 근거 / 남은 일 |
|---|---|---|
| B1 로컬 DB | 완료 | SQLite 트랜잭션, JSON 이전, 중간 실패 롤백·복구 자동 검증 |
| C3 VoiceOver | 완료 | iPhone 15 Pro에서 F10 샘플 전체 경로 PASS. 음성 안내·위치 조절·상세 복귀 확인 |
| C4 다운로드 전력 | 완료 | power-3에서 백그라운드 전송 16.932초 구간의 앱 전력 영향 확인 |
| C4 전후 비교 | 실기기 대기 | 4개 완주 구간 비교. PV2 retry2가 Serious로 기록되어 Nominal 조건 반복 검증 대기 |
| D 전체 자동 CI | 완료 | Core/재생/앱 UI 9개/네이티브 HLS 3개를 동일 커밋에서 원격 실행 |
| README 10분 재현 | 완료 | 사전 설치된 Xcode/runtime 조건에서 새 runner·시뮬레이터 빌드/Mock 로그인/재생 smoke 424초 |
| Player/Download 상태도 | 완료 | 코드와 대조한 Mermaid 2개 및 PDF 그림 |
| 데이터 사용조건 | 완료 | URL·출처·사용 범위·번들 대체 fixture를 README에 명시 |

[이번 구현·검증 결과](Measurements/Final-Gaps-2026-11-06/REPORT.md) · [남은 실기기 순서와 파일명](FINAL_DEVICE_QA.md).

## 이미 확보한 대표 근거

- 현재 자동 검증: Core XCTest 31 + Swift Testing 247, 카오스 3종 각 1,000시드, 100건 SIGKILL 2회 복구, iOS 재생 25개, 앱 UI 9개, 네이티브 HLS UI 3개 및 Release 빌드.
- 과거 실기기: HLS 22회 p50 0.742초 / p95 1.269초. 반복 재생 footprint 28.92→36.75MiB, 5~20회 36.64~36.86MiB. 모든 빌드의 누수 부재를 뜻하지 않는다.
- 실제 홈 표시 간격 p50 12.503ms / p95 25.005ms를 확보했다. 조건이 다른 이전 기록을 성능 개선 증명으로 합치지 않는다.
- 현재 아키텍처 PDF는 14쪽 그림 중심 문서다. 기존 제출 태그·3분 32초 영상·ZIP은 당시 버전으로 보존하며 현재 앱 코드가 촬영에 포함됐다고 표시하지 않는다.

## 79개 확인 단위와 근거

구조화 원본: [checklist.json](Measurements/Assignment-Audit-2026-11-06/checklist.json). 각 완료는 연결한 근거의 환경·주입 범위에 한정한다.

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
| B1-1 | 찜·이어보기·최근 검색을 로컬 DB에 먼저 기록 | 완료 | [0030-sqlite-local-projection-outbox.md](ADR/0030-sqlite-local-projection-outbox.md) · [SQLiteMigrationTests.swift](../Packages/StreamLabCore/Tests/StreamLabPresentationTests/SQLiteMigrationTests.swift) · [REPORT.md](Measurements/Final-Gaps-2026-11-06/REPORT.md) |
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
| C3-1 | VoiceOver 탐색→상세→재생→자막→중단 전체 독립 조작 | 완료 | [PHASE1_MANUAL_QA.md](PHASE1_MANUAL_QA.md) · [ASSIGNMENT_PROGRESS.md](ASSIGNMENT_PROGRESS.md) · [FINAL_DEVICE_QA.md](FINAL_DEVICE_QA.md) |
| C3-2 | Dynamic Type·고대비/다크·Reduce Motion | 완료 | [ASSIGNMENT_PROGRESS.md](ASSIGNMENT_PROGRESS.md) · [PHASE1_MANUAL_QA.md](PHASE1_MANUAL_QA.md) |
| C3-3 | 44pt 터치·focus order·접근성 label | 완료 | [ASSIGNMENT_PROGRESS.md](ASSIGNMENT_PROGRESS.md) · [PHASE2_REPORT.md](PHASE2_REPORT.md) |
| C4-1 | 2,000 fixture 실제 표시 프레임 p50/p95 | 완료 | [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) · [display-intervals.json](Measurements/C4-2026-10-31/display-intervals.json) |
| C4-2 | 20회 allocation·retained·메모리 추세 | 완료 | [MEMORY_EVIDENCE.md](Measurements/C4-2026-10-31/MEMORY_EVIDENCE.md) · [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) |
| C4-3 | HLS 20회 이상 TTFF p50/p95·네트워크 조건 | 완료 | [REPORT.md](Measurements/HLS-2026-10-25/REPORT.md) |
| C4-4 | 백그라운드 다운로드 에너지/디스크와 캐시 근거 | 완료 | [다운로드 전력](Measurements/C4-2026-10-31/REPORT.md) · [REPORT.md](Measurements/C4-2026-10-31/power/REPORT.md) · [REPORT.md](Measurements/C4-2026-10-31/fileio/REPORT.md) · [0028-offline-hls-downloads.md](ADR/0028-offline-hls-downloads.md) · [FINAL_DEVICE_QA.md](FINAL_DEVICE_QA.md) |
| C4-5 | 동일 조건의 전후 개선 증거 | 실기기 검증 대기 | [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) · [FINAL_DEVICE_QA.md](FINAL_DEVICE_QA.md) |

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
| DH-2 | 시나리오별 비동기 race 및 CI 자동 실행 증빙 | 완료 | [CI_VALIDATION.md](CI_VALIDATION.md) · [REPORT.md](Measurements/Final-Gaps-2026-11-06/REPORT.md) |
| DH-3 | 시나리오 조건·관측 로그·최종 불변식 근거 | 완료 | [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) · [REPORT.md](Measurements/Combined-Failures-2026-10-31/REPORT.md) · [CI_VALIDATION.md](CI_VALIDATION.md) |

### 제출물·사용 데이터

| ID | 요구사항 | 판정 | 근거 |
|---|---|---|---|
| E1 | 구동 가능한 앱·비공개 API 없이 Mock 실행 | 완료 | [README.md](../README.md) · [SUBMISSION_RECORD.md](SUBMISSION_RECORD.md) |
| E2 | README만으로 10분 내 제3자 빌드/실행/Mock/테스트 | 완료 | [README.md](../README.md) · [check-submission-app-mac.sh](../scripts/check-submission-app-mac.sh) · [REPORT.md](Measurements/Final-Gaps-2026-11-06/REPORT.md) |
| E3 | 충돌·플레이어 수명·다운로드 정책 ADR 3개 이상 | 완료 | [0021-multi-device-progress-revisions.md](ADR/0021-multi-device-progress-revisions.md) · [0007-playback-lifecycle.md](ADR/0007-playback-lifecycle.md) · [0028-offline-hls-downloads.md](ADR/0028-offline-hls-downloads.md) |
| E4 | Player/Download 상태도 2개, 오류·취소 경로 | 완료 | [PLAYER.md](States/PLAYER.md) · [DOWNLOAD.md](States/DOWNLOAD.md) · [streamlab-architecture-ko.pdf](Architecture/streamlab-architecture-ko.pdf) · [REPORT.md](Measurements/Final-Gaps-2026-11-06/REPORT.md) |
| E5 | 2,000 catalog·3profile·URL Mock·fault fixtures | 완료 | [MockCatalogRepositoryTests.swift](../Packages/StreamLabCore/Tests/StreamLabCatalogDataTests/MockCatalogRepositoryTests.swift) · [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) |
| E6 | unit/integration/UI/concurrency/chaos 테스트 구분 | 완료 | [CI_VALIDATION.md](CI_VALIDATION.md) · [CHAOS_ACCEPTANCE.md](CHAOS_ACCEPTANCE.md) · [README.md](../README.md) |
| E7 | TTFF·stall·메모리·frame time 계측 보고서 | 완료 | [REPORT.md](Measurements/C4-2026-10-31/REPORT.md) · [REPORT.md](Measurements/HLS-2026-10-25/REPORT.md) |
| E8 | 5분 이내 영상·장애 2개 주입 | 완료 | [SUBMISSION_RECORD.md](SUBMISSION_RECORD.md) · [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md) |
| DATA1 | 샘플 URL과 사용권 조건을 README에 명시 | 완료 | [README.md](../README.md) · [REPORT.md](Measurements/Final-Gaps-2026-11-06/REPORT.md) |
