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
printf '\n==> Cleaning stale package state\n'
rm -rf "$LOCAL_SOURCE_PACKAGES_DIR/checkouts/Web3.swift" 2>/dev/null || true
rm -f "$LOCAL_SOURCE_PACKAGES_DIR/workspace-state.json" 2>/dev/null || true
find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/SourcePackages/checkouts/Web3.swift" -prune -exec rm -rf {} + 2>/dev/null || true
find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/SourcePackages/workspace-state.json" -exec rm -f {} \; 2>/dev/null || true

if [ -f "scripts/deps/bootstrap-local-swiftpm-config.sh" ]; then
  echo "==> Bootstrapping local SwiftPM configuration"
  bash scripts/deps/bootstrap-local-swiftpm-config.sh

  LOCAL_SWIFTPM_GIT_CONFIG="$LOCAL_SOURCE_PACKAGES_DIR/configuration/gitconfig"
  if [[ -f "$LOCAL_SWIFTPM_GIT_CONFIG" ]]; then
    export GIT_CONFIG_GLOBAL="$LOCAL_SWIFTPM_GIT_CONFIG"
    echo "==> Using local SwiftPM Git config: ${GIT_CONFIG_GLOBAL}"
  fi
fi

# If destination is a placeholder, pick a concrete available simulator (prefer newest iPhone)
if [[ "$DEST" == *"Any iOS Simulator Device"* || "$DEST" == "" ]]; then
  echo "==> Autodetecting a concrete simulator device (with create fallback)"
  DEV_ID_RAW="$(LOG_PREFIX="[test-matrix]" PREFERRED_NAME="iPhone 16" ALLOW_CREATE=1 BOOT_SIMULATOR=0 "$(pwd)/scripts/ci/select-simulator.sh")"
  DEV_ID="$(printf '%s\n' "$DEV_ID_RAW" | awk 'match($0, /[A-Fa-f0-9-]{36}/) { print substr($0, RSTART, RLENGTH); exit }')"
  if [[ -z "$DEV_ID" ]]; then
    echo "Failed to detect a valid simulator UDID from selector output: $DEV_ID_RAW" >&2
    exit 1
  fi
  DEST="platform=iOS Simulator,id=${DEV_ID}"
  case "${HOST_ARCH}" in
    arm64|x86_64)
      DEST+=",arch=${HOST_ARCH}"
      ;;
  esac
  echo "==> Using detected destination: ${DEST}"
fi

restore_swiftpm_contract_files() {
  if [ -x "scripts/deps/restore-swiftpm-contract-files.sh" ]; then
    scripts/deps/restore-swiftpm-contract-files.sh "$(pwd)" "[test-matrix]"
  fi
}

# Enforce SSF pin, then apply repo-owned package contracts/fixes so SSF packages are stable under Xcode 16+
if [ -f "scripts/deps/enforce-ssf-pin.sh" ]; then
  printf '\n==> Enforcing shared-features-spm pinned revision\n'
  bash scripts/deps/enforce-ssf-pin.sh || true
fi

printf '\n==> Restoring committed SwiftPM contract files (if needed)\n'
restore_swiftpm_contract_files

if [ -f "scripts/deps/check-dependency-contracts.sh" ]; then
  printf '\n==> Validating dependency contracts\n'
  bash scripts/deps/check-dependency-contracts.sh
fi

apply_checkout_fixes() {
  # prepare-native-crypto-checkout may trigger SwiftPM materialization, so run
  # source compatibility fixes after native crypto preparation.
  if [ -f "scripts/spm-shared-features-fixes.sh" ]; then
    printf '\n==> Applying shared-features-spm fixes\n'
    SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 SSF_SINGLE_VALUE_CACHE_MANUAL_CLASS=1 bash scripts/spm-shared-features-fixes.sh "$(pwd)"
  fi

  if [ -x "scripts/deps/apply-charts-swift6-compat.sh" ]; then
    printf '\n==> Applying Charts Swift compatibility fixes\n'
    SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 bash scripts/deps/apply-charts-swift6-compat.sh "$(pwd)"
  fi

  if [ -x "scripts/deps/apply-svgkit-umbrella-contract.sh" ]; then
    printf '\n==> Applying SVGKit umbrella header contract\n'
    SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 bash scripts/deps/apply-svgkit-umbrella-contract.sh "$(pwd)"
  fi

  if [ -x "scripts/deps/apply-tonapi-http-types-contract.sh" ]; then
    printf '\n==> Applying TonAPI HTTPTypes dependency contract\n'
    SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 bash scripts/deps/apply-tonapi-http-types-contract.sh "$(pwd)"
  fi

  if [ -x "scripts/deps/apply-reown-signer-contract.sh" ]; then
    printf '\n==> Applying Reown signer dependency contract\n'
    SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 bash scripts/deps/apply-reown-signer-contract.sh "$(pwd)"
  fi

  if [ -x "scripts/deps/apply-web3-nio-ssl-contract.sh" ]; then
    printf '\n==> Applying Web3 NIOSSL dependency contract\n'
    SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 bash scripts/deps/apply-web3-nio-ssl-contract.sh "$(pwd)"
  fi

  printf '\n==> Refreshing Swift Package resolved state after checkout patches\n'
  xcodebuild \
    -resolvePackageDependencies \
    -workspace "${WORKSPACE}" \
    -scheme "${SCHEME}" \
    -clonedSourcePackagesDirPath "${LOCAL_SOURCE_PACKAGES_DIR}"

  if [ -f "scripts/deps/enforce-ssf-pin.sh" ]; then
    printf '\n==> Normalizing SwiftPM resolved contracts after checkout patches\n'
    bash scripts/deps/enforce-ssf-pin.sh
  fi

  restore_swiftpm_contract_files

  if [ -x "scripts/deps/check-swiftpm-consistency.sh" ]; then
    scripts/deps/check-swiftpm-consistency.sh
  fi
}

printf '\n==> Resolving Swift Package dependencies\n'
if ! xcodebuild \
  -resolvePackageDependencies \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -clonedSourcePackagesDirPath "${LOCAL_SOURCE_PACKAGES_DIR}"; then
  echo "Initial Swift Package resolution failed before shared-features/native-crypto preparation." >&2
  exit 1
fi

verify_native_crypto_state() {
  if [ ! -f "scripts/deps/prepare-native-crypto-checkout.sh" ]; then
    apply_checkout_fixes
    return 0
  fi

  printf '\n==> Preparing native crypto checkout\n'
  local status=0
  if SOURCE_PACKAGES_DIR="${LOCAL_SOURCE_PACKAGES_DIR}" STRICT_REQUIRED_PATCHES=1 bash scripts/deps/prepare-native-crypto-checkout.sh "$(pwd)" "${WORKSPACE}" "${SCHEME}"; then
    apply_checkout_fixes
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
    printf '\n==> Running %s tests\n' "${config}"
  else
    printf '\n==> Running %s tests (no xcpretty)\n' "${config}"
  fi

  verify_native_crypto_state

  local result_bundle_dir
  result_bundle_dir="$(pwd)/build/test-results"
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

  restore_swiftpm_contract_files

  if [[ "$HAS_XCPRETTY" == "1" ]]; then
    "${cmd[@]}" | xcpretty || {
      echo "xcodebuild ${config} tests failed" >&2
      exit 1
    }
  else
    "${cmd[@]}"
  fi

  if [[ -x "scripts/ci/coverage-summary.sh" ]]; then
    COVERAGE_TARGET_REGEX="${COVERAGE_TARGET_REGEX:-^fearless\\.app$}" \
      scripts/ci/coverage-summary.sh "${result_bundle_path}"
  fi
}

run_tests Debug

if [[ "${HOST_ARCH}" == "x86_64" ]]; then
  printf '\n==> Skipping Release simulator tests on x86_64 host due to missing native package symbols for simulator linking\n'
else
  run_tests Release
fi

if [[ "${HOST_ARCH}" == "x86_64" ]]; then
  printf '\n==> Debug tests passed; Release simulator tests were skipped on x86_64 host\n'
else
  printf '\n==> All tests passed in Debug and Release\n'
fi
