#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
WORKSPACE="${2:-fearless.xcworkspace}"
SCHEME="${3:-fearless.tests}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT/SourcePackages}"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"
ALLOW_RESOLVE_FAILURE="${ALLOW_RESOLVE_FAILURE:-0}"

run_step() {
  local script_path="$1"
  local label="$2"

  if [[ ! -x "$script_path" ]]; then
    echo "[prepare-native-crypto-checkout] Missing helper: $script_path" >&2
    exit 1
  fi

  echo "[prepare-native-crypto-checkout] ${label}"
  SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR}" \
    STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES}" \
    "$script_path" "$ROOT"
}

verify_current_state() {
  SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR}" \
    "$ROOT/scripts/deps/verify-native-crypto-package-state.sh" "$ROOT"
}

echo "[prepare-native-crypto-checkout] Checking current native crypto package state"
if verify_current_state >/dev/null 2>&1; then
  echo "[prepare-native-crypto-checkout] Native crypto checkout already matches the repo-owned contract"
  exit 0
fi

run_step "$ROOT/scripts/deps/apply-native-crypto-package-contract.sh" "Applying package contract"

echo "[prepare-native-crypto-checkout] Re-resolving Swift Package dependencies"
if ! xcodebuild \
  -resolvePackageDependencies \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_DIR}"; then
  if [[ "$ALLOW_RESOLVE_FAILURE" == "1" ]]; then
    echo "[prepare-native-crypto-checkout] Swift Package re-resolve failed but ALLOW_RESOLVE_FAILURE=1, continuing" >&2
  else
    echo "[prepare-native-crypto-checkout] Swift Package re-resolve failed before native crypto contract verification" >&2
    exit 3
  fi
fi

run_step "$ROOT/scripts/deps/apply-native-crypto-modulemap-contract.sh" "Applying modulemap contract"

echo "[prepare-native-crypto-checkout] Verifying native crypto package state"
verify_current_state
