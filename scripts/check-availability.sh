#!/usr/bin/env bash
set -euo pipefail

# Checks for iOS API availability issues by building the app target with the current
# minimum deployment target and surfacing any "only available in iOS X" diagnostics.
#
# Usage:
#   scripts/check-availability.sh [SCHEME] [WORKSPACE] [DESTINATION]
# Defaults:
#   SCHEME=fearless
#   WORKSPACE=fearless.xcworkspace
#   DESTINATION=${AVAILABILITY_DESTINATION:-generic/platform=iOS Simulator}
# Compilation needs an SDK, not a booted or registered simulator.

SCHEME="${1:-fearless}"
WORKSPACE="${2:-fearless.xcworkspace}"
DEST="${3:-${AVAILABILITY_DESTINATION:-generic/platform=iOS Simulator}}"

echo "==> Availability check: scheme=${SCHEME} dest=${DEST}"
mkdir -p build
set +e
xcodebuild \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -destination "${DEST}" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  clean build 2>&1 | tee build/availability.raw.log
statuses=("${PIPESTATUS[@]}")
set -e

# Scan for common availability diagnostics
availability_rc=0
if grep -E "is only available in iOS [0-9]+\.[0-9]+ or newer" build/availability.raw.log >/dev/null 2>&1; then
  printf '\n[availability] Potential availability violations detected:\n' >&2
  grep -nE "is only available in iOS [0-9]+\.[0-9]+ or newer" build/availability.raw.log | head -n 100 >&2 || true
  availability_rc=2
fi

# Keep the compiler's failure status even when it also reports availability errors.
if (( statuses[0] != 0 )); then
  printf '[availability] Build failed (exit %s).\n' "${statuses[0]}" >&2
  exit "${statuses[0]}"
fi
if (( statuses[1] != 0 )); then
  printf '[availability] Could not retain the build log (exit %s).\n' "${statuses[1]}" >&2
  exit "${statuses[1]}"
fi
(( availability_rc == 0 )) || exit "$availability_rc"

echo "==> Availability check passed"
