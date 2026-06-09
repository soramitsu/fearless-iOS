#!/usr/bin/env bash
# shellcheck disable=SC1003,SC2016
set -euo pipefail

ROOT="${1:-$(pwd)}"
archive_smoke="$ROOT/scripts/ci/archive-smoke.sh"

fail() {
  echo "[check-archive-smoke-contracts] ERROR: $*" >&2
  exit 1
}

[[ -f "$archive_smoke" ]] || fail "Missing file: $archive_smoke"

require_line() {
  local pattern="$1"
  local description="$2"

  grep -Fq -- "$pattern" "$archive_smoke" ||
    fail "archive-smoke must verify ${description}"
}

require_line 'codesign --verify --strict --verbose=2 "$app_path"' "signed archive code signature"
require_line 'trap cleanup_temp_paths EXIT' "archive-smoke temporary path cleanup trap"
require_line 'register_temp_path "$entitlements"' "temporary entitlement plist cleanup registration"
require_line 'register_temp_path "$decoded"' "temporary decoded profile cleanup registration"
require_line 'register_temp_path "$package_dir"' "temporary IPA extraction cleanup registration"
require_line 'register_temp_path "$export_options"' "temporary export options cleanup registration"
require_line 'profile_get_task_allow()' "profile get-task-allow helper"
require_line 'profile_has_provisioned_devices()' "profile provisioned-device helper"
require_line 'export_method_requires_provisioned_devices()' "export-method device requirement helper"
require_line 'export_method_uses_development_profile()' "development export profile helper"
require_line 'SIGNING_MODE="${SIGNING_MODE:-manual}"' "manual signing default"
require_line 'EXPORT_METHOD="${EXPORT_METHOD:-release-testing}"' "release-testing export default"
require_line 'INSTALL_EXPORTED_IPA="${INSTALL_EXPORTED_IPA:-0}"' "opt-in exported IPA install default"
require_line 'INSTALL_DEVICE_ID="${INSTALL_DEVICE_ID:-${DEVICE_ID:-}}"' "exported IPA install device id"
require_line 'INSTALL_LAUNCH_APP="${INSTALL_LAUNCH_APP:-${LAUNCH_APP:-1}}"' "exported IPA launch default"
require_line 'INSTALL_TIMEOUT_SECONDS="${INSTALL_TIMEOUT_SECONDS:-120}"' "exported IPA install timeout"
require_line 'SIGNING_MODE=automatic requires EXPORT_SIGNED_ARCHIVE=1' "automatic signing release export requirement"
require_line 'AUTOMATIC_ARCHIVE_IDENTITY="${AUTOMATIC_ARCHIVE_IDENTITY:-Apple Development}"' "automatic archive signing identity"
require_line 'AUTOMATIC_EXPORT_SIGNING_CERTIFICATE="${AUTOMATIC_EXPORT_SIGNING_CERTIFICATE:-}"' "cloud-managed automatic export default"
require_line 'APP_STORE_CONNECT_API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_API_KEY_PATH:-}}"' "App Store Connect API key path configuration"
require_line 'APP_STORE_CONNECT_API_KEY_CONTENT="${APP_STORE_CONNECT_API_KEY_CONTENT:-${ASC_API_KEY_CONTENT:-}}"' "App Store Connect API key content configuration"
require_line 'APP_STORE_CONNECT_API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_API_KEY_ID:-}}"' "App Store Connect API key id configuration"
require_line 'APP_STORE_CONNECT_API_KEY_ISSUER_ID="${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-${ASC_API_KEY_ISSUER_ID:-${APP_STORE_CONNECT_ISSUER_ID:-}}}"' "App Store Connect API key issuer configuration"
require_line 'configure_app_store_connect_auth_args' "App Store Connect API key argument configuration"
require_line 'APP_STORE_CONNECT_AUTH_ARGS=(' "App Store Connect authentication argument construction"
require_line '-authenticationKeyPath "$APP_STORE_CONNECT_API_KEY_PATH"' "xcodebuild App Store Connect key path flag"
require_line '-authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID"' "xcodebuild App Store Connect key id flag"
require_line '-authenticationKeyIssuerID "$APP_STORE_CONNECT_API_KEY_ISSUER_ID"' "xcodebuild App Store Connect issuer flag"
require_line 'ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-0}"' "opt-in Xcode provisioning updates"
require_line 'provisioning_updates_enabled()' "provisioning update policy helper"
require_line 'Continuing signed archive because provisioning updates are enabled' "signed archive provisioning update continuation"
require_line 'signed_archive_args+=(-allowProvisioningUpdates)' "signed archive provisioning update flag"
require_line 'signed_archive_args+=("${APP_STORE_CONNECT_AUTH_ARGS[@]}")' "signed archive App Store Connect authentication flags"
require_line 'export_args+=(-allowProvisioningUpdates)' "automatic export provisioning update flag"
require_line 'export_args+=("${APP_STORE_CONNECT_AUTH_ARGS[@]}")' "export App Store Connect authentication flags"
require_line 'ad-hoc | release-testing | debugging)' "device-backed export guard"
require_line 'reject_reasons+=("get-task-allow ${get_task_allow:-missing}, expected true for ${EXPORT_METHOD}")' "debugging profile get-task-allow preflight rejection"
require_line 'reject_reasons+=("get-task-allow ${get_task_allow:-missing}, expected false for ${EXPORT_METHOD}")' "release profile get-task-allow preflight rejection"
require_line 'reject_reasons+=("missing ProvisionedDevices for ${EXPORT_METHOD} export")' "device-backed export provisioned-devices preflight rejection"
require_line 'assert_profile_release_distribution "$decoded" "$artifact_label"' "embedded profile release distribution assertion"
require_line 'expected_get_task_allow="true"' "debugging embedded profile get-task-allow assertion"
require_line 'assert_profile_supports_export_method "$decoded" "$artifact_label"' "embedded profile export method assertion"
require_line 'assert_plist_value_equals "$info_plist" "CFBundleIdentifier" "$SIGNING_BUNDLE_ID" "bundle identifier" "$artifact_label"' "signed archive and IPA bundle identifier"
require_line 'assert_plist_value_equals "$entitlements" "application-identifier" "$expected_app_identifier" "application identifier" "$artifact_label"' "signed archive and IPA application identifier"
require_line 'assert_plist_value_equals "$entitlements" "com.apple.developer.team-identifier" "$SIGNING_TEAM_ID" "team identifier" "$artifact_label"' "signed archive and IPA team identifier"
require_line 'assert_plist_array_contains "$entitlements" "com.apple.security.application-groups" "$SIGNING_REQUIRED_APP_GROUP" "App Group" "$artifact_label"' "signed archive and IPA WalletConnect App Group entitlement"
require_line 'verify_app_bundle "$app_path" "signed archive app"' "signed archive app bundle"
require_line 'verify_embedded_profile "$app_path/embedded.mobileprovision" "signed archive app"' "signed archive embedded profile"
require_line 'verify_app_bundle "$app_path" "automatic signed archive app"' "automatic signed archive app bundle"
require_line 'EXPORT_SIGNED_ARCHIVE="${EXPORT_SIGNED_ARCHIVE:-$SIGNED_ARCHIVE}"' "signed archive export default"
require_line 'find_single_exported_ipa_path()' "single exported IPA path helper"
require_line '/usr/libexec/PlistBuddy -c "Add :method string ${EXPORT_METHOD}" "$export_options"' "export options method"
require_line '/usr/libexec/PlistBuddy -c "Add :signingStyle string ${SIGNING_MODE}" "$export_options"' "export options signing style"
require_line '/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:${SIGNING_BUNDLE_ID} string ${SIGNING_PROFILE_SPECIFIER}" "$export_options"' "export provisioning profile mapping"
require_line 'if [[ -n "$AUTOMATIC_EXPORT_SIGNING_CERTIFICATE" ]]; then' "optional automatic export signing certificate"
require_line '/usr/libexec/PlistBuddy -c "Add :signingCertificate string ${AUTOMATIC_EXPORT_SIGNING_CERTIFICATE}" "$export_options"' "optional automatic export signing certificate"
require_line 'Automatic export failed. Ensure Xcode has valid Apple account credentials' "automatic export account failure diagnostic"
require_line 'xcodebuild \' "signed archive IPA export"
require_line '    -exportArchive \' "signed archive IPA export mode"
if grep -Fq 'PROVISIONING_PROFILE_SPECIFIER="$SIGNING_PROFILE_SPECIFIER" \' "$archive_smoke"; then
  fail "archive-smoke must not pass PROVISIONING_PROFILE_SPECIFIER globally to xcodebuild; SwiftPM package targets do not support provisioning profiles"
fi
if grep -Fq 'DEVELOPMENT_TEAM="$SIGNING_TEAM_ID" \' "$archive_smoke"; then
  fail "archive-smoke must not pass DEVELOPMENT_TEAM globally to xcodebuild; use the app target signing settings and verify the archive output instead"
fi
if grep -Fq 'CODE_SIGN_STYLE=Manual \' "$archive_smoke"; then
  fail "archive-smoke must not pass CODE_SIGN_STYLE globally to xcodebuild; use the app target signing settings and verify the archive output instead"
fi
if grep -Fq 'CODE_SIGN_IDENTITY="$SIGNING_IDENTITY_PATTERN" \' "$archive_smoke"; then
  fail "archive-smoke must not pass CODE_SIGN_IDENTITY globally to xcodebuild; SwiftPM package targets inherit command-line signing settings"
fi
require_line 'CODE_SIGN_STYLE=Automatic' "automatic archive signing style override"
require_line 'CODE_SIGN_IDENTITY="$AUTOMATIC_ARCHIVE_IDENTITY"' "automatic archive identity override"
require_line 'verify_exported_ipa' "exported IPA presence"
require_line 'unzip -q "$ipa_path" -d "$package_dir"' "exported IPA unpacking"
require_line 'verify_app_bundle "$packaged_app" "exported IPA app"' "exported IPA app bundle"
require_line 'verify_embedded_profile "$packaged_app/embedded.mobileprovision" "exported IPA app"' "exported IPA embedded profile"
require_line 'install_exported_ipa()' "exported IPA physical-device install helper"
require_line 'IPA_PATH="$EXPORTED_IPA_PATH"' "exported IPA path handoff to install helper"
require_line 'BUNDLE_ID="$SIGNING_BUNDLE_ID"' "bundle id handoff to install helper"
require_line 'DEVICE_ID="$INSTALL_DEVICE_ID"' "device id handoff to install helper"
require_line 'LAUNCH_APP="$INSTALL_LAUNCH_APP"' "launch flag handoff to install helper"
require_line 'TIMEOUT_SECONDS="$INSTALL_TIMEOUT_SECONDS"' "timeout handoff to install helper"
require_line 'if [[ "$INSTALL_EXPORTED_IPA" == "1" ]]; then' "opt-in install after export verification"
require_line 'install_exported_ipa' "exported IPA install call"
require_line 'assert_plist_value_equals "$decoded" "Name" "$SIGNING_PROFILE_SPECIFIER" "profile name" "$artifact_label"' "embedded profile name"
require_line 'assert_plist_value_equals "$decoded" "TeamIdentifier:0" "$SIGNING_TEAM_ID" "profile team identifier" "$artifact_label"' "embedded profile team identifier"
require_line 'assert_plist_value_equals "$decoded" "Entitlements:application-identifier" "$expected_app_identifier" "profile application identifier" "$artifact_label"' "embedded profile application identifier"
require_line 'assert_plist_array_contains "$decoded" "Entitlements:com.apple.security.application-groups" "$SIGNING_REQUIRED_APP_GROUP" "profile App Group" "$artifact_label"' "embedded profile App Group"
require_line 'assert_profile_not_expired "$decoded" "$artifact_label"' "embedded profile expiration"

echo "[check-archive-smoke-contracts] OK"
