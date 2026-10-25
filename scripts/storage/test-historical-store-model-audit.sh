#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-historical-store-models.sh"
SOURCE_MODELS="$ROOT_DIR/fearless/Common/Storage/HistoricalStoreModels"
SOURCE_FIXTURES="$ROOT_DIR/fearlessTests/Resources/HistoricalStoreModels"
ACTIVE_MODELS="$ROOT_DIR/fearless/Common/Storage/SubstrateDataModel.xcdatamodeld"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-historical-audit-tests.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

# Known entries (see fearlessTests/Resources/HistoricalStoreModels/manifest.json).
V5_LANDING="SubstrateHistorical_d484c09eddea88ca"      # 3.2.2-3.5.3, lands on v5, drops CDSingleValue
V1_TRANSFER="SubstrateHistorical_27378408dc2e9402"     # 0.4.0-1.2.2, needs the 1.7 call path
V8_LANDING="SubstrateHistorical_201c41162d1b1604"      # private 4.0.1, lands on v10
V6_BUNDLED="SubstrateHistorical_e97c76d89436a124"      # 3.6.1-3.6.4, matches SubstrateDataModel_v6
V7_BUNDLED="SubstrateHistorical_9c31baa52f819db5"      # 3.7.0-3.7.4, matches SubstrateDataModel_v7

fail() {
  echo "[historical-model-audit-test][error] $*" >&2
  exit 1
}

# The inspection tools and compiled models are identical for every case.
tools_dir="$temporary_dir/tools"
mkdir -p "$tools_dir/module-cache"
for tool in historical-model-digest historical-model-inferred-drops; do
  CLANG_MODULE_CACHE_PATH="$tools_dir/module-cache" SWIFT_MODULECACHE_PATH="$tools_dir/module-cache" \
    xcrun swiftc "$SCRIPT_DIR/$tool.swift" -o "$tools_dir/$tool"
done
export FEARLESS_HISTORICAL_MODEL_TOOLS_DIR="$tools_dir"
export FEARLESS_HISTORICAL_STORE_MODELS_COMPILE_CACHE="$temporary_dir/compile-cache"

new_fixture() {
  local name="$1"
  local fixture="$temporary_dir/$name"
  mkdir -p "$fixture/Models" "$fixture/Fixtures" "$fixture/SubstrateDataModel.xcdatamodeld"
  cp -R "$SOURCE_MODELS/." "$fixture/Models/"
  cp -R "$SOURCE_FIXTURES/." "$fixture/Fixtures/"
  cp -R "$ACTIVE_MODELS/." "$fixture/SubstrateDataModel.xcdatamodeld/"
  printf '%s\n' "$fixture"
}

run_audit() {
  local fixture="$1"
  FEARLESS_HISTORICAL_STORE_MODELS_ROOT="$fixture/Models" \
    FEARLESS_HISTORICAL_STORE_MODEL_FIXTURES_ROOT="$fixture/Fixtures" \
    FEARLESS_SUBSTRATE_ACTIVE_MODEL_ROOT="$fixture/SubstrateDataModel.xcdatamodeld" \
    "$AUDIT_SCRIPT"
}

edit_manifest() {
  local fixture="$1"
  local program="$2"
  python3 - "$fixture/Fixtures/manifest.json" "$program" <<'PY'
import json, sys
path, program = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    manifest = json.load(handle)
models = {entry["resource"]: entry for entry in manifest["models"]}
exec(program, {"manifest": manifest, "models": models})
with open(path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2)
    handle.write("\n")
PY
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
  echo "[historical-model-audit-test] PASS (rejected): $label"
}

canonical="$(new_fixture canonical)"
run_audit "$canonical" >/dev/null
echo "[historical-model-audit-test] PASS: canonical inventory"

# (a) provenance
fixture="$(new_fixture source-mutation)"
perl -0pi -e 's/name="CDSingleValue"/name="CDSingleValueChanged"/' \
  "$fixture/Models/Source/$V5_LANDING.xcdatamodel/contents"
expect_failure "edited historical source" "$V5_LANDING Git-blob provenance changed" "$fixture"

fixture="$(new_fixture source-final-lf)"
perl -0pi -e 's/\n\z//' "$fixture/Models/Source/$V8_LANDING.xcdatamodel/contents"
expect_failure "source without the conventional final LF" "$V8_LANDING must end with the conventional final LF" "$fixture"

fixture="$(new_fixture unlisted-source)"
cp -R "$fixture/Models/Source/$V5_LANDING.xcdatamodel" \
  "$fixture/Models/Source/SubstrateHistorical_0000000000000000.xcdatamodel"
expect_failure "unlisted source model" "unlisted source model: SubstrateHistorical_0000000000000000" "$fixture"

fixture="$(new_fixture malformed-manifest)"
printf '%s\n' '{"format": ' >"$fixture/Fixtures/manifest.json"
expect_failure "malformed manifest" "manifest is not valid JSON" "$fixture"

fixture="$(new_fixture tier-mismatch)"
edit_manifest "$fixture" "models['$V5_LANDING']['tier'] = 'development'"
expect_failure "tier contradicting the releases" "tier must be appStore" "$fixture"

fixture="$(new_fixture two-roles)"
edit_manifest "$fixture" "models['$V8_LANDING']['excluded'] = 'unsupported transformable'"
expect_failure "entry with two roles" "exactly one of matchesBundled, landing and excluded" "$fixture"

# (b) compiled identities and folder contents
fixture="$(new_fixture unlisted-app-model)"
cp "$fixture/Fixtures/Fixtures/$V6_BUNDLED.mom" "$fixture/Models/App/HistoricalStoreModels/$V6_BUNDLED.mom"
expect_failure "fixture-only model copied into the app" "unlisted app model would ship in the app: $V6_BUNDLED" "$fixture"

fixture="$(new_fixture missing-app-model)"
rm "$fixture/Models/App/HistoricalStoreModels/$V8_LANDING.mom"
expect_failure "app model missing" "app model missing: $V8_LANDING" "$fixture"

fixture="$(new_fixture stale-app-model)"
cp "$fixture/Models/App/HistoricalStoreModels/$V5_LANDING.mom" \
  "$fixture/Models/App/HistoricalStoreModels/$V8_LANDING.mom"
expect_failure "stale app model" "app model $V8_LANDING is stale" "$fixture"

fixture="$(new_fixture stale-fixture-model)"
cp "$fixture/Fixtures/Fixtures/$V7_BUNDLED.mom" "$fixture/Fixtures/Fixtures/$V6_BUNDLED.mom"
expect_failure "stale fixture model" "fixture model $V6_BUNDLED is stale" "$fixture"

fixture="$(new_fixture corrupt-app-model)"
printf 'not a model' >"$fixture/Models/App/HistoricalStoreModels/$V8_LANDING.mom"
expect_failure "corrupt app model" "historical-model-digest failed" "$fixture"

fixture="$(new_fixture checksum-mismatch)"
edit_manifest "$fixture" "models['$V5_LANDING']['versionChecksum'] = 'AAAA'"
expect_failure "manifest version checksum" "versionChecksum" "$fixture"

# (c) digest uniqueness against the bundled models
fixture="$(new_fixture bundled-duplicate)"
edit_manifest "$fixture" "
entry = models['$V6_BUNDLED']
entry.update(matchesBundled=None, landing='SubstrateDataModel_v5',
             allowedDrops={'entities': [], 'attributes': []}, requiredConstants={})"
cp "$fixture/Fixtures/Fixtures/$V6_BUNDLED.mom" "$fixture/Models/App/HistoricalStoreModels/$V6_BUNDLED.mom"
expect_failure "app-bundled duplicate of a lineage model" "is not unique across bundled models" "$fixture"

fixture="$(new_fixture wrong-bundled-match)"
edit_manifest "$fixture" "models['$V6_BUNDLED']['matchesBundled'] = 'SubstrateDataModel_v7'"
expect_failure "matchesBundled naming the wrong model" "matchesBundled SubstrateDataModel_v7 but" "$fixture"

# (d) landing hops
fixture="$(new_fixture narrowed-drops)"
edit_manifest "$fixture" "models['$V5_LANDING']['allowedDrops']['entities'] = []"
expect_failure "drop outside the allowlist" "$V5_LANDING inferred drops differ from allowedDrops" "$fixture"

fixture="$(new_fixture missing-required-constants)"
edit_manifest "$fixture" "models['$V1_TRANSFER']['requiredConstants'] = {}"
expect_failure "mandatory attribute without a constant" "$V1_TRANSFER unsatisfied required attributes" "$fixture"

fixture="$(new_fixture compatibility-landing)"
edit_manifest "$fixture" "models['$V8_LANDING']['landing'] = 'LegacyPublicSubstrateDataModel_v8'"
expect_failure "landing on a compatibility model" "is not a substrate lineage model" "$fixture"

fixture="$(new_fixture lossy-lineage-edit)"
perl -0pi -e 's/(<entity name="CDContact"[^>]*>.*?<attribute name=")name(")/${1}displayName${2}/s' \
  "$fixture/SubstrateDataModel.xcdatamodeld/SubstrateDataModel_v5.xcdatamodel/contents"
grep -q 'name="displayName"' "$fixture/SubstrateDataModel.xcdatamodeld/SubstrateDataModel_v5.xcdatamodel/contents" ||
  fail "lossy-lineage-edit fixture did not apply"
expect_failure "lineage edit that would drop contact names" "inferred drops differ from allowedDrops" "$fixture"

echo "[historical-model-audit-test] PASS: 1 canonical + 18 negative/adversarial cases"
