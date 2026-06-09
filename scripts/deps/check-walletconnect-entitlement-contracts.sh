#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
service_file="$ROOT/fearless/ApplicationLayer/Services/WalletConnect/WalletConnectService.swift"
entitlements_file="$ROOT/fearless/WalletConnect.entitlements"
archive_smoke="$ROOT/scripts/ci/archive-smoke.sh"

fail() {
  echo "[check-walletconnect-entitlement-contracts] ERROR: $*" >&2
  exit 1
}

service_group="$(
  sed -nE 's/.*walletConnectGroupIdentifier = "([^"]+)".*/\1/p' "$service_file" |
    head -n 1
)"

[[ -n "$service_group" ]] || fail "could not read WalletConnect group identifier from $service_file"

assert_plist_array_contains() {
  local plist_path="$1"
  local key_path="$2"
  local expected_value="$3"

  /usr/libexec/PlistBuddy -c "Print :${key_path}" "$plist_path" 2>/dev/null |
    grep -Fq "$expected_value"
}

assert_plist_array_contains "$entitlements_file" "com.apple.security.application-groups" "$service_group" ||
  fail "WalletConnect App Group entitlement must include '$service_group'"

if /usr/libexec/PlistBuddy -c "Print :keychain-access-groups" "$entitlements_file" 2>/dev/null |
  grep -Fq "$service_group"; then
  fail "WalletConnect uses '$service_group' through App Groups; do not add it as a raw keychain-access-groups entitlement"
fi

archive_app_group="$(
  sed -nE 's/^SIGNING_REQUIRED_APP_GROUP="\$\{SIGNING_REQUIRED_APP_GROUP:-([^}]*)\}"$/\1/p' "$archive_smoke"
)"

[[ "$archive_app_group" == "$service_group" ]] ||
  fail "archive-smoke SIGNING_REQUIRED_APP_GROUP ('$archive_app_group') must match '$service_group'"

echo "[check-walletconnect-entitlement-contracts] OK"
