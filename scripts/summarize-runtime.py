#!/usr/bin/env python3
"""Report only the diagnostics actually captured; missing logs never mean PASS."""
from pathlib import Path
import re
import sys


def summarize(folder: Path, test_exit: int, stream_alive: bool, configuration: str = "Release") -> tuple[list[str], int]:
    if configuration not in ("Debug", "Release"):
        raise ValueError("configuration must be Debug or Release")
    label = configuration.lower()
    build_path = folder / f"{label}-navigation.log"
    runtime_path = folder / "runtime.log"
    if not build_path.is_file() or not runtime_path.is_file():
        return [f"NOT TESTED {label}-navigation/runtime-glass: required logs missing"], 1
    build = build_path.read_text(errors="replace")
    runtime = (folder / "runtime.log").read_text(errors="replace")
    # xcodebuild can exit 0 without executing the selected test if selection drifts.
    executed = bool(re.search(r"Test Case .*testReleaseNavigationSoak.* passed", build))
    test_passed = test_exit == 0 and executed
    lines = [f"{'PASS' if test_passed else 'FAIL'} {label}-navigation-60 exit={test_exit} test-observed={executed}"]
    warnings = [line for line in build.splitlines() if re.search(r"\bwarning:", line, re.I)]
    (folder / "build-warnings.txt").write_text("\n".join(warnings))
    if test_passed:
        lines.append(f"{'FAIL' if warnings else 'PASS'} {label}-build-warning-free count={len(warnings)}")
    else:
        lines.append(f"NOT TESTED {label}-build-warning-free: {configuration} regression did not pass")
    diagnostics = [line for line in (runtime + "\n" + build).splitlines()
                   if re.search(r"glassEffect\(\).*multiple times per frame|Terminating app due to uncaught exception|Swift runtime failure", line)]
    (folder / "runtime-diagnostics.txt").write_text("\n".join(diagnostics))
    captured = stream_alive and "[Startup] SwiftUI root appeared" in runtime
    if diagnostics:
        lines.append(f"FAIL runtime-glass/crash-diagnostics count={len(diagnostics)} (see runtime-diagnostics.txt)")
    elif not captured or not test_passed:
        lines.append("NOT TESTED runtime-glass: complete app log capture and passing navigation test required")
    else:
        lines.append("PASS runtime-glass: no matching diagnostic during captured 60-cycle run only")
    return lines, 0 if test_passed and not warnings and captured and not diagnostics else 1


if __name__ == "__main__":
    output, status = summarize(Path(sys.argv[1]), int(sys.argv[2]), sys.argv[3] == "1", sys.argv[4] if len(sys.argv) > 4 else "Release")
    print("\n".join(output))
    sys.exit(status)
