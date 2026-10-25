#!/usr/bin/env bash
set -euo pipefail

PREFIX="[release-signing-bootstrap]"
ROOT_DIR="${IOS_RELEASE_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GATE="${IOS_RELEASE_GATE_BIN:-$ROOT_DIR/scripts/ci/run-release-signing-gate.sh}"
SECURITY_BIN="${IOS_RELEASE_SECURITY_BIN:-/usr/bin/security}"
PLUTIL_BIN="${IOS_RELEASE_PLUTIL_BIN:-/usr/bin/plutil}"
BASE64_BIN="${IOS_RELEASE_BASE64_BIN:-/usr/bin/base64}"
OPENSSL_BIN="${IOS_RELEASE_OPENSSL_BIN:-/usr/bin/openssl}"
PROFILE_INSTALL_DIR="${IOS_RELEASE_PROFILE_INSTALL_DIR:-$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles}"

fail() {
  echo "$PREFIX ERROR: $*" >&2
  exit 1
}

[[ "${GITHUB_ACTIONS:-false}" == "true" ]] || fail \
  "The signing bootstrap is reserved for trusted GitHub Actions pushes."
[[ "${GITHUB_EVENT_NAME:-}" == "push" ]] || fail \
  "The signing bootstrap refuses non-push events before reading signing material."
case "${GITHUB_REF:-}" in
  refs/heads/develop|refs/heads/master) ;;
  *) fail "The signing bootstrap refuses branches outside the release allow-list." ;;
esac
[[ "${IOS_RELEASE_SIGNING_REQUIRED:-}" == "1" ]] || fail \
  "Trusted release CI must set IOS_RELEASE_SIGNING_REQUIRED to literal 1."

certificate_base64="${IOS_RELEASE_CERTIFICATE_P12_BASE64:-}"
certificate_password="${IOS_RELEASE_CERTIFICATE_PASSWORD:-}"
profile_base64="${IOS_RELEASE_PROVISIONING_PROFILE_BASE64:-}"
configured=0
[[ -n "$certificate_base64" ]] && configured=$((configured + 1))
[[ -n "$certificate_password" ]] && configured=$((configured + 1))
[[ -n "$profile_base64" ]] && configured=$((configured + 1))
if ((configured == 0)); then
  fail "Release-signing secrets are missing; certificate, password, and provisioning profile are all required."
fi
if ((configured != 3)); then
  fail "Release-signing secrets are only partially configured; certificate, password, and provisioning profile must be supplied together."
fi

validate_base64_secret() {
  local value="$1"
  local maximum_length="$2"
  local label="$3"
  local length=${#value}
  ((length >= 4 && length <= maximum_length && length % 4 == 0)) || fail \
    "$label is not a bounded canonical base64 value."
  [[ "$value" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] || fail \
    "$label is not a bounded canonical base64 value."
}

validate_base64_secret "$certificate_base64" $((24 * 1024 * 1024)) "The release certificate"
validate_base64_secret "$profile_base64" $((4 * 1024 * 1024)) "The provisioning profile"
[[ ${#certificate_password} -le 1024 && "$certificate_password" != *$'\n'* && "$certificate_password" != *$'\r'* ]] || fail \
  "The release-certificate password is malformed or oversized."

for command_path in "$GATE" "$SECURITY_BIN" "$PLUTIL_BIN" "$BASE64_BIN" "$OPENSSL_BIN"; do
  [[ -x "$command_path" ]] || fail "A required signing-bootstrap command is unavailable."
done

umask 077
temporary_root="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fearless-signing-bootstrap.XXXXXX")"
chmod 700 "$temporary_root"
certificate_file="$temporary_root/release-certificate.p12"
profile_file="$temporary_root/release.mobileprovision"
profile_plist="$temporary_root/profile.plist"
keychain_path="$temporary_root/release-signing.keychain-db"
installed_profile=""
keychain_created=false
search_list_changed=false
original_keychains=()

cleanup() {
  local original_status=$?
  local cleanup_failed=false
  trap - EXIT INT TERM
  set +e
  if [[ "$search_list_changed" == "true" ]]; then
    "$SECURITY_BIN" list-keychains -d user -s "${original_keychains[@]}" >/dev/null 2>&1 || cleanup_failed=true
  fi
  if [[ "$keychain_created" == "true" ]]; then
    "$SECURITY_BIN" delete-keychain "$keychain_path" >/dev/null 2>&1 || cleanup_failed=true
  fi
  if [[ -n "$installed_profile" ]]; then
    rm -f -- "$installed_profile" || cleanup_failed=true
  fi
  rm -rf -- "$temporary_root" || cleanup_failed=true
  if [[ "$cleanup_failed" == "true" && "$original_status" -eq 0 ]]; then
    echo "$PREFIX ERROR: Ephemeral signing-material cleanup failed." >&2
    original_status=1
  fi
  exit "$original_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf '%s' "$certificate_base64" | "$BASE64_BIN" -D >"$certificate_file" || fail \
  "The release certificate could not be decoded."
printf '%s' "$profile_base64" | "$BASE64_BIN" -D >"$profile_file" || fail \
  "The provisioning profile could not be decoded."
unset certificate_base64 profile_base64 IOS_RELEASE_CERTIFICATE_P12_BASE64 IOS_RELEASE_PROVISIONING_PROFILE_BASE64

certificate_bytes="$(wc -c <"$certificate_file" | tr -d '[:space:]')"
profile_bytes="$(wc -c <"$profile_file" | tr -d '[:space:]')"
[[ "$certificate_bytes" =~ ^[0-9]+$ && "$certificate_bytes" -ge 1 && "$certificate_bytes" -le $((16 * 1024 * 1024)) ]] || fail \
  "The decoded release certificate is empty or oversized."
[[ "$profile_bytes" =~ ^[0-9]+$ && "$profile_bytes" -ge 1 && "$profile_bytes" -le $((3 * 1024 * 1024)) ]] || fail \
  "The decoded provisioning profile is empty or oversized."
chmod 600 "$certificate_file" "$profile_file"

keychain_password="$($OPENSSL_BIN rand -hex 32 2>/dev/null)"
[[ "$keychain_password" =~ ^[0-9a-f]{64}$ ]] || fail \
  "A private ephemeral-keychain password could not be generated."

while IFS= read -r keychain_line; do
  keychain_line="${keychain_line#"${keychain_line%%[![:space:]]*}"}"
  keychain_line="${keychain_line#\"}"
  keychain_line="${keychain_line%\"}"
  [[ -n "$keychain_line" ]] && original_keychains+=("$keychain_line")
done < <("$SECURITY_BIN" list-keychains -d user 2>/dev/null)

"$SECURITY_BIN" create-keychain -p "$keychain_password" "$keychain_path" >/dev/null 2>&1 || fail \
  "The ephemeral signing keychain could not be created."
keychain_created=true
"$SECURITY_BIN" set-keychain-settings -lut 21600 "$keychain_path" >/dev/null 2>&1 || fail \
  "The ephemeral signing keychain could not be constrained."
"$SECURITY_BIN" unlock-keychain -p "$keychain_password" "$keychain_path" >/dev/null 2>&1 || fail \
  "The ephemeral signing keychain could not be unlocked."
"$SECURITY_BIN" import "$certificate_file" -k "$keychain_path" -P "$certificate_password" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1 || fail \
  "The distribution certificate could not be imported."
unset certificate_password IOS_RELEASE_CERTIFICATE_PASSWORD
"$SECURITY_BIN" set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$keychain_password" "$keychain_path" >/dev/null 2>&1 || fail \
  "The ephemeral signing keychain could not authorize codesign."
unset keychain_password
"$SECURITY_BIN" list-keychains -d user -s "$keychain_path" "${original_keychains[@]}" >/dev/null 2>&1 || fail \
  "The ephemeral signing keychain could not be added to the user search list."
search_list_changed=true

"$SECURITY_BIN" cms -D -i "$profile_file" >"$profile_plist" 2>/dev/null || fail \
  "The provisioning profile could not be decoded."
chmod 600 "$profile_plist"
profile_uuid="$($PLUTIL_BIN -extract UUID raw -o - "$profile_plist" 2>/dev/null || true)"
profile_name="$($PLUTIL_BIN -extract Name raw -o - "$profile_plist" 2>/dev/null || true)"
[[ "$profile_uuid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] || fail \
  "The provisioning profile UUID is missing or malformed."
[[ -n "$profile_name" && ${#profile_name} -le 256 && "$profile_name" != *$'\n'* && "$profile_name" != *$'\r'* ]] || fail \
  "The provisioning profile name is missing or malformed."

mkdir -p "$PROFILE_INSTALL_DIR"
installed_profile="$PROFILE_INSTALL_DIR/$profile_uuid.mobileprovision"
[[ ! -e "$installed_profile" && ! -L "$installed_profile" ]] || fail \
  "The ephemeral provisioning-profile destination already exists."
/usr/bin/install -m 600 "$profile_file" "$installed_profile" || fail \
  "The ephemeral provisioning profile could not be installed."

IOS_RELEASE_SIGNING_REQUIRED=1 \
IOS_RELEASE_PROFILE_DIRS="$PROFILE_INSTALL_DIR" \
IOS_RELEASE_EXPECTED_PROFILE_UUID="$profile_uuid" \
IOS_RELEASE_PROVISIONING_PROFILE_SPECIFIER="$profile_name" \
IOS_RELEASE_SECURITY_BIN="$SECURITY_BIN" \
IOS_RELEASE_PLUTIL_BIN="$PLUTIL_BIN" \
  "$GATE"

echo "$PREFIX PASSED: trusted-push signing material was used ephemerally and will be removed."
