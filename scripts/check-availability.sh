#!/usr/bin/env bash
set -euo pipefail

# Checks for iOS API availability issues by building the app target with the current
# minimum deployment target and surfacing any "only available in iOS X" diagnostics.
#
# Usage:
#   scripts/check-availability.sh [SCHEME] [WORKSPACE]
# Defaults:
#   SCHEME=fearless
#   WORKSPACE=fearless.xcworkspace

SCHEME="${1:-fearless}"
WORKSPACE="${2:-fearless.xcworkspace}"

pick_latest_iphone() {
  local list
  list=$(xcrun simctl list devices available 2>/dev/null || xcrun simctl list devices 2>/dev/null || true)
  list=$(printf '%s\n' "$list" | grep -vi "unavailable" || true)
  for gen in $(seq 25 -1 8); do
    for variant in "iPhone ${gen}" "iPhone ${gen} Pro" "iPhone ${gen} Pro Max"; do
      if printf '%s\n' "$list" | grep -Fq "$variant"; then
        echo "$variant"
        return 0
      fi
    done
  done
  printf '%s\n' "$list" | grep -F "iPhone " | head -n1 | cut -d '(' -f1 | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' || true
}

pick_device_udid_by_name() {
  local name="$1"
  (xcrun simctl list devices available 2>/dev/null || xcrun simctl list devices 2>/dev/null || true) | awk -v n="$name" '
    index($0, n) > 0 {
      if (tolower($0) ~ /unavailable/) next
      if (match($0, /[A-Fa-f0-9-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

pick_any_iphone_udid() {
  (xcrun simctl list devices available 2>/dev/null || xcrun simctl list devices 2>/dev/null || true) | awk '
    /iPhone/ {
      if (tolower($0) ~ /unavailable/) next
      if (match($0, /[A-Fa-f0-9-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

DEST=""
DEV_NAME=$(pick_latest_iphone || true)
if [[ -n "${DEV_NAME:-}" ]]; then
  DEV_ID=$(pick_device_udid_by_name "${DEV_NAME}" || true)
fi
if [[ -z "${DEV_ID:-}" ]]; then
  DEV_ID=$(pick_any_iphone_udid || true)
fi
if [[ -n "${DEV_ID:-}" ]]; then
  DEST="platform=iOS Simulator,id=${DEV_ID}"
else
  echo "No concrete available iPhone simulator found for availability check." >&2
  exit 1
fi

echo "==> Availability check: scheme=${SCHEME} dest=${DEST}"
mkdir -p build || true
set +e
xcodebuild \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -destination "${DEST}" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  clean build | tee build/availability.raw.log
rc=$?
set -e

# Scan for common availability diagnostics
if grep -E "is only available in iOS [0-9]+\.[0-9]+ or newer" build/availability.raw.log >/dev/null 2>&1; then
  echo "\n[availability] Potential availability violations detected:" >&2
  grep -nE "is only available in iOS [0-9]+\.[0-9]+ or newer" build/availability.raw.log | head -n 100 >&2 || true
  exit 2
fi

echo "==> Availability check passed"
exit $rc
