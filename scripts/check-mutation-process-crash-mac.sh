#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/mutation-process-XXXXXX")"
{ git rev-parse HEAD; swift --version; } > "$run_dir/environment.txt" 2>&1
if swift build --package-path Tools/F03CrashProbe -Xswiftc -warnings-as-errors \
    -Xswiftc -strict-concurrency=complete > "$run_dir/build.log" 2>&1; then
  binary_dir="$(swift build --package-path Tools/F03CrashProbe --show-bin-path)"
else
  echo 'FAIL process probe build' | tee "$run_dir/RESULTS.txt"
  tail -40 "$run_dir/build.log"
  exit 1
fi
if python3 scripts/check-mutation-process-crash.py "$binary_dir/F03CrashProbe" > "$run_dir/process.log" 2>&1 &&
   grep -qx 'F03 PROCESS PASS kills=2 restarts=3 mutations=100 duplicateEffects=0 lost=0' "$run_dir/process.log"; then
  cat "$run_dir/process.log"
  echo 'PASS macOS SIGKILL durable mutation recovery' | tee "$run_dir/RESULTS.txt"
else
  cat "$run_dir/process.log"
  echo 'FAIL macOS SIGKILL durable mutation recovery' | tee "$run_dir/RESULTS.txt"
  exit 1
fi
echo 'NOT TESTED: iOS jetsam/file protection; power loss; kill during atomic write; production server' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
