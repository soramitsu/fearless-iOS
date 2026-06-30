#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT/SourcePackages}"
UMBRELLA_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto-umbrella.h"
MODULEMAP_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto.module.modulemap"
CHECKOUT_HELPER="$ROOT/scripts/deps/native-crypto-checkout-roots.sh"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"
PATCHED=0
FOUND=0

fail() {
  echo "[apply-native-crypto-modulemap-contract] $1" >&2
  exit 1
}

install_if_needed() {
  local source_file="$1"
  local destination_file="$2"

  if [[ -e "$destination_file" ]]; then
    chmod u+w "$destination_file" 2>/dev/null || true
  fi

  if [[ ! -f "$destination_file" ]] || ! cmp -s "$source_file" "$destination_file"; then
    cp "$source_file" "$destination_file"
    PATCHED=1
  fi
}

[[ -f "$CHECKOUT_HELPER" ]] || fail "Missing checkout helper at $CHECKOUT_HELPER"
[[ -f "$MODULEMAP_TEMPLATE" ]] || fail "Missing modulemap template at $MODULEMAP_TEMPLATE"
# shellcheck source=/dev/null
source "$CHECKOUT_HELPER"

patch_package_root() {
  local package_root="$1"
  local modulemap="$package_root/Sources/IrohaCrypto/include/module.modulemap"
  local include_dir="$package_root/Sources/IrohaCrypto/include"
  local parent_dir="$package_root/Sources/IrohaCrypto"

  [[ -f "$modulemap" ]] || return 0

  chmod -R u+w "$package_root/Sources/IrohaCrypto" 2>/dev/null || true

  if ! cmp -s "$MODULEMAP_TEMPLATE" "$modulemap"; then
    cp "$MODULEMAP_TEMPLATE" "$modulemap"
    PATCHED=1
  fi

  mkdir -p "$include_dir" "$parent_dir"

  if [[ -f "$UMBRELLA_TEMPLATE" ]]; then
    install_if_needed "$UMBRELLA_TEMPLATE" "$include_dir/IrohaCrypto-umbrella.h"
    install_if_needed "$UMBRELLA_TEMPLATE" "$parent_dir/IrohaCrypto-umbrella.h"
  else
    local tmp_template
    tmp_template="$(mktemp)"
    printf '%s\n' \
      '// Temporary umbrella header to satisfy IrohaCrypto module.modulemap' \
      '#import <Foundation/Foundation.h>' > "$tmp_template"
    install_if_needed "$tmp_template" "$include_dir/IrohaCrypto-umbrella.h"
    install_if_needed "$tmp_template" "$parent_dir/IrohaCrypto-umbrella.h"
    rm -f "$tmp_template"
  fi

  cmp -s "$MODULEMAP_TEMPLATE" "$modulemap" || fail "module.modulemap does not match the expected repo-owned template: $modulemap"
  [[ -f "$include_dir/IrohaCrypto-umbrella.h" ]] || fail "Missing include umbrella header after patch: $include_dir/IrohaCrypto-umbrella.h"
  [[ -f "$parent_dir/IrohaCrypto-umbrella.h" ]] || fail "Missing parent umbrella header after patch: $parent_dir/IrohaCrypto-umbrella.h"
}

while IFS= read -r package_root; do
  modulemap="$package_root/Sources/IrohaCrypto/include/module.modulemap"
  [[ -f "$modulemap" ]] || continue
  FOUND=1
  patch_package_root "$package_root"
done < <(native_crypto_checkout_candidates "$ROOT" "$SOURCE_PACKAGES_DIR")

if [[ "$FOUND" != "1" ]]; then
  if [[ "$STRICT_REQUIRED_PATCHES" == "1" ]]; then
    fail "No materialized IrohaCrypto module.modulemap found under SourcePackages or repo-local DerivedData"
  fi

  echo "[apply-native-crypto-modulemap-contract] IrohaCrypto module.modulemap not found in any materialized checkout (skip)"
  exit 0
fi

if [[ "$PATCHED" == "1" ]]; then
  echo "[apply-native-crypto-modulemap-contract] Patched IrohaCrypto modulemap/umbrella state"
else
  echo "[apply-native-crypto-modulemap-contract] IrohaCrypto modulemap/umbrella state already conformed"
fi
