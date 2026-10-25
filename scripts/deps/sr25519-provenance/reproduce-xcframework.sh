#!/bin/bash
# Rebuild sr25519lib.xcframework from the Rust source checked in at a shared-features-spm
# revision and compare the two executable archives with the ones committed there.
#
# usage: reproduce-xcframework.sh <shared-features-spm git dir> <empty work dir> [revision]
#
# The tree is exported with `git archive`, so the build never touches the checkout. The
# package's own scripts/build-sr25519-xcframework.py does the build; this script only
# chooses the environment. Set extra Cargo/rustup variables in the environment to try a
# variant, for example CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 (see
# docs/sr25519-native-provenance.md for what reproduces the 4323032 binaries).
#
# Exit status: 0 when both archives are byte-identical to the committed ones, 1 when they
# differ (a member-level comparison is written to <work dir>/compare), 2 on usage errors.
set -euo pipefail

if [ $# -lt 2 ]; then
    sed -n '2,15p' "$0" >&2
    exit 2
fi

REPOSITORY="$1"
WORK="$2"
REVISION="${3:-4323032511ee788b178aa3f9ed05e2518ee21c74}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK=Binaries/sr25519lib.xcframework
DEVICE=ios-arm64/sr25519lib.framework/sr25519lib
SIMULATOR=ios-arm64_x86_64-simulator/sr25519lib.framework/sr25519lib

if [ -e "$WORK" ] && [ -n "$(ls -A "$WORK")" ]; then
    echo "work dir $WORK is not empty" >&2
    exit 2
fi
mkdir -p "$WORK/source" "$WORK/committed" "$WORK/compare"

git -C "$REPOSITORY" archive "$REVISION" native scripts "$FRAMEWORK" | tar -x -C "$WORK/source"
git -C "$REPOSITORY" archive "$REVISION" "$FRAMEWORK" | tar -x -C "$WORK/committed"

{
    echo "revision $REVISION"
    echo "date $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host $(sw_vers -productName) $(sw_vers -productVersion) $(uname -m)"
    echo "xcode $(xcodebuild -version | tr '\n' ' ')"
    echo "developer_dir $(xcode-select -p)"
    echo "rustup $(rustup --version 2>/dev/null | head -1)"
    (cd "$WORK/source/native/sr25519crust" && echo "rustc $(rustc --version)" && echo "cargo $(cargo --version)")
    env | grep -E '^(CARGO_|RUSTUP_TOOLCHAIN|RUSTFLAGS|SOURCE_DATE_EPOCH|ZERO_AR_DATE)' | sort | sed 's/^/env /' || true
} > "$WORK/environment.txt"

(
    cd "$WORK/source"
    CARGO_TARGET_DIR="$WORK/target" python3 scripts/build-sr25519-xcframework.py
) > "$WORK/build.log" 2>&1

status=0
for slice in "$DEVICE" "$SIMULATOR"; do
    built="$WORK/source/$FRAMEWORK/$slice"
    committed="$WORK/committed/$FRAMEWORK/$slice"
    name="$(echo "$slice" | cut -d/ -f1)"
    built_sha="$(shasum -a 256 "$built" | cut -d' ' -f1)"
    committed_sha="$(shasum -a 256 "$committed" | cut -d' ' -f1)"
    if [ "$built_sha" = "$committed_sha" ]; then
        echo "$name identical $built_sha"
    else
        echo "$name DIFFERS built $built_sha committed $committed_sha"
        python3 -I "$HERE/ar_members.py" "$built" > "$WORK/compare/$name.built.tsv"
        python3 -I "$HERE/ar_members.py" "$committed" > "$WORK/compare/$name.committed.tsv"
        diff "$WORK/compare/$name.committed.tsv" "$WORK/compare/$name.built.tsv" \
            > "$WORK/compare/$name.diff" || true
        echo "  $(grep -c '^<' "$WORK/compare/$name.diff" || true) committed members not reproduced;" \
             "see $WORK/compare/$name.diff"
        status=1
    fi
done | tee "$WORK/result.txt"

(cd "$WORK/committed/$FRAMEWORK" && find . -type f | sort | xargs shasum -a 256) > "$WORK/compare/committed-files.txt"
(cd "$WORK/source/$FRAMEWORK" && find . -type f | sort | xargs shasum -a 256) > "$WORK/compare/built-files.txt"
if cmp -s "$WORK/compare/committed-files.txt" "$WORK/compare/built-files.txt"; then
    echo "every file in the xcframework identical ($(wc -l < "$WORK/compare/built-files.txt" | tr -d ' ') files)" \
        | tee -a "$WORK/result.txt"
else
    echo "xcframework files differ:" | tee -a "$WORK/result.txt"
    diff "$WORK/compare/committed-files.txt" "$WORK/compare/built-files.txt" | tee -a "$WORK/result.txt" || true
fi

grep -q -E 'DIFFERS|files differ' "$WORK/result.txt" && status=1
exit $status
