#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
IPA_PATH="${IPA_PATH:-$ROOT/build/fearless-debugging-script-export/fearless.ipa}"
BUNDLE_ID="${BUNDLE_ID:-jp.co.soramitsu.fearlesswallet.dev}"
DEVICE_ID="${DEVICE_ID:-}"
LAUNCH_APP="${LAUNCH_APP:-1}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"

usage() {
  cat <<EOF
Usage:
  DEVICE_ID=<device udid|serial|name> IPA_PATH=<path/to/app.ipa> $0

Defaults:
  IPA_PATH=$IPA_PATH
  BUNDLE_ID=$BUNDLE_ID
  LAUNCH_APP=$LAUNCH_APP

Set LAUNCH_APP=0 to install without launching.
EOF
}

fail() {
  echo "[install-ipa] ERROR: $*" >&2
  exit 1
}

TEMP_PATHS=()

register_temp_path() {
  TEMP_PATHS+=("$1")
}

cleanup_temp_paths() {
  local path

  if ((${#TEMP_PATHS[@]})); then
    for path in "${TEMP_PATHS[@]}"; do
      [[ -n "$path" ]] && rm -rf "$path"
    done
  fi
}

trap cleanup_temp_paths EXIT

extract_json_value() {
  local json_path="$1"
  local key_path="$2"

  plutil -extract "$key_path" raw -o - "$json_path" 2>/dev/null || true
}

resolve_single_device_id() {
  PRINT_RESOLVED_DEVICE_ID=1 TIMEOUT_SECONDS="$TIMEOUT_SECONDS" scripts/ci/check-device-ready.sh
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

[[ -f "$IPA_PATH" ]] || fail "IPA not found: $IPA_PATH"

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(resolve_single_device_id)"
fi

package_dir="$(mktemp -d)"
register_temp_path "$package_dir"

if ! unzip -q "$IPA_PATH" -d "$package_dir"; then
  fail "Could not unzip IPA: $IPA_PATH"
fi

app_count="$(find "$package_dir/Payload" -maxdepth 1 -name '*.app' -type d -print 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$app_count" == "1" ]] || fail "Expected exactly one Payload/*.app in $IPA_PATH, found $app_count."

app_path="$(find "$package_dir/Payload" -maxdepth 1 -name '*.app' -type d -print -quit)"
info_plist="$app_path/Info.plist"
[[ -f "$info_plist" ]] || fail "App bundle is missing Info.plist: $app_path"

actual_bundle_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null || true)"
[[ "$actual_bundle_id" == "$BUNDLE_ID" ]] ||
  fail "IPA bundle id is '$actual_bundle_id', expected '$BUNDLE_ID'."

codesign --verify --strict --verbose=2 "$app_path"

install_json="$(mktemp)"
install_log="$(mktemp)"
register_temp_path "$install_json"
register_temp_path "$install_log"

echo "[install-ipa] Installing $IPA_PATH on device '$DEVICE_ID'"
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  --timeout "$TIMEOUT_SECONDS" \
  --json-output "$install_json" \
  --log-output "$install_log" \
  "$app_path"

if [[ "$LAUNCH_APP" == "1" ]]; then
  launch_json="$(mktemp)"
  launch_log="$(mktemp)"
  register_temp_path "$launch_json"
  register_temp_path "$launch_log"

  echo "[install-ipa] Launching $BUNDLE_ID on device '$DEVICE_ID'"
  xcrun devicectl device process launch \
    --device "$DEVICE_ID" \
    --terminate-existing \
    --timeout "$TIMEOUT_SECONDS" \
    --json-output "$launch_json" \
    --log-output "$launch_log" \
    "$BUNDLE_ID"
fi

echo "[install-ipa] Installed $BUNDLE_ID on device '$DEVICE_ID'"
