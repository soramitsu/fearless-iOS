#!/usr/bin/env python3
"""Fail-closed audit for sanitized physical TestFlight upgrade evidence."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any


EXPECTED_BUNDLE_ID = "jp.co.soramitsu.fearlesswallet"
EXPECTED_VERSION = "4.2.0"
EXPECTED_BUILD = "2026.8.10"
EXPECTED_BASE_SOURCE_COMMIT = "2e45e55dc03ad904598e730cfb5994fb5c1072dc"
MINIMUM_USABILITY_SECONDS = 300


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


def validate(evidence: dict[str, Any], expected_artifact_source_commit: str) -> None:
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
            "uninstalled",
            "offloaded",
            "downgraded",
            "dataCleared",
            "keychainReset",
        },
        "installation",
    )
    require(
        installation.get("previousBuildVersion") == "2026.7.28",
        "installation must originate from build 2026.7.28",
    )
    require_true(installation, "installedInPlace")
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
        },
        "firstLaunch",
    )
    require_true(first_launch, "coldLaunch")
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
            "readyMarkerCount",
            "failedMarkerCount",
            "coldLaunch",
            "failureAlertShown",
            "pinAccepted",
            "walletRouteWorked",
        },
        "secondColdLaunch",
    )
    require_true(second_launch, "coldLaunch")
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
        "--expected-artifact-source-commit",
        required=True,
        help="Exact clean commit embedded in the TestFlight hotfix artifact",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        with args.evidence.open("r", encoding="utf-8") as source:
            evidence = json.load(source)
        require(isinstance(evidence, dict), "evidence root must be an object")
        validate(evidence, args.expected_artifact_source_commit)
    except (EvidenceError, json.JSONDecodeError, OSError) as error:
        print(f"TestFlight upgrade usability gate: FAILED: {error}")
        return 1

    print("TestFlight upgrade usability gate: PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
