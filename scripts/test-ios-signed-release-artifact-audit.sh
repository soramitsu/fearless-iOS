#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly AUDIT="$SCRIPT_DIR/ci/audit-ios-signed-release-artifact.sh"
readonly HASH_ARCHIVE="$SCRIPT_DIR/ci/hash-ios-archive.sh"
readonly TEMPORARY_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-signed-audit-tests.XXXXXX")"
readonly EXPECTED_GIT_SHA="7a819cb01e92920e5444151392df54245acdd4c8"

trap 'rm -rf "$TEMPORARY_DIR"' EXIT

RUN_NUMBER=0
CASE_DIR=""
ARCHIVE=""
APP=""
SIGNED_ENTITLEMENTS=""
PROFILE=""
SIGNING_CERTIFICATE=""
CASE_ENV=()

fail() {
  printf '%s\n' "[ios-signed-release-audit-test][error] $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  local file="$2"
  grep -Fq -- "$expected" "$file" ||
    fail "expected '$expected' in $(basename "$file")"
}

prepare_case() {
  local label="$1"
  RUN_NUMBER=$((RUN_NUMBER + 1))
  CASE_DIR="$TEMPORARY_DIR/case-${RUN_NUMBER}-${label}"
  ARCHIVE="$CASE_DIR/fearless.xcarchive"
  APP="$ARCHIVE/Products/Applications/fearless.app"
  SIGNED_ENTITLEMENTS="$CASE_DIR/signed-entitlements.plist"
  PROFILE="$CASE_DIR/profile.plist"
  SIGNING_CERTIFICATE="$CASE_DIR/signing-certificate.cer"
  mkdir -p "$APP" "$CASE_DIR/output"

  python3 - "$ARCHIVE/Info.plist" "$APP/Info.plist" \
    "$SIGNED_ENTITLEMENTS" "$PROFILE" "$SIGNING_CERTIFICATE" \
    "$EXPECTED_GIT_SHA" <<'PY'
import datetime
import plistlib
import sys

(
    archive_path,
    app_path,
    entitlements_path,
    profile_path,
    certificate_path,
    git_sha,
) = sys.argv[1:]
team = "YLWWUD25VZ"
bundle = "jp.co.soramitsu.fearlesswallet"
application_id = f"{team}.{bundle}"
certificate = b"canonical Fearless App Store signing certificate"
capabilities = {
    "com.apple.developer.associated-domains": [
        "applinks:fearlesswallet.io",
        "webcredentials:fearlesswallet.io",
    ],
    "com.apple.developer.icloud-container-identifiers": [
        "iCloud.jp.co.soramitsu.fearlesswallet"
    ],
    "com.apple.developer.icloud-services": ["CloudKit"],
    "com.apple.security.application-groups": [
        "group.jp.co.soramitsu.fearlesswallet"
    ],
}
signed = {
    **capabilities,
    "application-identifier": application_id,
    "com.apple.developer.team-identifier": team,
}
profile_entitlements = {
    "com.apple.developer.associated-domains": "*",
    "com.apple.developer.icloud-container-development-container-identifiers": [
        "iCloud.jp.co.soramitsu.fearlesswallet"
    ],
    "com.apple.developer.icloud-container-environment": [
        "Production",
        "Development",
    ],
    "com.apple.developer.icloud-container-identifiers": [
        "iCloud.jp.co.soramitsu.fearlesswallet"
    ],
    "com.apple.developer.icloud-services": "*",
    "com.apple.developer.ubiquity-container-identifiers": [
        "iCloud.jp.co.soramitsu.fearlesswallet"
    ],
    "com.apple.developer.ubiquity-kvstore-identifier": f"{team}.*",
    "com.apple.security.application-groups": [
        "group.jp.co.soramitsu.fearlesswallet"
    ],
    "application-identifier": application_id,
    "com.apple.developer.team-identifier": team,
    "get-task-allow": False,
    "beta-reports-active": True,
    "keychain-access-groups": ["YLWWUD25VZ.*", "com.apple.token"],
}
archive = {
    "ApplicationProperties": {
        "ApplicationPath": "Applications/fearless.app",
        "CFBundleIdentifier": bundle,
        "SigningIdentity": "Apple Distribution: Fearless Test ($team)",
        "Team": team,
    }
}
app = {
    "CFBundleExecutable": "fearless",
    "CFBundleIdentifier": bundle,
    "CFBundleShortVersionString": "4.2.0",
    "CFBundleVersion": "2026.7.28",
    "FearlessBuildConfiguration": "Release",
    "FearlessBitcoinSupportContract": "bip84-mainnet-v1",
    "FearlessEnableTestability": "NO",
    "FearlessGitCommit": git_sha,
    "FearlessSwiftOptimizationLevel": "-O",
    "MinimumOSVersion": "15.0",
}
profile = {
    "CreationDate": datetime.datetime(2026, 1, 1),
    "DeveloperCertificates": [certificate],
    "Entitlements": profile_entitlements,
    "ExpirationDate": datetime.datetime(2035, 1, 1),
    "Name": "Fearless App Store",
    "TeamIdentifier": [team],
    "TeamName": "Fearless",
    "UUID": "11111111-2222-3333-4444-555555555555",
}
for path, payload in (
    (archive_path, archive),
    (app_path, app),
    (entitlements_path, signed),
    (profile_path, profile),
):
    with open(path, "wb") as destination:
        plistlib.dump(payload, destination)
with open(certificate_path, "wb") as destination:
    destination.write(certificate)
PY

  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$APP/fearless"
  chmod +x "$APP/fearless"
  mkdir -p \
    "$APP/Frameworks" \
    "$ARCHIVE/dSYMs/fearless.app.dSYM/Contents/Resources/DWARF"
  printf '%s\n' 'synthetic app symbols' \
    >"$ARCHIVE/dSYMs/fearless.app.dSYM/Contents/Resources/DWARF/fearless"
  local framework_name
  for framework_name in MPQRCoreSDK blake2lib libed25519 sr25519lib; do
    mkdir -p \
      "$APP/Frameworks/$framework_name.framework" \
      "$ARCHIVE/dSYMs/$framework_name.framework.dSYM/Contents/Resources/DWARF"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' \
      >"$APP/Frameworks/$framework_name.framework/$framework_name"
    chmod +x "$APP/Frameworks/$framework_name.framework/$framework_name"
    printf '%s\n' 'synthetic framework symbols' \
      >"$ARCHIVE/dSYMs/$framework_name.framework.dSYM/Contents/Resources/DWARF/$framework_name"
    python3 - "$APP/Frameworks/$framework_name.framework/Info.plist" \
      "$framework_name" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "wb") as destination:
    plistlib.dump({"CFBundleExecutable": sys.argv[2]}, destination)
PY
  done
  printf '%s\n' "opaque production profile" >"$APP/embedded.mobileprovision"
  mkdir -p \
    "$APP/Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd" \
    "$APP/SubstrateDataModel.momd"
  local resource
  local -a resources=(
    "CompatibleUserDataModel_v13.mom"
    "LegacyEcosystemUserDataModel_v12.mom"
    "LegacyPublicSubstrateDataModel_v8.mom"
    "LegacyPublicSubstrateDataModel_v9.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/UserDataModel.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v2.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v3.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v4.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v5.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v6.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v7.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v8.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v9.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v10.mom"
    "Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd/MultiassetUserDataModel_v11.mom"
    "SubstrateDataModel.momd/SubstrateDataModel.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v2.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v3.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v4.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v5.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v6.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v7.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v8.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v10.mom"
    "SubstrateDataModel.momd/SubstrateDataModel_v10.omo"
    "SubstrateDataModel.momd/VersionInfo.plist"
    "SingleToMultiasset.cdm" "MultiassetV2.cdm" "MultiassetV9.cdm"
    "UserDataModelV10toV11.cdm" "SubstrateV2Mapping.cdm"
    "SubstrateV2toV4.cdm" "SubstrateV3toV4.cdm"
  )
  for resource in "${resources[@]}"; do
    : >"$APP/$resource"
  done
  python3 - "$APP/SubstrateDataModel.momd/VersionInfo.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "wb") as destination:
    plistlib.dump(
        {
            "NSManagedObjectModel_CurrentVersionName": "SubstrateDataModel_v10",
            "NSManagedObjectModel_VersionChecksums": {
                "SubstrateDataModel_v10":
                    "Qyb9lyHRxl1FB0CHQeMaajp812iiqKqtSLJ0U/U120A="
            },
        },
        destination,
    )
PY
  CASE_ENV=()
}

run_audit() {
  local label="$1"
  local executable_sha
  local archive_sha
  local signing_certificate_sha1
  executable_sha="$(shasum -a 256 "$APP/fearless" | awk '{print $1}')"
  archive_sha="$(bash "$HASH_ARCHIVE" "$ARCHIVE")"
  signing_certificate_sha1="$(
    shasum -a 1 "$SIGNING_CERTIFICATE" | awk '{print $1}'
  )"

  env \
    FEARLESS_SIGNED_AUDIT_TEST_HARNESS=1 \
    FEARLESS_SIGNED_AUDIT_CODESIGN_BIN="$TEMPORARY_DIR/bin/codesign" \
    FEARLESS_SIGNED_AUDIT_SECURITY_BIN="$TEMPORARY_DIR/bin/security" \
    FEARLESS_SIGNED_AUDIT_DYLD_INFO_BIN="$TEMPORARY_DIR/bin/dyld-info" \
    FEARLESS_SIGNED_AUDIT_DWARFDUMP_BIN="$TEMPORARY_DIR/bin/dwarfdump" \
    FEARLESS_SIGNED_AUDIT_MODEL_CHECKSUM_BIN="$TEMPORARY_DIR/bin/model-checksum" \
    FAKE_SIGNED_ENTITLEMENTS="$SIGNED_ENTITLEMENTS" \
    FAKE_SIGNING_CERTIFICATE="$SIGNING_CERTIFICATE" \
    FAKE_PROFILE_PLIST="$PROFILE" \
    ${CASE_ENV[@]+"${CASE_ENV[@]}"} \
    bash "$AUDIT" \
      --archive "$ARCHIVE" \
      --expected-git-sha "${EXPECTED_GIT_OVERRIDE:-$EXPECTED_GIT_SHA}" \
      --expected-build 2026.7.28 \
      --expected-executable-sha256 "${EXPECTED_EXECUTABLE_SHA_OVERRIDE:-$executable_sha}" \
      --expected-archive-sha256 "${EXPECTED_ARCHIVE_SHA_OVERRIDE:-$archive_sha}" \
      --expected-signing-certificate-sha1 "${EXPECTED_SIGNING_CERTIFICATE_SHA_OVERRIDE:-$signing_certificate_sha1}" \
      --expected-profile-uuid 11111111-2222-3333-4444-555555555555 \
      --expected-profile-name "Fearless App Store" \
      --receipt "$CASE_DIR/output/receipt.json" \
      >"$CASE_DIR/stdout" 2>"$CASE_DIR/stderr"
}

expect_failure() {
  local label="$1"
  local expected="$2"
  if run_audit "$label"; then
    fail "$label unexpectedly passed"
  fi
  assert_contains "$expected" "$CASE_DIR/stderr"
  printf '%s\n' "[ios-signed-release-audit-test] PASS (rejected): $label"
}

mutate_plist() {
  local path="$1"
  local expression="$2"
  python3 - "$path" "$expression" <<'PY'
import datetime
import plistlib
import sys

path, expression = sys.argv[1:]
with open(path, "rb") as source:
    value = plistlib.load(source)
scope = {"value": value, "datetime": datetime}
exec(expression, scope, scope)
with open(path, "wb") as destination:
    plistlib.dump(value, destination)
PY
}

mkdir -p "$TEMPORARY_DIR/bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "${FAKE_CODESIGN_VERIFY_FAIL:-0}" == "1" && "${1:-}" == "--verify" ]]; then exit 1; fi' \
  'if [[ "${1:-}" == "-d" && "${2:-}" == --extract-certificates=* ]]; then' \
  '  prefix="${2#--extract-certificates=}"' \
  '  cp "$FAKE_SIGNING_CERTIFICATE" "${prefix}0"' \
  'elif [[ "${1:-}" == "-d" ]]; then' \
  '  cp "$FAKE_SIGNED_ENTITLEMENTS" /dev/stdout' \
  'fi' \
  >"$TEMPORARY_DIR/bin/codesign"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  '[[ "${FAKE_SECURITY_FAIL:-0}" != "1" ]] || exit 1' \
  'cp "$FAKE_PROFILE_PLIST" /dev/stdout' \
  >"$TEMPORARY_DIR/bin/security"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'classes=(' \
  '  CDAsset CDChain CDChainNode CDChainStorageItem CDChainXcmConfig' \
  '  CDContact CDContactItem CDExternalApi CDPhishingItem CDPolkaswapDex' \
  '  CDPolkaswapRemoteSettings CDPriceData CDPriceProvider CDRuntimeMetadataItem' \
  '  CDScamInfo CDStashItem CDTonConnectedApp CDTonDapp CDTransactionHistoryItem' \
  '  CDXcmAvailableAsset CDXcmAvailableDestination CDAccountInfo CDAssetVisibility' \
  '  CDChainAccount CDChainSettings CDCurrency CDCustomChainNode CDMetaAccount' \
  ')' \
  'for class_name in "${classes[@]}"; do' \
  '  [[ "$class_name" == "${FAKE_MISSING_MANAGED_CLASS:-}" ]] || printf "        @interface %s : NSManagedObject\n" "$class_name"' \
  'done' \
  >"$TEMPORARY_DIR/bin/dyld-info"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'case "$(basename "$1")" in' \
  '  LegacyPublicSubstrateDataModel_v8.mom) printf "%s\n" "imSZzqXP9cY45NCRhNsckcRIZCdVU6Zdy+00j3YlBYo=" ;;' \
  '  LegacyPublicSubstrateDataModel_v9.mom) printf "%s\n" "Yl1+IwzSLG/79DUIwG/5NUjkMG2fk5+Ke9z8rpb6gQA=" ;;' \
  '  SubstrateDataModel_v10.mom) printf "%s\n" "${FAKE_V10_CHECKSUM:-Qyb9lyHRxl1FB0CHQeMaajp812iiqKqtSLJ0U/U120A=}" ;;' \
  '  SubstrateDataModel_v10.omo) printf "%s\n" "${FAKE_V10_OPTIMIZED_CHECKSUM:-Qyb9lyHRxl1FB0CHQeMaajp812iiqKqtSLJ0U/U120A=}" ;;' \
  '  SubstrateDataModel.momd) printf "%s\n" "${FAKE_ACTIVE_SUBSTRATE_CHECKSUM:-Qyb9lyHRxl1FB0CHQeMaajp812iiqKqtSLJ0U/U120A=}" ;;' \
  '  *) exit 2 ;;' \
  'esac' \
  >"$TEMPORARY_DIR/bin/model-checksum"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'artifact="${2:-}"' \
  '[[ "${1:-}" == "--uuid" && -n "$artifact" ]] || exit 2' \
  'logical="$(basename "$artifact")"' \
  'if [[ "$logical" == *.dSYM ]]; then logical="${logical%.dSYM}"; fi' \
  'if [[ "$logical" == *.framework ]]; then logical="${logical%.framework}"; fi' \
  'if [[ "$logical" == "fearless.app" ]]; then logical="fearless"; fi' \
  'uuid="11111111-2222-3333-4444-555555555555"' \
  'if [[ -n "${FAKE_DSYM_MISMATCH:-}" && "$logical" == "$FAKE_DSYM_MISMATCH" && "$artifact" == *.dSYM ]]; then' \
  '  uuid="AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"' \
  'fi' \
  'printf "UUID: %s (arm64) %s\n" "$uuid" "$artifact"' \
  >"$TEMPORARY_DIR/bin/dwarfdump"
chmod +x \
  "$TEMPORARY_DIR/bin/codesign" \
  "$TEMPORARY_DIR/bin/security" \
  "$TEMPORARY_DIR/bin/dyld-info" \
  "$TEMPORARY_DIR/bin/dwarfdump" \
  "$TEMPORARY_DIR/bin/model-checksum"

prepare_case canonical
if ! run_audit canonical; then
  sed -n '1,100p' "$CASE_DIR/stderr" >&2
  fail "canonical signed archive was rejected"
fi
assert_contains '"archiveTreeSHA256"' "$CASE_DIR/output/receipt.json"
assert_contains '"distributionProfile": "valid-app-store"' "$CASE_DIR/output/receipt.json"
assert_contains '"uiDesignCompatibility": "native-redesigned-tab-bar"' "$CASE_DIR/output/receipt.json"
assert_contains '"bitcoinSupportContract": "bip84-mainnet-v1"' "$CASE_DIR/output/receipt.json"
assert_contains '"minimumOSVersion": "15.0"' "$CASE_DIR/output/receipt.json"
assert_contains '"dSYMContract": "exact-uuid-upload-coverage"' "$CASE_DIR/output/receipt.json"
assert_contains '"sourceLineCoverage": "not-asserted"' "$CASE_DIR/output/receipt.json"
assert_contains '"requiredManagedObjectClassCount": 28' "$CASE_DIR/output/receipt.json"
assert_contains '"requiredResourceCount": 34' "$CASE_DIR/output/receipt.json"
assert_contains '"activeSubstrateModelName": "SubstrateDataModel_v10"' "$CASE_DIR/output/receipt.json"
printf '%s\n' "[ios-signed-release-audit-test] PASS: canonical signed archive"

prepare_case wrong-build
mutate_plist "$APP/Info.plist" \
  'value["CFBundleVersion"] = "2026.7.27"'
expect_failure wrong-build "archived build number is not the expected fresh build"

prepare_case missing-bitcoin-support-contract
mutate_plist "$APP/Info.plist" \
  'del value["FearlessBitcoinSupportContract"]'
expect_failure missing-bitcoin-support-contract "lacks the native Bitcoin support contract"

prepare_case wrong-bitcoin-support-contract
mutate_plist "$APP/Info.plist" \
  'value["FearlessBitcoinSupportContract"] = "engine-only"'
expect_failure wrong-bitcoin-support-contract "does not attest the reviewed native Bitcoin support contract"

prepare_case enabled-ui-design-compatibility
mutate_plist "$APP/Info.plist" \
  'value["UIDesignRequiresCompatibility"] = True'
expect_failure enabled-ui-design-compatibility "must omit pre-iOS 26 design compatibility"

prepare_case explicit-disabled-ui-design-compatibility
mutate_plist "$APP/Info.plist" \
  'value["UIDesignRequiresCompatibility"] = False'
expect_failure explicit-disabled-ui-design-compatibility "must omit pre-iOS 26 design compatibility"

prepare_case minimum-os-too-low
mutate_plist "$APP/Info.plist" \
  'value["MinimumOSVersion"] = "14.1"'
expect_failure minimum-os-too-low "MinimumOSVersion is not exactly iOS 15.0"

prepare_case missing-framework-dsym
rm -r "$ARCHIVE/dSYMs/MPQRCoreSDK.framework.dSYM"
expect_failure missing-framework-dsym "MPQRCoreSDK.framework dSYM is missing"

prepare_case mismatched-framework-dsym
CASE_ENV=("FAKE_DSYM_MISMATCH=sr25519lib")
expect_failure mismatched-framework-dsym "sr25519lib.framework dSYM UUID inventory does not exactly match"

prepare_case extra-dsym
mkdir -p "$ARCHIVE/dSYMs/Unexpected.framework.dSYM"
expect_failure extra-dsym "dSYM inventory is not exactly one bundle per embedded code object"

prepare_case wrong-commit
EXPECTED_GIT_OVERRIDE="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
expect_failure wrong-commit "embedded git commit"
unset EXPECTED_GIT_OVERRIDE

prepare_case executable-digest
EXPECTED_EXECUTABLE_SHA_OVERRIDE="$(printf 'a%.0s' {1..64})"
expect_failure executable-digest "executable SHA-256"
unset EXPECTED_EXECUTABLE_SHA_OVERRIDE

prepare_case archive-digest
EXPECTED_ARCHIVE_SHA_OVERRIDE="$(printf 'b%.0s' {1..64})"
expect_failure archive-digest "archive SHA-256"
unset EXPECTED_ARCHIVE_SHA_OVERRIDE

prepare_case wrong-team
mutate_plist "$PROFILE" \
  'value["TeamIdentifier"] = ["AAAAAAAAAA"]'
expect_failure wrong-team "signed entitlements or embedded distribution profile"

prepare_case wrong-archive-team
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["Team"] = "AAAAAAAAAA"'
expect_failure wrong-archive-team "xcarchive metadata"

prepare_case archive-path-includes-products
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["ApplicationPath"] = "Products/Applications/fearless.app"'
expect_failure archive-path-includes-products "xcarchive metadata"

prepare_case archive-path-traversal
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["ApplicationPath"] = "../Applications/fearless.app"'
expect_failure archive-path-traversal "xcarchive metadata"

prepare_case archive-path-absolute
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["ApplicationPath"] = "/Applications/fearless.app"'
expect_failure archive-path-absolute "xcarchive metadata"

prepare_case archive-path-wrong-app
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["ApplicationPath"] = "Applications/attacker.app"'
expect_failure archive-path-wrong-app "xcarchive metadata"

prepare_case archive-path-missing
mutate_plist "$ARCHIVE/Info.plist" \
  'del value["ApplicationProperties"]["ApplicationPath"]'
expect_failure archive-path-missing "xcarchive metadata"

prepare_case development-identity
mutate_plist "$ARCHIVE/Info.plist" \
  'value["ApplicationProperties"]["SigningIdentity"] = "Apple Development: Unsafe"'
expect_failure development-identity "distribution identity"

prepare_case development-profile
mutate_plist "$PROFILE" \
  'value["ProvisionedDevices"] = ["DEVICE-UDID"]'
expect_failure development-profile "signed entitlements or embedded distribution profile"

prepare_case non-testflight-profile
mutate_plist "$PROFILE" \
  'del value["Entitlements"]["beta-reports-active"]'
expect_failure non-testflight-profile "signed entitlements or embedded distribution profile"

prepare_case enterprise-profile
mutate_plist "$PROFILE" \
  'value["ProvisionsAllDevices"] = True'
expect_failure enterprise-profile "signed entitlements or embedded distribution profile"

prepare_case get-task-allow
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["get-task-allow"] = True'
expect_failure get-task-allow "signed entitlements or embedded distribution profile"

prepare_case expired-profile
mutate_plist "$PROFILE" \
  'value["ExpirationDate"] = datetime.datetime(2026, 2, 1)'
expect_failure expired-profile "signed entitlements or embedded distribution profile"

prepare_case profile-expiring-too-soon
mutate_plist "$PROFILE" \
  'value["ExpirationDate"] = datetime.datetime.now() + datetime.timedelta(days=7)'
expect_failure profile-expiring-too-soon "signed entitlements or embedded distribution profile"

prepare_case replaced-walletconnect-group
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["com.apple.security.application-groups"] = ["group.com.walletconnect.sdk"]'
expect_failure replaced-walletconnect-group "signed entitlements or embedded distribution profile"

prepare_case unexpected-signed-keychain-group
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["keychain-access-groups"] = ["group.jp.co.soramitsu.fearlesswallet"]'
expect_failure unexpected-signed-keychain-group "signed entitlements or embedded distribution profile"

prepare_case profile-missing-keychain-group
mutate_plist "$PROFILE" \
  'del value["Entitlements"]["keychain-access-groups"]'
expect_failure profile-missing-keychain-group "signed entitlements or embedded distribution profile"

prepare_case profile-signing-certificate-mismatch
mutate_plist "$PROFILE" \
  'value["DeveloperCertificates"] = [b"unrelated distribution certificate"]'
expect_failure profile-signing-certificate-mismatch "signed entitlements or embedded distribution profile"

prepare_case wrong-profile-uuid
mutate_plist "$PROFILE" \
  'value["UUID"] = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"'
expect_failure wrong-profile-uuid "signed entitlements or embedded distribution profile"

prepare_case wrong-profile-name
mutate_plist "$PROFILE" \
  'value["Name"] = "Unreviewed App Store Profile"'
expect_failure wrong-profile-name "signed entitlements or embedded distribution profile"

prepare_case profile-unauthorized-associated-domains
mutate_plist "$PROFILE" \
  'value["Entitlements"]["com.apple.developer.associated-domains"] = ["applinks:attacker.example"]'
expect_failure profile-unauthorized-associated-domains "signed entitlements or embedded distribution profile"

prepare_case profile-missing-production-cloud-environment
mutate_plist "$PROFILE" \
  'value["Entitlements"]["com.apple.developer.icloud-container-environment"] = ["Development"]'
expect_failure profile-missing-production-cloud-environment "signed entitlements or embedded distribution profile"

prepare_case profile-wrong-ubiquity-container
mutate_plist "$PROFILE" \
  'value["Entitlements"]["com.apple.developer.ubiquity-container-identifiers"] = ["iCloud.jp.co.soramitsu.fearlesswallet.dev"]'
expect_failure profile-wrong-ubiquity-container "signed entitlements or embedded distribution profile"

prepare_case profile-unexpected-entitlement
mutate_plist "$PROFILE" \
  'value["Entitlements"]["com.apple.developer.healthkit"] = True'
expect_failure profile-unexpected-entitlement "signed entitlements or embedded distribution profile"

prepare_case unexpected-signed-entitlement
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["com.apple.developer.healthkit"] = True'
expect_failure unexpected-signed-entitlement "signed entitlements or embedded distribution profile"

prepare_case development-cloud
mutate_plist "$SIGNED_ENTITLEMENTS" \
  'value["com.apple.developer.icloud-container-identifiers"] = ["iCloud.jp.co.soramitsu.fearlesswallet.dev"]'
expect_failure development-cloud "signed entitlements or embedded distribution profile"

prepare_case signature-failure
CASE_ENV=("FAKE_CODESIGN_VERIFY_FAIL=1")
expect_failure signature-failure "strict code-signature"

prepare_case profile-decode-failure
CASE_ENV=("FAKE_SECURITY_FAIL=1")
expect_failure profile-decode-failure "could not be decoded"

prepare_case missing-coredata-resource
rm "$APP/LegacyPublicSubstrateDataModel_v9.mom"
expect_failure missing-coredata-resource "required Core Data resource"

prepare_case missing-managed-object-class
CASE_ENV=("FAKE_MISSING_MANAGED_CLASS=CDTonDapp")
expect_failure missing-managed-object-class "managed-object runtime class"

prepare_case wrong-v10-model-checksum
CASE_ENV=("FAKE_V10_CHECKSUM=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
expect_failure wrong-v10-model-checksum "active Substrate v10 model checksum changed"

prepare_case missing-v10-optimized-model
rm "$APP/SubstrateDataModel.momd/SubstrateDataModel_v10.omo"
expect_failure missing-v10-optimized-model "required Core Data resource"

prepare_case wrong-v10-optimized-model-checksum
CASE_ENV=("FAKE_V10_OPTIMIZED_CHECKSUM=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
expect_failure wrong-v10-optimized-model-checksum "preferred Substrate v10 optimized model checksum changed"

prepare_case wrong-active-substrate-model-checksum
CASE_ENV=("FAKE_ACTIVE_SUBSTRATE_CHECKSUM=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
expect_failure wrong-active-substrate-model-checksum "active Substrate model bundle does not resolve to v10"

prepare_case missing-substrate-version-info
rm "$APP/SubstrateDataModel.momd/VersionInfo.plist"
expect_failure missing-substrate-version-info "required Core Data resource"

prepare_case stale-substrate-current-version
mutate_plist "$APP/SubstrateDataModel.momd/VersionInfo.plist" \
  'value["NSManagedObjectModel_CurrentVersionName"] = "SubstrateDataModel_v8"'
expect_failure stale-substrate-current-version "VersionInfo does not select v10"

prepare_case wrong-substrate-version-info-v10-checksum
mutate_plist "$APP/SubstrateDataModel.momd/VersionInfo.plist" \
  'value["NSManagedObjectModel_VersionChecksums"]["SubstrateDataModel_v10"] = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="'
expect_failure wrong-substrate-version-info-v10-checksum "VersionInfo v10 checksum changed"

prepare_case override-without-harness
if env \
  FEARLESS_SIGNED_AUDIT_CODESIGN_BIN="$TEMPORARY_DIR/bin/codesign" \
  bash "$AUDIT" >"$CASE_DIR/stdout" 2>"$CASE_DIR/stderr"; then
  fail "tool override without harness unexpectedly passed"
fi
assert_contains "only in the explicit test harness" "$CASE_DIR/stderr"
printf '%s\n' "[ios-signed-release-audit-test] PASS (rejected): override without harness"

printf '%s\n' \
  "[ios-signed-release-audit-test] PASS: 1 positive + 48 negative/adversarial contracts"
