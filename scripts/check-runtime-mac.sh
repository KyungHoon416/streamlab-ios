#!/usr/bin/env bash
# Debug/Release navigation regression + scoped runtime diagnostics. Not a leak test.
set -uo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-Release}"
case "$configuration" in
  Debug|Release) ;;
  *) echo 'CONFIGURATION must be Debug or Release' >&2; exit 2 ;;
esac
configuration_slug="$(printf '%s' "$configuration" | tr '[:upper:]' '[:lower:]')"
mkdir -p Docs/Validation
log_dir="$(mktemp -d "$PWD/Docs/Validation/runtime-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
summary="$log_dir/RESULTS.txt"
stream_pid=""
: > "$summary"
finish() {
  if [ -n "$stream_pid" ]; then
    kill -INT "$stream_pid" 2>/dev/null || true
    wait "$stream_pid" 2>/dev/null || true
  fi
  echo 'NOT TESTED memory-leaks: UI repetition does not measure retained objects or replace Instruments' >> "$summary"
  echo "Results: $summary"
}
trap finish EXIT
if ! command -v xcodebuild >/dev/null || ! command -v xcrun >/dev/null; then
  echo "NOT TESTED $configuration_slug-navigation/runtime-glass: requires Mac and Xcode" | tee -a "$summary"
  exit 2
fi
{
  echo "Configuration: $configuration"
  date -u
  git rev-parse HEAD
  git status --short
  xcodebuild -version
  xcrun simctl list devices available -j
} > "$log_dir/environment.txt" 2>&1
./scripts/bootstrap-mac.sh > "$log_dir/bootstrap.log" 2>&1 || {
  echo "FAIL bootstrap; NOT TESTED $configuration_slug-navigation/runtime-glass" | tee -a "$summary"
  exit 1
}
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for vs in d["devices"].values() for v in vs if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v: v.get("state") != "Booted"); print(a[0]["udid"] if a else "")')"
fi
if [ -z "$simulator_id" ]; then
  echo "NOT TESTED $configuration_slug-navigation/runtime-glass: no available iPhone Simulator" | tee -a "$summary"
  exit 2
fi
echo "Selected simulator: $simulator_id" >> "$log_dir/environment.txt"
xcrun simctl boot "$simulator_id" > "$log_dir/boot.log" 2>&1 || true
xcrun simctl bootstatus "$simulator_id" -b >> "$log_dir/boot.log" 2>&1 || exit 1
xcrun simctl spawn "$simulator_id" log stream --style compact --level debug --predicate 'process == "StreamLab"' > "$log_dir/runtime.log" 2>&1 &
stream_pid=$!
# Fresh products for the selected configuration; never share previous diagnostics.
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration "$configuration" \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$log_dir/DerivedData" -resultBundlePath "$log_dir/Navigation.xcresult" \
  -parallel-testing-enabled NO \
  -only-testing:StreamLabUITests/StreamLabUITests/testReleaseNavigationSoak \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO test > "$log_dir/$configuration_slug-navigation.log" 2>&1
test_exit=$?
stream_alive=0
kill -0 "$stream_pid" 2>/dev/null && stream_alive=1
kill -INT "$stream_pid" 2>/dev/null || true
wait "$stream_pid" 2>/dev/null || true
stream_pid=""
python3 scripts/summarize-runtime.py "$log_dir" "$test_exit" "$stream_alive" "$configuration" | tee -a "$summary"
result=${PIPESTATUS[0]}
exit "$result"
