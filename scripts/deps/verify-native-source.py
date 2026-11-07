#!/usr/bin/env python3
"""Verify that the iOS build uses app-owned native modules and reviewed binaries."""

import argparse
import hashlib
import json
import os
import re
import subprocess
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


def verify(root, source_packages=None):
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
    if (root / ".git").exists():
        tracked = subprocess.run(
            ["git", "ls-files", "-z", "--", "Native/Binaries"], cwd=root,
            check=True, capture_output=True,
        ).stdout.decode().split("\0")
        tracked_binaries = {path.removeprefix("Native/") for path in tracked if path}
        if tracked_binaries != set(binaries):
            raise ValueError("Native binary provenance must match tracked files; ignored local files cannot qualify a clean checkout")
    if (root / ".git").exists():
        tracked = subprocess.run(
            ["git", "ls-files", "-z", "--", "Native/Sources", "Native/Tests"], cwd=root,
            check=True, capture_output=True,
        ).stdout.decode().split("\0")
        actual_sources = {
            path.relative_to(root).as_posix()
            for directory in ("Sources", "Tests")
            for path in (native / directory).rglob("*") if path.is_file()
        }
        if actual_sources != {path for path in tracked if path}:
            raise ValueError("Native source files must be tracked, including generated mocks used by tests")
    for relative, digest in binaries.items():
        if not relative.startswith("Binaries/") or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid native binary provenance entry")
        path = owned_path(native, relative)
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError("Native binary bytes changed: " + relative)
    result = {"ownership": contract["ownership"], "sourceFiles": source_files, "nativeBinaryFiles": len(binaries), "externalPackages": len(pins)}
    if source_packages:
        result["verifiedCheckouts"] = verify_checkouts(Path(source_packages), pins)
    return result


def checkout_name(pin):
    """SwiftPM names a checkout after the last component of the repository URL."""
    location = str(pin.get("location", "")).rstrip("/")
    name = location.rsplit("/", 1)[-1]
    if name.endswith(".git"):
        name = name[:-4]
    if not name or name in (".", "..") or "/" in name:
        raise ValueError("Unusable SwiftPM location for " + str(pin.get("identity")))
    return name


def git_output(checkout, *arguments):
    completed = subprocess.run(
        # A verifier must not write: no index refresh, no locks.
        ["git", "--no-optional-locks", "-C", str(checkout), *arguments],
        check=False, capture_output=True,
    )
    if completed.returncode != 0:
        raise ValueError("Git cannot read resolved checkout " + checkout.name)
    return completed.stdout.decode("utf-8", "replace")


def verify_checkouts(source_packages, pins):
    """Every pinned package must be checked out at exactly its pinned commit, unmodified.

    Before 4.2.1 the callers passed SOURCE_PACKAGES_DIR but nothing read it, so a
    tampered or moved checkout in the build's package directory went unnoticed.
    """
    checkouts = source_packages / "checkouts"
    if not checkouts.is_dir():
        raise ValueError("SOURCE_PACKAGES_DIR has no checkouts directory: " + str(source_packages))
    verified = 0
    for pin in pins:
        revision = pin.get("state", {}).get("revision", "")
        checkout = checkouts / checkout_name(pin)
        if checkout.is_symlink() or not checkout.is_dir():
            raise ValueError("Missing resolved checkout for " + str(pin.get("identity")))
        head = git_output(checkout, "rev-parse", "HEAD").strip()
        if head != revision:
            raise ValueError("Resolved checkout " + checkout.name + " is at " + head[:12] + ", pinned " + revision[:12])
        changes = git_output(checkout, "status", "--porcelain", "--untracked-files=all", "--ignore-submodules=none")
        if changes.strip():
            raise ValueError("Resolved checkout " + checkout.name + " differs from its pinned commit")
        verified += 1
    return verified


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument(
        "--source-packages",
        default=os.environ.get("SOURCE_PACKAGES_DIR", ""),
        help="SwiftPM source packages directory whose checkouts must match the pins (default: $SOURCE_PACKAGES_DIR)",
    )
    args = parser.parse_args()
    try:
        result = verify(Path(args.root), source_packages=args.source_packages or None)
    except (OSError, ValueError, TypeError, KeyError) as error:
        parser.exit(1, "[native-source] " + str(error) + "\n")
    print("[native-source] " + json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
