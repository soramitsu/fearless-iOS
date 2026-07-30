#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly AUDIT="$REPO_ROOT/scripts/ci/audit-ios-release-identity.sh"
readonly FIXTURES="$(mktemp -d "${TMPDIR:-/tmp}/fearless-release-identity-tests.XXXXXX")"

trap 'rm -rf "$FIXTURES"' EXIT

pass_count=0
fail_count=0

run_pass() {
  local label="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    pass_count=$((pass_count + 1))
  else
    printf '[ios-release-identity-test] expected pass: %s\n' "$label" >&2
    exit 1
  fi
}

run_reject() {
  local label="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    printf '[ios-release-identity-test] expected rejection: %s\n' "$label" >&2
    exit 1
  fi
  fail_count=$((fail_count + 1))
}

settings="$FIXTURES/settings.json"
jq -n '[
  {
    target: "fearless",
    buildSettings: {
      PRODUCT_BUNDLE_IDENTIFIER: "jp.co.soramitsu.fearlesswallet",
      MARKETING_VERSION: "4.2.0",
      CURRENT_PROJECT_VERSION: "2026.7.28",
      CODE_SIGN_ENTITLEMENTS: "fearless/WalletConnect.entitlements",
      CODE_SIGN_IDENTITY: "Apple Distribution: Soramitsu Co., Ltd. (YLWWUD25VZ)",
      CODE_SIGN_STYLE: "Manual",
      DEVELOPMENT_TEAM: "YLWWUD25VZ",
      PROVISIONING_PROFILE_SPECIFIER: "Fearless App Store 2026.7.26",
      SWIFT_OPTIMIZATION_LEVEL: "-O",
      ENABLE_TESTABILITY: "NO"
    }
  }
]' > "$settings"

debug_settings="$FIXTURES/debug-settings.json"
jq -n '[
  {
    target: "fearless",
    buildSettings: {
      PRODUCT_BUNDLE_IDENTIFIER: "jp.co.soramitsu.fearlesswallet.dev",
      CODE_SIGN_ENTITLEMENTS: "fearless/WalletConnect.dev.entitlements",
      CODE_SIGN_STYLE: "Automatic",
      DEVELOPMENT_TEAM: "YLWWUD25VZ"
    }
  }
]' > "$debug_settings"

dev_entitlements="$REPO_ROOT/fearless/WalletConnect.dev.entitlements"

run_audit() {
  local info_plist="${4:-$REPO_ROOT/fearless/Info.plist}"
  local wallet_connect_service="${5:-$REPO_ROOT/fearless/ApplicationLayer/Services/WalletConnect/WalletConnectService.swift}"
  local debug_settings_file="${6:-$debug_settings}"
  local debug_entitlements_file="${7:-$dev_entitlements}"

  IOS_RELEASE_AUDIT_TEST_HARNESS=1 \
  IOS_EXPECTED_BUILD_NUMBER=2026.7.28 \
  IOS_RELEASE_SETTINGS_JSON="$1" \
  IOS_DEBUG_SETTINGS_JSON="$debug_settings_file" \
  IOS_RELEASE_SCHEME_FILE="$2" \
  IOS_RELEASE_ENTITLEMENTS_FILE="$3" \
  IOS_DEBUG_ENTITLEMENTS_FILE="$debug_entitlements_file" \
  IOS_RELEASE_INFO_PLIST_FILE="$info_plist" \
  IOS_RELEASE_WALLET_CONNECT_SERVICE_FILE="$wallet_connect_service" \
    bash "$AUDIT"
}

run_debug_fixture() {
  local debug_settings_file="$1"
  local debug_entitlements_file="${2:-$dev_entitlements}"

  run_audit \
    "$settings" \
    "$scheme" \
    "$entitlements" \
    "$REPO_ROOT/fearless/Info.plist" \
    "$REPO_ROOT/fearless/ApplicationLayer/Services/WalletConnect/WalletConnectService.swift" \
    "$debug_settings_file" \
    "$debug_entitlements_file"
}

scheme="$REPO_ROOT/fearless.xcodeproj/xcshareddata/xcschemes/fearless.xcscheme"
entitlements="$REPO_ROOT/fearless/WalletConnect.entitlements"
run_pass canonical run_audit "$settings" "$scheme" "$entitlements"

dev_scheme="$FIXTURES/dev.xcscheme"
sed 's/buildConfiguration = "Release"/buildConfiguration = "Dev"/' \
  "$scheme" > "$dev_scheme"
run_reject dev-archive run_audit "$settings" "$dev_scheme" "$entitlements"

duplicate_scheme="$FIXTURES/duplicate.xcscheme"
sed 's#</Scheme>#<ArchiveAction buildConfiguration="Release"/></Scheme>#' \
  "$scheme" > "$duplicate_scheme"
run_reject duplicate-archive-action \
  run_audit "$settings" "$duplicate_scheme" "$entitlements"

scheme_symlink="$FIXTURES/scheme-link"
ln -s "$scheme" "$scheme_symlink"
run_reject scheme-symlink \
  run_audit "$settings" "$scheme_symlink" "$entitlements"

mutate_setting() {
  local key="$1"
  local value="$2"
  local destination="$3"

  jq --arg key "$key" --arg value "$value" \
    '.[0].buildSettings[$key] = $value' "$settings" > "$destination"
}

wrong_bundle="$FIXTURES/wrong-bundle.json"
mutate_setting PRODUCT_BUNDLE_IDENTIFIER jp.co.soramitsu.fearless "$wrong_bundle"
run_reject wrong-bundle run_audit "$wrong_bundle" "$scheme" "$entitlements"

wrong_version="$FIXTURES/wrong-version.json"
mutate_setting MARKETING_VERSION 4.1.9 "$wrong_version"
run_reject wrong-version run_audit "$wrong_version" "$scheme" "$entitlements"

wrong_build="$FIXTURES/wrong-build.json"
mutate_setting CURRENT_PROJECT_VERSION 7 "$wrong_build"
run_reject wrong-build run_audit "$wrong_build" "$scheme" "$entitlements"

debug_optimization="$FIXTURES/debug-optimization.json"
mutate_setting SWIFT_OPTIMIZATION_LEVEL -Onone "$debug_optimization"
run_reject debug-optimization \
  run_audit "$debug_optimization" "$scheme" "$entitlements"

testable_release="$FIXTURES/testable-release.json"
mutate_setting ENABLE_TESTABILITY YES "$testable_release"
run_reject testable-release \
  run_audit "$testable_release" "$scheme" "$entitlements"

automatic_signing="$FIXTURES/automatic-signing.json"
mutate_setting CODE_SIGN_STYLE Automatic "$automatic_signing"
run_reject automatic-signing \
  run_audit "$automatic_signing" "$scheme" "$entitlements"

wrong_signing_identity="$FIXTURES/wrong-signing-identity.json"
mutate_setting CODE_SIGN_IDENTITY "Apple Development" "$wrong_signing_identity"
run_reject wrong-signing-identity \
  run_audit "$wrong_signing_identity" "$scheme" "$entitlements"

wrong_profile="$FIXTURES/wrong-profile.json"
mutate_setting PROVISIONING_PROFILE_SPECIFIER \
  "Another App Store Profile" "$wrong_profile"
run_reject wrong-profile \
  run_audit "$wrong_profile" "$scheme" "$entitlements"

empty_profile="$FIXTURES/empty-profile.json"
mutate_setting PROVISIONING_PROFILE_SPECIFIER "" "$empty_profile"
run_reject empty-profile \
  run_audit "$empty_profile" "$scheme" "$entitlements"

wrong_team="$FIXTURES/wrong-team.json"
mutate_setting DEVELOPMENT_TEAM AAAAAAAAAA "$wrong_team"
run_reject wrong-development-team \
  run_audit "$wrong_team" "$scheme" "$entitlements"

dev_entitlement_setting="$FIXTURES/dev-entitlement-setting.json"
mutate_setting CODE_SIGN_ENTITLEMENTS \
  fearless/WalletConnect.dev.entitlements "$dev_entitlement_setting"
run_reject dev-entitlement-setting \
  run_audit "$dev_entitlement_setting" "$scheme" "$entitlements"

extra_target="$FIXTURES/extra-target.json"
jq '. + [.[0]]' "$settings" > "$extra_target"
run_reject duplicate-fearless-target \
  run_audit "$extra_target" "$scheme" "$entitlements"

malformed_settings="$FIXTURES/malformed-settings.json"
printf '%s\n' '{"not":"an array"}' > "$malformed_settings"
run_reject malformed-settings \
  run_audit "$malformed_settings" "$scheme" "$entitlements"

mutate_debug_setting() {
  local key="$1"
  local value="$2"
  local destination="$3"

  jq --arg key "$key" --arg value "$value" \
    '.[0].buildSettings[$key] = $value' \
    "$debug_settings" > "$destination"
}

debug_production_bundle="$FIXTURES/debug-production-bundle.json"
mutate_debug_setting \
  PRODUCT_BUNDLE_IDENTIFIER \
  jp.co.soramitsu.fearlesswallet \
  "$debug_production_bundle"
run_reject debug-production-bundle \
  run_debug_fixture "$debug_production_bundle"

debug_production_entitlements="$FIXTURES/debug-production-entitlements.json"
mutate_debug_setting \
  CODE_SIGN_ENTITLEMENTS \
  fearless/WalletConnect.entitlements \
  "$debug_production_entitlements"
run_reject debug-production-entitlements \
  run_debug_fixture "$debug_production_entitlements"

debug_manual_signing="$FIXTURES/debug-manual-signing.json"
mutate_debug_setting CODE_SIGN_STYLE Manual "$debug_manual_signing"
run_reject debug-manual-signing \
  run_debug_fixture "$debug_manual_signing"

debug_wrong_team="$FIXTURES/debug-wrong-team.json"
mutate_debug_setting DEVELOPMENT_TEAM AAAAAAAAAA "$debug_wrong_team"
run_reject debug-wrong-development-team \
  run_debug_fixture "$debug_wrong_team"

duplicate_debug_target="$FIXTURES/duplicate-debug-target.json"
jq '. + [.[0]]' "$debug_settings" > "$duplicate_debug_target"
run_reject duplicate-debug-target \
  run_debug_fixture "$duplicate_debug_target"

malformed_debug_settings="$FIXTURES/malformed-debug-settings.json"
printf '%s\n' '{"not":"an array"}' > "$malformed_debug_settings"
run_reject malformed-debug-settings \
  run_debug_fixture "$malformed_debug_settings"

mutate_entitlements() {
  local filter="$1"
  local destination="$2"

  plutil -convert json -o - "$entitlements" |
    jq "$filter" |
    plutil -convert xml1 -o "$destination" -
}

extra_cloud="$FIXTURES/extra-cloud.entitlements"
mutate_entitlements \
  '.["com.apple.developer.icloud-container-identifiers"] += ["iCloud.evil"]' \
  "$extra_cloud"
run_reject extra-cloud run_audit "$settings" "$scheme" "$extra_cloud"

missing_applinks="$FIXTURES/missing-applinks.entitlements"
mutate_entitlements \
  '.["com.apple.developer.associated-domains"] = ["webcredentials:fearlesswallet.io"]' \
  "$missing_applinks"
run_reject missing-applinks \
  run_audit "$settings" "$scheme" "$missing_applinks"

wrong_group="$FIXTURES/wrong-group.entitlements"
mutate_entitlements \
  '.["com.apple.security.application-groups"] = ["group.com.walletconnect.sdk"]' \
  "$wrong_group"
run_reject wrong-group run_audit "$settings" "$scheme" "$wrong_group"

keychain_group="$FIXTURES/keychain-group.entitlements"
mutate_entitlements \
  '.["keychain-access-groups"] = ["group.jp.co.soramitsu.fearlesswallet"]' \
  "$keychain_group"
run_reject unexpected-keychain-group \
  run_audit "$settings" "$scheme" "$keychain_group"

extra_entitlement="$FIXTURES/extra-entitlement.entitlements"
mutate_entitlements \
  '.["com.apple.developer.healthkit"] = true' \
  "$extra_entitlement"
run_reject unexpected-entitlement \
  run_audit "$settings" "$scheme" "$extra_entitlement"

entitlements_symlink="$FIXTURES/entitlements-link"
ln -s "$entitlements" "$entitlements_symlink"
run_reject entitlements-symlink \
  run_audit "$settings" "$scheme" "$entitlements_symlink"

debug_entitlements_production_group="$FIXTURES/debug-production-group.entitlements"
plutil -convert json -o - "$dev_entitlements" |
  jq '.["com.apple.security.application-groups"] = ["group.jp.co.soramitsu.fearlesswallet"]' |
  plutil -convert xml1 -o "$debug_entitlements_production_group" -
run_reject debug-production-group \
  run_debug_fixture "$debug_settings" "$debug_entitlements_production_group"

debug_entitlements_missing_group="$FIXTURES/debug-missing-group.entitlements"
plutil -convert json -o - "$dev_entitlements" |
  jq 'del(.["com.apple.security.application-groups"])' |
  plutil -convert xml1 -o "$debug_entitlements_missing_group" -
run_reject debug-missing-group \
  run_debug_fixture "$debug_settings" "$debug_entitlements_missing_group"

debug_entitlements_legacy_group="$FIXTURES/debug-legacy-group.entitlements"
plutil -convert json -o - "$dev_entitlements" |
  jq '.["com.apple.security.application-groups"] = ["group.com.walletconnect.sdk"]' |
  plutil -convert xml1 -o "$debug_entitlements_legacy_group" -
run_reject debug-legacy-group \
  run_debug_fixture "$debug_settings" "$debug_entitlements_legacy_group"

debug_entitlements_extra_group="$FIXTURES/debug-extra-group.entitlements"
plutil -convert json -o - "$dev_entitlements" |
  jq '.["com.apple.security.application-groups"] += ["group.evil"]' |
  plutil -convert xml1 -o "$debug_entitlements_extra_group" -
run_reject debug-extra-group \
  run_debug_fixture "$debug_settings" "$debug_entitlements_extra_group"

debug_entitlements_keychain_group="$FIXTURES/debug-keychain-group.entitlements"
plutil -convert json -o - "$dev_entitlements" |
  jq '.["keychain-access-groups"] = ["group.jp.co.soramitsu.fearlesswallet.walletconnect"]' |
  plutil -convert xml1 -o "$debug_entitlements_keychain_group" -
run_reject debug-explicit-keychain-group \
  run_debug_fixture "$debug_settings" "$debug_entitlements_keychain_group"

debug_entitlements_production_cloud="$FIXTURES/debug-production-cloud.entitlements"
plutil -convert json -o - "$dev_entitlements" |
  jq '.["com.apple.developer.icloud-container-identifiers"] = ["iCloud.jp.co.soramitsu.fearlesswallet"]' |
  plutil -convert xml1 -o "$debug_entitlements_production_cloud" -
run_reject debug-production-cloud \
  run_debug_fixture "$debug_settings" "$debug_entitlements_production_cloud"

debug_entitlements_symlink="$FIXTURES/debug-entitlements-link"
ln -s "$dev_entitlements" "$debug_entitlements_symlink"
run_reject debug-entitlements-symlink \
  run_debug_fixture "$debug_settings" "$debug_entitlements_symlink"

hardcoded_build_plist="$FIXTURES/hardcoded-build.plist"
cp "$REPO_ROOT/fearless/Info.plist" "$hardcoded_build_plist"
plutil -replace CFBundleVersion -string 1 "$hardcoded_build_plist"
run_reject hardcoded-bundle-version \
  run_audit "$settings" "$scheme" "$entitlements" "$hardcoded_build_plist"

hardcoded_version_plist="$FIXTURES/hardcoded-version.plist"
cp "$REPO_ROOT/fearless/Info.plist" "$hardcoded_version_plist"
plutil -replace CFBundleShortVersionString -string 4.2.0 \
  "$hardcoded_version_plist"
run_reject hardcoded-marketing-version \
  run_audit "$settings" "$scheme" "$entitlements" "$hardcoded_version_plist"

missing_production_group_service="$FIXTURES/missing-production-group.swift"
sed \
  's/static let productionGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet"/static let productionGroupIdentifier = "group.com.walletconnect.sdk"/' \
  "$REPO_ROOT/fearless/ApplicationLayer/Services/WalletConnect/WalletConnectService.swift" \
  > "$missing_production_group_service"
run_reject wallet-connect-production-group-mismatch \
  run_audit "$settings" "$scheme" "$entitlements" \
    "$REPO_ROOT/fearless/Info.plist" "$missing_production_group_service"

missing_development_group_service="$FIXTURES/missing-development-group.swift"
sed \
  's/group\.jp\.co\.soramitsu\.fearlesswallet\.walletconnect/group.com.walletconnect.sdk/' \
  "$REPO_ROOT/fearless/ApplicationLayer/Services/WalletConnect/WalletConnectService.swift" \
  > "$missing_development_group_service"
run_reject wallet-connect-development-group-mismatch \
  run_audit "$settings" "$scheme" "$entitlements" \
    "$REPO_ROOT/fearless/Info.plist" "$missing_development_group_service"

hardcoded_group_service="$FIXTURES/hardcoded-wallet-connect-group.swift"
sed \
  's/groupIdentifier: groupIdentifier/groupIdentifier: Self.walletConnectGroupIdentifier/' \
  "$REPO_ROOT/fearless/ApplicationLayer/Services/WalletConnect/WalletConnectService.swift" \
  > "$hardcoded_group_service"
run_reject wallet-connect-hardcoded-group \
  run_audit "$settings" "$scheme" "$entitlements" \
    "$REPO_ROOT/fearless/Info.plist" "$hardcoded_group_service"

printf '%s\n' \
  "[ios-release-identity-test] PASS: $pass_count positive and $fail_count negative/adversarial cases"
