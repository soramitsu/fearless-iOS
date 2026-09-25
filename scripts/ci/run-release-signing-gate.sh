#!/usr/bin/env bash
set -euo pipefail

PREFIX="[release-signing-gate]"
ROOT_DIR="${IOS_RELEASE_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORKSPACE="${IOS_RELEASE_WORKSPACE:-$ROOT_DIR/fearless.xcworkspace}"
SCHEME="${IOS_RELEASE_SCHEME:-fearless}"
SOURCE_PACKAGES_DIR="${IOS_RELEASE_SOURCE_PACKAGES_DIR:-$ROOT_DIR/SourcePackages}"
EXPECTED_TEAM_ID="YLWWUD25VZ"
EXPECTED_BUNDLE_ID="jp.co.soramitsu.fearlesswallet"
EXPECTED_APPLICATION_ID="$EXPECTED_TEAM_ID.$EXPECTED_BUNDLE_ID"
EXPECTED_ICLOUD_CONTAINER="iCloud.$EXPECTED_BUNDLE_ID"
EXPECTED_APP_GROUP="group.$EXPECTED_BUNDLE_ID"
SECURITY_BIN="${IOS_RELEASE_SECURITY_BIN:-/usr/bin/security}"
XCODEBUILD_BIN="${IOS_RELEASE_XCODEBUILD_BIN:-$(xcrun --find xcodebuild 2>/dev/null || true)}"
CODESIGN_BIN="${IOS_RELEASE_CODESIGN_BIN:-/usr/bin/codesign}"
PLUTIL_BIN="${IOS_RELEASE_PLUTIL_BIN:-/usr/bin/plutil}"
SIGNING_REQUIRED="${IOS_RELEASE_SIGNING_REQUIRED:-0}"
PROFILE_DIRS="${IOS_RELEASE_PROFILE_DIRS:-$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles:$HOME/Library/MobileDevice/Provisioning Profiles}"
EXPECTED_PROFILE_UUID="${IOS_RELEASE_EXPECTED_PROFILE_UUID:-}"
PROFILE_SPECIFIER="${IOS_RELEASE_PROVISIONING_PROFILE_SPECIFIER:-}"

fail() {
  echo "$PREFIX ERROR: $*" >&2
  exit 1
}

normalize_boolean() {
  case "$1" in
    1|true) printf '1\n' ;;
    0|false|'') printf '0\n' ;;
    *) fail "IOS_RELEASE_SIGNING_REQUIRED must be exactly 0, false, 1, or true." ;;
  esac
}

SIGNING_REQUIRED="$(normalize_boolean "$SIGNING_REQUIRED")"

if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
  [[ "${GITHUB_EVENT_NAME:-}" == "push" ]] || fail \
    "The real signing gate refuses to access signing material outside a trusted push."
  case "${GITHUB_REF:-}" in
    refs/heads/develop|refs/heads/master) ;;
    *) fail "The real signing gate refuses to access signing material outside a release branch." ;;
  esac
  [[ "$SIGNING_REQUIRED" == "1" ]] || fail \
    "Trusted release CI must require signing material; IOS_RELEASE_SIGNING_REQUIRED must be 1."
  [[ "$EXPECTED_PROFILE_UUID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] || fail \
    "Trusted release CI must bind the archive to one decoded provisioning-profile UUID."
  [[ -n "$PROFILE_SPECIFIER" && ${#PROFILE_SPECIFIER} -le 256 && "$PROFILE_SPECIFIER" != *$'\n'* && "$PROFILE_SPECIFIER" != *$'\r'* ]] || fail \
    "Trusted release CI must bind the archive to one bounded provisioning-profile specifier."
fi

for command_path in "$SECURITY_BIN" "$CODESIGN_BIN" "$PLUTIL_BIN"; do
  [[ -x "$command_path" ]] || fail "A required Apple release-validation tool is unavailable."
done
[[ -n "$XCODEBUILD_BIN" && -x "$XCODEBUILD_BIN" ]] || fail "xcodebuild is unavailable."
[[ -d "$WORKSPACE" ]] || fail "The iOS workspace is unavailable."
[[ -d "$SOURCE_PACKAGES_DIR/checkouts" ]] || fail \
  "Resolved Swift packages are unavailable; resolve them into the repository SourcePackages directory before this gate."

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/fearless-release-signing.XXXXXX")"
chmod 700 "$temporary_root"
cleanup() {
  rm -rf "$temporary_root"
}
trap cleanup EXIT INT TERM

plist_type() {
  local file="$1"
  local key_path="$2"
  "$PLUTIL_BIN" -type "$key_path" "$file" 2>/dev/null
}

plist_value() {
  local file="$1"
  local key_path="$2"
  "$PLUTIL_BIN" -extract "$key_path" raw -o - "$file" 2>/dev/null
}

plist_array_contains() {
  local file="$1"
  local key_path="$2"
  local expected="$3"
  local count index value

  [[ "$(plist_type "$file" "$key_path" || true)" == "array" ]] || return 1
  count="$(plist_value "$file" "$key_path" || true)"
  [[ "$count" =~ ^[0-9]+$ ]] || return 1
  index=0
  while ((index < count)); do
    value="$(plist_value "$file" "$key_path.$index" || true)"
    [[ "$value" == "$expected" ]] && return 0
    index=$((index + 1))
  done
  return 1
}

plist_array_is_exact_set() {
  local file="$1"
  local key_path="$2"
  local expected_count="$3"
  shift 3
  local count expected

  [[ "$(plist_type "$file" "$key_path" || true)" == "array" ]] || return 1
  count="$(plist_value "$file" "$key_path" || true)"
  [[ "$count" == "$expected_count" ]] || return 1
  for expected in "$@"; do
    plist_array_contains "$file" "$key_path" "$expected" || return 1
  done
}

profile_supports_value() {
  local profile="$1"
  local key_path="$2"
  local expected="$3"
  local value_type value

  value_type="$(plist_type "$profile" "$key_path" || true)"
  case "$value_type" in
    string)
      value="$(plist_value "$profile" "$key_path" || true)"
      [[ "$value" == "*" || "$value" == "$expected" ]]
      ;;
    array)
      plist_array_contains "$profile" "$key_path" "$expected" ||
        plist_array_contains "$profile" "$key_path" "*"
      ;;
    *) return 1 ;;
  esac
}

profile_matches_release_contract() {
  local profile="$1"
  [[ "$(plist_value "$profile" 'Entitlements.application-identifier' || true)" == \
      "$EXPECTED_APPLICATION_ID" ]] || return 1
  [[ "$(plist_value "$profile" 'Entitlements.com\.apple\.developer\.team-identifier' || true)" == \
      "$EXPECTED_TEAM_ID" ]] || return 1
  plist_array_is_exact_set \
    "$profile" \
    'Entitlements.com\.apple\.developer\.icloud-container-identifiers' \
    1 \
    "$EXPECTED_ICLOUD_CONTAINER" || return 1
  plist_array_is_exact_set \
    "$profile" \
    'Entitlements.com\.apple\.security\.application-groups' \
    1 \
    "$EXPECTED_APP_GROUP" || return 1
  profile_supports_value \
    "$profile" \
    'Entitlements.com\.apple\.developer\.associated-domains' \
    'applinks:fearlesswallet.io' || return 1
  profile_supports_value \
    "$profile" \
    'Entitlements.com\.apple\.developer\.associated-domains' \
    'webcredentials:fearlesswallet.io' || return 1
  profile_supports_value \
    "$profile" \
    'Entitlements.com\.apple\.developer\.icloud-services' \
    'CloudKit' || return 1
  [[ "$(plist_value "$profile" 'Entitlements.get-task-allow' || true)" == "false" ]] || return 1
  [[ "$(plist_value "$profile" 'Entitlements.beta-reports-active' || true)" == "true" ]] || return 1
  ! plist_type "$profile" 'ProvisionedDevices' >/dev/null 2>&1 || return 1
  [[ "$(plist_value "$profile" 'ProvisionsAllDevices' || true)" != "true" ]] || return 1
  if [[ -n "$EXPECTED_PROFILE_UUID" ]]; then
    [[ "$(plist_value "$profile" 'UUID' || true)" == "$EXPECTED_PROFILE_UUID" ]] || return 1
  fi
  if [[ -n "$PROFILE_SPECIFIER" ]]; then
    [[ "$(plist_value "$profile" 'Name' || true)" == "$PROFILE_SPECIFIER" ]] || return 1
  fi
}

identity_output="$($SECURITY_BIN find-identity -v -p codesigning 2>/dev/null || true)"
identity_count="$(printf '%s\n' "$identity_output" | awk -v team="$EXPECTED_TEAM_ID" '
  /^[[:space:]]*[0-9]+\)[[:space:]]+[0-9A-Fa-f]{40}[[:space:]]+/ &&
    ($0 ~ /"Apple Distribution:/ || $0 ~ /"iPhone Distribution:/) &&
    index($0, "(" team ")\"") { count += 1 }
  END { print count + 0 }
')"
unset identity_output

matching_profile_count=0
IFS=':' read -r -a profile_directories <<< "$PROFILE_DIRS"
for profile_directory in "${profile_directories[@]}"; do
  [[ -d "$profile_directory" ]] || continue
  while IFS= read -r -d '' profile_path; do
    decoded_profile="$temporary_root/profile-$matching_profile_count.plist"
    if "$SECURITY_BIN" cms -D -i "$profile_path" >"$decoded_profile" 2>/dev/null &&
      profile_matches_release_contract "$decoded_profile"; then
      matching_profile_count=$((matching_profile_count + 1))
    fi
    rm -f "$decoded_profile"
  done < <(find "$profile_directory" -type f \
    \( -name '*.mobileprovision' -o -name '*.provisionprofile' \) -print0 2>/dev/null)
done

if ((identity_count == 0 && matching_profile_count == 0)); then
  if [[ "$SIGNING_REQUIRED" == "1" ]]; then
    fail "Signed Release validation is required, but no code-signing identity or matching provisioning profile is installed."
  fi
  echo "$PREFIX SKIPPED: no code-signing identity or matching provisioning profile is installed."
  exit 0
fi

if ((identity_count == 0 || matching_profile_count == 0)); then
  fail "Signing material is only partially configured; both a code-signing identity and a matching provisioning profile are required."
fi

archive_path="$temporary_root/FearlessRelease.xcarchive"
build_log="$temporary_root/xcodebuild.log"
: >"$build_log"
chmod 600 "$build_log"

signing_overrides=()
if [[ -n "$PROFILE_SPECIFIER" ]]; then
  signing_overrides+=(
    "CODE_SIGN_STYLE=Manual"
    "CODE_SIGN_IDENTITY=Apple Distribution"
    "DEVELOPMENT_TEAM=$EXPECTED_TEAM_ID"
    "PROVISIONING_PROFILE_SPECIFIER=$PROFILE_SPECIFIER"
  )
fi

if ! SOURCE_PACKAGES_DIR="$SOURCE_PACKAGES_DIR" \
  ALLOW_DERIVEDDATA_FALLBACK=0 \
  STRICT_REQUIRED_PATCHES=1 \
  "$XCODEBUILD_BIN" \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
    -disableAutomaticPackageResolution \
    -archivePath "$archive_path" \
    "${signing_overrides[@]}" \
    archive >"$build_log" 2>&1; then
  echo "$PREFIX ERROR: signed Release archive failed. Sanitized diagnostics:" >&2
  sed -E \
    -e 's/[0-9A-Fa-f]{40,64}/[REDACTED_DIGEST]/g' \
    -e 's/(Signing Identity:).*/\1 [REDACTED]/' \
    -e 's/(Provisioning Profile:).*/\1 [REDACTED]/' \
    -e 's/(Certificate:).*/\1 [REDACTED]/' \
    "$build_log" |
    grep -E '(^|[[:space:]])(error:|ERROR:)|\*\* ARCHIVE FAILED \*\*' |
    tail -n 20 >&2 || true
  exit 1
fi

bash "$ROOT_DIR/scripts/ci/materialize-embedded-framework-dsyms.sh" \
  "$archive_path"

applications_dir="$archive_path/Products/Applications"
[[ -d "$applications_dir" ]] || fail "The Release archive contains no Applications directory."
app_path=""
app_count=0
while IFS= read -r -d '' candidate_app; do
  app_path="$candidate_app"
  app_count=$((app_count + 1))
done < <(find "$applications_dir" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print0)
[[ "$app_count" == "1" && -n "$app_path" ]] || fail \
  "The Release archive must contain exactly one application product."

"$CODESIGN_BIN" --verify --deep --strict "$app_path" >/dev/null 2>&1 || fail \
  "The archived application failed strict code-signature verification."
[[ -f "$app_path/embedded.mobileprovision" ]] || fail \
  "The archived application does not contain an embedded provisioning profile."
[[ -f "$app_path/PrivacyInfo.xcprivacy" ]] || fail \
  "The archived application does not contain PrivacyInfo.xcprivacy."

signed_entitlements="$temporary_root/signed-entitlements.plist"
embedded_profile="$temporary_root/embedded-profile.plist"
: >"$signed_entitlements"
: >"$embedded_profile"
chmod 600 "$signed_entitlements" "$embedded_profile"
"$CODESIGN_BIN" -d --entitlements :- "$app_path" >"$signed_entitlements" 2>/dev/null || fail \
  "Signed entitlements could not be extracted from the archived application."
"$SECURITY_BIN" cms -D -i "$app_path/embedded.mobileprovision" >"$embedded_profile" 2>/dev/null || fail \
  "The embedded provisioning profile could not be decoded."

[[ "$(plist_value "$app_path/Info.plist" 'CFBundleIdentifier' || true)" == "$EXPECTED_BUNDLE_ID" ]] || fail \
  "The archived application bundle identifier does not match the production contract."
[[ "$(plist_value "$signed_entitlements" 'application-identifier' || true)" == "$EXPECTED_APPLICATION_ID" ]] || fail \
  "The signed application identifier does not match the production contract."
[[ "$(plist_value "$signed_entitlements" 'com\.apple\.developer\.team-identifier' || true)" == "$EXPECTED_TEAM_ID" ]] || fail \
  "The signed team identifier does not match the production contract."
[[ "$(plist_value "$signed_entitlements" 'beta-reports-active' || true)" == "true" ]] || fail \
  "The signed application must carry the App Store beta-reports-active entitlement."
plist_array_is_exact_set \
  "$signed_entitlements" \
  'com\.apple\.developer\.associated-domains' \
  2 \
  'applinks:fearlesswallet.io' \
  'webcredentials:fearlesswallet.io' || fail \
  "The signed associated-domain entitlement does not match the production contract."
plist_array_is_exact_set \
  "$signed_entitlements" \
  'com\.apple\.developer\.icloud-container-identifiers' \
  1 \
  "$EXPECTED_ICLOUD_CONTAINER" || fail \
  "The signed CloudKit container entitlement does not match the production contract."
plist_array_is_exact_set \
  "$signed_entitlements" \
  'com\.apple\.developer\.icloud-services' \
  1 \
  'CloudKit' || fail \
  "The signed CloudKit service entitlement does not match the production contract."
plist_array_is_exact_set \
  "$signed_entitlements" \
  'com\.apple\.security\.application-groups' \
  1 \
  "$EXPECTED_APP_GROUP" || fail \
  "The signed application-group entitlement does not match the production contract."
if plist_type "$signed_entitlements" 'keychain-access-groups' >/dev/null 2>&1; then
  fail "The archived application contains an unreviewed explicit keychain access-group entitlement."
fi

profile_matches_release_contract "$embedded_profile" || fail \
  "The embedded provisioning profile does not authorize the production entitlement contract."

signed_get_task_allow="$(plist_value "$signed_entitlements" 'get-task-allow' || true)"
profile_get_task_allow="$(plist_value "$embedded_profile" 'Entitlements.get-task-allow' || true)"
[[ "$signed_get_task_allow" == "false" && "$profile_get_task_allow" == "false" ]] || fail \
  "The production archive and embedded profile must both set get-task-allow to false."

echo "$PREFIX PASSED: signed Release archive, entitlements, provisioning profile, and privacy manifest are consistent."
