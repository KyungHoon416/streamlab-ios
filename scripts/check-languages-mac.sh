#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/languages-XXXXXX")" || exit 2
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v: v.get("state") != "Booted"); print(a[0]["udid"] if a else "")')"
fi
if [ -z "$simulator_id" ]; then
  echo 'NOT TESTED: no available iPhone simulator' | tee -a "$run_dir/RESULTS.txt"
  exit 2
fi
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator_id"; } > "$run_dir/environment.txt" 2>&1
build_dir="$(mktemp -d /private/tmp/streamlab-languages-XXXXXX)" || exit 2
echo "Build directory: $build_dir" >> "$run_dir/environment.txt"
echo "Running Core tests. Log: $run_dir/core.log"
swift test --package-path Packages/StreamLabCore --scratch-path "$build_dir/Core" \
  --filter MuteCaptionPolicyTests -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete > "$run_dir/core.log" 2>&1
core_result=$?
if [ "$core_result" -eq 0 ] && grep -q 'Executed 10 tests, with 0 failures' "$run_dir/core.log"; then
  echo 'PASS ten mute-caption policy/storage tests' > "$run_dir/RESULTS.txt"
else
  echo "FAIL core exit=$core_result" > "$run_dir/RESULTS.txt"
  echo 'NOT TESTED: language UI tests (Core build/test failed)' >> "$run_dir/RESULTS.txt"
  tail -n 40 "$run_dir/core.log"
  echo "Results: $run_dir/RESULTS.txt"
  exit 1
fi
log_start="$(date '+%Y-%m-%d %H:%M:%S')"
echo "Running language preference UI tests. Log: $run_dir/ui-tests.log"
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$build_dir/DerivedData" -resultBundlePath "$run_dir/UITests.xcresult" \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 900 -maximum-test-execution-time-allowance 900 \
  -only-testing:StreamLabUITests/StreamLabUITests/testSubtitleSelectionSeekingAndRestoration \
  -only-testing:StreamLabUITests/StreamLabUITests/testLanguagePreferenceSurvivesEpisodesRelaunchAndProfileSwitch \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$run_dir/ui-tests.log" 2>&1
result=$?
# App-process orientation messages are not guaranteed to appear in XCTest output.
xcrun simctl spawn "$simulator_id" log show --start "$log_start" --style compact \
  --predicate 'subsystem == "com.example.streamlab.demo" AND category == "PlaybackOrientation"' \
  > "$run_dir/orientation.log" 2>&1
diagnostics_result=$?
echo "Orientation log collection exit=$diagnostics_result" >> "$run_dir/environment.txt"
if [ "$result" -eq 0 ]; then
  for test_name in testSubtitleSelectionSeekingAndRestoration testLanguagePreferenceSurvivesEpisodesRelaunchAndProfileSwitch; do
    if ! grep -Eq "${test_name}.*passed" "$run_dir/ui-tests.log"; then
      echo "FAIL required UI test did not pass: $test_name" >> "$run_dir/RESULTS.txt"
      result=1
    fi
  done
fi
if [ "$result" -eq 0 ]; then
  echo 'PASS language-playback exit=0' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL language-playback exit=$result" | tee -a "$run_dir/RESULTS.txt"
fi
echo 'NOT TESTED: full Core/UI suites, physical volume events and real HLS alternate audio listening verification' >> "$run_dir/RESULTS.txt"
tail -n 35 "$run_dir/ui-tests.log"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
