#!/usr/bin/env python3
"""Stream one Fearless PID from os_trace with device-side privacy filtering.

This helper must run with the pinned pymobiledevice3 10.7.2 interpreter. The
device receives the exact PID and PROCESS_ONLY flag; broad device logs,
historical records, call stacks, and sensitive payload fields are never
requested. Raw target-process messages go only to stdout for the sanitizer.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import posixpath
import sys
from typing import Any


EXPECTED_PROCESS = "fearless"
STREAM_FLAG_NAMES = (
    "PROCESS_ONLY",
    "PAYLOAD",
    "NO_SENSITIVE",
    "DEBUG",
    "INFO",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--expected-process", default=EXPECTED_PROCESS)
    parser.add_argument("--process-poll-interval", type=float, default=0.02)
    return parser.parse_args()


def safe_envelope(entry: Any, expected_pid: int, expected_process: str) -> dict[str, Any]:
    """Build the pinned CLI envelope after enforcing the device-side contract."""

    if entry.pid != expected_pid:
        raise RuntimeError("device stream returned an unexpected process")
    if posixpath.basename(entry.filename) != expected_process:
        raise RuntimeError("device stream returned an unexpected executable")
    label = None
    if entry.label is not None:
        label = {
            "subsystem": entry.label.subsystem,
            "category": entry.label.category,
        }
    return {
        "pid": entry.pid,
        "timestamp": entry.timestamp.isoformat(),
        "level": entry.level.name,
        "filename": expected_process,
        "message": entry.message,
        "label": label,
    }


async def stream(args: argparse.Namespace) -> None:
    # Imports stay inside the pinned-runtime entry point so source-level tests do
    # not need pymobiledevice3 installed globally.
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.os_trace import (
        OsActivityStreamFlag,
        OsTraceService,
    )

    if args.expected_process != EXPECTED_PROCESS or args.process_poll_interval <= 0:
        raise RuntimeError("invalid target process contract")

    lockdown = await create_using_usbmux(
        serial=args.udid,
        autopair=True,
        connection_type="USB",
    )
    service = OsTraceService(lockdown)
    stream_flags = 0
    for name in STREAM_FLAG_NAMES:
        stream_flags |= int(getattr(OsActivityStreamFlag, name))
    try:
        target_pid = None
        watcher_armed = False
        while target_pid is None:
            pid_service = OsTraceService(lockdown)
            try:
                response = await pid_service.get_pid_list()
            finally:
                await pid_service.close()
            payload = response.get("Payload") if isinstance(response, dict) else None
            if not isinstance(payload, dict):
                raise RuntimeError("invalid process-list response")
            matches: list[int] = []
            for raw_pid, process in payload.items():
                if not isinstance(process, dict):
                    continue
                if process.get("ProcessName") != args.expected_process:
                    continue
                try:
                    pid = int(raw_pid)
                except (TypeError, ValueError) as error:
                    raise RuntimeError("invalid target pid") from error
                if pid <= 0:
                    raise RuntimeError("invalid target pid")
                matches.append(pid)
            if len(matches) > 1:
                raise RuntimeError("multiple target processes")
            if not watcher_armed:
                if matches:
                    raise RuntimeError("target launched before watcher armed")
                print(
                    json.dumps(
                        {
                            "capture_control": "pid_watcher_armed",
                            "filename": args.expected_process,
                        },
                        sort_keys=True,
                    ),
                    flush=True,
                )
                watcher_armed = True
            if matches:
                target_pid = matches[0]
                break
            await asyncio.sleep(args.process_poll_interval)

        print(
            json.dumps(
                {
                    "capture_control": "target_process_observed",
                    "filename": args.expected_process,
                    "pid": target_pid,
                },
                sort_keys=True,
            ),
            flush=True,
        )
        async for entry in service.syslog(pid=target_pid, stream_flags=stream_flags):
            print(
                json.dumps(
                    safe_envelope(entry, target_pid, args.expected_process),
                    ensure_ascii=False,
                    sort_keys=True,
                ),
                flush=True,
            )
    finally:
        await service.close()
        await lockdown.close()


def main() -> int:
    args = parse_args()
    try:
        asyncio.run(stream(args))
    except (KeyboardInterrupt, BrokenPipeError):
        return 130
    except Exception:
        # Raw error text can contain device identifiers and is intentionally not
        # printed. The supervisor maps this stable nonzero status.
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
