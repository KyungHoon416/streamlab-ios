#!/usr/bin/env bash
# Fresh build only; does not repeat the UI suite or suppress diagnostics.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo 'NOT TESTED: Xcode is required'; exit 2; }
mkdir -p Docs/Validation
warning_log_dir="$(mktemp -d "$PWD/Docs/Validation/warnings-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")" || exit 1
warning_build_dir="$(mktemp -d /private/tmp/streamlab-warnings.XXXXXX)" || exit 1
{
  git rev-parse HEAD
  git status --short
  xcodebuild -version
  echo "DerivedData: $warning_build_dir"
} > "$warning_log_dir/environment.txt" 2>&1
xcodebuild -project StreamLab.xcodeproj -scheme StreamLab -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$warning_build_dir" -resultBundlePath "$warning_log_dir/Build.xcresult" SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO build > "$warning_log_dir/build.log" 2>&1
warning_build_exit=$?
python3 - "$warning_log_dir" "$warning_build_exit" <<'PY'
import pathlib, re, sys
folder = pathlib.Path(sys.argv[1])
code = int(sys.argv[2])
lines = (folder / 'build.log').read_text(errors='replace').splitlines()
warnings = [line for line in lines if re.search(r'\bwarning:', line, re.I)]
(folder / 'warnings.txt').write_text('\n'.join(warnings) + '\n')
summary = f'{"PASS" if code == 0 else "FAIL"} simulator-build exit={code}\n'
summary += ('NOT TESTED warning-free: build failed\n' if code else
            f'{"FAIL" if warnings else "PASS"} warning-free count={len(warnings)}\n')
if warnings:
    summary += '\nBuild warning details:\n' + '\n'.join(warnings) + '\n'
summary += '\nRuntime glassEffect warning: NOT TESTED by this build-only script\n'
(folder / 'RESULTS.txt').write_text(summary)
print(summary)
PY
warning_report_exit=$?
echo "Results: $warning_log_dir/RESULTS.txt"
if [ "$warning_build_exit" -ne 0 ]; then exit "$warning_build_exit"; fi
if [ "$warning_report_exit" -ne 0 ]; then exit "$warning_report_exit"; fi
if grep -q '^FAIL warning-free' "$warning_log_dir/RESULTS.txt"; then exit 1; fi
