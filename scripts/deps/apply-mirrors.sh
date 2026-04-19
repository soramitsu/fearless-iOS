#!/usr/bin/env bash
set -euo pipefail

# Configure SwiftPM mirrors for reliable dependency access.
# Reads mirrors from scripts/deps/mirrors.json and applies them via
#   - swift package config set-mirror (SPM)
# Generic GitHub token rewrites remain owned by the CI/private-pods scripts.

BASE_DIR="${1:-$(pwd)}"
MIRRORS_JSON="${2:-$BASE_DIR/scripts/deps/mirrors.json}"

if [ ! -f "$MIRRORS_JSON" ]; then
  echo "[apply-mirrors] No mirrors.json found at $MIRRORS_JSON; skipping" >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[apply-mirrors] jq not found; install jq to use JSON-based mirrors" >&2
  exit 0
fi

SWIFT_PACKAGE_ARGS=()
if [ -f "$BASE_DIR/Package.swift" ]; then
  SWIFT_PACKAGE_ARGS=(--package-path "$BASE_DIR")
elif [ -f "$BASE_DIR/Packages/FearlessDependencies/Package.swift" ]; then
  SWIFT_PACKAGE_ARGS=(--package-path "$BASE_DIR/Packages/FearlessDependencies")
fi

echo "[apply-mirrors] Applying mirrors from $MIRRORS_JSON"

# Expected format:
# {
#   "object": [ { "original": "https://github.com/owner/repo", "mirror": "https://mirror/repo" } ],
#   "version": 1
# }

spm_count=$(jq '.object | length' "$MIRRORS_JSON")
if [ "$spm_count" != "null" ] && [ "$spm_count" -gt 0 ] 2>/dev/null; then
  for i in $(seq 0 $((spm_count - 1))); do
    orig=$(jq -r ".object[$i].original" "$MIRRORS_JSON")
    mir=$(jq -r ".object[$i].mirror" "$MIRRORS_JSON")
    if [ -n "$orig" ] && [ -n "$mir" ] && [ "$orig" != "null" ] && [ "$mir" != "null" ]; then
      echo "[apply-mirrors] SPM mirror: $orig -> $mir"
      swift package "${SWIFT_PACKAGE_ARGS[@]}" config set-mirror --original "$orig" --mirror "$mir" || true
    fi
  done
fi

echo "[apply-mirrors] Done"
