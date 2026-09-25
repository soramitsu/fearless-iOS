#!/usr/bin/env bash
set -euo pipefail

# Compatibility entry point. Resolved dependency sources are immutable.
ROOT="${1:-$(pwd)}"
exec python3 "$ROOT/scripts/deps/verify-shared-features-source.py" "$ROOT"
