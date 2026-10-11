#!/usr/bin/env bash
# Run from the repository on a Mac. Results never imply unexecuted checks passed.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p Docs/Validation
log_dir="$(mktemp -d "$PWD/Docs/Validation/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
summary="$log_dir/RESULTS.txt"
failed=0
completed=" "
checks="fixtures project-structure bootstrap generated-project-structure core simulator-build ui-tests"
: > "$summary"
finish() {
  local result=$?
  for name in $checks; do
    case "$completed" in
      *" $name "*) ;;
      *) echo "NOT TESTED $name: prerequisites unavailable or validation stopped" >> "$summary" ;;
    esac
  done
  echo "NOT TESTED manual-voiceover: requires manual VoiceOver navigation" >> "$summary"
  echo "NOT TESTED instruments: requires Instruments measurements" >> "$summary"
  printf '\nResults: %s\n' "$summary"
  return "$result"
}
trap finish EXIT
run_check() {
  local name="$1"
  shift
  echo "Running $name..."
  "$@" >"$log_dir/$name.log" 2>&1
  local result=$?
  completed="$completed$name "
  if [ "$result" -eq 0 ]; then
    echo "PASS $name exit=$result" | tee -a "$summary"
  else
    echo "FAIL $name exit=$result" | tee -a "$summary"
    tail -n 40 "$log_dir/$name.log"
    failed=1
  fi
  return "$result"
}
{
  date -u
  git rev-parse HEAD
  git status --short
  uname -s
} > "$log_dir/environment.txt" 2>&1
run_check fixtures python3 scripts/validate-fixtures.py
run_check project-structure python3 scripts/validate-project.py
if ! command -v xcodebuild >/dev/null || ! command -v xcrun >/dev/null; then
  echo 'NOT TESTED Apple toolchain: run this script on a Mac with Xcode.' | tee -a "$summary"
  exit 2
fi
xcodebuild -version >> "$log_dir/environment.txt" 2>&1
xcrun swift --version >> "$log_dir/environment.txt" 2>&1
run_check bootstrap ./scripts/bootstrap-mac.sh || exit 1
run_check generated-project-structure python3 scripts/validate-project.py
# Keep Core products separate from the previously contaminated project-local .build.
core_build_dir="$(mktemp -d /private/tmp/streamlab-core.XXXXXX)" || exit 1
echo "Core scratch path: $core_build_dir" >> "$log_dir/environment.txt"
run_check core xcrun swift test --package-path Packages/StreamLabCore --scratch-path "$core_build_dir" -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
run_check simulator-build xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath .derivedData -resultBundlePath "$log_dir/Build.xcresult" SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO build
build_exit=$?
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); devices=[v for vs in d["devices"].values() for v in vs if v.get("isAvailable") and "iPhone" in v["name"]]; devices.sort(key=lambda v: v.get("state") != "Booted"); print(devices[0]["udid"] if devices else "")')"
fi
if [ "$build_exit" -eq 0 ] && [ -n "$simulator_id" ]; then
  echo "Simulator: $simulator_id" >> "$log_dir/environment.txt"
  run_check ui-tests xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath .derivedData -resultBundlePath "$log_dir/UITests.xcresult" -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO test
else
  echo 'UI tests skipped: build failed or no available iPhone simulator.'
  failed=1
fi
exit "$failed"
