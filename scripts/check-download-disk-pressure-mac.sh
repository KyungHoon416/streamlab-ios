#!/usr/bin/env bash
# Storage accounting and download library UI checks.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/download-disk-pressure-XXXXXX")" || exit 2
build_dir="$(mktemp -d /private/tmp/streamlab-download-disk-pressure-XXXXXX)" || exit 2
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v:v.get("state")!="Booted"); print(a[0]["udid"] if a else "")')"
fi
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator_id"; echo "Build directory: $build_dir"; } > "$run_dir/environment.txt" 2>&1
if [ -z "$simulator_id" ]; then
  echo 'FAIL no available iPhone simulator' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
swift test --package-path Packages/StreamLabCore --scratch-path "$build_dir/Core" \
  --filter 'OfflineDownloadDiskPressureTests|OfflineDownloadExpiryTests|OfflineDownloadUsageTests|OfflineDownloadBudgetTests' -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete > "$run_dir/core.log" 2>&1
result=$?
if [ "$result" -ne 0 ] || ! grep -q 'Test run with 25 tests.*passed' "$run_dir/core.log"; then
  echo "FAIL storage policy exit=$result (twenty-five tests required)" | tee "$run_dir/RESULTS.txt"; exit 1
fi
echo 'PASS twenty-five storage accounting and existing download policy tests' > "$run_dir/RESULTS.txt"
TEST_RUNNER_STREAMLAB_TEST_DOWNLOADS=1 xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$build_dir/DerivedData" \
  -resultBundlePath "$run_dir/UITests.xcresult" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 360 -maximum-test-execution-time-allowance 360 \
  -only-testing:StreamLabUITests/StreamLabUITests/testHLSDiskPressureProtectsPinnedAndRetryRecovers \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$run_dir/ui-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ] && grep -Eq 'testHLSDiskPressureProtectsPinnedAndRetryRecovers.*passed' "$run_dir/ui-tests.log"; then
  echo 'PASS actual HLS pinned file preservation, admission disk pressure and retry recovery' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL download storage UI exit=$result; required test must pass" | tee -a "$run_dir/RESULTS.txt"; result=1
fi
echo 'NOT TESTED: physical disk exhaustion or mid-transfer ENOSPC; DEBUG injects zero admission capacity while retaining real HLS files' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
