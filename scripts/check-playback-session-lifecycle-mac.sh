#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/playback-session-lifecycle-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; } > "$run_dir/environment.txt" 2>&1
command -v xcodebuild >/dev/null || {
  echo 'NOT TESTED: Xcode required' | tee "$run_dir/RESULTS.txt"; exit 2;
}
xcodebuild -version >> "$run_dir/environment.txt" 2>&1
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v: v.get("state") != "Booted"); print(a[0]["udid"] if a else "")')"
fi
if [ -z "$simulator_id" ]; then
  echo 'NOT TESTED: no available iPhone simulator' | tee "$run_dir/RESULTS.txt"; exit 2
fi
# Test the package directly: do not regenerate or overwrite the user's app project.
cd Packages/StreamLabUI || exit 2
if ! xcodebuild -list -json > "$run_dir/schemes.json" 2> "$run_dir/schemes.log"; then
  echo 'FAIL package scheme discovery; see schemes.log' | tee "$run_dir/RESULTS.txt"; exit 1
fi
package_scheme="$(python3 - "$run_dir/schemes.json" <<'PY'
import json, sys
value = json.load(open(sys.argv[1]))
schemes = [s for section in value.values() if isinstance(section, dict) for s in section.get('schemes', [])]
for candidate in ['StreamLabUI-Package', 'StreamLabCatalogFeature']:
    if candidate in schemes:
        print(candidate)
        break
PY
)"
if [ -z "$package_scheme" ]; then
  echo 'FAIL expected package test scheme missing; see schemes.json' | tee "$run_dir/RESULTS.txt"; exit 1
fi
build_dir="$(mktemp -d /private/tmp/streamlab-now-playing-XXXXXX)" || exit 2
printf 'Simulator: %s\nScheme: %s\nDerivedData: %s\n' "$simulator_id" "$package_scheme" "$build_dir" >> "$run_dir/environment.txt"
echo "Running iOS playback session and Now Playing tests. Log: $run_dir/ios-tests.log"
xcodebuild -scheme "$package_scheme" -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$build_dir" \
  -resultBundlePath "$run_dir/Tests.xcresult" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
  -only-testing:StreamLabCatalogFeatureTests/PlaybackNowPlayingTests \
  -only-testing:StreamLabCatalogFeatureTests/PlaybackSessionLifecycleTests \
  -only-testing:StreamLabCatalogFeatureTests/PlaybackOrientationCallbackTests \
  -only-testing:StreamLabCatalogFeatureTests/PlaybackEntitlementBoundaryTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=NO test > "$run_dir/ios-tests.log" 2>&1
result=$?
if [ "$result" -eq 0 ] && grep -q 'Executed 17 tests, with 0 failures' "$run_dir/ios-tests.log" &&
   grep -Eq 'testRejectedEntitlementsCannotCreatePlayerAndRenewalRecovers.*passed' "$run_dir/ios-tests.log" &&
   grep -Eq 'testRotationRejectionCanArriveOffMainActor.*passed' "$run_dir/ios-tests.log" &&
   grep -Eq 'testRestoreRejectionCanArriveOffMainActor.*passed' "$run_dir/ios-tests.log" &&
   grep -Eq 'testCloseRejectsLateEntitlementSuccess.*passed' "$run_dir/ios-tests.log" &&
   grep -Eq 'testInvalidatedSessionRejectsLateEntitlementSuccess.*passed' "$run_dir/ios-tests.log" &&
   grep -Eq 'testOldProfileReplyCannotReplaceNewPlayer.*passed' "$run_dir/ios-tests.log" &&
   grep -Eq 'testPersistentRenewalFailureExhaustsRetryBudget.*passed' "$run_dir/ios-tests.log" &&
   grep -Eq 'testProfileReplacementDuringSeekStopsOldPlayerAndKeepsNewMetadata.*passed' "$run_dir/ios-tests.log" &&
   grep -Eq 'testTenBackgroundCyclesWithCachePressureReleasePlayer.*passed' "$run_dir/ios-tests.log"; then
  echo 'PASS seventeen iOS playback session and Now Playing tests' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL iOS lifecycle tests exit=$result; require seventeen executed tests" | tee "$run_dir/RESULTS.txt"
  result=1
fi
echo 'NOT TESTED: physical lock-screen card, SwiftUI profile-switch navigation, Bluetooth disconnection, full regression suite' >> "$run_dir/RESULTS.txt"
tail -n 30 "$run_dir/ios-tests.log"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
