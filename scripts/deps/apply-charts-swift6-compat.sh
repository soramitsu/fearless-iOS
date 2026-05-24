#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT/SourcePackages}"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"
PATCHED=0
FOUND=0

emit_candidates() {
  local candidate

  for candidate in \
    "$SOURCE_PACKAGES_DIR/checkouts/Charts" \
    "$ROOT/build/DerivedData/SourcePackages/checkouts/Charts" \
    "$ROOT/DerivedData/SourcePackages/checkouts/Charts" \
    "$ROOT/build/DerivedData"/*/SourcePackages/checkouts/Charts \
    "$ROOT/DerivedData"/*/SourcePackages/checkouts/Charts \
    "$HOME/Library/Developer/Xcode/DerivedData"/*/SourcePackages/checkouts/Charts; do
    [[ -d "$candidate" ]] || continue
    printf '%s\n' "$candidate"
  done | awk '!seen[$0]++'
}

patch_charts_root() {
  local package_root="$1"
  local utils="$package_root/Source/Charts/Utils/ChartUtils.swift"

  [[ -f "$utils" ]] || return 0
  FOUND=1
  chmod u+w "$utils" 2>/dev/null || true

  if ! /usr/bin/grep -q '^import Darwin$' "$utils"; then
    /usr/bin/perl -0pi -e 's/import Foundation\n/import Foundation\nimport Darwin\n/' "$utils"
    PATCHED=1
  fi

  /usr/bin/perl -0pi -e '
    s/Darwin\.Darwin\.pow/Darwin.pow/g;
    s/\bceil\(log10\(/Darwin.ceil(Darwin.log10(/g;
    s/(?<!Darwin\.)\bpow\(10\.0, Double\(pw\)\)/Darwin.pow(10.0, Double(pw))/g;
    s/\bceil\(-log10\(/Darwin.ceil(-Darwin.log10(/g;
  ' "$utils"
}

while IFS= read -r package_root; do
  patch_charts_root "$package_root"
done < <(emit_candidates)

if [[ "$FOUND" != "1" ]]; then
  if [[ "$STRICT_REQUIRED_PATCHES" == "1" ]]; then
    echo "[apply-charts-swift6-compat] Charts checkout not found" >&2
    exit 1
  fi

  echo "[apply-charts-swift6-compat] Charts checkout not found; skipping"
elif [[ "$PATCHED" == "1" ]]; then
  echo "[apply-charts-swift6-compat] Patched Charts Swift 6 math compatibility"
else
  echo "[apply-charts-swift6-compat] Charts Swift 6 compatibility already applied"
fi
