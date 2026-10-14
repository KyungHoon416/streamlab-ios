#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/ui-recovery-XXXXXX")" || exit 2
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v: v.get("state") != "Booted"); print(a[0]["udid"] if a else "")')"
fi
if [ -z "$simulator_id" ]; then
  echo 'NOT TESTED: no available iPhone simulator' | tee -a "$run_dir/RESULTS.txt"
  exit 2
fi
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator_id"; } > "$run_dir/environment.txt" 2>&1
build_dir="$(mktemp -d /private/tmp/streamlab-ui-recovery-XXXXXX)" || exit 2
echo "Build directory: $build_dir" >> "$run_dir/environment.txt"
echo "Running two UI regression tests. Log: $run_dir/ui-tests.log"
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$build_dir/DerivedData" -resultBundlePath "$run_dir/UITests.xcresult" \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 900 -maximum-test-execution-time-allowance 900 \
  -only-testing:StreamLabUITests/StreamLabUITests/testSubtitleSelectionSeekingAndRestoration \
  -only-testing:StreamLabUITests/StreamLabUITests/testReleaseNavigationSoak \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO test > "$run_dir/ui-tests.log" 2>&1
result=$?
# App-process orientation messages are not guaranteed to appear in XCTest output.
xcrun simctl spawn "$simulator_id" log show --last 15m --style compact \
  --predicate 'subsystem == "com.example.streamlab.demo" AND category == "PlaybackOrientation"' \
  > "$run_dir/orientation.log" 2>&1
diagnostics_result=$?
echo "Orientation log collection exit=$diagnostics_result" >> "$run_dir/environment.txt"
if [ "$result" -eq 0 ]; then
  echo 'PASS ui-recovery exit=0' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL ui-recovery exit=$result" | tee -a "$run_dir/RESULTS.txt"
fi
echo 'NOT TESTED: Core, full regression suite and real HLS listening verification' >> "$run_dir/RESULTS.txt"
tail -n 35 "$run_dir/ui-tests.log"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
