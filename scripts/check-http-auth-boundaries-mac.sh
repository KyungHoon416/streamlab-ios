#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/http-boundaries-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; xcodebuild -version; xcrun swift --version; python3 --version; } > "$run_dir/environment.txt" 2>&1
pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for kind in loader auth mutation; do
  python3 -u "scripts/http-$kind-fixture.py" --ready-file "$run_dir/$kind-url.txt" > "$run_dir/$kind-server.log" 2>&1 &
  pid=$!
  pids+=("$pid")
  # Cold CI runners may take longer than five seconds to start Python/HTTPServer.
  # This only bounds fixture readiness; request/retry budgets remain unchanged.
  for _ in {1..600}; do
    [ -s "$run_dir/$kind-url.txt" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.05
  done
  if [ ! -s "$run_dir/$kind-url.txt" ]; then
    echo "FAIL $kind fixture startup (readiness budget: 30 seconds)" | tee "$run_dir/RESULTS.txt"
    if kill -0 "$pid" 2>/dev/null; then
      echo 'Fixture process is alive but did not publish readiness.' | tee -a "$run_dir/RESULTS.txt"
    else
      echo 'Fixture process exited before readiness.' | tee -a "$run_dir/RESULTS.txt"
    fi
    cat "$run_dir/$kind-server.log"
    exit 1
  fi
done
export STREAMLAB_HTTP_FIXTURE_URL="$(cat "$run_dir/loader-url.txt")"
export STREAMLAB_AUTH_FIXTURE_URL="$(cat "$run_dir/auth-url.txt")"
export STREAMLAB_MUTATION_FIXTURE_URL="$(cat "$run_dir/mutation-url.txt")"
export STREAMLAB_TEST_KEYCHAIN=1
core_dir="$(mktemp -d /private/tmp/streamlab-http-boundaries-XXXXXX)" || exit 2
echo "Loopback HTTP + unique dummy Keychain items. Log: $run_dir/core.log"
swift test --package-path Packages/StreamLabCore --scratch-path "$core_dir" \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete 2>&1 | tee "$run_dir/core.log"
result=${PIPESTATUS[0]}
for suite in 'B2 URLSession loader integration' 'B2 HTTP durable queue integration' \
  'B3 HTTP authentication integration' 'B3 authentication single flight' \
  'C2 token store policy' 'C2 system Keychain integration' 'C2 persisted authentication' \
  'C2 durable authentication logout' 'C2 explicit authentication sign-in'; do
  if ! grep -Fq "Suite \"$suite\" passed" "$run_dir/core.log"; then
    echo "MISSING passed suite: $suite" | tee -a "$run_dir/RESULTS.txt"
    result=1
  fi
done
for marker in 'HTTP LOADER PASS redirect' 'HTTP LOADER PASS streaming-limit' 'HTTP LOADER PASS cancellation' \
  'HTTP QUEUE PASS lost-ack' 'HTTP QUEUE PASS conflict' 'HTTP QUEUE PASS retry-budget' 'HTTP QUEUE PASS cancellation' \
  'HTTP AUTH PASS success' 'HTTP AUTH PASS failure' 'HTTP AUTH PASS logout-in-flight' 'KEYCHAIN PASS dummy-item-lifecycle'; do
  if ! grep -Fxq "$marker" "$run_dir/core.log"; then
    echo "MISSING marker: $marker" | tee -a "$run_dir/RESULTS.txt"
    result=1
  fi
done
if [ "$result" -eq 0 ]; then
  echo 'PASS Core, real loopback HTTP and authentication/logout boundaries' | tee -a "$run_dir/RESULTS.txt"
else
  echo "FAIL Core/boundary gates exit=$result" | tee -a "$run_dir/RESULTS.txt"
fi
echo 'NOT TESTED: production endpoints, TLS, iOS locked-device Keychain, app login/logout wiring, full assignment acceptance' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
