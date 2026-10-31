# F01–F10 요구사항별 증빙과 미확인 범위

2026-10-31. PASS는 아래에 명시한 계층/주입 범위에 한정한다. 개별 테스트 통과를 모든 실기기 장애 조합 또는 과제 D 전체 완료로 합산하지 않는다.

| ID | 실제 확인한 근거 | 판정 및 남은 범위 |
|---|---|---|
| F01 홈 5회 역순 | AssignmentChaosTests.fiveHomeRefreshesReverseRepliesKeepLatestAndUniqueCards: 5개 요청이 모두 대기한 뒤 5→4→3→2→1 완료, 매 응답 뒤 최신 hero·레일·카드·이어보기 ID 확인 | 자동 PASS. 중복 제거 결함 재현 후 수정. 고정 완료 순서, sleep 없는 continuation transport |
| F02 401×8 + refresh 500 | HTTPAuthenticationTests.refreshHTTP500TerminatesAllEightWithoutRefreshStorm 및 AuthenticationSessionTests | 로컬 실제 HTTP 자동 PASS. refresh 1회·8개 종료 확인. 운영 서버/TLS는 제외 |
| F03 오프라인 100건/강제 종료 | AssignmentChaosTests.hundredQueuedMutationsRecoverAfterAllServerACKsAreLost: 100개 로컬 envelope, 서버 영속 반영, ACK 전 저장소 재구성, 재전송 후 100 revision/0 pending/값 일치 | 저장소 재열기 자동 PASS. 실제 프로세스 kill 시점·iOS 파일 보호와 동일하다고 주장하지 않음 |
| F04 seek 중 A→B | PlaybackSessionLifecycleTests.testProfileReplacementDuringSeekStopsOldPlayerAndKeepsNewMetadata: isSeeking=true 직후 무효화, B 재생, A player/item 제거 및 B Now Playing 유지. CatalogStoreTests는 이전 프로필 홈 응답 차단 | 플레이어/카탈로그 경계 자동 PASS. seek callback과 실제 프로필 UI 전환 전체를 하나의 UI race로 검증한 것은 아님 |
| F05 background×10 + 메모리 압박 | testTenBackgroundCyclesWithCachePressureReleasePlayer: 10회 foreground 전환과 실제 artwork cache purge, 같은 player 유지·최종 weak model/player 해제 | 주입 자동 PASS. OS 메모리 압박/observer 개수 전체 및 실기기 백그라운드 종료와 구분. 기존 Instruments 메모리/Leaks는 독립 증빙 |
| F06 다운로드 2개/실패/공간 부족 | OfflineDownloadDiskPressureTests·BudgetTests·FailureTests, 기존 UI testHLSTransferDiskPressureCleansConcurrentTasksAndRecovers / testHLSDiskPressureProtectsPinnedAndRetryRecovers | Core 재검증 PASS. 기존 native UI/실기기 공간 부족 증빙 있음. 2개 전송+단일 실패+고정 파일+실제 OS 공간 부족의 한 시나리오 통합은 미완료 |
| F07 429/503/timeout | HTTPMutationQueueTests.mixedStatusesRetryWithSameBodyAndBoundedBudget, RetryClockChaosTests 1000 seed | 실제 loopback HTTP 및 가상 시계 자동 PASS. 요청 envelope 유지/상한/취소 확인 |
| F08 A/B 진도 경쟁 | ProgressConflictTests, PlaybackSyncCoordinatorTests, DomainConflictChaosTests 1000 seed | 서버 Mock revision/explicit restart/재전송 수렴 자동 PASS. 실제 운영 다기기 서버 아님 |
| F09 만료 entitlement + offline | PlaybackEntitlementTests·BoundaryTests, 기존 expired-once UI/실기기 보고는 로컬 번들 오류→재시도 | 만료 차단/키 상태/수동 재시도는 PASS. 네트워크 단절 상태의 실제 저장 HLS와 만료 entitlement 결합은 아직 미확인. 단순 파일 만료와 구분 |
| F10 자막 변경·단절·종료 동시 | PlaybackLanguageTests, PlaybackDiagnosticsTests, 기존 자막/종료/복구 UI 개별 테스트 | 부분 근거만 존재. 세 이벤트를 동일 재생 시도에서 순서 제어하여 주입하는 통합 하네스는 미완료. 개별 PASS를 F10 PASS로 처리하지 않음 |

## 재현

```bash
bash scripts/check-assignment-core-mac.sh
bash scripts/check-playback-session-lifecycle-mac.sh
```

Core wrapper는 loopback HTTP fixture와 고유 더미 Keychain 테스트를 시작/정리하고, Core 전체 결과 및 F01/F03 완료·3종 1000 seed 표식을 요구한다. 서버 fixture는 임시 로컬 서버다. 임의 서비스나 실제 계정 토큰에 연결하지 않는다. `STREAMLAB_CHAOS_SEED=42`로 기존 세 카오스 suite의 특정 seed를 재생할 수 있으며 F01 완료 순서는 항상 5→4→3→2→1이다.

CI는 위 명령을 실행하고 실패 시 로그를 artifact로 보존한다. F10 등 미구현 하네스는 이름만 채워 PASS로 만들지 않는다. [이번 결과](Measurements/Chaos-Mapping-2026-10-31/REPORT.md).

## 실기기 순서 — 필요한 확인만

이번 코드 변경의 사용자 확인은 **홈 진입 → 새로고침 5회 → 레일/이어보기 → 상세 진입**이면 충분하다. 실제 역순 응답은 자동 테스트가 결정적으로 주입하므로 손으로 정확한 타이밍을 맞추지 않는다. 같은 작품이 서로 다른 추천 레일에 나오는 것은 정상이며 같은 레일 내부 중복 ID를 제거한다.

추가 복합 검증은 아래 순서로 진행하되 이전 성공 검증 전체를 다시 요구하지 않는다.

1. F09: Wi-Fi에서 HLS 샘플 다운로드 완료 → Xcode Debug의 expired-once 인수만 켜고 새 실행 → 비행기 모드 및 Wi-Fi도 끈 상태 → 다운로드 목록에서 해당 영상 재생. **첫 시도**가 만료 안내로 차단되는지 확인하고 취소한다. 이번에는 ‘재시도’로 실제 라이선스 갱신을 검증하지 않는다(로컬 Mock은 다음 요청에 새 grant를 발급한다). 종료 후 인수를 끄고 연결을 복구한다.
2. F05: 일반 실행에서 HLS 재생 중 홈 화면 이동/앱 복귀 10회, 복귀 시 시간/컨트롤 확인 후 닫기. OS 메모리 압박은 이 수동 동작만으로 재현되지 않으므로 메모리 부족을 만들려고 기기를 채우지 않는다. 새 Instruments trace는 현재 요청하지 않는다.
3. F06/F10: 현재 테스트로 동시 주입이 충분하지 않다. 수동 조작을 반복해 ‘동시’ 발생을 추정하지 말고 전용 통합 하네스 보강 후 검증한다. 실제 기기 저장 공간을 채울 필요는 없다.
