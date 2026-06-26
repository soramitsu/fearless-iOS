#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
FAILURES=0

record_failure() {
  echo "[branch-flow-audit] ERROR: $*" >&2
  FAILURES=1
}

scan_for_staging() {
  local file="$1"
  local matches
  matches="$(grep -nE '(^|[^[:alnum:]_])staging([^[:alnum:]_]|$)' "$file" || true)"
  if [[ -n "$matches" ]]; then
    record_failure "staging branch reference found in ${file#$ROOT_DIR/}:"
    printf '%s\n' "$matches" >&2
  fi
}

if [[ ! -d "$ROOT_DIR" ]]; then
  record_failure "repo root does not exist: $ROOT_DIR"
fi

JENKINSFILE="$ROOT_DIR/Jenkinsfile"
if [[ ! -f "$JENKINSFILE" ]]; then
  record_failure "Jenkinsfile is missing"
else
  scan_for_staging "$JENKINSFILE"
  UPLOAD_LINE="$(grep -nE 'uploadToNexusFor[[:space:]]*:' "$JENKINSFILE" || true)"
  if [[ -z "$UPLOAD_LINE" ]]; then
    record_failure "Jenkinsfile must declare uploadToNexusFor for release upload branches"
  elif [[ "$UPLOAD_LINE" != *master* || "$UPLOAD_LINE" != *develop* ]]; then
    record_failure "Jenkinsfile uploadToNexusFor must include only releasable master and integration develop branches"
    printf '%s\n' "$UPLOAD_LINE" >&2
  fi
fi

WORKFLOW_DIR="$ROOT_DIR/.github/workflows"
if [[ ! -d "$WORKFLOW_DIR" ]]; then
  record_failure ".github/workflows is missing"
else
  WORKFLOW_COUNT=0
  while IFS= read -r -d '' workflow; do
    WORKFLOW_COUNT=$((WORKFLOW_COUNT + 1))
    scan_for_staging "$workflow"
  done < <(find "$WORKFLOW_DIR" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

  if [[ "$WORKFLOW_COUNT" -eq 0 ]]; then
    record_failure "no GitHub workflow files found"
  fi

  CODECOV_WORKFLOW="$WORKFLOW_DIR/codecov.yml"
  if [[ ! -f "$CODECOV_WORKFLOW" ]]; then
    record_failure "Codecov workflow is missing"
  elif ! awk '
    /^  [A-Za-z0-9_-]+:$/ {
      if (in_job && has_name && has_needs && has_result_guard) {
        found = 1
      }
      in_job = 1
      has_name = 0
      has_needs = 0
      has_result_guard = 0
      next
    }
    in_job && /^[^[:space:]]/ {
      if (has_name && has_needs && has_result_guard) {
        found = 1
      }
      in_job = 0
    }
    in_job && /^[[:space:]]+name:[[:space:]]*continuous-integration\/jenkins\/pr-merge[[:space:]]*$/ {
      has_name = 1
    }
    in_job && /^[[:space:]]+needs:[[:space:]]*build[[:space:]]*$/ {
      has_needs = 1
    }
    in_job && index($0, "needs.build.result") > 0 {
      has_result_guard = 1
    }
    END {
      if (in_job && has_name && has_needs && has_result_guard) {
        found = 1
      }
      exit(found ? 0 : 1)
    }
  ' "$CODECOV_WORKFLOW"; then
    record_failure "Codecov workflow must publish continuous-integration/jenkins/pr-merge backed by the build job result"
  fi
fi

if [[ "$FAILURES" -ne 0 ]]; then
  exit 1
fi

echo "[branch-flow-audit] Branch flow audit passed."
