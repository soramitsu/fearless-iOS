#!/usr/bin/env bash
set -euo pipefail

# Enforce repo-owned SwiftPM resolved-state contracts across committed files and
# materialized DerivedData copies that are writable.
#
# Usage:
#   scripts/deps/enforce-ssf-pin.sh [REVISION] [WORKSPACE_DIR]
# Defaults:
#   REVISION=3ad0fe928333c9ac28972e3669ca733c6972f060
#   WORKSPACE_DIR=current working directory

REVISION="${1:-3ad0fe928333c9ac28972e3669ca733c6972f060}"
ROOT="${2:-$(pwd)}"
WEB3_SOURCE_URL="https://github.com/soramitsu/web3-swift"

echo "[enforce-ssf-pin] Target revision: ${REVISION}"

patch_resolved() {
  local resolved="$1"
  [[ -f "$resolved" ]] || return 0
  [[ -w "$resolved" ]] || {
    echo "[enforce-ssf-pin] Skipping non-writable file: $resolved"
    return 0
  }
  [[ "$resolved" == *"/SnapshotsPreviewCache/"* ]] && {
    echo "[enforce-ssf-pin] Skipping preview snapshot cache file: $resolved"
    return 0
  }

  local tmp="${resolved}.tmp"

  /usr/bin/awk -v rev="$REVISION" '
    BEGIN{in_pkg=0}
    /"identity"[[:space:]]*:[[:space:]]*"shared-features-spm"/ { in_pkg=1 }
    in_pkg==1 && /"state"[[:space:]]*:/ { print; next }
    in_pkg==1 && /"revision"[[:space:]]*:/ { sub(/"revision"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"revision\" : \"" rev "\""); print; in_pkg=0; next }
    { print }
  ' "$resolved" > "$tmp" || {
    rm -f "$tmp"
    echo "[enforce-ssf-pin] Warning: failed to prepare patch for $resolved"
    return 0
  }

  /usr/bin/perl -0pi -e '
    s/"identity"\s*:\s*"web3\.swift"/"identity" : "web3-swift"/g;
    s|https://github\.com/bnsports/Web3\.swift\.git|'"$WEB3_SOURCE_URL"'|g;
  ' "$tmp" || {
    rm -f "$tmp"
    echo "[enforce-ssf-pin] Warning: failed to normalize Web3 source in $resolved"
    return 0
  }

  if cmp -s "$resolved" "$tmp"; then
    rm -f "$tmp"
  else
    echo "[enforce-ssf-pin] Patching $resolved"
    mv "$tmp" "$resolved"
  fi
}

# Committed Package.resolved files
patch_resolved "$ROOT/fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved"
patch_resolved "$ROOT/fearless.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

# DerivedData copies (skip preview snapshot caches and non-writable paths)
for dd in "$HOME/Library/Developer/Xcode/DerivedData" "$ROOT/DerivedData"; do
  [[ -d "$dd" ]] || continue
  while IFS= read -r -d '' file; do
    patch_resolved "$file"
  done < <(/usr/bin/find "$dd" -type f -path "*/xcshareddata/swiftpm/Package.resolved" -print0 2>/dev/null)
done

echo "[enforce-ssf-pin] Completed enforcing shared-features-spm pin"
