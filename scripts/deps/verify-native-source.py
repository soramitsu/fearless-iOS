#!/usr/bin/env python3
"""Verify that the iOS build uses app-owned native modules and reviewed binaries."""

import argparse
import hashlib
import json
import re
from pathlib import Path


RETIRED_REPOSITORIES = ("shared-features-spm", "fearless-starscream", "fearless-keys")
RESOLVED_PATHS = (
    "fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    "fearless.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
)


def owned_path(root, relative):
    path = root / relative
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError as error:
        raise ValueError("Native source escapes the app checkout: " + str(relative)) from error
    if not path.exists():
        raise ValueError("Missing native source: " + str(relative))
    return path


def verify(root):
    root = Path(root).resolve()
    native = owned_path(root, "Native")
    if native.is_symlink() or (native / ".git").exists():
        raise ValueError("Native must be an ordinary app-owned source directory")
    contract = json.loads(owned_path(root, "config/native-sources.json").read_text())
    if type(contract.get("schema")) is not int or contract.get("schema") != 1 or contract.get("ownership") != "soramitsu/fearless-iOS" or contract.get("sourceRoot") != "Native":
        raise ValueError("Invalid iOS native ownership contract")

    manifest = owned_path(root, "Native/Package.swift").read_text()
    project = owned_path(root, "fearless.xcodeproj/project.pbxproj").read_text()
    if not re.search(r"relativePath\s*=\s*Native\s*;", project):
        raise ValueError("Xcode must build the local Native package")
    if 'name: "FearlessNative"' not in manifest:
        raise ValueError("The local package must identify the iOS native modules")
    build_files = [root / "Native/Package.swift", root / "Podfile"]
    build_files.extend((root / "Packages").glob("*/Package.swift"))
    for file in build_files:
        text = file.read_text()
        if any(name in text for name in RETIRED_REPOSITORIES) or "FearlessKeys" in text:
            raise ValueError("Retired internal dependency in " + str(file.relative_to(root)))
        for relative in re.findall(r'\.package\(\s*path\s*:\s*"([^"]+)"', text):
            package = file.parent / relative
            try:
                owned_path(root, package.relative_to(root))
                owned_path(root, (package / "Package.swift").relative_to(root))
            except ValueError as error:
                raise ValueError("A local package cannot depend on a sibling checkout") from error
    if any(name in project for name in RETIRED_REPOSITORIES) or "FearlessUtilsCompat" in project:
        raise ValueError("Xcode still refers to a retired internal package")

    resolved = [json.loads(owned_path(root, path).read_text()) for path in RESOLVED_PATHS]
    if resolved[0] != resolved[1]:
        raise ValueError("Committed SwiftPM resolution files differ")
    pins = resolved[0].get("pins", [])
    identities = [pin.get("identity") for pin in pins]
    if len(identities) != len(set(identities)):
        raise ValueError("Duplicate SwiftPM package identity")
    for pin in pins:
        if any(name in json.dumps(pin) for name in RETIRED_REPOSITORIES):
            raise ValueError("SwiftPM still resolves a retired internal repository")
        revision = pin.get("state", {}).get("revision", "")
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise ValueError("SwiftPM dependency is not bound to a commit")

    source_files = 0
    for directory in ("Sources", "Tests", "native", "Binaries"):
        source = owned_path(root, "Native/" + directory)
        for path in source.rglob("*"):
            if path.name == ".git":
                raise ValueError("Nested Git checkout in native sources")
            owned_path(root, path.relative_to(root))
            if path.is_file():
                source_files += 1

    binaries = contract.get("nativeBinaries")
    if not isinstance(binaries, dict) or not binaries:
        raise ValueError("Native binary provenance is missing")
    actual_files = {path.relative_to(native).as_posix() for path in (native / "Binaries").rglob("*") if path.is_file()}
    if actual_files != set(binaries):
        raise ValueError("Native binary inventory differs from its provenance record")
    for relative, digest in binaries.items():
        if not relative.startswith("Binaries/") or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid native binary provenance entry")
        path = owned_path(native, relative)
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError("Native binary bytes changed: " + relative)
    return {"ownership": contract["ownership"], "sourceFiles": source_files, "nativeBinaryFiles": len(binaries), "externalPackages": len(pins)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".")
    args = parser.parse_args()
    try:
        result = verify(Path(args.root))
    except (OSError, ValueError, TypeError, KeyError) as error:
        parser.exit(1, "[native-source] " + str(error) + "\n")
    print("[native-source] " + json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
