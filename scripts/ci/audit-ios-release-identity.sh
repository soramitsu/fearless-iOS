#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

readonly EXPECTED_DEVELOPMENT_TEAM="YLWWUD25VZ"
readonly AUDIT_TEST_HARNESS="${IOS_RELEASE_AUDIT_TEST_HARNESS:-0}"

fail() {
  printf '[ios-release-identity] FAIL: %s\n' "$*" >&2
  exit 1
}

readonly TEST_HARNESS_OVERRIDE_NAMES=(
  IOS_RELEASE_SCHEME_FILE
  IOS_RELEASE_ENTITLEMENTS_FILE
  IOS_DEBUG_ENTITLEMENTS_FILE
  IOS_RELEASE_INFO_PLIST_FILE
  IOS_RELEASE_WALLET_CONNECT_SERVICE_FILE
  IOS_RELEASE_SETTINGS_JSON
  IOS_DEBUG_SETTINGS_JSON
  IOS_EXPECTED_BUNDLE_ID
  IOS_EXPECTED_DEBUG_BUNDLE_ID
  IOS_EXPECTED_MARKETING_VERSION
)
if [[ "$AUDIT_TEST_HARNESS" != "1" ]]; then
  for override_name in "${TEST_HARNESS_OVERRIDE_NAMES[@]}"; do
    [[ -z "${!override_name:-}" ]] ||
      fail "$override_name is accepted only with IOS_RELEASE_AUDIT_TEST_HARNESS=1"
  done
fi

readonly SCHEME_FILE="${IOS_RELEASE_SCHEME_FILE:-$REPO_ROOT/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme}"
readonly ENTITLEMENTS_FILE="${IOS_RELEASE_ENTITLEMENTS_FILE:-$REPO_ROOT/fearless/WalletConnect.entitlements}"
readonly DEBUG_ENTITLEMENTS_FILE="${IOS_DEBUG_ENTITLEMENTS_FILE:-$REPO_ROOT/fearless/WalletConnect.dev.entitlements}"
readonly INFO_PLIST_FILE="${IOS_RELEASE_INFO_PLIST_FILE:-$REPO_ROOT/fearless/Info.plist}"
readonly WALLET_CONNECT_SERVICE_FILE="${IOS_RELEASE_WALLET_CONNECT_SERVICE_FILE:-$REPO_ROOT/fearless/ApplicationLayer/Services/WalletConnect/WalletConnectService.swift}"
readonly EXPECTED_BUNDLE_ID="${IOS_EXPECTED_BUNDLE_ID:-jp.co.soramitsu.fearlesswallet}"
readonly EXPECTED_DEBUG_BUNDLE_ID="${IOS_EXPECTED_DEBUG_BUNDLE_ID:-jp.co.soramitsu.fearlesswallet.dev}"
readonly EXPECTED_VERSION="${IOS_EXPECTED_MARKETING_VERSION:-4.2.0}"
readonly EXPECTED_BUILD="${IOS_EXPECTED_BUILD_NUMBER:-}"
[[ "$EXPECTED_BUILD" =~ ^[1-9][0-9]{0,3}(\.[0-9]{1,2}){0,2}$ ]] ||
  fail "IOS_EXPECTED_BUILD_NUMBER must be an explicit canonical CFBundleVersion"

require_regular_file() {
  local path="$1"
  local label="$2"

  [[ -f "$path" ]] || fail "$label is missing: $path"
  [[ ! -L "$path" ]] || fail "$label must not be a symbolic link: $path"
}

require_regular_file "$SCHEME_FILE" "shared scheme"
require_regular_file "$ENTITLEMENTS_FILE" "production entitlements"
require_regular_file "$DEBUG_ENTITLEMENTS_FILE" "development entitlements"
require_regular_file "$INFO_PLIST_FILE" "application Info.plist"
require_regular_file "$WALLET_CONNECT_SERVICE_FILE" "WalletConnect service"

bundle_version="$(
  plutil -extract CFBundleVersion raw "$INFO_PLIST_FILE" 2>/dev/null
)" || fail "application Info.plist has no CFBundleVersion"
[[ "$bundle_version" == '$(CURRENT_PROJECT_VERSION)' ]] ||
  fail "CFBundleVersion must expand CURRENT_PROJECT_VERSION"

short_version="$(
  plutil -extract CFBundleShortVersionString raw "$INFO_PLIST_FILE" 2>/dev/null
)" || fail "application Info.plist has no CFBundleShortVersionString"
[[ "$short_version" == '$(MARKETING_VERSION)' ]] ||
  fail "CFBundleShortVersionString must expand MARKETING_VERSION"

git_commit="$(
  plutil -extract FearlessGitCommit raw "$INFO_PLIST_FILE" 2>/dev/null
)" || fail "application Info.plist has no FearlessGitCommit"
[[ "$git_commit" == '$(FEARLESS_GIT_COMMIT)' ]] ||
  fail "FearlessGitCommit must expand FEARLESS_GIT_COMMIT"

archive_action_count="$(
  xmllint --xpath 'count(/Scheme/ArchiveAction)' "$SCHEME_FILE" 2>/dev/null
)" || fail "shared scheme is not valid XML"
[[ "$archive_action_count" == "1" ]] ||
  fail "shared scheme must contain exactly one ArchiveAction"

archive_configuration="$(
  xmllint --xpath 'string(/Scheme/ArchiveAction/@buildConfiguration)' \
    "$SCHEME_FILE" 2>/dev/null
)" || fail "cannot read ArchiveAction configuration"
[[ "$archive_configuration" == "Release" ]] ||
  fail "shared scheme archives $archive_configuration instead of Release"

settings_json="${IOS_RELEASE_SETTINGS_JSON:-}"
generated_settings=""
if [[ -z "$settings_json" ]]; then
  generated_settings="$(mktemp "${TMPDIR:-/tmp}/fearless-release-settings.XXXXXX")"
  settings_json="$generated_settings"

  xcodebuild_args=(
    -workspace "$REPO_ROOT/fearless.xcworkspace"
    -scheme fearless
    -configuration Release
    -destination "generic/platform=iOS"
    -showBuildSettings
    -json
    "CURRENT_PROJECT_VERSION=$EXPECTED_BUILD"
  )

  if [[ -n "${IOS_RELEASE_SOURCE_PACKAGES_DIR:-}" ]]; then
    xcodebuild_args+=(
      -clonedSourcePackagesDirPath "$IOS_RELEASE_SOURCE_PACKAGES_DIR"
      -disableAutomaticPackageResolution
      -skipPackageUpdates
    )
  fi

  xcodebuild "${xcodebuild_args[@]}" > "$settings_json" ||
    fail "xcodebuild could not resolve Release settings"
else
  require_regular_file "$settings_json" "Release settings JSON"
fi

debug_settings_json="${IOS_DEBUG_SETTINGS_JSON:-}"
generated_debug_settings=""
if [[ -z "$debug_settings_json" ]]; then
  generated_debug_settings="$(
    mktemp "${TMPDIR:-/tmp}/fearless-debug-settings.XXXXXX"
  )"
  debug_settings_json="$generated_debug_settings"

  debug_xcodebuild_args=(
    -workspace "$REPO_ROOT/fearless.xcworkspace"
    -scheme fearless
    -configuration Debug
    -destination "generic/platform=iOS"
    -showBuildSettings
    -json
  )

  if [[ -n "${IOS_RELEASE_SOURCE_PACKAGES_DIR:-}" ]]; then
    debug_xcodebuild_args+=(
      -clonedSourcePackagesDirPath "$IOS_RELEASE_SOURCE_PACKAGES_DIR"
      -disableAutomaticPackageResolution
      -skipPackageUpdates
    )
  fi

  xcodebuild "${debug_xcodebuild_args[@]}" > "$debug_settings_json" ||
    fail "xcodebuild could not resolve Debug settings"
else
  require_regular_file "$debug_settings_json" "Debug settings JSON"
fi

jq -e '
  type == "array" and
  ([.[] | select(.target == "fearless")] | length == 1)
' "$settings_json" >/dev/null ||
  fail "Release settings must contain exactly one fearless target"

jq -e '
  type == "array" and
  ([.[] | select(.target == "fearless")] | length == 1)
' "$debug_settings_json" >/dev/null ||
  fail "Debug settings must contain exactly one fearless target"

read_setting() {
  local key="$1"

  jq -er --arg key "$key" '
    [.[] | select(.target == "fearless")][0].buildSettings[$key] //
      error("missing setting")
  ' "$settings_json" 2>/dev/null ||
    fail "Release setting is missing: $key"
}

read_debug_setting() {
  local key="$1"

  jq -er --arg key "$key" '
    [.[] | select(.target == "fearless")][0].buildSettings[$key] //
      error("missing setting")
  ' "$debug_settings_json" 2>/dev/null ||
    fail "Debug setting is missing: $key"
}

require_setting() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(read_setting "$key")"
  [[ "$actual" == "$expected" ]] ||
    fail "$key is '$actual', expected '$expected'"
}

require_debug_setting() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(read_debug_setting "$key")"
  [[ "$actual" == "$expected" ]] ||
    fail "Debug $key is '$actual', expected '$expected'"
}

require_setting PRODUCT_BUNDLE_IDENTIFIER "$EXPECTED_BUNDLE_ID"
require_setting MARKETING_VERSION "$EXPECTED_VERSION"
require_setting CURRENT_PROJECT_VERSION "$EXPECTED_BUILD"
require_setting CODE_SIGN_ENTITLEMENTS "fearless/WalletConnect.entitlements"
require_setting CODE_SIGN_STYLE "Automatic"
require_setting DEVELOPMENT_TEAM "$EXPECTED_DEVELOPMENT_TEAM"
require_setting SWIFT_OPTIMIZATION_LEVEL "-O"
require_setting ENABLE_TESTABILITY "NO"

require_debug_setting PRODUCT_BUNDLE_IDENTIFIER "$EXPECTED_DEBUG_BUNDLE_ID"
require_debug_setting \
  CODE_SIGN_ENTITLEMENTS \
  "fearless/WalletConnect.dev.entitlements"
require_debug_setting CODE_SIGN_STYLE "Automatic"
require_debug_setting DEVELOPMENT_TEAM "$EXPECTED_DEVELOPMENT_TEAM"

entitlements_json="$(
  plutil -convert json -o - "$ENTITLEMENTS_FILE" 2>/dev/null
)" || fail "production entitlements are not a valid property list"

jq -e '
  type == "object" and
  (keys | sort) == (
    [
      "com.apple.developer.associated-domains",
      "com.apple.developer.icloud-container-identifiers",
      "com.apple.developer.icloud-services",
      "com.apple.security.application-groups"
    ] | sort
  ) and
  .["com.apple.developer.associated-domains"] == [
    "applinks:fearlesswallet.io",
    "webcredentials:fearlesswallet.io"
  ] and
  .["com.apple.developer.icloud-container-identifiers"] == [
    "iCloud.jp.co.soramitsu.fearlesswallet"
  ] and
  .["com.apple.developer.icloud-services"] == ["CloudKit"] and
  .["com.apple.security.application-groups"] == [
    "group.jp.co.soramitsu.fearlesswallet"
  ] and
  (has("keychain-access-groups") | not)
' <<<"$entitlements_json" >/dev/null ||
  fail "production entitlements do not match the Fearless App Store identity"

debug_entitlements_json="$(
  plutil -convert json -o - "$DEBUG_ENTITLEMENTS_FILE" 2>/dev/null
)" || fail "development entitlements are not a valid property list"

jq -e '
  type == "object" and
  (keys | sort) == (
    [
      "com.apple.developer.associated-domains",
      "com.apple.developer.icloud-container-identifiers",
      "com.apple.developer.icloud-services",
      "com.apple.security.application-groups"
    ] | sort
  ) and
  .["com.apple.developer.associated-domains"] == [
    "webcredentials:fearlesswallet.io"
  ] and
  .["com.apple.developer.icloud-container-identifiers"] == [
    "iCloud.jp.co.soramitsu.fearless",
    "iCloud.jp.co.soramitsu.fearlesswallet.dev"
  ] and
  .["com.apple.developer.icloud-services"] == ["CloudKit"] and
  .["com.apple.security.application-groups"] == [
    "group.jp.co.soramitsu.fearlesswallet.walletconnect"
  ] and
  (has("keychain-access-groups") | not)
' <<<"$debug_entitlements_json" >/dev/null ||
  fail "Debug entitlements do not match the isolated development identity"

grep -Fq \
  'static let productionGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet"' \
  "$WALLET_CONNECT_SERVICE_FILE" ||
  fail "WalletConnect production consumer does not use the entitled app group"
grep -Fq \
  'static let developmentGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet.walletconnect"' \
  "$WALLET_CONNECT_SERVICE_FILE" ||
  fail "WalletConnect development consumer does not use the registered Debug app group"
grep -Fq \
  'WalletConnectGroupIdentifierResolver.resolve(' \
  "$WALLET_CONNECT_SERVICE_FILE" ||
  fail "WalletConnect setup does not resolve its group from the application identity"
grep -Fq \
  'groupIdentifier: groupIdentifier' \
  "$WALLET_CONNECT_SERVICE_FILE" ||
  fail "WalletConnect networking does not consume the resolved group"
if grep -Fq \
  'groupIdentifier: Self.walletConnectGroupIdentifier' \
  "$WALLET_CONNECT_SERVICE_FILE"; then
  fail "WalletConnect setup still consumes a hard-coded app group"
fi

if [[ -n "$generated_settings" ]]; then
  rm -f "$generated_settings"
fi
if [[ -n "$generated_debug_settings" ]]; then
  rm -f "$generated_debug_settings"
fi

printf '%s\n' \
  "[ios-release-identity] PASS: Release archives $EXPECTED_BUNDLE_ID $EXPECTED_VERSION ($EXPECTED_BUILD)"
