#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(pwd)}"
python3 "$ROOT/scripts/deps/verify-native-source.py" "$ROOT"
python3 -I "$ROOT/scripts/deps/verify-build-tools.py" "$ROOT"
echo "[check-dependency-contracts] Native sources, package pins and source-built tools verified"
