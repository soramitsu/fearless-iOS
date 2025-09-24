#!/usr/bin/env bash
set -euo pipefail

# Hotfix for shared-features-spm IrohaCrypto module.modulemap umbrella path on Xcode 16+
# - Resolves SwiftPM packages to materialize the checkout
# - Patches umbrella header path and creates a stub umbrella header if missing
#
# Usage:
#   scripts/spm-iroha-hotfix.sh [SCHEME] [WORKSPACE]
# Defaults:
#   SCHEME=fearless
#   WORKSPACE=fearless.xcworkspace

SCHEME="${1:-fearless}"
WORKSPACE="${2:-fearless.xcworkspace}"

echo "==> Running SPM IrohaCrypto hotfix (scheme=${SCHEME}, workspace=${WORKSPACE})"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found in PATH" >&2
  exit 127
fi

# Resolve Swift Package dependencies to ensure checkout exists in DerivedData
echo "==> Resolving SwiftPM dependencies"
xcodebuild -resolvePackageDependencies -workspace "${WORKSPACE}" -scheme "${SCHEME}" || true

_sed_inplace() {
  # Cross-platform sed -i
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

patch_path() {
  local base="$1"
  local mm="$base/SourcePackages/checkouts/shared-features-spm/Sources/IrohaCrypto/include/module.modulemap"
  if [ -f "$mm" ]; then
    echo "==> Patching module.modulemap: $mm"
    _sed_inplace 's|umbrella header "../IrohaCrypto-umbrella.h"|umbrella header "IrohaCrypto-umbrella.h"|g' "$mm" || true
    local include_dir="$(dirname "$mm")"
    local parent_dir="$(dirname "$include_dir")"
    local hdr_include="$include_dir/IrohaCrypto-umbrella.h"
    local hdr_parent="$parent_dir/IrohaCrypto-umbrella.h"
    if [ ! -f "$hdr_include" ]; then
      printf '%s\n' \
        '// Temporary umbrella header to satisfy IrohaCrypto module.modulemap' \
        '#import <Foundation/Foundation.h>' > "$hdr_include"
    fi
    if [ ! -f "$hdr_parent" ]; then
      printf '%s\n' \
        '// Temporary umbrella header to satisfy IrohaCrypto module.modulemap (parent path)' \
        '#import <Foundation/Foundation.h>' > "$hdr_parent"
    fi
  fi
}

# Common DerivedData candidates
echo "==> Searching for module maps to patch"

# 1) DerivedData co-located in workspace (when configured by CI)
if [ -n "${WORKSPACE_DIR:-}" ] && [ -d "$WORKSPACE_DIR/DerivedData" ]; then
  patch_path "$WORKSPACE_DIR/DerivedData/fearless"
fi

# 2) DerivedData under current repo directory (common in some CIs)
if [ -d "DerivedData/fearless" ]; then
  patch_path "$(pwd)/DerivedData/fearless"
fi

# 3) Default Xcode DerivedData locations
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/*; do
  [ -d "$dd/SourcePackages" ] || continue
  patch_path "$dd"
done

echo "==> SPM IrohaCrypto hotfix completed"

