# HLS PiP 수동 검증

현재 모든 실제 PiP 항목: NOT TESTED. 시뮬레이터와 실제 기기 결과를 구분한다.
Apple의 supported/possible이 false인 환경은 미지원/준비 대기로 기록하며 PASS로 처리하지 않는다.

## 먼저 빌드와 기존 동작 확인

```bash
cd ~/Desktop/streamlab-ios &&
git pull --ff-only --no-rebase origin main &&
caffeinate -i bash scripts/check-pip-mac.sh
```

이 스크립트는 기존 자막 이동/일반 백그라운드 일시정지/이어보기를 검증한다.
실제 PiP 테스트는 아니다. RESULTS.txt, ui-tests.log, UITests.xcresult를 저장한다.

## 수동 확인

1. 일반 앱 실행 → adult-a → 상세 → 데모 재생 → 소스에서 HLS 오디오 비교 선택.
2. 실제 영상/오디오가 재생되면 상단 작은 화면(PiP) 버튼을 누른다.
3. 작은 창이 표시되는지 확인하고 시스템 홈으로 이동한다. 영상·소리가 계속 진행되어야 한다.
4. 작은 창에서 일시정지/재생을 각각 실행한다. 시간 숫자뿐 아니라 영상·소리를 확인한다.
5. 작은 창의 앱 복귀 버튼을 누른다. 같은 영상/위치/음성 선택의 플레이어로 돌아와야 한다.
6. 다시 PiP를 시작하고 작은 창 X를 누른다. 뒤에서 소리가 없어야 한다.
   앱에 돌아오면 일시정지 상태이고 재생 버튼으로 다시 시작할 수 있어야 한다.
7. PiP 중 앱으로 전환해 플레이어의 닫기를 누른다. 작은 창과 오디오 모두 종료되어야 한다.
8. adult-b로 전환한다. A의 위치/음성 설정이 B에 노출되지 않아야 한다.
9. HLS 자막의 비 Forced 트랙을 선택해 실제 cue 구간에서 PiP 자막을 확인한다.
   DVS 등 선택한 음성도 유지되어야 한다. 없는 트랙은 NOT TESTED.
10. PiP 없이 재생 중 홈으로 이동하면 일시정지해야 한다. 돌아와도 자동 재생하지 않아야 한다.

| 항목 | 결과 |
|---|---|
| HLS PiP 시작 / 홈에서 지속 재생 | NOT TESTED |
| 작은 창 재생·정지 / 앱 복귀 | NOT TESTED |
| PiP X / 앱 닫기 후 오디오 종료 | NOT TESTED |
| 프로필별 위치·언어 분리 | NOT TESTED |
| HLS native 자막 / 오디오 선택 유지 | NOT TESTED |
| PiP 없이 백그라운드 일시정지 | NOT TESTED |
| 20회 PiP 진입·종료 후 메모리 | NOT TESTED |

오프라인 데모와 데모 에피소드는 PiP 비활성화가 현재 의도된 범위다.
복귀 시 원래 플레이어를 유지하므로 PiP 시작만으로 앱 내 홈/검색으로 이동하지 않는다.
PiP 버튼은 지원 여부와 관계없이 표시한다. 미지원이면 비활성화하고 해당 안내를 표시한다.
시뮬레이터에서 미지원 안내가 나오거나 계속 준비 중이면 모델/OS와 화면을 기록하고 실제 기기에서도 확인한다.
버튼 자체가 없으면 최신 소스를 빌드한 앱인지 먼저 확인한다. 홈으로 나가기만 해서는 자동 PiP가 시작되지 않는다.

## Automatic PiP on device — 2026-10-16 (supersedes explicit-only behavior)

The app now enables AVKit automatic PiP for actively playing HLS. On scene inactivity,
it allows up to two seconds for the system's willStart callback before pausing if
PiP did not start. It never calls startPictureInPicture to force automatic entry.
Inactive/active changes without PiP (for example Control Center) eventually pause;
foreground return does not resume automatically. A started transition retains the
existing ten-second failure watchdog. Stop/source changes cancel pending handoffs.

Manual validation (all new behavior NOT TESTED until device results are provided):
1. Record commit, iPhone model and iOS version. Enable automatic PiP in system settings.
2. Play an HLS video, wait until playing/PiP available, then go directly Home without
   tapping PiP. Confirm a floating video and continuous audio/video.
3. Restore the app from PiP; close the player and confirm audio stops.
4. Repeat automatic entry, then close the floating window with X; confirm audio stops.
5. Pause before going Home; confirm no automatic playback starts.
6. Disable system automatic PiP and repeat: no forced PiP, playback pauses within the
   short handoff allowance. Re-enable afterward. Check PiP button entry still works.
7. Open and close Control Center while playing; check that no invisible audio persists
   without a player/PiP, and paused playback does not restart by itself.

Simulator fallback regression: `caffeinate -i bash scripts/check-pip-mac.sh`.
This script does not certify native automatic PiP. Structure validation PASS only.
