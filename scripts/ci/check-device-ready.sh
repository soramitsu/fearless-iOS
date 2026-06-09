#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${DEVICE_ID:-}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-30}"
PRINT_RESOLVED_DEVICE_ID="${PRINT_RESOLVED_DEVICE_ID:-0}"

fail() {
  echo "[device-ready] ERROR: $*" >&2
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

first_available_device_id() {
  local devices_json="$1"
  local candidate
  local key_path

  for key_path in \
    "result.devices.0.identifier" \
    "result.devices.0.identifier.identifier" \
    "result.devices.0.hardwareProperties.udid" \
    "result.devices.0.properties.udid" \
    "result.devices.0.deviceProperties.name" \
    "result.devices.0.name"; do
    candidate="$(extract_json_value "$devices_json" "$key_path")"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

devices_json="$(mktemp)"
register_temp_path "$devices_json"

if ! xcrun devicectl list devices --timeout "$TIMEOUT_SECONDS" --json-output "$devices_json" >/dev/null; then
  fail "Could not list devices with devicectl."
fi

device_count="$(extract_json_value "$devices_json" "result.devices")"
if [[ -z "$device_count" || "$device_count" == "0" ]]; then
  fail "No devices found. Connect and trust an iPhone, then rerun with DEVICE_ID=<device udid|serial|name>."
fi

if [[ -n "$DEVICE_ID" ]]; then
  echo "[device-ready] Device requested: $DEVICE_ID"
  exit 0
fi

if [[ "$device_count" != "1" ]]; then
  xcrun devicectl list devices || true
  fail "Found ${device_count} devices. Rerun with DEVICE_ID=<device udid|serial|name>."
fi

resolved_device_id="$(first_available_device_id "$devices_json" || true)"
if [[ -z "$resolved_device_id" ]]; then
  xcrun devicectl list devices --columns '*' || true
  fail "Found one device but could not parse its identifier from devicectl JSON. Rerun with DEVICE_ID=<device udid|serial|name>."
fi

if [[ "$PRINT_RESOLVED_DEVICE_ID" == "1" ]]; then
  printf '%s\n' "$resolved_device_id"
else
  echo "[device-ready] Device available: $resolved_device_id"
fi
