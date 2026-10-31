#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/http-auth-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; } > "$run_dir/environment.txt" 2>&1
if ! command -v xcrun >/dev/null || ! command -v python3 >/dev/null; then
  echo 'NOT TESTED: requires Apple toolchain and python3' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
{ xcodebuild -version; xcrun swift --version; python3 --version; } >> "$run_dir/environment.txt" 2>&1
python3 scripts/http-auth-fixture.py --ready-file "$run_dir/fixture-url.txt" > "$run_dir/server.log" 2>&1 &
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
STREAMLAB_AUTH_FIXTURE_URL="$(cat "$run_dir/fixture-url.txt")"
export STREAMLAB_AUTH_FIXTURE_URL
core_dir="$(mktemp -d /private/tmp/streamlab-auth-http-core-XXXXXX)" || exit 2
echo "Running Core and HTTP authentication tests. Log: $run_dir/core.log"
swift test --package-path Packages/StreamLabCore --scratch-path "$core_dir" \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete 2>&1 | tee "$run_dir/core.log"
result=${PIPESTATUS[0]}
if [ "$result" -eq 0 ] && grep -q 'Suite "B3 HTTP authentication integration" passed' "$run_dir/core.log" &&
   grep -q 'HTTP AUTH PASS success' "$run_dir/core.log" &&
   grep -q 'HTTP AUTH PASS failure' "$run_dir/core.log" &&
   grep -q 'HTTP AUTH PASS logout-in-flight' "$run_dir/core.log"; then
  echo 'PASS Core and HTTP authentication integration' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL Core/HTTP auth exit=$result; require suite and all three markers" | tee "$run_dir/RESULTS.txt"
  result=1
fi
echo 'NOT TESTED: iOS UI, TLS, Keychain, app sign-in/out wiring, external server, full B3/F02' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt (send with environment.txt, core.log, server.log)"
exit "$result"
