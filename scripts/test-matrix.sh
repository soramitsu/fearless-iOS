#!/usr/bin/env bash
set -euo pipefail

# Runs unit and integration tests across Debug and Release configurations.
#
# Usage:
#   scripts/test-matrix.sh [SCHEME] [DESTINATION]
# Defaults:
#   SCHEME=fearless
#   DESTINATION="platform=iOS Simulator,OS=latest,name=iPhone 15"

SCHEME="${1:-fearless}"
DEST="${2:-platform=iOS Simulator,OS=latest,name=iPhone 15}"
WORKSPACE="fearless.xcworkspace"

echo "==> Using scheme: ${SCHEME}"
echo "==> Destination: ${DEST}"

function run_tests() {
  local config=$1
  echo "\n==> Running ${config} tests"
  local extra=()
  if [[ "${config}" == "Release" ]]; then
    # Ensure testability for Release builds when running unit tests on simulator
    extra+=(ENABLE_TESTABILITY=YES)
  fi
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
    xcodebuild \
      -workspace "${WORKSPACE}" \
      -scheme "${SCHEME}" \
      -configuration "${config}" \
      -destination "${DEST}" \
      -enableCodeCoverage YES \
      "${extra[@]}" \
      clean test
  }
fi

run_tests Debug
run_tests Release

echo "\n==> All tests passed in Debug and Release"
