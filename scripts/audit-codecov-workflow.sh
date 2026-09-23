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
  'codecov/codecov-action@fb8b3582c8e4def4969c97caa2f19720cb33a72f' \
  'Codecov action must be pinned to the reviewed v7.0.0 commit with the live codecovsecops verification-key endpoint.'
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

# Exact-source reports need bootstrap's resolved checkouts, and must fail before
# any simulator build can consume them. Audit the reviewed workflow step format.
python3 - "$WORKFLOW_FILE" <<'PYTHON'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
steps = list(re.finditer(r"^      - name: (.+)$", text, re.MULTILINE))
required = (
    ("Bootstrap Dependencies", r"^          bash scripts/ci/bootstrap\.sh$"),
    ("Shared-features delta report", r'^          bash \./scripts/deps/audit-shared-features-delta-report\.sh "\$\(pwd\)" --write-report build/reports/shared-features-delta-report\.json$'),
    ("Build & Test (Simulator)", None),
)
positions = []
for name, command in required:
    matches = [(index, step) for index, step in enumerate(steps) if step.group(1) == name]
    if len(matches) != 1:
        raise SystemExit(f"[codecov-workflow-audit][error] Require exactly one dependency pipeline step: {name}")
    index, step = matches[0]
    positions.append(step.start())
    end = steps[index + 1].start() if index + 1 < len(steps) else len(text)
    block = text[step.end():end]
    if command is not None:
        if not re.search(command, block, re.MULTILINE):
            raise SystemExit(f"[codecov-workflow-audit][error] Required active command missing from {name}")
        if re.search(r"^        (?:if|continue-on-error):", block, re.MULTILINE):
            raise SystemExit(f"[codecov-workflow-audit][error] Dependency pipeline step must remain unconditional and fail closed: {name}")
if positions != sorted(positions):
    raise SystemExit("[codecov-workflow-audit][error] Dependency bootstrap must precede the exact-source report, and the report must precede simulator build/test")
PYTHON

echo "[codecov-workflow-audit] passed"
