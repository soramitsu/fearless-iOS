#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="${1:-$ROOT_DIR/.github/workflows/codecov.yml}"

fail() {
  echo "[codecov-coverage-contract][error] $*" >&2
  exit 1
}

[[ -f "$WORKFLOW" && ! -L "$WORKFLOW" ]] ||
  fail "Codecov workflow must be a regular, non-symlink file."

require_text() {
  local text="$1"
  grep -Fq -- "$text" "$WORKFLOW" ||
    fail "Codecov workflow is missing required coverage control: $text"
}

require_text "persist-credentials: false"
require_text "-enableCodeCoverage YES"
require_text '-resultBundlePath "$RESULT_BUNDLE"'
require_text "-type f -name '*.profdata' -print -quit"
require_text 'xcrun llvm-profdata show "$COVERAGE_PROFILE"'
require_text 'test -d "$RESULT_BUNDLE"'
require_text "plugins: xcode"
require_text "swift_project: fearless"
require_text "fail_ci_if_error: true"
require_text "use_oidc: true"

if grep -Eq 'codecov/codecov-action@(main|master|v[0-9]+)[[:space:]#]' "$WORKFLOW"; then
  fail "Codecov action must use an immutable full commit SHA."
fi

echo "[codecov-coverage-contract] executable coverage and upload contract passed"
