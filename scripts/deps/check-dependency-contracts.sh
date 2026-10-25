#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(pwd)}"
python3 "$ROOT/scripts/deps/verify-native-source.py" "$ROOT"
echo "[check-dependency-contracts] App-owned native sources and external package pins verified"
