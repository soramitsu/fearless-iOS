#!/usr/bin/env python3

from __future__ import annotations

import asyncio
import contextlib
import importlib.util
import io
import json
import os
import plistlib
import signal
import stat
import struct
import subprocess
import sys
import tempfile
import time
import types
import unittest
from unittest.mock import patch
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).with_name("capture-testflight-startup.py")
SPEC = importlib.util.spec_from_file_location("capture_testflight_startup", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
CAPTURE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CAPTURE
SPEC.loader.exec_module(CAPTURE)

HELPER_PATH = Path(__file__).with_name("stream-fearless-pid-syslog.py")
HELPER_SPEC = importlib.util.spec_from_file_location("stream_fearless_pid_syslog", HELPER_PATH)
assert HELPER_SPEC is not None and HELPER_SPEC.loader is not None
HELPER = importlib.util.module_from_spec(HELPER_SPEC)
HELPER_SPEC.loader.exec_module(HELPER)


def safe_record(message: str) -> dict[str, Any]:
    return {
        "timestamp": "2026-08-12T12:00:15.000000Z",
        "level": "ERROR",
        "subsystem": "jp.co.soramitsu.fearlesswallet",
        "category": "startup-readiness",
        "message": message,
    }


class FakePipeline:
    def __init__(
        self,
        batches: list[list[dict[str, Any]]] | None = None,
        failures: list[str | None] | None = None,
        begin_count: int = 1,
        watcher_armed_count: int = 1,
        launch_counts: list[int] | None = None,
    ) -> None:
        self.batches = list(batches or [])
        self.failures = list(failures or [])
        self.closed = False
        self._begin_count = begin_count
        self._watcher_armed_count = watcher_armed_count
        self._launch_count = 0
        self.launch_counts = list(launch_counts or [])

    def drain(self) -> list[dict[str, Any]]:
        return self.batches.pop(0) if self.batches else []

    def failure_reason(self) -> str | None:
        return self.failures.pop(0) if self.failures else None

    def begin_count(self) -> int:
        return self._begin_count

    def watcher_armed_count(self) -> int:
        return self._watcher_armed_count

    def launch_count(self) -> int:
        if self.launch_counts:
            self._launch_count = self.launch_counts.pop(0)
        return self._launch_count

    def finalize(self) -> list[dict[str, Any]]:
        self.closed = True
        records: list[dict[str, Any]] = []
        while self.batches:
            records.extend(self.batches.pop(0))
        return records

    def close(self) -> None:
        self.closed = True


class FakeBackend:
    def __init__(
        self,
        *,
        devices: list[list[str] | Exception] | None = None,
        identity: Any = None,
        identities: list[Any] | None = None,
        snapshots: list[Any] | None = None,
        pipeline: FakePipeline | None = None,
    ) -> None:
        self.devices = list(devices or [["private-device-token"]])
        self.identity = identity or CAPTURE.AppIdentity(
            CAPTURE.EXPECTED_BUNDLE_IDENTIFIER,
            CAPTURE.EXPECTED_MARKETING_VERSION,
            CAPTURE.EXPECTED_BUILD_NUMBER,
        )
        self.identities = list(identities or [])
        self.snapshots = list(snapshots or [])
        self.pipeline = pipeline or FakePipeline()
        self.last_device_value: list[str] = []
        self.last_snapshot: Any = CAPTURE.ProcessSnapshot(False, None)
        self.pipeline_started = False

    def usb_device_tokens(self) -> list[str]:
        value = self.devices.pop(0) if self.devices else self.last_device_value
        if isinstance(value, Exception):
            raise value
        self.last_device_value = value
        return value

    def app_identity(self, device_token: str) -> Any:
        value = self.identities.pop(0) if self.identities else self.identity
        if isinstance(value, Exception):
            raise value
        return value

    def process_snapshot(self, device_token: str) -> Any:
        value = self.snapshots.pop(0) if self.snapshots else self.last_snapshot
        if isinstance(value, BaseException):
            raise value
        self.last_snapshot = value
        if self.pipeline_started and value.running:
            self.pipeline._launch_count = 1
        return value

    def start_pipeline(self, device_token: str) -> FakePipeline:
        self.pipeline_started = True
        return self.pipeline


class CaptureControllerTests(unittest.TestCase):
    def settings(
        self,
        observation: float = 0.05,
        grace: float = 0,
        ready_observation: float = 0,
        wait_timeout: float = 0.2,
        expected_build: str = CAPTURE.EXPECTED_BUILD_NUMBER,
    ) -> Any:
        return CAPTURE.CaptureSettings(
            poll_interval=0.001,
            device_poll_interval=0.001,
            device_wait_timeout=wait_timeout,
            stop_wait_timeout=wait_timeout,
            watcher_arm_timeout=wait_timeout,
            start_wait_timeout=wait_timeout,
            observation_seconds=observation,
            terminal_grace_seconds=grace,
            ready_observation_seconds=ready_observation,
            expected_build_number=expected_build,
        )

    def output_path(self, root: str) -> Path:
        return Path(root) / "capture"

    def test_running_stop_start_failure_publishes_one_private_window(self) -> None:
        incident = safe_record(
            "legacy_incident_code=SUBSTRATE_PREFLIGHT_TIMEOUT "
            "legacy_resolution=soft_threshold"
        )
        failed = safe_record("FEARLESS_STARTUP_FAILED")
        pipeline = FakePipeline(batches=[[], [incident, failed]])
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(True, 101),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 202),
                CAPTURE.ProcessSnapshot(True, 202),
                CAPTURE.ProcessSnapshot(True, 202),
            ],
            pipeline=pipeline,
        )

        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            receipt = CAPTURE.CaptureController(
                backend, output, self.settings()
            ).run()

            self.assertEqual(receipt["captureStatus"], "complete")
            self.assertEqual(receipt["processStartCount"], 1)
            self.assertEqual(receipt["processStopCount"], 1)
            self.assertEqual(receipt["failedMarkerCount"], 1)
            self.assertEqual(
                receipt["incidentCodes"], ["SUBSTRATE_PREFLIGHT_TIMEOUT"]
            )
            self.assertEqual(receipt["terminalObservation"], "failed_marker")
            self.assertTrue(receipt["diagnosticSufficient"])
            self.assertFalse(receipt["rawSyslogPersisted"])
            self.assertFalse(receipt["containerAccessed"])
            self.assertTrue(receipt["failureObserved"])
            self.assertTrue(receipt["deterministicIncidentAvailable"])

            log_path = output / "fearless-startup-sanitized.ndjson"
            content = log_path.read_text()
            self.assertIn("SUBSTRATE_PREFLIGHT_TIMEOUT", content)
            self.assertEqual(content.count("FEARLESS_COLD_LAUNCH_CAPTURE_BEGIN"), 1)
            self.assertEqual(content.count("FEARLESS_COLD_LAUNCH_CAPTURE_END"), 1)
            for path in (
                log_path,
                output / "installed-app-metadata.json",
                output / "capture-receipt.json",
            ):
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(
                receipt["sanitizedLogSHA256"],
                CAPTURE.file_sha256(log_path),
            )
            self.assertEqual(
                receipt["installedAppMetadataSHA256"],
                CAPTURE.file_sha256(output / "installed-app-metadata.json"),
            )
            self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o700)
            self.assertFalse((output / "capture-aborted.json").exists())
            self.assertTrue(pipeline.closed)

    def test_initially_stopped_then_ready_is_one_cold_launch(self) -> None:
        pipeline = FakePipeline(batches=[[], [safe_record("FEARLESS_STARTUP_READY")]])
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 303),
                CAPTURE.ProcessSnapshot(True, 303),
                CAPTURE.ProcessSnapshot(True, 303),
            ],
            pipeline=pipeline,
        )

        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend, self.output_path(directory), self.settings()
            ).run()

        self.assertEqual(receipt["initialProcessState"], "stopped")
        self.assertEqual(receipt["readyMarkerCount"], 1)
        self.assertEqual(receipt["failedMarkerCount"], 0)
        self.assertEqual(receipt["terminalObservation"], "ready_marker")
        self.assertFalse(receipt["failureObserved"])
        self.assertFalse(receipt["diagnosticSufficient"])

    def test_waits_through_absent_and_unavailable_device(self) -> None:
        pipeline = FakePipeline(batches=[[], [safe_record("FEARLESS_STARTUP_FAILED")]])
        backend = FakeBackend(
            devices=[[], CAPTURE.DeviceUnavailable(), ["private-device-token"]],
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 404),
                CAPTURE.ProcessSnapshot(True, 404),
                CAPTURE.ProcessSnapshot(True, 404),
            ],
            pipeline=pipeline,
        )

        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend, self.output_path(directory), self.settings()
            ).run()

        self.assertEqual(receipt["captureStatus"], "complete")

    def test_wrong_build_fails_closed_with_only_safe_metadata(self) -> None:
        backend = FakeBackend(
            identity=CAPTURE.AppIdentity(
                CAPTURE.EXPECTED_BUNDLE_IDENTIFIER,
                CAPTURE.EXPECTED_MARKETING_VERSION,
                "2026.8.10",
            )
        )

        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            with self.assertRaisesRegex(CAPTURE.CaptureError, "installed_identity_mismatch"):
                CAPTURE.CaptureController(backend, output, self.settings()).run()

            metadata = json.loads((output / "installed-app-metadata.json").read_text())
            abort = json.loads((output / "capture-aborted.json").read_text())
            self.assertEqual(metadata["buildNumber"], "2026.8.10")
            self.assertEqual(abort["reason"], "installed_identity_mismatch")
            self.assertFalse((output / "capture-receipt.json").exists())
            self.assertFalse((output / "fearless-startup-sanitized.ndjson").exists())
            self.assertFalse((output / ".fearless-startup-sanitized.ndjson.pending").exists())

    def test_multiple_devices_fail_before_reading_app_metadata(self) -> None:
        backend = FakeBackend(devices=[["private-one", "private-two"]])
        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            with self.assertRaisesRegex(CAPTURE.CaptureError, "multiple_usb_devices"):
                CAPTURE.CaptureController(backend, output, self.settings()).run()
            self.assertFalse((output / "installed-app-metadata.json").exists())
            self.assertEqual(
                json.loads((output / "capture-aborted.json").read_text())["reason"],
                "multiple_usb_devices",
            )

    def test_disconnect_after_arming_aborts_without_final_log(self) -> None:
        pipeline = FakePipeline()
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.DeviceUnavailable(),
            ],
            pipeline=pipeline,
        )

        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            with self.assertRaisesRegex(
                CAPTURE.CaptureError, "device_disconnected_after_armed"
            ):
                CAPTURE.CaptureController(backend, output, self.settings()).run()
            self.assertFalse((output / "capture-receipt.json").exists())
            self.assertFalse((output / "fearless-startup-sanitized.ndjson").exists())
            self.assertTrue(pipeline.closed)

    def test_process_replacement_without_stop_is_rejected(self) -> None:
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(True, 606),
                CAPTURE.ProcessSnapshot(True, 606),
                CAPTURE.ProcessSnapshot(True, 607),
            ]
        )
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(
                CAPTURE.CaptureError, "process_replaced_without_observed_stop"
            ):
                CAPTURE.CaptureController(
                    backend, self.output_path(directory), self.settings()
                ).run()

    def test_disconnect_before_stop_reconnects_only_with_same_running_process(self) -> None:
        pipeline = FakePipeline(batches=[[], [safe_record("FEARLESS_STARTUP_FAILED")]])
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(True, 611),
                CAPTURE.DeviceUnavailable(),
                CAPTURE.ProcessSnapshot(True, 611),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 612),
                CAPTURE.ProcessSnapshot(True, 612),
                CAPTURE.ProcessSnapshot(True, 612),
            ],
            pipeline=pipeline,
        )

        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend, self.output_path(directory), self.settings()
            ).run()

        self.assertEqual(receipt["reconnectCountBeforeStop"], 1)
        self.assertEqual(receipt["processStartCount"], 1)

    def test_disconnect_before_stop_rejects_an_unobserved_stop(self) -> None:
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(True, 621),
                CAPTURE.DeviceUnavailable(),
                CAPTURE.ProcessSnapshot(False, None),
            ]
        )

        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(
                CAPTURE.CaptureError,
                "lifecycle_continuity_lost_during_disconnect",
            ):
                CAPTURE.CaptureController(
                    backend, self.output_path(directory), self.settings()
                ).run()

    def test_second_launch_after_termination_is_rejected(self) -> None:
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 707),
                CAPTURE.ProcessSnapshot(True, 707),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 708),
            ]
        )
        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            with self.assertRaisesRegex(CAPTURE.CaptureError, "second_launch_observed"):
                CAPTURE.CaptureController(
                    backend, output, self.settings(observation=1, grace=1)
                ).run()
            self.assertFalse((output / "capture-receipt.json").exists())

    def test_unsafe_filter_output_never_reaches_disk(self) -> None:
        sentinel = "AliceFamilyVault-private-wallet"
        unsafe = safe_record(sentinel)
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 808),
                CAPTURE.ProcessSnapshot(True, 808),
                CAPTURE.ProcessSnapshot(True, 808),
            ],
            pipeline=FakePipeline(batches=[[], [unsafe]]),
        )

        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            with self.assertRaisesRegex(CAPTURE.CaptureError, "unsafe_sanitized_message"):
                CAPTURE.CaptureController(backend, output, self.settings()).run()
            persisted = "".join(
                path.read_text(errors="ignore")
                for path in output.iterdir()
                if path.is_file()
            )
            self.assertNotIn(sentinel, persisted)
            self.assertFalse((output / "capture-receipt.json").exists())

    def test_pipeline_failure_and_interrupt_leave_no_final_receipt(self) -> None:
        cases = [
            (
                FakeBackend(
                    snapshots=[
                        CAPTURE.ProcessSnapshot(False, None),
                        CAPTURE.ProcessSnapshot(False, None),
                    ],
                    pipeline=FakePipeline(failures=[None, "syslog_stream_ended"]),
                ),
                CAPTURE.CaptureError,
            ),
            (
                FakeBackend(
                    snapshots=[
                        CAPTURE.ProcessSnapshot(False, None),
                        CAPTURE.ProcessSnapshot(False, None),
                        KeyboardInterrupt(),
                    ]
                ),
                KeyboardInterrupt,
            ),
        ]
        for backend, expected_error in cases:
            with self.subTest(error=expected_error.__name__):
                with tempfile.TemporaryDirectory() as directory:
                    output = self.output_path(directory)
                    with self.assertRaises(expected_error):
                        CAPTURE.CaptureController(
                            backend, output, self.settings()
                        ).run()
                    self.assertFalse((output / "capture-receipt.json").exists())
                    self.assertFalse(
                        (output / "fearless-startup-sanitized.ndjson").exists()
                    )
                    self.assertFalse(
                        (output / ".fearless-startup-sanitized.ndjson.pending").exists()
                    )

    def test_interrupt_during_pipeline_start_closes_the_owned_pipeline(self) -> None:
        for interrupt_signal in CAPTURE.CAPTURE_INTERRUPT_SIGNALS:
            with self.subTest(signal=interrupt_signal):
                pipeline = FakePipeline()

                class InterruptingBackend(FakeBackend):
                    def start_pipeline(self, device_token: str) -> FakePipeline:
                        self.pipeline_started = True
                        os.kill(os.getpid(), interrupt_signal)
                        return self.pipeline

                backend = InterruptingBackend(
                    snapshots=[CAPTURE.ProcessSnapshot(False, None)],
                    pipeline=pipeline,
                )

                with tempfile.TemporaryDirectory() as directory:
                    output = self.output_path(directory)
                    with self.assertRaises(KeyboardInterrupt):
                        CAPTURE.CaptureController(
                            backend,
                            output,
                            self.settings(),
                        ).run()

                    self.assertTrue(pipeline.closed)
                    abort = json.loads(
                        (output / "capture-aborted.json").read_text()
                    )
                    self.assertEqual(abort["reason"], "interrupted")
                    self.assertFalse((output / "capture-receipt.json").exists())
                    self.assertFalse(
                        (output / "fearless-startup-sanitized.ndjson").exists()
                    )

    def test_controller_owned_real_pipeline_finalizes_with_sigterm(self) -> None:
        raw_record = {
            "pid": 949,
            "timestamp": "2026-08-12T12:00:15.000000Z",
            "level": "ERROR",
            "filename": "fearless",
            "message": "FEARLESS_STARTUP_FAILED",
            "label": None,
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            helper = root / "fake-stream.py"
            helper.write_text(
                "#!/usr/bin/env python3\n"
                "import json,time\n"
                "print(json.dumps({'capture_control':'pid_watcher_armed','filename':'fearless'}), flush=True)\n"
                "time.sleep(0.05)\n"
                "print(json.dumps({'capture_control':'target_process_observed','filename':'fearless','pid':949}), flush=True)\n"
                "print(json.dumps({'capture_control':'pid_stream_started','filename':'fearless','pid':949}), flush=True)\n"
                f"print(json.dumps({raw_record!r}), flush=True)\n"
                "time.sleep(30)\n"
            )
            helper.chmod(0o700)

            class RealPipelineBackend(FakeBackend):
                def __init__(self) -> None:
                    super().__init__()
                    self.snapshot_count = 0

                def process_snapshot(self, device_token: str) -> Any:
                    self.snapshot_count += 1
                    if self.snapshot_count < 4:
                        return CAPTURE.ProcessSnapshot(False, None)
                    return CAPTURE.ProcessSnapshot(True, 949)

                def start_pipeline(self, device_token: str) -> Any:
                    self.pipeline_started = True
                    return CAPTURE.FilterPipeline(
                        Path(sys.executable),
                        helper,
                        Path(__file__).with_name("filter-startup-syslog.py"),
                        device_token,
                    )

            output = self.output_path(directory)
            receipt = CAPTURE.CaptureController(
                RealPipelineBackend(),
                output,
                self.settings(observation=1, grace=0, wait_timeout=2),
            ).run()

            self.assertEqual(receipt["captureStatus"], "complete")
            self.assertEqual(receipt["filterBeginCount"], 1)
            self.assertEqual(receipt["failedMarkerCount"], 1)
            self.assertTrue((output / "capture-receipt.json").exists())

    def test_duplicate_ready_marker_fails_capture_integrity(self) -> None:
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 818),
                CAPTURE.ProcessSnapshot(True, 818),
            ],
            pipeline=FakePipeline(
                batches=[
                    [
                        safe_record("FEARLESS_STARTUP_READY"),
                        safe_record("FEARLESS_STARTUP_READY"),
                    ]
                ]
            ),
        )

        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            with self.assertRaisesRegex(CAPTURE.CaptureError, "duplicate_ready_marker"):
                CAPTURE.CaptureController(backend, output, self.settings()).run()
            self.assertFalse((output / "capture-receipt.json").exists())

    def test_installed_identity_change_at_any_capture_boundary_fails_closed(self) -> None:
        distributed = CAPTURE.AppIdentity(
            CAPTURE.EXPECTED_BUNDLE_IDENTIFIER,
            CAPTURE.EXPECTED_MARKETING_VERSION,
            CAPTURE.EXPECTED_BUILD_NUMBER,
        )
        replacement = CAPTURE.AppIdentity(
            CAPTURE.EXPECTED_BUNDLE_IDENTIFIER,
            CAPTURE.EXPECTED_MARKETING_VERSION,
            "2026.8.10",
        )
        cases = [
            (
                [distributed, replacement],
                [
                    CAPTURE.ProcessSnapshot(False, None),
                ],
            ),
            (
                [distributed, distributed, replacement],
                [
                    CAPTURE.ProcessSnapshot(False, None),
                    CAPTURE.ProcessSnapshot(False, None),
                    CAPTURE.ProcessSnapshot(True, 819),
                ],
            ),
            (
                [distributed, distributed, distributed, replacement],
                [
                    CAPTURE.ProcessSnapshot(False, None),
                    CAPTURE.ProcessSnapshot(False, None),
                    CAPTURE.ProcessSnapshot(True, 820),
                    CAPTURE.ProcessSnapshot(True, 820),
                    CAPTURE.ProcessSnapshot(True, 820),
                ],
            ),
        ]
        for identities, snapshots in cases:
            with self.subTest(identity_checks=len(identities)):
                backend = FakeBackend(
                    identities=identities,
                    snapshots=snapshots,
                )
                with tempfile.TemporaryDirectory() as directory:
                    output = self.output_path(directory)
                    with self.assertRaisesRegex(
                        CAPTURE.CaptureError, "installed_identity_changed"
                    ):
                        CAPTURE.CaptureController(
                            backend, output, self.settings()
                        ).run()
                    self.assertFalse((output / "capture-receipt.json").exists())

    def test_taira_build_is_explicitly_allowlisted_for_qualification_capture(self) -> None:
        hotfix = CAPTURE.AppIdentity(
            CAPTURE.EXPECTED_BUNDLE_IDENTIFIER,
            CAPTURE.EXPECTED_MARKETING_VERSION,
            CAPTURE.HOTFIX_BUILD_NUMBER,
        )
        backend = FakeBackend(
            identity=hotfix,
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 822),
                CAPTURE.ProcessSnapshot(True, 822),
            ],
            pipeline=FakePipeline(
                batches=[[safe_record("FEARLESS_STARTUP_READY")]],
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend,
                self.output_path(directory),
                self.settings(expected_build=CAPTURE.HOTFIX_BUILD_NUMBER),
            ).run()

        self.assertEqual(receipt["buildNumber"], CAPTURE.HOTFIX_BUILD_NUMBER)
        self.assertEqual(receipt["readyMarkerCount"], 1)
        self.assertEqual(receipt["failedMarkerCount"], 0)

    def test_ready_marker_holds_observation_without_delaying_failure(self) -> None:
        ready_backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 822),
                CAPTURE.ProcessSnapshot(True, 822),
            ],
            pipeline=FakePipeline(
                batches=[[safe_record("FEARLESS_STARTUP_READY")]],
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            started = time.monotonic()
            ready_receipt = CAPTURE.CaptureController(
                ready_backend,
                self.output_path(directory),
                self.settings(
                    observation=0.005,
                    grace=0,
                    ready_observation=0.02,
                ),
            ).run()
            ready_elapsed = time.monotonic() - started

        self.assertGreaterEqual(ready_elapsed, 0.02)
        self.assertEqual(ready_receipt["readyObservationSecondsRequested"], 0.02)
        self.assertGreaterEqual(
            ready_receipt["readyObservationElapsedMilliseconds"], 20
        )
        self.assertTrue(ready_receipt["readyObservationSatisfied"])

        failed_backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 823),
                CAPTURE.ProcessSnapshot(True, 823),
            ],
            pipeline=FakePipeline(
                batches=[[safe_record("FEARLESS_STARTUP_FAILED")]],
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            started = time.monotonic()
            failed_receipt = CAPTURE.CaptureController(
                failed_backend,
                self.output_path(directory),
                self.settings(
                    observation=0.1,
                    grace=0,
                    ready_observation=0.05,
                ),
            ).run()
            failed_elapsed = time.monotonic() - started

        self.assertLess(failed_elapsed, 0.05)
        self.assertEqual(failed_receipt["failedMarkerCount"], 1)
        self.assertIsNone(failed_receipt["readyObservationElapsedMilliseconds"])
        self.assertFalse(failed_receipt["readyObservationSatisfied"])

    def test_process_termination_after_ready_fails_ready_observation(self) -> None:
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 824),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
            ],
            pipeline=FakePipeline(
                batches=[[safe_record("FEARLESS_STARTUP_READY")]],
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend,
                self.output_path(directory),
                self.settings(
                    observation=0.1,
                    grace=0,
                    ready_observation=0.02,
                ),
            ).run()

        self.assertEqual(receipt["readyMarkerCount"], 1)
        self.assertEqual(receipt["terminalObservation"], "process_terminated")
        self.assertEqual(receipt["finalProcessState"], "stopped")
        self.assertTrue(receipt["failureObserved"])
        self.assertFalse(receipt["readyObservationSatisfied"])

    def test_finalization_race_cannot_publish_running_ready_state(self) -> None:
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 825),
                CAPTURE.ProcessSnapshot(True, 825),
                CAPTURE.ProcessSnapshot(True, 825),
                CAPTURE.ProcessSnapshot(False, None),
            ],
            pipeline=FakePipeline(
                batches=[[safe_record("FEARLESS_STARTUP_READY")]],
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend,
                self.output_path(directory),
                self.settings(),
            ).run()

        self.assertEqual(receipt["terminalObservation"], "process_terminated")
        self.assertEqual(receipt["finalProcessState"], "stopped")
        self.assertTrue(receipt["failureObserved"])
        self.assertFalse(receipt["readyObservationSatisfied"])

    def test_controller_rejects_unbounded_duration_and_unallowlisted_build(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            with self.assertRaisesRegex(
                CAPTURE.CaptureError,
                "ready_observation_seconds_must_be_finite",
            ):
                CAPTURE.CaptureController(
                    FakeBackend(),
                    output,
                    self.settings(ready_observation=float("inf")),
                )
            self.assertFalse(output.exists())

            with self.assertRaisesRegex(
                CAPTURE.CaptureError,
                "unsupported_expected_build",
            ):
                CAPTURE.CaptureController(
                    FakeBackend(),
                    output,
                    self.settings(expected_build="2026.9.99"),
                )
            self.assertFalse(output.exists())

    def test_existing_output_directory_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            output.mkdir()
            with self.assertRaisesRegex(CAPTURE.CaptureError, "output_directory_exists"):
                CAPTURE.CaptureController(
                    FakeBackend(), output, self.settings()
                ).run()

    def test_description_only_diagnostic_records_timing_without_claiming_mapping(self) -> None:
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 828),
                CAPTURE.ProcessSnapshot(True, 828),
                CAPTURE.ProcessSnapshot(True, 828),
            ],
            pipeline=FakePipeline(
                batches=[
                    [safe_record("legacy_startup_description=storage,failure")]
                ]
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend,
                self.output_path(directory),
                self.settings(observation=0.003),
            ).run()

        self.assertIsNotNone(receipt["firstDiagnosticElapsedMilliseconds"])
        self.assertFalse(receipt["diagnosticSufficient"])
        self.assertEqual(receipt["incidentCodes"], [])

    def test_acknowledged_empty_pid_stream_completes_without_claiming_diagnosis(self) -> None:
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 818),
                CAPTURE.ProcessSnapshot(True, 818),
            ],
            pipeline=FakePipeline(begin_count=1),
        )
        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend,
                self.output_path(directory),
                self.settings(observation=0.003),
            ).run()

        self.assertEqual(receipt["terminalObservation"], "observation_window_elapsed")
        self.assertEqual(receipt["sanitizedRecordCount"], 0)
        self.assertEqual(receipt["filterBeginCount"], 1)
        self.assertTrue(receipt["devicePIDStreamStartAcknowledged"])
        self.assertFalse(receipt["diagnosticSufficient"])

    def test_pid_watcher_rejects_a_fast_crash_without_stream_evidence(self) -> None:
        pipeline = FakePipeline(
            begin_count=0,
            launch_counts=[0, 1, 1, 1, 1],
        )
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
            ],
            pipeline=pipeline,
        )
        with tempfile.TemporaryDirectory() as directory:
            output = self.output_path(directory)
            with self.assertRaisesRegex(
                CAPTURE.CaptureError, "pid_stream_unconfirmed"
            ):
                CAPTURE.CaptureController(
                    backend,
                    output,
                    self.settings(grace=0),
                ).run()
            self.assertFalse((output / "capture-receipt.json").exists())
            self.assertFalse(
                (output / "fearless-startup-sanitized.ndjson").exists()
            )

    def test_process_termination_has_privacy_safe_elapsed_time(self) -> None:
        pipeline = FakePipeline(
            batches=[[safe_record("FEARLESS_STARTUP_FAILED")]],
        )
        backend = FakeBackend(
            snapshots=[
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(True, 838),
                CAPTURE.ProcessSnapshot(False, None),
                CAPTURE.ProcessSnapshot(False, None),
            ],
            pipeline=pipeline,
        )
        with tempfile.TemporaryDirectory() as directory:
            receipt = CAPTURE.CaptureController(
                backend,
                self.output_path(directory),
                self.settings(grace=0),
            ).run()
        self.assertIsInstance(
            receipt["processTerminationElapsedMilliseconds"], int
        )
        self.assertGreaterEqual(
            receipt["processTerminationElapsedMilliseconds"], 0
        )
        self.assertEqual(
            CAPTURE.CaptureController._elapsed_milliseconds(10.0, 25.0),
            15_000,
        )


class FilterPipelineTests(unittest.TestCase):
    def test_confirmed_pid_stream_can_finalize_without_app_log_records(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "fake-stream.py"
            fake.write_text(
                "#!/usr/bin/env python3\n"
                "import json,time\n"
                "print(json.dumps({'capture_control':'pid_watcher_armed','filename':'fearless'}), flush=True)\n"
                "print(json.dumps({'capture_control':'target_process_observed','filename':'fearless','pid':909}), flush=True)\n"
                "print(json.dumps({'capture_control':'pid_stream_started','filename':'fearless','pid':909}), flush=True)\n"
                "time.sleep(30)\n"
            )
            fake.chmod(0o700)
            pipeline = CAPTURE.FilterPipeline(
                Path(sys.executable),
                fake,
                Path(__file__).with_name("filter-startup-syslog.py"),
                "private-device-token",
            )
            deadline = time.monotonic() + 2
            while pipeline.begin_count() == 0 and time.monotonic() < deadline:
                pipeline.drain()
                time.sleep(0.01)

            self.assertEqual(pipeline.watcher_armed_count(), 1)
            self.assertEqual(pipeline.launch_count(), 1)
            self.assertEqual(pipeline.begin_count(), 1)
            self.assertEqual(pipeline.finalize(), [])

    def test_raw_syslog_flows_only_to_sanitizer(self) -> None:
        raw_sentinel = "AliceFamilyVault-private-wallet"
        raw_record = {
            "pid": 919,
            "timestamp": "2026-08-12T12:00:15.000000Z",
            "level": "ERROR",
            "filename": "fearless",
            "message": f"Selected wallet {raw_sentinel} failed to open",
            "label": {
                "subsystem": "jp.co.soramitsu.fearlesswallet",
                "category": "root",
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "fake-pymobiledevice3"
            fake.write_text(
                "#!/usr/bin/env python3\n"
                "import json,time\n"
                "print(json.dumps({'capture_control':'pid_watcher_armed','filename':'fearless'}), flush=True)\n"
                "print(json.dumps({'capture_control':'target_process_observed','filename':'fearless','pid':919}), flush=True)\n"
                "print(json.dumps({'capture_control':'pid_stream_started','filename':'fearless','pid':919}), flush=True)\n"
                f"print(json.dumps({raw_record!r}), flush=True)\n"
                "time.sleep(10)\n"
            )
            fake.chmod(0o700)
            pipeline = CAPTURE.FilterPipeline(
                Path(sys.executable),
                fake,
                Path(__file__).with_name("filter-startup-syslog.py"),
                "private-device-token",
            )
            try:
                deadline = time.monotonic() + 2
                records: list[dict[str, Any]] = []
                while time.monotonic() < deadline and not records:
                    records.extend(pipeline.drain())
                    time.sleep(0.01)
            finally:
                pipeline.close()

        serialized = json.dumps(records)
        self.assertNotIn(raw_sentinel, serialized)
        self.assertIn("selected_wallet_opening", serialized)

    def test_finalize_rejects_a_pid_stream_that_already_died(self) -> None:
        raw_record = {
            "pid": 929,
            "timestamp": "2026-08-12T12:00:15.000000Z",
            "level": "ERROR",
            "filename": "fearless",
            "message": "Substrate storage preflight timed out",
            "label": None,
        }
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "fake-stream.py"
            fake.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "print(json.dumps({'capture_control':'pid_watcher_armed','filename':'fearless'}), flush=True)\n"
                "print(json.dumps({'capture_control':'target_process_observed','filename':'fearless','pid':929}), flush=True)\n"
                "print(json.dumps({'capture_control':'pid_stream_started','filename':'fearless','pid':929}), flush=True)\n"
                f"print(json.dumps({raw_record!r}), flush=True)\n"
            )
            fake.chmod(0o700)
            pipeline = CAPTURE.FilterPipeline(
                Path(sys.executable),
                fake,
                Path(__file__).with_name("filter-startup-syslog.py"),
                "private-device-token",
            )
            deadline = time.monotonic() + 2
            while pipeline._syslog.poll() is None and time.monotonic() < deadline:
                time.sleep(0.01)
            with self.assertRaisesRegex(CAPTURE.CaptureError, "device_pid_stream_ended"):
                pipeline.finalize()
            pipeline.close()

    def test_constructor_failure_terminates_both_started_children(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "fake-stream.py"
            fake.write_text(
                "#!/usr/bin/env python3\n"
                "import time\n"
                "time.sleep(30)\n"
            )
            fake.chmod(0o700)
            children: list[subprocess.Popen[str]] = []
            real_popen = subprocess.Popen

            def tracking_popen(*args: Any, **kwargs: Any) -> Any:
                process = real_popen(*args, **kwargs)
                children.append(process)
                return process

            with patch.object(
                CAPTURE.subprocess,
                "Popen",
                side_effect=tracking_popen,
            ), patch.object(
                CAPTURE.threading.Thread,
                "start",
                side_effect=KeyboardInterrupt,
            ):
                with self.assertRaises(KeyboardInterrupt):
                    CAPTURE.FilterPipeline(
                        Path(sys.executable),
                        fake,
                        Path(__file__).with_name("filter-startup-syslog.py"),
                        "private-device-token",
                    )

            self.assertEqual(len(children), 2)
            self.assertTrue(all(process.poll() is not None for process in children))


class DevicePidStreamHelperTests(unittest.TestCase):
    def test_contract_requests_only_exact_pid_nonhistorical_nonsensitive_stream(self) -> None:
        self.assertEqual(
            HELPER.STREAM_FLAG_NAMES,
            ("PROCESS_ONLY", "PAYLOAD", "NO_SENSITIVE", "DEBUG", "INFO"),
        )
        for forbidden in ("HISTORICAL", "PROMISCUOUS", "CALLSTACK"):
            self.assertNotIn(forbidden, HELPER.STREAM_FLAG_NAMES)

    def test_safe_envelope_rejects_wrong_pid_or_process_and_keeps_minimal_fields(self) -> None:
        class Label:
            subsystem = "jp.co.soramitsu.fearlesswallet"
            category = "root"

        class Level:
            name = "ERROR"

        class Entry:
            pid = 939
            filename = "/private/var/fearless"
            timestamp = __import__("datetime").datetime(2026, 8, 12, 12, 0, 15)
            level = Level()
            message = "Substrate storage preflight timed out"
            label = Label()
            private_value = "AliceFamilyVault"

        envelope = HELPER.safe_envelope(Entry(), 939, "fearless")
        self.assertEqual(
            set(envelope),
            {"pid", "timestamp", "level", "filename", "message", "label"},
        )
        self.assertNotIn("AliceFamilyVault", json.dumps(envelope))
        with self.assertRaises(RuntimeError):
            HELPER.safe_envelope(Entry(), 940, "fearless")
        with self.assertRaises(RuntimeError):
            HELPER.safe_envelope(Entry(), 939, "FearlessHelper")

    def test_rejected_or_malformed_stream_ack_emits_no_started_control(self) -> None:
        os_trace_module = types.ModuleType("pymobiledevice3.services.os_trace")
        os_trace_module.OS_TRACE_RELAY_MESSAGE_FILTER_ALL = 65535

        class FakeService:
            def __init__(self, response: bytes):
                self.service = self
                self.chunks = [
                    struct.pack("<I", 2),
                    len(response).to_bytes(2, "little"),
                    response,
                ]

            async def connect(self) -> None:
                pass

            async def send_plist(self, request: dict[str, Any]) -> None:
                self.request = request

            async def recvall(self, count: int) -> bytes:
                value = self.chunks.pop(0)
                self.assert_length = len(value)
                if len(value) != count:
                    raise AssertionError((len(value), count))
                return value

        responses = (
            plistlib.dumps({"Status": "RequestRejected"}),
            b"not-a-plist",
        )
        with patch.dict(
            sys.modules,
            {"pymobiledevice3.services.os_trace": os_trace_module},
        ):
            for response in responses:
                with self.subTest(response=response):
                    safe_output = io.StringIO()
                    with contextlib.redirect_stdout(safe_output):
                        with self.assertRaises(Exception):
                            asyncio.run(
                                HELPER.start_confirmed_pid_stream(
                                    FakeService(response),
                                    939,
                                    421,
                                    "fearless",
                                )
                            )
                    self.assertEqual(safe_output.getvalue(), "")

    def test_helper_binds_first_target_and_requests_only_device_side_pid(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package = root / "pymobiledevice3"
            services = package / "services"
            services.mkdir(parents=True)
            (package / "__init__.py").write_text("")
            (services / "__init__.py").write_text("")
            (package / "lockdown.py").write_text(
                "class Lockdown:\n"
                "    async def close(self): pass\n"
                "async def create_using_usbmux(**kwargs):\n"
                "    assert kwargs == {'serial':'private-device-token','autopair':True,'connection_type':'USB'}\n"
                "    return Lockdown()\n"
            )
            (services / "os_trace.py").write_text(
                "import asyncio,plistlib,struct\n"
                "from datetime import datetime\n"
                "from enum import IntFlag\n"
                "OS_TRACE_RELAY_MESSAGE_FILTER_ALL=65535\n"
                "class OsActivityStreamFlag(IntFlag):\n"
                "    PROCESS_ONLY=1; PAYLOAD=4; HISTORICAL=8; CALLSTACK=16; DEBUG=32; NO_SENSITIVE=128; INFO=256; PROMISCUOUS=512\n"
                "class Level: name='ERROR'\n"
                "class Label: subsystem='jp.co.soramitsu.fearlesswallet'; category='root'\n"
                "class Entry:\n"
                "    pid=444; timestamp=datetime(2026,8,12,12,0,15); level=Level(); filename='fearless'; message='Substrate storage preflight timed out'; label=Label()\n"
                "def parse_syslog_entry(value):\n"
                "    assert value == b'one-record'\n"
                "    return Entry()\n"
                "class Wire:\n"
                "    def __init__(self): self.chunks=[]\n"
                "    async def send_plist(self, request):\n"
                "        required=1|4|32|128|256\n"
                "        assert request == {'Request':'StartActivity','MessageFilter':65535,'Pid':444,'StreamFlags':required}\n"
                "        assert request['StreamFlags'] & (8|16|512) == 0\n"
                "        response=plistlib.dumps({'Status':'RequestSuccessful'})\n"
                "        self.chunks=[struct.pack('<I',2),len(response).to_bytes(2,'little'),response,b'\\x02',struct.pack('<I',10),b'one-record']\n"
                "    async def recvall(self, count):\n"
                "        if not self.chunks:\n"
                "            await asyncio.sleep(60)\n"
                "        value=self.chunks.pop(0)\n"
                "        assert len(value) == count\n"
                "        return value\n"
                "class OsTraceService:\n"
                "    polls=0\n"
                "    def __init__(self, lockdown): self.service=Wire()\n"
                "    async def connect(self): pass\n"
                "    async def close(self): pass\n"
                "    async def get_pid_list(self):\n"
                "        type(self).polls += 1\n"
                "        if type(self).polls == 1: return {'Payload': {'12': {'ProcessName':'OtherApp'}}}\n"
                "        return {'Payload': {'444': {'ProcessName':'fearless'}, '12': {'ProcessName':'OtherApp'}}}\n"
            )
            environment = os.environ.copy()
            environment["PYTHONPATH"] = str(root)
            environment["PYTHONDONTWRITEBYTECODE"] = "1"
            process = subprocess.Popen(
                [
                    sys.executable,
                    str(HELPER_PATH),
                    "--udid",
                    "private-device-token",
                    "--process-poll-interval",
                    "0.001",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=environment,
            )
            assert process.stdout is not None
            lines = [process.stdout.readline() for _ in range(4)]
            process.terminate()
            _, stderr = process.communicate(timeout=5)

        self.assertEqual(process.returncode, -signal.SIGTERM, stderr)
        records = [json.loads(line) for line in lines]
        self.assertEqual(records[0]["capture_control"], "pid_watcher_armed")
        self.assertEqual(records[1]["capture_control"], "target_process_observed")
        self.assertEqual(records[1]["pid"], 444)
        self.assertEqual(records[2]["capture_control"], "pid_stream_started")
        self.assertEqual(records[2]["pid"], 444)
        self.assertEqual(records[3]["pid"], 444)
        serialized = "".join(lines)
        self.assertNotIn("OtherApp", serialized)
        self.assertNotIn("private-device-token", serialized)


class CaptureCliContractTests(unittest.TestCase):
    def test_expected_build_cli_accepts_only_distributed_and_hotfix_builds(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / "pymobiledevice3"
            executable.write_text("#!/usr/bin/env python3\n")
            executable.chmod(0o700)
            for build_number in CAPTURE.SUPPORTED_CAPTURE_BUILD_NUMBERS:
                with self.subTest(build_number=build_number), patch.object(
                    sys,
                    "argv",
                    [
                        str(SCRIPT_PATH),
                        "--pymobiledevice3",
                        str(executable),
                        "--output-directory",
                        str(root / f"capture-{build_number}"),
                        "--expected-build",
                        build_number,
                    ],
                ):
                    args = CAPTURE.parse_args()
                    self.assertEqual(args.expected_build, build_number)

            with patch.object(
                sys,
                "argv",
                [
                    str(SCRIPT_PATH),
                    "--pymobiledevice3",
                    str(executable),
                    "--output-directory",
                    str(root / "capture-unexpected"),
                    "--expected-build",
                    "2026.9.99",
                ],
            ), self.assertRaises(SystemExit):
                CAPTURE.parse_args()

    def test_documented_relative_invocation_resolves_private_helpers_absolutely(self) -> None:
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--help"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
            timeout=5,
            cwd=SCRIPT_PATH.parent.parent,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--stream-helper", result.stdout)

    def test_relative_entrypoint_defaults_pass_argument_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / "pymobiledevice3"
            executable.write_text("#!/usr/bin/env python3\n")
            executable.chmod(0o700)
            with patch.object(
                sys,
                "argv",
                [
                    str(SCRIPT_PATH),
                    "--pymobiledevice3",
                    str(executable),
                    "--output-directory",
                    str(root / "capture"),
                ],
            ):
                args = CAPTURE.parse_args()
            CAPTURE.validate_args(args)

        self.assertTrue(args.stream_helper.is_absolute())
        self.assertTrue(args.filter.is_absolute())

    def test_pinned_process_schema_accepts_integer_or_decimal_string_pid(self) -> None:
        backend = object.__new__(CAPTURE.PymobiledeviceBackend)
        for raw_pid in (1234, "1234"):
            with self.subTest(raw_pid=raw_pid):
                backend._json_command = lambda _arguments, pid=raw_pid: [
                    {"pid": pid, "name": "fearless"}
                ]
                self.assertEqual(
                    backend.process_snapshot("private-device-token"),
                    CAPTURE.ProcessSnapshot(True, 1234),
                )

    def test_sigterm_cleans_up_children_and_leaves_only_interrupted_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            interpreter = root / "python"
            interpreter.symlink_to(Path(sys.executable).resolve())
            backend = root / "pymobiledevice3"
            backend.write_text(
                f"#!{interpreter}\n"
                "import json,sys\n"
                "args=sys.argv[1:]\n"
                "if args == ['version']: print('10.7.2')\n"
                "elif args[:3] == ['usbmux','list','--usb']: print(json.dumps(['private-device']))\n"
                "elif args[:2] == ['apps','query']:\n"
                " print(json.dumps({'jp.co.soramitsu.fearlesswallet': {'CFBundleIdentifier':'jp.co.soramitsu.fearlesswallet','CFBundleShortVersionString':'4.2.0','CFBundleVersion':'2026.7.28'}}))\n"
                "elif args[:2] == ['processes','pgrep']: print('[]')\n"
                "else: sys.exit(2)\n"
            )
            backend.chmod(0o700)
            helper = root / "fake-pid-helper.py"
            helper.write_text(
                "import json,time\n"
                "print(json.dumps({'capture_control':'pid_watcher_armed','filename':'fearless'}), flush=True)\n"
                "time.sleep(60)\n"
            )
            output = root / "capture"
            process = subprocess.Popen(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--pymobiledevice3",
                    str(backend),
                    "--stream-helper",
                    str(helper),
                    "--output-directory",
                    str(output),
                    "--poll-interval",
                    "0.01",
                    "--device-poll-interval",
                    "0.01",
                    "--watcher-arm-timeout",
                    "2",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
            )

            def cleanup_process() -> None:
                if process.poll() is None:
                    process.kill()
                    process.communicate(timeout=5)

            self.addCleanup(cleanup_process)
            assert process.stdout is not None
            deadline = time.monotonic() + 5
            lines: list[str] = []
            while time.monotonic() < deadline:
                line = process.stdout.readline()
                if line:
                    lines.append(line)
                    if "FEARLESS_CAPTURE_ARMED" in line:
                        break
                elif process.poll() is not None:
                    break
            self.assertTrue(
                any("FEARLESS_CAPTURE_ARMED" in line for line in lines),
                "".join(lines),
            )
            children = subprocess.run(
                ["pgrep", "-P", str(process.pid)],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                check=False,
            )
            child_pids = [int(value) for value in children.stdout.split()]
            self.assertGreaterEqual(len(child_pids), 2)

            process.send_signal(signal.SIGTERM)
            remaining_stdout, stderr = process.communicate(timeout=5)
            lines.append(remaining_stdout)
            self.assertEqual(process.returncode, CAPTURE.EXIT_INTERRUPTED, stderr)
            self.assertIn("reason=interrupted", stderr)
            abort = json.loads((output / "capture-aborted.json").read_text())
            self.assertEqual(abort["reason"], "interrupted")
            self.assertFalse((output / "capture-receipt.json").exists())
            self.assertFalse(
                (output / "fearless-startup-sanitized.ndjson").exists()
            )
            for child_pid in child_pids:
                with self.assertRaises(ProcessLookupError):
                    os.kill(child_pid, 0)


if __name__ == "__main__":
    unittest.main()
