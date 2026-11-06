#!/usr/bin/env bash
# Fresh simulator, no signing account or Firebase setup needed.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/submission-app-XXXXXX")" || exit 2
build_dir="${STREAMLAB_COMBINED_BUILD_DIR:-$(mktemp -d /private/tmp/streamlab-submission-app-XXXXXX)}"
fixture="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; a=[(k,v) for k,g in json.load(sys.stdin)["devices"].items() for v in g if v.get("isAvailable") and "iPhone" in v["name"]]; print(a[0][1]["deviceTypeIdentifier"]+" "+a[0][0] if a else "")')"
if [ -z "$fixture" ]; then echo 'FAIL no iPhone simulator runtime' | tee "$run_dir/RESULTS.txt"; exit 2; fi
read -r device_type runtime <<< "$fixture"
simulator="$(xcrun simctl create "StreamLab-Submission-$$" "$device_type" "$runtime")" || exit 2
trap 'xcrun simctl shutdown "$simulator" >/dev/null 2>&1 || true; xcrun simctl delete "$simulator" >/dev/null 2>&1 || true' EXIT
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator"; } > "$run_dir/environment.txt"
start=$SECONDS
tests=(testColdLaunchAndRelaunchShowProfiles testSwiftUIScreensAndPlayback)
result=0
run_tests() {
  local phase="$1"
  shift
  local options=() test_name
  for test_name in "$@"; do options+=("-only-testing:StreamLabUITests/StreamLabUITests/$test_name"); done
  xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator" -derivedDataPath "$build_dir/DerivedData" \
    -resultBundlePath "$run_dir/$phase.xcresult" -parallel-testing-enabled NO \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 240 -maximum-test-execution-time-allowance 240 \
    "${options[@]}" SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_SUPPRESS_WARNINGS=NO \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$run_dir/$phase.log" 2>&1
  local exit_code=$?
  for test_name in "$@"; do
    if ! grep -Eq "$test_name.*passed" "$run_dir/$phase.log"; then exit_code=1; fi
  done
  if [ "$exit_code" -ne 0 ]; then echo "FAIL $phase" | tee -a "$run_dir/RESULTS.txt"; return 1; fi
  echo "PASS $phase tests=$#" | tee -a "$run_dir/RESULTS.txt"
}
if ! run_tests smoke "${tests[@]}"; then echo "Results: $run_dir/RESULTS.txt"; exit 1; fi
elapsed=$((SECONDS-start))
echo "CLEAN_SIMULATOR_BUILD_LAUNCH_SECONDS=$elapsed" | tee -a "$run_dir/RESULTS.txt"
if [ "$elapsed" -ge 600 ]; then echo 'FAIL 10 minute reproduction budget' | tee -a "$run_dir/RESULTS.txt"; result=1; fi
run_tests boundaries testMyListPersistsAndIsolatesProfiles testRecentSearchesPersistAndIsolateProfiles \
  testSubtitleSelectionSeekingAndRestoration testF04CloseDuringSeekThenSwitchProfileKeepsNewPlaybackIndependent \
  testPlaybackAccessibilityControlPath || result=1
run_tests measurement testControlledHomeScrollC testControlledHomeScrollPV || result=1
echo 'SCOPE: clean simulator build/launch, SQLite-backed UI persistence, F04 and structural accessibility. Physical VoiceOver/power are separate.' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
