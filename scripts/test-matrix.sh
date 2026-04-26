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
LOCAL_SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages"

echo "==> Using scheme: ${SCHEME}"
echo "==> Destination: ${DEST}"

HOST_ARCH="$(uname -m)"

# xcodebuild writes intermediate result artifacts under TMPDIR.
# Ensure it points to an existing, writable directory.
if [[ -z "${TMPDIR:-}" || ! -d "${TMPDIR}" ]]; then
  export TMPDIR="${HOME}/Library/Caches/fearless-iOS/tmp"
fi
mkdir -p "${TMPDIR}" 2>/dev/null || true

# Remove stale package state before any helper script triggers package resolution.
echo "\n==> Cleaning stale package state"
rm -rf "$LOCAL_SOURCE_PACKAGES_DIR/checkouts/Web3.swift" 2>/dev/null || true
rm -f "$LOCAL_SOURCE_PACKAGES_DIR/workspace-state.json" 2>/dev/null || true
find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/SourcePackages/checkouts/Web3.swift" -prune -exec rm -rf {} + 2>/dev/null || true
find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/SourcePackages/workspace-state.json" -exec rm -f {} \; 2>/dev/null || true

if [ -f "scripts/deps/bootstrap-local-swiftpm-config.sh" ]; then
  echo "==> Bootstrapping local SwiftPM configuration"
  bash scripts/deps/bootstrap-local-swiftpm-config.sh
fi

# If destination is a placeholder, pick a concrete available simulator (prefer newest iPhone)
if [[ "$DEST" == *"Any iOS Simulator Device"* || "$DEST" == "" ]]; then
  echo "==> Autodetecting a concrete simulator device (with create fallback)"
  DEV_ID="$(
    LOG_PREFIX="[test-matrix]" PREFERRED_NAME="iPhone 16" ALLOW_CREATE=1 BOOT_SIMULATOR=0 \
      "$(pwd)/scripts/ci/select-simulator.sh" 2>&1 | awk '
        match($0, /[A-Fa-f0-9-]{36}/) {
          found = substr($0, RSTART, RLENGTH)
        }
        END {
          if (found != "") {
            print found
          }
        }
      '
  )"
  if [[ -z "$DEV_ID" ]]; then
    echo "Failed to detect a valid simulator UDID from selector output" >&2
    exit 1
  fi
  DEST="platform=iOS Simulator,id=${DEV_ID}"
  echo "==> Using detected destination: ${DEST}"
fi

# Enforce SSF pin, then apply repo-owned package contracts/fixes so SSF packages are stable under Xcode 16+
if [ -f "scripts/deps/enforce-ssf-pin.sh" ]; then
  echo "\n==> Enforcing shared-features-spm pinned revision"
  bash scripts/deps/enforce-ssf-pin.sh || true
fi

if [ -x "scripts/deps/restore-swiftpm-contract-files.sh" ]; then
  echo "\n==> Restoring committed SwiftPM contract files (if needed)"
  scripts/deps/restore-swiftpm-contract-files.sh "$(pwd)" "[test-matrix]"
fi

if [ -f "scripts/deps/check-dependency-contracts.sh" ]; then
  echo "\n==> Validating dependency contracts"
  bash scripts/deps/check-dependency-contracts.sh
fi

echo "\n==> Resolving Swift Package dependencies"
if ! xcodebuild \
  -resolvePackageDependencies \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -clonedSourcePackagesDirPath "${LOCAL_SOURCE_PACKAGES_DIR}"; then
  echo "Initial Swift Package resolution failed before shared-features/native-crypto preparation." >&2
  exit 1
fi

# Patch shared-features-spm manifest and sources in the explicit local checkout.
if [ -f "scripts/spm-shared-features-fixes.sh" ]; then
  echo "\n==> Applying shared-features-spm fixes (SSFModels deps, Web3 API drift)"
  SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 bash scripts/spm-shared-features-fixes.sh "$(pwd)"
fi

verify_native_crypto_state() {
  if [ ! -f "scripts/deps/prepare-native-crypto-checkout.sh" ]; then
    return 0
  fi

  echo "\n==> Preparing native crypto checkout"
  local status=0
  if SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" STRICT_REQUIRED_PATCHES=1 bash scripts/deps/prepare-native-crypto-checkout.sh "$(pwd)" "${WORKSPACE}" "${SCHEME}"; then
    return 0
  else
    status=$?
  fi

  if [[ "$status" == "2" ]]; then
    echo "Native crypto contract failed because the resolved shared-features-spm checkout is missing." >&2
    echo "This indicates a package resolution/materialization problem rather than a patched package contract failure." >&2
  elif [[ "$status" == "3" ]]; then
    echo "Native crypto preparation failed because Swift Package re-resolution did not succeed." >&2
    echo "This indicates the checkout could not be materialized consistently before native crypto contract verification." >&2
  else
    echo "Native crypto contract failed because the resolved shared-features-spm checkout violates the expected package contract." >&2
    echo "This indicates the checkout exists, but IrohaCrypto linker/modulemap state is still incorrect." >&2
  fi
  exit "$status"
}

verify_native_crypto_state

# Ensure Cuckoo mock generation build phases run even on CI
unset CI || true

# Ensure tooling available
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found in PATH" >&2
  exit 127
fi

HAS_XCPRETTY=0
if command -v xcpretty >/dev/null 2>&1; then
  HAS_XCPRETTY=1
fi

run_tests() {
  local config=$1
  if [[ "$HAS_XCPRETTY" == "1" ]]; then
    echo "\n==> Running ${config} tests"
  else
    echo "\n==> Running ${config} tests (no xcpretty)"
  fi

  verify_native_crypto_state

  local result_bundle_dir="$(pwd)/build/test-results"
  local sanitized_scheme="${SCHEME//./_}"
  local result_bundle_path="${result_bundle_dir}/${sanitized_scheme}-${config}.xcresult"
  mkdir -p "${result_bundle_dir}"
  rm -rf "${result_bundle_path}"

  local extra=()
  if [[ "${HOST_ARCH}" == "arm64" ]]; then
    extra+=("EXCLUDED_ARCHS=x86_64")
  fi
  if [[ "${config}" == "Release" ]]; then
    # Ensure testability for Release builds when running unit tests on simulator
    extra+=(ENABLE_TESTABILITY=YES)
  fi

  local cmd=(
    xcodebuild
    -workspace "${WORKSPACE}"
    -scheme "${SCHEME}"
    -configuration "${config}"
    -destination "${DEST}"
    -clonedSourcePackagesDirPath "${LOCAL_SOURCE_PACKAGES_DIR}"
    -disableAutomaticPackageResolution
    -resultBundlePath "${result_bundle_path}"
    -enableCodeCoverage YES
  )
  if ((${#extra[@]})); then
    cmd+=("${extra[@]}")
  fi
  cmd+=(clean test)

  if [[ "$HAS_XCPRETTY" == "1" ]]; then
    "${cmd[@]}" | xcpretty || {
      echo "xcodebuild ${config} tests failed" >&2
      exit 1
    }
  else
    "${cmd[@]}"
  fi
}

run_tests Debug

if [[ "${HOST_ARCH}" == "x86_64" ]]; then
  echo "\n==> Skipping Release simulator tests on x86_64 host due to missing native package symbols for simulator linking"
else
  run_tests Release
fi

if [[ "${HOST_ARCH}" == "x86_64" ]]; then
  echo "\n==> Debug tests passed; Release simulator tests were skipped on x86_64 host"
else
  echo "\n==> All tests passed in Debug and Release"
fi
