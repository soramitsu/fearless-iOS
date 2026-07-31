#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT_DIR/scripts/audit-codecov-coverage-contract.sh"
SOURCE="$ROOT_DIR/.github/workflows/codecov.yml"
mkdir -p "$ROOT_DIR/build/test-tmp"
tmp_dir="$(mktemp -d "$ROOT_DIR/build/test-tmp/codecov-coverage-contract.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "[codecov-coverage-contract-test][error] $*" >&2
  exit 1
}

expect_rejected() {
  local label="$1"
  local workflow="$tmp_dir/$negative_count.yml"
  local output="$tmp_dir/$negative_count.log"
  cp "$SOURCE" "$workflow"
  shift
  "$@" "$workflow"
  if "$AUDIT" "$workflow" > "$output" 2>&1; then
    fail "$label unexpectedly passed"
  fi
  negative_count=$((negative_count + 1))
}

delete_text() {
  local text="$1"
  local workflow="$2"
  TEXT="$text" perl -0pi -e 's/\Q$ENV{TEXT}\E//' "$workflow"
}

replace_text() {
  local from="$1"
  local to="$2"
  local workflow="$3"
  FROM="$from" TO="$to" perl -0pi -e \
    's/\Q$ENV{FROM}\E/$ENV{TO}/ or die "fixture mutation missed\n"' \
    "$workflow"
}

"$AUDIT" "$SOURCE" >/dev/null
positive_count=1
negative_count=0

expect_rejected \
  "coverage generation removed" \
  delete_text "-enableCodeCoverage YES"
expect_rejected \
  "result bundle removed" \
  delete_text '-resultBundlePath "$RESULT_BUNDLE"'
expect_rejected \
  "profdata fail-closed check removed" \
  delete_text "-type f -name '*.profdata' -print -quit"
expect_rejected \
  "profdata readability check removed" \
  delete_text 'xcrun llvm-profdata show "$COVERAGE_PROFILE"'
expect_rejected \
  "Codecov upload made non-blocking" \
  replace_text "fail_ci_if_error: true" "fail_ci_if_error: false"
expect_rejected \
  "Codecov OIDC removed" \
  replace_text \
    "use_oidc: \${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}" \
    "use_oidc: false"
expect_rejected \
  "mutable Codecov action reference" \
  replace_text \
    "codecov/codecov-action@671740ac38dd9b0130fbe1cec585b89eea48d3de" \
    "codecov/codecov-action@v7"

[[ "$positive_count" == "1" && "$negative_count" == "7" ]] ||
  fail "unexpected test counts: $positive_count positive, $negative_count negative"

echo \
  "[codecov-coverage-contract-test] $positive_count positive + $negative_count adversarial cases passed"
