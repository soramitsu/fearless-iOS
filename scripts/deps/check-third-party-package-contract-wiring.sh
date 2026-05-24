#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"

fail() {
  echo "[check-third-party-package-contract-wiring] $1" >&2
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

contract_scripts=(
  "scripts/deps/apply-tonapi-http-types-contract.sh"
  "scripts/deps/apply-reown-signer-contract.sh"
  "scripts/deps/apply-web3-nio-ssl-contract.sh"
  "scripts/deps/apply-charts-swift6-compat.sh"
  "scripts/deps/apply-svgkit-umbrella-contract.sh"
)

entrypoints=(
  "scripts/test-matrix.sh"
  "scripts/dev-setup.sh"
  "scripts/ci/bootstrap.sh"
  "scripts/ci/run-pr.sh"
)

for script in "${contract_scripts[@]}"; do
  ensure_executable "$ROOT/$script"

  for entrypoint in "${entrypoints[@]}"; do
    ensure_contains \
      "$ROOT/$entrypoint" \
      "$script" \
      "$entrypoint is not wired to $script"
  done

  ensure_contains \
    "$ROOT/fearless.xcodeproj/project.pbxproj" \
    "$script" \
    "Xcode project build phase is not wired to $script"

  ensure_contains \
    "$ROOT/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme" \
    "$script" \
    "fearless scheme pre-action is not wired to $script"

  ensure_contains \
    "$ROOT/fearless.xcodeproj/xcshareddata/xcschemes/fearless.tests.xcscheme" \
    "$script" \
    "fearless.tests scheme pre-action is not wired to $script"
done

ensure_contains \
  "$ROOT/scripts/dev-setup.sh" \
  "Refreshing SwiftPM resolved state after package patches" \
  "dev-setup.sh does not refresh SwiftPM after package patches"

ensure_contains \
  "$ROOT/scripts/test-matrix.sh" \
  "Refreshing Swift Package resolved state after checkout patches" \
  "test-matrix.sh does not refresh SwiftPM after package patches"

ensure_contains \
  "$ROOT/scripts/ci/bootstrap.sh" \
  "Refreshing SwiftPM resolved state after package patches" \
  "ci/bootstrap.sh does not refresh SwiftPM after package patches"

ensure_contains \
  "$ROOT/scripts/deps/apply-web3-nio-ssl-contract.sh" \
  "github.com/apple/swift-nio.git" \
  "Web3 contract does not declare the SwiftNIO package"

for product in NIOCore NIOHTTP1 NIOPosix NIOSSL; do
  ensure_contains \
    "$ROOT/scripts/deps/apply-web3-nio-ssl-contract.sh" \
    "name: \"$product\"" \
    "Web3 contract does not declare $product as a direct target dependency"
done

echo "[check-third-party-package-contract-wiring] OK"
