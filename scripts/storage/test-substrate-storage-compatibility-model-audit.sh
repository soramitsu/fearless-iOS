#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-substrate-storage-compatibility-models.sh"
SOURCE_MODELS="$ROOT_DIR/fearless/Common/Storage/SubstrateCompatibilityModels"
ACTIVE_MODELS="$ROOT_DIR/fearless/Common/Storage/SubstrateDataModel.xcdatamodeld"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-substrate-audit-tests.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

fail() {
  echo "[substrate-model-audit-test][error] $*" >&2
  exit 1
}

new_fixture() {
  local name="$1"
  local fixture="$temporary_dir/$name"
  mkdir -p \
    "$fixture/Compatibility" \
    "$fixture/SubstrateDataModel.xcdatamodeld"
  cp -R "$SOURCE_MODELS/." "$fixture/Compatibility/"
  cp -R \
    "$ACTIVE_MODELS/." \
    "$fixture/SubstrateDataModel.xcdatamodeld/"
  printf '%s\n' "$fixture"
}

run_audit() {
  local fixture="$1"
  FEARLESS_SUBSTRATE_COMPATIBILITY_MODELS_ROOT="$fixture/Compatibility" \
    FEARLESS_SUBSTRATE_ACTIVE_MODEL_ROOT="$fixture/SubstrateDataModel.xcdatamodeld" \
    "$AUDIT_SCRIPT"
}

expect_failure() {
  local label="$1"
  local expected_message="$2"
  local fixture="$3"
  local output status

  set +e
  output="$(run_audit "$fixture" 2>&1)"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "$label unexpectedly passed"
  [[ "$output" == *"$expected_message"* ]] ||
    fail "$label failed without expected message '$expected_message': $output"
  echo "[substrate-model-audit-test] PASS (rejected): $label"
}

canonical="$(new_fixture canonical)"
run_audit "$canonical" >/dev/null
echo "[substrate-model-audit-test] PASS: canonical models"

fixture="$(new_fixture public-v8-mutation)"
perl -0pi -e 's/name="ecosystem"/name="ecosystemChanged"/' \
  "$fixture/Compatibility/Source/LegacyPublicSubstrateDataModel_v8.xcdatamodel/contents"
expect_failure "mutated public v8" "XML provenance changed" "$fixture"

fixture="$(new_fixture public-v9-mutation)"
perl -0pi -e 's/name="coinbaseUrl"/name="coinbaseUrlChanged"/' \
  "$fixture/Compatibility/Source/LegacyPublicSubstrateDataModel_v9.xcdatamodel/contents"
expect_failure "mutated public v9" "XML provenance changed" "$fixture"

fixture="$(new_fixture v10-union-removal)"
perl -0pi -e 's/name="ethereumType"/name="ethereumTypeRemoved"/' \
  "$fixture/SubstrateDataModel.xcdatamodeld/SubstrateDataModel_v10.xcdatamodel/contents"
expect_failure "v10 missing modern ethereum field" "v10 ethereumType" "$fixture"

fixture="$(new_fixture v10-ton-removal)"
perl -0pi -e 's/name="CDTonConnectedApp"/name="CDTonConnectedAppRemoved"/' \
  "$fixture/SubstrateDataModel.xcdatamodeld/SubstrateDataModel_v10.xcdatamodel/contents"
expect_failure "v10 missing TON entity" "v10 TON connected-app entity" "$fixture"

fixture="$(new_fixture malformed-v10)"
printf '%s\n' '<model><entity>' > \
  "$fixture/SubstrateDataModel.xcdatamodeld/SubstrateDataModel_v10.xcdatamodel/contents"
expect_failure "malformed v10" "not well-formed XML" "$fixture"

fixture="$(new_fixture stale-public-v9)"
cp \
  "$fixture/Compatibility/Compiled/LegacyPublicSubstrateDataModel_v8.mom" \
  "$fixture/Compatibility/Compiled/LegacyPublicSubstrateDataModel_v9.mom"
expect_failure "stale public v9 compiled model" "compiled public v9 model is stale" "$fixture"

fixture="$(new_fixture wrong-current-version)"
perl -0pi -e \
  's/SubstrateDataModel_v10.xcdatamodel/SubstrateDataModel_v8.xcdatamodel/' \
  "$fixture/SubstrateDataModel.xcdatamodeld/.xccurrentversion"
expect_failure "v10 not active" "active Substrate model is not v10" "$fixture"

echo "[substrate-model-audit-test] PASS: 1 canonical + 7 negative/adversarial cases"
