#!/usr/bin/env bash
# UI path events are injected; this does not toggle actual network connectivity.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/offline-banner-XXXXXX")" || exit 2
build_dir="$(mktemp -d /private/tmp/streamlab-offline-banner-XXXXXX)" || exit 2
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v:v.get("state")!="Booted"); print(a[0]["udid"] if a else "")')"
fi
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator_id"; echo "Build directory: $build_dir"; } > "$run_dir/environment.txt" 2>&1
if [ -z "$simulator_id" ]; then
  echo 'FAIL no available iPhone simulator' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$build_dir/DerivedData" \
  -resultBundlePath "$run_dir/UITests.xcresult" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 360 -maximum-test-execution-time-allowance 360 \
  -only-testing:StreamLabUITests/StreamLabUITests/testDownloadScreenShowsOfflineThenRestoredBanner \
  -only-testing:StreamLabUITests/StreamLabUITests/testPlaybackShowsOfflineThenRestoredBanner \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$run_dir/ui-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ] && grep -Eq 'testDownloadScreenShowsOfflineThenRestoredBanner.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testPlaybackShowsOfflineThenRestoredBanner.*passed' "$run_dir/ui-tests.log"; then
  echo 'PASS download and playback offline/reconnected banner appearance and dismissal' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL network banner UI exit=$result; required test must pass" | tee -a "$run_dir/RESULTS.txt"; result=1
fi
echo 'NOT TESTED: actual physical network disconnection during transfer/streaming; UI uses injected path events and local playback' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
