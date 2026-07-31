#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_FILE="${IOS_CODECOV_AUDIT_WORKFLOW_FILE:-$ROOT_DIR/.github/workflows/codecov.yml}"

fail() {
  echo "[codecov-workflow-audit][error] $*" >&2
  exit 1
}

require_active_text() {
  local value="$1"
  local message="$2"
  grep -F -- "$value" "$WORKFLOW_FILE" |
    grep -Eq '^[[:space:]]*[^#[:space:]]' || fail "$message"
}

[[ -f "$WORKFLOW_FILE" ]] || fail "Missing Codecov workflow: $WORKFLOW_FILE"

if grep -Eq 'codecov\.io/bash|bash[[:space:]]+<\([[:space:]]*curl|curl[^|]*\|[[:space:]]*(ba)?sh' "$WORKFLOW_FILE"; then
  fail "Codecov workflow may not download and execute an unverified shell script."
fi

require_active_text \
  'codecov/codecov-action@671740ac38dd9b0130fbe1cec585b89eea48d3de' \
  'Codecov action must be pinned to the reviewed v5.5.2 commit.'
require_active_text \
  'actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5' \
  'Codecov workflow checkout action must be pinned.'
require_active_text \
  'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02' \
  'Codecov workflow artifact upload action must be pinned.'
require_active_text 'contents: read' 'Codecov workflow must use read-only repository contents permission.'
require_active_text 'fail_ci_if_error: true' 'Codecov upload failures must fail CI.'
require_active_text 'swift_project: fearless' 'Codecov must upload the Fearless Swift project coverage.'
require_active_text 'id-token: write' 'Trusted Codecov uploads require OIDC permission.'
require_active_text \
  "use_oidc: \${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}" \
  'Codecov must use OIDC for trusted events and preserve tokenless fork PR uploads.'
require_active_text \
  'bash ./scripts/test-codecov-workflow-audit.sh' \
  'Codecov CI must run the uploader audit adversarial self-test.'
require_active_text \
  'bash ./scripts/audit-codecov-workflow.sh' \
  'Codecov CI must audit the real workflow.'

if grep -Eq '^[[:space:]]*(contents|actions|pull-requests|checks):[[:space:]]+write([[:space:]]|$)' "$WORKFLOW_FILE"; then
  fail "Codecov workflow grants an unnecessary repository write permission."
fi

unpinned="$(grep -E '^[[:space:]]*uses:[[:space:]]+' "$WORKFLOW_FILE" | grep -Ev '@[0-9a-f]{40}([[:space:]]|$)' || true)"
[[ -z "$unpinned" ]] || fail "Workflow action reference is not a full commit SHA: $unpinned"

echo "[codecov-workflow-audit] passed"
