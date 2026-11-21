#!/usr/bin/env python3
"""Check the vendored host tool sources and the local release build receipt."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile

PRODUCTS = ("rswift", "swiftformat")
DEPENDENCIES = {"rswift", "swiftformat", "Commander", "XcodeEdit"}
BOOTSTRAP = "scripts/deps/build-tools-from-source.sh"


def object_hash(kind, data):
    header = kind + b" " + str(len(data)).encode() + b"\0"
    return hashlib.sha1(header + data).digest()


def git_object_id(path, omitted=None, relative=""):
    """Hash the on-disk bytes and modes using Git's blob and tree encoding."""
    mode = path.lstat().st_mode
    if stat.S_ISDIR(mode):
        entries = []
        # Recreate the upstream tree using Git's metadata for unvendored siblings.
        for record in (omitted or {}).get(relative, []):
            metadata, filename = record.split("\t")
            git_mode, kind, oid = metadata.split()
            name = os.fsencode(filename)
            entry = git_mode.lstrip("0").encode() + b" " + name + b"\0" + bytes.fromhex(oid)
            entries.append((name + (b"/" if kind == "tree" else b""), entry))
        for child in path.iterdir():
            child_mode = child.lstat().st_mode
            name = os.fsencode(child.name)
            directory = stat.S_ISDIR(child_mode)
            git_mode = b"40000" if directory else b"100755" if child_mode & 0o111 else b"100644"
            child_id = git_object_id(child, omitted, str(Path(relative) / child.name))
            entry = git_mode + b" " + name + b"\0" + child_id
            entries.append((name + (b"/" if directory else b""), entry))
        kind, data = b"tree", b"".join(entry for _, entry in sorted(entries))
    elif stat.S_ISREG(mode):
        kind, data = b"blob", path.read_bytes()
    else:
        raise ValueError("unexpected file type in " + str(path))
    return object_hash(kind, data)


def source_inputs(package):
    pins = (package / "sources.json").read_bytes()
    sources = json.loads(pins)
    if set(sources) != DEPENDENCIES:
        raise ValueError("incomplete source pins")
    for name, pin in sources.items():
        vendor = package / "Vendor" / name
        proof = json.loads((package / "Provenance" / (name + ".json")).read_bytes())
        commit = proof["commit"].encode()
        if object_hash(b"commit", commit).hex() != pin["revision"]:
            raise ValueError(name + " revision differs from the upstream commit")
        tree = git_object_id(vendor, proof["omitted"]).hex()
        if commit.splitlines()[0] != ("tree " + tree).encode() or git_object_id(vendor).hex() != pin["tree"]:
            raise ValueError(name + " sources differ from " + pin["revision"])
    return {
        "pins": hashlib.sha256(pins).hexdigest(),
        "manifest": hashlib.sha256((package / "Package.swift").read_bytes()).hexdigest(),
        "builder": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "compiler": subprocess.check_output(
            ["xcrun", "--sdk", "macosx", "swiftc", "--version"], text=True, stderr=subprocess.STDOUT
        ).strip(),
    }


def product_digests(directory):
    hashes = {}
    for name in PRODUCTS:
        path = directory / name
        if path.is_symlink() or not path.is_file() or not os.access(path, os.X_OK):
            raise ValueError("missing executable " + name)
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return hashes


def verify_products(directory, inputs):
    receipt_file = directory / "receipt.json"
    if receipt_file.resolve() != receipt_file:
        raise ValueError("symlink in the local tool output path")
    receipt = json.loads(receipt_file.read_bytes())
    if receipt != {"inputs": inputs, "products": product_digests(directory)}:
        raise ValueError("local build receipt differs from the sources or executables")


def build(root, force):
    package = root / "BuildTools"
    output = root / "build/source-tools"
    destination = output / "bin"
    if destination.resolve() != destination or (output / "build.lock").is_symlink():
        raise ValueError("symlink in the local tool output path")
    output.mkdir(parents=True, exist_ok=True)
    with (output / "build.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        inputs = source_inputs(package)
        if not force:
            try:
                verify_products(destination, inputs)
            except (OSError, ValueError):
                pass
            else:
                print("[build-tools] verified existing release executables")
                return

        # Build only verified inputs, without a pre-existing SwiftPM manifest or object cache.
        with tempfile.TemporaryDirectory(dir=output) as tmp:
            stage = Path(tmp)
            for file in ("Package.swift", "sources.json"):
                shutil.copyfile(package / file, stage / file)
            shutil.copytree(package / "Provenance", stage / "Provenance")
            for name in DEPENDENCIES:
                shutil.copytree(package / "Vendor" / name, stage / "Vendor" / name, symlinks=True)
            if source_inputs(stage) != inputs:
                raise ValueError("sources changed while preparing the build")
            command = ["xcrun", "--sdk", "macosx", "swift", "build", "--package-path", tmp, "-c", "release"]
            subprocess.run(command, check=True)
            products = Path(subprocess.check_output(command + ["--show-bin-path"], text=True).strip())
            receipt = {"inputs": inputs, "products": product_digests(products)}
            (stage / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
            destination.mkdir(exist_ok=True)
            for name in PRODUCTS:
                os.replace(products / name, destination / name)
            os.replace(stage / "receipt.json", destination / "receipt.json")
            verify_products(destination, source_inputs(package))
        print("[build-tools] installed verified release executables")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--build", action="store_true", help="compile missing or stale products")
    parser.add_argument("--force", action="store_true", help="build from source even if the local receipt matches")
    args = parser.parse_args()
    if args.force and not args.build:
        parser.error("--force requires --build")
    root = args.root.resolve()
    try:
        if args.build:
            build(root, args.force)
        else:
            verify_products(root / "build/source-tools/bin", source_inputs(root / "BuildTools"))
            print("[build-tools] verified vendored sources and release executables")
    except (OSError, ValueError, KeyError, TypeError, IndexError, subprocess.CalledProcessError) as error:
        print("error: %s; restore pinned sources if changed and run %s" % (error, BOOTSTRAP), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
