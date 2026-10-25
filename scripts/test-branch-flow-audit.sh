#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-branch-flow.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

write_valid_repo() {
  local repo="$1"
  mkdir -p "$repo/.github/workflows"
  cat > "$repo/Jenkinsfile" <<'EOF'
def appPipeline = new org.ios.AppPipeline(
  uploadToNexusFor: ['master','develop']
)
EOF
  cat > "$repo/.github/workflows/codecov.yml" <<'EOF'
name: Codecov Fearless
on:
  push:
    branches:
      - develop
      - master
  pull_request:
    branches:
      - develop
      - master
jobs:
  build:
    runs-on: macOS-latest
    steps:
      - run: echo build
  jenkins-pr-merge:
    name: continuous-integration/jenkins/pr-merge
    runs-on: ubuntu-latest
    needs: build
    if: always()
    steps:
      - run: |
          if [[ "${{ needs.build.result }}" != "success" ]]; then
            exit 1
          fi
EOF
}

expect_pass() {
  local repo="$1"
  bash "$AUDIT_SCRIPT" "$repo" >/dev/null
}

expect_fail() {
  local repo="$1"
  local label="$2"
  local output="$TMP_DIR/$label.out"
  if bash "$AUDIT_SCRIPT" "$repo" >"$output" 2>&1; then
    echo "[branch-flow-audit-test] ERROR: expected failure for $label" >&2
    exit 1
  fi
  if ! grep -q "ERROR" "$output"; then
    echo "[branch-flow-audit-test] ERROR: $label failed without an audit error" >&2
    cat "$output" >&2
    exit 1
  fi
}

VALID_REPO="$TMP_DIR/valid"
write_valid_repo "$VALID_REPO"
expect_pass "$VALID_REPO"

JENKINS_STAGING_REPO="$TMP_DIR/jenkins-staging"
write_valid_repo "$JENKINS_STAGING_REPO"
cat > "$JENKINS_STAGING_REPO/Jenkinsfile" <<'EOF'
def appPipeline = new org.ios.AppPipeline(
  uploadToNexusFor: ['master','develop','staging']
)
EOF
expect_fail "$JENKINS_STAGING_REPO" "jenkins-staging"

WORKFLOW_STAGING_REPO="$TMP_DIR/workflow-staging"
write_valid_repo "$WORKFLOW_STAGING_REPO"
cat > "$WORKFLOW_STAGING_REPO/.github/workflows/codecov.yml" <<'EOF'
name: Codecov Fearless
on:
  push:
    branches:
      - develop
      - master
      - staging
EOF
expect_fail "$WORKFLOW_STAGING_REPO" "workflow-staging"

MISSING_UPLOAD_REPO="$TMP_DIR/missing-upload"
write_valid_repo "$MISSING_UPLOAD_REPO"
cat > "$MISSING_UPLOAD_REPO/Jenkinsfile" <<'EOF'
def appPipeline = new org.ios.AppPipeline(
  appTests: false
)
EOF
expect_fail "$MISSING_UPLOAD_REPO" "missing-upload"

MISSING_JENKINS_CONTEXT_REPO="$TMP_DIR/missing-jenkins-context"
write_valid_repo "$MISSING_JENKINS_CONTEXT_REPO"
perl -0pi -e 's/\n  jenkins-pr-merge:.*//s' "$MISSING_JENKINS_CONTEXT_REPO/.github/workflows/codecov.yml"
expect_fail "$MISSING_JENKINS_CONTEXT_REPO" "missing-jenkins-context"

DETACHED_JENKINS_CONTEXT_REPO="$TMP_DIR/detached-jenkins-context"
write_valid_repo "$DETACHED_JENKINS_CONTEXT_REPO"
perl -0pi -e 's/\n    needs: build//' "$DETACHED_JENKINS_CONTEXT_REPO/.github/workflows/codecov.yml"
expect_fail "$DETACHED_JENKINS_CONTEXT_REPO" "detached-jenkins-context"

UNGUARDED_JENKINS_CONTEXT_REPO="$TMP_DIR/unguarded-jenkins-context"
write_valid_repo "$UNGUARDED_JENKINS_CONTEXT_REPO"
perl -0pi -e 's/needs\.build\.result/build.result.removed/' "$UNGUARDED_JENKINS_CONTEXT_REPO/.github/workflows/codecov.yml"
expect_fail "$UNGUARDED_JENKINS_CONTEXT_REPO" "unguarded-jenkins-context"

echo "[branch-flow-audit-test] Branch flow audit self-test passed."
