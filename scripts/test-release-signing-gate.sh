#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT_DIR/scripts/ci/run-release-signing-gate.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FIXTURE="$TMP_DIR/fixture"
BIN_DIR="$TMP_DIR/bin"
PROFILE_DIR="$TMP_DIR/profiles"
OUTPUT="$TMP_DIR/output"
SECRET_SENTINEL="SUPER_SECRET_SIGNING_SENTINEL"

fail() {
  echo "[release-signing-gate-test][error] $*" >&2
  exit 1
}

mkdir -p "$FIXTURE/fearless.xcworkspace" "$FIXTURE/SourcePackages/checkouts" "$BIN_DIR" "$PROFILE_DIR"
touch "$PROFILE_DIR/release.mobileprovision"

cat > "$FIXTURE/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>jp.co.soramitsu.fearlesswallet</string>
</dict></plist>
PLIST

cat > "$FIXTURE/entitlements.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>application-identifier</key><string>YLWWUD25VZ.jp.co.soramitsu.fearlesswallet</string>
<key>com.apple.developer.team-identifier</key><string>YLWWUD25VZ</string>
<key>com.apple.developer.associated-domains</key><array>
<string>applinks:fearlesswallet.io</string><string>webcredentials:fearlesswallet.io</string>
</array>
<key>com.apple.developer.icloud-container-identifiers</key><array>
<string>iCloud.jp.co.soramitsu.fearlesswallet</string>
</array>
<key>com.apple.developer.icloud-services</key><array><string>CloudKit</string></array>
<key>com.apple.security.application-groups</key><array>
<string>group.jp.co.soramitsu.fearlesswallet</string>
</array>
<key>get-task-allow</key><false/>
<key>beta-reports-active</key><true/>
</dict></plist>
PLIST

cat > "$FIXTURE/profile.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>UUID</key><string>12345678-1234-1234-1234-123456789ABC</string>
<key>Name</key><string>Fearless App Store</string>
<key>Entitlements</key><dict>
<key>application-identifier</key><string>YLWWUD25VZ.jp.co.soramitsu.fearlesswallet</string>
<key>com.apple.developer.team-identifier</key><string>YLWWUD25VZ</string>
<key>com.apple.developer.associated-domains</key><string>*</string>
<key>com.apple.developer.icloud-container-identifiers</key><array>
<string>iCloud.jp.co.soramitsu.fearlesswallet</string>
</array>
<key>com.apple.developer.icloud-services</key><string>*</string>
<key>com.apple.security.application-groups</key><array>
<string>group.jp.co.soramitsu.fearlesswallet</string>
</array>
<key>get-task-allow</key><false/>
<key>beta-reports-active</key><true/>
</dict></dict></plist>
PLIST

cat > "$BIN_DIR/security" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "find-identity" ]]; then
  if [[ "${FAKE_IDENTITY_AVAILABLE:-1}" == "1" ]]; then
    echo "  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA \"Apple Distribution: $SECRET_SENTINEL (YLWWUD25VZ)\""
    echo "     1 valid identities found"
  else
    echo "     0 valid identities found"
  fi
  exit 0
fi
if [[ "${1:-}" == "cms" ]]; then
  cat "$FAKE_PROFILE_PLIST"
  exit 0
fi
exit 64
SCRIPT

cat > "$BIN_DIR/codesign" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--verify" ]]; then
  [[ "${FAKE_CODESIGN_VERIFY_FAIL:-0}" != "1" ]]
  exit
fi
if [[ "${1:-}" == "-d" ]]; then
  cat "$FAKE_ENTITLEMENTS_PLIST"
  exit 0
fi
exit 64
SCRIPT

cat > "$BIN_DIR/xcodebuild" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
archive_path=""
saw_manual_style=0
saw_distribution_identity=0
saw_profile_specifier=0
while (($#)); do
  if [[ "$1" == "-archivePath" ]]; then
    shift
    archive_path="$1"
  elif [[ "$1" == "CODE_SIGN_STYLE=Manual" ]]; then
    saw_manual_style=1
  elif [[ "$1" == "CODE_SIGN_IDENTITY=Apple Distribution" ]]; then
    saw_distribution_identity=1
  elif [[ "$1" == "PROVISIONING_PROFILE_SPECIFIER=Fearless App Store" ]]; then
    saw_profile_specifier=1
  fi
  shift
done
[[ -n "$archive_path" ]]
[[ "$saw_manual_style" == "1" && "$saw_distribution_identity" == "1" && "$saw_profile_specifier" == "1" ]]
if [[ "${FAKE_XCODEBUILD_FAIL:-0}" == "1" ]]; then
  echo "error: Signing Identity: $SECRET_SENTINEL certificate AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >&2
  echo "** ARCHIVE FAILED **" >&2
  exit 65
fi
app="$archive_path/Products/Applications/fearless.app"
mkdir -p "$app"
cp "$FAKE_INFO_PLIST" "$app/Info.plist"
cp "$FAKE_PROFILE_PLIST" "$app/embedded.mobileprovision"
unless_privacy="${FAKE_MISSING_PRIVACY:-0}"
if [[ "$unless_privacy" != "1" ]]; then
  printf '%s\n' '<?xml version="1.0"?><plist version="1.0"><dict></dict></plist>' > "$app/PrivacyInfo.xcprivacy"
fi
SCRIPT

chmod +x "$BIN_DIR/security" "$BIN_DIR/codesign" "$BIN_DIR/xcodebuild"

run_gate() {
  rm -rf "$OUTPUT"
  mkdir -p "$OUTPUT"
  SECRET_SENTINEL="$SECRET_SENTINEL" \
  FAKE_PROFILE_PLIST="${FAKE_PROFILE_PLIST:-$FIXTURE/profile.plist}" \
  FAKE_ENTITLEMENTS_PLIST="${FAKE_ENTITLEMENTS_PLIST:-$FIXTURE/entitlements.plist}" \
  FAKE_INFO_PLIST="${FAKE_INFO_PLIST:-$FIXTURE/Info.plist}" \
  IOS_RELEASE_ROOT_DIR="$FIXTURE" \
  IOS_RELEASE_WORKSPACE="$FIXTURE/fearless.xcworkspace" \
  IOS_RELEASE_SOURCE_PACKAGES_DIR="$FIXTURE/SourcePackages" \
  IOS_RELEASE_PROFILE_DIRS="${TEST_PROFILE_DIRS:-$PROFILE_DIR}" \
  IOS_RELEASE_SECURITY_BIN="$BIN_DIR/security" \
  IOS_RELEASE_XCODEBUILD_BIN="$BIN_DIR/xcodebuild" \
  IOS_RELEASE_CODESIGN_BIN="$BIN_DIR/codesign" \
  IOS_RELEASE_SIGNING_REQUIRED="${TEST_SIGNING_REQUIRED:-0}" \
  IOS_RELEASE_EXPECTED_PROFILE_UUID="${TEST_PROFILE_UUID:-12345678-1234-1234-1234-123456789ABC}" \
  IOS_RELEASE_PROVISIONING_PROFILE_SPECIFIER="${TEST_PROFILE_SPECIFIER:-Fearless App Store}" \
  FAKE_IDENTITY_AVAILABLE="${FAKE_IDENTITY_AVAILABLE:-1}" \
  FAKE_XCODEBUILD_FAIL="${FAKE_XCODEBUILD_FAIL:-0}" \
  FAKE_CODESIGN_VERIFY_FAIL="${FAKE_CODESIGN_VERIFY_FAIL:-0}" \
  FAKE_MISSING_PRIVACY="${FAKE_MISSING_PRIVACY:-0}" \
  GITHUB_ACTIONS="${TEST_GITHUB_ACTIONS:-false}" \
  GITHUB_EVENT_NAME="${TEST_GITHUB_EVENT_NAME:-}" \
  GITHUB_REF="${TEST_GITHUB_REF:-}" \
    "$GATE" >"$OUTPUT/stdout" 2>"$OUTPUT/stderr"
}

expect_failure() {
  local label="$1"
  if run_gate; then
    fail "$label was accepted"
  fi
  if grep -Fq "$SECRET_SENTINEL" "$OUTPUT/stdout" "$OUTPUT/stderr"; then
    fail "$label leaked signing identity material"
  fi
}

if ! run_gate; then
  sed -n '1,80p' "$OUTPUT/stderr" >&2
  fail "valid signed Release fixture was rejected"
fi
grep -Fq 'PASSED' "$OUTPUT/stdout" || fail "valid signed Release fixture did not report success"
if grep -Fq "$SECRET_SENTINEL" "$OUTPUT/stdout" "$OUTPUT/stderr"; then
  fail "valid signed Release run leaked signing identity material"
fi

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-exact-authorizations.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.associated-domains' \
  -xml '<array><string>applinks:fearlesswallet.io</string><string>webcredentials:fearlesswallet.io</string></array>' \
  "$FIXTURE/profile-exact-authorizations.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.icloud-services' \
  -xml '<array><string>CloudKit</string></array>' \
  "$FIXTURE/profile-exact-authorizations.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-exact-authorizations.plist" run_gate || fail \
  "exact-array profile authorizations were rejected"

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-array-wildcards.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.associated-domains' \
  -xml '<array><string>*</string></array>' \
  "$FIXTURE/profile-array-wildcards.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.icloud-services' \
  -xml '<array><string>*</string></array>' \
  "$FIXTURE/profile-array-wildcards.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-array-wildcards.plist" run_gate || fail \
  "array wildcard profile authorizations were rejected"

TEST_GITHUB_ACTIONS=true TEST_GITHUB_EVENT_NAME=push TEST_SIGNING_REQUIRED=1 \
  TEST_GITHUB_REF=refs/heads/develop run_gate || fail \
  "trusted release-branch push fixture was rejected"

TEST_GITHUB_ACTIONS=true TEST_GITHUB_EVENT_NAME=pull_request \
  TEST_GITHUB_REF=refs/pull/1/merge expect_failure "pull-request signing attempt"

TEST_GITHUB_ACTIONS=true TEST_GITHUB_EVENT_NAME=push \
  TEST_GITHUB_REF=refs/heads/feature/untrusted expect_failure \
  "non-release-branch signing attempt"

TEST_SIGNING_REQUIRED=invalid expect_failure "invalid signing-required policy"

FAKE_IDENTITY_AVAILABLE=0 TEST_PROFILE_DIRS="$TMP_DIR/no-profiles" run_gate || fail \
  "missing optional signing material did not skip cleanly"
grep -Fq 'SKIPPED' "$OUTPUT/stdout" || fail "missing optional signing material was not explicit"

FAKE_IDENTITY_AVAILABLE=0 TEST_PROFILE_DIRS="$TMP_DIR/no-profiles" TEST_SIGNING_REQUIRED=1 \
  expect_failure "missing required signing material"

FAKE_IDENTITY_AVAILABLE=1 TEST_PROFILE_DIRS="$TMP_DIR/no-profiles" \
  expect_failure "identity without matching profile"

FAKE_IDENTITY_AVAILABLE=0 TEST_PROFILE_DIRS="$PROFILE_DIR" \
  expect_failure "profile without signing identity"

FAKE_XCODEBUILD_FAIL=1 expect_failure "archive failure"
FAKE_CODESIGN_VERIFY_FAIL=1 expect_failure "invalid application signature"
FAKE_MISSING_PRIVACY=1 expect_failure "missing privacy manifest"

cp "$FIXTURE/Info.plist" "$FIXTURE/Info-wrong-bundle.plist"
plutil -replace CFBundleIdentifier -string 'com.attacker.wallet' \
  "$FIXTURE/Info-wrong-bundle.plist"
FAKE_INFO_PLIST="$FIXTURE/Info-wrong-bundle.plist" \
  expect_failure "mismatched application bundle identifier"

cp "$FIXTURE/entitlements.plist" "$FIXTURE/entitlements-bad-group.plist"
plutil -replace 'com\.apple\.security\.application-groups.0' -string \
  'group.com.walletconnect.sdk' "$FIXTURE/entitlements-bad-group.plist"
FAKE_ENTITLEMENTS_PLIST="$FIXTURE/entitlements-bad-group.plist" \
  expect_failure "mismatched signed application group"

cp "$FIXTURE/entitlements.plist" "$FIXTURE/entitlements-keychain.plist"
plutil -insert 'keychain-access-groups' -xml \
  '<array><string>group.com.walletconnect.sdk</string></array>' \
  "$FIXTURE/entitlements-keychain.plist"
FAKE_ENTITLEMENTS_PLIST="$FIXTURE/entitlements-keychain.plist" \
  expect_failure "unreviewed signed keychain group"

cp "$FIXTURE/entitlements.plist" "$FIXTURE/entitlements-task-mismatch.plist"
plutil -replace 'get-task-allow' -bool YES \
  "$FIXTURE/entitlements-task-mismatch.plist"
FAKE_ENTITLEMENTS_PLIST="$FIXTURE/entitlements-task-mismatch.plist" \
  expect_failure "signed/profile get-task-allow mismatch"

cp "$FIXTURE/entitlements.plist" "$FIXTURE/entitlements-development.plist"
cp "$FIXTURE/profile.plist" "$FIXTURE/profile-development.plist"
plutil -replace 'get-task-allow' -bool YES "$FIXTURE/entitlements-development.plist"
plutil -replace 'Entitlements.get-task-allow' -bool YES "$FIXTURE/profile-development.plist"
FAKE_ENTITLEMENTS_PLIST="$FIXTURE/entitlements-development.plist" \
  FAKE_PROFILE_PLIST="$FIXTURE/profile-development.plist" \
  expect_failure "development-signed archive"

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-adhoc.plist"
plutil -insert 'ProvisionedDevices' -xml \
  '<array><string>00000000-0000000000000000</string></array>' \
  "$FIXTURE/profile-adhoc.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-adhoc.plist" \
  expect_failure "ad-hoc provisioning profile"

cp "$FIXTURE/entitlements.plist" "$FIXTURE/entitlements-no-beta.plist"
plutil -replace 'beta-reports-active' -bool NO "$FIXTURE/entitlements-no-beta.plist"
FAKE_ENTITLEMENTS_PLIST="$FIXTURE/entitlements-no-beta.plist" \
  expect_failure "signed archive without beta reporting"

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-no-beta.plist"
plutil -replace 'Entitlements.beta-reports-active' -bool NO "$FIXTURE/profile-no-beta.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-no-beta.plist" \
  expect_failure "profile without beta reporting"

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-bad-domain.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.associated-domains' \
  -xml '<array><string>webcredentials:fearlesswallet.io</string></array>' \
  "$FIXTURE/profile-bad-domain.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-bad-domain.plist" \
  expect_failure "profile missing the application-link domain"

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-near-wildcard-domain.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.associated-domains' \
  -string '*evil' "$FIXTURE/profile-near-wildcard-domain.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-near-wildcard-domain.plist" \
  expect_failure "profile with malformed associated-domain wildcard"

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-bad-icloud-service.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.icloud-services' \
  -xml '<array><string>CloudDocuments</string></array>' \
  "$FIXTURE/profile-bad-icloud-service.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-bad-icloud-service.plist" \
  expect_failure "profile missing CloudKit authorization"

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-near-wildcard-service.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.icloud-services' \
  -string '*evil' "$FIXTURE/profile-near-wildcard-service.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-near-wildcard-service.plist" \
  expect_failure "profile with malformed iCloud-service wildcard"

cp "$FIXTURE/entitlements.plist" "$FIXTURE/entitlements-extra-domain.plist"
plutil -insert 'com\.apple\.developer\.associated-domains.2' \
  -string 'applinks:attacker.example' \
  "$FIXTURE/entitlements-extra-domain.plist"
FAKE_ENTITLEMENTS_PLIST="$FIXTURE/entitlements-extra-domain.plist" \
  expect_failure "wildcard profile with an unreviewed signed associated domain"

cp "$FIXTURE/entitlements.plist" "$FIXTURE/entitlements-extra-icloud-service.plist"
plutil -insert 'com\.apple\.developer\.icloud-services.1' \
  -string 'CloudDocuments' \
  "$FIXTURE/entitlements-extra-icloud-service.plist"
FAKE_ENTITLEMENTS_PLIST="$FIXTURE/entitlements-extra-icloud-service.plist" \
  expect_failure "wildcard profile with an unreviewed signed iCloud service"

cp "$FIXTURE/profile.plist" "$FIXTURE/profile-bad-container.plist"
plutil -replace 'Entitlements.com\.apple\.developer\.icloud-container-identifiers' \
  -xml '<array><string>iCloud.jp.co.soramitsu.fearless</string></array>' \
  "$FIXTURE/profile-bad-container.plist"
FAKE_PROFILE_PLIST="$FIXTURE/profile-bad-container.plist" \
  expect_failure "profile with stale CloudKit container"

echo "[release-signing-gate-test] all behavioral fixtures passed"
