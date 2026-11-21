#!/usr/bin/env python3
"""Exercise the offline build, receipt and upstream source checks."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("build_tools", Path(__file__).with_name("verify-build-tools.py"))
TOOLS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOLS)


class BuildToolsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.package = self.root / "BuildTools"
        shutil.copytree(Path(__file__).resolve().parents[2] / "BuildTools", self.package)
        self.products = self.root / "build/source-tools/bin"
        self.calls = self.root / "calls"
        xcrun = self.root / "xcrun"
        xcrun.write_text("""#!/bin/sh
set -eu
shift 2
case "$1" in
    swiftc) echo 'fixture compiler' ;;
    swift)
        stage=$4
        case "$*" in
            *--show-bin-path) echo "$stage/products" ;;
            *)
                echo build >> "$BUILD_CALLS"
                test -z "${BUILD_FAIL:-}"
                mkdir "$stage/products"
                for tool in rswift swiftformat; do
                    echo "$tool" > "$stage/products/$tool"
                    chmod +x "$stage/products/$tool"
                done
                ;;
        esac ;;
    *) exit 2 ;;
esac
""")
        xcrun.chmod(0o755)
        environment = patch.dict(os.environ, {"PATH": str(self.root) + ":" + os.environ["PATH"],
                                              "BUILD_CALLS": str(self.calls), "BUILD_FAIL": ""})
        environment.start()
        self.addCleanup(environment.stop)

    def test_build_reuses_only_current_products_and_force_recompiles(self):
        TOOLS.build(self.root, False)
        TOOLS.build(self.root, False)
        self.assertEqual(self.calls.read_text(), "build\n")
        TOOLS.build(self.root, True)
        self.assertEqual(self.calls.read_text(), "build\nbuild\n")
        TOOLS.verify_products(self.products, TOOLS.source_inputs(self.package))

    def test_replaced_deleted_and_symlinked_products_fail_verification(self):
        TOOLS.build(self.root, False)
        inputs = TOOLS.source_inputs(self.package)
        tool = self.products / "rswift"
        tool.write_text("replaced")
        with self.assertRaisesRegex(ValueError, "receipt"):
            TOOLS.verify_products(self.products, inputs)
        tool.unlink()
        with self.assertRaisesRegex(ValueError, "missing executable"):
            TOOLS.verify_products(self.products, inputs)
        tool.symlink_to("swiftformat")
        with self.assertRaisesRegex(ValueError, "missing executable"):
            TOOLS.verify_products(self.products, inputs)
        TOOLS.build(self.root, False)
        TOOLS.verify_products(self.products, inputs)

    def test_changed_source_fails_before_building(self):
        (self.package / "Vendor/swiftformat/CommandLineTool/main.swift").write_text("// replacement")
        with self.assertRaisesRegex(ValueError, "sources differ"):
            TOOLS.build(self.root, False)
        self.assertFalse(self.calls.exists())

    def test_added_source_fails(self):
        (self.package / "Vendor/Commander/Sources/extra.swift").touch()
        with self.assertRaisesRegex(ValueError, "Commander"):
            TOOLS.source_inputs(self.package)

    def test_local_manifest_change_invalidates_products(self):
        TOOLS.build(self.root, False)
        with (self.package / "Package.swift").open("a") as manifest:
            manifest.write("// edited\n")
        with self.assertRaisesRegex(ValueError, "receipt"):
            TOOLS.verify_products(self.products, TOOLS.source_inputs(self.package))

    def test_revision_must_be_the_upstream_commit_containing_the_sources(self):
        pins_file = self.package / "sources.json"
        pins = json.loads(pins_file.read_text())
        pins["rswift"]["revision"] = "a" * 40
        pins_file.write_text(json.dumps(pins))
        with self.assertRaisesRegex(ValueError, "revision"):
            TOOLS.source_inputs(self.package)

    def test_failed_build_preserves_existing_products(self):
        TOOLS.build(self.root, False)
        with patch.dict(os.environ, {"BUILD_FAIL": "1"}), self.assertRaises(subprocess.CalledProcessError):
            TOOLS.build(self.root, True)
        TOOLS.verify_products(self.products, TOOLS.source_inputs(self.package))

    def test_output_must_be_inside_the_worktree(self):
        (self.root / "elsewhere").mkdir()
        (self.root / "build").symlink_to(self.root / "elsewhere")
        with self.assertRaisesRegex(ValueError, "symlink"):
            TOOLS.build(self.root, False)
        self.assertEqual(list((self.root / "elsewhere").iterdir()), [])


if __name__ == "__main__":
    unittest.main()
