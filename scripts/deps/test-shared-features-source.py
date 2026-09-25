#!/usr/bin/env python3
"""Exercise source substitution, dirty-tree and pin-confusion rejection."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("source_verifier", Path(__file__).with_name("verify-shared-features-source.py"))
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)
AUDIT_SPEC = importlib.util.spec_from_file_location("source_audit", Path(__file__).with_name("audit-pinned-shared-features.py"))
AUDIT = importlib.util.module_from_spec(AUDIT_SPEC)
AUDIT_SPEC.loader.exec_module(AUDIT)


class SourceVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="fearless-source-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.transport_checkout = self.root / "SourcePackages/checkouts/fearless-starscream"
        self.transport_checkout.mkdir(parents=True)
        for arguments in [("init", "--quiet"), ("config", "user.email", "fixture@example.invalid"), ("config", "user.name", "Transport fixture")]:
            self.transport_git(*arguments)
        (self.transport_checkout / "Transport.swift").write_text("let guarded = true\n")
        (self.transport_checkout / ".gitignore").write_text("*.ignored\n")
        self.transport_git("add", ".")
        self.transport_git("commit", "--quiet", "-m", "transport fixture")
        self.transport_identity = {
            "schema": 1, "repository": "https://github.com/soramitsu/fearless-starscream",
            "revision": self.transport_git("rev-parse", "HEAD").strip(),
            "tree": self.transport_git("rev-parse", "HEAD^{tree}").strip(),
            "baseRevision": "b" * 40, "reviewUrl": "https://github.com/soramitsu/fearless-starscream/pull/5",
        }
        self.checkout = self.root / "SourcePackages/checkouts/shared-features-spm"
        self.checkout.mkdir(parents=True)
        self.run_git("init", "--quiet")
        self.run_git("config", "user.email", "fixture@example.invalid")
        self.run_git("config", "user.name", "Source fixture")
        self.write("source.swift", "let value = 1\n")
        self.write(".gitignore", "*.ignored\n")
        self.write("Package.swift", f'.package(url: "{self.transport_identity["repository"]}", .revision("{self.transport_identity["revision"]}"))\n')
        self.run_git("add", ".")
        self.run_git("commit", "--quiet", "-m", "fixture")
        self.identity = {
            "schema": 1, "repository": "https://github.com/soramitsu/shared-features-spm.git",
            "revision": self.run_git("rev-parse", "HEAD").strip(),
            "tree": self.run_git("rev-parse", "HEAD^{tree}").strip(),
            "baseRevision": "a" * 40, "reviewUrl": "https://github.com/soramitsu/shared-features-spm/pull/82",
            "carriedDeltas": sorted(VERIFIER.DELTA_IDS),
        }
        self.prepare_pins()

    def run_git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.checkout), *arguments], text=True, stderr=subprocess.PIPE)

    def transport_git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.transport_checkout), *arguments], text=True, stderr=subprocess.PIPE)

    def write(self, name, text):
        (self.checkout / name).write_text(text)

    def prepare_pins(self):
        files = {
            "config/shared-features-source.json": json.dumps(self.identity),
            "config/starscream-source.json": json.dumps(self.transport_identity),
            "Packages/FearlessUtilsCompat/Package.swift": f'.package(url: "{self.identity["repository"]}", revision: "{self.identity["revision"]}")',
            "fearless.xcodeproj/project.pbxproj": f'repositoryURL = "{self.identity["repository"]}"; requirement = {{ kind = revision; revision = {self.identity["revision"]}; }};',
        }
        for name in ["fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved", "fearless.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"]:
            files[name] = json.dumps({"pins": [
                {"identity": "shared-features-spm", "kind": "remoteSourceControl", "location": self.identity["repository"], "state": {"revision": self.identity["revision"]}},
                {"identity": "fearless-starscream", "kind": "remoteSourceControl", "location": self.transport_identity["repository"], "state": {"revision": self.transport_identity["revision"]}},
            ]})
        for name, data in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(data)

    def verify(self):
        return VERIFIER.verify_checkout(self.checkout, self.identity)

    def test_clean_pinned_tree_and_all_pins_pass(self):
        self.assertEqual(self.verify(), 3)
        self.assertEqual(VERIFIER.contract(self.root), self.identity)
        VERIFIER.verify_pins(self.root, self.identity)
        self.assertEqual(self.run_git("status", "--porcelain"), "")

    def test_complete_graph_verifies_both_actual_sources(self):
        result = VERIFIER.verify_dependency_graph(self.root, self.root / "SourcePackages")
        self.assertEqual(result["verifiedFileCounts"], {"shared-features-spm": 3, "fearless-starscream": 2})
        self.assertEqual(result["transport"], self.transport_identity)

    def test_transport_contract_required_even_for_pins_only(self):
        (self.root / "config/starscream-source.json").unlink()
        with self.assertRaises(OSError): VERIFIER.verify_dependency_graph(self.root)

    def test_transport_contract_rejects_malformed_identity(self):
        for key, value in [("schema", True), ("revision", "develop"), ("tree", "bad"), ("baseRevision", "bad"), ("repository", "https://example.invalid"), ("reviewUrl", "https://example.invalid/pull/5"), ("extra", True)]:
            with self.subTest(key=key):
                wrong = copy.deepcopy(self.transport_identity)
                wrong[key] = value
                (self.root / "config/starscream-source.json").write_text(json.dumps(wrong))
                with self.assertRaises(ValueError): VERIFIER.verify_dependency_graph(self.root)

    def test_duplicate_contract_fields_rejected(self):
        for name in ["config/shared-features-source.json", "config/starscream-source.json"]:
            path = self.root / name
            original = path.read_text()
            path.write_text(original[:-1] + ', "schema": 1}')
            with self.assertRaises(ValueError): VERIFIER.verify_dependency_graph(self.root)
            path.write_text(original)

    def test_transport_resolver_substitution_rejected(self):
        for name in VERIFIER.RESOLVED_PATHS:
            for mutation in ["revision", "branch", "location", "kind", "duplicate", "missing"]:
                with self.subTest(path=name, mutation=mutation):
                    self.prepare_pins()
                    path = self.root / name
                    value = json.loads(path.read_text())
                    pin = value["pins"][1]
                    if mutation == "revision": pin["state"]["revision"] = "0" * 40
                    elif mutation == "branch": pin["state"]["branch"] = "main"
                    elif mutation == "location": pin["location"] = "https://example.invalid"
                    elif mutation == "kind": pin["kind"] = "fileSystem"
                    elif mutation == "duplicate": value["pins"].append(copy.deepcopy(pin))
                    elif mutation == "missing": value["pins"].pop()
                    path.write_text(json.dumps(value))
                    with self.assertRaises(ValueError): VERIFIER.verify_dependency_graph(self.root)

    def test_transport_hidden_source_change_blocks_graph_and_audit(self):
        self.prepare_audit()
        self.transport_git("update-index", "--assume-unchanged", "Transport.swift")
        (self.transport_checkout / "Transport.swift").write_text("let guarded = false\n")
        self.assertEqual(self.transport_git("status", "--porcelain"), "")
        with self.assertRaises(ValueError): VERIFIER.verify_dependency_graph(self.root, self.root / "SourcePackages")
        self.assertEqual(self.report()["removalReadiness"]["status"], "blocked")

    def test_transport_additional_ignored_source_rejected(self):
        (self.transport_checkout / "Injected.ignored").write_text("unexpected")
        with self.assertRaises(ValueError): VERIFIER.verify_dependency_graph(self.root, self.root / "SourcePackages")

    def test_wrong_transport_checkout_revision_rejected(self):
        (self.transport_checkout / "Transport.swift").write_text("let guarded = false\n")
        self.transport_git("commit", "-am", "different implementation", "--quiet")
        with self.assertRaises(ValueError): VERIFIER.verify_dependency_graph(self.root, self.root / "SourcePackages")

    def test_committed_sdk_cannot_select_different_transport(self):
        path = self.checkout / "Package.swift"
        path.write_text(path.read_text().replace(self.transport_identity["revision"], "0" * 40))
        self.run_git("commit", "-am", "wrong transport", "--quiet")
        self.identity["revision"] = self.run_git("rev-parse", "HEAD").strip()
        self.identity["tree"] = self.run_git("rev-parse", "HEAD^{tree}").strip()
        self.prepare_pins()
        with self.assertRaisesRegex(ValueError, "guarded transport source pin"):
            VERIFIER.verify_dependency_graph(self.root, self.root / "SourcePackages")

    def test_dirty_tracked_source_rejected(self):
        self.write("source.swift", "let value = 2\n")
        with self.assertRaises(ValueError): self.verify()

    def test_assume_unchanged_does_not_hide_substitution(self):
        self.run_git("update-index", "--assume-unchanged", "source.swift")
        self.write("source.swift", "let value = 9\n")
        self.assertEqual(self.run_git("status", "--porcelain"), "")
        with self.assertRaises(ValueError): self.verify()

    def test_staged_substitution_rejected_even_if_working_bytes_restored(self):
        self.write("source.swift", "let value = 3\n")
        self.run_git("add", "source.swift")
        self.write("source.swift", "let value = 1\n")
        with self.assertRaises(ValueError): self.verify()

    def test_ignored_additional_source_rejected(self):
        self.write("malicious.ignored", "extra Swift source")
        self.assertEqual(self.run_git("status", "--porcelain"), "")
        with self.assertRaises(ValueError): self.verify()

    def test_untracked_source_rejected(self):
        self.write("additional.swift", "unexpected")
        with self.assertRaises(ValueError): self.verify()

    def test_executable_mode_change_rejected(self):
        (self.checkout / "source.swift").chmod(0o755)
        with self.assertRaises(ValueError): self.verify()

    def test_missing_file_rejected(self):
        (self.checkout / "source.swift").unlink()
        with self.assertRaises(OSError): self.verify()

    def test_symlink_substitution_rejected(self):
        path = self.checkout / "source.swift"
        original = path.read_bytes()
        path.unlink()
        (self.root / "outside.swift").write_bytes(original)
        path.symlink_to(self.root / "outside.swift")
        with self.assertRaises(ValueError): self.verify()

    def test_wrong_revision_and_tree_rejected(self):
        for key in ["revision", "tree"]:
            with self.subTest(key=key):
                wrong = copy.deepcopy(self.identity)
                wrong[key] = "0" * 40
                with self.assertRaises(ValueError): VERIFIER.verify_checkout(self.checkout, wrong)

    def test_nested_directory_is_not_a_checkout(self):
        nested = self.checkout / "nested"
        nested.mkdir()
        with self.assertRaises(ValueError): VERIFIER.verify_checkout(nested, self.identity)

    def test_mutated_source_contract_rejected(self):
        for key, value in [("schema", True), ("revision", "main"), ("repository", "https://example.invalid/replacement"), ("reviewUrl", "https://example.invalid/pull/83"), ("carriedDeltas", ["fake"] * 11), ("unexpected", 1)]:
            with self.subTest(key=key):
                wrong = copy.deepcopy(self.identity)
                wrong[key] = value
                (self.root / "config/shared-features-source.json").write_text(json.dumps(wrong))
                with self.assertRaises(ValueError): VERIFIER.contract(self.root)

    def test_every_pin_source_rejects_mismatch(self):
        for path in ["fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved", "fearless.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved", "Packages/FearlessUtilsCompat/Package.swift", "fearless.xcodeproj/project.pbxproj"]:
            with self.subTest(path=path):
                self.prepare_pins()
                file = self.root / path
                file.write_text(file.read_text().replace(self.identity["revision"], "0" * 40))
                with self.assertRaises(ValueError): VERIFIER.verify_pins(self.root, self.identity)

    def test_ambiguous_branch_and_revision_pin_rejected(self):
        path = self.root / "fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        value = json.loads(path.read_text())
        value["pins"][0]["state"]["branch"] = "develop"
        path.write_text(json.dumps(value))
        with self.assertRaises(ValueError): VERIFIER.verify_pins(self.root, self.identity)

    def test_local_package_substitution_rejected(self):
        path = self.root / "fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        value = json.loads(path.read_text())
        value["pins"][0]["kind"] = "fileSystem"
        path.write_text(json.dumps(value))
        with self.assertRaises(ValueError): VERIFIER.verify_pins(self.root, self.identity)

    def prepare_audit(self):
        source_root = Path(__file__).resolve().parents[2]
        files = ["scripts/deps/check-shared-features-fix-wiring.sh",
                 "scripts/spm-shared-features-fixes.sh", "scripts/deps/prepare-native-crypto-checkout.sh",
                 "scripts/deps/apply-native-crypto-package-contract.sh", "scripts/deps/apply-native-crypto-modulemap-contract.sh",
                 "scripts/deps/templates/IrohaCrypto.module.modulemap", "scripts/deps/templates/IrohaCrypto-umbrella.h",
                 "scripts/deps/templates/IrohaCrypto.linker-settings.swiftfrag"]
        for name in files:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_root / name, target)
        for name in ["scripts/test-matrix.sh", "scripts/dev-setup.sh", "scripts/ci/bootstrap.sh", "scripts/ci/run-pr.sh", ".github/workflows/codecov.yml"]:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('python3 scripts/deps/verify-shared-features-source.py "$ROOT"\n')
        project = self.root / "fearless.xcodeproj/project.pbxproj"
        project.write_text(project.read_text() + '\npython3 scripts/deps/verify-shared-features-source.py "$ROOT"\n')

    def report(self):
        return AUDIT.audit(self.root, self.root / "SourcePackages")

    def test_ready_source_does_not_claim_release_qualification(self):
        self.prepare_audit()
        report = self.report()
        self.assertEqual(report["removalReadiness"]["status"], "ready")
        self.assertFalse(report["mutatesResolvedCheckout"])
        self.assertFalse(report["releaseQualified"])
        self.assertEqual(len(report["carriedDeltas"]), 11)

    def test_dirty_source_blocks_ready_report(self):
        self.prepare_audit()
        self.write("source.swift", "substituted")
        self.assertEqual(self.report()["removalReadiness"]["status"], "blocked")

    def test_missing_build_verification_blocks_report(self):
        self.prepare_audit()
        (self.root / "scripts/ci/run-pr.sh").write_text("echo skipped\n")
        self.assertEqual(self.report()["removalReadiness"]["status"], "blocked")

    def test_ignored_verification_failure_blocks_report(self):
        self.prepare_audit()
        (self.root / "scripts/ci/run-pr.sh").write_text('python3 scripts/deps/verify-shared-features-source.py "$ROOT" || true\n')
        self.assertEqual(self.report()["removalReadiness"]["status"], "blocked")

    def test_restored_patch_call_blocks_report(self):
        self.prepare_audit()
        path = self.root / "scripts/ci/bootstrap.sh"
        path.write_text(path.read_text() + 'bash scripts/spm-shared-features-fixes.sh "$ROOT"\n')
        self.assertEqual(self.report()["removalReadiness"]["status"], "blocked")

    def test_compatibility_helper_cannot_reinstate_mutation(self):
        self.prepare_audit()
        path = self.root / "scripts/deps/apply-native-crypto-package-contract.sh"
        path.write_text(path.read_text() + "touch dependency.swift\n")
        report = self.report()
        self.assertEqual(report["removalReadiness"]["status"], "blocked")
        self.assertTrue(report["mutatesResolvedCheckout"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
