#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/http-loader-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; } > "$run_dir/environment.txt" 2>&1
if ! command -v xcrun >/dev/null || ! command -v python3 >/dev/null; then
  echo 'NOT TESTED: requires Apple toolchain and python3' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
{ xcodebuild -version; xcrun swift --version; python3 --version; } >> "$run_dir/environment.txt" 2>&1
python3 scripts/http-loader-fixture.py --ready-file "$run_dir/fixture-url.txt" > "$run_dir/server.log" 2>&1 &
fixture_pid=$!
cleanup() { kill "$fixture_pid" 2>/dev/null || true; wait "$fixture_pid" 2>/dev/null || true; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for _ in {1..100}; do
  if [ -s "$run_dir/fixture-url.txt" ]; then break; fi
  if ! kill -0 "$fixture_pid" 2>/dev/null; then break; fi
  sleep 0.05
done
if [ ! -s "$run_dir/fixture-url.txt" ]; then
  echo 'FAIL local HTTP fixture startup; see server.log' | tee "$run_dir/RESULTS.txt"
  exit 1
fi
STREAMLAB_HTTP_FIXTURE_URL="$(cat "$run_dir/fixture-url.txt")"
export STREAMLAB_HTTP_FIXTURE_URL
core_dir="$(mktemp -d /private/tmp/streamlab-loader-core-XXXXXX)" || exit 2
echo "Running Core and loopback URLSession tests. Log: $run_dir/core.log"
swift test --package-path Packages/StreamLabCore --scratch-path "$core_dir" \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete 2>&1 | tee "$run_dir/core.log"
result=${PIPESTATUS[0]}
if [ "$result" -eq 0 ] && grep -q 'Suite "B2 URLSession loader integration" passed' "$run_dir/core.log" &&
   grep -q 'HTTP LOADER PASS redirect' "$run_dir/core.log" &&
   grep -q 'HTTP LOADER PASS streaming-limit' "$run_dir/core.log" &&
   grep -q 'HTTP LOADER PASS cancellation' "$run_dir/core.log"; then
  echo 'PASS Core and loopback URLSession loader integration' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL Core/loader exit=$result; require suite and all 3 markers" | tee "$run_dir/RESULTS.txt"
  result=1
fi
echo 'NOT TESTED: iOS UI, TLS/authentication, external server, actual internet recovery, full B2/Part D' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt (send with environment.txt, core.log, server.log)"
exit "$result"
