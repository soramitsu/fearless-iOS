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
      CURRENT_PROJECT_VERSION: "2026.7.26",
      CODE_SIGN_ENTITLEMENTS: "fearless/WalletConnect.entitlements",
      CODE_SIGN_STYLE: "Automatic",
      SWIFT_OPTIMIZATION_LEVEL: "-O",
      ENABLE_TESTABILITY: "NO"
    }
  }
]' > "$settings"

run_audit() {
  local info_plist="${4:-$REPO_ROOT/fearless/Info.plist}"

  IOS_RELEASE_SETTINGS_JSON="$1" \
  IOS_RELEASE_SCHEME_FILE="$2" \
  IOS_RELEASE_ENTITLEMENTS_FILE="$3" \
  IOS_RELEASE_INFO_PLIST_FILE="$info_plist" \
    bash "$AUDIT"
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

manual_signing="$FIXTURES/manual-signing.json"
mutate_setting CODE_SIGN_STYLE Manual "$manual_signing"
run_reject manual-signing \
  run_audit "$manual_signing" "$scheme" "$entitlements"

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
  '.["keychain-access-groups"] = ["group.com.walletconnect.sdk"]' \
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

printf '%s\n' \
  "[ios-release-identity-test] PASS: $pass_count positive and $fail_count negative/adversarial cases"
