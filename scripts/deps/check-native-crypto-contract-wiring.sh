#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"

fail() {
  echo "[check-native-crypto-contract-wiring] $1" >&2
  exit 1
}

ensure_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  [[ -f "$file" ]] || fail "Missing file: $file"
  /usr/bin/grep -Fq "$pattern" "$file" || fail "$label"
}

ensure_absent() {
  local pattern="$1"
  local label="$2"

  # Release workspaces contain ignored DerivedData, archives, and package
  # checkouts. Search the reviewed source index so generated binaries cannot
  # turn this source-wiring assertion into an unbounded filesystem crawl.
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fail "Root is not a Git worktree: $ROOT"
  if git -C "$ROOT" grep -nF "$pattern" \
    -- . \
    ":(exclude)scripts/deps/$(basename "$0")" >/dev/null 2>&1; then
    fail "$label"
  fi
}

ensure_contains \
  "$ROOT/scripts/test-matrix.sh" \
  "scripts/deps/verify-shared-features-source.py" \
  "test-matrix.sh is not wired to verify-shared-features-source.py"

ensure_contains \
  "$ROOT/scripts/dev-setup.sh" \
  "scripts/deps/verify-shared-features-source.py" \
  "dev-setup.sh is not wired to verify-shared-features-source.py"

ensure_contains \
  "$ROOT/scripts/ci/bootstrap.sh" \
  "scripts/deps/verify-shared-features-source.py" \
  "ci/bootstrap.sh is not wired to verify-shared-features-source.py"

ensure_contains \
  "$ROOT/scripts/ci/run-pr.sh" \
  "scripts/deps/verify-shared-features-source.py" \
  "ci/run-pr.sh is not wired to verify-shared-features-source.py"

ensure_absent "scripts/spm-iroha-hotfix.sh" "Legacy spm-iroha-hotfix.sh reference still exists"
ensure_absent "apply-native-crypto-contracts.sh" "Removed apply-native-crypto-contracts.sh reference still exists"

echo "[check-native-crypto-contract-wiring] OK"
