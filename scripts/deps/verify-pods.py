#!/usr/bin/env python3
"""Verify installed CocoaPods sources and the build tools Xcode runs.

`Podfile` pins Sora pods, SVGKit, Charts and others by version or git tag, and a
tag can be moved. `R.swift` and `SwiftFormat` arrive as prebuilt executables that
run inside every build; `rswift` writes Swift that is compiled into the app. This
check compares every installed pod's files, and each executable, with the digests
recorded in `config/pods-source-pins.json`, so a moved tag, a replaced download
or a local edit fails the build before any of that code runs.

    python3 -I scripts/deps/verify-pods.py [ROOT]
    python3 -I scripts/deps/verify-pods.py [ROOT] --record --pods <reviewed Pods dir>

`--record` rewrites the pins from a Pods directory that has been reviewed against
its upstream sources. Never record from an unreviewed install.
"""

import argparse
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

PINS = "config/pods-source-pins.json"

# Pods whose code is compiled into the app or its tests.
SOURCE_PODS = (
    "Charts",
    "CocoaLumberjack",
    "Cuckoo",
    "FireMock",
    "MediaView",
    "R.swift.Library",
    "SVGKit",
    "SoraFoundation",
    "SoraKeystore",
    "SoraUI",
    "SwiftAlgorithms",
)

# Executables that Xcode build phases run.
TOOLS = (
    "R.swift/rswift",
    "SwiftFormat/CommandLineTool/swiftformat",
)


class PodsVerificationError(Exception):
    pass


def file_digest(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_digest(directory):
    """Digest of every file, symlink and executable bit under `directory`."""
    if directory.is_symlink() or not directory.is_dir():
        raise PodsVerificationError("Missing pod directory: " + directory.name)
    entries = []
    for path in sorted(directory.rglob("*"), key=lambda item: item.relative_to(directory).as_posix()):
        relative = path.relative_to(directory).as_posix()
        mode = path.lstat().st_mode
        if stat.S_ISLNK(mode):
            entries.append("L %s %s" % (relative, os.readlink(path)))
        elif stat.S_ISREG(mode):
            executable = "x" if mode & 0o111 else "-"
            entries.append("F %s %s %s" % (relative, file_digest(path), executable))
        elif stat.S_ISDIR(mode):
            continue
        else:
            raise PodsVerificationError("Unexpected file type in pod: " + relative)
    return hashlib.sha256("\n".join(entries).encode("utf-8")).hexdigest()


def measure(pods):
    measured = {"pods": {}, "tools": {}}
    for name in SOURCE_PODS:
        measured["pods"][name] = tree_digest(pods / name)
    for relative in TOOLS:
        tool = pods / relative
        if tool.is_symlink() or not tool.is_file():
            raise PodsVerificationError("Missing build tool: " + relative)
        measured["tools"][relative] = file_digest(tool)
    return measured


def verify(root, pods=None):
    root = Path(root).resolve()
    pods = Path(pods).resolve() if pods else root / "Pods"
    try:
        recorded = json.loads((root / PINS).read_text())
    except (OSError, ValueError) as error:
        raise PodsVerificationError("Cannot read " + PINS + ": " + str(error))
    if recorded.get("schema") != 1:
        raise PodsVerificationError("Unsupported " + PINS + " schema")
    if set(recorded.get("pods", {})) != set(SOURCE_PODS) or set(recorded.get("tools", {})) != set(TOOLS):
        raise PodsVerificationError(PINS + " does not list exactly the verified pods and tools")

    measured = measure(pods)
    for name in SOURCE_PODS:
        if measured["pods"][name] != recorded["pods"][name]:
            raise PodsVerificationError("Pod sources differ from the reviewed pin: " + name)
    for relative in TOOLS:
        if measured["tools"][relative] != recorded["tools"][relative]:
            raise PodsVerificationError("Build tool differs from the reviewed pin: " + relative)
    return {"pods": len(SOURCE_PODS), "tools": len(TOOLS)}


def record(root, pods):
    root = Path(root).resolve()
    measured = measure(Path(pods).resolve())
    document = {
        "schema": 1,
        "note": "Digests of reviewed CocoaPods sources and build-phase executables; see scripts/deps/verify-pods.py",
        "pods": measured["pods"],
        "tools": measured["tools"],
    }
    (root / PINS).write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
    return document


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--pods", help="Pods directory to check (default: ROOT/Pods)")
    parser.add_argument("--record", action="store_true", help="rewrite the pins from a reviewed Pods directory")
    args = parser.parse_args(argv)
    try:
        if args.record:
            if not args.pods:
                parser.error("--record needs --pods pointing at a reviewed install")
            record(args.root, args.pods)
            print("[pods] recorded " + PINS)
        else:
            print("[pods] " + json.dumps(verify(args.root, args.pods), sort_keys=True))
    except (OSError, PodsVerificationError) as error:
        print("[pods] " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
