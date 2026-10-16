#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/regression-fixes-XXXXXX")" || exit 2
core_dir="$(mktemp -d /private/tmp/streamlab-regression-fixes-core-XXXXXX)" || exit 2
echo "Running deterministic Core tests. Log: $run_dir/core.log"
swift test --package-path Packages/StreamLabCore --scratch-path "$core_dir" > "$run_dir/core.log" 2>&1
core_result=$?
if [ "$core_result" -eq 0 ]; then
  echo 'PASS core exit=0' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL core exit=$core_result" | tee -a "$run_dir/RESULTS.txt"
  tail -n 35 "$run_dir/core.log"
  echo "Results: $run_dir/RESULTS.txt"
  exit "$core_result"
fi
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v: v.get("state") != "Booted"); print(a[0]["udid"] if a else "")')"
fi
if [ -z "$simulator_id" ]; then
  echo 'NOT TESTED: no available iPhone simulator' | tee -a "$run_dir/RESULTS.txt"
  exit 2
fi
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator_id"; } > "$run_dir/environment.txt" 2>&1
build_dir="$(mktemp -d /private/tmp/streamlab-regression-fixes-XXXXXX)" || exit 2
echo "Build directory: $build_dir" >> "$run_dir/environment.txt"
echo "Running source-list, My List and maximum Dynamic Type regression tests. Log: $run_dir/ui-tests.log"
qoe_start="$(date '+%Y-%m-%d %H:%M:%S')"
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$build_dir/DerivedData" -resultBundlePath "$run_dir/UITests.xcresult" \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 900 -maximum-test-execution-time-allowance 900 \
  -only-testing:StreamLabUITests/StreamLabUITests/testMyListPersistsAndIsolatesProfiles \
  -only-testing:StreamLabUITests/StreamLabUITests/testPlaybackLargeTextControls \
  -only-testing:StreamLabUITests/StreamLabUITests/testMissingSubtitleFallsBackAndRestoresWithoutChangingOtherProfile \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO test > "$run_dir/ui-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ]; then
  # All three regression cases must execute and pass.
  if ! grep -Eq "testPlaybackLargeTextControls.*passed" "$run_dir/ui-tests.log" ||
     ! grep -Eq "testMyListPersistsAndIsolatesProfiles.*passed" "$run_dir/ui-tests.log" ||
     ! grep -Eq "testMissingSubtitleFallsBackAndRestoresWithoutChangingOtherProfile.*passed" "$run_dir/ui-tests.log"; then
    echo 'FAIL required regression tests did not all pass (check skipped tests/environment)' >> "$run_dir/RESULTS.txt"
    result=1
  fi
fi
# App-process logs are collected separately; limit to this test run.
xcrun simctl spawn "$simulator_id" log show --start "$qoe_start" --style compact \
  --predicate 'subsystem == "com.example.streamlab.demo" AND category == "PlaybackQoE"' \
  > "$run_dir/qoe.log" 2>&1
diagnostics_result=$?
echo "QoE log collection exit=$diagnostics_result" >> "$run_dir/environment.txt"
if [ "$result" -eq 0 ]; then
  echo 'PASS regression-fixes exit=0' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL regression-fixes exit=$result" | tee -a "$run_dir/RESULTS.txt"
fi
if [ "$diagnostics_result" -eq 0 ] && grep -q 'summary attempt=' "$run_dir/qoe.log"; then
  if grep -Eq 'invalid_transitions=[1-9][0-9]*|accepted=false' "$run_dir/qoe.log"; then
    echo 'FAIL observed playback transition invariant' >> "$run_dir/RESULTS.txt"
    result=1
  else
    echo 'PASS QoE summary collected; no rejected transitions observed (not a performance threshold assertion)' >> "$run_dir/RESULTS.txt"
  fi
else
  echo 'NOT TESTED: QoE summary log unavailable; inspect Xcode console' >> "$run_dir/RESULTS.txt"
fi
echo 'NOT TESTED: native unplayable-track/audio-role fallback, real-device HLS QoE, actual OS media reset, PiP and full regression' >> "$run_dir/RESULTS.txt"
tail -n 35 "$run_dir/ui-tests.log"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
