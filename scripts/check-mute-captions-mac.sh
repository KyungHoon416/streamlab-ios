#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/mute-captions-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; xcodebuild -version; } > "$run_dir/environment.txt" 2>&1
build_dir="$(mktemp -d /private/tmp/streamlab-mute-captions-XXXXXX)" || exit 2
echo "Build directory: $build_dir" >> "$run_dir/environment.txt"
echo "Running mute-caption policy tests. Logs: $run_dir"
swift test --package-path Packages/StreamLabCore --scratch-path "$build_dir/Core" \
  --filter MuteCaptionPolicyTests -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete \
  > "$run_dir/core.log" 2>&1
result=$?
if [ "$result" -ne 0 ] || ! grep -q 'Executed 6 tests, with 0 failures' "$run_dir/core.log"; then
  echo "FAIL mute-caption tests exit=$result; require six executed tests" | tee "$run_dir/RESULTS.txt"
  tail -n 40 "$run_dir/core.log"
  exit 1
fi
echo 'PASS six mute-caption policy/storage tests' | tee "$run_dir/RESULTS.txt"
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$build_dir/DerivedData" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  build > "$run_dir/build.log" 2>&1
result=$?
if [ "$result" -eq 0 ]; then
  echo 'PASS simulator build' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL simulator build exit=$result" | tee -a "$run_dir/RESULTS.txt"
fi
echo 'NOT TESTED: physical volume KVO, HLS subtitle switching, VoiceOver, full UI regression' >> "$run_dir/RESULTS.txt"
tail -n 25 "$run_dir/build.log"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
