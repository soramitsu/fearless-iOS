#!/usr/bin/env bash
set -euo pipefail

# Runs unit and integration tests across Debug and Release configurations.
#
# Usage:
#   scripts/test-matrix.sh [SCHEME] [DESTINATION]
# Defaults:
#   SCHEME=fearless.tests
#   DESTINATION="platform=iOS Simulator,name=Any iOS Simulator Device"

SCHEME="${1:-fearless.tests}"
DEST="${2:-platform=iOS Simulator,name=Any iOS Simulator Device}"
WORKSPACE="fearless.xcworkspace"

echo "==> Using scheme: ${SCHEME}"
echo "==> Destination: ${DEST}"

pick_latest_iphone_name() {
  # Try descending generations to prefer the most modern simulator present
  local list
  list=$(xcrun simctl list devices 2>/dev/null || true)
  for gen in $(seq 25 -1 8); do
    for variant in "iPhone ${gen}" "iPhone ${gen} Pro" "iPhone ${gen} Pro Max"; do
      if printf '%s\n' "$list" | grep -Fq "$variant"; then
        echo "$variant"
        return 0
      fi
    done
  done
  # Fallback: first available iPhone entry, if any
  printf '%s\n' "$list" | grep -F "iPhone " | head -n1 | cut -d '(' -f1 | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' || true
}

pick_device_udid_by_name() {
  local name="$1"
  # Extract the first UDID for a device line containing the provided name
  xcrun simctl list devices 2>/dev/null | awk -v n="$name" 'index($0,n)>0 { if (match($0, /\(([A-F0-9-]{36})\)/, m)) { print m[1]; exit } }'
}

# If destination is a placeholder, pick a concrete available simulator (prefer newest iPhone)
if [[ "$DEST" == *"Any iOS Simulator Device"* || "$DEST" == "" ]]; then
  echo "==> Autodetecting a concrete simulator device (latest iPhone if available)"
  DEV_NAME=$(pick_latest_iphone_name || true)
  if [[ -n "${DEV_NAME:-}" ]]; then
    DEV_ID=$(pick_device_udid_by_name "${DEV_NAME}" || true)
    if [[ -n "${DEV_ID:-}" ]]; then
      DEST="platform=iOS Simulator,id=${DEV_ID}"
    else
      DEST="platform=iOS Simulator,name=${DEV_NAME}"
    fi
  else
    DEST="generic/platform=iOS Simulator"
  fi
  echo "==> Using detected destination: ${DEST}"
fi

# Enforce SSF pin, then apply SPM hotfixes so SSF packages are stable under Xcode 16+
if [ -x "scripts/deps/enforce-ssf-pin.sh" ]; then
  echo "\n==> Enforcing shared-features-spm pinned revision"
  scripts/deps/enforce-ssf-pin.sh || true
fi

# Apply SPM IrohaCrypto hotfix so SSFModels can import IrohaCrypto under Xcode 16+
if [ -x "scripts/spm-iroha-hotfix.sh" ]; then
  echo "\n==> Applying SPM IrohaCrypto hotfix"
  scripts/spm-iroha-hotfix.sh "${SCHEME}" "${WORKSPACE}" || true
fi

# Patch shared-features-spm manifest and sources for missing SSFModels deps
if [ -x "scripts/spm-shared-features-fixes.sh" ]; then
  echo "\n==> Applying shared-features-spm fixes (SSFModels deps, Web3 API drift)"
  scripts/spm-shared-features-fixes.sh "$(pwd)" || true
fi

# Ensure SPM dependencies are re-resolved after patching Package.swift in checkouts
echo "\n==> Resolving Swift Package dependencies"
xcodebuild -resolvePackageDependencies -workspace "${WORKSPACE}" -scheme "${SCHEME}" || true

# Ensure Cuckoo mock generation build phases run even on CI
unset CI || true

function run_tests() {
  local config=$1
  echo "\n==> Running ${config} tests"
  local extra=()
  if [[ "${config}" == "Release" ]]; then
    # Ensure testability for Release builds when running unit tests on simulator
    extra+=(ENABLE_TESTABILITY=YES)
  fi
  if ((${#extra[@]})); then
    xcodebuild \
      -workspace "${WORKSPACE}" \
      -scheme "${SCHEME}" \
      -configuration "${config}" \
      -destination "${DEST}" \
      -enableCodeCoverage YES \
      "${extra[@]}" \
      clean test | xcpretty || {
        echo "xcodebuild ${config} tests failed" >&2
        exit 1
      }
  else
    xcodebuild \
      -workspace "${WORKSPACE}" \
      -scheme "${SCHEME}" \
      -configuration "${config}" \
      -destination "${DEST}" \
      -enableCodeCoverage YES \
      clean test | xcpretty || {
        echo "xcodebuild ${config} tests failed" >&2
        exit 1
      }
  fi
}

# Ensure tooling available
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found in PATH" >&2
  exit 127
fi

# xcpretty is optional; fall back to raw output
if ! command -v xcpretty >/dev/null 2>&1; then
  run_tests() {
    local config=$1
    echo "\n==> Running ${config} tests (no xcpretty)"
    local extra=()
    if [[ "${config}" == "Release" ]]; then
      extra+=(ENABLE_TESTABILITY=YES)
    fi
    if ((${#extra[@]})); then
      xcodebuild \
        -workspace "${WORKSPACE}" \
        -scheme "${SCHEME}" \
        -configuration "${config}" \
        -destination "${DEST}" \
        -enableCodeCoverage YES \
        "${extra[@]}" \
        clean test
    else
      xcodebuild \
        -workspace "${WORKSPACE}" \
        -scheme "${SCHEME}" \
        -configuration "${config}" \
        -destination "${DEST}" \
        -enableCodeCoverage YES \
        clean test
    fi
  }
fi

run_tests Debug
run_tests Release

echo "\n==> All tests passed in Debug and Release"
