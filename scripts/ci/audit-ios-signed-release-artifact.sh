#!/usr/bin/env bash
set -euo pipefail

# Fail-closed audit of the exact production .xcarchive proposed for TestFlight.
# The caller must supply independently recorded digests from the archive build
# step; this script never infers provenance from the current checkout.

umask 077

readonly LOG_PREFIX="[ios-signed-release-audit]"
readonly EXPECTED_TEAM="YLWWUD25VZ"
readonly EXPECTED_BUNDLE="jp.co.soramitsu.fearlesswallet"
readonly EXPECTED_VERSION="4.2.0"
readonly EXPECTED_APPLICATION_ID="${EXPECTED_TEAM}.${EXPECTED_BUNDLE}"
readonly EXPECTED_ASSOCIATED_DOMAINS_JSON='["applinks:fearlesswallet.io","webcredentials:fearlesswallet.io"]'
readonly EXPECTED_ICLOUD_CONTAINERS_JSON='["iCloud.jp.co.soramitsu.fearlesswallet"]'
readonly EXPECTED_ICLOUD_SERVICES_JSON='["CloudKit"]'
readonly EXPECTED_APP_GROUPS_JSON='["group.jp.co.soramitsu.fearlesswallet"]'
readonly EXPECTED_PROFILE_KEYCHAIN_GROUPS_JSON='["YLWWUD25VZ.*","com.apple.token"]'
readonly MINIMUM_PROFILE_VALIDITY_DAYS=14
readonly TEST_HARNESS="${FEARLESS_SIGNED_AUDIT_TEST_HARNESS:-0}"

fail() {
  printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/ci/audit-ios-signed-release-artifact.sh \
    --archive /absolute/path/to/fearless.xcarchive \
    --expected-git-sha 40_HEX_SHA \
    --expected-build CANONICAL_CF_BUNDLE_VERSION \
    --expected-executable-sha256 64_HEX_SHA256 \
    --expected-archive-sha256 64_HEX_SHA256 \
    --expected-signing-certificate-sha1 40_HEX_SHA1 \
    --expected-profile-uuid UUID \
    --expected-profile-name PROFILE_NAME \
    --receipt /absolute/path/to/new-receipt.json

The archive digest is the canonical tree digest emitted by:
  bash scripts/ci/hash-ios-archive.sh /absolute/path/to/fearless.xcarchive

Tool overrides are accepted only when
FEARLESS_SIGNED_AUDIT_TEST_HARNESS=1:
  FEARLESS_SIGNED_AUDIT_CODESIGN_BIN
  FEARLESS_SIGNED_AUDIT_SECURITY_BIN
  FEARLESS_SIGNED_AUDIT_PYTHON_BIN
  FEARLESS_SIGNED_AUDIT_SHASUM_BIN
USAGE
}

require_option_value() {
  local option="$1"
  local remaining="$2"
  [[ "$remaining" -ge 2 ]] || fail "$option requires a value"
}

require_executable() {
  local executable="$1"
  local label="$2"

  if [[ "$executable" == */* ]]; then
    [[ -x "$executable" ]] || fail "$label is not executable"
  else
    command -v "$executable" >/dev/null 2>&1 ||
      fail "$label is unavailable"
  fi
}

lowercase() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

if [[ "$TEST_HARNESS" != "1" ]]; then
  for override_name in \
    FEARLESS_SIGNED_AUDIT_CODESIGN_BIN \
    FEARLESS_SIGNED_AUDIT_SECURITY_BIN \
    FEARLESS_SIGNED_AUDIT_PYTHON_BIN \
    FEARLESS_SIGNED_AUDIT_SHASUM_BIN; do
    [[ -z "${!override_name:-}" ]] ||
      fail "$override_name is accepted only in the explicit test harness"
  done
fi

readonly CODESIGN_BIN="${FEARLESS_SIGNED_AUDIT_CODESIGN_BIN:-codesign}"
readonly SECURITY_BIN="${FEARLESS_SIGNED_AUDIT_SECURITY_BIN:-security}"
readonly PYTHON_BIN="${FEARLESS_SIGNED_AUDIT_PYTHON_BIN:-python3}"
readonly SHASUM_BIN="${FEARLESS_SIGNED_AUDIT_SHASUM_BIN:-shasum}"

archive=""
expected_git_sha=""
expected_build=""
expected_executable_sha=""
expected_archive_sha=""
expected_signing_certificate_sha1=""
expected_profile_uuid=""
expected_profile_name=""
receipt=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --archive)
      require_option_value "$1" "$#"
      archive="$2"
      shift 2
      ;;
    --expected-git-sha)
      require_option_value "$1" "$#"
      expected_git_sha="$2"
      shift 2
      ;;
    --expected-build)
      require_option_value "$1" "$#"
      expected_build="$2"
      shift 2
      ;;
    --expected-executable-sha256)
      require_option_value "$1" "$#"
      expected_executable_sha="$2"
      shift 2
      ;;
    --expected-archive-sha256)
      require_option_value "$1" "$#"
      expected_archive_sha="$2"
      shift 2
      ;;
    --expected-signing-certificate-sha1)
      require_option_value "$1" "$#"
      expected_signing_certificate_sha1="$2"
      shift 2
      ;;
    --expected-profile-uuid)
      require_option_value "$1" "$#"
      expected_profile_uuid="$2"
      shift 2
      ;;
    --expected-profile-name)
      require_option_value "$1" "$#"
      expected_profile_name="$2"
      shift 2
      ;;
    --receipt)
      require_option_value "$1" "$#"
      receipt="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ "$archive" == /* ]] || fail "--archive must be an absolute path"
[[ "$archive" == *.xcarchive ]] || fail "--archive must name an .xcarchive"
[[ -d "$archive" && ! -L "$archive" ]] ||
  fail "--archive must name a real, non-symlink directory"
[[ "$expected_git_sha" =~ ^[0-9A-Fa-f]{40}$ ]] ||
  fail "--expected-git-sha must be an exact 40-hex commit"
[[ "$expected_build" =~ ^[1-9][0-9]{0,3}(\.[0-9]{1,2}){0,2}$ ]] ||
  fail "--expected-build must be an explicit canonical CFBundleVersion"
[[ "$expected_executable_sha" =~ ^[0-9A-Fa-f]{64}$ ]] ||
  fail "--expected-executable-sha256 must be 64 hex"
[[ "$expected_archive_sha" =~ ^[0-9A-Fa-f]{64}$ ]] ||
  fail "--expected-archive-sha256 must be 64 hex"
[[ "$expected_signing_certificate_sha1" =~ ^[0-9A-Fa-f]{40}$ ]] ||
  fail "--expected-signing-certificate-sha1 must be 40 hex"
[[ "$expected_profile_uuid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] ||
  fail "--expected-profile-uuid must be a UUID"
[[ -n "$expected_profile_name" && "$expected_profile_name" != *$'\n'* ]] ||
  fail "--expected-profile-name must be a nonempty single line"
[[ "$receipt" == /* ]] || fail "--receipt must be an absolute path"
[[ ! -e "$receipt" && ! -L "$receipt" ]] ||
  fail "--receipt must not already exist"
[[ -d "$(dirname "$receipt")" && ! -L "$(dirname "$receipt")" ]] ||
  fail "--receipt parent must be a real existing directory"

require_executable "$CODESIGN_BIN" "codesign"
require_executable "$SECURITY_BIN" "security"
require_executable "$PYTHON_BIN" "Python"
require_executable "$SHASUM_BIN" "shasum"

archive="$(cd "$archive" && pwd -P)"
readonly archive

readonly ARCHIVE_INFO="$archive/Info.plist"
[[ -f "$ARCHIVE_INFO" && ! -L "$ARCHIVE_INFO" ]] ||
  fail "archive Info.plist is missing or unsafe"

readonly APP_ROOT="$archive/Products/Applications"
[[ -d "$APP_ROOT" && ! -L "$APP_ROOT" ]] ||
  fail "archive Products/Applications directory is missing or unsafe"

app_inventory="$(
  find "$APP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print
)"
app_count="$(printf '%s\n' "$app_inventory" | awk 'NF { count += 1 } END { print count + 0 }')"
[[ "$app_count" == "1" ]] ||
  fail "archive must contain exactly one top-level application"
readonly APP_PATH="$app_inventory"
[[ ! -L "$APP_PATH" ]] || fail "archived application must not be a symlink"

readonly APP_INFO="$APP_PATH/Info.plist"
[[ -f "$APP_INFO" && ! -L "$APP_INFO" ]] ||
  fail "archived application Info.plist is missing or unsafe"

read_plist_string() {
  local plist="$1"
  local key_path="$2"

  "$PYTHON_BIN" - "$plist" "$key_path" <<'PY'
import plistlib
import sys

path, key_path = sys.argv[1:]
try:
    with open(path, "rb") as source:
        value = plistlib.load(source)
    for component in key_path.split("."):
        value = value[component]
except (OSError, KeyError, TypeError, plistlib.InvalidFileException):
    raise SystemExit(2)
if not isinstance(value, str) or not value:
    raise SystemExit(3)
print(value)
PY
}

bundle_id="$(read_plist_string "$APP_INFO" CFBundleIdentifier)" ||
  fail "archived app lacks CFBundleIdentifier"
version="$(read_plist_string "$APP_INFO" CFBundleShortVersionString)" ||
  fail "archived app lacks CFBundleShortVersionString"
build="$(read_plist_string "$APP_INFO" CFBundleVersion)" ||
  fail "archived app lacks CFBundleVersion"
embedded_git_sha="$(read_plist_string "$APP_INFO" FearlessGitCommit)" ||
  fail "archived app lacks FearlessGitCommit provenance"
configuration="$(read_plist_string "$APP_INFO" FearlessBuildConfiguration)" ||
  fail "archived app lacks Release configuration attestation"
optimization="$(read_plist_string "$APP_INFO" FearlessSwiftOptimizationLevel)" ||
  fail "archived app lacks Swift optimization attestation"
testability="$(read_plist_string "$APP_INFO" FearlessEnableTestability)" ||
  fail "archived app lacks testability attestation"
executable_name="$(read_plist_string "$APP_INFO" CFBundleExecutable)" ||
  fail "archived app lacks CFBundleExecutable"

[[ "$bundle_id" == "$EXPECTED_BUNDLE" ]] ||
  fail "archived bundle identifier is not the production identity"
[[ "$version" == "$EXPECTED_VERSION" ]] ||
  fail "archived marketing version is not $EXPECTED_VERSION"
[[ "$build" == "$expected_build" ]] ||
  fail "archived build number is not the expected fresh build"
[[ "$(lowercase "$embedded_git_sha")" == "$(lowercase "$expected_git_sha")" ]] ||
  fail "embedded git commit does not match the expected build commit"
[[ "$configuration" == "Release" ]] ||
  fail "archived app was not built with Release configuration"
[[ "$optimization" == "-O" ]] ||
  fail "archived app was not built with Swift -O"
[[ "$testability" == "NO" ]] ||
  fail "archived app has testability enabled"
[[ "$executable_name" =~ ^[A-Za-z0-9._-]+$ ]] ||
  fail "archived executable name is unsafe"

readonly EXECUTABLE="$APP_PATH/$executable_name"
[[ -f "$EXECUTABLE" && ! -L "$EXECUTABLE" && -x "$EXECUTABLE" ]] ||
  fail "archived executable is missing, unsafe, or not executable"
actual_executable_sha="$("$SHASUM_BIN" -a 256 "$EXECUTABLE" | awk '{print $1}')"
[[ "$actual_executable_sha" =~ ^[0-9A-Fa-f]{64}$ ]] ||
  fail "could not compute archived executable SHA-256"
[[ "$(lowercase "$actual_executable_sha")" == "$(lowercase "$expected_executable_sha")" ]] ||
  fail "archived executable SHA-256 does not match build provenance"

readonly HASH_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/hash-ios-archive.sh"
[[ -x "$HASH_SCRIPT" ]] || fail "canonical archive hash helper is unavailable"
actual_archive_sha="$("$HASH_SCRIPT" "$archive")" ||
  fail "could not compute canonical archive SHA-256"
[[ "$(lowercase "$actual_archive_sha")" == "$(lowercase "$expected_archive_sha")" ]] ||
  fail "archive SHA-256 does not match build provenance"

"$PYTHON_BIN" - "$ARCHIVE_INFO" "$APP_PATH" "$EXPECTED_BUNDLE" "$EXPECTED_TEAM" <<'PY' ||
import os
import plistlib
import sys

path, app_path, expected_bundle, expected_team = sys.argv[1:]
try:
    with open(path, "rb") as source:
        payload = plistlib.load(source)
except (OSError, plistlib.InvalidFileException):
    raise SystemExit(2)
properties = payload.get("ApplicationProperties")
if not isinstance(properties, dict):
    raise SystemExit(3)
expected_relative = os.path.relpath(app_path, os.path.dirname(path))
if properties.get("ApplicationPath") != expected_relative:
    raise SystemExit(4)
if properties.get("CFBundleIdentifier") != expected_bundle:
    raise SystemExit(5)
if properties.get("Team") != expected_team:
    raise SystemExit(6)
identity = properties.get("SigningIdentity")
if not isinstance(identity, str) or not (
    identity.startswith("Apple Distribution:") or
    identity.startswith("iPhone Distribution:")
):
    raise SystemExit(7)
PY
  fail "xcarchive metadata does not bind the production app, team, and distribution identity"

temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-signed-audit.XXXXXX")"
cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

if ! "$CODESIGN_BIN" --verify --deep --strict "$APP_PATH" \
  >"$temporary_dir/codesign-verify" 2>&1; then
  fail "archived app failed strict code-signature verification"
fi

if ! "$CODESIGN_BIN" -d --entitlements :- --xml "$APP_PATH" \
  >"$temporary_dir/signed-entitlements.plist" \
  2>"$temporary_dir/codesign-diagnostics"; then
  fail "could not extract signed application entitlements"
fi
[[ -s "$temporary_dir/signed-entitlements.plist" ]] ||
  fail "signed application entitlements were empty"
if ! "$CODESIGN_BIN" -d \
  --extract-certificates="$temporary_dir/signing-certificate" \
  "$APP_PATH" >"$temporary_dir/certificate-output" \
  2>"$temporary_dir/certificate-diagnostics"; then
  fail "could not extract the application signing certificate"
fi
readonly SIGNING_CERTIFICATE="$temporary_dir/signing-certificate0"
[[ -f "$SIGNING_CERTIFICATE" && ! -L "$SIGNING_CERTIFICATE" ]] ||
  fail "application signature has no regular leaf certificate"
signing_certificate_sha1="$(
  "$SHASUM_BIN" -a 1 "$SIGNING_CERTIFICATE" | awk '{print $1}'
)"
[[ "$signing_certificate_sha1" =~ ^[0-9A-Fa-f]{40}$ ]] ||
  fail "could not compute the application signing certificate SHA-1"
[[ "$(lowercase "$signing_certificate_sha1")" == "$(lowercase "$expected_signing_certificate_sha1")" ]] ||
  fail "application signing certificate does not match the expected release identity"

readonly EMBEDDED_PROFILE="$APP_PATH/embedded.mobileprovision"
[[ -f "$EMBEDDED_PROFILE" && ! -L "$EMBEDDED_PROFILE" ]] ||
  fail "archived app has no regular embedded provisioning profile"
if ! "$SECURITY_BIN" cms -D -i "$EMBEDDED_PROFILE" \
  >"$temporary_dir/profile.plist" 2>"$temporary_dir/security-diagnostics"; then
  fail "embedded provisioning profile could not be decoded"
fi

"$PYTHON_BIN" - \
  "$temporary_dir/signed-entitlements.plist" \
  "$temporary_dir/profile.plist" \
  "$EXPECTED_TEAM" \
  "$EXPECTED_APPLICATION_ID" \
  "$EXPECTED_ASSOCIATED_DOMAINS_JSON" \
  "$EXPECTED_ICLOUD_CONTAINERS_JSON" \
  "$EXPECTED_ICLOUD_SERVICES_JSON" \
  "$EXPECTED_APP_GROUPS_JSON" \
  "$EXPECTED_PROFILE_KEYCHAIN_GROUPS_JSON" \
  "$MINIMUM_PROFILE_VALIDITY_DAYS" \
  "$signing_certificate_sha1" \
  "$expected_profile_uuid" \
  "$expected_profile_name" <<'PY' ||
import datetime
import hashlib
import json
import plistlib
import sys

(
    entitlements_path,
    profile_path,
    expected_team,
    expected_application_id,
    associated_json,
    containers_json,
    services_json,
    groups_json,
    profile_keychain_groups_json,
    minimum_validity_days_text,
    signing_certificate_sha1,
    expected_profile_uuid,
    expected_profile_name,
) = sys.argv[1:]

def load(path):
    try:
        with open(path, "rb") as source:
            return plistlib.load(source)
    except (OSError, plistlib.InvalidFileException):
        raise SystemExit(2)

signed = load(entitlements_path)
profile = load(profile_path)
if not isinstance(signed, dict) or not isinstance(profile, dict):
    raise SystemExit(3)

expected = {
    "com.apple.developer.associated-domains": json.loads(associated_json),
    "com.apple.developer.icloud-container-identifiers": json.loads(containers_json),
    "com.apple.developer.icloud-services": json.loads(services_json),
    "com.apple.security.application-groups": json.loads(groups_json),
}
for key, value in expected.items():
    if signed.get(key) != value:
        raise SystemExit(4)
if signed.get("application-identifier") != expected_application_id:
    raise SystemExit(5)
if signed.get("com.apple.developer.team-identifier") != expected_team:
    raise SystemExit(6)
if signed.get("get-task-allow") is True:
    raise SystemExit(7)

allowed_signed_keys = set(expected) | {
    "application-identifier",
    "beta-reports-active",
    "com.apple.developer.icloud-container-environment",
    "com.apple.developer.team-identifier",
    "get-task-allow",
}
if set(signed) - allowed_signed_keys:
    raise SystemExit(8)
if (
    "beta-reports-active" in signed
    and signed["beta-reports-active"] is not True
):
    raise SystemExit(8)
if (
    "com.apple.developer.icloud-container-environment" in signed
    and signed["com.apple.developer.icloud-container-environment"] != "Production"
):
    raise SystemExit(8)

def scalar_values(value):
    if isinstance(value, dict):
        for nested in value.values():
            yield from scalar_values(nested)
    elif isinstance(value, (list, tuple)):
        for nested in value:
            yield from scalar_values(nested)
    elif isinstance(value, str):
        yield value

for value in scalar_values(signed):
    if value in {
        "group.jp.co.soramitsu.fearlesswallet",
        "group.com.walletconnect.sdk",
        "group.jp.co.soramitsu.fearlesswallet.dev",
        "iCloud.jp.co.soramitsu.fearless",
        "iCloud.jp.co.soramitsu.fearlesswallet.dev",
    }:
        if value != "group.jp.co.soramitsu.fearlesswallet":
            raise SystemExit(9)

team_identifiers = profile.get("TeamIdentifier")
if team_identifiers != [expected_team]:
    raise SystemExit(10)
if profile.get("TeamName") is not None and not isinstance(profile.get("TeamName"), str):
    raise SystemExit(11)
if (
    not isinstance(profile.get("UUID"), str)
    or profile["UUID"].lower() != expected_profile_uuid.lower()
):
    raise SystemExit(12)
if profile.get("Name") != expected_profile_name:
    raise SystemExit(13)
profile_certificates = profile.get("DeveloperCertificates")
if (
    not isinstance(profile_certificates, list)
    or not profile_certificates
    or not all(isinstance(certificate, bytes) for certificate in profile_certificates)
):
    raise SystemExit(13)
profile_certificate_fingerprints = {
    hashlib.sha1(certificate).hexdigest()
    for certificate in profile_certificates
}
if signing_certificate_sha1.lower() not in profile_certificate_fingerprints:
    raise SystemExit(13)
creation = profile.get("CreationDate")
expiration = profile.get("ExpirationDate")
if not isinstance(creation, datetime.datetime) or not isinstance(expiration, datetime.datetime):
    raise SystemExit(14)
now = datetime.datetime.now(datetime.timezone.utc)
if creation.tzinfo is None:
    creation = creation.replace(tzinfo=datetime.timezone.utc)
if expiration.tzinfo is None:
    expiration = expiration.replace(tzinfo=datetime.timezone.utc)
try:
    minimum_validity_days = int(minimum_validity_days_text)
except ValueError:
    raise SystemExit(15)
minimum_expiration = now + datetime.timedelta(days=minimum_validity_days)
if creation >= expiration or expiration < minimum_expiration:
    raise SystemExit(15)

# App Store/TestFlight profiles do not enumerate development devices and are
# never enterprise profiles.
if "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices") is True:
    raise SystemExit(16)
profile_entitlements = profile.get("Entitlements")
if not isinstance(profile_entitlements, dict):
    raise SystemExit(17)
if profile_entitlements.get("application-identifier") != expected_application_id:
    raise SystemExit(18)
if profile_entitlements.get("com.apple.developer.team-identifier") != expected_team:
    raise SystemExit(19)
if profile_entitlements.get("get-task-allow") is not False:
    raise SystemExit(20)
if profile_entitlements.get("beta-reports-active") is not True:
    raise SystemExit(20)

# The signed app must contain the exact least-privilege values above. Apple's
# App Store profile is an authorization envelope: associated domains and iCloud
# services are represented as "*" in the real production profile, while the
# container and app-group identities remain explicit. Validate that distinction
# instead of requiring the profile payload to be byte-shaped like the app's
# signed entitlements.
associated_authorization = profile_entitlements.get(
    "com.apple.developer.associated-domains"
)
if associated_authorization not in (
    "*",
    expected["com.apple.developer.associated-domains"],
):
    raise SystemExit(21)
services_authorization = profile_entitlements.get(
    "com.apple.developer.icloud-services"
)
if services_authorization not in (
    "*",
    expected["com.apple.developer.icloud-services"],
):
    raise SystemExit(21)
for key in (
    "com.apple.developer.icloud-container-identifiers",
    "com.apple.security.application-groups",
):
    if profile_entitlements.get(key) != expected[key]:
        raise SystemExit(21)

expected_containers = expected[
    "com.apple.developer.icloud-container-identifiers"
]
if profile_entitlements.get(
    "com.apple.developer.icloud-container-development-container-identifiers"
) != expected_containers:
    raise SystemExit(21)
if profile_entitlements.get(
    "com.apple.developer.ubiquity-container-identifiers"
) != expected_containers:
    raise SystemExit(21)
if profile_entitlements.get(
    "com.apple.developer.ubiquity-kvstore-identifier"
) != f"{expected_team}.*":
    raise SystemExit(21)

profile_cloud_environments = profile_entitlements.get(
    "com.apple.developer.icloud-container-environment"
)
if isinstance(profile_cloud_environments, str):
    profile_cloud_environments = [profile_cloud_environments]
if (
    not isinstance(profile_cloud_environments, list)
    or "Production" not in profile_cloud_environments
    or not set(profile_cloud_environments).issubset({"Development", "Production"})
):
    raise SystemExit(21)
if profile_entitlements.get("keychain-access-groups") != json.loads(
    profile_keychain_groups_json
):
    raise SystemExit(21)
allowed_profile_keys = allowed_signed_keys | {
    "com.apple.developer.icloud-container-development-container-identifiers",
    "com.apple.developer.ubiquity-container-identifiers",
    "com.apple.developer.ubiquity-kvstore-identifier",
    "keychain-access-groups",
}
if set(profile_entitlements) - allowed_profile_keys:
    raise SystemExit(22)
if (
    "beta-reports-active" in profile_entitlements
    and profile_entitlements["beta-reports-active"] is not True
):
    raise SystemExit(23)
PY
  fail "signed entitlements or embedded distribution profile violate the production contract"

# Recompute the canonical tree digest after every signature/profile read and
# immediately before publishing the receipt. This prevents a concurrently
# mutated archive from retaining the digest accepted at the start of the audit.
final_archive_sha="$("$HASH_SCRIPT" "$archive")" ||
  fail "could not recompute canonical archive SHA-256 before receipt publication"
[[ "$(lowercase "$final_archive_sha")" == "$(lowercase "$actual_archive_sha")" ]] ||
  fail "archive changed while signed identity and profile were audited"

receipt_pending="${receipt}.pending.$$"
"$PYTHON_BIN" - \
  "$receipt_pending" \
  "$expected_git_sha" \
  "$bundle_id" \
  "$version" \
  "$build" \
  "$actual_executable_sha" \
  "$actual_archive_sha" \
  "$EXPECTED_TEAM" \
  "$signing_certificate_sha1" \
  "$expected_profile_uuid" \
  "$expected_profile_name" <<'PY'
import datetime
import json
import os
import sys

(
    path,
    git_sha,
    bundle_id,
    version,
    build,
    executable_sha,
    archive_sha,
    team,
    signing_certificate_sha1,
    profile_uuid,
    profile_name,
) = sys.argv[1:]
payload = {
    "schemaVersion": 1,
    "audit": "fearless-ios-signed-production-archive",
    "auditedAtUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "gitCommit": git_sha.lower(),
    "bundleIdentifier": bundle_id,
    "marketingVersion": version,
    "buildNumber": build,
    "developmentTeam": team,
    "executableSHA256": executable_sha.lower(),
    "archiveTreeSHA256": archive_sha.lower(),
    "signingCertificateSHA1": signing_certificate_sha1.lower(),
    "provisioningProfileUUID": profile_uuid.lower(),
    "provisioningProfileName": profile_name,
    "distributionProfile": "valid-app-store",
    "signedEntitlements": "exact-production-contract",
}
with open(path, "x", encoding="utf-8") as destination:
    json.dump(payload, destination, indent=2, sort_keys=True)
    destination.write("\n")
    destination.flush()
    os.fsync(destination.fileno())
PY
mv "$receipt_pending" "$receipt"

printf '%s\n' \
  "$LOG_PREFIX PASS: exact commit, bundle/version/build, executable/archive hashes, distribution profile, and signed production entitlements verified"
