#!/usr/bin/env python3

from __future__ import annotations

import copy
import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("audit-testflight-upgrade-usability-gate.py")
SPEC = importlib.util.spec_from_file_location("upgrade_gate", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)
EXPECTED_ARTIFACT_SOURCE_COMMIT = "a" * 40


def passing_evidence() -> dict:
    return {
        "schemaVersion": 1,
        "bundleIdentifier": "jp.co.soramitsu.fearlesswallet",
        "marketingVersion": "4.2.0",
        "buildVersion": "2026.8.10",
        "baseSourceCommit": "2e45e55dc03ad904598e730cfb5994fb5c1072dc",
        "artifactSourceCommit": EXPECTED_ARTIFACT_SOURCE_COMMIT,
        "distribution": "apple-testflight-internal",
        "installation": {
            "installedInPlace": True,
            "previousBuildVersion": "2026.7.28",
            "uninstalled": False,
            "offloaded": False,
            "downgraded": False,
            "dataCleared": False,
            "keychainReset": False,
        },
        "firstLaunch": {
            "startedAt": "2026-08-10T12:00:00+09:00",
            "completedAt": "2026-08-10T12:05:00+09:00",
            "coldLaunch": True,
            "readyMarkerCount": 1,
            "failedMarkerCount": 0,
            "failureAlertShown": False,
            "pinAccepted": True,
            "walletRouteWorked": True,
        },
        "preservation": {
            "appContainerPreserved": True,
            "walletCountsUnchanged": True,
            "logicalStoreIntegrityPassed": True,
            "keychainAccessible": True,
            "settingsAccessible": True,
        },
        "secondColdLaunch": {
            "coldLaunch": True,
            "readyMarkerCount": 1,
            "failedMarkerCount": 0,
            "failureAlertShown": False,
            "pinAccepted": True,
            "walletRouteWorked": True,
        },
        "release": {
            "internalGroupValidatedFirst": True,
            "publicBetaReplacedBeforeGate": False,
        },
    }


class UpgradeUsabilityGateTests(unittest.TestCase):
    def test_accepts_complete_sanitized_five_minute_gate(self) -> None:
        GATE.validate(passing_evidence(), EXPECTED_ARTIFACT_SOURCE_COMMIT)

    def test_rejects_process_liveness_sized_window(self) -> None:
        evidence = passing_evidence()
        evidence["firstLaunch"]["completedAt"] = "2026-08-10T12:00:45+09:00"

        with self.assertRaisesRegex(GATE.EvidenceError, "at least five minutes"):
            GATE.validate(evidence, EXPECTED_ARTIFACT_SOURCE_COMMIT)

    def test_rejects_duplicate_ready_or_any_failed_marker(self) -> None:
        duplicate = passing_evidence()
        duplicate["firstLaunch"]["readyMarkerCount"] = 2
        with self.assertRaisesRegex(GATE.EvidenceError, "exactly one ready"):
            GATE.validate(duplicate, EXPECTED_ARTIFACT_SOURCE_COMMIT)

        failed = passing_evidence()
        failed["firstLaunch"]["failedMarkerCount"] = 1
        with self.assertRaisesRegex(GATE.EvidenceError, "failed marker"):
            GATE.validate(failed, EXPECTED_ARTIFACT_SOURCE_COMMIT)

    def test_rejects_destructive_install_or_missing_usability(self) -> None:
        destructive = passing_evidence()
        destructive["installation"]["dataCleared"] = True
        with self.assertRaisesRegex(GATE.EvidenceError, "dataCleared must be false"):
            GATE.validate(destructive, EXPECTED_ARTIFACT_SOURCE_COMMIT)

        no_wallet_route = copy.deepcopy(passing_evidence())
        no_wallet_route["firstLaunch"]["walletRouteWorked"] = False
        with self.assertRaisesRegex(GATE.EvidenceError, "walletRouteWorked must be true"):
            GATE.validate(no_wallet_route, EXPECTED_ARTIFACT_SOURCE_COMMIT)

    def test_rejects_extra_raw_or_identifier_fields(self) -> None:
        raw_path = passing_evidence()
        raw_path["databasePath"] = "/private/var/mobile/Containers/example.sqlite"
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            GATE.validate(raw_path, EXPECTED_ARTIFACT_SOURCE_COMMIT)

        wallet_identifier = passing_evidence()
        wallet_identifier["preservation"]["walletAddress"] = "sanitized-looking-value"
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            GATE.validate(wallet_identifier, EXPECTED_ARTIFACT_SOURCE_COMMIT)

    def test_rejects_boolean_marker_counts(self) -> None:
        evidence = passing_evidence()
        evidence["firstLaunch"]["readyMarkerCount"] = True

        with self.assertRaisesRegex(GATE.EvidenceError, "exactly one ready"):
            GATE.validate(evidence, EXPECTED_ARTIFACT_SOURCE_COMMIT)

    def test_rejects_base_commit_as_artifact_provenance(self) -> None:
        evidence = passing_evidence()
        evidence["artifactSourceCommit"] = GATE.EXPECTED_BASE_SOURCE_COMMIT

        with self.assertRaisesRegex(GATE.EvidenceError, "must include the hotfix"):
            GATE.validate(evidence, GATE.EXPECTED_BASE_SOURCE_COMMIT)


if __name__ == "__main__":
    unittest.main()
