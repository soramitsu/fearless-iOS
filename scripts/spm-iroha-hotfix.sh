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
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$(pwd)/SourcePackages}"
PATCHED_COUNT=0

echo "==> Running SPM IrohaCrypto hotfix (scheme=${SCHEME}, workspace=${WORKSPACE})"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found in PATH" >&2
  exit 127
fi

# Resolve Swift Package dependencies to ensure checkout exists in DerivedData
# Optionally skip resolve when running inside Xcode pre-actions to avoid nested xcodebuild re-entrancy
if [ -z "${HOTFIX_SKIP_RESOLVE:-}" ]; then
  echo "==> Resolving SwiftPM dependencies"
  xcodebuild \
    -resolvePackageDependencies \
    -workspace "${WORKSPACE}" \
    -scheme "${SCHEME}" \
    -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_DIR}" || true
else
  echo "==> Skipping SPM resolve (HOTFIX_SKIP_RESOLVE set)"
fi

_sed_inplace() {
  # Cross-platform sed -i
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

write_umbrella_headers() {
  local include_dir="$1"
  local parent_dir="$2"
  local hdr_include="$include_dir/IrohaCrypto-umbrella.h"
  local hdr_parent="$parent_dir/IrohaCrypto-umbrella.h"

  printf '%s\n' \
    '// Temporary umbrella header to satisfy IrohaCrypto module.modulemap' \
    '#import <Foundation/Foundation.h>' > "$hdr_include"
  printf '%s\n' \
    '// Temporary umbrella header to satisfy IrohaCrypto module.modulemap (parent path)' \
    '#import <Foundation/Foundation.h>' > "$hdr_parent"
}

patch_modulemap() {
  local mm="$1"
  [ -f "$mm" ] || return 0

  echo "==> Patching module.modulemap: $mm"
  _sed_inplace 's|umbrella header "../IrohaCrypto-umbrella.h"|umbrella header "IrohaCrypto-umbrella.h"|g' "$mm" || true

  local include_dir
  local parent_dir
  include_dir="$(dirname "$mm")"
  parent_dir="$(dirname "$include_dir")"
  write_umbrella_headers "$include_dir" "$parent_dir"

  if [ -f "$include_dir/IrohaCrypto-umbrella.h" ] && [ -f "$parent_dir/IrohaCrypto-umbrella.h" ]; then
    PATCHED_COUNT=$((PATCHED_COUNT + 1))
  fi
}

patch_path() {
  local base="$1"
  local mm="$base/SourcePackages/checkouts/shared-features-spm/Sources/IrohaCrypto/include/module.modulemap"
  patch_modulemap "$mm"
}

patch_any_under_base() {
  local base="$1"
  local found=0
  while IFS= read -r -d '' mm; do
    found=1
    patch_modulemap "$mm"
  done < <(/usr/bin/find "$base" -type f -path "*/SourcePackages/checkouts/*/Sources/IrohaCrypto/include/module.modulemap" -print0 2>/dev/null)

  if [ "$found" = 0 ]; then
    echo "==> No IrohaCrypto module.modulemap found under: $base"
  fi
}

# Common DerivedData candidates
echo "==> Searching for module maps to patch"

# 1) DerivedData co-located in workspace (when configured by CI)
if [ -n "${WORKSPACE_DIR:-}" ] && [ -d "$WORKSPACE_DIR/DerivedData" ]; then
  patch_path "$WORKSPACE_DIR/DerivedData/fearless"
fi

# 1a) Explicit local cloned source packages directory
if [ -d "$SOURCE_PACKAGES_DIR" ]; then
  patch_any_under_base "$(dirname "$SOURCE_PACKAGES_DIR")"
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

# 4) Workspace/local SourcePackages (CI often uses clonedSourcePackagesDirPath)
if [ -n "${WORKSPACE_DIR:-}" ] && [ -d "$WORKSPACE_DIR/SourcePackages" ]; then
  patch_any_under_base "$WORKSPACE_DIR"
fi

if [ -d "SourcePackages" ]; then
  patch_any_under_base "$(pwd)"
fi

if [ "${HOTFIX_REQUIRE_PATCH:-0}" = "1" ] && [ "$PATCHED_COUNT" -eq 0 ]; then
  echo "IrohaCrypto hotfix could not find any checkout to patch" >&2
  exit 1
fi

echo "==> IrohaCrypto hotfix patched ${PATCHED_COUNT} checkout(s)"
echo "==> SPM IrohaCrypto hotfix completed"
