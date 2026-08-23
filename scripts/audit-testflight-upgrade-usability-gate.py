#!/usr/bin/env python3
"""Fail-closed audit for sanitized physical TestFlight upgrade evidence."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import re
import stat
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


EXPECTED_BUNDLE_ID = "jp.co.soramitsu.fearlesswallet"
EXPECTED_VERSION = "4.2.0"
EXPECTED_BUILD = "2026.8.31"
EXPECTED_PREVIOUS_BUILDS = (
    "2026.8.15",
    "2026.8.17",
    "2026.8.18",
    "2026.8.19",
    "2026.8.20",
    "2026.8.21",
    "2026.8.22",
    "2026.8.23",
    "2026.8.24",
    "2026.8.25",
    "2026.8.26",
    "2026.8.27",
    "2026.8.28",
    "2026.8.29",
    "2026.8.30",
)
EXPECTED_BASE_SOURCE_COMMIT = "2e45e55dc03ad904598e730cfb5994fb5c1072dc"
MINIMUM_USABILITY_SECONDS = 300
WALL_CLOCK_ROUNDING_TOLERANCE_MILLISECONDS = 1000
EXPECTED_CAPTURE_AUDIT = "fearless-testflight-startup-capture"
EXPECTED_CAPTURE_METHOD = "paired-device-fearless-process-only-sanitized-syslog"
EXPECTED_PYMOBILEDEVICE3_VERSION = "10.7.2"
TAB_BAR_ROUTE_ATTESTATIONS = (
    "bottomTabBarVisible",
    "portfolioTabRouteWorked",
    "defiTabRouteWorked",
    "polkaswapTabRouteWorked",
    "crossChainTabRouteWorked",
    "settingsTabRouteWorked",
)
PI_PRICE_ATTESTATION = "piBackedTokenPricesVisible"
POLKASWAP_ATTESTATIONS = (
    "polkaswapSettingsLoaded",
    "polkaswapQuoteWorked",
    "polkaswapSwapFeeQuoteWorked",
    "polkaswapSwapButtonVisibleAndHittable",
    "polkaswapPreviewWorked",
    "polkaswapSigningReady",
)
BITCOIN_ATTESTATIONS = (
    "bitcoinAssetVisible",
    "bitcoinOfficialLogoVisible",
    "bitcoinBundledOfficialLogoVisible",
    "bitcoinMempoolPublicEndpointWorked",
    "bitcoinBalanceRefreshWorked",
    "bitcoinReceiveAddressWorked",
    "bitcoinSendFeeQuoteWorked",
    "bitcoinSigningReady",
    "bitcoinSwitchNodeActionAbsent",
    "bitcoinChainAccountOptionsButtonHidden",
)
BITCOIN_FIRST_LAUNCH_PROVISIONING_ATTESTATIONS = (
    "bitcoinProvisioningWalletExistedBeforeUpdate",
    "bitcoinProvisioningWalletHadNoBitcoinAccountBeforeUpdate",
    "bitcoinStoredRootMnemonicAutoProvisioned",
    "bitcoinAutoProvisionedAddressMatchesBIP84",
    "bitcoinLegacyWalletSeedAdoptionAvailable",
    "bitcoinLegacyWalletSeedAdoptedWithConfirmation",
    "bitcoinLegacyWalletSeedActionSurvivedSheetDismissal",
    "bitcoinLegacyWalletSeedAdoptionResultDelivered",
    "bitcoinLegacyWalletSeedDedicatedAccountsPersisted",
    "bitcoinMissingStoredSeedFailureVisibleAndActionable",
    "bitcoinRawSeedBridgeAddressMatchesGoldenVector",
    "tairaRawSeedBridgeAccountProvisioned",
)
BITCOIN_SECOND_LAUNCH_PROVISIONING_ATTESTATIONS = (
    "bitcoinAutoProvisionedAddressStableAcrossRelaunch",
    "bitcoinRawSeedBridgeAddressStableAcrossRelaunch",
    "bitcoinLegacyWalletSeedDedicatedAccountsPersistedAcrossRelaunch",
    "tairaRawSeedBridgeAccountStableAcrossRelaunch",
)
TAIRA_ATTESTATIONS = (
    "tairaTestnetVisible",
    "tairaXorAssetVisible",
    "tairaCanonicalXorAliasResolved",
    "tairaCanonicalXorSchemaValidated",
    "tairaCanonicalToriiEndpointWorked",
    "tairaExistingWalletAccountProvisioned",
    "tairaBalanceRefreshWorked",
    "tairaReceiveAddressVisibleAndValid",
    "tairaSendUnavailable",
    "tairaSwitchNodeActionAbsent",
    "tairaChainAccountOptionsButtonHidden",
)
FIRST_LAUNCH_ACCOUNTLESS_ATTESTATIONS = (
    "bitcoinVisibleWhileRemoteCatalogUnavailable",
    "bitcoinVisibleWithoutChainAccount",
    "bitcoinDedicatedImportAvailable",
    "tairaVisibleWhileRemoteCatalogUnavailable",
    "tairaVisibleWithoutChainAccount",
    "tairaDedicatedImportAvailable",
)
CAPTURE_RECEIPT_KEYS = {
    "schemaVersion",
    "audit",
    "captureStatus",
    "bundleIdentifier",
    "marketingVersion",
    "buildNumber",
    "observationMethod",
    "deviceSidePIDFilter",
    "historicalLogsRequested",
    "sensitivePayloadRequested",
    "pymobiledevice3Version",
    "captureToolSHA256",
    "startupFilterSHA256",
    "pidStreamHelperSHA256",
    "startedAtUTC",
    "completedAtUTC",
    "initialProcessState",
    "reconnectCountBeforeStop",
    "coldLaunchObserved",
    "processStartCount",
    "processStopCount",
    "finalProcessState",
    "terminalObservation",
    "sanitizedRecordCount",
    "filterBeginCount",
    "devicePIDStreamStartAcknowledged",
    "readyMarkerCount",
    "failedMarkerCount",
    "incidentCodes",
    "firstDiagnosticElapsedMilliseconds",
    "processTerminationElapsedMilliseconds",
    "readyMarkerElapsedMilliseconds",
    "readyObservationSecondsRequested",
    "readyObservationElapsedMilliseconds",
    "readyObservationSatisfied",
    "failureObserved",
    "deterministicIncidentAvailable",
    "diagnosticSufficient",
    "rawSyslogPersisted",
    "containerAccessed",
    "sanitizedLogSHA256",
    "installedAppMetadataSHA256",
}
CAPTURE_METADATA_KEYS = {
    "schemaVersion",
    "observationMethod",
    "observedAtUTC",
    "bundleIdentifier",
    "marketingVersion",
    "buildNumber",
}
SCRIPT_DIRECTORY = Path(__file__).resolve().parent
CAPTURE_TOOL_PATH = SCRIPT_DIRECTORY / "capture-testflight-startup.py"
STARTUP_FILTER_PATH = SCRIPT_DIRECTORY / "filter-startup-syslog.py"
PID_STREAM_HELPER_PATH = SCRIPT_DIRECTORY / "stream-fearless-pid-syslog.py"
_CAPTURE_MODULE: Any = None


class EvidenceError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise EvidenceError(message)


def require_exact_keys(mapping: dict[str, Any], expected: set[str], name: str) -> None:
    actual = set(mapping)
    require(
        actual == expected,
        f"{name} keys must match the privacy-safe schema exactly",
    )


def require_true(mapping: dict[str, Any], key: str) -> None:
    require(type(mapping.get(key)) is bool and mapping[key] is True, f"{key} must be true")


def require_false(mapping: dict[str, Any], key: str) -> None:
    require(type(mapping.get(key)) is bool and mapping[key] is False, f"{key} must be false")


def require_integer(mapping: dict[str, Any], key: str, expected: int, message: str) -> None:
    value = mapping.get(key)
    require(type(value) is int and value == expected, message)


def require_nonnegative_integer(mapping: dict[str, Any], key: str) -> int:
    value = mapping.get(key)
    require(
        type(value) is int and value >= 0,
        f"{key} must be a non-negative integer",
    )
    return value


def require_sha256(value: Any, name: str) -> str:
    require(
        isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None,
        f"{name} must be a lowercase SHA-256",
    )
    return value


def require_finite_number(mapping: dict[str, Any], key: str) -> float:
    value = mapping.get(key)
    require(
        type(value) in (int, float) and math.isfinite(value) and value >= 0,
        f"{key} must be a finite non-negative number",
    )
    return float(value)


def require_mapping(value: Any, name: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{name} must be an object")
    return value


def timestamp(value: Any, name: str) -> datetime:
    require(isinstance(value, str), f"{name} must be an ISO-8601 string")
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise EvidenceError(f"{name} is not valid ISO-8601") from error
    require(result.tzinfo is not None, f"{name} must include a timezone")
    return result


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def capture_module() -> Any:
    global _CAPTURE_MODULE
    if _CAPTURE_MODULE is None:
        spec = importlib.util.spec_from_file_location(
            "fearless_capture_contract_for_upgrade_audit",
            CAPTURE_TOOL_PATH,
        )
        require(
            spec is not None and spec.loader is not None,
            "capture tool contract is unavailable",
        )
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        _CAPTURE_MODULE = module
    return _CAPTURE_MODULE


def require_private_regular_file(path: Path, name: str) -> None:
    require(path.is_file() and not path.is_symlink(), f"{name} must be a regular file")
    mode = stat.S_IMODE(path.stat().st_mode)
    require(mode & 0o077 == 0, f"{name} must not be group/world accessible")


def require_private_directory(path: Path, name: str) -> None:
    require(path.is_dir() and not path.is_symlink(), f"{name} must be a directory")
    mode = stat.S_IMODE(path.stat().st_mode)
    require(mode & 0o077 == 0, f"{name} must not be group/world accessible")


def validate_capture_receipt(
    receipt: dict[str, Any],
    name: str,
    minimum_ready_observation_seconds: int,
) -> None:
    require_exact_keys(receipt, CAPTURE_RECEIPT_KEYS, name)
    require_integer(receipt, "schemaVersion", 1, f"{name} schemaVersion must equal 1")
    require(receipt.get("audit") == EXPECTED_CAPTURE_AUDIT, f"{name} audit drifted")
    require(receipt.get("captureStatus") == "complete", f"{name} is incomplete")
    require(receipt.get("bundleIdentifier") == EXPECTED_BUNDLE_ID, f"{name} bundle drifted")
    require(receipt.get("marketingVersion") == EXPECTED_VERSION, f"{name} version drifted")
    require(receipt.get("buildNumber") == EXPECTED_BUILD, f"{name} build drifted")
    require(
        receipt.get("observationMethod") == EXPECTED_CAPTURE_METHOD,
        f"{name} observation method drifted",
    )
    require_true(receipt, "deviceSidePIDFilter")
    require_false(receipt, "historicalLogsRequested")
    require_false(receipt, "sensitivePayloadRequested")
    require(
        receipt.get("pymobiledevice3Version") == EXPECTED_PYMOBILEDEVICE3_VERSION,
        f"{name} backend version drifted",
    )
    for key in (
        "captureToolSHA256",
        "startupFilterSHA256",
        "pidStreamHelperSHA256",
        "sanitizedLogSHA256",
        "installedAppMetadataSHA256",
    ):
        require_sha256(receipt.get(key), f"{name}.{key}")
    require(
        receipt.get("captureToolSHA256") == file_sha256(CAPTURE_TOOL_PATH),
        f"{name} capture tool provenance drifted",
    )
    require(
        receipt.get("startupFilterSHA256") == file_sha256(STARTUP_FILTER_PATH),
        f"{name} startup filter provenance drifted",
    )
    require(
        receipt.get("pidStreamHelperSHA256") == file_sha256(PID_STREAM_HELPER_PATH),
        f"{name} PID stream helper provenance drifted",
    )
    started = timestamp(receipt.get("startedAtUTC"), f"{name}.startedAtUTC")
    completed = timestamp(receipt.get("completedAtUTC"), f"{name}.completedAtUTC")
    require(completed >= started, f"{name} timestamps are reversed")
    require(
        receipt.get("initialProcessState") in {"running", "stopped"},
        f"{name} initial process state is invalid",
    )
    require_nonnegative_integer(receipt, "reconnectCountBeforeStop")
    require_true(receipt, "coldLaunchObserved")
    require_integer(receipt, "processStartCount", 1, f"{name} must observe one launch")
    require_nonnegative_integer(receipt, "processStopCount")
    require(receipt.get("finalProcessState") == "running", f"{name} process stopped")
    require(receipt.get("terminalObservation") == "ready_marker", f"{name} did not end ready")
    require_nonnegative_integer(receipt, "sanitizedRecordCount")
    require_integer(receipt, "filterBeginCount", 1, f"{name} PID stream was not singular")
    require_true(receipt, "devicePIDStreamStartAcknowledged")
    require_integer(receipt, "readyMarkerCount", 1, f"{name} must have one READY marker")
    require_integer(receipt, "failedMarkerCount", 0, f"{name} contains FAILED")
    require(receipt.get("incidentCodes") == [], f"{name} contains an incident code")
    require(
        receipt.get("firstDiagnosticElapsedMilliseconds") is None,
        f"{name} contains a failure diagnostic",
    )
    require(
        receipt.get("processTerminationElapsedMilliseconds") is None,
        f"{name} launch terminated",
    )
    ready_elapsed_from_launch = require_nonnegative_integer(
        receipt,
        "readyMarkerElapsedMilliseconds",
    )
    requested = require_finite_number(receipt, "readyObservationSecondsRequested")
    elapsed = require_nonnegative_integer(receipt, "readyObservationElapsedMilliseconds")
    require(
        requested >= minimum_ready_observation_seconds,
        f"{name} READY observation request is too short",
    )
    require(
        elapsed >= round(requested * 1000),
        f"{name} READY observation elapsed time is too short",
    )
    require(
        (completed - started).total_seconds() * 1000
        + WALL_CLOCK_ROUNDING_TOLERANCE_MILLISECONDS
        >= ready_elapsed_from_launch + elapsed,
        f"{name} capture timestamps are shorter than the READY observation",
    )
    require_true(receipt, "readyObservationSatisfied")
    require_false(receipt, "failureObserved")
    require_false(receipt, "deterministicIncidentAvailable")
    require_false(receipt, "diagnosticSufficient")
    require_false(receipt, "rawSyslogPersisted")
    require_false(receipt, "containerAccessed")


def load_capture_bundle(receipt_path: Path, name: str) -> tuple[dict[str, Any], str]:
    require(receipt_path.name == "capture-receipt.json", f"{name} receipt filename drifted")
    require_private_directory(receipt_path.parent, f"{name} capture directory")
    require_private_regular_file(receipt_path, f"{name} receipt")
    log_path = receipt_path.parent / "fearless-startup-sanitized.ndjson"
    metadata_path = receipt_path.parent / "installed-app-metadata.json"
    require_private_regular_file(log_path, f"{name} sanitized log")
    require_private_regular_file(metadata_path, f"{name} metadata")
    try:
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        raise EvidenceError(f"{name} capture bundle is unreadable") from error
    require(isinstance(receipt, dict), f"{name} receipt must be an object")
    require(isinstance(metadata, dict), f"{name} metadata must be an object")
    require_exact_keys(metadata, CAPTURE_METADATA_KEYS, f"{name} metadata")
    require_integer(metadata, "schemaVersion", 1, f"{name} metadata schema drifted")
    require(
        metadata.get("observationMethod") == "paired-device-read-only-app-query",
        f"{name} metadata observation method drifted",
    )
    timestamp(metadata.get("observedAtUTC"), f"{name}.metadata.observedAtUTC")
    require(
        metadata.get("bundleIdentifier") == EXPECTED_BUNDLE_ID,
        f"{name} metadata bundle drifted",
    )
    require(
        metadata.get("marketingVersion") == EXPECTED_VERSION,
        f"{name} metadata version drifted",
    )
    require(metadata.get("buildNumber") == EXPECTED_BUILD, f"{name} metadata build drifted")
    require(
        file_sha256(metadata_path) == receipt.get("installedAppMetadataSHA256"),
        f"{name} metadata hash mismatch",
    )
    require(
        file_sha256(log_path) == receipt.get("sanitizedLogSHA256"),
        f"{name} sanitized log hash mismatch",
    )

    try:
        records = [
            json.loads(line)
            for line in log_path.read_text(encoding="utf-8").splitlines()
            if line
        ]
    except (json.JSONDecodeError, OSError) as error:
        raise EvidenceError(f"{name} sanitized log is unreadable") from error
    require(len(records) >= 3, f"{name} sanitized log is incomplete")
    require(
        records[0].get("event") == "FEARLESS_COLD_LAUNCH_CAPTURE_BEGIN"
        and set(records[0]) == {"event", "timestamp"},
        f"{name} sanitized log has no singular begin boundary",
    )
    require(
        records[-1].get("event") == "FEARLESS_COLD_LAUNCH_CAPTURE_END"
        and set(records[-1]) == {"event", "timestamp"},
        f"{name} sanitized log has no singular end boundary",
    )
    timestamp(records[0].get("timestamp"), f"{name}.log.startedAt")
    timestamp(records[-1].get("timestamp"), f"{name}.log.completedAt")
    require(
        records[0].get("timestamp") == receipt.get("startedAtUTC"),
        f"{name} log start does not match its receipt",
    )
    require(
        records[-1].get("timestamp") == receipt.get("completedAtUTC"),
        f"{name} log completion does not match its receipt",
    )
    middle = records[1:-1]
    capture_contract = capture_module()
    for record in middle:
        require(isinstance(record, dict), f"{name} sanitized record must be an object")
        require(
            set(record) == {"timestamp", "level", "subsystem", "category", "message"},
            f"{name} sanitized record schema drifted",
        )
        timestamp(record.get("timestamp"), f"{name}.record.timestamp")
        require(isinstance(record.get("message"), str), f"{name} message is invalid")
        try:
            canonical = capture_contract.validate_sanitized_record(record)
        except capture_contract.CaptureError as error:
            raise EvidenceError(f"{name} contains unsafe sanitized content") from error
        require(canonical == record, f"{name} sanitized record is not canonical")
    ready_count = sum(record["message"] == "FEARLESS_STARTUP_READY" for record in middle)
    failed_count = sum(
        record["message"] == "FEARLESS_STARTUP_FAILED"
        or record["message"].startswith("FEARLESS_STARTUP_FAILED ")
        for record in middle
    )
    require(len(middle) == receipt.get("sanitizedRecordCount"), f"{name} record count mismatch")
    require(ready_count == receipt.get("readyMarkerCount"), f"{name} READY count mismatch")
    require(failed_count == receipt.get("failedMarkerCount"), f"{name} FAILED count mismatch")
    return receipt, file_sha256(receipt_path)


def validate(
    evidence: dict[str, Any],
    expected_artifact_source_commit: str,
    first_capture_receipt: dict[str, Any],
    first_capture_receipt_sha256: str,
    second_capture_receipt: dict[str, Any],
    second_capture_receipt_sha256: str,
) -> None:
    validate_capture_receipt(
        first_capture_receipt,
        "first launch capture",
        MINIMUM_USABILITY_SECONDS,
    )
    validate_capture_receipt(second_capture_receipt, "second launch capture", 0)
    require_sha256(first_capture_receipt_sha256, "first capture receipt SHA-256")
    require_sha256(second_capture_receipt_sha256, "second capture receipt SHA-256")
    require(
        first_capture_receipt_sha256 != second_capture_receipt_sha256,
        "first and second launch capture receipts must be distinct",
    )
    require(
        timestamp(
            second_capture_receipt.get("startedAtUTC"),
            "second launch capture.startedAtUTC",
        )
        > timestamp(
            first_capture_receipt.get("completedAtUTC"),
            "first launch capture.completedAtUTC",
        ),
        "second cold launch must begin after the first capture completes",
    )
    require_exact_keys(
        evidence,
        {
            "schemaVersion",
            "bundleIdentifier",
            "marketingVersion",
            "buildVersion",
            "baseSourceCommit",
            "artifactSourceCommit",
            "distribution",
            "installation",
            "firstLaunch",
            "preservation",
            "secondColdLaunch",
            "release",
        },
        "evidence",
    )
    require_integer(evidence, "schemaVersion", 1, "schemaVersion must equal 1")
    require(evidence.get("bundleIdentifier") == EXPECTED_BUNDLE_ID, "bundle identifier drifted")
    require(evidence.get("marketingVersion") == EXPECTED_VERSION, "marketing version drifted")
    require(evidence.get("buildVersion") == EXPECTED_BUILD, "build version drifted")
    require(
        evidence.get("baseSourceCommit") == EXPECTED_BASE_SOURCE_COMMIT,
        "base source commit drifted",
    )
    require(
        re.fullmatch(r"[0-9a-f]{40}", expected_artifact_source_commit) is not None,
        "expected artifact source commit must be a lowercase 40-character git SHA",
    )
    require(
        evidence.get("artifactSourceCommit") == expected_artifact_source_commit,
        "artifact source commit drifted",
    )
    require(
        expected_artifact_source_commit != EXPECTED_BASE_SOURCE_COMMIT,
        "artifact source commit must include the hotfix changes",
    )
    require(
        evidence.get("distribution") == "apple-testflight-internal",
        "distribution must be the Apple-delivered internal TestFlight build",
    )

    installation = require_mapping(evidence.get("installation"), "installation")
    require_exact_keys(
        installation,
        {
            "installedInPlace",
            "previousBuildVersion",
            "originalAppStoreContainerPreserved",
            "uninstalled",
            "offloaded",
            "downgraded",
            "dataCleared",
            "keychainReset",
        },
        "installation",
    )
    require(
        installation.get("previousBuildVersion") in EXPECTED_PREVIOUS_BUILDS,
        "installation must update in place from supported predecessor build 2026.8.15, 2026.8.17, 2026.8.18, 2026.8.19, 2026.8.20, 2026.8.21, 2026.8.22, 2026.8.23, 2026.8.24, 2026.8.25, 2026.8.26, 2026.8.27, or 2026.8.28",
    )
    require_true(installation, "installedInPlace")
    require_true(installation, "originalAppStoreContainerPreserved")
    for key in ("uninstalled", "offloaded", "downgraded", "dataCleared", "keychainReset"):
        require_false(installation, key)

    first_launch = require_mapping(evidence.get("firstLaunch"), "firstLaunch")
    require_exact_keys(
        first_launch,
        {
            "startedAt",
            "completedAt",
            "coldLaunch",
            "readyMarkerCount",
            "failedMarkerCount",
            "failureAlertShown",
            "pinAccepted",
            "walletRouteWorked",
            "bottomNavigationControlCount",
            *TAB_BAR_ROUTE_ATTESTATIONS,
            PI_PRICE_ATTESTATION,
            *POLKASWAP_ATTESTATIONS,
            *BITCOIN_ATTESTATIONS,
            *BITCOIN_FIRST_LAUNCH_PROVISIONING_ATTESTATIONS,
            *TAIRA_ATTESTATIONS,
            *FIRST_LAUNCH_ACCOUNTLESS_ATTESTATIONS,
            "captureReceiptSHA256",
        },
        "firstLaunch",
    )
    require_true(first_launch, "coldLaunch")
    require(
        first_launch.get("captureReceiptSHA256") == first_capture_receipt_sha256,
        "first launch capture receipt hash drifted",
    )
    require(
        first_launch.get("startedAt") == first_capture_receipt.get("startedAtUTC"),
        "first launch start does not match its capture receipt",
    )
    require(
        first_launch.get("completedAt")
        == first_capture_receipt.get("completedAtUTC"),
        "first launch completion does not match its capture receipt",
    )
    started_at = timestamp(first_launch.get("startedAt"), "firstLaunch.startedAt")
    completed_at = timestamp(first_launch.get("completedAt"), "firstLaunch.completedAt")
    require(
        (completed_at - started_at).total_seconds() >= MINIMUM_USABILITY_SECONDS,
        "first launch usability window must last at least five minutes",
    )
    require_integer(
        first_launch,
        "readyMarkerCount",
        1,
        "first launch must contain exactly one ready marker",
    )
    require_integer(
        first_launch,
        "failedMarkerCount",
        0,
        "first launch contains a failed marker",
    )
    require_false(first_launch, "failureAlertShown")
    require_true(first_launch, "pinAccepted")
    require_true(first_launch, "walletRouteWorked")
    require_integer(
        first_launch,
        "bottomNavigationControlCount",
        5,
        "first launch must expose all five bottom navigation controls",
    )
    for key in TAB_BAR_ROUTE_ATTESTATIONS:
        require_true(first_launch, key)
    require_true(first_launch, PI_PRICE_ATTESTATION)
    for key in POLKASWAP_ATTESTATIONS:
        require_true(first_launch, key)
    for key in BITCOIN_ATTESTATIONS:
        require_true(first_launch, key)
    for key in BITCOIN_FIRST_LAUNCH_PROVISIONING_ATTESTATIONS:
        require_true(first_launch, key)
    for key in TAIRA_ATTESTATIONS:
        require_true(first_launch, key)
    for key in FIRST_LAUNCH_ACCOUNTLESS_ATTESTATIONS:
        require_true(first_launch, key)
    require(
        first_launch.get("readyMarkerCount")
        == first_capture_receipt.get("readyMarkerCount"),
        "first launch READY count does not match its capture receipt",
    )
    require(
        first_launch.get("failedMarkerCount")
        == first_capture_receipt.get("failedMarkerCount"),
        "first launch FAILED count does not match its capture receipt",
    )

    preservation = require_mapping(evidence.get("preservation"), "preservation")
    require_exact_keys(
        preservation,
        {
            "appContainerPreserved",
            "walletCountsUnchanged",
            "logicalStoreIntegrityPassed",
            "keychainAccessible",
            "settingsAccessible",
        },
        "preservation",
    )
    for key in (
        "appContainerPreserved",
        "walletCountsUnchanged",
        "logicalStoreIntegrityPassed",
        "keychainAccessible",
        "settingsAccessible",
    ):
        require_true(preservation, key)

    second_launch = require_mapping(evidence.get("secondColdLaunch"), "secondColdLaunch")
    require_exact_keys(
        second_launch,
        {
            "startedAt",
            "completedAt",
            "readyMarkerCount",
            "failedMarkerCount",
            "coldLaunch",
            "failureAlertShown",
            "pinAccepted",
            "walletRouteWorked",
            "bottomNavigationControlCount",
            *TAB_BAR_ROUTE_ATTESTATIONS,
            PI_PRICE_ATTESTATION,
            *POLKASWAP_ATTESTATIONS,
            *BITCOIN_ATTESTATIONS,
            *BITCOIN_SECOND_LAUNCH_PROVISIONING_ATTESTATIONS,
            *TAIRA_ATTESTATIONS,
            "captureReceiptSHA256",
        },
        "secondColdLaunch",
    )
    require_true(second_launch, "coldLaunch")
    require(
        second_launch.get("captureReceiptSHA256") == second_capture_receipt_sha256,
        "second launch capture receipt hash drifted",
    )
    require(
        second_launch.get("startedAt") == second_capture_receipt.get("startedAtUTC"),
        "second launch start does not match its capture receipt",
    )
    require(
        second_launch.get("completedAt")
        == second_capture_receipt.get("completedAtUTC"),
        "second launch completion does not match its capture receipt",
    )
    require_integer(
        second_launch,
        "readyMarkerCount",
        1,
        "second cold launch must contain exactly one ready marker",
    )
    require_integer(
        second_launch,
        "failedMarkerCount",
        0,
        "second cold launch contains a failed marker",
    )
    require_false(second_launch, "failureAlertShown")
    require_true(second_launch, "pinAccepted")
    require_true(second_launch, "walletRouteWorked")
    require_integer(
        second_launch,
        "bottomNavigationControlCount",
        5,
        "second launch must expose all five bottom navigation controls",
    )
    for key in TAB_BAR_ROUTE_ATTESTATIONS:
        require_true(second_launch, key)
    require_true(second_launch, PI_PRICE_ATTESTATION)
    for key in POLKASWAP_ATTESTATIONS:
        require_true(second_launch, key)
    for key in BITCOIN_ATTESTATIONS:
        require_true(second_launch, key)
    for key in BITCOIN_SECOND_LAUNCH_PROVISIONING_ATTESTATIONS:
        require_true(second_launch, key)
    for key in TAIRA_ATTESTATIONS:
        require_true(second_launch, key)
    require(
        second_launch.get("readyMarkerCount")
        == second_capture_receipt.get("readyMarkerCount"),
        "second launch READY count does not match its capture receipt",
    )
    require(
        second_launch.get("failedMarkerCount")
        == second_capture_receipt.get("failedMarkerCount"),
        "second launch FAILED count does not match its capture receipt",
    )

    release = require_mapping(evidence.get("release"), "release")
    require_exact_keys(
        release,
        {"internalGroupValidatedFirst", "publicBetaReplacedBeforeGate"},
        "release",
    )
    require_true(release, "internalGroupValidatedFirst")
    require_false(release, "publicBetaReplacedBeforeGate")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path)
    parser.add_argument(
        "--first-launch-capture-receipt",
        required=True,
        type=Path,
        help="Privacy-safe capture-receipt.json for the five-minute launch",
    )
    parser.add_argument(
        "--second-launch-capture-receipt",
        required=True,
        type=Path,
        help="Privacy-safe capture-receipt.json for the second cold launch",
    )
    parser.add_argument(
        "--expected-artifact-source-commit",
        required=True,
        help="Exact clean commit embedded in the TestFlight hotfix artifact",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        require_private_regular_file(args.evidence, "upgrade usability evidence")
        require(
            args.first_launch_capture_receipt.resolve()
            != args.second_launch_capture_receipt.resolve(),
            "first and second launch capture receipt paths must be distinct",
        )
        with args.evidence.open("r", encoding="utf-8") as source:
            evidence = json.load(source)
        require(isinstance(evidence, dict), "evidence root must be an object")
        first_receipt, first_receipt_sha256 = load_capture_bundle(
            args.first_launch_capture_receipt,
            "first launch",
        )
        second_receipt, second_receipt_sha256 = load_capture_bundle(
            args.second_launch_capture_receipt,
            "second launch",
        )
        validate(
            evidence,
            args.expected_artifact_source_commit,
            first_receipt,
            first_receipt_sha256,
            second_receipt,
            second_receipt_sha256,
        )
    except (EvidenceError, json.JSONDecodeError, OSError) as error:
        print(f"TestFlight upgrade usability gate: FAILED: {error}")
        return 1

    print("TestFlight upgrade usability gate: PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
