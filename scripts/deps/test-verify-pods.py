#!/usr/bin/env python3
"""Tests for scripts/deps/verify-pods.py."""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("verify_pods", Path(__file__).with_name("verify-pods.py"))
PODS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PODS)


class VerifyPodsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "config").mkdir()
        self.pods = self.root / "Pods"
        for name in PODS.SOURCE_PODS:
            self.write("Pods/%s/Sources/%s.swift" % (name, name.replace(".", "")), "// %s\n" % name)
        for relative in PODS.TOOLS:
            self.write("Pods/" + relative, "#!/bin/sh\nexit 0\n")
            os.chmod(self.pods / relative, 0o755)
        PODS.record(self.root, self.pods)

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def test_recorded_install_passes(self):
        self.assertEqual(PODS.verify(self.root), {"pods": len(PODS.SOURCE_PODS), "tools": len(PODS.TOOLS)})

    def test_edited_pod_source_fails(self):
        self.write("Pods/SoraUI/Sources/SoraUI.swift", "// moved tag\n")
        with self.assertRaisesRegex(PODS.PodsVerificationError, "SoraUI"):
            PODS.verify(self.root)

    def test_added_pod_file_fails(self):
        self.write("Pods/SVGKit/Sources/Injected.m", "// injected\n")
        with self.assertRaisesRegex(PODS.PodsVerificationError, "SVGKit"):
            PODS.verify(self.root)

    def test_replaced_build_tool_fails(self):
        self.write("Pods/R.swift/rswift", "#!/bin/sh\necho owned\n")
        with self.assertRaisesRegex(PODS.PodsVerificationError, "R.swift/rswift"):
            PODS.verify(self.root)

    def test_executable_bit_change_fails(self):
        os.chmod(self.pods / "SoraKeystore/Sources/SoraKeystore.swift", 0o755)
        with self.assertRaisesRegex(PODS.PodsVerificationError, "SoraKeystore"):
            PODS.verify(self.root)

    def test_missing_pod_fails(self):
        import shutil
        shutil.rmtree(self.pods / "Charts")
        with self.assertRaisesRegex(PODS.PodsVerificationError, "Charts"):
            PODS.verify(self.root)

    def test_pins_must_cover_exactly_the_checked_set(self):
        pins = json.loads((self.root / PODS.PINS).read_text())
        del pins["pods"]["MediaView"]
        (self.root / PODS.PINS).write_text(json.dumps(pins))
        with self.assertRaisesRegex(PODS.PodsVerificationError, "exactly"):
            PODS.verify(self.root)


if __name__ == "__main__":
    unittest.main()
