import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import qualify


class ResultGateTests(unittest.TestCase):
    def setUp(self):
        self.inventory = {"compiledSourceCommit": "original", "tests": ["Import/testA()", "Import/testB()"]}
        self.device = dict(deviceId="owned", osVersion="26.5", platform="iOS Simulator")
        self.run = dict(sourceCommit="original", device="owned", exitCode=0)
        self.summary = dict(result="Passed", totalTestCount=2, passedTests=2, failedTests=0, skippedTests=0,
                            expectedFailures=0, testFailures=[], devicesAndConfigurations=[dict(
                                device=self.device, passedTests=2, failedTests=0, skippedTests=0, expectedFailures=0)])
        self.tests = dict(devices=[self.device], testNodes=[dict(nodeType="Test Suite", children=[
            dict(nodeType="Test Case", nodeIdentifier=name, result="Passed") for name in self.inventory["tests"]])])

    def check(self):
        qualify.check_results(self.run, self.summary, self.tests, self.inventory, "owned", "26.5")

    def test_exact_named_results_pass(self):
        self.check()

    def test_same_count_cannot_replace_required_test(self):
        self.tests["testNodes"][0]["children"][0]["nodeIdentifier"] = "Import/testUnlisted()"
        with self.assertRaisesRegex(ValueError, "unlisted"):
            self.check()

    def test_missing_duplicate_and_empty_inventory_fail(self):
        for kind in ("missing", "duplicate", "empty"):
            with self.subTest(kind=kind):
                self.setUp()
                nodes = self.tests["testNodes"][0]["children"]
                if kind == "missing":
                    nodes.pop()
                elif kind == "duplicate":
                    nodes[1] = copy.deepcopy(nodes[0])
                else:
                    self.inventory["tests"] = []
                with self.assertRaises(ValueError):
                    self.check()

    def test_skipped_failed_expected_failure_cannot_be_green_summary(self):
        for status in ("Skipped", "Failed", "Expected Failure"):
            with self.subTest(status=status):
                self.tests["testNodes"][0]["children"][0]["result"] = status
                with self.assertRaisesRegex(ValueError, "nonpassing"):
                    self.check()

    def test_source_device_runtime_and_process_failure_are_bound(self):
        for target, key, bad in (("run", "sourceCommit", "new"), ("run", "device", "other"),
                                 ("run", "exitCode", 65), ("device", "osVersion", "27.0")):
            with self.subTest(key=key):
                self.setUp()
                getattr(self, target)[key] = bad
                with self.assertRaises(ValueError):
                    self.check()

    def test_summary_counts_and_hidden_failures_must_match(self):
        for key, bad in (("totalTestCount", 3), ("passedTests", 1), ("failedTests", 1), ("skippedTests", 1),
                         ("expectedFailures", 1), ("testFailures", [{"message": "failure"}])):
            with self.subTest(key=key):
                self.setUp()
                self.summary[key] = bad
                with self.assertRaises(ValueError):
                    self.check()

    def test_artifact_missing_drift_or_unlisted_file_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            products = root / "Products"
            app = products / "app/fearless.debug.dylib"
            bundle = products / "app/PlugIns/fearlessTests.xctest/fearlessTests"
            bundle.parent.mkdir(parents=True)
            app.write_bytes(b"app")
            bundle.write_bytes(b"tests")
            pins = [dict(path=str(p), bytes=p.stat().st_size, sha256=hashlib.sha256(p.read_bytes()).hexdigest())
                    for p in (app, bundle)]
            (root / "freeze.json").write_text(json.dumps(dict(readerCommit="original", files=pins)))
            self.assertEqual(qualify.check_reader(root, self.inventory), 2)
            bundle.write_bytes(b"drift")
            with self.assertRaisesRegex(ValueError, "artifact drift"):
                qualify.check_reader(root, self.inventory)
            bundle.write_bytes(b"tests")
            extra = products / "extra"
            extra.write_bytes(b"unlisted")
            with self.assertRaisesRegex(ValueError, "unlisted"):
                qualify.check_reader(root, self.inventory)
            extra.unlink()
            bundle.unlink()
            with self.assertRaisesRegex(ValueError, "missing artifact"):
                qualify.check_reader(root, self.inventory)


if __name__ == "__main__":
    unittest.main()
