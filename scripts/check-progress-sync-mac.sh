#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/progress-sync-XXXXXX")" || exit 2
build_dir="$(mktemp -d /private/tmp/streamlab-progress-core-XXXXXX)" || exit 2
{ git rev-parse HEAD; git status --short; xcrun swift --version; } > "$run_dir/environment.txt" 2>&1
echo "Running Core tests including A3. Log: $run_dir/core.log"
swift test --package-path Packages/StreamLabCore --scratch-path "$build_dir" > "$run_dir/core.log" 2>&1
result=$?
if [ "$result" -eq 0 ] && grep -q 'Suite "A3 multi-device revision simulation" passed' "$run_dir/core.log"; then
  echo 'PASS core and A3 simulation exit=0' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL core/A3 exit=$result; require A3 suite completion" | tee "$run_dir/RESULTS.txt"
  result=1
fi
echo 'NOT TESTED: network server, physical cross-device playback, AVPlayer integration, app relaunch persistence and full UI regression' >> "$run_dir/RESULTS.txt"
tail -n 35 "$run_dir/core.log"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
