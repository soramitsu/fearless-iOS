#!/usr/bin/env bash
# shellcheck disable=SC1003,SC2016
set -euo pipefail

ROOT="${1:-$(pwd)}"
workflow="$ROOT/.github/workflows/codecov.yml"

fail() {
  echo "[check-ci-signing-contracts] ERROR: $*" >&2
  exit 1
}

[[ -f "$workflow" ]] || fail "Missing file: $workflow"

require_line() {
  local pattern="$1"
  local description="$2"

  grep -Fq -- "$pattern" "$workflow" ||
    fail "Codecov workflow must include ${description}"
}

reject_line() {
  local pattern="$1"
  local description="$2"

  if grep -Fq -- "$pattern" "$workflow"; then
    fail "Codecov workflow must not use ${description}"
  fi
}

reject_line 'mapfile ' "Bash 4-only mapfile"
reject_line 'readarray ' "Bash 4-only readarray"
require_line 'KEYCHAIN_PATH="$RUNNER_TEMP/fearless-release-signing.keychain-db"' "dedicated release signing keychain"
require_line 'ORIGINAL_KEYCHAINS="$RUNNER_TEMP/fearless-original-keychains.txt"' "original keychain list capture path"
require_line 'APP_STORE_CONNECT_API_KEY_CONTENT: ${{ secrets.APP_STORE_CONNECT_API_KEY_CONTENT }}' "App Store Connect API key content secret mapping"
require_line 'APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}' "App Store Connect API key id secret mapping"
require_line 'APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}' "App Store Connect API key issuer secret mapping"
require_line 'api_key_secret_count=0' "App Store Connect API key secret completeness check"
require_line 'Using App Store Connect API key automatic signing; skipping manual signing asset install.' "automatic signing skips manual asset install"
require_line 'echo "FEARLESS_SIGNING_MODE=automatic" >> "$GITHUB_ENV"' "automatic signing mode env handoff"
require_line 'echo "FEARLESS_SIGNING_KEYCHAIN_PATH=$KEYCHAIN_PATH"' "early signing keychain cleanup env handoff"
require_line 'echo "FEARLESS_SIGNING_CERT_PATH=$CERT_PATH"' "early decoded certificate cleanup env handoff"
require_line 'echo "FEARLESS_SIGNING_PROFILE_PATH=$PROFILE_PATH"' "early decoded provisioning profile cleanup env handoff"
require_line 'echo "FEARLESS_SIGNING_PROFILE_PLIST=$PROFILE_PLIST"' "early decoded profile plist cleanup env handoff"
require_line 'echo "FEARLESS_SIGNING_ORIGINAL_KEYCHAINS=$ORIGINAL_KEYCHAINS"' "early original keychain list cleanup env handoff"
require_line 'EXPECTED_TEAM_ID="YLWWUD25VZ"' "expected signing team guard"
require_line 'EXPECTED_PROFILE_NAME="fearlesswallet-dev-adhoc"' "expected ad-hoc profile name guard"
require_line 'EXPECTED_BUNDLE_ID="jp.co.soramitsu.fearlesswallet.dev"' "expected signed bundle id guard"
require_line 'EXPECTED_APP_IDENTIFIER="$EXPECTED_TEAM_ID.$EXPECTED_BUNDLE_ID"' "expected application identifier guard"
require_line 'EXPECTED_APP_GROUP="group.jp.co.soramitsu.fearlesswallet.walletconnect"' "expected WalletConnect App Group guard"
require_line 'require_profile_value() {' "decoded profile scalar validation helper"
require_line 'require_profile_array_contains() {' "decoded profile array validation helper"
require_line 'security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST"' "decoded provisioning profile validation"
require_line 'require_profile_value "Name" "$EXPECTED_PROFILE_NAME" "name"' "profile name validation"
require_line 'require_profile_value "TeamIdentifier:0" "$EXPECTED_TEAM_ID" "team identifier"' "profile team validation"
require_line 'require_profile_value "Entitlements:application-identifier" "$EXPECTED_APP_IDENTIFIER" "application identifier"' "profile app identifier validation"
require_line 'require_profile_array_contains "Entitlements:com.apple.security.application-groups" "$EXPECTED_APP_GROUP" "App Group"' "profile App Group validation"
require_line 'PROFILE_EXPIRATION="$(plutil -extract ExpirationDate raw -o - "$PROFILE_PLIST" 2>/dev/null || true)"' "profile expiration extraction"
require_line 'Decoded provisioning profile is expired' "profile expiration rejection"
require_line 'PROFILE_GET_TASK_ALLOW="$(/usr/libexec/PlistBuddy -c '\''Print :Entitlements:get-task-allow'\'' "$PROFILE_PLIST" 2>/dev/null || true)"' "profile get-task-allow extraction"
require_line 'Decoded provisioning profile has get-task-allow' "debug provisioning profile rejection"
require_line 'Decoded provisioning profile is missing ProvisionedDevices for release-testing export' "non-release-testing provisioning profile rejection"
require_line 'security list-keychains -d user > "$ORIGINAL_KEYCHAINS"' "original keychain list capture"
require_line 'CERT_IDENTITY_COUNT="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>/dev/null |' "temporary keychain signing identity validation"
require_line 'Decoded p12 did not install an Apple Distribution identity for team' "wrong p12 identity rejection"
require_line 'while IFS= read -r keychain; do' "Bash 3-compatible keychain list parsing"
require_line 'original_keychains+=("$keychain")' "portable keychain array population"
require_line 'security list-keychains -d user -s "$KEYCHAIN_PATH" "${original_keychains[@]}"' "temporary signing keychain search list append"
require_line 'INSTALLED_PROFILE_PATH="$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"' "installed provisioning profile path capture"
require_line 'echo "FEARLESS_SIGNING_INSTALLED_PROFILE_PATH=$INSTALLED_PROFILE_PATH"' "installed profile cleanup env handoff"
require_line '- name: Cleanup Signing Assets (Manual)' "manual signing cleanup step"
require_line "if: \${{ always() && github.event_name == 'workflow_dispatch' && inputs.require_signed_archive }}" "always-run manual signing cleanup condition"
require_line 'SIGNING_MODE=automatic \' "automatic signed archive mode"
require_line 'ALLOW_PROVISIONING_UPDATES=1 \' "automatic signed archive provisioning updates"
require_line 'EXPORT_METHOD=release-testing \' "automatic signed archive release-testing export"
require_line 'RELEASE_READINESS_MODE=archive \' "automatic signed archive release readiness mode"
require_line 'RUN_DEPENDENCY_CONTRACTS=0 \' "signed archive avoids duplicate dependency contract run"
require_line 'scripts/ci/release-readiness.sh "$PWD"' "signed archive release readiness gate"
require_line 'EXPORT_METHOD=release-testing RELEASE_READINESS_MODE=archive RUN_DEPENDENCY_CONTRACTS=0 SKIP_BOOTSTRAP=1 scripts/ci/release-readiness.sh "$PWD"' "manual signed archive release readiness export"
require_line 'keychain_path="${FEARLESS_SIGNING_KEYCHAIN_PATH:-$RUNNER_TEMP/fearless-release-signing.keychain-db}"' "keychain cleanup fallback"
require_line 'cert_path="${FEARLESS_SIGNING_CERT_PATH:-$RUNNER_TEMP/fearless-distribution.p12}"' "decoded certificate cleanup fallback"
require_line 'profile_path="${FEARLESS_SIGNING_PROFILE_PATH:-$RUNNER_TEMP/fearlesswallet-dev-adhoc.mobileprovision}"' "decoded profile cleanup fallback"
require_line 'profile_plist="${FEARLESS_SIGNING_PROFILE_PLIST:-$RUNNER_TEMP/fearlesswallet-dev-adhoc.plist}"' "decoded profile plist cleanup fallback"
require_line 'original_keychains_path="${FEARLESS_SIGNING_ORIGINAL_KEYCHAINS:-$RUNNER_TEMP/fearless-original-keychains.txt}"' "original keychain list cleanup fallback"
require_line '"${FEARLESS_SIGNING_INSTALLED_PROFILE_PATH:-}"' "installed profile removal"
require_line '"$cert_path"' "decoded certificate removal"
require_line '"$profile_path"' "decoded profile removal"
require_line '"$profile_plist"' "decoded profile plist removal"
require_line 'security list-keychains -d user -s "${original_keychains[@]}"' "original keychain list restoration"
require_line 'rm -f "$original_keychains_path"' "original keychain list cleanup"
require_line 'security delete-keychain "$keychain_path"' "release keychain deletion"

echo "[check-ci-signing-contracts] OK"
