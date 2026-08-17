#!/usr/bin/env bash
set -euo pipefail

# Xcode replaces static-library framework executables with generated codeless
# stubs when it embeds SwiftPM binary targets. It does not generate dSYMs for
# those stubs. MPQRCoreSDK is a stripped vendor framework without a bundled
# dSYM. Derive UUID-bound symbol bundles from the exact archived executables
# and require exact UUID parity before allowing the archive to continue to the
# release audit.
#
# The generated MPQRCoreSDK bundle satisfies App Store Connect's UUID lookup,
# but cannot recreate source-line DWARF that the upstream binary never shipped.
# Do not describe this operation as complete source-level symbolication.

umask 077

readonly LOG_PREFIX="[embedded-framework-dsyms]"
readonly TEST_HARNESS="${FEARLESS_DSYM_TEST_HARNESS:-0}"
readonly REQUIRED_FRAMEWORKS=(
  MPQRCoreSDK
  blake2lib
  libed25519
  sr25519lib
)

fail() {
  printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/ci/materialize-embedded-framework-dsyms.sh \
    /absolute/path/to/fearless.xcarchive

The command modifies only the archive's dSYMs directory. It never changes the
signed application or any embedded framework executable.
USAGE
}

require_executable() {
  local executable="$1"
  local label="$2"

  if [[ "$executable" == */* ]]; then
    [[ -x "$executable" ]] || fail "$label is not executable"
  else
    command -v "$executable" >/dev/null 2>&1 || fail "$label is unavailable"
  fi
}

if [[ "$TEST_HARNESS" != "1" ]]; then
  for override_name in \
    FEARLESS_DSYM_DSYMUTIL_BIN \
    FEARLESS_DSYM_DWARFDUMP_BIN; do
    [[ -z "${!override_name:-}" ]] ||
      fail "$override_name is accepted only in the explicit test harness"
  done
fi

if [[ "$#" == "1" && ( "$1" == "--help" || "$1" == "-h" ) ]]; then
  usage
  exit 0
fi
[[ "$#" == "1" ]] || fail "exactly one .xcarchive path is required"

readonly DSYMUTIL_BIN="${FEARLESS_DSYM_DSYMUTIL_BIN:-$(xcrun --find dsymutil 2>/dev/null || true)}"
readonly DWARFDUMP_BIN="${FEARLESS_DSYM_DWARFDUMP_BIN:-$(xcrun --find dwarfdump 2>/dev/null || true)}"
require_executable "$DSYMUTIL_BIN" "dsymutil"
require_executable "$DWARFDUMP_BIN" "dwarfdump"

archive="$1"
[[ "$archive" == /* && "$archive" == *.xcarchive ]] ||
  fail "archive must be an absolute .xcarchive path"
[[ -d "$archive" && ! -L "$archive" ]] ||
  fail "archive must be a real, non-symlink directory"
archive="$(cd "$archive" && pwd -P)"
readonly archive

readonly APPLICATIONS_DIR="$archive/Products/Applications"
readonly DSYMS_DIR="$archive/dSYMs"
[[ -d "$APPLICATIONS_DIR" && ! -L "$APPLICATIONS_DIR" ]] ||
  fail "archive Applications directory is missing or unsafe"
[[ -d "$DSYMS_DIR" && ! -L "$DSYMS_DIR" ]] ||
  fail "archive dSYMs directory is missing or unsafe"

app_inventory="$({
  find "$APPLICATIONS_DIR" -mindepth 1 -maxdepth 1 \
    -type d -name '*.app' -print
} | sort)"
app_count="$(printf '%s\n' "$app_inventory" | awk 'NF { count += 1 } END { print count + 0 }')"
[[ "$app_count" == "1" ]] || fail "archive must contain exactly one application"
readonly APP_PATH="$app_inventory"
readonly FRAMEWORKS_DIR="$APP_PATH/Frameworks"
[[ -d "$FRAMEWORKS_DIR" && ! -L "$FRAMEWORKS_DIR" ]] ||
  fail "archived application Frameworks directory is missing or unsafe"

uuid_inventory() {
  local artifact="$1"
  local output inventory count

  output="$($DWARFDUMP_BIN --uuid "$artifact" 2>/dev/null)" || return 1
  inventory="$(printf '%s\n' "$output" | awk '
    $1 == "UUID:" && $2 ~ /^[0-9A-Fa-f-]{36}$/ && $3 ~ /^\([A-Za-z0-9_]+\)$/ {
      uuid = toupper($2)
      arch = $3
      gsub(/[()]/, "", arch)
      print uuid " " arch
    }
  ' | LC_ALL=C sort -u)"
  count="$(printf '%s\n' "$inventory" | awk 'NF { count += 1 } END { print count + 0 }')"
  [[ "$count" -gt 0 ]] || return 1
  printf '%s\n' "$inventory"
}

pending_paths=()
cleanup() {
  local path
  for path in "${pending_paths[@]}"; do
    [[ "$path" == "$DSYMS_DIR"/.fearless-dsym-pending-* ]] || continue
    [[ ! -e "$path" && ! -L "$path" ]] || rm -rf -- "$path"
  done
}
trap cleanup EXIT INT TERM

for framework_name in "${REQUIRED_FRAMEWORKS[@]}"; do
  framework="$FRAMEWORKS_DIR/$framework_name.framework"
  binary="$framework/$framework_name"
  destination="$DSYMS_DIR/$framework_name.framework.dSYM"

  [[ -d "$framework" && ! -L "$framework" ]] ||
    fail "required embedded framework is missing or unsafe: $framework_name"
  [[ -f "$binary" && ! -L "$binary" ]] ||
    fail "required embedded framework executable is missing or unsafe: $framework_name"

  binary_uuids="$(uuid_inventory "$binary")" ||
    fail "could not read executable UUIDs for $framework_name"

  if [[ -e "$destination" || -L "$destination" ]]; then
    [[ -d "$destination" && ! -L "$destination" ]] ||
      fail "existing dSYM is unsafe: $framework_name"
    dsym_uuids="$(uuid_inventory "$destination")" ||
      fail "could not read existing dSYM UUIDs for $framework_name"
    [[ "$dsym_uuids" == "$binary_uuids" ]] ||
      fail "existing dSYM UUIDs do not match $framework_name"
    continue
  fi

  pending="$DSYMS_DIR/.fearless-dsym-pending-${framework_name}.$$.dSYM"
  [[ ! -e "$pending" && ! -L "$pending" ]] ||
    fail "private pending dSYM path already exists"
  pending_paths+=("$pending")

  if ! dsymutil_output="$("$DSYMUTIL_BIN" "$binary" -o "$pending" 2>&1)"; then
    [[ -z "$dsymutil_output" ]] || printf '%s\n' "$dsymutil_output" >&2
    fail "dsymutil failed for $framework_name"
  fi
  [[ -d "$pending" && ! -L "$pending" ]] ||
    fail "dsymutil produced an unsafe bundle for $framework_name"
  dsym_uuids="$(uuid_inventory "$pending")" ||
    fail "could not read generated dSYM UUIDs for $framework_name"
  [[ "$dsym_uuids" == "$binary_uuids" ]] ||
    fail "generated dSYM UUIDs do not match $framework_name"

  mv "$pending" "$destination"
done

pending_paths=()
trap - EXIT INT TERM

printf '%s\n' \
  "$LOG_PREFIX PASS: exact-UUID upload dSYMs exist for MPQRCoreSDK and all three Xcode-generated crypto stubs" \
  "$LOG_PREFIX NOTE: MPQRCoreSDK source-line DWARF remains unavailable in the upstream vendor binary"
