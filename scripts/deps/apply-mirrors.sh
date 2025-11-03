#!/usr/bin/env bash
set -euo pipefail

# Configure SwiftPM and Git mirrors for faster, reliable dependency access.
# Reads mirrors from scripts/deps/mirrors.json and applies them via
#   - swift package config set-mirror (SPM)
#   - git config url.*.insteadOf (for CocoaPods/Pods and generic Git)

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

echo "[apply-mirrors] Applying mirrors from $MIRRORS_JSON"

# Expected format:
# {
#   "spm": [ { "original": "https://github.com/owner/repo", "mirror": "https://mirror/repo" } ],
#   "git": [ { "original": "https://github.com/", "mirror": "https://TOKEN@github.com/" } ]
# }

spm_count=$(jq '.spm | length' "$MIRRORS_JSON")
if [ "$spm_count" != "null" ] && [ "$spm_count" -gt 0 ] 2>/dev/null; then
  for i in $(seq 0 $((spm_count - 1))); do
    orig=$(jq -r ".spm[$i].original" "$MIRRORS_JSON")
    mir=$(jq -r ".spm[$i].mirror" "$MIRRORS_JSON")
    if [ -n "$orig" ] && [ -n "$mir" ] && [ "$orig" != "null" ] && [ "$mir" != "null" ]; then
      echo "[apply-mirrors] SPM mirror: $orig -> $mir"
      swift package config set-mirror --package-url "$orig" --mirror-url "$mir" || true
    fi
  done
fi

git_count=$(jq '.git | length' "$MIRRORS_JSON")
if [ "$git_count" != "null" ] && [ "$git_count" -gt 0 ] 2>/dev/null; then
  for i in $(seq 0 $((git_count - 1))); do
    orig=$(jq -r ".git[$i].original" "$MIRRORS_JSON")
    raw_mir=$(jq -r ".git[$i].mirror" "$MIRRORS_JSON")

    # Derive mirror value safely: expand GH_PAT_READ placeholder only if token present
    mir="$raw_mir"
    case "$raw_mir" in
      *"\${GH_PAT_READ:+https://\${GH_PAT_READ}@github.com/}"*)
        if [ -n "${GH_PAT_READ:-}" ]; then
          mir="https://${GH_PAT_READ}@github.com/"
        else
          mir="" # no token – skip this mapping
        fi
        ;;
    esac

    if [ -n "$orig" ] && [ -n "$mir" ] \
       && [ "$orig" != "null" ] && [ "$mir" != "null" ]; then
      echo "[apply-mirrors] Git mirror: $orig -> $mir"
      git config --global url."$mir".insteadOf "$orig" || true
    else
      echo "[apply-mirrors] Skipping Git mirror for $orig (no valid mirror configured)" >&2
    fi
  done
fi

echo "[apply-mirrors] Done"
