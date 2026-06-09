#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="${1:-$(pwd)}"
install_script="$ROOT/scripts/ci/install-ipa-to-device.sh"
device_script="$ROOT/scripts/ci/check-device-ready.sh"
agents_doc="$ROOT/AGENTS.md"

fail() {
  echo "[check-device-install-contracts] ERROR: $*" >&2
  exit 1
}

require_file() {
  local file="$1"

  [[ -f "$file" ]] || fail "Missing file: $file"
}

require_line() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  require_file "$file"
  grep -Fq -- "$pattern" "$file" ||
    fail "${description} missing from ${file#"$ROOT"/}: $pattern"
}

require_file "$install_script"
[[ -x "$install_script" ]] || fail "Install helper is not executable: ${install_script#"$ROOT"/}"
require_file "$device_script"
[[ -x "$device_script" ]] || fail "Device readiness helper is not executable: ${device_script#"$ROOT"/}"

require_line "$install_script" 'IPA_PATH="${IPA_PATH:-$ROOT/build/fearless-debugging-script-export/fearless.ipa}"' "default verified development IPA path"
require_line "$install_script" 'BUNDLE_ID="${BUNDLE_ID:-jp.co.soramitsu.fearlesswallet.dev}"' "default dev bundle id"
require_line "$install_script" 'scripts/ci/check-device-ready.sh' "shared device readiness helper"
require_line "$install_script" 'unzip -q "$IPA_PATH" -d "$package_dir"' "IPA extraction"
require_line "$install_script" 'find "$package_dir/Payload" -maxdepth 1 -name '\''*.app'\'' -type d' "single Payload app discovery"
require_line "$install_script" '/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist"' "bundle id verification"
require_line "$install_script" 'codesign --verify --strict --verbose=2 "$app_path"' "app signature verification before install"
require_line "$install_script" 'xcrun devicectl device install app' "physical device install"
require_line "$install_script" '--json-output "$install_json"' "install JSON output"
require_line "$install_script" 'xcrun devicectl device process launch' "post-install launch"
require_line "$install_script" '--terminate-existing' "clean relaunch"
require_line "$device_script" 'xcrun devicectl list devices --timeout "$TIMEOUT_SECONDS" --json-output "$devices_json" >/dev/null' "stable devicectl JSON device discovery"
require_line "$device_script" 'fail "No devices found. Connect and trust an iPhone' "clear no-device diagnostic"
require_line "$device_script" 'PRINT_RESOLVED_DEVICE_ID="${PRINT_RESOLVED_DEVICE_ID:-0}"' "resolved device id print mode"
require_line "$device_script" 'first_available_device_id()' "device identifier resolver"

require_line "$agents_doc" 'scripts/ci/install-ipa-to-device.sh' "AGENTS install helper documentation"

echo "[check-device-install-contracts] OK"
