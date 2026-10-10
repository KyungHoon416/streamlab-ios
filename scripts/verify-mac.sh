#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
run_id="$(date -u +%Y%m%dT%H%M%SZ)"
log_dir="$PWD/Docs/Validation/$run_id"
mkdir -p "$log_dir"
summary="$log_dir/RESULTS.txt"
failed=0
run_check() {
  local name="$1"
  shift
  "$@" >"$log_dir/$name.log" 2>&1
  local result=$?
  if [ "$result" -eq 0 ]; then
    echo "PASS $name exit=$result" | tee -a "$summary"
  else
    echo "FAIL $name exit=$result" | tee -a "$summary"
    tail -n 40 "$log_dir/$name.log"
    failed=1
  fi
  return "$result"
}
if ! command -v xcodebuild >/dev/null || ! command -v swift >/dev/null; then
  echo 'NOT TESTED: Xcode and Swift are required on macOS.' | tee "$summary"
  exit 2
fi
xcodebuild -version >"$log_dir/environment.txt" 2>&1
swift --version >>"$log_dir/environment.txt" 2>&1
run_check fixtures python3 scripts/validate-fixtures.py
run_check bootstrap ./scripts/bootstrap-mac.sh || exit 1
run_check core swift test --package-path Packages/StreamLabCore -Xswiftc -warnings-as-errors
run_check simulator-build xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
if [ -z "${SIMULATOR_ID:-}" ]; then
  SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((v["udid"] for vs in d["devices"].values() for v in vs if v.get("isAvailable") and "iPhone" in v["name"]), ""))')"
fi
if [ -n "${SIMULATOR_ID:-}" ]; then
  echo "Simulator: $SIMULATOR_ID" >>"$log_dir/environment.txt"
  run_check ui-tests xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath .derivedData -resultBundlePath "$log_dir/UITests.xcresult" CODE_SIGNING_ALLOWED=NO test
else
  echo 'NOT TESTED ui-tests: install an iPhone simulator runtime or set SIMULATOR_ID.' | tee -a "$summary"
  failed=1
fi
printf '\nResults: %s\n' "$summary"
echo 'VoiceOver, Instruments and real-device checks remain manual; update PHASE1_REPORT.md with observed evidence.'
exit "$failed"
