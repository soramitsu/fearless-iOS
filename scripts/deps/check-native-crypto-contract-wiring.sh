#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"

fail() {
  echo "[check-native-crypto-contract-wiring] $1" >&2
  exit 1
}

ensure_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  [[ -f "$file" ]] || fail "Missing file: $file"
  /usr/bin/grep -Fq "$pattern" "$file" || fail "$label"
}

ensure_executable() {
  local file="$1"

  [[ -x "$file" ]] || fail "Missing executable helper: $file"
}

ensure_absent() {
  local pattern="$1"
  local label="$2"

  if /usr/bin/grep -RInF "$pattern" "$ROOT" \
    --exclude-dir=.git \
    --exclude-dir=build \
    --exclude-dir=DerivedData \
    --exclude-dir=SourcePackages \
    --exclude="$(basename "$0")" >/dev/null 2>&1; then
    fail "$label"
  fi
}

for script in \
  "scripts/deps/prepare-native-crypto-checkout.sh" \
  "scripts/deps/apply-native-crypto-package-contract.sh" \
  "scripts/deps/apply-native-crypto-modulemap-contract.sh" \
  "scripts/deps/verify-native-crypto-package-state.sh"; do
  ensure_executable "$ROOT/$script"
done

ensure_contains \
  "$ROOT/scripts/deps/native-crypto-checkout-roots.sh" \
  "ALLOW_DERIVEDDATA_FALLBACK" \
  "native crypto checkout helper must gate global DerivedData fallback"

ensure_contains \
  "$ROOT/scripts/test-matrix.sh" \
  "scripts/deps/prepare-native-crypto-checkout.sh" \
  "test-matrix.sh is not wired to prepare-native-crypto-checkout.sh"

ensure_contains \
  "$ROOT/scripts/dev-setup.sh" \
  "scripts/deps/prepare-native-crypto-checkout.sh" \
  "dev-setup.sh is not wired to prepare-native-crypto-checkout.sh"

ensure_contains \
  "$ROOT/scripts/ci/bootstrap.sh" \
  "scripts/deps/prepare-native-crypto-checkout.sh" \
  "ci/bootstrap.sh is not wired to prepare-native-crypto-checkout.sh"

ensure_contains \
  "$ROOT/scripts/ci/run-pr.sh" \
  "scripts/deps/prepare-native-crypto-checkout.sh" \
  "ci/run-pr.sh is not wired to prepare-native-crypto-checkout.sh"

ensure_absent "scripts/spm-iroha-hotfix.sh" "Legacy spm-iroha-hotfix.sh reference still exists"
ensure_absent "apply-native-crypto-contracts.sh" "Removed apply-native-crypto-contracts.sh reference still exists"

echo "[check-native-crypto-contract-wiring] OK"
