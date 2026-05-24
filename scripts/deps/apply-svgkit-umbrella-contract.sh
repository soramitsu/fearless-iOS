#!/usr/bin/env bash
set -euo pipefail

# SVGKit 3.0.0 exposes these headers through its SwiftPM public include
# directory, but the umbrella header omits them on iOS because the upstream
# Xcode-era header gates macOS-only types behind SVGKIT_MAC. Importing the
# guarded headers keeps SwiftPM explicit-module builds warning-clean.

BASE_DIR="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$BASE_DIR/SourcePackages}"
ALLOW_DERIVEDDATA_FALLBACK="${ALLOW_DERIVEDDATA_FALLBACK:-0}"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"

patched=0
seen=0

candidate_roots=(
  "$SOURCE_PACKAGES_DIR/checkouts/SVGKit"
)

if [[ "$ALLOW_DERIVEDDATA_FALLBACK" == "1" ]]; then
  for dd in "$BASE_DIR/build/DerivedData"/* "$BASE_DIR/DerivedData"/* "$HOME/Library/Developer/Xcode/DerivedData"/*; do
    [[ -d "$dd/SourcePackages/checkouts/SVGKit" ]] || continue
    candidate_roots+=("$dd/SourcePackages/checkouts/SVGKit")
  done
fi

for root in "${candidate_roots[@]}"; do
  header="$root/Source/SVGKit.h"
  include_dir="$root/Source/include"
  [[ -f "$header" && -d "$include_dir" ]] || continue

  seen=$((seen + 1))

  for required in SVGKDefine_Private.h SVGKExporterNSImage.h SVGKImageRep.h; do
    if [[ ! -e "$include_dir/$required" ]]; then
      echo "[apply-svgkit-umbrella-contract] Missing expected SVGKit public header: $include_dir/$required" >&2
      exit 1
    fi
  done

  chmod u+w "$header" 2>/dev/null || true

  if ! /usr/bin/grep -q '#import "SVGKDefine_Private.h"' "$header"; then
    /usr/bin/perl -0pi -e 's/#import "SVGKDefine\.h"\n/#import "SVGKDefine.h"\n#import "SVGKDefine_Private.h"\n/' "$header"
    patched=1
  fi

  if /usr/bin/grep -q '#if SVGKIT_MAC' "$header" && /usr/bin/grep -q '#import "SVGKExporterNSImage.h"' "$header"; then
    /usr/bin/perl -0pi -e 's/#if SVGKIT_MAC\n#import "SVGKExporterNSImage\.h"\n#else\n#import "SVGKExporterUIImage\.h"\n#endif/#import "SVGKExporterNSImage.h"\n#import "SVGKExporterUIImage.h"/' "$header"
    patched=1
  elif ! /usr/bin/grep -q '#import "SVGKExporterNSImage.h"' "$header"; then
    /usr/bin/perl -0pi -e 's/#import "SVGKExporterNSData\.h"\n/#import "SVGKExporterNSData.h"\n#import "SVGKExporterNSImage.h"\n/' "$header"
    patched=1
  fi

  if /usr/bin/grep -q '#if SVGKIT_MAC' "$header" && /usr/bin/grep -q '#import "SVGKImageRep.h"' "$header"; then
    /usr/bin/perl -0pi -e 's/#if SVGKIT_MAC\n#import "SVGKImageRep\.h"\n#endif/#import "SVGKImageRep.h"/' "$header"
    patched=1
  elif ! /usr/bin/grep -q '#import "SVGKImageRep.h"' "$header"; then
    /usr/bin/perl -0pi -e 's/#import "SVGUtils\.h"\n/#import "SVGUtils.h"\n#import "SVGKImageRep.h"\n/' "$header"
    patched=1
  fi
done

if [[ "$seen" -eq 0 ]]; then
  if [[ "$STRICT_REQUIRED_PATCHES" == "1" ]]; then
    echo "[apply-svgkit-umbrella-contract] SVGKit checkout not found" >&2
    exit 1
  fi
  echo "[apply-svgkit-umbrella-contract] SVGKit checkout not found; skipping"
elif [[ "$patched" == "1" ]]; then
  echo "[apply-svgkit-umbrella-contract] Patched SVGKit umbrella header contract"
else
  echo "[apply-svgkit-umbrella-contract] SVGKit umbrella header contract already applied"
fi
