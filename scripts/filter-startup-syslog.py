#!/usr/bin/env python3
"""Reduce Fearless process syslog NDJSON to privacy-safe startup diagnostics.

Input is expected to come from a process-filtered syslog stream. The filter never
writes the original line: it selects startup-related messages, removes values that
look like paths or identifiers, and emits a small stable NDJSON record.
"""

from __future__ import annotations

import argparse
import json
import posixpath
import re
import sys
from pathlib import Path
from typing import Any, TextIO


STARTUP_TERMS = re.compile(
    r"(?:FEARLESS_STARTUP|startup|setup|migrat|preflight|protected[ -]data|"
    r"selected[ -]wallet|wallet[ -]opening|core[ -]?data|persistent[ -]store|"
    r"database|storage|timeout|timed[ -]out|error|fail|exception|integrity|"
    r"insufficient[ -]space)",
    re.IGNORECASE,
)

LEGACY_DESCRIPTIONS = (
    ("protected_data", re.compile(r"protected[ -]data", re.IGNORECASE)),
    ("insufficient_storage", re.compile(r"insufficient[ -](?:space|storage)", re.IGNORECASE)),
    ("integrity", re.compile(r"integrity|quick[ _-]?check", re.IGNORECASE)),
    ("substrate_preflight", re.compile(r"preflight", re.IGNORECASE)),
    (
        "selected_wallet_opening",
        re.compile(r"selected[ -](?:wallet|account)|wallet[ -]opening", re.IGNORECASE),
    ),
    ("migration", re.compile(r"migrat", re.IGNORECASE)),
    ("storage", re.compile(r"core[ -]?data|persistent[ -]store|database|storage", re.IGNORECASE)),
    ("timeout", re.compile(r"timeout|timed[ -]out", re.IGNORECASE)),
    ("failure", re.compile(r"error|fail|exception", re.IGNORECASE)),
)

# These are exact, source-derived descriptions emitted by distributed build
# 2026.7.28. Values that may contain paths, entity names, model names, or store
# contents are matched but never retained.
LEGACY_INCIDENTS = (
    (
        "MIGRATION_TIMEOUT",
        "soft_threshold",
        re.compile(
            r"Wallet storage migration (?:timed out|is still running)",
            re.IGNORECASE,
        ),
    ),
    (
        "SUBSTRATE_PREFLIGHT_TIMEOUT",
        "soft_threshold",
        re.compile(r"Substrate storage preflight timed out", re.IGNORECASE),
    ),
    (
        "SELECTED_WALLET_OPENING_TIMEOUT",
        "soft_threshold",
        re.compile(r"Selected wallet storage setup timed out", re.IGNORECASE),
    ),
    (
        "USER_STORAGE_COMPATIBILITY_MISSING",
        "compatibility_model",
        re.compile(
            r"(?:Unsupported user store version|"
            r"User store model is unavailable for|"
            r"No user store migration path from)",
            re.IGNORECASE,
        ),
    ),
    (
        "USER_STORAGE_INTEGRITY_REJECTED",
        "staged_repair",
        re.compile(
            r"(?:A stored value could not be processed safely|"
            r"private user-storage copy could not be repaired safely|"
            r"migrated user store did not pass integrity validation)",
            re.IGNORECASE,
        ),
    ),
    (
        "SUBSTRATE_COMPATIBILITY_MISSING",
        "compatibility_model",
        re.compile(
            r"(?:Unsupported Substrate store version|"
            r"Substrate store model is unavailable for|"
            r"No forward Substrate store migration path from|"
            r"Unable to create the Substrate store mapping from|"
            r"staged Substrate store .* is not compatible with)",
            re.IGNORECASE,
        ),
    ),
    (
        "SUBSTRATE_INTEGRITY_REJECTED",
        "staged_repair",
        re.compile(
            r"(?:Substrate storage safely stopped during|"
            r"Protected-data inspection rejected the store|"
            r"Staged Substrate store changed .* row count|"
            r"Staged Substrate store changed protected local values|"
            r"unsupported cached value)",
            re.IGNORECASE,
        ),
    ),
    (
        "SUBSTRATE_PREFLIGHT_COMPATIBILITY_MISSING",
        "compatibility_model",
        re.compile(
            r"Substrate storage entity .* (?:has no managed object class|"
            r"cannot resolve class|resolves as .* expected)",
            re.IGNORECASE,
        ),
    ),
    (
        "WALLET_MAPPING_CONFLICT",
        "compatibility_mapping",
        re.compile(
            r"(?:wallet store contains duplicate identifiers|"
            r"supported wallet conflicts with an unsupported stored wallet)",
            re.IGNORECASE,
        ),
    ),
    (
        "WALLET_RECORD_REJECTED",
        "staged_repair",
        re.compile(
            r"(?:stored wallet does not contain the account fields supported|"
            r"stored wallet record is invalid|"
            r"wallet order cannot be incremented safely)",
            re.IGNORECASE,
        ),
    ),
)

LEGACY_INSUFFICIENT_STORAGE = re.compile(
    r"SQLite replacement requires ([0-9]{1,20}) free bytes, but only "
    r"[0-9]{1,20} bytes are available",
    re.IGNORECASE,
)
MAX_UINT64 = (1 << 64) - 1

UUID_VALUE = re.compile(
    r"(?<![0-9A-Fa-f])[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(?![0-9A-Fa-f])"
)
HEX_VALUE = re.compile(r"(?<![0-9A-Za-z])(?:0x)?[0-9A-Fa-f]{32,}(?![0-9A-Za-z])")
LONG_TOKEN = re.compile(r"(?<![0-9A-Za-z])[0-9A-Za-z_+/=-]{32,}(?![0-9A-Za-z])")
DEVICE_PATH = re.compile(r"/(?:private/var|var|Users|Volumes|mobile)/[^\s\]\[(){}<>\"']+")
URL_QUERY = re.compile(r"(https?://[^\s?]+)\?[^\s]+", re.IGNORECASE)
LABELED_VALUE = re.compile(
    r"\b(address|account|wallet|meta(?:id)?|public[ -]?key|private[ -]?key|"
    r"seed|mnemonic|secret|token)\s*[:=]\s*([^\s,;]+)",
    re.IGNORECASE,
)

SAFE_TIMESTAMP = re.compile(
    r"[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}"
    r"(?:\.[0-9]{1,9})?(?:Z|[+-][0-9]{2}:?[0-9]{2})?"
)
SAFE_LEVELS = {
    "DEBUG",
    "INFO",
    "NOTICE",
    "WARNING",
    "ERROR",
    "FAULT",
    "DEFAULT",
}
SETUP_PHASES = (
    "languageMigration",
    "userStorageMigration",
    "substrateMigration",
    "substratePreflight",
    "selectedWalletOpening",
)
INCIDENT_CODES = (
    "LANGUAGE_MIGRATION_FAILED",
    "USER_STORAGE_MIGRATION_FAILED",
    "USER_STORAGE_COMPATIBILITY_MISSING",
    "USER_STORAGE_INTEGRITY_REJECTED",
    "SUBSTRATE_MIGRATION_FAILED",
    "SUBSTRATE_COMPATIBILITY_MISSING",
    "SUBSTRATE_INTEGRITY_REJECTED",
    "SUBSTRATE_PREFLIGHT_FAILED",
    "SUBSTRATE_PREFLIGHT_COMPATIBILITY_MISSING",
    "SELECTED_WALLET_OPENING_FAILED",
    "WALLET_MAPPING_CONFLICT",
    "WALLET_RECORD_REJECTED",
    "INSUFFICIENT_STORAGE",
)
RECOVERY_ACTIONS = ("retry", "install_latest_build", "free_storage")
EXPECTED_SUBSYSTEM = "jp.co.soramitsu.fearlesswallet"
STARTUP_CATEGORY = "startup-readiness"
STRUCTURED_MARKER = re.compile(
    rf"(?:FEARLESS_STARTUP_READY|"
    rf"FEARLESS_STARTUP_SLOW phase=(?:{'|'.join(SETUP_PHASES)}) "
    rf"elapsed_ms=[0-9]{{1,20}}|"
    rf"FEARLESS_STARTUP_FAILED phase=(?:{'|'.join(SETUP_PHASES)}) "
    rf"code=(?:{'|'.join(INCIDENT_CODES)}) elapsed_ms=[0-9]{{1,20}} "
    rf"recovery=(?:{'|'.join(RECOVERY_ACTIONS)}) "
    rf"required_free_bytes=[0-9]{{1,20}})"
)
LEGACY_UNTYPED_FAILURE_MARKER = "FEARLESS_STARTUP_FAILED"


def sanitize_message(message: str) -> str:
    """Return a single-line message with identifier-shaped values removed."""

    sanitized = message.replace("\r", " ").replace("\n", " ")
    sanitized = DEVICE_PATH.sub("<redacted-path>", sanitized)
    sanitized = URL_QUERY.sub(r"\1?<redacted-query>", sanitized)
    sanitized = UUID_VALUE.sub("<redacted-id>", sanitized)
    sanitized = HEX_VALUE.sub("<redacted-hex>", sanitized)
    sanitized = LONG_TOKEN.sub("<redacted-identifier>", sanitized)
    sanitized = LABELED_VALUE.sub(r"\1: <redacted-value>", sanitized)
    return " ".join(sanitized.split())


def privacy_safe_known_legacy_incident(message: str) -> str | None:
    """Map a source-derived legacy description to a stable safe incident."""

    insufficient_storage = LEGACY_INSUFFICIENT_STORAGE.search(message)
    if insufficient_storage is not None:
        required_free_bytes = int(insufficient_storage.group(1))
        if required_free_bytes <= MAX_UINT64:
            return (
                "legacy_incident_code=INSUFFICIENT_STORAGE "
                f"legacy_resolution=free_storage required_free_bytes={required_free_bytes}"
            )

    for incident_code, resolution, pattern in LEGACY_INCIDENTS:
        if pattern.search(message):
            return (
                f"legacy_incident_code={incident_code} "
                f"legacy_resolution={resolution}"
            )

    return None


def privacy_safe_legacy_description(message: str) -> str:
    """Classify legacy output without retaining any user-controlled text."""

    known_incident = privacy_safe_known_legacy_incident(message)
    if known_incident is not None:
        return known_incident

    descriptions = [
        description
        for description, pattern in LEGACY_DESCRIPTIONS
        if pattern.search(message)
    ]
    if not descriptions:
        descriptions = ["startup"]
    return "legacy_startup_description=" + ",".join(descriptions)


def safe_subsystem(value: Any) -> str | None:
    return EXPECTED_SUBSYSTEM if value == EXPECTED_SUBSYSTEM else None


def safe_category(value: Any) -> str | None:
    return STARTUP_CATEGORY if value == STARTUP_CATEGORY else None


def safe_timestamp(value: Any) -> str | None:
    if not isinstance(value, str) or SAFE_TIMESTAMP.fullmatch(value) is None:
        return None
    return value


def safe_level(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.upper()
    return normalized if normalized in SAFE_LEVELS else None


def privacy_safe_structured_message(message: str) -> str:
    """Keep only exact markers emitted by the hotfix or distributed .28 build."""

    candidate = sanitize_message(message)
    if candidate == LEGACY_UNTYPED_FAILURE_MARKER:
        return candidate
    if STRUCTURED_MARKER.fullmatch(candidate) is not None:
        return candidate
    return "invalid_startup_marker"


def safe_record(entry: dict[str, Any]) -> dict[str, Any] | None:
    """Select one startup entry and retain only privacy-safe fields."""

    message = entry.get("message")
    if not isinstance(message, str):
        return None

    label = entry.get("label")
    subsystem = safe_subsystem(label.get("subsystem")) if isinstance(label, dict) else None
    category = safe_category(label.get("category")) if isinstance(label, dict) else None
    is_startup_category = category == STARTUP_CATEGORY
    known_legacy_incident = privacy_safe_known_legacy_incident(message)

    if (
        not is_startup_category
        and known_legacy_incident is None
        and not STARTUP_TERMS.search(message)
    ):
        return None

    if is_startup_category or "FEARLESS_STARTUP_" in message:
        safe_message = privacy_safe_structured_message(message)
    else:
        safe_message = known_legacy_incident or privacy_safe_legacy_description(message)

    return {
        "timestamp": safe_timestamp(entry.get("timestamp")),
        "level": safe_level(entry.get("level")),
        "subsystem": subsystem,
        "category": category,
        "message": safe_message,
    }


def emit(record: dict[str, Any], streams: list[TextIO]) -> None:
    line = json.dumps(record, ensure_ascii=False, sort_keys=True)
    for stream in streams:
        print(line, file=stream, flush=True)


class FilterProtocolError(ValueError):
    pass


def filter_stream(
    source: TextIO,
    streams: list[TextIO],
    expected_process: str | None = None,
    expected_pid: int | None = None,
    bind_first_pid: bool = False,
) -> None:
    baseline_emitted = False
    bound_pid = expected_pid

    for line in source:
        try:
            entry = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            if expected_process is not None:
                raise FilterProtocolError("malformed process-filtered NDJSON")
            continue

        if not isinstance(entry, dict):
            if expected_process is not None:
                raise FilterProtocolError("invalid process-filtered record")
            continue

        control = entry.get("capture_control")
        if control is not None:
            if expected_process is None or not bind_first_pid:
                raise FilterProtocolError("unexpected capture control")
            filename = entry.get("filename")
            if not isinstance(filename, str) or posixpath.basename(filename) != expected_process:
                raise FilterProtocolError("unexpected process envelope")
            if control == "pid_watcher_armed":
                if set(entry) != {"capture_control", "filename"}:
                    raise FilterProtocolError("invalid watcher control")
                emit(
                    {"event": "FEARLESS_PID_WATCHER_ARMED", "timestamp": None},
                    streams,
                )
                continue
            if control == "target_process_observed":
                if set(entry) != {"capture_control", "filename", "pid"}:
                    raise FilterProtocolError("invalid process control")
                pid = entry.get("pid")
                if type(pid) is not int or pid <= 0:
                    raise FilterProtocolError("invalid process control")
                if bound_pid is not None and bound_pid != pid:
                    raise FilterProtocolError("multiple process instances")
                bound_pid = pid
                emit(
                    {"event": "FEARLESS_TARGET_PROCESS_OBSERVED", "timestamp": None},
                    streams,
                )
                continue
            raise FilterProtocolError("unknown capture control")

        if expected_process is not None:
            filename = entry.get("filename")
            if not isinstance(filename, str) or posixpath.basename(filename) != expected_process:
                raise FilterProtocolError("unexpected process envelope")
        if bind_first_pid and bound_pid is None:
            raise FilterProtocolError("process record arrived before binding")
        if bound_pid is not None and entry.get("pid") != bound_pid:
            raise FilterProtocolError("unexpected pid envelope")

        if not baseline_emitted:
            emit(
                {
                    "event": "FEARLESS_STARTUP_CAPTURE_BEGIN",
                    "timestamp": safe_timestamp(entry.get("timestamp")),
                },
                streams,
            )
            baseline_emitted = True

        record = safe_record(entry)
        if record is not None:
            emit(record, streams)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional path for the sanitized NDJSON (stdout is always retained).",
    )
    parser.add_argument(
        "--expected-process",
        help=(
            "Fail closed unless every upstream JSON envelope belongs to this exact "
            "process basename; the process value is never emitted"
        ),
    )
    parser.add_argument(
        "--expected-pid",
        type=int,
        help="Fail closed unless every envelope has this PID; the PID is never emitted",
    )
    parser.add_argument(
        "--bind-first-pid",
        action="store_true",
        help="Bind a private PID from the reviewed watcher control; never emit it",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output: TextIO | None = None

    try:
        if args.expected_pid is not None and args.bind_first_pid:
            raise FilterProtocolError("conflicting pid modes")
        streams = [sys.stdout]
        if args.output is not None:
            output = args.output.open("w", encoding="utf-8")
            streams.append(output)
        filter_stream(
            sys.stdin,
            streams,
            expected_process=args.expected_process,
            expected_pid=args.expected_pid,
            bind_first_pid=args.bind_first_pid,
        )
    except BrokenPipeError:
        return 0
    except FilterProtocolError:
        return 2
    finally:
        if output is not None:
            output.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
