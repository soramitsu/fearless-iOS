#!/usr/bin/env python3
"""Capture one privacy-safe Fearless TestFlight startup from a paired iPhone.

The device syslog is never written or returned to this process. The
Fearless-process-only stream is connected directly to filter-startup-syslog.py
through an OS pipe. This supervisor persists only validated, canonicalized
filter output and a small lifecycle receipt with no device or process IDs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import queue
import re
import signal
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Protocol


EXPECTED_BUNDLE_IDENTIFIER = "jp.co.soramitsu.fearlesswallet"
EXPECTED_MARKETING_VERSION = "4.2.0"
EXPECTED_BUILD_NUMBER = "2026.7.28"
FAILED_HOTFIX_BUILD_NUMBER = "2026.8.10"
FAILED_TAB_BAR_HOTFIX_BUILD_NUMBER = "2026.8.13"
LEGACY_COMPATIBILITY_BUILD_NUMBER = "2026.8.15"
REDESIGN_WITHOUT_BITCOIN_BUILD_NUMBER = "2026.8.17"
BITCOIN_WITH_POLKASWAP_REGRESSION_BUILD_NUMBER = "2026.8.18"
POLKASWAP_WITH_HIDDEN_CTA_BUILD_NUMBER = "2026.8.19"
HOTFIX_BUILD_NUMBER = "2026.8.20"
SUPPORTED_CAPTURE_BUILD_NUMBERS = (
    EXPECTED_BUILD_NUMBER,
    FAILED_HOTFIX_BUILD_NUMBER,
    FAILED_TAB_BAR_HOTFIX_BUILD_NUMBER,
    LEGACY_COMPATIBILITY_BUILD_NUMBER,
    REDESIGN_WITHOUT_BITCOIN_BUILD_NUMBER,
    BITCOIN_WITH_POLKASWAP_REGRESSION_BUILD_NUMBER,
    POLKASWAP_WITH_HIDDEN_CTA_BUILD_NUMBER,
    HOTFIX_BUILD_NUMBER,
)
PROCESS_NAME = "fearless"
SUPPORTED_PYMOBILEDEVICE3_VERSION = "10.7.2"
MAX_PROCESS_TOKEN = (1 << 32) - 1
CAPTURE_INTERRUPT_SIGNALS = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)

EXIT_OUTPUT_EXISTS = 20
EXIT_DEPENDENCY = 21
EXIT_DEVICE_WAIT_TIMEOUT = 30
EXIT_AMBIGUOUS_DEVICE = 31
EXIT_INSTALLED_IDENTITY = 32
EXIT_LIFECYCLE = 40
EXIT_CAPTURE_PIPELINE = 41
EXIT_SANITIZED_PROTOCOL = 42
EXIT_INTERRUPTED = 130

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
SAFE_SUBSYSTEM = EXPECTED_BUNDLE_IDENTIFIER
SAFE_CATEGORY = "startup-readiness"
SAFE_PHASES = (
    "languageMigration",
    "userStorageMigration",
    "substrateMigration",
    "substratePreflight",
    "selectedWalletOpening",
)
SAFE_INCIDENT_CODES = (
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
SAFE_RECOVERY_ACTIONS = ("retry", "install_latest_build", "free_storage")
SAFE_LEGACY_INCIDENT_CODES = (
    "MIGRATION_TIMEOUT",
    "SUBSTRATE_PREFLIGHT_TIMEOUT",
    "SELECTED_WALLET_OPENING_TIMEOUT",
    "USER_STORAGE_COMPATIBILITY_MISSING",
    "USER_STORAGE_INTEGRITY_REJECTED",
    "SUBSTRATE_COMPATIBILITY_MISSING",
    "SUBSTRATE_INTEGRITY_REJECTED",
    "SUBSTRATE_PREFLIGHT_COMPATIBILITY_MISSING",
    "WALLET_MAPPING_CONFLICT",
    "WALLET_RECORD_REJECTED",
    "INSUFFICIENT_STORAGE",
)
SAFE_LEGACY_RESOLUTIONS = (
    "soft_threshold",
    "compatibility_model",
    "staged_repair",
    "compatibility_mapping",
    "free_storage",
)
SAFE_LEGACY_DESCRIPTIONS = (
    "protected_data",
    "insufficient_storage",
    "integrity",
    "substrate_preflight",
    "selected_wallet_opening",
    "migration",
    "storage",
    "timeout",
    "failure",
    "startup",
)

STRUCTURED_MARKER = re.compile(
    rf"(?:FEARLESS_STARTUP_READY|"
    rf"FEARLESS_STARTUP_SLOW phase=(?:{'|'.join(SAFE_PHASES)}) "
    rf"elapsed_ms=[0-9]{{1,20}}|"
    rf"FEARLESS_STARTUP_FAILED phase=(?:{'|'.join(SAFE_PHASES)}) "
    rf"code=(?:{'|'.join(SAFE_INCIDENT_CODES)}) elapsed_ms=[0-9]{{1,20}} "
    rf"recovery=(?:{'|'.join(SAFE_RECOVERY_ACTIONS)}) "
    rf"required_free_bytes=[0-9]{{1,20}})"
)
LEGACY_INCIDENT = re.compile(
    rf"legacy_incident_code=({'|'.join(SAFE_LEGACY_INCIDENT_CODES)}) "
    rf"legacy_resolution=(?:{'|'.join(SAFE_LEGACY_RESOLUTIONS)})"
    rf"(?: required_free_bytes=[0-9]{{1,20}})?"
)
LEGACY_DESCRIPTION = re.compile(
    rf"legacy_startup_description=(?:{'|'.join(SAFE_LEGACY_DESCRIPTIONS)})"
    rf"(?:,(?:{'|'.join(SAFE_LEGACY_DESCRIPTIONS)}))*"
)


class CaptureError(RuntimeError):
    def __init__(self, reason: str, exit_code: int):
        super().__init__(reason)
        self.reason = reason
        self.exit_code = exit_code


class DeviceUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class AppIdentity:
    bundle_identifier: str
    marketing_version: str
    build_number: str


@dataclass(frozen=True)
class ProcessSnapshot:
    running: bool
    token: int | None


class SanitizedPipeline(Protocol):
    def drain(self) -> list[dict[str, Any]]: ...

    def failure_reason(self) -> str | None: ...

    def begin_count(self) -> int: ...

    def watcher_armed_count(self) -> int: ...

    def launch_count(self) -> int: ...

    def finalize(self) -> list[dict[str, Any]]: ...

    def close(self) -> None: ...


class DeviceBackend(Protocol):
    def usb_device_tokens(self) -> list[str]: ...

    def app_identity(self, device_token: str) -> AppIdentity: ...

    def process_snapshot(self, device_token: str) -> ProcessSnapshot: ...

    def start_pipeline(self, device_token: str) -> SanitizedPipeline: ...


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def controlled_interrupt(_signum: int, _frame: Any) -> None:
    raise KeyboardInterrupt


def safe_timestamp(value: Any) -> bool:
    return value is None or (
        isinstance(value, str) and SAFE_TIMESTAMP.fullmatch(value) is not None
    )


def validate_sanitized_record(record: Any) -> dict[str, Any] | None:
    """Validate filter output and return a canonical safe record.

    The filter's own begin marker is intentionally discarded. This wrapper
    creates the authoritative begin marker only after observing the one cold
    launch, so pre-launch records cannot enter the final evidence window.
    """

    if not isinstance(record, dict):
        raise CaptureError("invalid_sanitized_record", EXIT_SANITIZED_PROTOCOL)

    if set(record) == {"event", "timestamp"}:
        if record.get("event") != "FEARLESS_STARTUP_CAPTURE_BEGIN":
            raise CaptureError("invalid_sanitized_event", EXIT_SANITIZED_PROTOCOL)
        if not safe_timestamp(record.get("timestamp")):
            raise CaptureError("invalid_sanitized_timestamp", EXIT_SANITIZED_PROTOCOL)
        return None

    expected_keys = {"timestamp", "level", "subsystem", "category", "message"}
    if set(record) != expected_keys:
        raise CaptureError("invalid_sanitized_schema", EXIT_SANITIZED_PROTOCOL)
    if not safe_timestamp(record.get("timestamp")):
        raise CaptureError("invalid_sanitized_timestamp", EXIT_SANITIZED_PROTOCOL)
    if record.get("level") is not None and record.get("level") not in SAFE_LEVELS:
        raise CaptureError("invalid_sanitized_level", EXIT_SANITIZED_PROTOCOL)
    if record.get("subsystem") not in (None, SAFE_SUBSYSTEM):
        raise CaptureError("invalid_sanitized_subsystem", EXIT_SANITIZED_PROTOCOL)
    if record.get("category") not in (None, SAFE_CATEGORY):
        raise CaptureError("invalid_sanitized_category", EXIT_SANITIZED_PROTOCOL)

    message = record.get("message")
    if not isinstance(message, str):
        raise CaptureError("invalid_sanitized_message", EXIT_SANITIZED_PROTOCOL)
    if not (
        message == "FEARLESS_STARTUP_FAILED"
        or message == "invalid_startup_marker"
        or STRUCTURED_MARKER.fullmatch(message) is not None
        or LEGACY_INCIDENT.fullmatch(message) is not None
        or LEGACY_DESCRIPTION.fullmatch(message) is not None
    ):
        raise CaptureError("unsafe_sanitized_message", EXIT_SANITIZED_PROTOCOL)

    return {
        "timestamp": record.get("timestamp"),
        "level": record.get("level"),
        "subsystem": record.get("subsystem"),
        "category": record.get("category"),
        "message": message,
    }


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    pending = path.with_name(f".{path.name}.pending")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    descriptor = os.open(pending, flags, 0o600)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(payload, stream, ensure_ascii=False, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(pending, path)
    except BaseException:
        try:
            pending.unlink()
        except FileNotFoundError:
            pass
        raise


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


class FilterPipeline:
    def __init__(
        self,
        device_python: Path,
        stream_helper_path: Path,
        filter_path: Path,
        device_token: str,
    ) -> None:
        self._queue: queue.Queue[tuple[str, Any]] = queue.Queue()
        self._closing = False
        self._begin_count = 0
        self._watcher_armed_count = 0
        self._launch_count = 0
        filter_process: subprocess.Popen[str] | None = None
        syslog_process: subprocess.Popen[str] | None = None
        reader: threading.Thread | None = None
        try:
            filter_process = subprocess.Popen(
                [
                    sys.executable,
                    str(filter_path),
                    "--expected-process",
                    PROCESS_NAME,
                    "--bind-first-pid",
                ],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
            )
            if filter_process.stdin is None or filter_process.stdout is None:
                raise CaptureError(
                    "filter_pipe_unavailable", EXIT_CAPTURE_PIPELINE
                )

            syslog_process = subprocess.Popen(
                [
                    str(device_python),
                    str(stream_helper_path),
                    "--udid",
                    device_token,
                    "--expected-process",
                    PROCESS_NAME,
                    "--process-poll-interval",
                    "0.02",
                ],
                stdout=filter_process.stdin,
                stderr=subprocess.DEVNULL,
                text=True,
            )
            # Only the syslog child retains the raw-pipe writer. This process
            # never reads, buffers, logs, or persists the unfiltered stream.
            filter_process.stdin.close()

            self._filter = filter_process
            self._syslog = syslog_process
            reader = threading.Thread(
                target=self._read_safe_output,
                daemon=True,
            )
            self._reader = reader
            reader.start()
        except BaseException:
            if syslog_process is not None:
                self._terminate_process(syslog_process)
            if filter_process is not None:
                if filter_process.stdin is not None:
                    filter_process.stdin.close()
                self._terminate_process(filter_process)
                if filter_process.stdout is not None:
                    filter_process.stdout.close()
            if reader is not None and reader.is_alive():
                reader.join(timeout=5)
            raise

    @staticmethod
    def _terminate_process(process: subprocess.Popen[str]) -> None:
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)

    def _read_safe_output(self) -> None:
        assert self._filter.stdout is not None
        try:
            for line in self._filter.stdout:
                try:
                    record = json.loads(line)
                except (json.JSONDecodeError, TypeError):
                    self._queue.put(("error", "invalid_filter_ndjson"))
                    return
                if record == {
                    "event": "FEARLESS_PID_WATCHER_ARMED",
                    "timestamp": None,
                }:
                    self._watcher_armed_count += 1
                    continue
                if record == {
                    "event": "FEARLESS_TARGET_PROCESS_OBSERVED",
                    "timestamp": None,
                }:
                    self._launch_count += 1
                    continue
                try:
                    validated = validate_sanitized_record(record)
                except CaptureError as error:
                    self._queue.put(("error", error.reason))
                    return
                if validated is not None:
                    self._queue.put(("record", validated))
                else:
                    self._begin_count += 1
        finally:
            self._queue.put(("eof", None))

    def drain(self) -> list[dict[str, Any]]:
        records: list[dict[str, Any]] = []
        while True:
            try:
                kind, value = self._queue.get_nowait()
            except queue.Empty:
                break
            if kind == "record":
                records.append(value)
            elif kind == "error":
                raise CaptureError(str(value), EXIT_SANITIZED_PROTOCOL)
        return records

    def failure_reason(self) -> str | None:
        if self._closing:
            return None
        if self._syslog.poll() is not None:
            return "syslog_stream_ended"
        if self._filter.poll() is not None:
            return "sanitizer_ended"
        return None

    def begin_count(self) -> int:
        return self._begin_count

    def watcher_armed_count(self) -> int:
        return self._watcher_armed_count

    def launch_count(self) -> int:
        return self._launch_count

    def finalize(self) -> list[dict[str, Any]]:
        """Stop the raw producer, consume sanitizer EOF, and return safe tail records."""

        if self._syslog.poll() is not None:
            raise CaptureError("device_pid_stream_ended", EXIT_CAPTURE_PIPELINE)
        self.close()
        if self._syslog.returncode != -signal.SIGTERM:
            raise CaptureError("device_pid_stream_ended", EXIT_CAPTURE_PIPELINE)
        if self._reader.is_alive():
            raise CaptureError("sanitizer_reader_did_not_finish", EXIT_CAPTURE_PIPELINE)
        if self._filter.returncode != 0:
            raise CaptureError("sanitizer_protocol_failed", EXIT_CAPTURE_PIPELINE)
        return self.drain()

    def close(self) -> None:
        if self._closing:
            return
        self._closing = True
        if self._syslog.poll() is None:
            self._syslog.terminate()
        try:
            self._syslog.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self._syslog.kill()
            self._syslog.wait(timeout=5)
        try:
            self._filter.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self._filter.terminate()
            try:
                self._filter.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._filter.kill()
                self._filter.wait(timeout=5)
        self._reader.join(timeout=5)
        if self._filter.stdout is not None:
            self._filter.stdout.close()


class PymobiledeviceBackend:
    def __init__(
        self,
        executable: Path,
        stream_helper_path: Path,
        filter_path: Path,
        command_timeout: float,
    ):
        self.executable = executable
        self.device_python = self._pinned_interpreter(executable)
        self.stream_helper_path = stream_helper_path
        self.filter_path = filter_path
        self.command_timeout = command_timeout

    @staticmethod
    def _pinned_interpreter(executable: Path) -> Path:
        try:
            with executable.open("rb") as stream:
                first_line = stream.readline(4096).decode("utf-8").strip()
        except (OSError, UnicodeDecodeError) as error:
            raise CaptureError(
                "pymobiledevice3_shebang_unavailable", EXIT_DEPENDENCY
            ) from error
        if not first_line.startswith("#!/"):
            raise CaptureError("pymobiledevice3_shebang_unavailable", EXIT_DEPENDENCY)
        interpreter = Path(first_line[2:])
        try:
            same_environment = (
                interpreter.parent.resolve() == executable.parent.resolve()
            )
        except OSError as error:
            raise CaptureError("pymobiledevice3_interpreter_unavailable", EXIT_DEPENDENCY) from error
        if (
            not same_environment
            or not interpreter.exists()
            or not os.access(interpreter, os.X_OK)
        ):
            raise CaptureError(
                "pymobiledevice3_interpreter_unavailable", EXIT_DEPENDENCY
            )
        return interpreter

    def _json_command(self, arguments: list[str]) -> Any:
        try:
            result = subprocess.run(
                [str(self.executable), *arguments],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                check=False,
                timeout=self.command_timeout,
                text=True,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise DeviceUnavailable from error
        if result.returncode != 0:
            raise DeviceUnavailable
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise DeviceUnavailable from error

    def backend_version(self) -> str:
        try:
            result = subprocess.run(
                [str(self.executable), "version"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                check=False,
                timeout=self.command_timeout,
                text=True,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise CaptureError("pymobiledevice3_version_unavailable", EXIT_DEPENDENCY) from error
        value = result.stdout.strip()
        if result.returncode != 0 or re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", value) is None:
            raise CaptureError("pymobiledevice3_version_unavailable", EXIT_DEPENDENCY)
        return value

    def usb_device_tokens(self) -> list[str]:
        value = self._json_command(["usbmux", "list", "--usb", "--simple"])
        if not isinstance(value, list) or not all(
            isinstance(item, str) and item for item in value
        ):
            raise DeviceUnavailable
        return value

    def app_identity(self, device_token: str) -> AppIdentity:
        value = self._json_command(
            [
                "apps",
                "query",
                EXPECTED_BUNDLE_IDENTIFIER,
                "--udid",
                device_token,
            ]
        )
        if not isinstance(value, dict):
            raise DeviceUnavailable
        app = value.get(EXPECTED_BUNDLE_IDENTIFIER)
        if not isinstance(app, dict):
            raise CaptureError("fearless_not_installed", EXIT_INSTALLED_IDENTITY)
        bundle = app.get("CFBundleIdentifier")
        version = app.get("CFBundleShortVersionString")
        build = app.get("CFBundleVersion")
        if not all(isinstance(item, str) for item in (bundle, version, build)):
            raise CaptureError("installed_identity_incomplete", EXIT_INSTALLED_IDENTITY)
        return AppIdentity(bundle, version, build)

    def process_snapshot(self, device_token: str) -> ProcessSnapshot:
        value = self._json_command(
            ["processes", "pgrep", PROCESS_NAME, "--udid", device_token]
        )
        if not isinstance(value, list):
            raise DeviceUnavailable
        exact = [
            item
            for item in value
            if isinstance(item, dict) and item.get("name") == PROCESS_NAME
        ]
        if len(exact) > 1:
            raise CaptureError("multiple_fearless_processes", EXIT_LIFECYCLE)
        if not exact:
            return ProcessSnapshot(False, None)
        raw_token = exact[0].get("pid")
        if type(raw_token) is int:
            token = raw_token
        elif (
            isinstance(raw_token, str)
            and raw_token.isascii()
            and raw_token.isdecimal()
        ):
            token = int(raw_token)
        else:
            raise CaptureError("invalid_process_snapshot", EXIT_LIFECYCLE)
        if token <= 0 or token > MAX_PROCESS_TOKEN:
            raise CaptureError("invalid_process_snapshot", EXIT_LIFECYCLE)
        return ProcessSnapshot(True, token)

    def start_pipeline(self, device_token: str) -> SanitizedPipeline:
        return FilterPipeline(
            self.device_python,
            self.stream_helper_path,
            self.filter_path,
            device_token,
        )


@dataclass(frozen=True)
class CaptureSettings:
    poll_interval: float
    device_poll_interval: float
    device_wait_timeout: float
    stop_wait_timeout: float
    watcher_arm_timeout: float
    start_wait_timeout: float
    observation_seconds: float
    terminal_grace_seconds: float
    ready_observation_seconds: float = 0
    expected_build_number: str = EXPECTED_BUILD_NUMBER


@dataclass(frozen=True)
class CaptureProvenance:
    backend_version: str
    capture_tool_sha256: str
    filter_sha256: str
    stream_helper_sha256: str


def validate_capture_settings(settings: CaptureSettings) -> None:
    duration_contract = (
        ("poll_interval", settings.poll_interval, False),
        ("device_poll_interval", settings.device_poll_interval, False),
        ("device_wait_timeout", settings.device_wait_timeout, True),
        ("stop_wait_timeout", settings.stop_wait_timeout, True),
        ("watcher_arm_timeout", settings.watcher_arm_timeout, False),
        ("start_wait_timeout", settings.start_wait_timeout, True),
        ("observation_seconds", settings.observation_seconds, False),
        ("terminal_grace_seconds", settings.terminal_grace_seconds, True),
        (
            "ready_observation_seconds",
            settings.ready_observation_seconds,
            True,
        ),
    )
    for name, value, zero_allowed in duration_contract:
        if type(value) not in (int, float) or not math.isfinite(value):
            raise CaptureError(f"{name}_must_be_finite", EXIT_DEPENDENCY)
        if value < 0 or (not zero_allowed and value == 0):
            suffix = "must_not_be_negative" if zero_allowed else "must_be_positive"
            raise CaptureError(f"{name}_{suffix}", EXIT_DEPENDENCY)
    if settings.expected_build_number not in SUPPORTED_CAPTURE_BUILD_NUMBERS:
        raise CaptureError("unsupported_expected_build", EXIT_DEPENDENCY)


class CaptureController:
    def __init__(
        self,
        backend: DeviceBackend,
        output_directory: Path,
        settings: CaptureSettings,
        provenance: CaptureProvenance | None = None,
    ) -> None:
        validate_capture_settings(settings)
        self.backend = backend
        self.output_directory = output_directory
        self.settings = settings
        self.provenance = provenance or CaptureProvenance(
            SUPPORTED_PYMOBILEDEVICE3_VERSION,
            "0" * 64,
            "0" * 64,
            "0" * 64,
        )
        self.pipeline: SanitizedPipeline | None = None
        self.pending_stream: Any = None
        self.pending_path = output_directory / ".fearless-startup-sanitized.ndjson.pending"
        self.final_log_path = output_directory / "fearless-startup-sanitized.ndjson"
        self.metadata_path = output_directory / "installed-app-metadata.json"
        self.receipt_path = output_directory / "capture-receipt.json"
        self.abort_path = output_directory / "capture-aborted.json"

    def _prepare_output(self) -> None:
        try:
            self.output_directory.mkdir(mode=0o700, parents=False, exist_ok=False)
        except FileExistsError as error:
            raise CaptureError("output_directory_exists", EXIT_OUTPUT_EXISTS) from error
        self.pending_stream = self.pending_path.open("x", encoding="utf-8")
        os.chmod(self.pending_path, 0o600)

    def _safe_metadata(self, identity: AppIdentity) -> dict[str, Any]:
        return {
            "schemaVersion": 1,
            "observationMethod": "paired-device-read-only-app-query",
            "observedAtUTC": utc_now(),
            "bundleIdentifier": identity.bundle_identifier,
            "marketingVersion": identity.marketing_version,
            "buildNumber": identity.build_number,
        }

    def _wait_for_identity(self) -> tuple[str, AppIdentity]:
        wait_started = time.monotonic()
        print("FEARLESS_CAPTURE_WAITING_FOR_PAIRED_DEVICE", flush=True)
        while True:
            if (
                self.settings.device_wait_timeout > 0
                and time.monotonic() - wait_started >= self.settings.device_wait_timeout
            ):
                raise CaptureError("paired_device_wait_timeout", EXIT_DEVICE_WAIT_TIMEOUT)
            try:
                tokens = self.backend.usb_device_tokens()
            except DeviceUnavailable:
                time.sleep(self.settings.device_poll_interval)
                continue
            if len(tokens) > 1:
                raise CaptureError("multiple_usb_devices", EXIT_AMBIGUOUS_DEVICE)
            if not tokens:
                time.sleep(self.settings.device_poll_interval)
                continue
            try:
                identity = self.backend.app_identity(tokens[0])
            except DeviceUnavailable:
                time.sleep(self.settings.device_poll_interval)
                continue
            atomic_json(self.metadata_path, self._safe_metadata(identity))
            expected = self._expected_identity()
            if identity != expected:
                raise CaptureError("installed_identity_mismatch", EXIT_INSTALLED_IDENTITY)
            return tokens[0], identity

    def _expected_identity(self) -> AppIdentity:
        return AppIdentity(
            EXPECTED_BUNDLE_IDENTIFIER,
            EXPECTED_MARKETING_VERSION,
            self.settings.expected_build_number,
        )

    def _reconnect_before_stop(
        self,
        device_token: str,
        original_process_token: int,
        stop_deadline: float | None,
    ) -> ProcessSnapshot:
        while True:
            if stop_deadline is not None and time.monotonic() >= stop_deadline:
                raise CaptureError("force_quit_wait_timeout", EXIT_LIFECYCLE)
            try:
                tokens = self.backend.usb_device_tokens()
            except DeviceUnavailable:
                time.sleep(self.settings.device_poll_interval)
                continue
            if len(tokens) > 1:
                raise CaptureError("multiple_usb_devices", EXIT_AMBIGUOUS_DEVICE)
            if not tokens:
                time.sleep(self.settings.device_poll_interval)
                continue
            if tokens[0] != device_token:
                raise CaptureError("device_continuity_lost_before_stop", EXIT_LIFECYCLE)
            try:
                identity = self.backend.app_identity(device_token)
                snapshot = self.backend.process_snapshot(device_token)
            except DeviceUnavailable:
                time.sleep(self.settings.device_poll_interval)
                continue
            if identity != self._expected_identity():
                raise CaptureError("installed_identity_changed", EXIT_INSTALLED_IDENTITY)
            if not snapshot.running or snapshot.token != original_process_token:
                raise CaptureError(
                    "lifecycle_continuity_lost_during_disconnect", EXIT_LIFECYCLE
                )
            return snapshot

    def _wait_for_stopped_boundary(
        self,
        device_token: str,
        initial: ProcessSnapshot,
    ) -> tuple[ProcessSnapshot, int]:
        if not initial.running:
            return initial, 0
        assert initial.token is not None
        print("FEARLESS_CAPTURE_WAITING_FOR_FORCE_QUIT", flush=True)
        stop_deadline = (
            time.monotonic() + self.settings.stop_wait_timeout
            if self.settings.stop_wait_timeout > 0
            else None
        )
        reconnect_count = 0
        while True:
            if stop_deadline is not None and time.monotonic() >= stop_deadline:
                raise CaptureError("force_quit_wait_timeout", EXIT_LIFECYCLE)
            try:
                snapshot = self.backend.process_snapshot(device_token)
            except DeviceUnavailable:
                snapshot = self._reconnect_before_stop(
                    device_token, initial.token, stop_deadline
                )
                reconnect_count += 1
            if not snapshot.running:
                print("FEARLESS_FORCE_QUIT_OBSERVED", flush=True)
                return snapshot, reconnect_count
            if snapshot.token != initial.token:
                raise CaptureError(
                    "process_replaced_without_observed_stop", EXIT_LIFECYCLE
                )
            time.sleep(self.settings.poll_interval)

    def _write_record(self, record: dict[str, Any]) -> None:
        assert self.pending_stream is not None
        json.dump(record, self.pending_stream, ensure_ascii=False, sort_keys=True)
        self.pending_stream.write("\n")
        self.pending_stream.flush()

    def _start_owned_pipeline(self, device_token: str) -> SanitizedPipeline:
        """Defer parent interrupts until every child is controller-owned.

        Caught signal dispositions reset when the children exec, so this does
        not alter their signal behavior. The parent restores its handlers
        before delivering a deferred interruption through the normal cleanup
        path.
        """

        previous_handlers = {
            signum: signal.getsignal(signum)
            for signum in CAPTURE_INTERRUPT_SIGNALS
        }
        deferred_signals: list[int] = []

        def defer_interrupt(signum: int, _frame: Any) -> None:
            deferred_signals.append(signum)

        captured_error: BaseException | None = None
        pipeline: SanitizedPipeline | None = None
        try:
            for signum in CAPTURE_INTERRUPT_SIGNALS:
                signal.signal(signum, defer_interrupt)
            pipeline = self.backend.start_pipeline(device_token)
            self.pipeline = pipeline
        except BaseException as error:
            captured_error = error
        finally:
            # Block only in the already-spawned parent while restoring all
            # handlers. Children never inherit this temporary mask.
            previous_mask = signal.pthread_sigmask(
                signal.SIG_BLOCK,
                CAPTURE_INTERRUPT_SIGNALS,
            )
            try:
                for signum, handler in previous_handlers.items():
                    signal.signal(signum, handler)
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)

        if deferred_signals:
            raise KeyboardInterrupt
        if captured_error is not None:
            raise captured_error
        assert pipeline is not None
        return pipeline

    def _publish_success(self, receipt: dict[str, Any]) -> None:
        assert self.pending_stream is not None
        self.pending_stream.flush()
        os.fsync(self.pending_stream.fileno())
        self.pending_stream.close()
        self.pending_stream = None
        receipt["sanitizedLogSHA256"] = file_sha256(self.pending_path)
        receipt["installedAppMetadataSHA256"] = file_sha256(self.metadata_path)
        os.replace(self.pending_path, self.final_log_path)
        atomic_json(self.receipt_path, receipt)

    def _publish_abort(self, error: CaptureError) -> None:
        if self.pending_stream is not None:
            self.pending_stream.close()
            self.pending_stream = None
        try:
            self.pending_path.unlink()
        except FileNotFoundError:
            pass
        atomic_json(
            self.abort_path,
            {
                "schemaVersion": 1,
                "audit": "fearless-testflight-startup-capture",
                "captureStatus": "aborted",
                "reason": error.reason,
                "observedAtUTC": utc_now(),
                "rawSyslogPersisted": False,
                "containerAccessed": False,
            },
        )

    def _discard_pending(self) -> None:
        if self.pending_stream is not None:
            self.pending_stream.close()
            self.pending_stream = None
        try:
            self.pending_path.unlink()
        except FileNotFoundError:
            pass

    @staticmethod
    def _classify_message(message: str) -> tuple[bool, bool, str | None]:
        ready = message == "FEARLESS_STARTUP_READY"
        failed = message == "FEARLESS_STARTUP_FAILED" or message.startswith(
            "FEARLESS_STARTUP_FAILED "
        )
        match = LEGACY_INCIDENT.fullmatch(message)
        incident = match.group(1) if match is not None else None
        if failed and " code=" in message:
            incident = message.split(" code=", 1)[1].split(" ", 1)[0]
        return ready, failed, incident

    def _safe_initial_snapshot(self, device_token: str) -> ProcessSnapshot:
        try:
            return self.backend.process_snapshot(device_token)
        except DeviceUnavailable as error:
            raise CaptureError(
                "device_disconnected_before_stopped_boundary", EXIT_LIFECYCLE
            ) from error

    def _require_distributed_identity(
        self,
        device_token: str,
        disconnect_reason: str,
    ) -> None:
        try:
            identity = self.backend.app_identity(device_token)
        except DeviceUnavailable as error:
            raise CaptureError(disconnect_reason, EXIT_LIFECYCLE) from error
        if identity != self._expected_identity():
            raise CaptureError("installed_identity_changed", EXIT_INSTALLED_IDENTITY)

    @staticmethod
    def _elapsed_milliseconds(started: float, observed: float) -> int:
        return max(0, round((observed - started) * 1000))

    def run(self) -> dict[str, Any]:
        self._prepare_output()
        try:
            device_token, identity = self._wait_for_identity()
            initial = self._safe_initial_snapshot(device_token)
            initial_state = "running" if initial.running else "stopped"
            stopped, reconnect_count = self._wait_for_stopped_boundary(
                device_token, initial
            )
            self._start_owned_pipeline(device_token)
            watcher_deadline = time.monotonic() + self.settings.watcher_arm_timeout
            while self.pipeline.watcher_armed_count() == 0:
                pipeline_failure = self.pipeline.failure_reason()
                if pipeline_failure is not None:
                    raise CaptureError(pipeline_failure, EXIT_CAPTURE_PIPELINE)
                if time.monotonic() >= watcher_deadline:
                    raise CaptureError(
                        "pid_watcher_arm_timeout", EXIT_CAPTURE_PIPELINE
                    )
                time.sleep(self.settings.poll_interval)
            if self.pipeline.watcher_armed_count() != 1:
                raise CaptureError("duplicate_pid_watcher_arm", EXIT_LIFECYCLE)
            self._require_distributed_identity(
                device_token,
                "device_disconnected_before_armed_identity_check",
            )
            try:
                confirmed = self.backend.process_snapshot(device_token)
            except DeviceUnavailable as error:
                raise CaptureError(
                    "device_disconnected_after_stopped_boundary", EXIT_LIFECYCLE
                ) from error
            pipeline_failure = self.pipeline.failure_reason()
            if pipeline_failure is not None:
                raise CaptureError(pipeline_failure, EXIT_CAPTURE_PIPELINE)
            if (
                confirmed.running
                or confirmed != stopped
                or self.pipeline.launch_count() != 0
            ):
                raise CaptureError("launch_started_before_armed", EXIT_LIFECYCLE)

            print(
                "FEARLESS_CAPTURE_ARMED "
                f"version={identity.marketing_version} build={identity.build_number} "
                f"initial_process_state={initial_state}",
                flush=True,
            )

            previous = confirmed
            launch_token: int | None = None
            launch_started_at_utc: str | None = None
            launch_started_monotonic: float | None = None
            terminal_deadline: float | None = None
            terminal_observation: str | None = None
            process_stop_count = int(initial.running)
            process_start_count = 0
            sanitized_record_count = 0
            ready_marker_count = 0
            failed_marker_count = 0
            incident_codes: list[str] = []
            first_diagnostic_elapsed_ms: int | None = None
            process_termination_elapsed_ms: int | None = None
            ready_marker_elapsed_ms: int | None = None
            ready_observed_monotonic: float | None = None
            launch_process_termination_observed = False
            launch_wait_started = time.monotonic()

            def consume_launch_records(records: list[dict[str, Any]]) -> None:
                nonlocal sanitized_record_count
                nonlocal ready_marker_count
                nonlocal failed_marker_count
                nonlocal first_diagnostic_elapsed_ms
                nonlocal terminal_observation
                nonlocal terminal_deadline
                nonlocal ready_marker_elapsed_ms
                nonlocal ready_observed_monotonic

                for record in records:
                    validated_record = validate_sanitized_record(record)
                    if validated_record is None:
                        continue
                    self._write_record(validated_record)
                    sanitized_record_count += 1
                    ready, failed, incident = self._classify_message(
                        validated_record["message"]
                    )
                    ready_marker_count += int(ready)
                    failed_marker_count += int(failed)
                    if ready_marker_count > 1:
                        raise CaptureError("duplicate_ready_marker", EXIT_LIFECYCLE)
                    if incident is not None and incident not in incident_codes:
                        incident_codes.append(incident)
                    if (
                        first_diagnostic_elapsed_ms is None
                        and (
                            failed
                            or incident is not None
                            or validated_record["message"].startswith(
                                "legacy_startup_description="
                            )
                        )
                        and launch_started_monotonic is not None
                    ):
                        first_diagnostic_elapsed_ms = max(
                            0,
                            self._elapsed_milliseconds(
                                launch_started_monotonic,
                                time.monotonic(),
                            ),
                        )
                    if failed:
                        terminal_observation = "failed_marker"
                        terminal_deadline = (
                            time.monotonic() + self.settings.terminal_grace_seconds
                        )
                    elif ready and terminal_observation is None:
                        ready_observed_monotonic = time.monotonic()
                        if launch_started_monotonic is not None:
                            ready_marker_elapsed_ms = self._elapsed_milliseconds(
                                launch_started_monotonic,
                                ready_observed_monotonic,
                            )
                        terminal_observation = "ready_marker"
                        terminal_deadline = (
                            ready_observed_monotonic
                            + max(
                                self.settings.terminal_grace_seconds,
                                self.settings.ready_observation_seconds,
                            )
                        )

            while True:
                pipeline_failure = self.pipeline.failure_reason()
                if pipeline_failure is not None:
                    raise CaptureError(pipeline_failure, EXIT_CAPTURE_PIPELINE)
                if self.pipeline.launch_count() > 1:
                    raise CaptureError("second_launch_observed", EXIT_LIFECYCLE)
                try:
                    snapshot = self.backend.process_snapshot(device_token)
                except DeviceUnavailable as error:
                    raise CaptureError(
                        "device_disconnected_after_armed", EXIT_LIFECYCLE
                    ) from error

                if launch_token is None:
                    watcher_observed_launch = self.pipeline.launch_count() == 1
                    if snapshot.running or watcher_observed_launch:
                        self._require_distributed_identity(
                            device_token,
                            "device_disconnected_at_launch_identity_check",
                        )
                        launch_token = snapshot.token if snapshot.running else 0
                        process_start_count = 1
                        launch_started_at_utc = utc_now()
                        launch_started_monotonic = time.monotonic()
                        self._write_record(
                            {
                                "event": "FEARLESS_COLD_LAUNCH_CAPTURE_BEGIN",
                                "timestamp": launch_started_at_utc,
                            }
                        )
                        print("FEARLESS_COLD_LAUNCH_OBSERVED", flush=True)
                        consume_launch_records(self.pipeline.drain())
                        if not snapshot.running:
                            process_stop_count += 1
                            launch_process_termination_observed = True
                            process_termination_elapsed_ms = (
                                self._elapsed_milliseconds(
                                    launch_started_monotonic,
                                    time.monotonic(),
                                )
                            )
                            terminal_observation = "process_terminated"
                            terminal_deadline = (
                                time.monotonic()
                                + self.settings.terminal_grace_seconds
                            )
                    else:
                        if (
                            launch_token is None
                            and self.settings.start_wait_timeout > 0
                            and time.monotonic() - launch_wait_started
                            >= self.settings.start_wait_timeout
                        ):
                            raise CaptureError(
                                "cold_launch_wait_timeout", EXIT_LIFECYCLE
                            )
                else:
                    if launch_token == 0 and snapshot.running:
                        raise CaptureError("second_launch_observed", EXIT_LIFECYCLE)
                    if (
                        launch_token > 0
                        and snapshot.running
                        and snapshot.token != launch_token
                    ):
                        raise CaptureError("second_launch_observed", EXIT_LIFECYCLE)
                    if previous.running and not snapshot.running:
                        process_stop_count += 1
                        launch_process_termination_observed = True
                        if process_termination_elapsed_ms is None:
                            process_termination_elapsed_ms = (
                                self._elapsed_milliseconds(
                                    launch_started_monotonic,
                                    time.monotonic(),
                                )
                            )
                        if terminal_observation != "failed_marker":
                            terminal_observation = "process_terminated"
                            terminal_deadline = (
                                time.monotonic()
                                + self.settings.terminal_grace_seconds
                            )
                    if not previous.running and snapshot.running:
                        raise CaptureError("second_launch_observed", EXIT_LIFECYCLE)

                    consume_launch_records(self.pipeline.drain())

                    now = time.monotonic()
                    assert launch_started_monotonic is not None
                    if terminal_deadline is not None and now >= terminal_deadline:
                        break
                    if (
                        ready_observed_monotonic is None
                        and now - launch_started_monotonic
                        >= self.settings.observation_seconds
                    ):
                        terminal_observation = (
                            terminal_observation or "observation_window_elapsed"
                        )
                        break

                previous = snapshot
                time.sleep(self.settings.poll_interval)

            assert launch_started_at_utc is not None
            try:
                final_snapshot = self.backend.process_snapshot(device_token)
            except DeviceUnavailable as error:
                raise CaptureError(
                    "device_disconnected_before_capture_finalization", EXIT_LIFECYCLE
                ) from error
            if self.pipeline.launch_count() != 1:
                raise CaptureError("unconfirmed_pid_stream_launch", EXIT_LIFECYCLE)
            if launch_token == 0 and final_snapshot.running:
                raise CaptureError("second_launch_observed", EXIT_LIFECYCLE)
            if (
                launch_token > 0
                and final_snapshot.running
                and final_snapshot.token != launch_token
            ):
                raise CaptureError("second_launch_observed", EXIT_LIFECYCLE)
            if not final_snapshot.running and not launch_process_termination_observed:
                process_stop_count += 1
                launch_process_termination_observed = True
                assert launch_started_monotonic is not None
                process_termination_elapsed_ms = self._elapsed_milliseconds(
                    launch_started_monotonic,
                    time.monotonic(),
                )
                if terminal_observation != "failed_marker":
                    terminal_observation = "process_terminated"

            self._require_distributed_identity(
                device_token,
                "device_disconnected_at_final_identity_check",
            )

            assert self.pipeline is not None
            consume_launch_records(self.pipeline.finalize())
            if self.pipeline.begin_count() != 1:
                raise CaptureError("pid_stream_unconfirmed", EXIT_SANITIZED_PROTOCOL)

            try:
                completion_snapshot = self.backend.process_snapshot(device_token)
            except DeviceUnavailable as error:
                raise CaptureError(
                    "device_disconnected_after_capture_finalization", EXIT_LIFECYCLE
                ) from error
            if launch_token == 0 and completion_snapshot.running:
                raise CaptureError("second_launch_observed", EXIT_LIFECYCLE)
            if (
                launch_token > 0
                and completion_snapshot.running
                and completion_snapshot.token != launch_token
            ):
                raise CaptureError("second_launch_observed", EXIT_LIFECYCLE)
            if (
                not completion_snapshot.running
                and not launch_process_termination_observed
            ):
                process_stop_count += 1
                launch_process_termination_observed = True
                assert launch_started_monotonic is not None
                process_termination_elapsed_ms = self._elapsed_milliseconds(
                    launch_started_monotonic,
                    time.monotonic(),
                )
                if terminal_observation != "failed_marker":
                    terminal_observation = "process_terminated"
            final_snapshot = completion_snapshot
            self._require_distributed_identity(
                device_token,
                "device_disconnected_after_capture_identity_check",
            )

            completed_monotonic = time.monotonic()
            ready_observation_elapsed_ms = (
                self._elapsed_milliseconds(
                    ready_observed_monotonic,
                    completed_monotonic,
                )
                if ready_observed_monotonic is not None
                else None
            )
            ready_observation_satisfied = bool(
                ready_observed_monotonic is not None
                and completed_monotonic - ready_observed_monotonic
                >= self.settings.ready_observation_seconds
                and failed_marker_count == 0
                and terminal_observation == "ready_marker"
                and final_snapshot.running
            )
            completed_at = utc_now()
            self._write_record(
                {
                    "event": "FEARLESS_COLD_LAUNCH_CAPTURE_END",
                    "timestamp": completed_at,
                }
            )
            receipt = {
                "schemaVersion": 1,
                "audit": "fearless-testflight-startup-capture",
                "captureStatus": "complete",
                "bundleIdentifier": identity.bundle_identifier,
                "marketingVersion": identity.marketing_version,
                "buildNumber": identity.build_number,
                "observationMethod": (
                    "paired-device-fearless-process-only-sanitized-syslog"
                ),
                "deviceSidePIDFilter": True,
                "historicalLogsRequested": False,
                "sensitivePayloadRequested": False,
                "pymobiledevice3Version": self.provenance.backend_version,
                "captureToolSHA256": self.provenance.capture_tool_sha256,
                "startupFilterSHA256": self.provenance.filter_sha256,
                "pidStreamHelperSHA256": self.provenance.stream_helper_sha256,
                "startedAtUTC": launch_started_at_utc,
                "completedAtUTC": completed_at,
                "initialProcessState": initial_state,
                "reconnectCountBeforeStop": reconnect_count,
                "coldLaunchObserved": True,
                "processStartCount": process_start_count,
                "processStopCount": process_stop_count,
                "finalProcessState": (
                    "running" if final_snapshot.running else "stopped"
                ),
                "terminalObservation": terminal_observation,
                "sanitizedRecordCount": sanitized_record_count,
                "filterBeginCount": self.pipeline.begin_count(),
                "devicePIDStreamStartAcknowledged": True,
                "readyMarkerCount": ready_marker_count,
                "failedMarkerCount": failed_marker_count,
                "incidentCodes": incident_codes,
                "firstDiagnosticElapsedMilliseconds": first_diagnostic_elapsed_ms,
                "processTerminationElapsedMilliseconds": (
                    process_termination_elapsed_ms
                ),
                "readyMarkerElapsedMilliseconds": ready_marker_elapsed_ms,
                "readyObservationSecondsRequested": (
                    self.settings.ready_observation_seconds
                ),
                "readyObservationElapsedMilliseconds": (
                    ready_observation_elapsed_ms
                ),
                "readyObservationSatisfied": ready_observation_satisfied,
                "failureObserved": bool(
                    failed_marker_count
                    or terminal_observation == "process_terminated"
                ),
                "deterministicIncidentAvailable": bool(incident_codes),
                "diagnosticSufficient": bool(incident_codes),
                "rawSyslogPersisted": False,
                "containerAccessed": False,
            }
            self._publish_success(receipt)
            print(
                "FEARLESS_CAPTURE_COMPLETE "
                f"terminal={terminal_observation} records={sanitized_record_count}",
                flush=True,
            )
            return receipt
        except CaptureError as error:
            self._publish_abort(error)
            raise
        except KeyboardInterrupt:
            self._publish_abort(CaptureError("interrupted", EXIT_INTERRUPTED))
            raise
        finally:
            if self.pipeline is not None:
                self.pipeline.close()
            if not self.receipt_path.exists() and not self.abort_path.exists():
                self._discard_pending()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-directory",
        required=True,
        type=Path,
        help="New private directory for sanitized metadata, log, and receipt",
    )
    parser.add_argument(
        "--pymobiledevice3",
        required=True,
        type=Path,
        help="Path to the reviewed pymobiledevice3 executable",
    )
    parser.add_argument(
        "--stream-helper",
        type=Path,
        default=Path(__file__).resolve().with_name("stream-fearless-pid-syslog.py"),
    )
    parser.add_argument(
        "--filter",
        type=Path,
        default=Path(__file__).resolve().with_name("filter-startup-syslog.py"),
    )
    parser.add_argument("--poll-interval", type=float, default=0.1)
    parser.add_argument(
        "--device-poll-interval",
        type=float,
        default=1,
        help="Seconds between paired-device checks while disconnected",
    )
    parser.add_argument(
        "--device-wait-timeout",
        type=float,
        default=0,
        help="Seconds to wait for one USB device; zero waits indefinitely",
    )
    parser.add_argument(
        "--stop-wait-timeout",
        type=float,
        default=300,
        help="Seconds to wait for the single force-quit; zero waits indefinitely",
    )
    parser.add_argument(
        "--watcher-arm-timeout",
        type=float,
        default=15,
        help="Seconds to arm the exact-PID watcher before prompting for launch",
    )
    parser.add_argument(
        "--start-wait-timeout",
        type=float,
        default=120,
        help="Seconds to wait for the single cold launch; zero waits indefinitely",
    )
    parser.add_argument("--observation-seconds", type=float, default=60)
    parser.add_argument("--terminal-grace-seconds", type=float, default=2)
    parser.add_argument(
        "--ready-observation-seconds",
        type=float,
        default=0,
        help=(
            "Seconds to keep the exact launch under observation after READY; "
            "FAILED still uses terminal grace"
        ),
    )
    parser.add_argument(
        "--expected-build",
        choices=SUPPORTED_CAPTURE_BUILD_NUMBERS,
        default=EXPECTED_BUILD_NUMBER,
        help="Exact allowlisted TestFlight build expected on the phone",
    )
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> None:
    if not args.output_directory.is_absolute():
        raise CaptureError("output_directory_must_be_absolute", EXIT_DEPENDENCY)
    if (
        not args.output_directory.parent.is_dir()
        or args.output_directory.parent.is_symlink()
    ):
        raise CaptureError("output_parent_missing", EXIT_DEPENDENCY)
    for path, reason in (
        (args.pymobiledevice3, "pymobiledevice3_unavailable"),
        (args.stream_helper, "pid_stream_helper_unavailable"),
        (args.filter, "startup_filter_unavailable"),
    ):
        if not path.is_absolute() or not path.is_file() or path.is_symlink():
            raise CaptureError(reason, EXIT_DEPENDENCY)
    if not os.access(args.pymobiledevice3, os.X_OK):
        raise CaptureError("pymobiledevice3_not_executable", EXIT_DEPENDENCY)
    validate_capture_settings(
        CaptureSettings(
            poll_interval=args.poll_interval,
            device_poll_interval=args.device_poll_interval,
            device_wait_timeout=args.device_wait_timeout,
            stop_wait_timeout=args.stop_wait_timeout,
            watcher_arm_timeout=args.watcher_arm_timeout,
            start_wait_timeout=args.start_wait_timeout,
            observation_seconds=args.observation_seconds,
            terminal_grace_seconds=args.terminal_grace_seconds,
            ready_observation_seconds=args.ready_observation_seconds,
            expected_build_number=args.expected_build,
        )
    )


def main() -> int:
    os.umask(0o077)
    args = parse_args()
    try:
        validate_args(args)
        backend = PymobiledeviceBackend(
            args.pymobiledevice3,
            args.stream_helper,
            args.filter,
            10,
        )
        backend_version = backend.backend_version()
        if backend_version != SUPPORTED_PYMOBILEDEVICE3_VERSION:
            raise CaptureError("unsupported_pymobiledevice3_version", EXIT_DEPENDENCY)

        controller = CaptureController(
            backend,
            args.output_directory,
            CaptureSettings(
                poll_interval=args.poll_interval,
                device_poll_interval=args.device_poll_interval,
                device_wait_timeout=args.device_wait_timeout,
                stop_wait_timeout=args.stop_wait_timeout,
                watcher_arm_timeout=args.watcher_arm_timeout,
                start_wait_timeout=args.start_wait_timeout,
                observation_seconds=args.observation_seconds,
                terminal_grace_seconds=args.terminal_grace_seconds,
                ready_observation_seconds=args.ready_observation_seconds,
                expected_build_number=args.expected_build,
            ),
            CaptureProvenance(
                backend_version=backend_version,
                capture_tool_sha256=file_sha256(Path(__file__).resolve()),
                filter_sha256=file_sha256(args.filter),
                stream_helper_sha256=file_sha256(args.stream_helper),
            ),
        )
        controller.run()
        return 0
    except KeyboardInterrupt:
        print("FEARLESS_CAPTURE_ABORTED reason=interrupted", file=sys.stderr)
        return EXIT_INTERRUPTED
    except CaptureError as error:
        print(f"FEARLESS_CAPTURE_ABORTED reason={error.reason}", file=sys.stderr)
        return error.exit_code


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, controlled_interrupt)
    signal.signal(signal.SIGHUP, controlled_interrupt)
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    raise SystemExit(main())
