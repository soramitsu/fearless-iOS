#!/usr/bin/env bash
set -euo pipefail

# Enforce a specific shared-features-spm revision across committed SwiftPM files and
# materialized DerivedData copies that are writable.
#
# Usage:
#   scripts/deps/enforce-ssf-pin.sh [REVISION] [WORKSPACE_DIR]
# Defaults:
#   REVISION=3ad0fe928333c9ac28972e3669ca733c6972f060
#   WORKSPACE_DIR=current working directory

REVISION="${1:-3ad0fe928333c9ac28972e3669ca733c6972f060}"
ROOT="${2:-$(pwd)}"

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

  if /usr/bin/grep -q '"identity"\s*:\s*"shared-features-spm"' "$resolved"; then
    echo "[enforce-ssf-pin] Patching $resolved"
    local tmp="${resolved}.tmp"
    /usr/bin/awk -v rev="$REVISION" '
      BEGIN{in_pkg=0}
      /"identity"[[:space:]]*:[[:space:]]*"shared-features-spm"/ { in_pkg=1 }
      in_pkg==1 && /"state"[[:space:]]*:/ { print; next }
      in_pkg==1 && /"revision"[[:space:]]*:/ { sub(/"revision"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"revision\" : \"" rev "\""); print; in_pkg=0; next }
      { print }
    ' "$resolved" > "$tmp" && mv "$tmp" "$resolved" || {
      rm -f "$tmp"
      echo "[enforce-ssf-pin] Warning: failed to patch $resolved"
    }
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
