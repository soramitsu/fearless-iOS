#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly MATERIALIZER="$SCRIPT_DIR/ci/materialize-embedded-framework-dsyms.sh"
readonly TEMPORARY_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-dsym-tests.XXXXXX")"

trap 'rm -rf "$TEMPORARY_DIR"' EXIT

fail() {
  printf '%s\n' "[embedded-framework-dsyms-test][error] $*" >&2
  exit 1
}

assert_uuid_match() {
  local binary="$1"
  local dsym="$2"
  local binary_uuids dsym_uuids

  binary_uuids="$(xcrun dwarfdump --uuid "$binary" | awk '$1 == "UUID:" { print $2, $3 }' | sort)"
  dsym_uuids="$(xcrun dwarfdump --uuid "$dsym" | awk '$1 == "UUID:" { print $2, $3 }' | sort)"
  [[ -n "$binary_uuids" && "$binary_uuids" == "$dsym_uuids" ]] ||
    fail "UUID inventory does not match for $(basename "$binary")"
}

make_archive() {
  local label="$1"
  local archive="$TEMPORARY_DIR/$label/fearless.xcarchive"
  local app="$archive/Products/Applications/fearless.app"
  local framework_name

  mkdir -p "$app/Frameworks" "$archive/dSYMs"
  for framework_name in MPQRCoreSDK blake2lib libed25519 sr25519lib; do
    mkdir -p "$app/Frameworks/$framework_name.framework"
    printf 'int %s_test_symbol(void) { return 1; }\n' "$framework_name" \
      >"$TEMPORARY_DIR/$framework_name.c"
    # Mirror the shipped inputs: the vendor/stub executables contain UUIDs but
    # no source-line DWARF for dsymutil to recover.
    xcrun clang -c "$TEMPORARY_DIR/$framework_name.c" \
      -o "$TEMPORARY_DIR/$framework_name.o"
    xcrun clang -dynamiclib "$TEMPORARY_DIR/$framework_name.o" \
      -o "$app/Frameworks/$framework_name.framework/$framework_name"
  done
  printf '%s\n' "$archive"
}

canonical="$(make_archive canonical)"
bash "$MATERIALIZER" "$canonical"
for framework_name in MPQRCoreSDK blake2lib libed25519 sr25519lib; do
  assert_uuid_match \
    "$canonical/Products/Applications/fearless.app/Frameworks/$framework_name.framework/$framework_name" \
    "$canonical/dSYMs/$framework_name.framework.dSYM"
done
bash "$MATERIALIZER" "$canonical"
printf '%s\n' "[embedded-framework-dsyms-test] PASS: materialization and idempotent verification"

missing_framework="$(make_archive missing-framework)"
rm -r "$missing_framework/Products/Applications/fearless.app/Frameworks/sr25519lib.framework"
if bash "$MATERIALIZER" "$missing_framework" \
  >"$TEMPORARY_DIR/missing.stdout" 2>"$TEMPORARY_DIR/missing.stderr"; then
  fail "missing framework unexpectedly passed"
fi
grep -Fq 'required embedded framework is missing' "$TEMPORARY_DIR/missing.stderr" ||
  fail "missing framework rejection was not explicit"
printf '%s\n' "[embedded-framework-dsyms-test] PASS (rejected): missing framework"

mismatched="$(make_archive mismatched)"
bash "$MATERIALIZER" "$mismatched"
cp \
  "$mismatched/dSYMs/blake2lib.framework.dSYM/Contents/Resources/DWARF/blake2lib" \
  "$mismatched/dSYMs/sr25519lib.framework.dSYM/Contents/Resources/DWARF/sr25519lib"
if bash "$MATERIALIZER" "$mismatched" \
  >"$TEMPORARY_DIR/mismatch.stdout" 2>"$TEMPORARY_DIR/mismatch.stderr"; then
  fail "mismatched dSYM unexpectedly passed"
fi
grep -Fq 'existing dSYM UUIDs do not match sr25519lib' "$TEMPORARY_DIR/mismatch.stderr" ||
  fail "mismatched dSYM rejection was not explicit"
printf '%s\n' "[embedded-framework-dsyms-test] PASS (rejected): mismatched UUID"

if FEARLESS_DSYM_DSYMUTIL_BIN=/usr/bin/false \
  bash "$MATERIALIZER" --help \
  >"$TEMPORARY_DIR/override.stdout" 2>"$TEMPORARY_DIR/override.stderr"; then
  fail "tool override without harness unexpectedly passed"
fi
grep -Fq 'only in the explicit test harness' "$TEMPORARY_DIR/override.stderr" ||
  fail "tool override rejection was not explicit"
printf '%s\n' "[embedded-framework-dsyms-test] PASS (rejected): unsafe tool override"
