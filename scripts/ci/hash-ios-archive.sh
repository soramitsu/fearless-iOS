#!/usr/bin/env bash
set -euo pipefail

umask 077

[[ "$#" == "1" ]] || {
  printf '%s\n' "Usage: bash scripts/ci/hash-ios-archive.sh /absolute/path/to/archive.xcarchive" >&2
  exit 64
}

archive="$1"
[[ "$archive" == /* && "$archive" == *.xcarchive ]] || {
  printf '%s\n' "archive path must be an absolute .xcarchive path" >&2
  exit 64
}
[[ -d "$archive" && ! -L "$archive" ]] || {
  printf '%s\n' "archive path must be a real non-symlink directory" >&2
  exit 1
}

python3 - "$archive" <<'PY'
import hashlib
import os
import stat
import sys

root = os.path.realpath(sys.argv[1])
digest = hashlib.sha256()

def frame(value):
    digest.update(str(len(value)).encode("ascii"))
    digest.update(b":")
    digest.update(value)
    digest.update(b";")

for directory, names, filenames in os.walk(root, topdown=True, followlinks=False):
    names.sort()
    filenames.sort()
    relative_directory = os.path.relpath(directory, root)
    for name in names + filenames:
        path = os.path.join(directory, name)
        relative = os.path.normpath(os.path.join(relative_directory, name))
        if relative.startswith("../") or relative == "..":
            raise SystemExit(2)
        encoded_path = relative.encode("utf-8")
        metadata = os.lstat(path)
        if stat.S_ISDIR(metadata.st_mode):
            kind = b"d"
            payload = b""
        elif stat.S_ISREG(metadata.st_mode):
            kind = b"f"
            with open(path, "rb") as source:
                content_digest = hashlib.sha256()
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    content_digest.update(chunk)
            payload = content_digest.digest()
        elif stat.S_ISLNK(metadata.st_mode):
            kind = b"l"
            payload = os.readlink(path).encode("utf-8")
        else:
            raise SystemExit(3)
        frame(kind)
        frame(encoded_path)
        frame(oct(stat.S_IMODE(metadata.st_mode)).encode("ascii"))
        frame(payload)

print(digest.hexdigest())
PY
