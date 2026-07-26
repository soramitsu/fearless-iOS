#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly BUILD_SCRIPT="$SCRIPT_DIR/ci/build-audited-ios-release-archive.sh"
readonly IDENTITY_AUDIT="$SCRIPT_DIR/ci/audit-ios-release-identity.sh"
readonly FIXTURES="$(mktemp -d "${TMPDIR:-/tmp}/fearless-release-archive-signing-tests.XXXXXX")"
trap 'rm -rf "$FIXTURES"' EXIT

fail() {
  printf '%s ERROR: %s\n' "[ios-release-archive-signing-test]" "$*" >&2
  exit 1
}

contains_workspace_signing_override() {
  grep -Eq \
    '^[[:space:]]*"?(CODE_SIGN_STYLE|PROVISIONING_PROFILE(_SPECIFIER)?)=' \
    "$1"
}

[[ -f "$BUILD_SCRIPT" && ! -L "$BUILD_SCRIPT" ]] ||
  fail "archive build script is missing or unsafe"
[[ -f "$IDENTITY_AUDIT" && ! -L "$IDENTITY_AUDIT" ]] ||
  fail "release identity audit is missing or unsafe"

# Command-line build-setting overrides apply to every target in a workspace.
# Profiles and manual signing must remain target-scoped, so neither is allowed
# in the xcodebuild argument vector assembled by this script.
if contains_workspace_signing_override "$BUILD_SCRIPT"; then
  fail "archive script contains a workspace-wide signing/profile override"
fi

# Prove the gate rejects both quoted/unquoted spellings and the legacy profile
# key. These mutations reproduce the class of command-line override that makes
# dependency targets fail with "does not support provisioning profiles."
override_number=0
while IFS= read -r override; do
  override_number=$((override_number + 1))
  mutant="$FIXTURES/override-$override_number.sh"
  cp "$BUILD_SCRIPT" "$mutant"
  printf '%s\n' "$override" >>"$mutant"
  contains_workspace_signing_override "$mutant" ||
    fail "gate accepted workspace-wide override mutation: $override"
done <<'OVERRIDES'
CODE_SIGN_STYLE=Manual
  "CODE_SIGN_STYLE=Automatic"
PROVISIONING_PROFILE=01234567-89AB-CDEF-0123-456789ABCDEF
  "PROVISIONING_PROFILE=01234567-89AB-CDEF-0123-456789ABCDEF"
PROVISIONING_PROFILE_SPECIFIER=Fearless App Store
  "PROVISIONING_PROFILE_SPECIFIER=Fearless App Store"
OVERRIDES

grep -Fq '"CODE_SIGN_IDENTITY=$EXPECTED_SIGNING_IDENTITY"' "$BUILD_SCRIPT" ||
  fail "archive script does not bind the reviewed distribution identity"
grep -Fq \
  'bash "$SCRIPT_DIR/audit-ios-signed-release-artifact.sh"' \
  "$BUILD_SCRIPT" ||
  fail "archive script no longer invokes the signed-artifact audit"
grep -Fq -- \
  '--expected-signing-certificate-sha1 "$EXPECTED_SIGNING_CERTIFICATE_SHA1"' \
  "$BUILD_SCRIPT" ||
  fail "signed-artifact audit is not bound to the reviewed certificate"
grep -Fq -- \
  '--expected-profile-uuid "$EXPECTED_PROFILE_UUID"' \
  "$BUILD_SCRIPT" ||
  fail "signed-artifact audit is not bound to the reviewed profile UUID"
grep -Fq -- \
  '--expected-profile-name "$EXPECTED_PROFILE_NAME"' \
  "$BUILD_SCRIPT" ||
  fail "signed-artifact audit is not bound to the reviewed profile name"
grep -Fq 'require_setting CODE_SIGN_STYLE "Automatic"' "$IDENTITY_AUDIT" ||
  fail "release identity no longer requires target-scoped Automatic signing"

printf '%s\n' \
  "[ios-release-archive-signing-test] PASS: canonical contract and $override_number workspace-wide override mutations"
