#!/usr/bin/env python3
"""Run or validate the bounded native TON recovery XCTest inventory."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import time


def read(path):
    return json.loads(Path(path).read_text())


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def leaves(nodes):
    for node in nodes:
        if node.get("nodeType") == "Test Case":
            yield node
        yield from leaves(node.get("children", []))


def check_results(run, summary, tests, inventory, device, os_version):
    expected = inventory["tests"]
    require(expected and len(set(expected)) == len(expected), "empty or duplicate required inventory")
    require(run.get("sourceCommit") == inventory["compiledSourceCommit"], "wrong source commit")
    require(run.get("device") == device and run.get("exitCode") == 0, "wrong device or failed command")
    actual = list(leaves(tests.get("testNodes", [])))
    names = [node.get("nodeIdentifier") for node in actual]
    require(len(names) == len(set(names)) and set(names) == set(expected), "missing, duplicate or unlisted test")
    require(all(node.get("result") == "Passed" for node in actual), "nonpassing named test")
    require(summary.get("result") == "Passed", "nonpassing summary")
    for key in ("totalTestCount", "passedTests"):
        require(summary.get(key) == len(expected), "wrong " + key)
    for key in ("failedTests", "skippedTests", "expectedFailures"):
        require(summary.get(key) == 0, "nonzero " + key)
    require(summary.get("testFailures") == [], "test failure diagnostics")
    configurations = summary.get("devicesAndConfigurations", [])
    require(len(configurations) == 1, "wrong configuration count")
    for devices in (tests.get("devices", []), [configurations[0].get("device", {})]):
        require(len(devices) == 1, "wrong device count")
        actual_device = devices[0]
        require(actual_device.get("deviceId") == device, "result device mismatch")
        require(actual_device.get("osVersion") == os_version, "runtime mismatch")
        require(actual_device.get("platform") == "iOS Simulator", "not a simulator result")
    for key in ("failedTests", "skippedTests", "expectedFailures"):
        require(configurations[0].get(key) == 0, "configuration " + key)
    require(configurations[0].get("passedTests") == len(expected), "configuration passed count")
    return actual_device


def check_reader(reader, inventory):
    reader = Path(reader).resolve()
    frozen = read(reader / "freeze.json")
    require(frozen.get("readerCommit") == inventory["compiledSourceCommit"], "reader source mismatch")
    pins = frozen.get("files", [])
    require(pins, "empty artifact pins")
    paths = []
    for pin in pins:
        path = Path(pin["path"]).resolve()
        require(path.is_relative_to(reader / "Products"), "artifact outside frozen Products")
        require(path.is_file(), "missing artifact: " + str(path))
        require(path.stat().st_size == pin["bytes"] and digest(path) == pin["sha256"], "artifact drift: " + str(path))
        paths.append(path)
    require(len(paths) == len(set(paths)), "duplicate artifact pins")
    actual = {p.resolve() for p in (reader / "Products").rglob("*") if p.is_file()}
    require(set(paths) == actual, "unlisted artifact")
    require(any(p.name == "fearlessTests" and p.parent.name == "fearlessTests.xctest" for p in paths), "missing compiled reader XCTest")
    require(any(p.name == "fearless.debug.dylib" for p in paths), "missing compiled app")
    return len(paths)


def check_source(repo, inventory):
    for pin in inventory["testSources"]:
        data = subprocess.check_output(["git", "show", inventory["compiledSourceCommit"] + ":" + pin["path"]], cwd=repo)
        require(hashlib.sha256(data).hexdigest() == pin["sha256"], "test source drift")


def validate(out, reader, inventory, device, os_version, repo):
    out, reader = Path(out), Path(reader).resolve()
    check_source(repo, inventory)
    count = check_reader(reader, inventory)
    run = read(out / "run.json")
    device_info = check_results(run, read(out / "summary.json"), read(out / "tests.json"), inventory, device, os_version)
    configured = plistlib.loads((out / "configured.xctestrun").read_bytes())
    host = reader / "Products/Debug-iphonesimulator/fearless.app"
    require(configured["fearlessTests"]["TestHostPath"] == str(host), "wrong tested host")
    require(configured["fearlessTests"]["TestBundlePath"] == "__TESTHOST__/PlugIns/fearlessTests.xctest", "wrong tested bundle")
    result = dict(status="passed", sourceCommit=inventory["compiledSourceCommit"], namedTests=len(inventory["tests"]),
                  artifactPins=count, device=device_info, scope=inventory["scope"],
                  inputs={name: digest(out / name) for name in ("run.json", "summary.json", "tests.json", "configured.xctestrun")},
                  readerFreezeSha256=digest(reader / "freeze.json"))
    (out / "validation.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def run_tests(out, reader, inventory, device):
    out, reader = Path(out), Path(reader).resolve()
    check_reader(reader, inventory)
    out.mkdir(parents=True, exist_ok=False)
    templates = list((reader / "Products").glob("*.xctestrun"))
    require(len(templates) == 1, "ambiguous xctestrun")
    template = templates[0].read_text().replace("__TESTROOT__", str(reader / "Products"))
    configured = plistlib.loads(template.encode())
    configured["fearlessTests"].setdefault("EnvironmentVariables", {})["TON_IMPORT_EVIDENCE_DIR"] = str(out / "captures")
    path = out / "configured.xctestrun"
    path.write_bytes(plistlib.dumps(configured))
    command = ["xcodebuild", "-xctestrun", str(path), "-destination", "platform=iOS Simulator,id=" + device,
               "-resultBundlePath", str(out / "result.xcresult"), "-parallel-testing-enabled", "NO",
               "-collect-test-diagnostics", "never", "test-without-building"]
    command += ["-only-testing:fearlessTests/" + name for name in sorted({item.split("/")[0] for item in inventory["tests"]})]
    record = dict(command=command, sourceCommit=inventory["compiledSourceCommit"], device=device, startedAt=time.time())
    with (out / "test.log").open("w") as log:
        record["exitCode"] = subprocess.call(command, stdout=log, stderr=subprocess.STDOUT)
    record["finishedAt"] = time.time()
    (out / "run.json").write_text(json.dumps(record, indent=2) + "\n")
    for kind in ("summary", "tests"):
        command = ["xcrun", "xcresulttool", "get", "test-results", kind, "--path", str(out / "result.xcresult")]
        completed = subprocess.run(command, capture_output=True, check=False)
        (out / (kind + ".json")).write_bytes(completed.stdout)
        (out / (kind + "-stderr.txt")).write_bytes(completed.stderr)
        require(completed.returncode == 0, "xcresulttool " + kind + " failed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--reader", type=Path, required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--os", required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    required = read(Path(__file__).with_name("inventory.json"))
    if args.run:
        check_source(args.repo, required)
        run_tests(args.out.resolve(), args.reader, required, args.device)
    print(json.dumps(validate(args.out, args.reader, required, args.device, args.os, args.repo), indent=2))
