#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

readonly SCHEME_FILE="${IOS_RELEASE_SCHEME_FILE:-$REPO_ROOT/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme}"
readonly ENTITLEMENTS_FILE="${IOS_RELEASE_ENTITLEMENTS_FILE:-$REPO_ROOT/fearless/WalletConnect.entitlements}"
readonly INFO_PLIST_FILE="${IOS_RELEASE_INFO_PLIST_FILE:-$REPO_ROOT/fearless/Info.plist}"
readonly EXPECTED_BUNDLE_ID="${IOS_EXPECTED_BUNDLE_ID:-jp.co.soramitsu.fearlesswallet}"
readonly EXPECTED_VERSION="${IOS_EXPECTED_MARKETING_VERSION:-4.2.0}"
readonly EXPECTED_BUILD="${IOS_EXPECTED_BUILD_NUMBER:-2026.7.26}"

fail() {
  printf '[ios-release-identity] FAIL: %s\n' "$*" >&2
  exit 1
}

require_regular_file() {
  local path="$1"
  local label="$2"

  [[ -f "$path" ]] || fail "$label is missing: $path"
  [[ ! -L "$path" ]] || fail "$label must not be a symbolic link: $path"
}

require_regular_file "$SCHEME_FILE" "shared scheme"
require_regular_file "$ENTITLEMENTS_FILE" "production entitlements"
require_regular_file "$INFO_PLIST_FILE" "application Info.plist"

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

jq -e '
  type == "array" and
  ([.[] | select(.target == "fearless")] | length == 1)
' "$settings_json" >/dev/null ||
  fail "Release settings must contain exactly one fearless target"

read_setting() {
  local key="$1"

  jq -er --arg key "$key" '
    [.[] | select(.target == "fearless")][0].buildSettings[$key] //
      error("missing setting")
  ' "$settings_json" 2>/dev/null ||
    fail "Release setting is missing: $key"
}

require_setting() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(read_setting "$key")"
  [[ "$actual" == "$expected" ]] ||
    fail "$key is '$actual', expected '$expected'"
}

require_setting PRODUCT_BUNDLE_IDENTIFIER "$EXPECTED_BUNDLE_ID"
require_setting MARKETING_VERSION "$EXPECTED_VERSION"
require_setting CURRENT_PROJECT_VERSION "$EXPECTED_BUILD"
require_setting CODE_SIGN_ENTITLEMENTS "fearless/WalletConnect.entitlements"
require_setting CODE_SIGN_STYLE "Automatic"
require_setting SWIFT_OPTIMIZATION_LEVEL "-O"
require_setting ENABLE_TESTABILITY "NO"

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

if [[ -n "$generated_settings" ]]; then
  rm -f "$generated_settings"
fi

printf '%s\n' \
  "[ios-release-identity] PASS: Release archives $EXPECTED_BUNDLE_ID $EXPECTED_VERSION ($EXPECTED_BUILD)"
