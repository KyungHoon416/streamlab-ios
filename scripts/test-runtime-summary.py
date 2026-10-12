#!/usr/bin/env python3
"""A missing capture or unexecuted test must never become a runtime PASS."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("summary", Path(__file__).with_name("summarize-runtime.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RuntimeSummaryTests(unittest.TestCase):
    def check(self, configuration="Release", build=None, runtime=None, alive=True, exit_code=0):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            if build is not None:
                (folder / f"{configuration.lower()}-navigation.log").write_text(build)
            if runtime is not None:
                (folder / "runtime.log").write_text(runtime)
            return module.summarize(folder, exit_code, alive, configuration)

    passed = "Test Case '-[StreamLabUITests testReleaseNavigationSoak]' passed"
    startup = "[Startup] SwiftUI root appeared"

    def test_configuration_labels_and_success(self):
        for config in ("Debug", "Release"):
            with self.subTest(config=config):
                lines, status = self.check(config, self.passed, self.startup)
                self.assertEqual(status, 0)
                self.assertIn(f"PASS {config.lower()}-navigation-60", lines[0])

    def test_missing_capture_cannot_pass(self):
        for runtime, alive in ((None, True), ("", True), (self.startup, False)):
            lines, status = self.check(build=self.passed, runtime=runtime, alive=alive)
            self.assertEqual(status, 1)
            self.assertTrue(any("NOT TESTED" in line for line in lines))

    def test_missing_build_cannot_pass(self):
        _, status = self.check(runtime=self.startup)
        self.assertEqual(status, 1)

    def test_zero_exit_without_selected_test_cannot_pass(self):
        lines, status = self.check(build="BUILD SUCCEEDED", runtime=self.startup)
        self.assertEqual(status, 1)
        self.assertIn("test-observed=False", lines[0])

    def test_glass_warning_in_either_log_fails(self):
        warning = "glassEffect() tried to update multiple times per frame."
        for build, runtime in ((self.passed, self.startup + warning),
                               (self.passed + warning, self.startup)):
            lines, status = self.check("Debug", build, runtime)
            self.assertEqual(status, 1)
            self.assertTrue(any(line.startswith("FAIL runtime-glass") for line in lines))

    def test_build_warning_or_failed_test_cannot_pass(self):
        for build, code in ((self.passed + "\nwarning: example", 0), (self.passed, 65)):
            _, status = self.check(build=build, runtime=self.startup, exit_code=code)
            self.assertEqual(status, 1)


if __name__ == "__main__":
    unittest.main()
