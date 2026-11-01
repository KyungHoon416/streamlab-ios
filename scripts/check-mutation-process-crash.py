#!/usr/bin/env python3
"""Kill only owned probe children at explicit durable boundaries, then relaunch."""
import pathlib
import signal
import subprocess
import sys
import tempfile
import time


def run(binary):
    with tempfile.TemporaryDirectory(prefix="streamlab-f03-process-") as directory:
        root = pathlib.Path(directory)
        for phase in ("seed", "send"):
            with (root / (phase + ".log")).open("w+") as log:
                process = subprocess.Popen([binary, phase, directory], stdout=log, stderr=log)
                try:
                    deadline = time.monotonic() + 30
                    ready = root / (phase + ".ready")
                    while not ready.exists():
                        if process.poll() is not None or time.monotonic() >= deadline:
                            log.seek(0)
                            raise RuntimeError(f"{phase} readiness failed: {log.read()}")
                        time.sleep(0.02)
                    if ready.read_text() != phase or process.poll() is not None:
                        raise RuntimeError(f"{phase} did not remain alive at boundary")
                    process.kill()
                    if process.wait(timeout=10) != -signal.SIGKILL:
                        raise RuntimeError(f"{phase} was not terminated by SIGKILL")
                    print(f"F03 PROCESS KILLED phase={phase} signal=SIGKILL", flush=True)
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.wait(timeout=10)
        for phase, marker in (
            ("recover", "F03 PROCESS RECOVERED mutations=100 serverEffects=100 pending=0 lost=0"),
            ("verify", "F03 PROCESS VERIFIED durableACKs=100 pending=0"),
        ):
            result = subprocess.run([binary, phase, directory], capture_output=True, text=True, timeout=30)
            if result.returncode != 0 or marker not in result.stdout.splitlines():
                raise RuntimeError(f"{phase} failed: {result.stdout}\n{result.stderr}")
            print(result.stdout, end="", flush=True)
    print("F03 PROCESS PASS kills=2 restarts=3 mutations=100 duplicateEffects=0 lost=0", flush=True)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: check-mutation-process-crash.py /absolute/path/to/F03CrashProbe")
    run(str(pathlib.Path(sys.argv[1]).resolve(strict=True)))
