#!/usr/bin/env bash
set -euo pipefail

# Selects a concrete iOS simulator UDID suitable for xcodebuild test.
# If no available iPhone simulator exists and ALLOW_CREATE=1 (default),
# attempts to create one from an available iOS runtime/device type.
#
# Output:
#   Prints simulator UDID to stdout on success.
#
# Env:
#   PREFERRED_NAME  Preferred device name pattern (default: iPhone 16)
#   ALLOW_CREATE    1 to create when missing, 0 to disable (default: 1)
#   BOOT_SIMULATOR  1 to boot selected simulator, 0 to skip (default: 0)
#   LOG_PREFIX      Prefix for log lines (default: [select-simulator])

PREFERRED_NAME="${PREFERRED_NAME:-iPhone 16}"
ALLOW_CREATE="${ALLOW_CREATE:-1}"
BOOT_SIMULATOR="${BOOT_SIMULATOR:-0}"
LOG_PREFIX="${LOG_PREFIX:-[select-simulator]}"

log() {
  echo "${LOG_PREFIX} $*" >&2
}

pick_udid_by_pattern() {
  local pattern="$1"
  xcrun simctl list devices available | awk -v pattern="$pattern" '
    $0 ~ pattern {
      if (match($0, /[A-Fa-f0-9-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

pick_udid_by_exact_name() {
  local target_name="$1"
  xcrun simctl list devices available | awk -v target="$target_name" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    {
      if (match($0, /\([A-Fa-f0-9-]{36}\)/)) {
        udid = substr($0, RSTART + 1, RLENGTH - 2)
        name = substr($0, 1, RSTART - 1)
        name = trim(name)
        if (name == target) {
          print udid
          exit
        }
      }
    }
  '
}

pick_any_iphone_udid() {
  pick_udid_by_pattern "iPhone"
}

find_latest_ios_runtime() {
  xcrun simctl list runtimes available | awk '
    function version_key(runtime_id,    version, parts, n, i, key) {
      version = runtime_id
      sub(/^.*SimRuntime\.iOS-/, "", version)
      n = split(version, parts, /-/)
      key = ""
      for (i = 1; i <= 4; i++) {
        key = key sprintf("%06d", (i <= n ? parts[i] + 0 : 0))
      }
      return key
    }
    /iOS/ && /com\.apple\.CoreSimulator\.SimRuntime\.iOS-/ {
      if (match($0, /com\.apple\.CoreSimulator\.SimRuntime\.iOS-[A-Za-z0-9-]+/)) {
        id = substr($0, RSTART, RLENGTH)
        key = version_key(id)
        if (best == "" || key > best_key) {
          best = id
          best_key = key
        }
      }
    }
    END {
      if (best != "") print best
    }
  '
}

pick_preferred_device_type() {
  local preferred=(
    "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"
    "com.apple.CoreSimulator.SimDeviceType.iPhone-16"
    "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
    "com.apple.CoreSimulator.SimDeviceType.iPhone-15"
    "com.apple.CoreSimulator.SimDeviceType.iPhone-14-Pro"
    "com.apple.CoreSimulator.SimDeviceType.iPhone-14"
  )

  local list
  list="$(xcrun simctl list devicetypes)"
  local type
  for type in "${preferred[@]}"; do
    if printf '%s\n' "$list" | grep -Fq "$type"; then
      echo "$type"
      return 0
    fi
  done

  printf '%s\n' "$list" | awk '
    /com\.apple\.CoreSimulator\.SimDeviceType\.iPhone-/ {
      if (match($0, /com\.apple\.CoreSimulator\.SimDeviceType\.iPhone-[A-Za-z0-9-]+/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

create_iphone_simulator() {
  local runtime_id="$1"
  local device_type="$2"
  local device_name="${3:-Codex CI iPhone}"
  xcrun simctl create "$device_name" "$device_type" "$runtime_id"
}

boot_if_needed() {
  local udid="$1"
  if [[ "$BOOT_SIMULATOR" == "1" ]]; then
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  fi
}

main() {
  local udid

  log "Searching for available simulator (preferred: ${PREFERRED_NAME})"
  udid="$(pick_udid_by_exact_name "$PREFERRED_NAME" || true)"
  if [[ -z "$udid" ]]; then
    udid="$(pick_udid_by_pattern "$PREFERRED_NAME" || true)"
  fi
  if [[ -z "$udid" ]]; then
    udid="$(pick_any_iphone_udid || true)"
  fi

  if [[ -z "$udid" && "$ALLOW_CREATE" == "1" ]]; then
    local runtime_id
    local device_type
    runtime_id="$(find_latest_ios_runtime || true)"
    device_type="$(pick_preferred_device_type || true)"

    if [[ -n "$runtime_id" && -n "$device_type" ]]; then
      log "No available iPhone simulator found. Creating one with ${device_type} on ${runtime_id}"
      udid="$(create_iphone_simulator "$runtime_id" "$device_type" "Codex CI iPhone" || true)"
    fi
  fi

  if [[ -z "$udid" ]]; then
    log "ERROR: failed to locate or create a concrete iPhone simulator" >&2
    exit 1
  fi

  boot_if_needed "$udid"
  echo "$udid"
}

main "$@"
