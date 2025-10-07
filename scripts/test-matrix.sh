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

# Apply SPM IrohaCrypto hotfix so SSFModels can import IrohaCrypto under Xcode 16+
if [ -x "scripts/spm-iroha-hotfix.sh" ]; then
  echo "\n==> Applying SPM IrohaCrypto hotfix"
  scripts/spm-iroha-hotfix.sh "${SCHEME}" "${WORKSPACE}" || true
fi

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
