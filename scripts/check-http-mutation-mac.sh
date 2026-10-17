#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/http-mutation-XXXXXX")" || exit 2
{ git rev-parse HEAD; git status --short; } > "$run_dir/environment.txt" 2>&1
if ! command -v xcrun >/dev/null; then
  echo 'NOT TESTED: Apple toolchain unavailable' | tee "$run_dir/RESULTS.txt"
  exit 2
fi
{ xcodebuild -version; xcrun swift --version; } >> "$run_dir/environment.txt" 2>&1
printf 'STREAMLAB_CHAOS_SEED=%s\n' "${STREAMLAB_CHAOS_SEED:-1...1000}" >> "$run_dir/environment.txt"
core_dir="$(mktemp -d /private/tmp/streamlab-http-core-XXXXXX)" || exit 2
echo "Running Core and HTTP adapter tests. Log: $run_dir/core.log"
swift test --package-path Packages/StreamLabCore --scratch-path "$core_dir" \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete 2>&1 | tee "$run_dir/core.log"
result=${PIPESTATUS[0]}
if [ "$result" -eq 0 ] && grep -q 'Suite "B2 HTTP mutation adapter" passed' "$run_dir/core.log"; then
  echo 'PASS Core and HTTP mutation adapter' | tee "$run_dir/RESULTS.txt"
else
  echo "FAIL Core/HTTP adapter exit=$result; require adapter suite completion" | tee "$run_dir/RESULTS.txt"
  result=1
fi
echo 'NOT TESTED: iOS UI, actual HTTP/network recovery, all B2 invariants, full Part D chaos scenarios' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
exit "$result"
