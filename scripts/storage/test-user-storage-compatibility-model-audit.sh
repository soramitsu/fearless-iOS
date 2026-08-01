#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-user-storage-compatibility-models.sh"
SOURCE_MODELS="$ROOT_DIR/fearless/Common/Storage/CompatibilityModels"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-user-storage-audit-tests.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

fail() {
  echo "[user-storage-model-audit-test][error] $*" >&2
  exit 1
}

new_fixture() {
  local name="$1"
  local fixture="$temporary_dir/$name"

  mkdir -p "$fixture"
  cp -R "$SOURCE_MODELS/." "$fixture/"
  printf '%s\n' "$fixture"
}

expect_failure() {
  local label="$1"
  local expected_message="$2"
  local fixture="$3"
  local output
  local status

  set +e
  output="$(FEARLESS_COMPATIBILITY_MODELS_ROOT="$fixture" "$AUDIT_SCRIPT" 2>&1)"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "$label unexpectedly passed"
  [[ "$output" == *"$expected_message"* ]] ||
    fail "$label failed without expected message '$expected_message': $output"
  echo "[user-storage-model-audit-test] PASS (rejected): $label"
}

FEARLESS_COMPATIBILITY_MODELS_ROOT="$SOURCE_MODELS" "$AUDIT_SCRIPT" >/dev/null
echo "[user-storage-model-audit-test] PASS: canonical models"

fixture="$(new_fixture legacy-checksum-mutation)"
perl -0pi -e \
  's/name="canExportEthereumMnemonic"/name="canExportEthereumMnemonicChanged"/' \
  "$fixture/Source/LegacyEcosystemUserDataModel_v12.xcdatamodel/contents"
expect_failure "mutated immutable legacy schema" "legacy source checksum changed" "$fixture"

fixture="$(new_fixture target-ecosystem-removal)"
perl -0pi -e 's/name="ecosystem"/name="ecosystemRemoved"/' \
  "$fixture/Source/CompatibleUserDataModel_v13.xcdatamodel/contents"
expect_failure "target missing ecosystem" "CDChainAccount.ecosystem" "$fixture"

fixture="$(new_fixture target-ton-removal)"
perl -0pi -e 's/name="tonAddress"/name="tonAddressRemoved"/' \
  "$fixture/Source/CompatibleUserDataModel_v13.xcdatamodel/contents"
expect_failure "target missing TON address" "CDMetaAccount.tonAddress" "$fixture"

fixture="$(new_fixture target-ethereum-based-removal)"
perl -0pi -e 's/name="ethereumBased"/name="ethereumBasedRemoved"/' \
  "$fixture/Source/CompatibleUserDataModel_v13.xcdatamodel/contents"
expect_failure "target missing public ethereum flag" "CDChainAccount.ethereumBased" "$fixture"

fixture="$(new_fixture duplicate-required-field)"
perl -0pi -e \
  's|(<attribute name="ecosystem" optional="YES" attributeType="String"/>)|$1\n        $1|' \
  "$fixture/Source/CompatibleUserDataModel_v13.xcdatamodel/contents"
expect_failure "duplicate compatibility field" "CDChainAccount.ecosystem attribute; found 2" "$fixture"

fixture="$(new_fixture malformed-source)"
printf '%s\n' '<model><entity>' > \
  "$fixture/Source/CompatibleUserDataModel_v13.xcdatamodel/contents"
expect_failure "malformed source XML" "source model is not well-formed XML" "$fixture"

fixture="$(new_fixture empty-compiled-model)"
: > "$fixture/Compiled/CompatibleUserDataModel_v13.mom"
expect_failure "empty compiled target" "compiled target model is empty" "$fixture"

fixture="$(new_fixture corrupt-compiled-model)"
printf '%s\n' 'not a Core Data model' > \
  "$fixture/Compiled/CompatibleUserDataModel_v13.mom"
expect_failure "corrupt compiled target" "Core Data model cannot be loaded" "$fixture"

fixture="$(new_fixture stale-compiled-model)"
cp "$fixture/Compiled/LegacyEcosystemUserDataModel_v12.mom" \
  "$fixture/Compiled/CompatibleUserDataModel_v13.mom"
expect_failure "stale compiled target" "compiled target checksum changed" "$fixture"

echo "[user-storage-model-audit-test] PASS: 1 canonical + 9 negative/adversarial cases"
