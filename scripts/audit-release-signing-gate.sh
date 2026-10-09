#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME_FILE="${IOS_RELEASE_GATE_AUDIT_SCHEME_FILE:-$ROOT_DIR/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme}"
WORKFLOW_FILE="${IOS_RELEASE_GATE_AUDIT_WORKFLOW_FILE:-$ROOT_DIR/.github/workflows/codecov.yml}"
RUN_PR_FILE="${IOS_RELEASE_GATE_AUDIT_RUN_PR_FILE:-$ROOT_DIR/scripts/ci/run-pr.sh}"
GATE_FILE="${IOS_RELEASE_GATE_AUDIT_GATE_FILE:-$ROOT_DIR/scripts/ci/run-release-signing-gate.sh}"
BOOTSTRAP_FILE="${IOS_RELEASE_GATE_AUDIT_BOOTSTRAP_FILE:-$ROOT_DIR/scripts/ci/run-release-signing-ci.sh}"
BOOTSTRAP_TEST_FILE="${IOS_RELEASE_GATE_AUDIT_BOOTSTRAP_TEST_FILE:-$ROOT_DIR/scripts/test-release-signing-bootstrap.sh}"

fail() {
  echo "[release-signing-gate-audit][error] $*" >&2
  exit 1
}

require_literal() {
  local file="$1"
  local literal="$2"
  local message="$3"
  grep -Fq -- "$literal" "$file" || fail "$message"
}

require_active_literal() {
  local file="$1"
  local literal="$2"
  local message="$3"
  awk -v expected="$literal" '
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      if (line == expected) found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$file" || fail "$message"
}

for required_file in "$SCHEME_FILE" "$WORKFLOW_FILE" "$RUN_PR_FILE" "$GATE_FILE" "$BOOTSTRAP_FILE" "$BOOTSTRAP_TEST_FILE"; do
  [[ -f "$required_file" ]] || fail "Missing release-signing gate input: $required_file"
done

archive_action="$(sed -n '/<ArchiveAction/,/<\/ArchiveAction>/p' "$SCHEME_FILE")"
grep -Fq 'buildConfiguration = "Release"' <<<"$archive_action" ||
  fail 'ArchiveAction must use the Release configuration.'
require_literal "$SCHEME_FILE" 'export STRICT_REQUIRED_PATCHES=1' \
  'The manual archive preaction must enforce required dependency patches.'
require_literal "$SCHEME_FILE" 'export ALLOW_DERIVEDDATA_FALLBACK=0' \
  'The manual archive preaction must use the repository-owned package checkout.'
require_literal "$SCHEME_FILE" 'if ! bash \&quot;${PROJECT_DIR}/scripts/spm-shared-features-fixes.sh\&quot;' \
  'The manual archive preaction must check dependency-patch failure explicitly.'
require_literal "$SCHEME_FILE" 'error: Required shared-features compatibility fixes failed.' \
  'The manual archive preaction must provide actionable failure diagnostics.'
if grep -Eq 'spm-shared-features-fixes\.sh[^<]*[|][|][[:space:]]*true' "$SCHEME_FILE"; then
  fail 'The manual archive preaction must not ignore dependency-patch failures.'
fi

require_active_literal "$WORKFLOW_FILE" 'bash ./scripts/test-release-signing-gate-audit.sh' \
  'GitHub CI must run the release-signing gate mutation self-test.'
require_active_literal "$WORKFLOW_FILE" 'bash ./scripts/test-release-signing-gate.sh' \
  'GitHub CI must run the behavioral release-signing gate self-test.'
require_active_literal "$WORKFLOW_FILE" 'bash ./scripts/test-release-signing-bootstrap.sh' \
  'GitHub CI must run the signing-bootstrap behavioral self-test.'
require_active_literal "$WORKFLOW_FILE" 'bash ./scripts/audit-release-signing-gate.sh' \
  'GitHub CI must audit the real release-signing gate.'
signed_gate_step="$(awk '
  /^      - name: Signed Release archive gate$/ { capture = 1 }
  capture {
    if (seen && /^      - name:/) exit
    print
    seen = 1
  }
' "$WORKFLOW_FILE")"
[[ -n "$signed_gate_step" ]] || fail \
  'GitHub CI must define a dedicated signed Release archive gate step.'
grep -Fqx "        if: github.event_name == 'push'" <<<"$signed_gate_step" || fail \
  'The real signing gate step must run only for trusted protected-branch pushes.'
for signed_step_line in \
  "          IOS_RELEASE_SIGNING_REQUIRED: '1'" \
  '          IOS_RELEASE_CERTIFICATE_P12_BASE64: ${{ secrets.IOS_RELEASE_CERTIFICATE_P12_BASE64 }}' \
  '          IOS_RELEASE_CERTIFICATE_PASSWORD: ${{ secrets.IOS_RELEASE_CERTIFICATE_PASSWORD }}' \
  '          IOS_RELEASE_PROVISIONING_PROFILE_BASE64: ${{ secrets.IOS_RELEASE_PROVISIONING_PROFILE_BASE64 }}' \
  '        run: bash ./scripts/ci/run-release-signing-ci.sh'; do
  grep -Fqx "$signed_step_line" <<<"$signed_gate_step" || fail \
    'Trusted GitHub CI must require and bootstrap all ephemeral Release-signing inputs in its protected step.'
done
if grep -Fq 'vars.IOS_RELEASE_SIGNING_REQUIRED' <<<"$signed_gate_step"; then
  fail 'Trusted release CI must not make signed archive validation optional through a repository variable.'
fi

require_active_literal "$RUN_PR_FILE" 'bash "$WORKSPACE_DIR/scripts/test-release-signing-gate-audit.sh"' \
  'PR CI must run the release-signing gate mutation self-test.'
require_active_literal "$RUN_PR_FILE" 'bash "$WORKSPACE_DIR/scripts/test-release-signing-gate.sh"' \
  'PR CI must run the behavioral release-signing gate self-test.'
require_active_literal "$RUN_PR_FILE" 'bash "$WORKSPACE_DIR/scripts/test-release-signing-bootstrap.sh"' \
  'PR CI must run the signing-bootstrap behavioral self-test.'
require_active_literal "$RUN_PR_FILE" 'bash "$WORKSPACE_DIR/scripts/audit-release-signing-gate.sh"' \
  'PR CI must audit the real release-signing gate.'

require_literal "$GATE_FILE" 'set -euo pipefail' \
  'The release-signing gate must fail on command, variable, or pipeline errors.'
require_literal "$GATE_FILE" "-configuration Release" \
  'The release-signing gate must archive the Release configuration.'
require_literal "$GATE_FILE" "-destination 'generic/platform=iOS'" \
  'The release-signing gate must target a generic iOS device.'
require_literal "$GATE_FILE" '-disableAutomaticPackageResolution' \
  'The release-signing gate must not mutate dependency resolution.'
require_literal "$GATE_FILE" 'archive >"$build_log" 2>&1' \
  'The release-signing gate must create and privately capture a real archive.'
require_literal "$GATE_FILE" '"$CODESIGN_BIN" --verify --deep --strict' \
  'The archived application signature must be strictly verified.'
require_literal "$GATE_FILE" 'profile_matches_release_contract "$embedded_profile"' \
  'The embedded profile must be validated against the production contract.'
wildcard_authorization_call_count="$(
  grep -F -c 'profile_supports_value \' "$GATE_FILE" || true
)"
[[ "$wildcard_authorization_call_count" == "3" ]] ||
  fail 'The embedded profile must authorize both associated domains and CloudKit through the wildcard-aware validator.'
require_literal "$GATE_FILE" '"$value" == "*" || "$value" == "$expected"' \
  'Apple provisioning-profile string wildcards must be recognized exactly.'
require_literal "$GATE_FILE" 'plist_array_contains "$profile" "$key_path" "*"' \
  'Apple provisioning-profile array wildcards must be recognized exactly.'
require_literal "$GATE_FILE" 'Entitlements.beta-reports-active' \
  'The embedded profile must authorize TestFlight beta reporting.'
require_literal "$GATE_FILE" "'beta-reports-active'" \
  'The signed application must carry TestFlight beta reporting.'
require_literal "$GATE_FILE" '[[ "$(plist_value "$profile" '\''Entitlements.beta-reports-active'\'' || true)" == "true" ]]' \
  'The embedded profile beta entitlement must be exactly true.'
require_literal "$GATE_FILE" '[[ "$(plist_value "$signed_entitlements" '\''beta-reports-active'\'' || true)" == "true" ]]' \
  'The signed application beta entitlement must be exactly true.'
require_literal "$GATE_FILE" 'signed_get_task_allow" == "false" && "$profile_get_task_allow" == "false"' \
  'The signed application and profile must both disable development debugging.'
require_literal "$GATE_FILE" 'ProvisionedDevices' \
  'Ad-hoc and development provisioning profiles must be rejected.'
require_literal "$GATE_FILE" 'IOS_RELEASE_EXPECTED_PROFILE_UUID' \
  'Trusted CI must bind the archive to the bootstrapped profile UUID.'
require_literal "$GATE_FILE" 'PROVISIONING_PROFILE_SPECIFIER=$PROFILE_SPECIFIER' \
  'The Release archive command must select the bootstrapped profile explicitly.'
require_literal "$GATE_FILE" 'PrivacyInfo.xcprivacy' \
  'The signed Release archive must contain the privacy manifest.'
require_literal "$GATE_FILE" 'keychain-access-groups' \
  'The signed Release archive must reject unreviewed keychain access groups.'
require_literal "$GATE_FILE" 'Signing material is only partially configured' \
  'Partially configured signing material must fail closed.'
require_literal "$GATE_FILE" 'IOS_RELEASE_SIGNING_REQUIRED' \
  'Trusted CI must be able to require signing material explicitly.'
require_literal "$GATE_FILE" '[[ "${GITHUB_EVENT_NAME:-}" == "push" ]]' \
  'The gate itself must refuse non-push GitHub events before reading signing material.'
require_literal "$GATE_FILE" 'refs/heads/develop|refs/heads/master' \
  'The gate itself must restrict signing-material access to release branches.'
require_literal "$GATE_FILE" 'chmod 600 "$build_log"' \
  'The raw archive log must be private.'
require_literal "$GATE_FILE" '[REDACTED_DIGEST]' \
  'Archive failure diagnostics must redact certificate digests.'
require_literal "$GATE_FILE" 's/(Signing Identity:).*/\1 [REDACTED]/' \
  'Archive failure diagnostics must redact signing identities.'
require_literal "$GATE_FILE" 's/(Provisioning Profile:).*/\1 [REDACTED]/' \
  'Archive failure diagnostics must redact provisioning profile details.'
require_literal "$GATE_FILE" 's/(Certificate:).*/\1 [REDACTED]/' \
  'Archive failure diagnostics must redact certificate details.'

if grep -Eq '(^|[[:space:]])set[[:space:]]+-x|(^|[[:space:]])(printenv|env)([[:space:]]|$)' "$GATE_FILE"; then
  fail 'The release-signing gate must not dump commands or environment variables.'
fi
if grep -Eq '^[[:space:]]*(echo|printf).*(identity_output|find-identity)' "$GATE_FILE"; then
  fail 'The release-signing gate must not print signing identity output.'
fi

require_literal "$BOOTSTRAP_FILE" 'set -euo pipefail' \
  'The signing bootstrap must fail closed on shell errors.'
require_literal "$BOOTSTRAP_FILE" 'GITHUB_EVENT_NAME:-}" == "push"' \
  'The signing bootstrap must reject non-push events before reading secrets.'
require_literal "$BOOTSTRAP_FILE" 'refs/heads/develop|refs/heads/master' \
  'The signing bootstrap must restrict secret use to release branches.'
require_literal "$BOOTSTRAP_FILE" 'IOS_RELEASE_SIGNING_REQUIRED:-}" == "1"' \
  'The signing bootstrap must require literal signed-archive enforcement.'
for secret_name in \
  IOS_RELEASE_CERTIFICATE_P12_BASE64 \
  IOS_RELEASE_CERTIFICATE_PASSWORD \
  IOS_RELEASE_PROVISIONING_PROFILE_BASE64; do
  require_literal "$BOOTSTRAP_FILE" "$secret_name" \
    "The signing bootstrap must consume $secret_name explicitly."
done
require_literal "$BOOTSTRAP_FILE" 'Release-signing secrets are missing' \
  'Missing signing secrets must fail closed.'
require_literal "$BOOTSTRAP_FILE" 'Release-signing secrets are only partially configured' \
  'Partially configured signing secrets must fail closed.'
require_literal "$BOOTSTRAP_FILE" 'if ((configured != 3)); then' \
  'Signing secrets must use an exact all-or-nothing cardinality gate.'
require_literal "$BOOTSTRAP_FILE" 'create-keychain' \
  'The signing bootstrap must create an ephemeral keychain.'
require_literal "$BOOTSTRAP_FILE" 'set-key-partition-list' \
  'The signing bootstrap must constrain imported certificate access.'
require_literal "$BOOTSTRAP_FILE" 'delete-keychain "$keychain_path"' \
  'The signing bootstrap must delete its ephemeral keychain.'
require_literal "$BOOTSTRAP_FILE" 'rm -f -- "$installed_profile"' \
  'The signing bootstrap must remove its installed provisioning profile.'
require_literal "$BOOTSTRAP_FILE" 'unset certificate_base64 profile_base64' \
  'The signing bootstrap must drop encoded signing material before invoking build tools.'
require_literal "$BOOTSTRAP_FILE" 'unset certificate_password' \
  'The signing bootstrap must drop the certificate password immediately after import.'
if grep -Eq '(^|[[:space:]])set[[:space:]]+-x|(^|[[:space:]])(printenv|env)([[:space:]]|$)' "$BOOTSTRAP_FILE"; then
  fail 'The signing bootstrap must not dump commands or environment variables.'
fi
require_literal "$BOOTSTRAP_TEST_FILE" 'missing signing secrets' \
  'The signing-bootstrap self-test must reject missing secret configuration.'
require_literal "$BOOTSTRAP_TEST_FILE" 'partially configured signing secrets' \
  'The signing-bootstrap self-test must reject partial secret configuration.'
require_literal "$BOOTSTRAP_TEST_FILE" 'ephemeral keychain cleanup failure' \
  'The signing-bootstrap self-test must reject cleanup failures.'
require_literal "$BOOTSTRAP_TEST_FILE" 'assert_no_secret_leak' \
  'The signing-bootstrap self-test must enforce output redaction.'

echo "[release-signing-gate-audit] passed"
