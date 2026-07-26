#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly AUDIT="$SCRIPT_DIR/ci/audit-ios-signed-release-artifact.sh"
readonly HASH_ARCHIVE="$SCRIPT_DIR/ci/hash-ios-archive.sh"
readonly TEMPORARY_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-signed-audit-tests.XXXXXX")"
readonly EXPECTED_GIT_SHA="7a819cb01e92920e5444151392df54245acdd4c8"

trap 'rm -rf "$TEMPORARY_DIR"' EXIT

RUN_NUMBER=0
CASE_DIR=""
ARCHIVE=""
APP=""
SIGNED_ENTITLEMENTS=""
PROFILE=""
SIGNING_CERTIFICATE=""
CASE_ENV=()

fail() {
  printf '%s\n' "[ios-signed-release-audit-test][error] $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  local file="$2"
  grep -Fq -- "$expected" "$file" ||
    fail "expected '$expected' in $(basename "$file")"
}

prepare_case() {
  local label="$1"
  RUN_NUMBER=$((RUN_NUMBER + 1))
  CASE_DIR="$TEMPORARY_DIR/case-${RUN_NUMBER}-${label}"
  ARCHIVE="$CASE_DIR/fearless.xcarchive"
  APP="$ARCHIVE/Products/Applications/fearless.app"
  SIGNED_ENTITLEMENTS="$CASE_DIR/signed-entitlements.plist"
  PROFILE="$CASE_DIR/profile.plist"
  SIGNING_CERTIFICATE="$CASE_DIR/signing-certificate.cer"
  mkdir -p "$APP" "$CASE_DIR/output"

  python3 - "$ARCHIVE/Info.plist" "$APP/Info.plist" \
    "$SIGNED_ENTITLEMENTS" "$PROFILE" "$SIGNING_CERTIFICATE" \
    "$EXPECTED_GIT_SHA" <<'PY'
import datetime
import plistlib
import sys

(
    archive_path,
    app_path,
    entitlements_path,
    profile_path,
    certificate_path,
    git_sha,
) = sys.argv[1:]
team = "YLWWUD25VZ"
bundle = "jp.co.soramitsu.fearlesswallet"
application_id = f"{team}.{bundle}"
certificate = b"canonical Fearless App Store signing certificate"
capabilities = {
    "com.apple.developer.associated-domains": [
        "applinks:fearlesswallet.io",
        "webcredentials:fearlesswallet.io",
    ],
    "com.apple.developer.icloud-container-identifiers": [
        "iCloud.jp.co.soramitsu.fearlesswallet"
    ],
    "com.apple.developer.icloud-services": ["CloudKit"],
    "com.apple.security.application-groups": [
        "group.jp.co.soramitsu.fearlesswallet"
    ],
}
signed = {
    **capabilities,
    "application-identifier": application_id,
    "com.apple.developer.team-identifier": team,
}
profile_entitlements = {
    "com.apple.developer.associated-domains": "*",
    "com.apple.developer.icloud-container-development-container-identifiers": [
        "iCloud.jp.co.soramitsu.fearlesswallet"
    ],
    "com.apple.developer.icloud-container-environment": [
        "Production",
        "Development",
    ],
    "com.apple.developer.icloud-container-identifiers": [
        "iCloud.jp.co.soramitsu.fearlesswallet"
    ],
    "com.apple.developer.icloud-services": "*",
    "com.apple.developer.ubiquity-container-identifiers": [
        "iCloud.jp.co.soramitsu.fearlesswallet"
    ],
    "com.apple.developer.ubiquity-kvstore-identifier": f"{team}.*",
    "com.apple.security.application-groups": [
        "group.jp.co.soramitsu.fearlesswallet"
    ],
    "application-identifier": application_id,
    "com.apple.developer.team-identifier": team,
    "get-task-allow": False,
    "beta-reports-active": True,
    "keychain-access-groups": ["YLWWUD25VZ.*", "com.apple.token"],
}
archive = {
    "ApplicationProperties": {
        "ApplicationPath": "Applications/fearless.app",
        "CFBundleIdentifier": bundle,
        "SigningIdentity": "Apple Distribution: Fearless Test ($team)",
        "Team": team,
    }
}
app = {
    "CFBundleExecutable": "fearless",
    "CFBundleIdentifier": bundle,
    "CFBundleShortVersionString": "4.2.0",
    "CFBundleVersion": "2026.7.27",
    "FearlessBuildConfiguration": "Release",
    "FearlessEnableTestability": "NO",
    "FearlessGitCommit": git_sha,
    "FearlessSwiftOptimizationLevel": "-O",
}
profile = {
    "CreationDate": datetime.datetime(2026, 1, 1),
    "DeveloperCertificates": [certificate],
    "Entitlements": profile_entitlements,
    "ExpirationDate": datetime.datetime(2035, 1, 1),
    "Name": "Fearless App Store",
    "TeamIdentifier": [team],
    "TeamName": "Fearless",
    "UUID": "11111111-2222-3333-4444-555555555555",
}
for path, payload in (
    (archive_path, archive),
    (app_path, app),
    (entitlements_path, signed),
    (profile_path, profile),
):
    with open(path, "wb") as destination:
        plistlib.dump(payload, destination)
with open(certificate_path, "wb") as destination:
    destination.write(certificate)
PY

  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$APP/fearless"
  chmod +x "$APP/fearless"
  printf '%s\n' "opaque production profile" >"$APP/embedded.mobileprovision"
  CASE_ENV=()
}

run_audit() {
  local label="$1"
  local executable_sha
  local archive_sha
  local signing_certificate_sha1
  executable_sha="$(shasum -a 256 "$APP/fearless" | awk '{print $1}')"
  archive_sha="$(bash "$HASH_ARCHIVE" "$ARCHIVE")"
  signing_certificate_sha1="$(
    shasum -a 1 "$SIGNING_CERTIFICATE" | awk '{print $1}'
  )"

  env \
    FEARLESS_SIGNED_AUDIT_TEST_HARNESS=1 \
    FEARLESS_SIGNED_AUDIT_CODESIGN_BIN="$TEMPORARY_DIR/bin/codesign" \
    FEARLESS_SIGNED_AUDIT_SECURITY_BIN="$TEMPORARY_DIR/bin/security" \
    FAKE_SIGNED_ENTITLEMENTS="$SIGNED_ENTITLEMENTS" \
    FAKE_SIGNING_CERTIFICATE="$SIGNING_CERTIFICATE" \
    FAKE_PROFILE_PLIST="$PROFILE" \
    ${CASE_ENV[@]+"${CASE_ENV[@]}"} \
    bash "$AUDIT" \
      --archive "$ARCHIVE" \
      --expected-git-sha "${EXPECTED_GIT_OVERRIDE:-$EXPECTED_GIT_SHA}" \
      --expected-build 2026.7.27 \
      --expected-executable-sha256 "${EXPECTED_EXECUTABLE_SHA_OVERRIDE:-$executable_sha}" \
      --expected-archive-sha256 "${EXPECTED_ARCHIVE_SHA_OVERRIDE:-$archive_sha}" \
      --expected-signing-certificate-sha1 "${EXPECTED_SIGNING_CERTIFICATE_SHA_OVERRIDE:-$signing_certificate_sha1}" \
      --expected-profile-uuid 11111111-2222-3333-4444-555555555555 \
      --expected-profile-name "Fearless App Store" \
      --receipt "$CASE_DIR/output/receipt.json" \
      >"$CASE_DIR/stdout" 2>"$CASE_DIR/stderr"
}

expect_failure() {
  local label="$1"
  local expected="$2"
  if run_audit "$label"; then
    fail "$label unexpectedly passed"
  fi
  assert_contains "$expected" "$CASE_DIR/stderr"
  printf '%s\n' "[ios-signed-release-audit-test] PASS (rejected): $label"
}

mutate_plist() {
  local path="$1"
  local expression="$2"
  python3 - "$path" "$expression" <<'PY'
import datetime
import plistlib
import sys

path, expression = sys.argv[1:]
with open(path, "rb") as source:
    value = plistlib.load(source)
scope = {"value": value, "datetime": datetime}
exec(expression, scope, scope)
with open(path, "wb") as destination:
    plistlib.dump(value, destination)
PY
}

mkdir -p "$TEMPORARY_DIR/bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "${FAKE_CODESIGN_VERIFY_FAIL:-0}" == "1" && "${1:-}" == "--verify" ]]; then exit 1; fi' \
  'if [[ "${1:-}" == "-d" && "${2:-}" == --extract-certificates=* ]]; then' \
  '  prefix="${2#--extract-certificates=}"' \
  '  cp "$FAKE_SIGNING_CERTIFICATE" "${prefix}0"' \
  'elif [[ "${1:-}" == "-d" ]]; then' \
  '  cp "$FAKE_SIGNED_ENTITLEMENTS" /dev/stdout' \
  'fi' \
  >"$TEMPORARY_DIR/bin/codesign"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  '[[ "${FAKE_SECURITY_FAIL:-0}" != "1" ]] || exit 1' \
  'cp "$FAKE_PROFILE_PLIST" /dev/stdout' \
  >"$TEMPORARY_DIR/bin/security"
chmod +x "$TEMPORARY_DIR/bin/codesign" "$TEMPORARY_DIR/bin/security"

prepare_case canonical
if ! run_audit canonical; then
  sed -n '1,100p' "$CASE_DIR/stderr" >&2
  fail "canonical signed archive was rejected"
fi
assert_contains '"archiveTreeSHA256"' "$CASE_DIR/output/receipt.json"
assert_contains '"distributionProfile": "valid-app-store"' "$CASE_DIR/output/receipt.json"
printf '%s\n' "[ios-signed-release-audit-test] PASS: canonical signed archive"

prepare_case wrong-commit
EXPECTED_GIT_OVERRIDE="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
expect_failure wrong-commit "embedded git commit"
unset EXPECTED_GIT_OVERRIDE

prepare_case executable-digest
EXPECTED_EXECUTABLE_SHA_OVERRIDE="$(printf 'a%.0s' {1..64})"
expect_failure executable-digest "executable SHA-256"
unset EXPECTED_EXECUTABLE_SHA_OVERRIDE

prepare_case archive-digest
EXPECTED_ARCHIVE_SHA_OVERRIDE="$(printf 'b%.0s' {1..64})"
expect_failure archive-digest "archive SHA-256"
unset EXPECTED_ARCHIVE_SHA_OVERRIDE

prepare_case wrong-team
mutate_plist "$PROFILE" \
  'value["TeamIdentifier"] = ["AAAAAAAAAA"]'
expect_failure wrong-team "signed entitlements or embedded distribution profile"

prepare_case wrong-archive-team
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["Team"] = "AAAAAAAAAA"'
expect_failure wrong-archive-team "xcarchive metadata"

prepare_case archive-path-includes-products
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["ApplicationPath"] = "Products/Applications/fearless.app"'
expect_failure archive-path-includes-products "xcarchive metadata"

prepare_case archive-path-traversal
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["ApplicationPath"] = "../Applications/fearless.app"'
expect_failure archive-path-traversal "xcarchive metadata"

prepare_case archive-path-absolute
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["ApplicationPath"] = "/Applications/fearless.app"'
expect_failure archive-path-absolute "xcarchive metadata"

prepare_case archive-path-wrong-app
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["ApplicationPath"] = "Applications/attacker.app"'
expect_failure archive-path-wrong-app "xcarchive metadata"

prepare_case archive-path-missing
mutate_plist "$ARCHIVE/Info.plist" \
  'del value["ApplicationProperties"]["ApplicationPath"]'
expect_failure archive-path-missing "xcarchive metadata"

prepare_case development-identity
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["SigningIdentity"] = "Apple Development: Unsafe"'
expect_failure development-identity "distribution identity"

prepare_case development-profile
mutate_plist "$PROFILE" \
  'value["ProvisionedDevices"] = ["DEVICE-UDID"]'
expect_failure development-profile "signed entitlements or embedded distribution profile"

prepare_case non-testflight-profile
mutate_plist "$PROFILE" \
  'del value["Entitlements"]["beta-reports-active"]'
expect_failure non-testflight-profile "signed entitlements or embedded distribution profile"

prepare_case enterprise-profile
mutate_plist "$PROFILE" \
  'value["ProvisionsAllDevices"] = True'
expect_failure enterprise-profile "signed entitlements or embedded distribution profile"

prepare_case get-task-allow
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["get-task-allow"] = True'
expect_failure get-task-allow "signed entitlements or embedded distribution profile"

prepare_case expired-profile
mutate_plist "$PROFILE" \
  'value["ExpirationDate"] = datetime.datetime(2026, 2, 1)'
expect_failure expired-profile "signed entitlements or embedded distribution profile"

prepare_case profile-expiring-too-soon
mutate_plist "$PROFILE" \
  'value["ExpirationDate"] = datetime.datetime.now() + datetime.timedelta(days=7)'
expect_failure profile-expiring-too-soon "signed entitlements or embedded distribution profile"

prepare_case replaced-walletconnect-group
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["com.apple.security.application-groups"] = ["group.com.walletconnect.sdk"]'
expect_failure replaced-walletconnect-group "signed entitlements or embedded distribution profile"

prepare_case unexpected-signed-keychain-group
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["keychain-access-groups"] = ["group.jp.co.soramitsu.fearlesswallet"]'
expect_failure unexpected-signed-keychain-group "signed entitlements or embedded distribution profile"

prepare_case profile-missing-keychain-group
mutate_plist "$PROFILE" \
  'del value["Entitlements"]["keychain-access-groups"]'
expect_failure profile-missing-keychain-group "signed entitlements or embedded distribution profile"

prepare_case profile-signing-certificate-mismatch
mutate_plist "$PROFILE" \
  'value["DeveloperCertificates"] = [b"unrelated distribution certificate"]'
expect_failure profile-signing-certificate-mismatch "signed entitlements or embedded distribution profile"

prepare_case wrong-profile-uuid
mutate_plist "$PROFILE" \
  'value["UUID"] = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"'
expect_failure wrong-profile-uuid "signed entitlements or embedded distribution profile"

prepare_case wrong-profile-name
mutate_plist "$PROFILE" \
  'value["Name"] = "Unreviewed App Store Profile"'
expect_failure wrong-profile-name "signed entitlements or embedded distribution profile"

prepare_case profile-unauthorized-associated-domains
mutate_plist "$PROFILE" \
  'value["Entitlements"]["com.apple.developer.associated-domains"] = ["applinks:attacker.example"]'
expect_failure profile-unauthorized-associated-domains "signed entitlements or embedded distribution profile"

prepare_case profile-missing-production-cloud-environment
mutate_plist "$PROFILE" \
  'value["Entitlements"]["com.apple.developer.icloud-container-environment"] = ["Development"]'
expect_failure profile-missing-production-cloud-environment "signed entitlements or embedded distribution profile"

prepare_case profile-wrong-ubiquity-container
mutate_plist "$PROFILE" \
  'value["Entitlements"]["com.apple.developer.ubiquity-container-identifiers"] = ["iCloud.jp.co.soramitsu.fearlesswallet.dev"]'
expect_failure profile-wrong-ubiquity-container "signed entitlements or embedded distribution profile"

prepare_case profile-unexpected-entitlement
mutate_plist "$PROFILE" \
  'value["Entitlements"]["com.apple.developer.healthkit"] = True'
expect_failure profile-unexpected-entitlement "signed entitlements or embedded distribution profile"

prepare_case unexpected-signed-entitlement
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["com.apple.developer.healthkit"] = True'
expect_failure unexpected-signed-entitlement "signed entitlements or embedded distribution profile"

prepare_case development-cloud
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["com.apple.developer.icloud-container-identifiers"] = ["iCloud.jp.co.soramitsu.fearlesswallet.dev"]'
expect_failure development-cloud "signed entitlements or embedded distribution profile"

prepare_case signature-failure
CASE_ENV=("FAKE_CODESIGN_VERIFY_FAIL=1")
expect_failure signature-failure "strict code-signature"

prepare_case profile-decode-failure
CASE_ENV=("FAKE_SECURITY_FAIL=1")
expect_failure profile-decode-failure "could not be decoded"

prepare_case override-without-harness
if env \
  FEARLESS_SIGNED_AUDIT_CODESIGN_BIN="$TEMPORARY_DIR/bin/codesign" \
  bash "$AUDIT" >"$CASE_DIR/stdout" 2>"$CASE_DIR/stderr"; then
  fail "tool override without harness unexpectedly passed"
fi
assert_contains "only in the explicit test harness" "$CASE_DIR/stderr"
printf '%s\n' "[ios-signed-release-audit-test] PASS (rejected): override without harness"

printf '%s\n' \
  "[ios-signed-release-audit-test] PASS: 1 positive + 32 negative/adversarial contracts"
