#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODELS_ROOT="${FEARLESS_SUBSTRATE_COMPATIBILITY_MODELS_ROOT:-$ROOT_DIR/fearless/Common/Storage/SubstrateCompatibilityModels}"
SOURCE_DIR="$MODELS_ROOT/Source"
COMPILED_DIR="$MODELS_ROOT/Compiled"
ACTIVE_MODEL_ROOT="${FEARLESS_SUBSTRATE_ACTIVE_MODEL_ROOT:-$ROOT_DIR/fearless/Common/Storage/SubstrateDataModel.xcdatamodeld}"
COMPILER="$SCRIPT_DIR/compile-substrate-storage-compatibility-models.sh"
CHECKSUM_SOURCE="$SCRIPT_DIR/core-data-model-checksum.swift"

LEGACY_V8="LegacyPublicSubstrateDataModel_v8"
LEGACY_V9="LegacyPublicSubstrateDataModel_v9"
ACTIVE_V10="SubstrateDataModel_v10"
EXPECTED_V8_XML_SHA256="d5634c446b0881d261f58d5317eff72cc54d06d8f2679a1301056e689740ea29"
EXPECTED_V9_XML_SHA256="aa0fede5a4ee217e0c6be45f7379ca9c3583edde4e0ee379fa0756641728b769"
EXPECTED_V8_GIT_BLOB="98daa733cb798fc2245c1d60ed66c366d7a30d4a"
EXPECTED_V9_GIT_BLOB="26899179e07abd06086a012c3325d1ac62ac5509"
EXPECTED_V8_CHECKSUM="imSZzqXP9cY45NCRhNsckcRIZCdVU6Zdy+00j3YlBYo="
EXPECTED_V9_CHECKSUM="Yl1+IwzSLG/79DUIwG/5NUjkMG2fk5+Ke9z8rpb6gQA="
EXPECTED_V10_CHECKSUM="Qyb9lyHRxl1FB0CHQeMaajp812iiqKqtSLJ0U/U120A="

fail() {
  echo "[substrate-model-audit][error] $*" >&2
  exit 1
}

require_nonempty_file() {
  local path="$1"
  local description="$2"
  [[ -f "$path" ]] || fail "$description is missing: $path"
  [[ -s "$path" ]] || fail "$description is empty: $path"
}

require_xpath_count() {
  local path="$1"
  local xpath="$2"
  local expected="$3"
  local description="$4"
  local actual
  actual="$(xmllint --xpath "count($xpath)" "$path" 2>/dev/null)" ||
    fail "unable to inspect $description"
  [[ "$actual" == "$expected" ]] ||
    fail "$description: expected $expected, found $actual"
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v od >/dev/null 2>&1 || fail "od is required"
command -v perl >/dev/null 2>&1 || fail "perl is required"
command -v shasum >/dev/null 2>&1 || fail "shasum is required"
command -v xmllint >/dev/null 2>&1 || fail "xmllint is required"
command -v xcrun >/dev/null 2>&1 || fail "xcrun is required"

v8_source="$SOURCE_DIR/$LEGACY_V8.xcdatamodel/contents"
v9_source="$SOURCE_DIR/$LEGACY_V9.xcdatamodel/contents"
v10_source="$ACTIVE_MODEL_ROOT/$ACTIVE_V10.xcdatamodel/contents"
v8_compiled="$COMPILED_DIR/$LEGACY_V8.mom"
v9_compiled="$COMPILED_DIR/$LEGACY_V9.mom"

for required in \
  "$v8_source|public v8 source" \
  "$v9_source|public v9 source" \
  "$v10_source|active v10 source" \
  "$v8_compiled|compiled public v8 model" \
  "$v9_compiled|compiled public v9 model" \
  "$COMPILER|compatibility model compiler" \
  "$CHECKSUM_SOURCE|Core Data checksum inspector"; do
  require_nonempty_file "${required%%|*}" "${required#*|}"
done

for source_path in "$v8_source" "$v9_source" "$v10_source"; do
  xmllint --noout "$source_path" 2>/dev/null ||
    fail "source model is not well-formed XML: $source_path"
done

temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-substrate-model-audit.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

verify_immutable_source() {
  local source_path="$1"
  local expected_sha="$2"
  local expected_blob="$3"
  local name="$4"
  local trailing_hex normalized actual_sha actual_blob

  trailing_hex="$(LC_ALL=C tail -c 2 "$source_path" | od -An -tx1 | tr -d '[:space:]')"
  [[ "$trailing_hex" == "3e0a" ]] ||
    fail "$name must differ from its immutable Git blob by exactly one final LF"

  normalized="$temporary_dir/$name.contents"
  perl -0pe 's/\n\z//' "$source_path" >"$normalized"
  actual_sha="$(shasum -a 256 "$normalized" | awk '{print $1}')"
  actual_blob="$(git hash-object --no-filters "$normalized")"

  [[ "$actual_sha" == "$expected_sha" ]] ||
    fail "$name XML provenance changed: expected $expected_sha, got $actual_sha"
  [[ "$actual_blob" == "$expected_blob" ]] ||
    fail "$name Git-blob provenance changed: expected $expected_blob, got $actual_blob"
}

verify_immutable_source "$v8_source" "$EXPECTED_V8_XML_SHA256" "$EXPECTED_V8_GIT_BLOB" "$LEGACY_V8"
verify_immutable_source "$v9_source" "$EXPECTED_V9_XML_SHA256" "$EXPECTED_V9_GIT_BLOB" "$LEGACY_V9"

for legacy_source in "$v8_source" "$v9_source"; do
  require_xpath_count "$legacy_source" "/model/entity[@name='CDTonConnectedApp']" 1 "legacy TON connected-app entity"
  require_xpath_count "$legacy_source" "/model/entity[@name='CDTonDapp']/attribute[@name='chains' and @attributeType='Transformable']" 1 "legacy TON dapp chains"
  require_xpath_count "$legacy_source" "/model/entity[@name='CDChain']/attribute[@name='ecosystem' and @optional='YES']" 1 "legacy chain ecosystem"
  require_xpath_count "$legacy_source" "/model/entity[@name='CDChain']/attribute[@name='tonBridgeUrl' and @attributeType='URI' and @optional='YES']" 1 "legacy TON bridge URL"
  require_xpath_count "$legacy_source" "/model/entity[@name='CDAsset']/attribute[@name='ethereumType']" 0 "legacy ethereumType absence"
done
require_xpath_count "$v8_source" "/model/entity[@name='CDAsset']/attribute[@name='coinbaseUrl']" 0 "public v8 coinbaseUrl absence"
require_xpath_count "$v9_source" "/model/entity[@name='CDAsset']/attribute[@name='coinbaseUrl' and @optional='YES']" 1 "public v9 coinbaseUrl"

require_xpath_count "$v10_source" "/model/entity[@name='CDTonConnectedApp']" 1 "v10 TON connected-app entity"
require_xpath_count "$v10_source" "/model/entity[@name='CDTonDapp']/attribute[@name='chains' and @attributeType='Transformable']" 1 "v10 TON dapp chains"
require_xpath_count "$v10_source" "/model/entity[@name='CDAsset']/attribute[@name='coinbaseUrl' and @optional='YES']" 1 "v10 coinbaseUrl"
require_xpath_count "$v10_source" "/model/entity[@name='CDAsset']/attribute[@name='ethereumType' and @optional='YES']" 1 "v10 ethereumType"
require_xpath_count "$v10_source" "/model/entity[@name='CDChain']/attribute[@name='ecosystem' and @optional='YES']" 1 "v10 ecosystem"
require_xpath_count "$v10_source" "/model/entity[@name='CDChain']/attribute[@name='tonBridgeUrl' and @attributeType='URI' and @optional='YES']" 1 "v10 TON bridge URL"
require_xpath_count "$v10_source" "/model//attribute[@customClassName='[String]']" 0 "v10 unsafe transformable custom classes"
require_xpath_count "$v10_source" "/model/entity[@name='CDTransactionHistoryItem' and @codeGenerationType='class']" 1 "v10 transaction-history runtime class"

current_version="$(xmllint --xpath 'string(/plist/dict/key[.="_XCCurrentVersionName"]/following-sibling::string[1])' "$ACTIVE_MODEL_ROOT/.xccurrentversion" 2>/dev/null)"
[[ "$current_version" == "$ACTIVE_V10.xcdatamodel" ]] ||
  fail "active Substrate model is not v10: $current_version"

FEARLESS_SUBSTRATE_COMPATIBILITY_MODELS_ROOT="$MODELS_ROOT" \
  "$COMPILER" --output-dir "$temporary_dir/generated" >/dev/null

sdk_root="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun momc \
  --sdkroot="$sdk_root" \
  --iphoneos-deployment-target 14.1 \
  --module fearless \
  --no-warnings \
  "$ACTIVE_MODEL_ROOT" \
  "$temporary_dir/SubstrateDataModel.momd" >/dev/null

checksum_binary="$temporary_dir/core-data-model-checksum"
module_cache="$temporary_dir/module-cache"
mkdir -p "$module_cache"
CLANG_MODULE_CACHE_PATH="$module_cache" \
  SWIFT_MODULECACHE_PATH="$module_cache" \
  xcrun swiftc "$CHECKSUM_SOURCE" -o "$checksum_binary"

checksum_for_model() {
  local path="$1"
  local checksum
  checksum="$("$checksum_binary" "$path" 2>/dev/null)" ||
    fail "Core Data model cannot be loaded: $path"
  [[ -n "$checksum" ]] || fail "Core Data model has an empty checksum: $path"
  printf '%s\n' "$checksum"
}

generated_v8_checksum="$(checksum_for_model "$temporary_dir/generated/$LEGACY_V8.mom")"
generated_v9_checksum="$(checksum_for_model "$temporary_dir/generated/$LEGACY_V9.mom")"
committed_v8_checksum="$(checksum_for_model "$v8_compiled")"
committed_v9_checksum="$(checksum_for_model "$v9_compiled")"
active_v10_checksum="$(checksum_for_model "$temporary_dir/SubstrateDataModel.momd/$ACTIVE_V10.mom")"

[[ "$generated_v8_checksum" == "$EXPECTED_V8_CHECKSUM" ]] || fail "public v8 source checksum changed"
[[ "$generated_v9_checksum" == "$EXPECTED_V9_CHECKSUM" ]] || fail "public v9 source checksum changed"
[[ "$committed_v8_checksum" == "$EXPECTED_V8_CHECKSUM" ]] || fail "compiled public v8 model is stale"
[[ "$committed_v9_checksum" == "$EXPECTED_V9_CHECKSUM" ]] || fail "compiled public v9 model is stale"
[[ "$active_v10_checksum" == "$EXPECTED_V10_CHECKSUM" ]] || fail "active v10 checksum changed"

echo "[substrate-model-audit] PASS"
echo "[substrate-model-audit] Public v8 checksum: $committed_v8_checksum"
echo "[substrate-model-audit] Public v9 checksum: $committed_v9_checksum"
echo "[substrate-model-audit] Active v10 checksum: $active_v10_checksum"
