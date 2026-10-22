#!/usr/bin/env bash
# Cache ownership and asynchronous purge races, plus app lifecycle wiring build.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mkdir -p Docs/Validation
run_dir="$(mktemp -d "$PWD/Docs/Validation/artwork-memory-XXXXXX")" || exit 2
build_dir="$(mktemp -d /private/tmp/streamlab-artwork-memory-XXXXXX)" || exit 2
simulator_id="${SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for group in d["devices"].values() for v in group if v.get("isAvailable") and "iPhone" in v["name"]]; a.sort(key=lambda v:v.get("state")!="Booted"); print(a[0]["udid"] if a else "")')"
fi
{ git rev-parse HEAD; git status --short; xcodebuild -version; echo "Simulator: $simulator_id"; } > "$run_dir/environment.txt" 2>&1
fail() { echo "FAIL $1" | tee -a "$run_dir/RESULTS.txt"; exit 1; }
[ -n "$simulator_id" ] || fail 'no available iPhone simulator'
swift test --package-path Packages/StreamLabCore --scratch-path "$build_dir/Core" \
  --filter ArtworkDataCacheTests -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete > "$run_dir/core.log" 2>&1 || fail 'byte cache tests'
grep -q 'Test run with 7 tests.*passed' "$run_dir/core.log" || fail 'seven byte cache tests required'
repo="$PWD"
(cd Packages/StreamLabUI && xcodebuild -scheme StreamLabUI-Package -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$build_dir/UI" \
  -resultBundlePath "$run_dir/Memory.xcresult" -parallel-testing-enabled NO \
  -only-testing:StreamLabCatalogFeatureTests/ArtworkMemoryTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO test) > "$run_dir/decoded-cache.log" 2>&1 || fail 'decoded cache tests'
grep -q 'Test run with 2 tests.*passed' "$run_dir/decoded-cache.log" || fail 'two decoded cache tests required'
xcodebuild -project "$repo/StreamLab.xcodeproj" -scheme StreamLab -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$build_dir/Release" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO build > "$run_dir/release.log" 2>&1 || fail 'app Release build'
echo 'PASS seven byte-cache tests, two iOS decoded-cache tests, Release app build' | tee "$run_dir/RESULTS.txt"
echo 'NOT TESTED: physical memory pressure, ten app background cycles, process retained allocations or Instruments performance metrics' >> "$run_dir/RESULTS.txt"
echo "Results: $run_dir/RESULTS.txt"
