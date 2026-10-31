#!/usr/bin/env bash
# F06 native transfers and F09 downloaded media with unavailable license renewal.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/download-combined-XXXXXX")" || exit 2
build_dir="${STREAMLAB_COMBINED_BUILD_DIR:-}"
if [ -z "$build_dir" ]; then
  build_dir="$(mktemp -d /private/tmp/streamlab-download-combined-XXXXXX)" || exit 2
fi
simulator_id="${SIMULATOR_ID:-}"
# Device-wide budgets include other accounts' pinned files. Use a fresh simulator
# by default, never erase an existing user's simulator to make this test pass.
created_simulator=""
if [ -z "$simulator_id" ]; then
  fixture="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[(k,v) for k,g in d["devices"].items() for v in g if v.get("isAvailable") and "iPhone" in v["name"]]; print(a[0][1]["deviceTypeIdentifier"]+" "+a[0][0] if a else "")')"
  if [ -n "$fixture" ]; then
    read -r device_type runtime <<< "$fixture"
    simulator_id="$(xcrun simctl create "StreamLab-Combined-$$" "$device_type" "$runtime")" || exit 2
    created_simulator="$simulator_id"
    trap 'xcrun simctl shutdown "$created_simulator" >/dev/null 2>&1 || true; xcrun simctl delete "$created_simulator" >/dev/null 2>&1 || true' EXIT
  fi
fi
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator_id"; echo "Build directory: $build_dir"; } > "$run_dir/environment.txt" 2>&1
if [ -z "$simulator_id" ]; then
  echo 'FAIL no available iPhone simulator' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
TEST_RUNNER_STREAMLAB_TEST_DOWNLOADS=1 xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$build_dir/DerivedData" \
  -resultBundlePath "$run_dir/UITests.xcresult" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 360 -maximum-test-execution-time-allowance 360 \
  -only-testing:StreamLabUITests/StreamLabUITests/testF06ConcurrentFailureDiskPressurePreservesPinnedAndRecovers \
  -only-testing:StreamLabUITests/StreamLabUITests/testF09DownloadedHLSExpiredOfflineGrantBlocksRetryAndCloses \
  -only-testing:StreamLabUITests/StreamLabUITests/testRealHLSDownloadRelaunchPlaybackAndDelete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$run_dir/ui-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ] &&
   grep -Eq 'testF06ConcurrentFailureDiskPressurePreservesPinnedAndRecovers.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testF09DownloadedHLSExpiredOfflineGrantBlocksRetryAndCloses.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testRealHLSDownloadRelaunchPlaybackAndDelete.*passed' "$run_dir/ui-tests.log" &&
   grep -q 'Executed 3 tests, with 0 failures' "$run_dir/ui-tests.log"; then
  echo 'PASS F06 native failure/disk/pin recovery, F09 license boundary and normal downloaded playback regression' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL combined download UI exit=$result; three executed tests must pass" | tee "$run_dir/RESULTS.txt"; result=1
fi
echo 'INJECTED: capacity=0, one native task cancellation, cached expired entitlement and unavailable renewal. NOT TESTED: physical ENOSPC, airplane mode, production DRM.' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
