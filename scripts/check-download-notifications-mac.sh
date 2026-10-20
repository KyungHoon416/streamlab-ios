#!/usr/bin/env bash
# Native HLS integration is explicit: no successful skip or simulated completion.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/download-notifications-XXXXXX")" || exit 2
build_dir="$(mktemp -d /private/tmp/streamlab-download-notifications-XXXXXX)" || exit 2
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v:v.get("state")!="Booted"); print(a[0]["udid"] if a else "")')"
fi
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator_id"; echo "Build directory: $build_dir"; } > "$run_dir/environment.txt" 2>&1
if [ -z "$simulator_id" ]; then
  echo 'NOT TESTED: no iPhone simulator' | tee "$run_dir/RESULTS.txt"; exit 2
fi
swift test --package-path Packages/StreamLabCore --scratch-path "$build_dir/Core" \
  --filter 'DownloadNotificationTests|OfflineDownloadBudgetTests' -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete > "$run_dir/core.log" 2>&1
result=$?
if [ "$result" -ne 0 ] || ! grep -q 'Test run with 19 tests.*passed' "$run_dir/core.log"; then
  echo "FAIL download policy exit=$result (nineteen tests required)" | tee "$run_dir/RESULTS.txt"; exit 1
fi
echo 'PASS nineteen notification race, network transition and download policy tests' > "$run_dir/RESULTS.txt"
TEST_RUNNER_STREAMLAB_TEST_DOWNLOADS=1 xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$build_dir/DerivedData" \
  -resultBundlePath "$run_dir/UITests.xcresult" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 360 -maximum-test-execution-time-allowance 360 \
  -only-testing:StreamLabUITests/StreamLabUITests/testHLSBackgroundCompletionNotificationRemovedOnLogout \
  -only-testing:StreamLabUITests/StreamLabUITests/testHLSCancelledDownloadDoesNotNotify \
  -only-testing:StreamLabUITests/StreamLabUITests/testHLSTwoTransfersQueueThirdAndLogoutCleansNativeTasks \
  -only-testing:StreamLabUITests/StreamLabUITests/testNetworkReconnectBannerAppearsThenDismisses \
  -only-testing:StreamLabUITests/StreamLabUITests/testDownloadsLibraryEmptyAtMaximumTextSize \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$run_dir/ui-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ] && grep -Eq 'testHLSBackgroundCompletionNotificationRemovedOnLogout.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testHLSCancelledDownloadDoesNotNotify.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testHLSTwoTransfersQueueThirdAndLogoutCleansNativeTasks.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testNetworkReconnectBannerAppearsThenDismisses.*passed' "$run_dir/ui-tests.log" &&
   grep -Eq 'testDownloadsLibraryEmptyAtMaximumTextSize.*passed' "$run_dir/ui-tests.log"; then
  echo 'PASS real completion notification, cancel/logout suppression, reconnect banner and large text' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL native HLS download exit=$result; required test must pass" | tee -a "$run_dir/RESULTS.txt"; result=1
fi
echo 'NOT TESTED: physical notification presentation/Focus settings, real network toggle banner, OS termination/wakeup; deterministic path events used for banner UI' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
