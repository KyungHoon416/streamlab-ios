#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/audio-interruptions-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; } > "$run_dir/environment.txt" 2>&1
if ! command -v xcrun >/dev/null; then
  echo 'NOT TESTED: Apple toolchain unavailable' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
{ xcodebuild -version; xcrun swift --version; } >> "$run_dir/environment.txt" 2>&1
core_dir="$(mktemp -d /private/tmp/streamlab-audio-interruptions-XXXXXX)" || exit 2
swift test --package-path Packages/StreamLabCore --scratch-path "$core_dir" \
  --filter PlaybackInterruptionPolicyTests \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete 2>&1 | tee "$run_dir/core.log"
result=${PIPESTATUS[0]}
if [ "$result" -eq 0 ] && grep -q 'Executed 6 tests, with 0 failures' "$run_dir/core.log"; then
  echo 'PASS six interruption intent policy tests' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL interruption policy tests exit=$result; require six executed tests" | tee "$run_dir/RESULTS.txt"
  result=1
fi
echo 'NOT TESTED: iOS build, phone/Siri interruptions, headphone/Bluetooth disconnection, stale activation callbacks on device' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
