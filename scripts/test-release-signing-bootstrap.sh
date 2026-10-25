#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$ROOT_DIR/scripts/ci/run-release-signing-ci.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
BIN_DIR="$TMP_DIR/bin"
PROFILE_DIR="$TMP_DIR/profiles"
OUTPUT_DIR="$TMP_DIR/output"
SECURITY_LOG="$TMP_DIR/security.log"
SECRET_SENTINEL="SUPER_SECRET_BOOTSTRAP_SENTINEL"

fail() {
  echo "[release-signing-bootstrap-test][error] $*" >&2
  exit 1
}

mkdir -p "$BIN_DIR" "$PROFILE_DIR" "$OUTPUT_DIR"

cat >"$TMP_DIR/profile.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>UUID</key><string>12345678-1234-1234-1234-123456789ABC</string>
<key>Name</key><string>Fearless App Store</string>
</dict></plist>
PLIST

cat >"$BIN_DIR/security" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >>"$FAKE_SECURITY_LOG"
case "${1:-}" in
  list-keychains)
    if [[ "$*" == *" -s "* ]]; then
      exit 0
    fi
    printf '    "%s"\n' "$FAKE_ORIGINAL_KEYCHAIN"
    ;;
  create-keychain)
    touch "${@: -1}"
    ;;
  set-keychain-settings|unlock-keychain|set-key-partition-list)
    ;;
  import)
    if [[ "${FAKE_IMPORT_FAIL:-0}" == "1" ]]; then exit 71; fi
    ;;
  cms)
    cat "$FAKE_PROFILE_PLIST"
    ;;
  delete-keychain)
    rm -f -- "${@: -1}"
    [[ "${FAKE_DELETE_FAIL:-0}" != "1" ]]
    ;;
  *) exit 64 ;;
esac
SCRIPT

cat >"$BIN_DIR/gate" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$IOS_RELEASE_SIGNING_REQUIRED" == "1" ]]
[[ "$IOS_RELEASE_EXPECTED_PROFILE_UUID" == "12345678-1234-1234-1234-123456789ABC" ]]
[[ "$IOS_RELEASE_PROVISIONING_PROFILE_SPECIFIER" == "Fearless App Store" ]]
[[ -f "$IOS_RELEASE_PROFILE_DIRS/$IOS_RELEASE_EXPECTED_PROFILE_UUID.mobileprovision" ]]
if [[ "${FAKE_GATE_FAIL:-0}" == "1" ]]; then exit 72; fi
echo "[fake-release-signing-gate] PASSED"
SCRIPT
chmod +x "$BIN_DIR/security" "$BIN_DIR/gate"

certificate_base64="$(printf 'certificate-fixture' | base64 | tr -d '\n')"
profile_base64="$(printf 'profile-fixture' | base64 | tr -d '\n')"

run_bootstrap() {
  rm -rf "$PROFILE_DIR" "$OUTPUT_DIR"
  mkdir -p "$PROFILE_DIR" "$OUTPUT_DIR"
  : >"$SECURITY_LOG"
  GITHUB_ACTIONS="${TEST_GITHUB_ACTIONS:-true}" \
  GITHUB_EVENT_NAME="${TEST_GITHUB_EVENT_NAME:-push}" \
  GITHUB_REF="${TEST_GITHUB_REF:-refs/heads/develop}" \
  IOS_RELEASE_SIGNING_REQUIRED="${TEST_SIGNING_REQUIRED:-1}" \
  IOS_RELEASE_CERTIFICATE_P12_BASE64="${TEST_CERTIFICATE_BASE64-$certificate_base64}" \
  IOS_RELEASE_CERTIFICATE_PASSWORD="${TEST_CERTIFICATE_PASSWORD-$SECRET_SENTINEL}" \
  IOS_RELEASE_PROVISIONING_PROFILE_BASE64="${TEST_PROFILE_BASE64-$profile_base64}" \
  IOS_RELEASE_ROOT_DIR="$TMP_DIR" \
  IOS_RELEASE_GATE_BIN="$BIN_DIR/gate" \
  IOS_RELEASE_SECURITY_BIN="$BIN_DIR/security" \
  IOS_RELEASE_PLUTIL_BIN="/usr/bin/plutil" \
  IOS_RELEASE_BASE64_BIN="/usr/bin/base64" \
  IOS_RELEASE_OPENSSL_BIN="/usr/bin/openssl" \
  IOS_RELEASE_PROFILE_INSTALL_DIR="$PROFILE_DIR" \
  FAKE_SECURITY_LOG="$SECURITY_LOG" \
  FAKE_ORIGINAL_KEYCHAIN="$TMP_DIR/original.keychain-db" \
  FAKE_PROFILE_PLIST="$TMP_DIR/profile.plist" \
  FAKE_IMPORT_FAIL="${TEST_IMPORT_FAIL:-0}" \
  FAKE_DELETE_FAIL="${TEST_DELETE_FAIL:-0}" \
  FAKE_GATE_FAIL="${TEST_GATE_FAIL:-0}" \
  RUNNER_TEMP="$TMP_DIR" \
    "$BOOTSTRAP" >"$OUTPUT_DIR/stdout" 2>"$OUTPUT_DIR/stderr"
}

assert_no_secret_leak() {
  if grep -Fq "$SECRET_SENTINEL" "$OUTPUT_DIR/stdout" "$OUTPUT_DIR/stderr"; then
    fail "$1 leaked signing material"
  fi
}

expect_failure() {
  local label="$1"
  if run_bootstrap; then
    fail "$label was accepted"
  fi
  assert_no_secret_leak "$label"
  if find "$PROFILE_DIR" -mindepth 1 -print -quit | grep -q .; then
    fail "$label left an installed provisioning profile"
  fi
}

run_bootstrap || {
  sed -n '1,80p' "$OUTPUT_DIR/stderr" >&2
  fail "valid trusted-push bootstrap was rejected"
}
grep -Fq 'PASSED' "$OUTPUT_DIR/stdout" || fail "valid bootstrap did not report success"
assert_no_secret_leak "valid bootstrap"
grep -Fxq 'delete-keychain' "$SECURITY_LOG" || fail "valid bootstrap did not delete its ephemeral keychain"
if find "$PROFILE_DIR" -mindepth 1 -print -quit | grep -q .; then
  fail "valid bootstrap left an installed provisioning profile"
fi

TEST_GITHUB_EVENT_NAME=pull_request expect_failure "pull-request signing bootstrap"
TEST_GITHUB_REF=refs/heads/feature/untrusted expect_failure "untrusted-branch signing bootstrap"
TEST_SIGNING_REQUIRED=0 expect_failure "optional signing on trusted push"
TEST_CERTIFICATE_BASE64='' TEST_CERTIFICATE_PASSWORD='' TEST_PROFILE_BASE64='' \
  expect_failure "missing signing secrets"
TEST_CERTIFICATE_PASSWORD='' expect_failure "partially configured signing secrets"
TEST_CERTIFICATE_BASE64='not_base64!' expect_failure "malformed certificate base64"
TEST_IMPORT_FAIL=1 expect_failure "certificate import failure"
TEST_GATE_FAIL=1 expect_failure "signed archive gate failure"
TEST_DELETE_FAIL=1 expect_failure "ephemeral keychain cleanup failure"

echo "[release-signing-bootstrap-test] all behavioral fixtures passed"
