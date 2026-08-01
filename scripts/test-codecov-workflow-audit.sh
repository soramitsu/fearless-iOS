#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT_DIR/scripts/audit-codecov-workflow.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
fixture="$tmp_dir/codecov.yml"

fail() {
  echo "[codecov-workflow-audit-test][error] $*" >&2
  exit 1
}

reset_fixture() {
  cp "$ROOT_DIR/.github/workflows/codecov.yml" "$fixture"
}

run_audit() {
  IOS_CODECOV_AUDIT_WORKFLOW_FILE="$fixture" "$AUDIT" >/dev/null 2>&1
}

expect_failure() {
  local label="$1"
  if run_audit; then
    fail "$label was accepted"
  fi
}

remove_line() {
  local needle="$1"
  awk -v needle="$needle" 'index($0, needle) == 0 { print }' "$fixture" > "$fixture.next"
  mv "$fixture.next" "$fixture"
}

comment_line() {
  local needle="$1"
  awk -v needle="$needle" '
    index($0, needle) != 0 { print "# " $0; next }
    { print }
  ' "$fixture" > "$fixture.next"
  mv "$fixture.next" "$fixture"
}

reset_fixture
run_audit || fail "valid Codecov workflow was rejected"

reset_fixture
sed -i.bak 's/codecov\/codecov-action@[0-9a-f]*/codecov\/codecov-action@v5/' "$fixture"
expect_failure "unpinned Codecov action"

reset_fixture
comment_line 'codecov/codecov-action@'
expect_failure "commented-out pinned Codecov action"

reset_fixture
sed -i.bak 's/actions\/checkout@[0-9a-f]*/actions\/checkout@v4/' "$fixture"
expect_failure "unpinned checkout action"

reset_fixture
sed -i.bak 's/actions\/upload-artifact@[0-9a-f]*/actions\/upload-artifact@v4/' "$fixture"
expect_failure "unpinned artifact upload action"

reset_fixture
remove_line 'fail_ci_if_error: true'
expect_failure "fail-open Codecov upload"

reset_fixture
remove_line 'swift_project: fearless'
expect_failure "Codecov upload for the wrong Swift project"

reset_fixture
remove_line 'id-token: write'
expect_failure "Codecov upload without OIDC permission"

reset_fixture
remove_line 'use_oidc:'
expect_failure "Codecov upload without trusted-event OIDC"

reset_fixture
remove_line 'test-codecov-workflow-audit.sh'
expect_failure "CI without uploader audit self-test"

reset_fixture
remove_line 'bash ./scripts/audit-codecov-workflow.sh'
expect_failure "CI without real uploader audit"

reset_fixture
perl -0pi -e 's/contents: read/contents: write/' "$fixture"
expect_failure "unnecessary repository write permission"

reset_fixture
printf '\n      - run: bash <(curl -s https://codecov.io/bash)\n' >> "$fixture"
expect_failure "unverified curl-to-shell uploader"

reset_fixture
printf '\n      - run: curl -fsSL https://codecov.io/bash | sh\n' >> "$fixture"
expect_failure "piped unverified uploader"

echo "[codecov-workflow-audit-test] all adversarial fixtures passed"
