#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import io
import json
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("filter-startup-syslog.py")
SPEC = importlib.util.spec_from_file_location("filter_startup_syslog", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
FILTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FILTER)


class StartupSyslogFilterTests(unittest.TestCase):
    def test_strict_process_mode_accepts_only_exact_fearless_envelope(self) -> None:
        source = io.StringIO(
            json.dumps(
                {
                    "filename": "/private/var/containers/Bundle/fearless",
                    "timestamp": "2026-08-10T12:00:15.000000",
                    "level": "ERROR",
                    "message": "Substrate storage preflight timed out",
                    "label": {
                        "subsystem": "jp.co.soramitsu.fearlesswallet",
                        "category": "root",
                    },
                }
            )
            + "\n"
        )
        output = io.StringIO()

        FILTER.filter_stream(source, [output], expected_process="fearless")

        self.assertIn("SUBSTRATE_PREFLIGHT_TIMEOUT", output.getvalue())
        self.assertNotIn("/private/var", output.getvalue())
        self.assertNotIn("filename", output.getvalue())

    def test_strict_process_mode_rejects_wrong_or_missing_process(self) -> None:
        for filename in ("FearlessHelper", None):
            with self.subTest(filename=filename):
                entry = {
                    "timestamp": "2026-08-10T12:00:15.000000",
                    "level": "ERROR",
                    "message": "Storage migration failed",
                    "label": None,
                }
                if filename is not None:
                    entry["filename"] = filename
                with self.assertRaises(FILTER.FilterProtocolError):
                    FILTER.filter_stream(
                        io.StringIO(json.dumps(entry) + "\n"),
                        [io.StringIO()],
                        expected_process="fearless",
                    )

    def test_strict_process_mode_rejects_malformed_ndjson(self) -> None:
        with self.assertRaises(FILTER.FilterProtocolError):
            FILTER.filter_stream(
                io.StringIO("not-json\n"),
                [io.StringIO()],
                expected_process="fearless",
            )

    def test_strict_process_mode_validates_pid_without_emitting_it(self) -> None:
        entry = {
            "pid": 1234,
            "filename": "fearless",
            "timestamp": "2026-08-10T12:00:15.000000",
            "level": "ERROR",
            "message": "Substrate storage preflight timed out",
            "label": None,
        }
        output = io.StringIO()
        FILTER.filter_stream(
            io.StringIO(json.dumps(entry) + "\n"),
            [output],
            expected_process="fearless",
            expected_pid=1234,
        )
        self.assertNotIn("1234", output.getvalue())

        with self.assertRaises(FILTER.FilterProtocolError):
            FILTER.filter_stream(
                io.StringIO(json.dumps(entry) + "\n"),
                [io.StringIO()],
                expected_process="fearless",
                expected_pid=5678,
            )

    def test_strict_watcher_binds_first_pid_and_emits_only_safe_controls(self) -> None:
        records = [
            {"capture_control": "pid_watcher_armed", "filename": "fearless"},
            {
                "capture_control": "target_process_observed",
                "filename": "fearless",
                "pid": 2468,
            },
            {
                "pid": 2468,
                "filename": "fearless",
                "timestamp": "2026-08-10T12:00:15.000000",
                "level": "ERROR",
                "message": "Substrate storage preflight timed out",
                "label": None,
            },
        ]
        output = io.StringIO()
        FILTER.filter_stream(
            io.StringIO("".join(json.dumps(record) + "\n" for record in records)),
            [output],
            expected_process="fearless",
            bind_first_pid=True,
        )
        value = output.getvalue()
        self.assertIn("FEARLESS_PID_WATCHER_ARMED", value)
        self.assertIn("FEARLESS_TARGET_PROCESS_OBSERVED", value)
        self.assertIn("SUBSTRATE_PREFLIGHT_TIMEOUT", value)
        self.assertNotIn("2468", value)

    def test_strict_watcher_rejects_record_before_binding_or_pid_change(self) -> None:
        raw = {
            "pid": 3579,
            "filename": "fearless",
            "timestamp": "2026-08-10T12:00:15.000000",
            "level": "ERROR",
            "message": "Storage migration failed",
            "label": None,
        }
        with self.assertRaises(FILTER.FilterProtocolError):
            FILTER.filter_stream(
                io.StringIO(json.dumps(raw) + "\n"),
                [io.StringIO()],
                expected_process="fearless",
                bind_first_pid=True,
            )

        controls_and_wrong_pid = [
            {"capture_control": "pid_watcher_armed", "filename": "fearless"},
            {
                "capture_control": "target_process_observed",
                "filename": "fearless",
                "pid": 3579,
            },
            {**raw, "pid": 3580},
        ]
        with self.assertRaises(FILTER.FilterProtocolError):
            FILTER.filter_stream(
                io.StringIO(
                    "".join(
                        json.dumps(record) + "\n"
                        for record in controls_and_wrong_pid
                    )
                ),
                [io.StringIO()],
                expected_process="fearless",
                bind_first_pid=True,
            )

    def test_classifies_legacy_description_without_retaining_identifiers_or_paths(self) -> None:
        source = io.StringIO(
            json.dumps(
                {
                    "timestamp": "2026-08-10T12:00:15.125000",
                    "level": "ERROR",
                    "message": (
                        "Selected account: 123e4567-e89b-12d3-a456-426614174000 "
                        "failed at /private/var/mobile/Containers/Data/store.sqlite"
                    ),
                    "label": {
                        "subsystem": "jp.co.soramitsu.fearlesswallet",
                        "category": "root",
                    },
                }
            )
            + "\n"
        )
        output = io.StringIO()

        FILTER.filter_stream(source, [output])

        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(records[0]["event"], "FEARLESS_STARTUP_CAPTURE_BEGIN")
        self.assertEqual(
            records[1]["message"],
            "legacy_startup_description=selected_wallet_opening,failure",
        )
        self.assertNotIn("123e4567", output.getvalue())
        self.assertNotIn("/private/var", output.getvalue())

    def test_never_retains_freeform_wallet_names_from_legacy_logs(self) -> None:
        source = io.StringIO(
            json.dumps(
                {
                    "timestamp": "2026-08-10T12:00:15.125000",
                    "level": "ERROR",
                    "message": "Selected wallet Alice Family Vault failed to open",
                    "label": {"subsystem": "jp.co.soramitsu.fearlesswallet", "category": "root"},
                }
            )
            + "\n"
        )
        output = io.StringIO()

        FILTER.filter_stream(source, [output])

        self.assertNotIn("Alice", output.getvalue())
        self.assertNotIn("Family", output.getvalue())
        self.assertIn("selected_wallet_opening", output.getvalue())

    def test_discards_non_startup_message_but_keeps_safe_marker(self) -> None:
        source = io.StringIO(
            "\n".join(
                [
                    json.dumps(
                        {
                            "timestamp": "2026-08-10T12:00:00.000000",
                            "level": "INFO",
                            "message": "ordinary balance refresh",
                            "label": None,
                        }
                    ),
                    json.dumps(
                        {
                            "timestamp": "2026-08-10T12:00:15.000000",
                            "level": "ERROR",
                            "message": (
                                "FEARLESS_STARTUP_FAILED phase=substratePreflight "
                                "code=SUBSTRATE_PREFLIGHT_FAILED elapsed_ms=15000 "
                                "recovery=retry required_free_bytes=0"
                            ),
                            "label": {
                                "subsystem": "jp.co.soramitsu.fearlesswallet",
                                "category": "startup-readiness",
                            },
                        }
                    ),
                ]
            )
            + "\n"
        )
        output = io.StringIO()

        FILTER.filter_stream(source, [output])

        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(len(records), 2)
        self.assertEqual(records[1]["category"], "startup-readiness")
        self.assertEqual(
            records[1]["message"],
            (
                "FEARLESS_STARTUP_FAILED phase=substratePreflight "
                "code=SUBSTRATE_PREFLIGHT_FAILED elapsed_ms=15000 "
                "recovery=retry required_free_bytes=0"
            ),
        )

    def test_keeps_distributed_build_untyped_failure_marker(self) -> None:
        source = io.StringIO(
            "\n".join(
                [
                    json.dumps(
                        {
                            "timestamp": "2026-08-10T12:00:15.000000",
                            "level": "ERROR",
                            "message": "Substrate storage preflight timed out",
                            "label": {
                                "subsystem": "jp.co.soramitsu.fearlesswallet",
                                "category": "root",
                            },
                        }
                    ),
                    json.dumps(
                        {
                            "timestamp": "2026-08-10T12:00:15.001000",
                            "level": "ERROR",
                            "message": "FEARLESS_STARTUP_FAILED",
                            "label": {
                                "subsystem": "jp.co.soramitsu.fearlesswallet",
                                "category": "startup-readiness",
                            },
                        }
                    ),
                ]
            )
            + "\n"
        )
        output = io.StringIO()

        FILTER.filter_stream(source, [output])

        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(
            records[1]["message"],
            "legacy_incident_code=SUBSTRATE_PREFLIGHT_TIMEOUT "
            "legacy_resolution=soft_threshold",
        )
        self.assertEqual(records[2]["message"], "FEARLESS_STARTUP_FAILED")
        self.assertEqual(records[2]["timestamp"], "2026-08-10T12:00:15.001000")

    def test_replaces_malformed_marker_and_untrusted_envelope_fields(self) -> None:
        source = io.StringIO(
            json.dumps(
                {
                    "timestamp": "/private/var/mobile/secret.sqlite",
                    "level": "wallet-Alice",
                    "message": (
                        "FEARLESS_STARTUP_FAILED phase=substratePreflight "
                        "code=SUBSTRATE_PREFLIGHT_FAILED elapsed_ms=15000 "
                        "recovery=retry required_free_bytes=0 note=AliceVault"
                    ),
                    "label": {
                        "subsystem": "jp.co.soramitsu.fearlesswallet",
                        "category": "startup-readiness",
                    },
                }
            )
            + "\n"
        )
        output = io.StringIO()

        FILTER.filter_stream(source, [output])

        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertIsNone(records[0]["timestamp"])
        self.assertIsNone(records[1]["timestamp"])
        self.assertIsNone(records[1]["level"])
        self.assertEqual(records[1]["message"], "invalid_startup_marker")
        self.assertNotIn("Alice", output.getvalue())
        self.assertNotIn("/private/var", output.getvalue())

    def test_discards_identifier_shaped_subsystem_and_category_labels(self) -> None:
        identifier = "5F3DA97572D04A82B2E62FFEC93A807BC02B9451"
        source = io.StringIO(
            json.dumps(
                {
                    "timestamp": "2026-08-10T12:00:15.125000",
                    "level": "ERROR",
                    "message": "Storage migration failed",
                    "label": {
                        "subsystem": identifier,
                        "category": identifier,
                    },
                }
            )
            + "\n"
        )
        output = io.StringIO()

        FILTER.filter_stream(source, [output])

        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertIsNone(records[1]["subsystem"])
        self.assertIsNone(records[1]["category"])
        self.assertNotIn(identifier, output.getvalue())

    def test_maps_known_legacy_failures_without_retaining_dynamic_values(self) -> None:
        messages = [
            (
                "Wallet storage migration timed out",
                "legacy_incident_code=MIGRATION_TIMEOUT "
                "legacy_resolution=soft_threshold",
            ),
            (
                "Substrate storage preflight timed out",
                "legacy_incident_code=SUBSTRATE_PREFLIGHT_TIMEOUT "
                "legacy_resolution=soft_threshold",
            ),
            (
                "Selected wallet storage setup timed out",
                "legacy_incident_code=SELECTED_WALLET_OPENING_TIMEOUT "
                "legacy_resolution=soft_threshold",
            ),
            (
                "User store model is unavailable for PrivateModelName",
                "legacy_incident_code=USER_STORAGE_COMPATIBILITY_MISSING "
                "legacy_resolution=compatibility_model",
            ),
            (
                "Substrate storage entity PrivateEntity cannot resolve class PrivateClass",
                "legacy_incident_code=SUBSTRATE_PREFLIGHT_COMPATIBILITY_MISSING "
                "legacy_resolution=compatibility_model",
            ),
            (
                "The wallet store contains duplicate identifiers",
                "legacy_incident_code=WALLET_MAPPING_CONFLICT "
                "legacy_resolution=compatibility_mapping",
            ),
            (
                "SQLite replacement requires 5242880 free bytes, but only "
                "1024 bytes are available",
                "legacy_incident_code=INSUFFICIENT_STORAGE "
                "legacy_resolution=free_storage required_free_bytes=5242880",
            ),
        ]
        source = io.StringIO(
            "".join(
                json.dumps(
                    {
                        "timestamp": f"2026-08-10T12:00:{index:02d}.000000",
                        "level": "ERROR",
                        "message": message,
                        "label": {
                            "subsystem": "jp.co.soramitsu.fearlesswallet",
                            "category": "root",
                        },
                    }
                )
                + "\n"
                for index, (message, _) in enumerate(messages)
            )
        )
        output = io.StringIO()

        FILTER.filter_stream(source, [output])

        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(
            [record["message"] for record in records[1:]],
            [expected for _, expected in messages],
        )
        self.assertNotIn("PrivateModelName", output.getvalue())
        self.assertNotIn("PrivateEntity", output.getvalue())
        self.assertNotIn("PrivateClass", output.getvalue())
        self.assertNotIn("1024", output.getvalue())


if __name__ == "__main__":
    unittest.main()
