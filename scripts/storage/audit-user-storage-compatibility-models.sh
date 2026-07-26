#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODELS_ROOT="${FEARLESS_COMPATIBILITY_MODELS_ROOT:-$ROOT_DIR/fearless/Common/Storage/CompatibilityModels}"
SOURCE_DIR="$MODELS_ROOT/Source"
COMPILED_DIR="$MODELS_ROOT/Compiled"
COMPILER="$SCRIPT_DIR/compile-user-storage-compatibility-models.sh"
CHECKSUM_SOURCE="$SCRIPT_DIR/core-data-model-checksum.swift"

LEGACY_MODEL="LegacyEcosystemUserDataModel_v12"
TARGET_MODEL="CompatibleUserDataModel_v13"
EXPECTED_LEGACY_CHECKSUM="+oGDYB1AZIk54P/liFbJ3aXArqvhW7YLFAy04AChJ+s="
EXPECTED_TARGET_CHECKSUM="dX3y/Aa+rMRI3ZxRibOGIkyCHwrc0zgNO9OoBnS5G/Y="

fail() {
  echo "[user-storage-model-audit][error] $*" >&2
  exit 1
}

require_nonempty_file() {
  local path="$1"
  local description="$2"

  [[ -f "$path" ]] || fail "$description is missing: $path"
  [[ -s "$path" ]] || fail "$description is empty: $path"
}

validate_xml() {
  local path="$1"

  if ! xmllint --noout "$path" 2>/dev/null; then
    fail "source model is not well-formed XML: $path"
  fi
}

require_attribute() {
  local path="$1"
  local model_description="$2"
  local entity="$3"
  local attribute="$4"
  local type="$5"
  local optional="$6"
  local xpath
  local count

  xpath="count(/model/entity[@name='$entity']/attribute[@name='$attribute' and @attributeType='$type' and @optional='$optional'])"
  count="$(xmllint --xpath "$xpath" "$path" 2>/dev/null)" ||
    fail "unable to inspect $model_description source: $path"

  [[ "$count" == "1" ]] ||
    fail "$model_description must define exactly one optional $type $entity.$attribute attribute; found $count"
}

command -v xmllint >/dev/null 2>&1 || fail "xmllint is required"
command -v xcrun >/dev/null 2>&1 || fail "xcrun is required"
require_nonempty_file "$COMPILER" "compatibility model compiler"
require_nonempty_file "$CHECKSUM_SOURCE" "Core Data checksum inspector"

legacy_source="$SOURCE_DIR/$LEGACY_MODEL.xcdatamodel/contents"
target_source="$SOURCE_DIR/$TARGET_MODEL.xcdatamodel/contents"
legacy_compiled="$COMPILED_DIR/$LEGACY_MODEL.mom"
target_compiled="$COMPILED_DIR/$TARGET_MODEL.mom"

require_nonempty_file "$legacy_source" "legacy source model"
require_nonempty_file "$target_source" "target source model"
require_nonempty_file "$legacy_compiled" "compiled legacy model"
require_nonempty_file "$target_compiled" "compiled target model"
validate_xml "$legacy_source"
validate_xml "$target_source"

for source_spec in \
  "$legacy_source|legacy model" \
  "$target_source|target model"; do
  source_path="${source_spec%%|*}"
  source_description="${source_spec#*|}"
  require_attribute "$source_path" "$source_description" "CDChainAccount" "ecosystem" "String" "YES"
  require_attribute "$source_path" "$source_description" "CDMetaAccount" "tonAddress" "Binary" "YES"
  require_attribute "$source_path" "$source_description" "CDMetaAccount" "tonContractVersion" "String" "YES"
  require_attribute "$source_path" "$source_description" "CDMetaAccount" "tonPublicKey" "Binary" "YES"
done
require_attribute "$target_source" "target model" "CDChainAccount" "ethereumBased" "Boolean" "YES"

temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-user-storage-audit.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

FEARLESS_COMPATIBILITY_MODELS_ROOT="$MODELS_ROOT" \
  "$COMPILER" --output-dir "$temporary_dir/generated" >/dev/null

generated_legacy="$temporary_dir/generated/$LEGACY_MODEL.mom"
generated_target="$temporary_dir/generated/$TARGET_MODEL.mom"
require_nonempty_file "$generated_legacy" "generated legacy model"
require_nonempty_file "$generated_target" "generated target model"

checksum_binary="$temporary_dir/core-data-model-checksum"
module_cache="$temporary_dir/module-cache"
mkdir -p "$module_cache"
if ! CLANG_MODULE_CACHE_PATH="$module_cache" \
  SWIFT_MODULECACHE_PATH="$module_cache" \
  xcrun swiftc "$CHECKSUM_SOURCE" -o "$checksum_binary"; then
  fail "unable to compile the Core Data checksum inspector"
fi

checksum_for_model() {
  local path="$1"
  local checksum

  if ! checksum="$("$checksum_binary" "$path" 2>/dev/null)"; then
    fail "Core Data model cannot be loaded: $path"
  fi
  [[ -n "$checksum" ]] || fail "Core Data model has an empty checksum: $path"
  printf '%s\n' "$checksum"
}

generated_legacy_checksum="$(checksum_for_model "$generated_legacy")"
committed_legacy_checksum="$(checksum_for_model "$legacy_compiled")"
generated_target_checksum="$(checksum_for_model "$generated_target")"
committed_target_checksum="$(checksum_for_model "$target_compiled")"

[[ "$generated_legacy_checksum" == "$EXPECTED_LEGACY_CHECKSUM" ]] ||
  fail "legacy source checksum changed: expected $EXPECTED_LEGACY_CHECKSUM, got $generated_legacy_checksum"
[[ "$committed_legacy_checksum" == "$EXPECTED_LEGACY_CHECKSUM" ]] ||
  fail "compiled legacy checksum changed: expected $EXPECTED_LEGACY_CHECKSUM, got $committed_legacy_checksum"
[[ "$generated_target_checksum" == "$EXPECTED_TARGET_CHECKSUM" ]] ||
  fail "target source checksum changed: expected $EXPECTED_TARGET_CHECKSUM, got $generated_target_checksum"
[[ "$committed_target_checksum" == "$EXPECTED_TARGET_CHECKSUM" ]] ||
  fail "compiled target checksum changed: expected $EXPECTED_TARGET_CHECKSUM, got $committed_target_checksum"

[[ "$generated_legacy_checksum" == "$committed_legacy_checksum" ]] ||
  fail "compiled legacy model is stale: generated $generated_legacy_checksum, committed $committed_legacy_checksum"
[[ "$generated_target_checksum" == "$committed_target_checksum" ]] ||
  fail "compiled target model is stale: generated $generated_target_checksum, committed $committed_target_checksum"

echo "[user-storage-model-audit] PASS"
echo "[user-storage-model-audit] Legacy checksum: $committed_legacy_checksum"
echo "[user-storage-model-audit] Target checksum: $committed_target_checksum"
