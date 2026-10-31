# F01–F10 요구사항별 증빙과 미확인 범위

2026-10-31. PASS는 아래에 명시한 계층/주입 범위에 한정한다. 개별 테스트 통과를 모든 실기기 장애 조합 또는 과제 D 전체 완료로 합산하지 않는다.

| ID | 실제 확인한 근거 | 판정 및 남은 범위 |
|---|---|---|
| F01 홈 5회 역순 | AssignmentChaosTests.fiveHomeRefreshesReverseRepliesKeepLatestAndUniqueCards: 5개 요청이 모두 대기한 뒤 5→4→3→2→1 완료, 매 응답 뒤 최신 hero·레일·카드·이어보기 ID 확인 | 자동 PASS. 중복 제거 결함 재현 후 수정. 고정 완료 순서, sleep 없는 continuation transport |
| F02 401×8 + refresh 500 | HTTPAuthenticationTests.refreshHTTP500TerminatesAllEightWithoutRefreshStorm 및 AuthenticationSessionTests | 로컬 실제 HTTP 자동 PASS. refresh 1회·8개 종료 확인. 운영 서버/TLS는 제외 |
| F03 오프라인 100건/강제 종료 | AssignmentChaosTests.hundredQueuedMutationsRecoverAfterAllServerACKsAreLost: 100개 로컬 envelope, 서버 영속 반영, ACK 전 저장소 재구성, 재전송 후 100 revision/0 pending/값 일치 | 저장소 재열기 자동 PASS. 실제 프로세스 kill 시점·iOS 파일 보호와 동일하다고 주장하지 않음 |
| F04 seek 중 A→B | PlaybackSessionLifecycleTests.testProfileReplacementDuringSeekStopsOldPlayerAndKeepsNewMetadata: isSeeking=true 직후 무효화, B 재생, A player/item 제거 및 B Now Playing 유지. CatalogStoreTests는 이전 프로필 홈 응답 차단 | 플레이어/카탈로그 경계 자동 PASS. seek callback과 실제 프로필 UI 전환 전체를 하나의 UI race로 검증한 것은 아님 |
| F05 background×10 + 메모리 압박 | testTenBackgroundCyclesWithCachePressureReleaseModelAndStopPlayer: 10회 foreground 전환과 실제 artwork cache purge, 같은 player 유지·최종 weak model 해제·player item 제거/정지·Now Playing 해제 | 주입 자동 PASS. AVPlayer 자체의 OS 참조 해제 시점은 미확인. OS 메모리 압박/observer 개수 전체 및 실기기 백그라운드 종료와 구분. 기존 Instruments 메모리/Leaks는 독립 증빙 |
| F06 다운로드 2개/실패/공간 부족 | OfflineDownloadDiskPressureTests·BudgetTests·FailureTests, 기존 UI testHLSTransferDiskPressureCleansConcurrentTasksAndRecovers / testHLSDiskPressureProtectsPinnedAndRetryRecovers | Core 재검증 PASS. 기존 native UI/실기기 공간 부족 증빙 있음. 새 `testF06ConcurrentFailureDiskPressurePreservesPinnedAndRecovers`는 2개 실제 전송의 단일 실패+공간 압박 정리 후, 재다운로드·고정·공간 압박 재시도·복구를 한 시나리오로 연결한다. 실제 ENOSPC는 제외; 실행 결과는 복합 검증 보고서 참고 |
| F07 429/503/timeout | HTTPMutationQueueTests.mixedStatusesRetryWithSameBodyAndBoundedBudget, RetryClockChaosTests 1000 seed | 실제 loopback HTTP 및 가상 시계 자동 PASS. 요청 envelope 유지/상한/취소 확인 |
| F08 A/B 진도 경쟁 | ProgressConflictTests, PlaybackSyncCoordinatorTests, DomainConflictChaosTests 1000 seed | 서버 Mock revision/explicit restart/재전송 수렴 자동 PASS. 실제 운영 다기기 서버 아님 |
| F09 만료 entitlement + offline | PlaybackEntitlementTests·BoundaryTests, 기존 expired-once UI/실기기 보고는 로컬 번들 오류→재시도 | 만료 차단/키 상태/수동 재시도는 PASS. 새 `testF09DownloadedHLSExpiredOfflineGrantBlocksRetryAndCloses`는 실제 다운로드 완료 파일과 만료 grant/갱신 불가를 연결한다. 패키지 테스트는 player 미생성 및 재시도 상한도 검증한다. 갱신 불가는 Mock 주입이며 실제 비행기 모드/운영 DRM과 구분 |
| F10 자막 변경·단절·종료 동시 | PlaybackLanguageTests, PlaybackDiagnosticsTests, 기존 자막/종료/복구 UI 개별 테스트 | 6개 처리 순서 자동 PASS. `testSubtitleNetworkFailureAndEndPermutationsCannotResurrectClosedPlayback`는 동일 AVPlayer에서 자막 선택·네트워크 오류를 담은 실패 알림·종료 알림 6개 순서를 주입한다. 종료/실패 후 중지·새 재생·옛 알림 무시와 현재 아이템 단독 실패도 확인한다. 실제 네트워크 차단 타이밍은 주입하지 않음 |

## 재현

```bash
bash scripts/check-assignment-core-mac.sh
bash scripts/check-playback-session-lifecycle-mac.sh
```

Core wrapper는 loopback HTTP fixture와 고유 더미 Keychain 테스트를 시작/정리하고, Core 전체 결과 및 F01/F03 완료·3종 1000 seed 표식을 요구한다. 서버 fixture는 임시 로컬 서버다. 임의 서비스나 실제 계정 토큰에 연결하지 않는다. `STREAMLAB_CHAOS_SEED=42`로 기존 세 카오스 suite의 특정 seed를 재생할 수 있으며 F01 완료 순서는 항상 5→4→3→2→1이다.

CI는 위 명령을 실행하고 실패 시 로그를 artifact로 보존한다. 네이티브 다운로드 복합 검증은 `bash scripts/check-download-combined-mac.sh`로 별도 실행한다(외부 Apple HLS 접속 필요). [이번 결과](Measurements/Chaos-Mapping-2026-10-31/REPORT.md).

## 실기기 순서 — 필요한 확인만

이전 F01 변경의 사용자 확인은 **홈 진입 → 새로고침 5회 → 레일/이어보기 → 상세 진입**이다. 실제 역순 응답은 자동 테스트가 결정적으로 주입하므로 손으로 정확한 타이밍을 맞추지 않는다. 같은 작품이 서로 다른 추천 레일에 나오는 것은 정상이며 같은 레일 내부 중복 ID를 제거한다.

추가 실기기는 다음만 확인한다.

1. F09: Wi-Fi에서 HLS 샘플 다운로드 완료 → Xcode Edit Scheme → Run(Debug) → Arguments Passed On Launch에 `--ui-test-entitlement-offline-expired`만 추가 → 새 실행 → 비행기 모드와 Wi-Fi 끄기 → 다운로드 목록에서 재생. 화면 안에 만료 안내가 나오고 ‘재생 다시 시도’ 후에는 갱신 불가와 남은 2회가 표시돼야 한다. 닫기(X)로 목록으로 돌아가도 파일은 유지되어야 한다. 인수를 제거하고 다시 실행한 뒤 기존 오프라인 재생·시간 갱신을 확인한다. 이 인수는 만료/갱신 불가 Mock으로 운영 DRM 시험이 아니다.
2. F10: 정상 HLS 재생 → 자막 변경 → Wi-Fi/셀룰러 끄기 → 종료/오류 화면에서 닫기 → 연결 복구 후 새 재생. 이전 오류나 종료가 새 재생을 중단시키지 않아야 한다. 버퍼가 남아 있으면 끊자마자 실패하지 않는 것이 정상이다. 동시 순서 6개는 자동 주입으로 확인하며 손으로 맞출 필요 없다.
3. F06: 자동 검증은 0 용량 읽기와 네이티브 취소를 주입하므로 실기기를 실제로 채우지 않는다. 1GB 정책상 두 500MB 예약과 양수 크기의 고정 완료 파일은 동시 수용할 수 없어, 고정 보호는 같은 시나리오의 복구 단계에서 검증한다.

[복합 검증·원격 CI 결과](Measurements/Combined-Failures-2026-10-31/REPORT.md).
