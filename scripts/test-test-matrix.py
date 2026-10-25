#!/usr/bin/env python3
"""Exercise the real matrix entry point with isolated command substitutes."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class TestMatrixVerification(unittest.TestCase):
    def run_matrix(self, fail_verification=0, fail_resolution=False):
        with tempfile.TemporaryDirectory(prefix="fearless-matrix-test-") as temp:
            root = Path(temp)
            (root / "scripts/deps").mkdir(parents=True)
            source = Path(__file__).with_name("test-matrix.sh").read_bytes()
            (root / "scripts/test-matrix.sh").write_bytes(source)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            log = root / "commands.jsonl"
            substitute = f"#!{sys.executable}\n" + '''import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
log = pathlib.Path(os.environ["MATRIX_TEST_LOG"])
prior = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
args = sys.argv[1:]
with log.open("a") as output:
    output.write(json.dumps([name, args]) + "\\n")
if name == "python3" and args and args[0].endswith("verify-native-source.py"):
    count = 1 + sum(n == name and a and a[0] == args[0] for n, a in prior)
    if count == int(os.environ["MATRIX_TEST_FAIL_VERIFICATION"]):
        sys.exit(42)
if name == "xcodebuild" and "-resolvePackageDependencies" in args and os.environ["MATRIX_TEST_FAIL_RESOLUTION"] == "1":
    sys.exit(37)
if name == "uname":
    print("arm64")
if name == "xcpretty":
    sys.stdout.write(sys.stdin.read())
'''
            for name in ["python3", "xcodebuild", "uname", "xcpretty", "find", "rm"]:
                path = bin_dir / name
                path.write_text(substitute)
                path.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
                       TMPDIR=str(root), MATRIX_TEST_LOG=str(log),
                       MATRIX_TEST_FAIL_VERIFICATION=str(fail_verification),
                       MATRIX_TEST_FAIL_RESOLUTION=str(int(fail_resolution)))
            result = subprocess.run(
                ["/bin/bash", "scripts/test-matrix.sh", "fearless.tests",
                 "platform=iOS Simulator,id=isolated-test"],
                cwd=root, env=env, capture_output=True, text=True, timeout=20)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            return result, calls

    def phases(self, calls):
        phases = []
        for name, args in calls:
            if name == "python3" and args[0].endswith("verify-native-source.py"):
                phases.append("verify")
            if name == "xcodebuild":
                phases.append("resolve" if "-resolvePackageDependencies" in args else
                              args[args.index("-configuration") + 1])
        return phases

    def test_each_configuration_revalidates_resolved_source_before_build(self):
        result, calls = self.run_matrix()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.phases(calls), ["verify", "resolve", "verify", "verify", "Debug", "verify", "Release"])

    def test_debug_verification_failure_prevents_all_test_builds(self):
        result, calls = self.run_matrix(fail_verification=3)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(self.phases(calls), ["verify", "resolve", "verify", "verify"])

    def test_release_verification_failure_prevents_release_test_build(self):
        result, calls = self.run_matrix(fail_verification=4)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(self.phases(calls), ["verify", "resolve", "verify", "verify", "Debug", "verify"])

    def test_owned_source_failure_prevents_resolution_and_builds(self):
        result, calls = self.run_matrix(fail_verification=1)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(self.phases(calls), ["verify"])

    def test_resolution_failure_prevents_verification_and_test_builds(self):
        result, calls = self.run_matrix(fail_resolution=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(self.phases(calls), ["verify", "resolve"])


if __name__ == "__main__":
    unittest.main()
