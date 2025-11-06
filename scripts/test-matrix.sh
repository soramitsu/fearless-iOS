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
RESULTS_DIR="${RESULTS_DIR:-build/coverage}"

echo "==> Using scheme: ${SCHEME}"
echo "==> Destination: ${DEST}"
echo "==> Coverage artifacts directory: ${RESULTS_DIR}"

mkdir -p "${RESULTS_DIR}"

pick_latest_iphone() {
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

# If destination is a placeholder, pick a concrete available simulator (prefer newest iPhone)
if [[ "$DEST" == *"Any iOS Simulator Device"* || "$DEST" == "" ]]; then
  echo "==> Autodetecting a concrete simulator device (latest iPhone if available)"
  DEV_NAME=$(pick_latest_iphone || true)
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
  local bundle_path="${RESULTS_DIR}/${config}.xcresult"
  rm -rf "${bundle_path}" || true
  if ((${#extra[@]})); then
    xcodebuild \
      -workspace "${WORKSPACE}" \
      -scheme "${SCHEME}" \
      -configuration "${config}" \
      -destination "${DEST}" \
      -enableCodeCoverage YES \
      -resultBundlePath "${bundle_path}" \
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
      -resultBundlePath "${bundle_path}" \
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
    local bundle_path="${RESULTS_DIR}/${config}.xcresult"
    rm -rf "${bundle_path}" || true
    if ((${#extra[@]})); then
      xcodebuild \
        -workspace "${WORKSPACE}" \
        -scheme "${SCHEME}" \
        -configuration "${config}" \
        -destination "${DEST}" \
        -enableCodeCoverage YES \
        -resultBundlePath "${bundle_path}" \
        "${extra[@]}" \
        clean test
    else
      xcodebuild \
        -workspace "${WORKSPACE}" \
        -scheme "${SCHEME}" \
        -configuration "${config}" \
        -destination "${DEST}" \
        -enableCodeCoverage YES \
        -resultBundlePath "${bundle_path}" \
        clean test
    fi
  }
fi

run_tests Debug
run_tests Release

echo "\n==> All tests passed in Debug and Release"

if [[ "${CODECOV_EXPORT:-0}" == "1" ]]; then
  echo "\n==> Exporting coverage artifacts for Codecov"
  scripts/ci/export-codecov.sh "${RESULTS_DIR}"
fi
