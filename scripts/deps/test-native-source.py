#!/usr/bin/env python3
"""Regression tests for iOS source ownership and native provenance boundaries."""

import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location("native_source", Path(__file__).with_name("verify-native-source.py"))
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class NativeSourceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for folder in ("Sources", "Tests", "native", "Binaries"):
            (self.root / "Native" / folder).mkdir(parents=True)
        self.write("Native/Package.swift", 'let package = Package(name: "FearlessNative")')
        self.write("fearless.xcodeproj/project.pbxproj", "relativePath = Native;")
        self.write("Podfile", "platform :ios, '15.0'\n")
        self.write("Native/Binaries/example", "native fixture")
        self.contract = {"schema": 1, "ownership": "soramitsu/fearless-iOS", "sourceRoot": "Native", "nativeBinaries": {"Binaries/example": hashlib.sha256(b"native fixture").hexdigest()}}
        self.write("config/native-sources.json", json.dumps(self.contract))
        for path in VERIFIER.RESOLVED_PATHS:
            self.write(path, json.dumps({"pins": [{"identity": "upstream", "state": {"revision": "a" * 40}}], "version": 3}))

    def write(self, path, value):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(value)

    def test_owned_sources_and_pinned_external_dependencies_pass(self):
        self.assertEqual(VERIFIER.verify(self.root)["nativeBinaryFiles"], 1)

    def test_tracked_native_binary_inventory_passes(self):
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "add", "-f", "Native/Binaries/example"], cwd=self.root, check=True)
        VERIFIER.verify(self.root)

    def test_ignored_local_binary_cannot_qualify_clean_checkout(self):
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        self.write(".gitignore", "Native/Binaries/\n")
        with self.assertRaisesRegex(ValueError, "match tracked files"):
            VERIFIER.verify(self.root)

    def test_ignored_generated_mock_is_rejected(self):
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "add", "-f", "Native/Binaries/example"], cwd=self.root, check=True)
        self.write(".gitignore", "*.generated.swift\n")
        self.write("Native/Sources/Mocks/Example.generated.swift", "struct ExampleMock {}")
        with self.assertRaisesRegex(ValueError, "source files must be tracked"):
            VERIFIER.verify(self.root)

    def test_remote_internal_package_is_rejected(self):
        self.write("Native/Package.swift", 'Package(name: "FearlessNative", url: "https://github.com/soramitsu/shared-features-spm.git")')
        with self.assertRaisesRegex(ValueError, "Retired internal"):
            VERIFIER.verify(self.root)

    def test_private_key_pod_is_rejected(self):
        self.write("Podfile", "pod 'FearlessKeys'")
        with self.assertRaisesRegex(ValueError, "Retired internal"):
            VERIFIER.verify(self.root)

    def test_sibling_package_is_rejected(self):
        self.write("Packages/Other/Package.swift", '.package(path: "../outside")')
        with self.assertRaisesRegex(ValueError, "sibling checkout"):
            VERIFIER.verify(self.root)

    def test_in_repo_sibling_package_is_allowed(self):
        self.write("Packages/Other/Package.swift", '.package(path: "../Owned")')
        self.write("Packages/Owned/Package.swift", 'Package(name: "Owned")')
        VERIFIER.verify(self.root)

    def test_source_symlink_cannot_escape_checkout(self):
        (self.root / "Native/Sources/outside").symlink_to(self.root.parent)
        with self.assertRaisesRegex(ValueError, "escapes"):
            VERIFIER.verify(self.root)

    def test_nested_git_checkout_is_rejected(self):
        self.write("Native/Sources/.git", "gitdir: /somewhere")
        with self.assertRaisesRegex(ValueError, "Nested Git"):
            VERIFIER.verify(self.root)

    def test_changed_native_binary_is_rejected(self):
        self.write("Native/Binaries/example", "different bytes")
        with self.assertRaisesRegex(ValueError, "binary bytes changed"):
            VERIFIER.verify(self.root)

    def test_unrecorded_native_binary_is_rejected(self):
        self.write("Native/Binaries/extra", "extra")
        with self.assertRaisesRegex(ValueError, "inventory differs"):
            VERIFIER.verify(self.root)

    def test_missing_native_binary_is_rejected(self):
        (self.root / "Native/Binaries/example").unlink()
        with self.assertRaisesRegex(ValueError, "inventory differs"):
            VERIFIER.verify(self.root)

    def test_different_resolver_states_are_rejected(self):
        self.write(VERIFIER.RESOLVED_PATHS[0], '{"pins": [], "version": 3}')
        with self.assertRaisesRegex(ValueError, "resolution files differ"):
            VERIFIER.verify(self.root)

    def test_internal_resolver_pin_is_rejected(self):
        for path in VERIFIER.RESOLVED_PATHS:
            self.write(path, json.dumps({"pins": [{"identity": "fearless-starscream", "state": {"revision": "a" * 40}}]}))
        with self.assertRaisesRegex(ValueError, "retired internal repository"):
            VERIFIER.verify(self.root)

    def test_unpinned_external_dependency_is_rejected(self):
        for path in VERIFIER.RESOLVED_PATHS:
            self.write(path, json.dumps({"pins": [{"identity": "upstream", "state": {"branch": "master"}}]}))
        with self.assertRaisesRegex(ValueError, "bound to a commit"):
            VERIFIER.verify(self.root)


if __name__ == "__main__":
    unittest.main()
