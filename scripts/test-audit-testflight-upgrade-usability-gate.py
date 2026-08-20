#!/usr/bin/env python3

from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).with_name("audit-testflight-upgrade-usability-gate.py")
SPEC = importlib.util.spec_from_file_location("upgrade_gate", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)
EXPECTED_ARTIFACT_SOURCE_COMMIT = "a" * 40
FIRST_RECEIPT_SHA256 = "b" * 64
SECOND_RECEIPT_SHA256 = "c" * 64


def passing_capture_receipt(*, first: bool) -> dict:
    return {
        "schemaVersion": 1,
        "audit": "fearless-testflight-startup-capture",
        "captureStatus": "complete",
        "bundleIdentifier": "jp.co.soramitsu.fearlesswallet",
        "marketingVersion": "4.2.0",
        "buildNumber": "2026.8.26",
        "observationMethod": "paired-device-fearless-process-only-sanitized-syslog",
        "deviceSidePIDFilter": True,
        "historicalLogsRequested": False,
        "sensitivePayloadRequested": False,
        "pymobiledevice3Version": "10.7.2",
        "captureToolSHA256": GATE.file_sha256(GATE.CAPTURE_TOOL_PATH),
        "startupFilterSHA256": GATE.file_sha256(GATE.STARTUP_FILTER_PATH),
        "pidStreamHelperSHA256": GATE.file_sha256(GATE.PID_STREAM_HELPER_PATH),
        "startedAtUTC": (
            "2026-08-10T12:00:00+09:00"
            if first
            else "2026-08-10T12:10:00+09:00"
        ),
        "completedAtUTC": (
            "2026-08-10T12:05:00+09:00"
            if first
            else "2026-08-10T12:10:02+09:00"
        ),
        "initialProcessState": "stopped",
        "reconnectCountBeforeStop": 0,
        "coldLaunchObserved": True,
        "processStartCount": 1,
        "processStopCount": 0,
        "finalProcessState": "running",
        "terminalObservation": "ready_marker",
        "sanitizedRecordCount": 1,
        "filterBeginCount": 1,
        "devicePIDStreamStartAcknowledged": True,
        "readyMarkerCount": 1,
        "failedMarkerCount": 0,
        "incidentCodes": [],
        "firstDiagnosticElapsedMilliseconds": None,
        "processTerminationElapsedMilliseconds": None,
        "readyMarkerElapsedMilliseconds": 0,
        "readyObservationSecondsRequested": 300 if first else 0,
        "readyObservationElapsedMilliseconds": 300000 if first else 0,
        "readyObservationSatisfied": True,
        "failureObserved": False,
        "deterministicIncidentAvailable": False,
        "diagnosticSufficient": False,
        "rawSyslogPersisted": False,
        "containerAccessed": False,
        "sanitizedLogSHA256": "d" * 64,
        "installedAppMetadataSHA256": "e" * 64,
    }


def validate(
    evidence: dict,
    expected_commit: str = EXPECTED_ARTIFACT_SOURCE_COMMIT,
) -> None:
    GATE.validate(
        evidence,
        expected_commit,
        passing_capture_receipt(first=True),
        FIRST_RECEIPT_SHA256,
        passing_capture_receipt(first=False),
        SECOND_RECEIPT_SHA256,
    )


def write_capture_bundle(root: Path, *, first: bool) -> tuple[Path, str]:
    root.mkdir(mode=0o700)
    metadata_path = root / "installed-app-metadata.json"
    log_path = root / "fearless-startup-sanitized.ndjson"
    receipt_path = root / "capture-receipt.json"
    metadata = {
        "schemaVersion": 1,
        "observationMethod": "paired-device-read-only-app-query",
        "observedAtUTC": "2026-08-10T11:59:59+09:00",
        "bundleIdentifier": "jp.co.soramitsu.fearlesswallet",
        "marketingVersion": "4.2.0",
        "buildNumber": "2026.8.26",
    }
    records = [
        {
            "event": "FEARLESS_COLD_LAUNCH_CAPTURE_BEGIN",
            "timestamp": (
                "2026-08-10T12:00:00+09:00"
                if first
                else "2026-08-10T12:10:00+09:00"
            ),
        },
        {
            "timestamp": (
                "2026-08-10T12:00:00.100000+09:00"
                if first
                else "2026-08-10T12:10:00.100000+09:00"
            ),
            "level": "INFO",
            "subsystem": "jp.co.soramitsu.fearlesswallet",
            "category": "startup-readiness",
            "message": "FEARLESS_STARTUP_READY",
        },
        {
            "event": "FEARLESS_COLD_LAUNCH_CAPTURE_END",
            "timestamp": (
                "2026-08-10T12:05:00+09:00"
                if first
                else "2026-08-10T12:10:02+09:00"
            ),
        },
    ]
    metadata_path.write_text(json.dumps(metadata, sort_keys=True) + "\n")
    log_path.write_text("".join(json.dumps(record, sort_keys=True) + "\n" for record in records))
    metadata_path.chmod(0o600)
    log_path.chmod(0o600)
    receipt = passing_capture_receipt(first=first)
    receipt["installedAppMetadataSHA256"] = GATE.file_sha256(metadata_path)
    receipt["sanitizedLogSHA256"] = GATE.file_sha256(log_path)
    receipt_path.write_text(json.dumps(receipt, sort_keys=True) + "\n")
    receipt_path.chmod(0o600)
    return receipt_path, GATE.file_sha256(receipt_path)


def passing_evidence() -> dict:
    return {
        "schemaVersion": 1,
        "bundleIdentifier": "jp.co.soramitsu.fearlesswallet",
        "marketingVersion": "4.2.0",
        "buildVersion": "2026.8.26",
        "baseSourceCommit": "2e45e55dc03ad904598e730cfb5994fb5c1072dc",
        "artifactSourceCommit": EXPECTED_ARTIFACT_SOURCE_COMMIT,
        "distribution": "apple-testflight-internal",
        "installation": {
            "installedInPlace": True,
            "previousBuildVersion": "2026.8.25",
            "originalAppStoreContainerPreserved": True,
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
            "bottomNavigationControlCount": 5,
            "bottomTabBarVisible": True,
            "portfolioTabRouteWorked": True,
            "defiTabRouteWorked": True,
            "polkaswapTabRouteWorked": True,
            "crossChainTabRouteWorked": True,
            "settingsTabRouteWorked": True,
            "piBackedTokenPricesVisible": True,
            "polkaswapSettingsLoaded": True,
            "polkaswapQuoteWorked": True,
            "polkaswapSwapFeeQuoteWorked": True,
            "polkaswapSwapButtonVisibleAndHittable": True,
            "polkaswapPreviewWorked": True,
            "polkaswapSigningReady": True,
            "bitcoinAssetVisible": True,
            "bitcoinOfficialLogoVisible": True,
            "bitcoinBundledOfficialLogoVisible": True,
            "bitcoinMempoolPublicEndpointWorked": True,
            "bitcoinVisibleWhileRemoteCatalogUnavailable": True,
            "bitcoinVisibleWithoutChainAccount": True,
            "bitcoinDedicatedImportAvailable": True,
            "bitcoinBalanceRefreshWorked": True,
            "bitcoinReceiveAddressWorked": True,
            "bitcoinSendFeeQuoteWorked": True,
            "bitcoinSigningReady": True,
            "bitcoinSwitchNodeActionAbsent": True,
            "bitcoinChainAccountOptionsButtonHidden": True,
            "bitcoinProvisioningWalletExistedBeforeUpdate": True,
            "bitcoinProvisioningWalletHadNoBitcoinAccountBeforeUpdate": True,
            "bitcoinStoredRootMnemonicAutoProvisioned": True,
            "bitcoinAutoProvisionedAddressMatchesBIP84": True,
            "bitcoinLegacyWalletSeedAdoptionAvailable": True,
            "bitcoinLegacyWalletSeedAdoptedWithConfirmation": True,
            "bitcoinRawSeedBridgeAddressMatchesGoldenVector": True,
            "tairaRawSeedBridgeAccountProvisioned": True,
            "tairaTestnetVisible": True,
            "tairaXorAssetVisible": True,
            "tairaCanonicalXorAliasResolved": True,
            "tairaCanonicalXorSchemaValidated": True,
            "tairaCanonicalToriiEndpointWorked": True,
            "tairaVisibleWhileRemoteCatalogUnavailable": True,
            "tairaVisibleWithoutChainAccount": True,
            "tairaDedicatedImportAvailable": True,
            "tairaExistingWalletAccountProvisioned": True,
            "tairaBalanceRefreshWorked": True,
            "tairaReceiveAddressVisibleAndValid": True,
            "tairaSendUnavailable": True,
            "tairaSwitchNodeActionAbsent": True,
            "tairaChainAccountOptionsButtonHidden": True,
            "captureReceiptSHA256": FIRST_RECEIPT_SHA256,
        },
        "preservation": {
            "appContainerPreserved": True,
            "walletCountsUnchanged": True,
            "logicalStoreIntegrityPassed": True,
            "keychainAccessible": True,
            "settingsAccessible": True,
        },
        "secondColdLaunch": {
            "startedAt": "2026-08-10T12:10:00+09:00",
            "completedAt": "2026-08-10T12:10:02+09:00",
            "coldLaunch": True,
            "readyMarkerCount": 1,
            "failedMarkerCount": 0,
            "failureAlertShown": False,
            "pinAccepted": True,
            "walletRouteWorked": True,
            "bottomNavigationControlCount": 5,
            "bottomTabBarVisible": True,
            "portfolioTabRouteWorked": True,
            "defiTabRouteWorked": True,
            "polkaswapTabRouteWorked": True,
            "crossChainTabRouteWorked": True,
            "settingsTabRouteWorked": True,
            "piBackedTokenPricesVisible": True,
            "polkaswapSettingsLoaded": True,
            "polkaswapQuoteWorked": True,
            "polkaswapSwapFeeQuoteWorked": True,
            "polkaswapSwapButtonVisibleAndHittable": True,
            "polkaswapPreviewWorked": True,
            "polkaswapSigningReady": True,
            "bitcoinAssetVisible": True,
            "bitcoinOfficialLogoVisible": True,
            "bitcoinBundledOfficialLogoVisible": True,
            "bitcoinMempoolPublicEndpointWorked": True,
            "bitcoinBalanceRefreshWorked": True,
            "bitcoinReceiveAddressWorked": True,
            "bitcoinSendFeeQuoteWorked": True,
            "bitcoinSigningReady": True,
            "bitcoinSwitchNodeActionAbsent": True,
            "bitcoinChainAccountOptionsButtonHidden": True,
            "bitcoinAutoProvisionedAddressStableAcrossRelaunch": True,
            "bitcoinRawSeedBridgeAddressStableAcrossRelaunch": True,
            "tairaRawSeedBridgeAccountStableAcrossRelaunch": True,
            "tairaTestnetVisible": True,
            "tairaXorAssetVisible": True,
            "tairaCanonicalXorAliasResolved": True,
            "tairaCanonicalXorSchemaValidated": True,
            "tairaCanonicalToriiEndpointWorked": True,
            "tairaExistingWalletAccountProvisioned": True,
            "tairaBalanceRefreshWorked": True,
            "tairaReceiveAddressVisibleAndValid": True,
            "tairaSendUnavailable": True,
            "tairaSwitchNodeActionAbsent": True,
            "tairaChainAccountOptionsButtonHidden": True,
            "captureReceiptSHA256": SECOND_RECEIPT_SHA256,
        },
        "release": {
            "internalGroupValidatedFirst": True,
            "publicBetaReplacedBeforeGate": False,
        },
    }


class UpgradeUsabilityGateTests(unittest.TestCase):
    def test_accepts_complete_sanitized_five_minute_gate(self) -> None:
        validate(passing_evidence())

    def test_rejects_process_liveness_sized_window(self) -> None:
        evidence = passing_evidence()
        evidence["firstLaunch"]["completedAt"] = "2026-08-10T12:00:45+09:00"
        short_capture = passing_capture_receipt(first=True)
        short_capture["completedAtUTC"] = "2026-08-10T12:00:45+09:00"

        with self.assertRaisesRegex(GATE.EvidenceError, "timestamps are shorter"):
            GATE.validate(
                evidence,
                EXPECTED_ARTIFACT_SOURCE_COMMIT,
                short_capture,
                FIRST_RECEIPT_SHA256,
                passing_capture_receipt(first=False),
                SECOND_RECEIPT_SHA256,
            )

    def test_rejects_duplicate_ready_or_any_failed_marker(self) -> None:
        duplicate = passing_evidence()
        duplicate["firstLaunch"]["readyMarkerCount"] = 2
        with self.assertRaisesRegex(GATE.EvidenceError, "exactly one ready"):
            validate(duplicate)

        failed = passing_evidence()
        failed["firstLaunch"]["failedMarkerCount"] = 1
        with self.assertRaisesRegex(GATE.EvidenceError, "failed marker"):
            validate(failed)

    def test_rejects_destructive_install_or_missing_usability(self) -> None:
        destructive = passing_evidence()
        destructive["installation"]["dataCleared"] = True
        with self.assertRaisesRegex(GATE.EvidenceError, "dataCleared must be false"):
            validate(destructive)

        replaced_container = passing_evidence()
        replaced_container["installation"]["originalAppStoreContainerPreserved"] = False
        with self.assertRaisesRegex(
            GATE.EvidenceError,
            "originalAppStoreContainerPreserved must be true",
        ):
            validate(replaced_container)

        stale_predecessor = passing_evidence()
        stale_predecessor["installation"]["previousBuildVersion"] = "2026.7.28"
        with self.assertRaisesRegex(GATE.EvidenceError, "supported predecessor build"):
            validate(stale_predecessor)

        redesigned_predecessor = passing_evidence()
        redesigned_predecessor["installation"]["previousBuildVersion"] = "2026.8.17"
        validate(redesigned_predecessor)

        no_wallet_route = copy.deepcopy(passing_evidence())
        no_wallet_route["firstLaunch"]["walletRouteWorked"] = False
        with self.assertRaisesRegex(GATE.EvidenceError, "walletRouteWorked must be true"):
            validate(no_wallet_route)

    def test_rejects_missing_or_failed_bottom_navigation_attestation(self) -> None:
        missing_count = passing_evidence()
        missing_count["firstLaunch"].pop("bottomNavigationControlCount")
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            validate(missing_count)

        wrong_count = passing_evidence()
        wrong_count["firstLaunch"]["bottomNavigationControlCount"] = 1
        with self.assertRaisesRegex(GATE.EvidenceError, "all five"):
            validate(wrong_count)

        for key in GATE.TAB_BAR_ROUTE_ATTESTATIONS:
            with self.subTest(key=key):
                failed_route = passing_evidence()
                failed_route["firstLaunch"][key] = False
                with self.assertRaisesRegex(
                    GATE.EvidenceError,
                    f"{key} must be true",
                ):
                    validate(failed_route)

    def test_rejects_missing_or_failed_pi_price_attestation(self) -> None:
        missing = passing_evidence()
        missing["firstLaunch"].pop("piBackedTokenPricesVisible")
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            validate(missing)

        for launch in ("firstLaunch", "secondColdLaunch"):
            with self.subTest(launch=launch):
                failed = passing_evidence()
                failed[launch]["piBackedTokenPricesVisible"] = False
                with self.assertRaisesRegex(
                    GATE.EvidenceError,
                    "piBackedTokenPricesVisible must be true",
                ):
                    validate(failed)

    def test_rejects_missing_or_failed_polkaswap_functionality_attestation(self) -> None:
        missing = passing_evidence()
        missing["firstLaunch"].pop("polkaswapSettingsLoaded")
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            validate(missing)

        for launch in ("firstLaunch", "secondColdLaunch"):
            for key in GATE.POLKASWAP_ATTESTATIONS:
                with self.subTest(launch=launch, key=key):
                    failed = passing_evidence()
                    failed[launch][key] = False
                    with self.assertRaisesRegex(
                        GATE.EvidenceError,
                        f"{key} must be true",
                    ):
                        validate(failed)

    def test_rejects_missing_or_failed_bitcoin_attestation(self) -> None:
        missing = passing_evidence()
        missing["firstLaunch"].pop("bitcoinAssetVisible")
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            validate(missing)

        for launch in ("firstLaunch", "secondColdLaunch"):
            for key in GATE.BITCOIN_ATTESTATIONS:
                with self.subTest(launch=launch, key=key):
                    failed = passing_evidence()
                    failed[launch][key] = False
                    with self.assertRaisesRegex(
                        GATE.EvidenceError,
                        f"{key} must be true",
                    ):
                        validate(failed)

    def test_rejects_missing_or_failed_bitcoin_provisioning_attestation(self) -> None:
        launch_contracts = (
            ("firstLaunch", GATE.BITCOIN_FIRST_LAUNCH_PROVISIONING_ATTESTATIONS),
            ("secondColdLaunch", GATE.BITCOIN_SECOND_LAUNCH_PROVISIONING_ATTESTATIONS),
        )
        for launch, keys in launch_contracts:
            for key in keys:
                with self.subTest(launch=launch, key=key):
                    missing = passing_evidence()
                    missing[launch].pop(key)
                    with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
                        validate(missing)

                    failed = passing_evidence()
                    failed[launch][key] = False
                    with self.assertRaisesRegex(
                        GATE.EvidenceError,
                        f"{key} must be true",
                    ):
                        validate(failed)

    def test_rejects_missing_or_failed_taira_attestation(self) -> None:
        missing = passing_evidence()
        missing["firstLaunch"].pop("tairaTestnetVisible")
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            validate(missing)

        for launch in ("firstLaunch", "secondColdLaunch"):
            for key in GATE.TAIRA_ATTESTATIONS:
                with self.subTest(launch=launch, key=key):
                    failed = passing_evidence()
                    failed[launch][key] = False
                    with self.assertRaisesRegex(
                        GATE.EvidenceError,
                        f"{key} must be true",
                    ):
                        validate(failed)

    def test_rejects_missing_or_failed_first_launch_accountless_attestation(self) -> None:
        for key in GATE.FIRST_LAUNCH_ACCOUNTLESS_ATTESTATIONS:
            with self.subTest(key=key):
                missing = passing_evidence()
                missing["firstLaunch"].pop(key)
                with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
                    validate(missing)

                failed = passing_evidence()
                failed["firstLaunch"][key] = False
                with self.assertRaisesRegex(
                    GATE.EvidenceError,
                    f"{key} must be true",
                ):
                    validate(failed)

    def test_rejects_extra_raw_or_identifier_fields(self) -> None:
        raw_path = passing_evidence()
        raw_path["databasePath"] = "/private/var/mobile/Containers/example.sqlite"
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            validate(raw_path)

        wallet_identifier = passing_evidence()
        wallet_identifier["preservation"]["walletAddress"] = "sanitized-looking-value"
        with self.assertRaisesRegex(GATE.EvidenceError, "privacy-safe schema"):
            validate(wallet_identifier)

    def test_rejects_boolean_marker_counts(self) -> None:
        evidence = passing_evidence()
        evidence["firstLaunch"]["readyMarkerCount"] = True

        with self.assertRaisesRegex(GATE.EvidenceError, "exactly one ready"):
            validate(evidence)

    def test_rejects_base_commit_as_artifact_provenance(self) -> None:
        evidence = passing_evidence()
        evidence["artifactSourceCommit"] = GATE.EXPECTED_BASE_SOURCE_COMMIT

        with self.assertRaisesRegex(GATE.EvidenceError, "must include the hotfix"):
            validate(evidence, GATE.EXPECTED_BASE_SOURCE_COMMIT)

    def test_rejects_short_or_stopped_first_capture_receipt(self) -> None:
        short = passing_capture_receipt(first=True)
        short["readyObservationSecondsRequested"] = 0
        short["readyObservationElapsedMilliseconds"] = 0
        with self.assertRaisesRegex(GATE.EvidenceError, "request is too short"):
            GATE.validate(
                passing_evidence(),
                EXPECTED_ARTIFACT_SOURCE_COMMIT,
                short,
                FIRST_RECEIPT_SHA256,
                passing_capture_receipt(first=False),
                SECOND_RECEIPT_SHA256,
            )

        stopped = passing_capture_receipt(first=True)
        stopped["finalProcessState"] = "stopped"
        stopped["terminalObservation"] = "process_terminated"
        stopped["processTerminationElapsedMilliseconds"] = 299999
        stopped["failureObserved"] = True
        stopped["readyObservationSatisfied"] = False
        with self.assertRaisesRegex(GATE.EvidenceError, "process stopped"):
            GATE.validate(
                passing_evidence(),
                EXPECTED_ARTIFACT_SOURCE_COMMIT,
                stopped,
                FIRST_RECEIPT_SHA256,
                passing_capture_receipt(first=False),
                SECOND_RECEIPT_SHA256,
            )

    def test_rejects_unbound_capture_receipt_hash(self) -> None:
        evidence = passing_evidence()
        evidence["firstLaunch"]["captureReceiptSHA256"] = "f" * 64
        with self.assertRaisesRegex(GATE.EvidenceError, "receipt hash drifted"):
            validate(evidence)

    def test_rejects_reusing_first_receipt_as_second_cold_launch(self) -> None:
        first_receipt = passing_capture_receipt(first=True)
        evidence = passing_evidence()
        evidence["secondColdLaunch"].update(
            {
                "startedAt": first_receipt["startedAtUTC"],
                "completedAt": first_receipt["completedAtUTC"],
                "captureReceiptSHA256": FIRST_RECEIPT_SHA256,
            }
        )
        with self.assertRaisesRegex(GATE.EvidenceError, "must be distinct"):
            GATE.validate(
                evidence,
                EXPECTED_ARTIFACT_SOURCE_COMMIT,
                first_receipt,
                FIRST_RECEIPT_SHA256,
                first_receipt,
                FIRST_RECEIPT_SHA256,
            )

    def test_rejects_second_launch_before_first_capture_completed(self) -> None:
        second_receipt = passing_capture_receipt(first=False)
        second_receipt["startedAtUTC"] = "2026-08-10T12:04:00+09:00"
        second_receipt["completedAtUTC"] = "2026-08-10T12:04:02+09:00"
        evidence = passing_evidence()
        evidence["secondColdLaunch"]["startedAt"] = second_receipt["startedAtUTC"]
        evidence["secondColdLaunch"]["completedAt"] = second_receipt["completedAtUTC"]
        with self.assertRaisesRegex(GATE.EvidenceError, "begin after"):
            GATE.validate(
                evidence,
                EXPECTED_ARTIFACT_SOURCE_COMMIT,
                passing_capture_receipt(first=True),
                FIRST_RECEIPT_SHA256,
                second_receipt,
                SECOND_RECEIPT_SHA256,
            )

    def test_loads_private_capture_bundle_and_rejects_sanitized_log_tampering(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            receipt_path, receipt_sha256 = write_capture_bundle(
                Path(directory) / "first",
                first=True,
            )
            receipt, observed_sha256 = GATE.load_capture_bundle(
                receipt_path,
                "first launch",
            )
            self.assertEqual(observed_sha256, receipt_sha256)
            GATE.validate_capture_receipt(receipt, "first launch capture", 300)

            log_path = receipt_path.parent / "fearless-startup-sanitized.ndjson"
            log_path.write_text(log_path.read_text() + "{}\n")
            log_path.chmod(0o600)
            with self.assertRaisesRegex(GATE.EvidenceError, "log hash mismatch"):
                GATE.load_capture_bundle(receipt_path, "first launch")

            unsafe_receipt_path, _ = write_capture_bundle(
                Path(directory) / "unsafe",
                first=True,
            )
            unsafe_log_path = (
                unsafe_receipt_path.parent / "fearless-startup-sanitized.ndjson"
            )
            unsafe_records = [
                json.loads(line) for line in unsafe_log_path.read_text().splitlines()
            ]
            unsafe_records[1]["message"] = "wallet address private-value"
            unsafe_log_path.write_text(
                "".join(
                    json.dumps(record, sort_keys=True) + "\n"
                    for record in unsafe_records
                )
            )
            unsafe_log_path.chmod(0o600)
            unsafe_receipt = json.loads(unsafe_receipt_path.read_text())
            unsafe_receipt["sanitizedLogSHA256"] = GATE.file_sha256(unsafe_log_path)
            unsafe_receipt_path.write_text(
                json.dumps(unsafe_receipt, sort_keys=True) + "\n"
            )
            unsafe_receipt_path.chmod(0o600)
            with self.assertRaisesRegex(GATE.EvidenceError, "unsafe sanitized"):
                GATE.load_capture_bundle(unsafe_receipt_path, "first launch")

    def test_cli_binds_two_private_capture_bundles_end_to_end(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first_path, first_sha256 = write_capture_bundle(
                root / "first",
                first=True,
            )
            second_path, second_sha256 = write_capture_bundle(
                root / "second",
                first=False,
            )
            evidence = passing_evidence()
            evidence["firstLaunch"]["captureReceiptSHA256"] = first_sha256
            evidence["secondColdLaunch"]["captureReceiptSHA256"] = second_sha256
            evidence_path = root / "evidence.json"
            evidence_path.write_text(json.dumps(evidence, sort_keys=True) + "\n")
            evidence_path.chmod(0o600)

            with patch.object(
                sys,
                "argv",
                [
                    str(SCRIPT_PATH),
                    str(evidence_path),
                    "--first-launch-capture-receipt",
                    str(first_path),
                    "--second-launch-capture-receipt",
                    str(second_path),
                    "--expected-artifact-source-commit",
                    EXPECTED_ARTIFACT_SOURCE_COMMIT,
                ],
            ):
                self.assertEqual(GATE.main(), 0)


if __name__ == "__main__":
    unittest.main()
