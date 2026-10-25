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
    '^[[:space:]]*"?(CODE_SIGN_IDENTITY|CODE_SIGN_STYLE|DEVELOPMENT_TEAM|PROVISIONING_PROFILE(_SPECIFIER)?)=' \
    "$1"
}

[[ -f "$BUILD_SCRIPT" && ! -L "$BUILD_SCRIPT" ]] ||
  fail "archive build script is missing or unsafe"
[[ -f "$IDENTITY_AUDIT" && ! -L "$IDENTITY_AUDIT" ]] ||
  fail "release identity audit is missing or unsafe"

# The archived build must be the same canonical version as the production
# target. Checking the project directly avoids resolving dependencies or signing.
python3 - "$BUILD_SCRIPT" "$SCRIPT_DIR/../fearless.xcodeproj/project.pbxproj" <<'PYTHON'
import json
import re
import subprocess
import sys
from pathlib import Path
script, project_path = sys.argv[1:]
source = Path(script).read_text()
builds = re.findall(r'^readonly EXPECTED_BUILD="([0-9.]+)"$', source, re.MULTILINE)
assert len(builds) == 1, 'archive must declare exactly one canonical build'
assert re.fullmatch(r'[1-9][0-9]{0,3}(\.[0-9]{1,2}){0,2}', builds[0]), 'invalid archive build'
objects = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', project_path]))['objects']
targets = [obj for obj in objects.values() if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'fearless']
assert len(targets) == 1, 'production target must be unique'
configurations = objects[targets[0]['buildConfigurationList']]['buildConfigurations']
release = [objects[key]['buildSettings'] for key in configurations if objects[key].get('name') == 'Release']
assert len(release) == 1, 'production Release configuration must be unique'
assert release[0]['CURRENT_PROJECT_VERSION'] == builds[0], 'archive/project build drift'
assert release[0]['MARKETING_VERSION'] == '4.2.0', 'archive/project marketing version drift'
PYTHON

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
CODE_SIGN_IDENTITY=Apple Distribution
  "CODE_SIGN_IDENTITY=Apple Distribution"
DEVELOPMENT_TEAM=YLWWUD25VZ
  "DEVELOPMENT_TEAM=YLWWUD25VZ"
PROVISIONING_PROFILE=01234567-89AB-CDEF-0123-456789ABCDEF
  "PROVISIONING_PROFILE=01234567-89AB-CDEF-0123-456789ABCDEF"
PROVISIONING_PROFILE_SPECIFIER=Fearless App Store
  "PROVISIONING_PROFILE_SPECIFIER=Fearless App Store"
OVERRIDES

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
grep -Fq \
  'readonly EXPECTED_BASE_SOURCE_COMMIT="2e45e55dc03ad904598e730cfb5994fb5c1072dc"' \
  "$BUILD_SCRIPT" ||
  fail "archive source is not bound to the exact distributed 4.2.0 (2026.7.28) commit"
grep -Fq \
  'git merge-base --is-ancestor "$EXPECTED_BASE_SOURCE_COMMIT" "$source_commit"' \
  "$BUILD_SCRIPT" ||
  fail "archive source ancestry is not enforced before the build"
grep -Fq 'require_setting CODE_SIGN_STYLE "Manual"' "$IDENTITY_AUDIT" ||
  fail "release identity no longer requires target-scoped Manual signing"
grep -Fq \
  'require_setting CODE_SIGN_IDENTITY "$EXPECTED_SIGNING_IDENTITY"' \
  "$IDENTITY_AUDIT" ||
  fail "release identity no longer requires the target-scoped distribution identity"
grep -Fq \
  'require_setting PROVISIONING_PROFILE_SPECIFIER "$EXPECTED_PROFILE_NAME"' \
  "$IDENTITY_AUDIT" ||
  fail "release identity no longer requires the target-scoped App Store profile"

printf '%s\n' \
  "[ios-release-archive-signing-test] PASS: canonical contract and $override_number workspace-wide override mutations"
