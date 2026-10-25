#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
REFERENCE_MIRRORS="$ROOT/scripts/deps/mirrors.json"
LOCAL_CONFIG_DIR="$ROOT/SourcePackages/configuration"
LOCAL_MIRRORS="$LOCAL_CONFIG_DIR/mirrors.json"

if [[ ! -f "$REFERENCE_MIRRORS" ]]; then
  echo "[bootstrap-local-swiftpm-config] Missing reference mirrors file: $REFERENCE_MIRRORS" >&2
  exit 1
fi

mkdir -p "$LOCAL_CONFIG_DIR"
cp "$REFERENCE_MIRRORS" "$LOCAL_MIRRORS"

echo "[bootstrap-local-swiftpm-config] Bootstrapped local mirrors config"
echo "[bootstrap-local-swiftpm-config] Source: $REFERENCE_MIRRORS"
echo "[bootstrap-local-swiftpm-config] Target: $LOCAL_MIRRORS"
