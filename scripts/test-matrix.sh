#!/usr/bin/env bash
set -euo pipefail

# Runs unit and integration tests across Debug and Release configurations.
#
# Usage:
#   scripts/test-matrix.sh [SCHEME] [DESTINATION]
# Defaults:
#   SCHEME=fearless
#   DESTINATION="platform=iOS Simulator,name=Any iOS Simulator Device"

SCHEME="${1:-fearless}"
DEST="${2:-platform=iOS Simulator,name=Any iOS Simulator Device}"
WORKSPACE="fearless.xcworkspace"

echo "==> Using scheme: ${SCHEME}"
echo "==> Destination: ${DEST}"

# If destination is a placeholder, pick a concrete available simulator (preferring iPhone 17)
if [[ "$DEST" == *"Any iOS Simulator Device"* ]]; then
  echo "==> Autodetecting a concrete simulator device"
  if xcrun simctl list devices | grep -q "iPhone 17"; then
    DEV_NAME="iPhone 17"
  else
    DEV_NAME=$(xcrun simctl list devices | grep -E "^\s*iPhone .*\((Booted|Shutdown)\)" | head -n1 | sed -E 's/^\s*([^\(]+)\s*\(.*/\1/' || true)
  fi
  if [[ -n "${DEV_NAME:-}" ]]; then
    DEST="platform=iOS Simulator,name=${DEV_NAME}"
  else
    # Fallback: leave generic platform spec (build-only may work; tests might still need a device)
    DEST="generic/platform=iOS Simulator"
  fi
  echo "==> Using detected destination: ${DEST}"
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
