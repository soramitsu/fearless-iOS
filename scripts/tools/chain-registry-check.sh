#!/usr/bin/env bash
set -euo pipefail

# Simple helper that fetches the current chain registry artifacts
# (prod/dev chains list + type bundle), prints their ETag, SHA256 and size,
# and stores the payloads under a temporary directory for manual inspection.
#
# Usage:
#   scripts/tools/chain-registry-check.sh
#   scripts/tools/chain-registry-check.sh <workspace-root>
#
# Requires: curl, shasum (macOS) or sha256sum (Linux), mktemp

ROOT="${1:-$(pwd)}"
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/chain-registry.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

declare -a TARGETS=(
  "prod|https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/chains/v13/chains.json"
  "dev|https://raw.githubusercontent.com/soramitsu/shared-features-utils/develop-free/chains/v13/chains_dev.json"
  "types|https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/chains/all_chains_types.json"
)

echo "[chain-registry] Inspecting upstream artifacts (tmp: $TMP_DIR)"

for target in "${TARGETS[@]}"; do
  label="${target%%|*}"
  url="${target#*|}"
  headers="$TMP_DIR/${label}.headers"
  payload="$TMP_DIR/${label}.json"

  echo ""
  echo "[chain-registry] => Fetching $label"
  curl -sS -D "$headers" -o "$payload" "$url"

  if command -v shasum >/dev/null 2>&1; then
    sha=$(shasum -a 256 "$payload" | awk '{print $1}')
  else
    sha=$(sha256sum "$payload" | awk '{print $1}')
  fi
  size=$(wc -c < "$payload" | tr -d ' ')
  etag=$(grep -i '^etag:' "$headers" | awk '{print $2}' | tr -d '"\r')
  last_mod=$(grep -i '^last-modified:' "$headers" | cut -d' ' -f2- || true)

  echo "[chain-registry] URL   : $url"
  echo "[chain-registry] ETag  : ${etag:-unknown}"
  echo "[chain-registry] Size  : ${size} bytes"
  echo "[chain-registry] SHA256: $sha"
  echo "[chain-registry] Saved : $payload"
  [[ -n "$last_mod" ]] && echo "[chain-registry] Last-Modified: $last_mod"
done

echo ""
echo "[chain-registry] Done. Payloads are available under $TMP_DIR for manual diffing."
