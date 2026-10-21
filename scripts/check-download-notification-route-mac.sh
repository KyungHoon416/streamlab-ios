#!/usr/bin/env bash
# Notification destination routing; test injection does not simulate an OS notification tap.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/notification-route-XXXXXX")" || exit 2
build_dir="$(mktemp -d /private/tmp/streamlab-notification-route-XXXXXX)" || exit 2
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
  -only-testing:StreamLabUITests/StreamLabUITests/testDownloadNotificationTapOpensCurrentProfileLibrary \
  -only-testing:StreamLabUITests/StreamLabUITests/testDownloadNotificationLaunchWaitsForProfileSelection \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$run_dir/ui-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ] && grep -Eq 'testDownloadNotificationTapOpensCurrentProfileLibrary.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testDownloadNotificationLaunchWaitsForProfileSelection.*passed' "$run_dir/ui-tests.log"; then
  echo 'PASS current-profile notification routing, cold launch profile gate and logout reset' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL notification route UI exit=$result; required test must pass" | tee -a "$run_dir/RESULTS.txt"; result=1
fi
echo 'NOT TESTED: tapping an actual OS-delivered completion notification on device; these tests inject the route request' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
