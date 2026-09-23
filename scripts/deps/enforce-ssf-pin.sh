#!/usr/bin/env bash
set -euo pipefail

# Historical entry point now verifies pins instead of rewriting them.
ROOT="${2:-$(pwd)}"
EXPECTED="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["revision"])' "$ROOT/config/shared-features-source.json")"
if [[ -n "${1:-}" && "$1" != "$EXPECTED" ]]; then
  echo "[enforce-ssf-pin] Refusing a revision outside the source contract" >&2
  exit 1
fi
exec python3 "$ROOT/scripts/deps/verify-shared-features-source.py" "$ROOT" --pins-only
