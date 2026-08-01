#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT_DIR/scripts/audit-release-signing-gate.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "[release-signing-gate-audit-test][error] $*" >&2
  exit 1
}

reset_fixture() {
  rm -rf "$TMP_DIR/fixture"
  mkdir -p "$TMP_DIR/fixture/scripts/ci" "$TMP_DIR/fixture/.github/workflows" \
    "$TMP_DIR/fixture/fearless.xcodeproj/xcshareddata/xcschemes"
  cp "$ROOT_DIR/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme" \
    "$TMP_DIR/fixture/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme"
  cp "$ROOT_DIR/.github/workflows/codecov.yml" \
    "$TMP_DIR/fixture/.github/workflows/codecov.yml"
  cp "$ROOT_DIR/scripts/ci/run-pr.sh" "$TMP_DIR/fixture/scripts/ci/run-pr.sh"
  cp "$ROOT_DIR/scripts/ci/run-release-signing-gate.sh" \
    "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
  cp "$ROOT_DIR/scripts/ci/run-release-signing-ci.sh" \
    "$TMP_DIR/fixture/scripts/ci/run-release-signing-ci.sh"
  cp "$ROOT_DIR/scripts/test-release-signing-bootstrap.sh" \
    "$TMP_DIR/fixture/scripts/test-release-signing-bootstrap.sh"
}

run_audit() {
  IOS_RELEASE_GATE_AUDIT_SCHEME_FILE="$TMP_DIR/fixture/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme" \
  IOS_RELEASE_GATE_AUDIT_WORKFLOW_FILE="$TMP_DIR/fixture/.github/workflows/codecov.yml" \
  IOS_RELEASE_GATE_AUDIT_RUN_PR_FILE="$TMP_DIR/fixture/scripts/ci/run-pr.sh" \
  IOS_RELEASE_GATE_AUDIT_GATE_FILE="$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh" \
  IOS_RELEASE_GATE_AUDIT_BOOTSTRAP_FILE="$TMP_DIR/fixture/scripts/ci/run-release-signing-ci.sh" \
  IOS_RELEASE_GATE_AUDIT_BOOTSTRAP_TEST_FILE="$TMP_DIR/fixture/scripts/test-release-signing-bootstrap.sh" \
    "$AUDIT" >/dev/null 2>&1
}

expect_failure() {
  local label="$1"
  if run_audit; then
    fail "$label was accepted"
  fi
}

reset_fixture
run_audit || fail "valid release-signing gate was rejected"

reset_fixture
perl -0pi -e 's/; then\n  echo \\&quot;error:/ || true; then\n  echo \\&quot;error:/' \
  "$TMP_DIR/fixture/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme"
expect_failure "fail-open archive preaction"

reset_fixture
perl -0pi -e 's/export STRICT_REQUIRED_PATCHES=1/export STRICT_REQUIRED_PATCHES=0/' \
  "$TMP_DIR/fixture/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme"
expect_failure "non-strict archive dependency patching"

reset_fixture
perl -0pi -e 's/(<ArchiveAction\s+buildConfiguration = )"Release"/$1"Dev"/' \
  "$TMP_DIR/fixture/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme"
expect_failure "non-Release archive action"

reset_fixture
perl -0pi -e 's/bash \.\/scripts\/ci\/run-release-signing-ci\.sh/echo removed-release-gate/' \
  "$TMP_DIR/fixture/.github/workflows/codecov.yml"
expect_failure "workflow without real signed archive gate"

reset_fixture
perl -0pi -e 's/if: github\.event_name == '\''push'\''/if: always()/' \
  "$TMP_DIR/fixture/.github/workflows/codecov.yml"
expect_failure "signing untrusted pull requests"

reset_fixture
perl -0pi -e "s/IOS_RELEASE_SIGNING_REQUIRED: '1'/IOS_RELEASE_SIGNING_REQUIRED: '0'/" \
  "$TMP_DIR/fixture/.github/workflows/codecov.yml"
expect_failure "optional trusted-push signing"

reset_fixture
perl -0pi -e 's/secrets\.IOS_RELEASE_PROVISIONING_PROFILE_BASE64/secrets.REMOVED_PROFILE/' \
  "$TMP_DIR/fixture/.github/workflows/codecov.yml"
expect_failure "workflow missing provisioning-profile secret"

reset_fixture
perl -0pi -e 's/bash \.\/scripts\/ci\/run-release-signing-ci\.sh/bash .\/scripts\/ci\/run-release-signing-gate.sh/' \
  "$TMP_DIR/fixture/.github/workflows/codecov.yml"
expect_failure "workflow bypassing ephemeral bootstrap"

reset_fixture
perl -0pi -e 's/\[\[ "\$\{GITHUB_EVENT_NAME:-\}" == "push" \]\]/true/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "gate without an internal trusted-event guard"

reset_fixture
perl -0pi -e 's/refs\/heads\/develop\|refs\/heads\/master/refs\/heads\/*/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "gate without a release-branch guard"

reset_fixture
perl -0pi -e 's/bash "\$WORKSPACE_DIR\/scripts\/test-release-signing-gate\.sh"/echo removed-behavioral-test/' \
  "$TMP_DIR/fixture/scripts/ci/run-pr.sh"
expect_failure "PR CI without behavioral gate tests"

reset_fixture
perl -0pi -e 's/-configuration Release/-configuration Debug/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "Debug archive substitution"

reset_fixture
perl -0pi -e "s/generic\/platform=iOS/platform=iOS Simulator,name=iPhone 16/" \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "simulator signing substitution"

reset_fixture
perl -0pi -e 's/--verify --deep --strict/--verify/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "weakened signature verification"

reset_fixture
perl -0pi -e 's/profile_matches_release_contract "\$embedded_profile"/true # removed profile validation/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "removed embedded-profile validation"

reset_fixture
perl -0pi -e 's{profile_supports_value \\}{profile_supports_value_removed \\}g' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "removed wildcard-aware profile authorization"

reset_fixture
perl -0pi -e 's/"\$value" == "\*" \|\| "\$value" == "\$expected"/"\$value" == "\$expected"/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "removed Apple string-wildcard authorization"

reset_fixture
perl -0pi -e 's/plist_array_contains "\$profile" "\$key_path" "\*"/false/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "removed Apple array-wildcard authorization"

reset_fixture
perl -0pi -e 's/\[\[ "\$signed_get_task_allow" == "false" && "\$profile_get_task_allow" == "false" \]\]/true/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "development profile accepted"

reset_fixture
perl -0pi -e "s/'Entitlements\.beta-reports-active'/'Entitlements.removed-beta-reporting'/" \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "profile beta-report entitlement removed"

reset_fixture
perl -0pi -e 's/delete-keychain "\$keychain_path"/true # keychain deletion removed/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-ci.sh"
expect_failure "ephemeral keychain cleanup removed"

reset_fixture
perl -0pi -e 's/Release-signing secrets are only partially configured/Partial signing material accepted/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-ci.sh"
expect_failure "partial signing configuration guard removed"

reset_fixture
perl -0pi -e 's/chmod 600 "\$build_log"/chmod 644 "\$build_log"/' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "world-readable archive log"

reset_fixture
perl -0pi -e 's/s\/\(Signing Identity:\)\.\*\/\\1 \[REDACTED\]\///' \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "removed signing-identity redaction"

reset_fixture
printf '\necho "$identity_output"\n' >> \
  "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "direct signing-identity output"

reset_fixture
printf '\nset -x\nprintenv\n' >> "$TMP_DIR/fixture/scripts/ci/run-release-signing-gate.sh"
expect_failure "signing environment dump"

echo "[release-signing-gate-audit-test] all adversarial fixtures passed"
