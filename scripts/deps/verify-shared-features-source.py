#!/usr/bin/env python3
"""Read-only verification of the shared SDK and guarded transport used by the build."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

DELTA_IDS = {
    "web3-mirror-normalization", "ssfmodels-explicit-dependencies",
    "ssfpolkaswap-explicit-dependencies", "sorakeystore-runtime-namespace",
    "ethereum-private-key-data-array", "addressfactory-compatibility-cleanup",
    "scrypt-simulator-arch-guard", "native-crypto-sidecar-pruning",
    "ssfpools-public-initializers", "native-crypto-contract-reapply",
    "strict-required-patch-accounting",
}
RESOLVED_PATHS = [
    "fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    "fearless.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
]


def load_json(path):
    def unique_fields(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(f"Duplicate JSON field: {key}")
            value[key] = item
        return value
    return json.loads(path.read_text(), object_pairs_hook=unique_fields)


def git(checkout, *arguments):
    return subprocess.check_output(
        ["git", "--no-replace-objects", "-C", str(checkout), *arguments],
        stderr=subprocess.PIPE,
    )


def contract(root):
    value = load_json(root / "config/shared-features-source.json")
    if set(value) != {"schema", "repository", "revision", "tree", "baseRevision", "reviewUrl", "carriedDeltas"}:
        raise ValueError("Unexpected shared-features source contract fields")
    if value["schema"] != 1 or type(value["schema"]) is not int:
        raise ValueError("Unsupported shared-features source contract")
    for name in ["revision", "tree", "baseRevision"]:
        if not isinstance(value[name], str) or not re.fullmatch(r"[a-f0-9]{40}", value[name]):
            raise ValueError(f"Invalid source identity: {name}")
    if value["repository"] != "https://github.com/soramitsu/shared-features-spm.git":
        raise ValueError("Unexpected shared-features source repository")
    if not isinstance(value["reviewUrl"], str) or not re.fullmatch(r"https://github\.com/soramitsu/shared-features-spm/pull/[1-9][0-9]*", value["reviewUrl"]):
        raise ValueError("Invalid shared-features review URL")
    deltas = value["carriedDeltas"]
    if not isinstance(deltas, list) or len(deltas) != 11 or set(deltas) != DELTA_IDS:
        raise ValueError("Expected all eleven unique carried deltas")
    return value


def transport_contract(root):
    value = load_json(root / "config/starscream-source.json")
    if set(value) != {"schema", "repository", "revision", "tree", "baseRevision", "reviewUrl"}:
        raise ValueError("Unexpected Starscream source contract fields")
    if type(value["schema"]) is not int or value["schema"] != 1:
        raise ValueError("Unsupported Starscream source contract")
    for name in ["revision", "tree", "baseRevision"]:
        if not isinstance(value[name], str) or not re.fullmatch(r"[a-f0-9]{40}", value[name]):
            raise ValueError(f"Invalid transport identity: {name}")
    if value["repository"] != "https://github.com/soramitsu/fearless-starscream":
        raise ValueError("Unexpected Starscream source repository")
    if not isinstance(value["reviewUrl"], str) or not re.fullmatch(r"https://github\.com/soramitsu/fearless-starscream/pull/[1-9][0-9]*", value["reviewUrl"]):
        raise ValueError("Invalid transport review URL")
    return value


def verify_resolved_pins(root, identity, package_identity):
    for name in RESOLVED_PATHS:
        pins = load_json(root / name)["pins"]
        matches = [pin for pin in pins if pin["identity"] == package_identity]
        if len(matches) != 1:
            raise ValueError(f"Expected one {package_identity} pin in {name}")
        pin = matches[0]
        if pin.get("kind") != "remoteSourceControl" or pin["location"] != identity["repository"] or pin["state"] != {"revision": identity["revision"]}:
            raise ValueError(f"Mismatched {package_identity} pin in {name}")


def verify_pins(root, identity):
    verify_resolved_pins(root, identity, "shared-features-spm")
    package = (root / "Packages/FearlessUtilsCompat/Package.swift").read_text()
    references = re.findall(r'\.package\(url:\s*"https://github.com/soramitsu/shared-features-spm.git",\s*revision:\s*"([a-f0-9]+)"\)', package)
    if references != [identity["revision"]]:
        raise ValueError("FearlessUtilsCompat source pin mismatch")
    project = (root / "fearless.xcodeproj/project.pbxproj").read_text()
    references = re.findall(r'repositoryURL = "https://github.com/soramitsu/shared-features-spm.git";\s*requirement = \{\s*kind = revision;\s*revision = ([a-f0-9]+);\s*\};', project)
    if references != [identity["revision"]]:
        raise ValueError("Xcode project source pin mismatch")


def verify_checkout(checkout, identity):
    checkout = checkout.resolve(strict=True)
    if Path(os.fsdecode(git(checkout, "rev-parse", "--show-toplevel")).strip()).resolve() != checkout:
        raise ValueError("Dependency path is not its own Git checkout")
    for expression, expected in [("HEAD", identity["revision"]), ("HEAD^{tree}", identity["tree"])]:
        if git(checkout, "rev-parse", expression).decode().strip() != expected:
            raise ValueError(f"Dependency {expression} does not match the pinned source")
    if git(checkout, "diff", "--no-ext-diff", "--cached", "--name-only", "HEAD"):
        raise ValueError("Dependency index contains staged changes")
    entries = git(checkout, "ls-tree", "-rz", "--full-tree", "HEAD").split(b"\0")
    expected_paths = set()
    # Hash every tracked byte. Git status alone can miss assume-unchanged files,
    # changed stat caches and ignored Swift sources that SwiftPM still compiles.
    for entry in entries:
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, kind, expected_hash = metadata.split()
        name = os.fsdecode(raw_path)
        if kind != b"blob" or mode not in [b"100644", b"100755", b"120000"]:
            raise ValueError(f"Unsupported dependency entry: {name}")
        expected_paths.add(name)
        path = checkout / name
        information = path.lstat()
        if mode == b"120000":
            if not stat.S_ISLNK(information.st_mode) or not path.resolve().is_relative_to(checkout):
                raise ValueError(f"Invalid dependency symlink: {name}")
            data = os.fsencode(os.readlink(path))
        else:
            if not stat.S_ISREG(information.st_mode):
                raise ValueError(f"Dependency file type mismatch: {name}")
            if bool(information.st_mode & stat.S_IXUSR) != (mode == b"100755"):
                raise ValueError(f"Dependency executable mode mismatch: {name}")
            data = path.read_bytes()
        actual_hash = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        if actual_hash != expected_hash.decode():
            raise ValueError(f"Dependency contents differ from pinned source: {name}")
    actual_paths = set()
    for directory, directories, files in os.walk(checkout, followlinks=False):
        if Path(directory) == checkout:
            directories[:] = [name for name in directories if name != ".git"]
            files = [name for name in files if name != ".git"]
        for name in [*files, *[name for name in directories if (Path(directory) / name).is_symlink()]]:
            actual_paths.add(str((Path(directory) / name).relative_to(checkout)))
    if actual_paths != expected_paths:
        raise ValueError("Dependency contains missing or additional files: " + ", ".join(sorted(actual_paths ^ expected_paths)[:5]))
    return len(expected_paths)


def verify_dependency_graph(root, source_packages=None):
    identity = contract(root)
    transport = transport_contract(root)
    verify_pins(root, identity)
    verify_resolved_pins(root, transport, "fearless-starscream")
    counts = {}
    if source_packages is not None:
        shared_checkout = source_packages / "checkouts/shared-features-spm"
        counts["shared-features-spm"] = verify_checkout(shared_checkout, identity)
        counts["fearless-starscream"] = verify_checkout(source_packages / "checkouts/fearless-starscream", transport)
        package = (shared_checkout / "Package.swift").read_text()
        references = re.findall(r'\.package\(url:\s*"https://github.com/soramitsu/fearless-starscream",\s*\.revision\("([a-f0-9]+)"\)\)', package)
        if references != [transport["revision"]]:
            raise ValueError("Shared SDK guarded transport source pin mismatch")
    return {"sharedFeatures": identity, "transport": transport, "verifiedFileCounts": counts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path.cwd())
    parser.add_argument("--pins-only", action="store_true")
    args = parser.parse_args()
    try:
        directory = None if args.pins_only else Path(os.environ.get("SOURCE_PACKAGES_DIR", args.root / "SourcePackages"))
        result = verify_dependency_graph(args.root, directory)
        identity = result["sharedFeatures"]
        transport = result["transport"]
        if args.pins_only:
            print(f"[shared-features-source] Pins match SDK {identity['revision']} and transport {transport['revision']}")
        else:
            print(f"[shared-features-source] Verified SDK {identity['revision']} and transport {transport['revision']} ({sum(result['verifiedFileCounts'].values())} exact source files)")
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"[shared-features-source] Rejected: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
