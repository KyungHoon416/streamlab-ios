#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/persisted-auth-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; } > "$run_dir/environment.txt" 2>&1
if ! command -v xcrun >/dev/null; then
  echo 'NOT TESTED: Apple toolchain unavailable' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
{ xcodebuild -version; xcrun swift --version; } >> "$run_dir/environment.txt" 2>&1
printf 'STREAMLAB_CHAOS_SEED=%s\n' "${STREAMLAB_CHAOS_SEED:-1...1000}" >> "$run_dir/environment.txt"
core_dir="$(mktemp -d /private/tmp/streamlab-persisted-auth-core-XXXXXX)" || exit 2
echo "Uses two dummy Keychain items in a unique test service; existing credentials are not queried."
echo "Running Core, persisted authentication and Keychain tests. Log: $run_dir/core.log"
STREAMLAB_TEST_KEYCHAIN=1 swift test --package-path Packages/StreamLabCore --scratch-path "$core_dir" \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete 2>&1 | tee "$run_dir/core.log"
result=${PIPESTATUS[0]}
if [ "$result" -eq 0 ] && grep -q 'Suite "C2 token store policy" passed' "$run_dir/core.log" &&
   grep -q 'Suite "C2 system Keychain integration" passed' "$run_dir/core.log" &&
   grep -q 'Suite "C2 persisted authentication" passed' "$run_dir/core.log" &&
   grep -q 'KEYCHAIN PASS dummy-item-lifecycle' "$run_dir/core.log"; then
  echo 'PASS Core, persisted authentication and Keychain' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL Core/persisted authentication/Keychain exit=$result; require policy and system suites plus cleanup completion" | tee "$run_dir/RESULTS.txt"
  result=1
fi
echo 'NOT TESTED: iOS locked-device protection, app login/logout wiring, production refresh endpoint, full C2' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
