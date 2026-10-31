#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/assignment-core-XXXXXX")" || exit 2
{ git rev-parse HEAD; xcodebuild -version; } > "$run_dir/environment.txt" 2>&1
bash scripts/check-http-auth-boundaries-mac.sh 2>&1 | tee "$run_dir/core.log"
result=${PIPESTATUS[0]}
expected=1000
if [ -n "${STREAMLAB_CHAOS_SEED:-}" ]; then expected=1; fi
for marker in 'F01 PASS order=5,4,3,2,1 latest=5 duplicates=0' \
  'F03 PASS mutations=100 serverEffects=100 pending=0 lost=0 replay=all-acks-lost' \
  "DOMAIN CHAOS PASS seeds=$expected " "CHAOS PASS seeds=$expected " "RETRY CLOCK CHAOS PASS seeds=$expected "; do
  if ! grep -q "^$marker" "$run_dir/core.log"; then
    echo "MISSING required marker: $marker" | tee -a "$run_dir/RESULTS.txt"
    result=1
  fi
done
if [ "$result" -eq 0 ]; then
  echo 'PASS assignment Core evidence (not full F01-F10 acceptance)' | tee -a "$run_dir/RESULTS.txt"
else
  echo 'FAIL assignment Core evidence' | tee -a "$run_dir/RESULTS.txt"
fi
exit "$result"
