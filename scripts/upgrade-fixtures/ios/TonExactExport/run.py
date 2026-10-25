#!/usr/bin/env python3
"""Run and strictly validate the source-bound TON exact-export regression inventory."""
import argparse
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import time

module_path = Path(__file__).resolve().parent.parent / "TonRecovery/qualify.py"
spec = importlib.util.spec_from_file_location("ton_recovery_gate", module_path)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def run(out, reader, inventory, device):
    gate.check_reader(reader, inventory)
    out.mkdir(parents=True, exist_ok=False)
    templates = list((reader / "Products").glob("*.xctestrun"))
    gate.require(len(templates) == 1, "ambiguous xctestrun")
    configured = plistlib.loads(templates[0].read_text().replace("__TESTROOT__", str(reader / "Products")).encode())
    environment = configured["fearlessTests"].setdefault("EnvironmentVariables", {})
    environment["TON_EXPORT_EVIDENCE_DIR"] = str(out / "captures/export")
    environment["TON_IMPORT_EVIDENCE_DIR"] = str(out / "captures/import")
    config_path = out / "configured.xctestrun"
    config_path.write_bytes(plistlib.dumps(configured))
    command = ["xcodebuild", "-xctestrun", str(config_path), "-destination", "platform=iOS Simulator,id=" + device,
               "-resultBundlePath", str(out / "result.xcresult"), "-parallel-testing-enabled", "NO",
               "-collect-test-diagnostics", "never", "test-without-building"]
    command += ["-only-testing:fearlessTests/" + name for name in sorted({test.split("/")[0] for test in inventory["tests"]})]
    record = dict(command=command, sourceCommit=inventory["compiledSourceCommit"], device=device, startedAt=time.time())
    with (out / "test.log").open("w") as log:
        record["exitCode"] = subprocess.call(command, stdout=log, stderr=subprocess.STDOUT)
    record["finishedAt"] = time.time()
    (out / "run.json").write_text(json.dumps(record, indent=2) + "\n")
    for kind in ("summary", "tests"):
        result = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", kind, "--path", str(out / "result.xcresult")], capture_output=True)
        (out / (kind + ".json")).write_bytes(result.stdout)
        (out / (kind + "-stderr.txt")).write_bytes(result.stderr)
        gate.require(result.returncode == 0, "xcresulttool failed: " + kind)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--reader", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--device", required=True)
    parser.add_argument("--os", required=True)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    inventory = gate.read(Path(__file__).with_name("inventory.json"))
    gate.check_source(args.repo, inventory)
    if not args.validate_only:
        run(args.out.resolve(), args.reader.resolve(), inventory, args.device)
    print(json.dumps(gate.validate(args.out.resolve(), args.reader.resolve(), inventory, args.device, args.os, args.repo), indent=2))
