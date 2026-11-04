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
# Each provenance commit has exactly one assignment, so neither a comment nor a
# second assignment can replace the reviewed value.
for pin in \
  EXPECTED_BASE_SOURCE_COMMIT=2e45e55dc03ad904598e730cfb5994fb5c1072dc \
  CONSOLIDATED_SOURCE_COMMIT=cbc0b07c85118b2c652b440af2f2cee73458ef8f \
  CONSOLIDATED_SOURCE_HEAD=aad0fc85b42b2f1e22b281d7185803f78de390d5; do
  name="${pin%%=*}"
  [[ "$(grep -Ec "(^|[^A-Za-z0-9_])$name=" "$BUILD_SCRIPT")" == 1 ]] &&
    grep -Fxq "readonly $name=\"${pin#*=}\"" "$BUILD_SCRIPT" ||
    fail "$name must be assigned exactly once, to the reviewed commit"
done

# Run the archive's release source provenance block against a throwaway history
# shaped like #1305: distributed source B, pull request head H on B, master M
# without B, and the squash S that puts H's exact tree on M.
[[ "$(grep -c '^# BEGIN release source provenance$' "$BUILD_SCRIPT")" == 1 &&
  "$(grep -c '^# END release source provenance$' "$BUILD_SCRIPT")" == 1 ]] ||
  fail "archive script must mark exactly one release source provenance block"
readonly PROVENANCE_BLOCK="$FIXTURES/provenance-block.sh"
awk '/^# END release source provenance$/ { exit } found { print } /^# BEGIN release source provenance$/ { found = 1 }' \
  "$BUILD_SCRIPT" >"$PROVENANCE_BLOCK"
grep -Fq 'git merge-base --is-ancestor "$CONSOLIDATED_SOURCE_COMMIT" "$source_commit"' "$PROVENANCE_BLOCK" ||
  fail "release source provenance block is empty or incomplete"

readonly PROVENANCE_REPO="$FIXTURES/provenance-repo"
fixture_git() {
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git -C "$PROVENANCE_REPO" \
    -c user.name=fixture -c user.email=fixture@example.invalid "$@"
}
fixture_commit() { # fixture_commit <file content> [parent...]
  local content="$1" blob tree parent
  local parents=()
  shift
  for parent in "$@"; do parents+=(-p "$parent"); done
  blob="$(printf '%s\n' "$content" | fixture_git hash-object -w --stdin)"
  tree="$(printf '100644 blob %s\tfile\n' "$blob" | fixture_git mktree)"
  fixture_git commit-tree "$tree" ${parents[@]+"${parents[@]}"} -m "$content"
}
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git -c init.defaultBranch=main init -q "$PROVENANCE_REPO"
fixture_base="$(fixture_commit distributed)"
fixture_head="$(fixture_commit pull-request "$fixture_base")"
fixture_master="$(fixture_commit master)"
fixture_squash="$(fixture_commit pull-request "$fixture_master")"
fixture_release="$(fixture_commit release "$fixture_squash")"
fixture_direct="$(fixture_commit direct "$fixture_base")"
fixture_unrelated="$(fixture_commit unrelated "$fixture_master")"
fixture_other_squash="$(fixture_commit other-tree "$fixture_master")"
fixture_other_release="$(fixture_commit other-release "$fixture_other_squash")"
[[ "$(fixture_git rev-parse "$fixture_squash^{tree}")" == "$(fixture_git rev-parse "$fixture_head^{tree}")" ]] ||
  fail "provenance fixture squash does not carry its pull request head's tree"

run_provenance() { # run_provenance <source> <consolidation commit> <pull request head>
  (
    fail() { printf '%s\n' "$*"; exit 1; }
    cd "$PROVENANCE_REPO"
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    EXPECTED_BASE_SOURCE_COMMIT="$fixture_base"
    CONSOLIDATED_SOURCE_COMMIT="$2"
    CONSOLIDATED_SOURCE_HEAD="$3"
    source_commit="$1"
    . "$PROVENANCE_BLOCK"
    printf 'accepted\n'
  ) 2>/dev/null
}
provenance_cases=0
expect_provenance() { # expect_provenance <outcome> <source> <consolidation commit> <pull request head>
  local expected="$1" actual
  shift
  provenance_cases=$((provenance_cases + 1))
  actual="$(run_provenance "$@")" || true
  [[ "$actual" == "$expected" ]] ||
    fail "release source provenance case $provenance_cases gave '$actual' instead of '$expected'"
}
readonly NOT_DESCENDED="release source is not descended from the exact distributed 4.2.0 (2026.7.28) source"
expect_provenance accepted "$fixture_base" "$fixture_squash" "$fixture_head"
expect_provenance accepted "$fixture_direct" "$fixture_squash" "$fixture_head"
expect_provenance accepted "$fixture_release" "$fixture_squash" "$fixture_head"
expect_provenance "$NOT_DESCENDED" "$fixture_unrelated" "$fixture_squash" "$fixture_head"
expect_provenance "$NOT_DESCENDED" "$fixture_master" "$fixture_squash" "$fixture_head"
expect_provenance "the #1305 consolidation commit does not carry its pull request head's exact tree" \
  "$fixture_other_release" "$fixture_other_squash" "$fixture_head"
expect_provenance "the #1305 pull request head is not descended from the distributed 4.2.0 (2026.7.28) source" \
  "$fixture_release" "$fixture_squash" "$fixture_master"
expect_provenance \
  "the #1305 consolidation commit or its pull request head is unavailable (git fetch origin refs/pull/1305/head)" \
  "$fixture_release" 0000000000000000000000000000000000000001 "$fixture_head"
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
  "[ios-release-archive-signing-test] PASS: canonical contract, $override_number workspace-wide override mutations and $provenance_cases release source provenance cases"
