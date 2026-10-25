#!/usr/bin/env python3
"""Reproduce or verify the vendored Ed25519 and BLAKE2 C sources from pinned upstream commits.

Without arguments, fetches every pinned upstream revision listed in
native/ed25519-blake2-sources.json and checks that each vendored file is
byte-identical to it, that each target directory holds exactly the listed
files, that every recorded SHA-256 still matches, and that the public headers
and the CMake export header equal those of the replaced frameworks in git
history. --write recreates the vendored upstream files instead of checking them.
"""

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "native" / "ed25519-blake2-sources.json"
TARGETS = [ROOT / "Sources" / "libed25519", ROOT / "Sources" / "blake2lib"]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fetch(repository, revision, cache):
    checkout = cache / revision
    if not checkout.exists():
        subprocess.run(["git", "init", "--quiet", str(checkout)], check=True)
        subprocess.run(["git", "-C", str(checkout), "fetch", "--quiet", "--depth", "1",
                        repository, revision], check=True)
    return checkout


def upstream_bytes(checkout, revision, path):
    return subprocess.run(["git", "-C", str(checkout), "show", f"{revision}:{path}"],
                          check=True, capture_output=True).stdout


def legacy_bytes(revision, path):
    if subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e", f"{revision}^{{commit}}"],
                      capture_output=True).returncode:
        subprocess.run(["git", "-C", str(ROOT), "fetch", "--quiet", "--depth", "1", "origin", revision],
                       check=True)
    return subprocess.run(["git", "-C", str(ROOT), "show", f"{revision}:{path}"],
                          check=True, capture_output=True).stdout


def expected_files(manifest):
    """Map each vendored path to the bytes' SHA-256 the manifest records for it."""
    expected = {}
    for source in manifest["sources"]:
        for path, digest in source["files"].items():
            expected[f"{source['destination']}/{path}"] = digest
    for group in ("generated", "legacyHeaders", "local"):
        for path, entry in manifest[group].items():
            expected[path] = entry["sha256"]
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true",
                        help="recreate vendored upstream files instead of verifying them")
    parser.add_argument("--cache", type=Path,
                        help="directory for upstream fetches (default: a temporary directory)")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    problems = []
    with tempfile.TemporaryDirectory(prefix="ed25519-blake2-upstream-") as temporary:
        cache = args.cache or Path(temporary)
        cache.mkdir(parents=True, exist_ok=True)
        for source in manifest["sources"]:
            checkout = fetch(source["repository"], source["revision"], cache)
            for path, digest in source["files"].items():
                data = upstream_bytes(checkout, source["revision"], path)
                if sha256(data) != digest:
                    problems.append(f"{source['repository']}@{source['revision']}:{path} "
                                    "does not match the recorded SHA-256")
                vendored = ROOT / source["destination"] / path
                if args.write:
                    vendored.parent.mkdir(parents=True, exist_ok=True)
                    vendored.write_bytes(data)
                elif not vendored.is_file() or vendored.read_bytes() != data:
                    problems.append(f"{vendored.relative_to(ROOT)} differs from "
                                    f"{source['repository']}@{source['revision']}:{path}")

    expected = expected_files(manifest)
    for path, digest in expected.items():
        file = ROOT / path
        if not file.is_file():
            problems.append(f"{path} is missing")
        elif sha256(file.read_bytes()) != digest:
            problems.append(f"{path} does not match the recorded SHA-256")
    for group in ("generated", "legacyHeaders"):
        for path, entry in manifest[group].items():
            if "legacy" in entry and (ROOT / path).is_file() and \
                    (ROOT / path).read_bytes() != legacy_bytes(manifest["legacyRevision"], entry["legacy"]):
                problems.append(f"{path} differs from {entry['legacy']} at {manifest['legacyRevision']}")
    present = {str(file.relative_to(ROOT)) for target in TARGETS
               for file in target.rglob("*") if file.is_file()}
    for path in sorted(present - set(expected)):
        problems.append(f"{path} is not recorded in {MANIFEST.relative_to(ROOT)}")

    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    print(f"{len(expected)} Ed25519/BLAKE2 source files match their pinned upstream revisions "
          "and recorded hashes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
