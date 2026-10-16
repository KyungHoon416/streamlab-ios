#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/durable-progress-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; } > "$run_dir/environment.txt" 2>&1
if ! command -v xcrun >/dev/null || ! command -v xcodebuild >/dev/null; then
  echo 'NOT TESTED: Apple toolchain unavailable' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
{ xcodebuild -version; xcrun swift --version; } >> "$run_dir/environment.txt" 2>&1
core_dir="$(mktemp -d /private/tmp/streamlab-durable-core-XXXXXX)" || exit 2
echo "Running Core tests. Log: $run_dir/core.log"
swift test --package-path Packages/StreamLabCore --scratch-path "$core_dir" \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete > "$run_dir/core.log" 2>&1
result=$?
if [ "$result" -ne 0 ] || ! grep -q 'Suite "B1 durable playback progress" passed' "$run_dir/core.log"; then
  echo "FAIL Core/B1 exit=$result; require B1 suite completion" | tee "$run_dir/RESULTS.txt"
  echo 'NOT TESTED: durable progress UI; Core prerequisite failed' >> "$run_dir/RESULTS.txt"
  tail -n 50 "$run_dir/core.log"
  exit 1
fi
echo 'PASS Core/B1 playback progress tests' | tee "$run_dir/RESULTS.txt"
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v: v.get("state") != "Booted"); print(a[0]["udid"] if a else "")')"
fi
if [ -z "$simulator_id" ]; then
  echo 'NOT TESTED: no available iPhone simulator' | tee -a "$run_dir/RESULTS.txt"
  exit 2
fi
echo "Simulator: $simulator_id" >> "$run_dir/environment.txt"
echo "Building and testing durable progress. Log: $run_dir/ui-tests.log"
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$run_dir/DerivedData" -resultBundlePath "$run_dir/UITests.xcresult" \
  -parallel-testing-enabled NO \
  -only-testing:StreamLabUITests/StreamLabUITests/testPlaybackResumeAfterRelaunchAndRestart \
  -only-testing:StreamLabUITests/StreamLabUITests/testPlaybackResumeWithOfflineMutationTransport \
  -only-testing:StreamLabUITests/StreamLabUITests/testHomeContinueWatchingUsesSavedProgress \
  -only-testing:StreamLabUITests/StreamLabUITests/testMyListPersistsAndIsolatesProfiles \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO test > "$run_dir/ui-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ]; then
  echo 'PASS durable progress UI' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL durable progress UI exit=$result" | tee -a "$run_dir/RESULTS.txt"
fi
echo 'NOT TESTED: real network recovery, power loss, account logout UI, recent-search queue integration, full regression' >> "$run_dir/RESULTS.txt"
tail -n 35 "$run_dir/ui-tests.log"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
