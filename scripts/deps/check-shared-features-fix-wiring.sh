#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"

fail() {
  echo "[check-shared-features-fix-wiring] $1" >&2
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
  local file="$1"
  local pattern="$2"
  local label="$3"

  [[ -f "$file" ]] || fail "Missing file: $file"
  if /usr/bin/grep -F "$pattern" "$file" >/dev/null 2>&1; then
    fail "$label"
  fi
}

ensure_contains \
  "$ROOT/scripts/test-matrix.sh" \
  'STRICT_REQUIRED_PATCHES=1 scripts/spm-shared-features-fixes.sh "$(pwd)"' \
  "test-matrix.sh is not wired to required shared-features-spm fixes"

ensure_contains \
  "$ROOT/scripts/dev-setup.sh" \
  'STRICT_REQUIRED_PATCHES=1 bash scripts/spm-shared-features-fixes.sh "$(pwd)"' \
  "dev-setup.sh is not wired to required shared-features-spm fixes"

ensure_contains \
  "$ROOT/scripts/ci/bootstrap.sh" \
  'STRICT_REQUIRED_PATCHES=1 bash scripts/spm-shared-features-fixes.sh "$WORKSPACE_DIR"' \
  "ci/bootstrap.sh is not wired to required shared-features-spm fixes"

ensure_contains \
  "$ROOT/scripts/ci/run-pr.sh" \
  'STRICT_REQUIRED_PATCHES=1 bash scripts/spm-shared-features-fixes.sh "$WORKSPACE_DIR"' \
  "ci/run-pr.sh is not wired to required shared-features-spm fixes"

ensure_absent \
  "$ROOT/scripts/dev-setup.sh" \
  'spm-shared-features-fixes.sh "$(pwd)" || true' \
  "dev-setup.sh still treats shared-features-spm fixes as optional"

ensure_absent \
  "$ROOT/scripts/ci/bootstrap.sh" \
  'spm-shared-features-fixes.sh "$WORKSPACE_DIR" || true' \
  "ci/bootstrap.sh still treats shared-features-spm fixes as optional"

ensure_absent \
  "$ROOT/scripts/ci/run-pr.sh" \
  'spm-shared-features-fixes.sh "$WORKSPACE_DIR" || true' \
  "ci/run-pr.sh still treats shared-features-spm fixes as optional"

echo "[check-shared-features-fix-wiring] OK"
