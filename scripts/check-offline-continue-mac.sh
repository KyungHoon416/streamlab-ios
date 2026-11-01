#!/usr/bin/env bash
# Home Continue Watching prefers a valid profile-scoped download; expired files use streaming.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/offline-continue-XXXXXX")" || exit 2
build_dir="${STREAMLAB_CONTINUE_BUILD_DIR:-}"
if [ -z "$build_dir" ]; then
  build_dir="$(mktemp -d /private/tmp/streamlab-offline-continue-XXXXXX)" || exit 2
fi
simulator_id="${SIMULATOR_ID:-}"
# Device-wide budgets include other accounts' pinned files. Use a fresh simulator
# by default, never erase an existing user's simulator to make this test pass.
created_simulator=""
if [ -z "$simulator_id" ]; then
  fixture="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[(k,v) for k,g in d["devices"].items() for v in g if v.get("isAvailable") and "iPhone" in v["name"]]; print(a[0][1]["deviceTypeIdentifier"]+" "+a[0][0] if a else "")')"
  if [ -n "$fixture" ]; then
    read -r device_type runtime <<< "$fixture"
    simulator_id="$(xcrun simctl create "StreamLab-Continue-$$" "$device_type" "$runtime")" || exit 2
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
  -only-testing:StreamLabUITests/StreamLabUITests/testHomeContinuePrefersDownloadedHLSAndRejectsExpiredPackage \
  -only-testing:StreamLabUITests/StreamLabUITests/testHomeContinueWatchingUsesSavedProgress \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$run_dir/ui-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ] &&
   grep -Eq 'testHomeContinuePrefersDownloadedHLSAndRejectsExpiredPackage.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testHomeContinueWatchingUsesSavedProgress.*passed' "$run_dir/ui-tests.log" &&
   grep -q 'Executed 2 tests, with 0 failures' "$run_dir/ui-tests.log"; then
  echo 'PASS home offline-first HLS selection, expired-file fallback and bundled resume regression' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL offline Continue Watching UI exit=$result; two executed tests must pass" | tee "$run_dir/RESULTS.txt"; result=1
fi
echo 'INJECTED: downloaded file expiry. Real HLS package and local playback path checked. NOT TESTED: physical airplane mode, production DRM.' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
