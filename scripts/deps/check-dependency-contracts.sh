#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"

RESTORE_SCRIPT="$ROOT/scripts/deps/restore-swiftpm-contract-files.sh"

if [[ -x "$RESTORE_SCRIPT" ]]; then
  "$RESTORE_SCRIPT" "$ROOT" "[check-dependency-contracts]"
fi

run_check() {
  local script_path="$1"
  local label="$2"

  if [[ ! -x "$script_path" ]]; then
    echo "[check-dependency-contracts] Missing helper: $script_path" >&2
    exit 1
  fi

  echo "[check-dependency-contracts] ${label}"
  "$script_path" "$ROOT"
}

run_check "$ROOT/scripts/deps/check-swiftpm-consistency.sh" "Validating committed SwiftPM state"
run_check "$ROOT/scripts/deps/check-native-crypto-contract-wiring.sh" "Validating native crypto contract wiring"
run_check "$ROOT/scripts/deps/check-shared-features-fix-wiring.sh" "Validating shared-features fix wiring"

echo "[check-dependency-contracts] OK"
