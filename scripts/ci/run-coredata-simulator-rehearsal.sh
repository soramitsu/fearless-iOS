#!/usr/bin/env bash
set -euo pipefail

# Rehearses first launch and relaunch of a standalone Release simulator app
# against a disposable, offline copy of the three Fearless Core Data stores.
#
# Safety properties:
# - requires an explicit, booted iPhone Simulator UDID;
# - verifies the .app contains an iOS Simulator binary;
# - rejects unsigned or linker-only Simulator app bundles;
# - requires artifact-embedded Release, Swift -O, and disabled-testability attestations;
# - refuses a simulator where this bundle is already installed;
# - never opens, deletes, renames, chmods, or otherwise writes the source fixture;
# - runs SQLite inspection only against additional private copies;
# - never prints database rows or application log messages;
# - never uninstalls an app or erases a simulator.

umask 077

readonly LOG_PREFIX="[coredata-simulator-rehearsal]"
readonly UUID_PATTERN='^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
readonly BUNDLE_ID_PATTERN='^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$'
readonly DEFAULT_ALIVE_SECONDS=8
readonly EXPECTED_BUNDLE_ID="jp.co.soramitsu.fearlesswallet"
readonly EXPECTED_VERSION="4.2.0"

readonly STORE_FILES=(
  "CacheDataModel.sqlite"
  "CacheDataModel.sqlite-shm"
  "CacheDataModel.sqlite-wal"
  "SubstrateDataModel.sqlite"
  "SubstrateDataModel.sqlite-shm"
  "SubstrateDataModel.sqlite-wal"
  "UserDataModel.sqlite"
  "UserDataModel.sqlite-shm"
  "UserDataModel.sqlite-wal"
)

readonly REQUIRED_MANAGED_OBJECT_CLASSES=(
  "CDAsset"
  "CDChain"
  "CDChainNode"
  "CDChainStorageItem"
  "CDChainXcmConfig"
  "CDContact"
  "CDContactItem"
  "CDExternalApi"
  "CDPhishingItem"
  "CDPolkaswapDex"
  "CDPolkaswapRemoteSettings"
  "CDPriceData"
  "CDPriceProvider"
  "CDRuntimeMetadataItem"
  "CDScamInfo"
  "CDStashItem"
  "CDTransactionHistoryItem"
  "CDXcmAvailableAsset"
  "CDXcmAvailableDestination"
  "CDAccountInfo"
  "CDAssetVisibility"
  "CDChainAccount"
  "CDChainSettings"
  "CDCurrency"
  "CDCustomChainNode"
  "CDMetaAccount"
)

readonly REQUIRED_CORE_DATA_RESOURCES=(
  "CompatibleUserDataModel_v13.mom"
  "LegacyEcosystemUserDataModel_v12.mom"
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
  "SingleToMultiasset.cdm"
  "MultiassetV2.cdm"
  "MultiassetV9.cdm"
  "UserDataModelV10toV11.cdm"
  "SubstrateV2Mapping.cdm"
  "SubstrateV2toV4.cdm"
  "SubstrateV3toV4.cdm"
)

SIMULATOR_UDID=""
APP_PATH=""
BUNDLE_ID=""
FIXTURE_DIR=""
ARTIFACTS_DIR=""
CRASH_REPORT_DIR="${HOME}/Library/Logs/DiagnosticReports"
ALIVE_SECONDS="$DEFAULT_ALIVE_SECONDS"
DISPOSABLE_FIXTURE_CONFIRMED=0
DRY_RUN=0
EXPECTED_GIT_SHA=""
EXPECTED_EXECUTABLE_SHA256=""
EXPECTED_BUILD=""

readonly REHEARSAL_TEST_HARNESS="${FEARLESS_REHEARSAL_TEST_HARNESS:-0}"
if [[ "$REHEARSAL_TEST_HARNESS" != "1" ]]; then
  for override_name in \
    FEARLESS_REHEARSAL_XCRUN_BIN \
    FEARLESS_REHEARSAL_CODESIGN_BIN \
    FEARLESS_REHEARSAL_PYTHON_BIN \
    FEARLESS_REHEARSAL_SHASUM_BIN \
    FEARLESS_REHEARSAL_PS_BIN \
    FEARLESS_REHEARSAL_SLEEP_BIN \
    FEARLESS_REHEARSAL_PROCESS_CHECK_BIN; do
    if [[ -n "${!override_name:-}" ]]; then
      printf '%s ERROR: %s\n' \
        "[coredata-simulator-rehearsal]" \
        "$override_name is accepted only with FEARLESS_REHEARSAL_TEST_HARNESS=1" >&2
      exit 1
    fi
  done
fi

XCRUN_BIN="${FEARLESS_REHEARSAL_XCRUN_BIN:-xcrun}"
CODESIGN_BIN="${FEARLESS_REHEARSAL_CODESIGN_BIN:-codesign}"
PYTHON_BIN="${FEARLESS_REHEARSAL_PYTHON_BIN:-python3}"
SHASUM_BIN="${FEARLESS_REHEARSAL_SHASUM_BIN:-shasum}"
PS_BIN="${FEARLESS_REHEARSAL_PS_BIN:-ps}"
SLEEP_BIN="${FEARLESS_REHEARSAL_SLEEP_BIN:-sleep}"
PROCESS_CHECK_BIN="${FEARLESS_REHEARSAL_PROCESS_CHECK_BIN:-}"

APP_EXECUTABLE_NAME=""
APP_EXECUTABLE_PATH=""
DATA_CONTAINER=""
CORE_DATA_TARGET=""
APP_RUNNING=0

log() {
  printf '%s %s\n' "$LOG_PREFIX" "$*"
}

fail() {
  printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2
  exit 1
}

cleanup() {
  if [[ "$APP_RUNNING" == "1" && -n "$SIMULATOR_UDID" && -n "$BUNDLE_ID" ]]; then
    "$XCRUN_BIN" simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" \
      >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/ci/run-coredata-simulator-rehearsal.sh \
    --simulator-udid UUID \
    --app /absolute/path/to/fearless.app \
    --bundle-id jp.co.soramitsu.fearlesswallet \
    --expected-git-sha 40_HEX_SHA \
    --expected-build CANONICAL_CF_BUNDLE_VERSION \
    --expected-executable-sha256 64_HEX_SHA256 \
    --fixture-dir /absolute/path/to/disposable/offline/CoreData \
    --artifacts-dir /absolute/path/to/new/artifacts \
    --confirm-disposable-fixture

Required safety acknowledgement:
  --confirm-disposable-fixture
      Confirms that --fixture-dir is an offline disposable copy, not a phone
      container, device backup, or sole recovery copy. The directory is still
      treated as immutable and is checksum-verified throughout the run.

Options:
  --alive-seconds N
      Require the launched process to remain alive for N seconds per launch
      (1...30, default 8).
  --crash-report-dir ABSOLUTE_DIRECTORY
      DiagnosticReports directory to inspect for new matching crash reports.
  --dry-run
      Perform fail-closed input, Simulator, binary, checksum, and copied-SQLite
      validation without installing or launching the app.
  --expected-git-sha SHA
      Exact 40-hex source commit embedded in the Simulator artifact.
  --expected-build BUILD
      Exact fresh CFBundleVersion selected after the App Store Connect check.
  --expected-executable-sha256 SHA
      Exact 64-hex executable digest recorded by the build step.
  --help

Controlled test-harness overrides:
  FEARLESS_REHEARSAL_XCRUN_BIN
  FEARLESS_REHEARSAL_CODESIGN_BIN
  FEARLESS_REHEARSAL_PYTHON_BIN
  FEARLESS_REHEARSAL_SHASUM_BIN
  FEARLESS_REHEARSAL_PS_BIN
  FEARLESS_REHEARSAL_SLEEP_BIN
  FEARLESS_REHEARSAL_PROCESS_CHECK_BIN
USAGE
}

require_option_value() {
  local option="$1"
  local remaining="$2"
  [[ "$remaining" -ge 2 ]] || fail "$option requires a value"
}

require_executable() {
  local executable="$1"
  local description="$2"

  if [[ "$executable" == */* ]]; then
    [[ -x "$executable" ]] || fail "$description is not executable"
  else
    command -v "$executable" >/dev/null 2>&1 ||
      fail "$description is unavailable"
  fi
}

validate_release_app_contract() {
  local symbols_file="$ARTIFACTS_DIR/managed-object-symbols.pending"
  local class_name
  local resource
  local build_configuration
  local optimization_level
  local enable_testability
  local embedded_git_sha
  local marketing_version
  local build_number
  local executable_digest

  build_configuration="$(
    plist_string "$APP_PATH/Info.plist" "FearlessBuildConfiguration"
  )" || fail "Release app lacks its build-configuration attestation"
  optimization_level="$(
    plist_string "$APP_PATH/Info.plist" "FearlessSwiftOptimizationLevel"
  )" || fail "Release app lacks its Swift-optimization attestation"
  enable_testability="$(
    plist_string "$APP_PATH/Info.plist" "FearlessEnableTestability"
  )" || fail "Release app lacks its testability attestation"
  embedded_git_sha="$(
    plist_string "$APP_PATH/Info.plist" "FearlessGitCommit"
  )" || fail "Release app lacks its git-commit attestation"
  marketing_version="$(
    plist_string "$APP_PATH/Info.plist" "CFBundleShortVersionString"
  )" || fail "Release app lacks its marketing version"
  build_number="$(
    plist_string "$APP_PATH/Info.plist" "CFBundleVersion"
  )" || fail "Release app lacks its build number"

  [[ "$build_configuration" == "Release" ]] ||
    fail "app was not built with the Release configuration"
  [[ "$optimization_level" == "-O" ]] ||
    fail "app was not built with Swift -O optimization"
  [[ "$enable_testability" == "NO" ]] ||
    fail "app was built with testability enabled"
  [[ "$embedded_git_sha" == "$EXPECTED_GIT_SHA" ]] ||
    fail "app git commit does not match --expected-git-sha"
  [[ "$marketing_version" == "$EXPECTED_VERSION" ]] ||
    fail "app marketing version is not $EXPECTED_VERSION"
  [[ "$build_number" == "$EXPECTED_BUILD" ]] ||
    fail "app build number is not --expected-build"
  executable_digest="$("$SHASUM_BIN" -a 256 "$APP_EXECUTABLE_PATH" | awk '{print $1}')"
  [[ "$executable_digest" =~ ^[0-9A-Fa-f]{64}$ ]] ||
    fail "unable to compute the Simulator executable SHA-256"
  [[ "$executable_digest" == "$EXPECTED_EXECUTABLE_SHA256" ]] ||
    fail "Simulator executable SHA-256 does not match the build record"

  if ! "$XCRUN_BIN" nm -gj "$APP_EXECUTABLE_PATH" >"$symbols_file" 2>/dev/null; then
    : >"$symbols_file"
    fail "unable to inspect managed-object symbols in the app executable"
  fi

  for class_name in "${REQUIRED_MANAGED_OBJECT_CLASSES[@]}"; do
    if ! grep -Fqx -- "_OBJC_CLASS_\$_${class_name}" "$symbols_file"; then
      : >"$symbols_file"
      fail "Release app is missing a required managed-object runtime class"
    fi
  done
  : >"$symbols_file"

  for resource in "${REQUIRED_CORE_DATA_RESOURCES[@]}"; do
    [[ -f "$APP_PATH/$resource" && ! -L "$APP_PATH/$resource" ]] ||
      fail "Release app is missing or symlinking a required Core Data migration resource"
  done

  printf '%s\n' \
    "Release, Swift -O, testability disabled; exact commit/version/build/executable SHA-256; 26 managed-object runtime classes and 29 Core Data resources verified" \
    >"$ARTIFACTS_DIR/coredata-app-contract.txt"
}

validate_app_signature_contract() {
  local verification_file="$ARTIFACTS_DIR/app-signature-verification.pending"
  local diagnostics_file="$ARTIFACTS_DIR/app-signature-diagnostics.pending"

  if ! "$CODESIGN_BIN" --verify --deep --strict "$APP_PATH" \
    >"$verification_file" 2>&1; then
    : >"$verification_file"
    fail "app failed strict code-signature verification"
  fi
  : >"$verification_file"

  if ! "$CODESIGN_BIN" -dv --verbose=4 "$APP_PATH" \
    >"$diagnostics_file" 2>&1; then
    : >"$diagnostics_file"
    fail "unable to inspect app code-signing identity"
  fi

  if ! "$PYTHON_BIN" - "$diagnostics_file" "$BUNDLE_ID" <<'PY'
import re
import sys

path, bundle_id = sys.argv[1:]
try:
    with open(path, "r", encoding="utf-8", errors="replace") as source:
        lines = source.readlines()
except OSError:
    sys.exit(2)

pattern = re.compile(r"^Identifier=(.+)$")
identifiers = [
    match.group(1)
    for line in lines
    if (match := pattern.fullmatch(line.rstrip("\r\n")))
]
if identifiers != [bundle_id]:
    sys.exit(3)
PY
  then
    : >"$diagnostics_file"
    fail "app code-signing identifier does not exactly match the requested bundle"
  fi
  : >"$diagnostics_file"

  printf '%s\n' \
    "strict bundle signature and exact bundle-bound code-signing identifier verified" \
    >"$ARTIFACTS_DIR/app-signature-contract.txt"
}

canonical_directory() {
  local directory="$1"
  (cd "$directory" && pwd -P)
}

path_is_within() {
  local child="$1"
  local parent="$2"

  [[ "$child" == "$parent" || "$child" == "$parent/"* ]]
}

plist_string() {
  local plist="$1"
  local key="$2"

  "$PYTHON_BIN" - "$plist" "$key" <<'PY'
import plistlib
import sys

path, key = sys.argv[1:]
try:
    with open(path, "rb") as source:
        value = plistlib.load(source).get(key)
except (OSError, plistlib.InvalidFileException):
    sys.exit(2)

if not isinstance(value, str) or not value:
    sys.exit(3)
print(value)
PY
}

validate_fixture_directory() {
  local directory="$1"

  "$PYTHON_BIN" - "$directory" <<'PY'
import os
import stat
import sys

directory = sys.argv[1]
expected = {
    "CacheDataModel.sqlite",
    "CacheDataModel.sqlite-shm",
    "CacheDataModel.sqlite-wal",
    "SubstrateDataModel.sqlite",
    "SubstrateDataModel.sqlite-shm",
    "SubstrateDataModel.sqlite-wal",
    "UserDataModel.sqlite",
    "UserDataModel.sqlite-shm",
    "UserDataModel.sqlite-wal",
}

try:
    directory_stat = os.lstat(directory)
    names = set(os.listdir(directory))
except OSError:
    print("fixture directory cannot be inspected", file=sys.stderr)
    sys.exit(2)

if not stat.S_ISDIR(directory_stat.st_mode) or stat.S_ISLNK(directory_stat.st_mode):
    print("fixture directory must be a real directory, not a symlink", file=sys.stderr)
    sys.exit(3)
if names != expected:
    print("fixture directory must contain exactly the nine expected store-family files", file=sys.stderr)
    sys.exit(4)

for name in sorted(expected):
    path = os.path.join(directory, name)
    try:
        item_stat = os.lstat(path)
    except OSError:
        print("fixture component cannot be inspected", file=sys.stderr)
        sys.exit(5)
    if not stat.S_ISREG(item_stat.st_mode) or stat.S_ISLNK(item_stat.st_mode):
        print("fixture components must be regular non-symlink files", file=sys.stderr)
        sys.exit(6)
    if name.endswith(".sqlite") and item_stat.st_size <= 0:
        print("primary SQLite stores must be nonempty", file=sys.stderr)
        sys.exit(7)
PY
}

write_family_manifest() {
  local directory="$1"
  local output="$2"
  local require_every_file="$3"
  local filename
  local digest_output
  local digest

  : >"$output"
  for filename in "${STORE_FILES[@]}"; do
    if [[ ! -e "$directory/$filename" ]]; then
      if [[ "$require_every_file" == "1" ]]; then
        fail "a required store-family component is missing"
      fi
      printf '%s  %s\n' "absent" "$filename" >>"$output"
      continue
    fi

    [[ -f "$directory/$filename" && ! -L "$directory/$filename" ]] ||
      fail "store-family components must be regular non-symlink files"
    digest_output="$("$SHASUM_BIN" -a 256 "$directory/$filename")" ||
      fail "unable to checksum a store-family component"
    digest="${digest_output%%[[:space:]]*}"
    [[ "$digest" =~ ^[0-9A-Fa-f]{64}$ ]] ||
      fail "a store-family checksum was malformed"
    printf '%s  %s\n' "$digest" "$filename" >>"$output"
  done
}

require_no_unexpected_files() {
  local directory="$1"

  "$PYTHON_BIN" - "$directory" <<'PY'
import os
import sys

expected = {
    "CacheDataModel.sqlite",
    "CacheDataModel.sqlite-shm",
    "CacheDataModel.sqlite-wal",
    "SubstrateDataModel.sqlite",
    "SubstrateDataModel.sqlite-shm",
    "SubstrateDataModel.sqlite-wal",
    "UserDataModel.sqlite",
    "UserDataModel.sqlite-shm",
    "UserDataModel.sqlite-wal",
}
try:
    names = set(os.listdir(sys.argv[1]))
except OSError:
    sys.exit(2)

if not names.issubset(expected):
    print("Core Data directory contains an unexpected file", file=sys.stderr)
    sys.exit(3)
for name in names:
    path = os.path.join(sys.argv[1], name)
    if os.path.islink(path) or not os.path.isfile(path):
        print("Core Data components must be regular non-symlink files", file=sys.stderr)
        sys.exit(4)
PY
}

copy_family() {
  local source="$1"
  local destination="$2"
  local require_every_file="$3"
  local filename

  [[ -d "$destination" && ! -L "$destination" ]] ||
    fail "copy destination is not a real directory"
  if [[ -n "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    fail "copy destination must be empty"
  fi

  for filename in "${STORE_FILES[@]}"; do
    if [[ -e "$source/$filename" ]]; then
      [[ -f "$source/$filename" && ! -L "$source/$filename" ]] ||
        fail "copy source contains a non-regular component"
      cp -p "$source/$filename" "$destination/$filename"
    elif [[ "$require_every_file" == "1" ]]; then
      fail "copy source is missing a required store-family component"
    fi
  done
}

inspect_sqlite_copies() {
  local directory="$1"
  local output="$2"

  "$PYTHON_BIN" - "$directory" "$output" <<'PY'
import json
import hashlib
import os
import sqlite3
import sys

directory, output = sys.argv[1:]
stores = (
    "CacheDataModel.sqlite",
    "SubstrateDataModel.sqlite",
    "UserDataModel.sqlite",
)
result = {}

def quote_identifier(value):
    return '"' + value.replace('"', '""') + '"'

def encode_value(value):
    if value is None:
        return b"n;"
    if isinstance(value, bytes):
        return b"b" + str(len(value)).encode("ascii") + b":" + value + b";"
    if isinstance(value, str):
        encoded = value.encode("utf-8")
        return b"s" + str(len(encoded)).encode("ascii") + b":" + encoded + b";"
    if isinstance(value, int):
        return b"i" + str(value).encode("ascii") + b";"
    if isinstance(value, float):
        return b"f" + value.hex().encode("ascii") + b";"
    raise RuntimeError("unsupported protected SQLite value type")

def rows_digest(rows):
    encoded_rows = []
    for row in rows:
        encoded_rows.append(b"".join(encode_value(value) for value in row))
    encoded_rows.sort()

    digest = hashlib.sha256()
    for row in encoded_rows:
        digest.update(str(len(row)).encode("ascii"))
        digest.update(b":")
        digest.update(row)
        digest.update(b";")
    return digest.hexdigest()

def table_columns(connection, table_name):
    return {
        row[1]
        for row in connection.execute(
            f"PRAGMA table_info({quote_identifier(table_name)})"
        ).fetchall()
    }

def protected_user_fingerprints(connection, table_names):
    meta_table = "ZCDMETAACCOUNT"
    chain_table = "ZCDCHAINACCOUNT"
    if meta_table not in table_names or chain_table not in table_names:
        raise RuntimeError("User store lacks protected wallet tables")

    meta_columns = table_columns(connection, meta_table)
    core_meta_columns = (
        "ZMETAID",
        "ZSUBSTRATEACCOUNTID",
        "ZSUBSTRATEPUBLICKEY",
        "ZSUBSTRATECRYPTOTYPE",
        "ZETHEREUMADDRESS",
        "ZETHEREUMPUBLICKEY",
    )
    missing_meta = set(core_meta_columns) - meta_columns
    if missing_meta:
        raise RuntimeError("User store lacks protected wallet identity columns")

    quoted_core_meta = ", ".join(quote_identifier(value) for value in core_meta_columns)
    fingerprints = {
        "wallet-core-identities-and-keys": rows_digest(
            connection.execute(
                f"SELECT {quoted_core_meta} FROM {quote_identifier(meta_table)}"
            ).fetchall()
        )
    }

    optional_wallet_groups = {
        "wallet-ton-identities-and-keys": (
            "ZTONADDRESS",
            "ZTONPUBLICKEY",
        ),
    }
    for label, columns in optional_wallet_groups.items():
        if set(columns).issubset(meta_columns):
            selected = ("ZMETAID",) + columns
            quoted = ", ".join(quote_identifier(value) for value in selected)
            fingerprints[label] = rows_digest(
                connection.execute(
                    f"SELECT {quoted} FROM {quote_identifier(meta_table)}"
                ).fetchall()
            )

    chain_columns = table_columns(connection, chain_table)
    core_chain_columns = (
        "ZACCOUNTID",
        "ZCHAINID",
        "ZPUBLICKEY",
        "ZCRYPTOTYPE",
        "ZMETAACCOUNT",
    )
    missing_chain = set(core_chain_columns) - chain_columns
    if missing_chain:
        raise RuntimeError("User store lacks protected child-account columns")

    fingerprints["child-identities-keys-and-wallet-links"] = rows_digest(
        connection.execute(
            f"""
            SELECT
                child.ZACCOUNTID,
                child.ZCHAINID,
                child.ZPUBLICKEY,
                child.ZCRYPTOTYPE,
                parent.ZMETAID
            FROM {quote_identifier(chain_table)} AS child
            LEFT JOIN {quote_identifier(meta_table)} AS parent
              ON child.ZMETAACCOUNT = parent.Z_PK
            """
        ).fetchall()
    )
    return fingerprints

def protected_substrate_topology(connection, table_names):
    chain_table = "ZCDCHAIN"
    node_table = "ZCDCHAINNODE"
    primary_key_table = "Z_PRIMARYKEY"
    required_tables = {chain_table, node_table, primary_key_table}
    if not required_tables.issubset(table_names):
        raise RuntimeError("Substrate store lacks chain/node topology tables")

    chain_columns = table_columns(connection, chain_table)
    node_columns = table_columns(connection, node_table)
    required_chain_columns = {"Z_PK", "ZCHAINID", "ZSELECTEDNODE"}
    required_node_columns = {"Z_PK", "ZCHAIN", "ZNAME", "ZURL"}
    if not required_chain_columns.issubset(chain_columns):
        raise RuntimeError("Substrate store lacks protected chain topology columns")
    if not required_node_columns.issubset(node_columns):
        raise RuntimeError("Substrate store lacks protected node topology columns")

    entity_numbers = {
        str(name).upper(): number
        for number, name in connection.execute(
            f"SELECT Z_ENT, Z_NAME FROM {quote_identifier(primary_key_table)}"
        ).fetchall()
    }
    chain_entity = entity_numbers.get("CDCHAIN")
    node_entity = entity_numbers.get("CDCHAINNODE")
    if not isinstance(chain_entity, int) or not isinstance(node_entity, int):
        raise RuntimeError("Substrate store lacks Core Data entity-number metadata")

    inline_custom_column = f"Z{chain_entity}CUSTOMNODES"
    if inline_custom_column not in node_columns:
        raise RuntimeError("Substrate store lacks the canonical customNodes relationship column")
    custom_tables = []
    for table_name in sorted(table_names):
        if table_name in {chain_table, node_table, primary_key_table}:
            continue
        columns = table_columns(connection, table_name)
        if "CUSTOMNODES" in table_name or any(
            "CUSTOMNODES" in column for column in columns
        ):
            custom_tables.append((table_name, columns))
    if custom_tables:
        raise RuntimeError("Substrate store has an unexpected customNodes join table")

    chains = {}
    for primary_key, chain_id, selected_node in connection.execute(
        f"""
        SELECT Z_PK, ZCHAINID, ZSELECTEDNODE
        FROM {quote_identifier(chain_table)}
        """
    ).fetchall():
        if (
            not isinstance(primary_key, int)
            or not isinstance(chain_id, str)
            or not chain_id.strip()
        ):
            raise RuntimeError("Substrate chain topology contains an invalid identity")
        chains[primary_key] = (chain_id, selected_node)
    if not chains:
        raise RuntimeError("Substrate chain topology is vacuous")

    optional_node_columns = tuple(
        column
        for column in ("ZAPIKEYNAME", "ZAPIQUERYNAME")
        if column in node_columns
    )
    selected_node_columns = (
        "Z_PK",
        "ZCHAIN",
        inline_custom_column,
        "ZNAME",
        "ZURL",
    ) + optional_node_columns
    node_query_columns = ", ".join(
        quote_identifier(column) for column in selected_node_columns
    )
    nodes = {}
    for row in connection.execute(
        f"SELECT {node_query_columns} FROM {quote_identifier(node_table)}"
    ).fetchall():
        primary_key, default_chain, custom_chain, name, url, *credentials = row
        if not isinstance(primary_key, int):
            raise RuntimeError("Substrate node topology contains an invalid primary key")
        nodes[primary_key] = (
            default_chain,
            custom_chain,
            name,
            url,
            *credentials,
        )
    if not nodes:
        raise RuntimeError("Substrate node topology is vacuous")

    custom_edges = set()
    for node_key, node in nodes.items():
        custom_chain = node[1]
        if custom_chain is not None:
            if custom_chain not in chains:
                raise RuntimeError("Substrate customNodes relationship is dangling")
            custom_edges.add((custom_chain, node_key))
    if not custom_edges:
        raise RuntimeError("Substrate fixture has no custom-node relationships")

    selected_edges = set()
    for chain_key, (_, selected_node) in chains.items():
        if selected_node is not None:
            if selected_node not in nodes:
                raise RuntimeError("Substrate selected-node relationship is dangling")
            selected_edges.add((chain_key, selected_node))

    default_edges = set()
    for node_key, node in nodes.items():
        default_chain = node[0]
        if default_chain is not None:
            if default_chain not in chains:
                raise RuntimeError("Substrate default-node relationship is dangling")
            default_edges.add((default_chain, node_key))

    has_custom_selected = bool(custom_edges & selected_edges)
    has_custom_only = any(
        any(source == chain_key for source, _ in custom_edges)
        and not any(source == chain_key for source, _ in default_edges)
        for chain_key in chains
    )
    if not has_custom_selected:
        raise RuntimeError("Substrate fixture lacks a selected custom-node topology")
    if not has_custom_only:
        raise RuntimeError("Substrate fixture lacks a custom-only chain topology")

    topology_rows = []
    for chain_key, (chain_id, selected_node) in chains.items():
        topology_rows.append(("chain", chain_id, selected_node))
        for relationship, edges in (
            ("default", default_edges),
            ("custom", custom_edges),
            ("selected", selected_edges),
        ):
            for source, node_key in sorted(edges):
                if source == chain_key:
                    topology_rows.append(
                        (relationship, chain_id, node_key, *nodes[node_key][2:])
                    )

    referenced_nodes = {
        node_key
        for _, node_key in default_edges | custom_edges | selected_edges
    }
    orphan_rows = [
        ("orphan", node_key, *node[2:])
        for node_key, node in nodes.items()
        if node_key not in referenced_nodes
    ]
    return {
        "fingerprints": {
            "chain-default-custom-selected-topology": rows_digest(topology_rows),
            "orphan-node-topology": rows_digest(orphan_rows),
        },
        "coverage": {
            "customOnlyChain": has_custom_only,
            "selectedCustomNode": has_custom_selected,
        },
    }

try:
    for store_name in stores:
        store_path = os.path.join(directory, store_name)
        if not os.path.isfile(store_path) or os.path.islink(store_path):
            raise RuntimeError(f"{store_name}: copied primary store is missing")

        connection = sqlite3.connect(store_path, timeout=5.0)
        try:
            connection.execute("PRAGMA query_only = ON")
            integrity_rows = [
                row[0] for row in connection.execute("PRAGMA integrity_check").fetchall()
            ]
            if integrity_rows != ["ok"]:
                raise RuntimeError(f"{store_name}: integrity check failed")

            table_names = [
                row[0]
                for row in connection.execute(
                    """
                    SELECT name
                    FROM sqlite_master
                    WHERE type = 'table' AND name GLOB 'Z*'
                    ORDER BY name
                    """
                ).fetchall()
            ]
            table_counts = {}
            for table_name in table_names:
                quoted_name = quote_identifier(table_name)
                count = connection.execute(
                    f"SELECT COUNT(*) FROM {quoted_name}"
                ).fetchone()[0]
                if not isinstance(count, int) or count < 0:
                    raise RuntimeError(f"{store_name}: invalid table count")
                table_counts[table_name] = count

            store_result = {
                "integrity": "ok",
                "applicationRowCount": sum(table_counts.values()),
                "tables": table_counts,
            }
            if store_name == "UserDataModel.sqlite":
                store_result["protectedFingerprints"] = (
                    protected_user_fingerprints(connection, set(table_names))
                )
            if store_name == "SubstrateDataModel.sqlite":
                topology = protected_substrate_topology(
                    connection, set(table_names)
                )
                store_result["protectedTopologyFingerprints"] = (
                    topology["fingerprints"]
                )
                store_result["topologyCoverage"] = topology["coverage"]
            result[store_name] = store_result
        finally:
            connection.close()
except (OSError, sqlite3.Error, RuntimeError) as error:
    print(f"copied SQLite inspection failed: {error}", file=sys.stderr)
    sys.exit(2)

temporary_output = output + ".pending"
with open(temporary_output, "w", encoding="utf-8") as destination:
    json.dump(result, destination, indent=2, sort_keys=True)
    destination.write("\n")
os.replace(temporary_output, output)
PY
}

log_count_summary() {
  local counts_file="$1"
  local phase="$2"

  "$PYTHON_BIN" - "$counts_file" "$phase" <<'PY'
import json
import sys

path, phase = sys.argv[1:]
with open(path, "r", encoding="utf-8") as source:
    payload = json.load(source)
for store_name in sorted(payload):
    count = payload[store_name]["applicationRowCount"]
    print(f"[coredata-simulator-rehearsal] {phase} {store_name}: {count} aggregate rows")
PY
}

validate_preservation() {
  local before="$1"
  local after_first="$2"
  local after_second="$3"

  "$PYTHON_BIN" - "$before" "$after_first" "$after_second" <<'PY'
import json
import sys

payloads = []
for path in sys.argv[1:]:
    with open(path, "r", encoding="utf-8") as source:
        payloads.append(json.load(source))

before, first, second = payloads
for phase_name, payload in (("prelaunch", before), ("first launch", first), ("relaunch", second)):
    for store_name in ("CacheDataModel.sqlite", "SubstrateDataModel.sqlite", "UserDataModel.sqlite"):
        store = payload.get(store_name)
        if not isinstance(store, dict) or store.get("integrity") != "ok":
            print(f"{phase_name} lacks an intact {store_name}", file=sys.stderr)
            sys.exit(2)

user_critical_tables = ("ZCDMETAACCOUNT", "ZCDCHAINACCOUNT")
before_user = before["UserDataModel.sqlite"]["tables"]
for table_name in user_critical_tables:
    if table_name not in before_user:
        print(f"prelaunch User store lacks required {table_name} count", file=sys.stderr)
        sys.exit(3)
    expected_count = before_user[table_name]
    for phase_name, payload in (("first launch", first), ("relaunch", second)):
        actual_count = payload["UserDataModel.sqlite"]["tables"].get(table_name)
        if actual_count != expected_count:
            print(f"{phase_name} changed the protected {table_name} row count", file=sys.stderr)
            sys.exit(4)

before_fingerprints = before["UserDataModel.sqlite"].get("protectedFingerprints")
if not isinstance(before_fingerprints, dict) or not before_fingerprints:
    print("prelaunch User store lacks protected wallet fingerprints", file=sys.stderr)
    sys.exit(5)
for fingerprint_name, expected_fingerprint in before_fingerprints.items():
    if (
        not isinstance(fingerprint_name, str)
        or not isinstance(expected_fingerprint, str)
        or len(expected_fingerprint) != 64
    ):
        print("prelaunch User store has malformed protected fingerprints", file=sys.stderr)
        sys.exit(6)
    for phase_name, payload in (("first launch", first), ("relaunch", second)):
        actual_fingerprint = (
            payload["UserDataModel.sqlite"]
            .get("protectedFingerprints", {})
            .get(fingerprint_name)
        )
        if actual_fingerprint != expected_fingerprint:
            print(
                f"{phase_name} changed protected wallet identities, keys, or relationships",
                file=sys.stderr,
            )
            sys.exit(7)

substrate_critical_tables = ("ZCDCHAIN", "ZCDRUNTIMEMETADATAITEM")
before_substrate = before["SubstrateDataModel.sqlite"]["tables"]
for table_name in substrate_critical_tables:
    expected_count = before_substrate.get(table_name)
    if not isinstance(expected_count, int) or expected_count <= 0:
        print(f"prelaunch Substrate store lacks populated {table_name}", file=sys.stderr)
        sys.exit(8)
    for phase_name, payload in (("first launch", first), ("relaunch", second)):
        actual_count = payload["SubstrateDataModel.sqlite"]["tables"].get(table_name)
        if actual_count != expected_count:
            print(f"{phase_name} changed the protected {table_name} row count", file=sys.stderr)
            sys.exit(9)

before_topology_store = before["SubstrateDataModel.sqlite"]
before_coverage = before_topology_store.get("topologyCoverage")
if before_coverage != {
    "customOnlyChain": True,
    "selectedCustomNode": True,
}:
    print(
        "prelaunch Substrate fixture lacks required custom-node topology coverage",
        file=sys.stderr,
    )
    sys.exit(10)
before_topology = before_topology_store.get("protectedTopologyFingerprints")
if not isinstance(before_topology, dict) or not before_topology:
    print("prelaunch Substrate store lacks topology fingerprints", file=sys.stderr)
    sys.exit(11)
for fingerprint_name, expected_fingerprint in before_topology.items():
    if (
        not isinstance(fingerprint_name, str)
        or not isinstance(expected_fingerprint, str)
        or len(expected_fingerprint) != 64
    ):
        print("prelaunch Substrate topology fingerprint is malformed", file=sys.stderr)
        sys.exit(12)
    for phase_name, payload in (("first launch", first), ("relaunch", second)):
        topology_store = payload["SubstrateDataModel.sqlite"]
        if topology_store.get("topologyCoverage") != before_coverage:
            print(
                f"{phase_name} changed required custom-node topology coverage",
                file=sys.stderr,
            )
            sys.exit(13)
        actual_fingerprint = (
            topology_store
            .get("protectedTopologyFingerprints", {})
            .get(fingerprint_name)
        )
        if actual_fingerprint != expected_fingerprint:
            print(
                f"{phase_name} changed protected default/custom/selected/orphan node topology",
                file=sys.stderr,
            )
            sys.exit(14)
PY
}

validate_simulator_inventory() {
  local inventory_file="$1"

  "$PYTHON_BIN" - "$inventory_file" "$SIMULATOR_UDID" <<'PY'
import json
import re
import sys

inventory_path, requested = sys.argv[1:]
uuid_pattern = re.compile(
    r"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
)
if not uuid_pattern.fullmatch(requested):
    print("requested Simulator UDID is not a canonical UUID", file=sys.stderr)
    sys.exit(2)

try:
    with open(inventory_path, "r", encoding="utf-8") as source:
        payload = json.load(source)
except (OSError, json.JSONDecodeError):
    print("simctl returned malformed device inventory", file=sys.stderr)
    sys.exit(3)

matches = []
devices_by_runtime = payload.get("devices")
if not isinstance(devices_by_runtime, dict):
    print("simctl device inventory has no devices object", file=sys.stderr)
    sys.exit(4)

for runtime, devices in devices_by_runtime.items():
    if not isinstance(runtime, str) or ".SimRuntime.iOS-" not in runtime:
        continue
    if not isinstance(devices, list):
        continue
    for device in devices:
        if (
            isinstance(device, dict)
            and str(device.get("udid", "")).lower() == requested.lower()
        ):
            matches.append(device)

if len(matches) != 1:
    print("requested UDID is not exactly one iOS Simulator", file=sys.stderr)
    sys.exit(5)

device = matches[0]
if device.get("isAvailable", True) is not True:
    print("requested iOS Simulator is unavailable", file=sys.stderr)
    sys.exit(6)
if device.get("state") != "Booted":
    print("requested iOS Simulator must already be Booted", file=sys.stderr)
    sys.exit(7)
name = device.get("name")
if not isinstance(name, str) or not name.startswith("iPhone"):
    print("requested Simulator must be an iPhone", file=sys.stderr)
    sys.exit(8)
PY
}

process_is_expected_and_alive() {
  local pid="$1"
  local process_command

  if [[ -n "$PROCESS_CHECK_BIN" ]]; then
    "$PROCESS_CHECK_BIN" "$pid" "$APP_EXECUTABLE_NAME"
    return
  fi

  kill -0 "$pid" 2>/dev/null || return 1
  process_command="$("$PS_BIN" -p "$pid" -o command= 2>/dev/null)" || return 1
  [[ "$process_command" == *"/$APP_EXECUTABLE_NAME"* ||
    "$process_command" == "$APP_EXECUTABLE_NAME" ||
    "$process_command" == "$APP_EXECUTABLE_NAME "* ]]
}

assert_process_stays_alive() {
  local pid="$1"
  local elapsed=0

  while [[ "$elapsed" -lt "$ALIVE_SECONDS" ]]; do
    process_is_expected_and_alive "$pid" ||
      fail "launched app did not remain alive for the required interval"
    "$SLEEP_BIN" 1
    elapsed=$((elapsed + 1))
  done
  process_is_expected_and_alive "$pid" ||
    fail "launched app exited at the end of the required interval"
}

parse_launch_pid() {
  local launch_output="$1"

  "$PYTHON_BIN" - "$launch_output" "$BUNDLE_ID" <<'PY'
import re
import sys

path, bundle_id = sys.argv[1:]
try:
    with open(path, "r", encoding="utf-8", errors="replace") as source:
        lines = source.readlines()
except OSError:
    sys.exit(2)

pattern = re.compile(r"^\s*" + re.escape(bundle_id) + r":\s*([1-9][0-9]*)\s*$")
matches = [pattern.match(line).group(1) for line in lines if pattern.match(line)]
if len(matches) != 1:
    sys.exit(3)
print(matches[0])
PY
}

scan_for_new_crash_reports() {
  local marker="$1"
  local phase="$2"
  local result_file="$ARTIFACTS_DIR/crash-scan-${phase}.txt"

  if "$PYTHON_BIN" - \
    "$CRASH_REPORT_DIR" \
    "$marker" \
    "$SIMULATOR_UDID" \
    "$BUNDLE_ID" \
    "$APP_EXECUTABLE_NAME" \
    "$result_file" <<'PY'
import os
import sys

root, marker_path, _udid, bundle_id, executable, output = sys.argv[1:]
marker_ns = os.stat(marker_path).st_mtime_ns
matches = []

for directory, _, filenames in os.walk(root):
    for filename in filenames:
        if not (filename.endswith(".ips") or filename.endswith(".crash")):
            continue
        path = os.path.join(directory, filename)
        try:
            if os.stat(path).st_mtime_ns < marker_ns:
                continue
            with open(path, "r", encoding="utf-8", errors="ignore") as source:
                content = source.read()
        except OSError:
            continue
        lowered = content.lower()
        has_app = bundle_id.lower() in lowered or executable.lower() in lowered
        if has_app:
            matches.append(filename)

with open(output, "w", encoding="utf-8") as destination:
    if matches:
        destination.write("matching crash report detected\n")
    else:
        destination.write("clean\n")

sys.exit(1 if matches else 0)
PY
  then
    return
  fi

  fail "a new crash report matched the requested Simulator app during $phase"
}

scan_unified_log_markers() {
  local start_time="$1"
  local phase="$2"
  local raw_file="$ARTIFACTS_DIR/unified-log-filtered-${phase}.pending"
  local scan_file="$ARTIFACTS_DIR/unified-log-scan-${phase}.txt"
  local predicate

  predicate="process == \"$APP_EXECUTABLE_NAME\" AND (eventMessage CONTAINS[c] \"FEARLESS_STARTUP_\" OR eventMessage CONTAINS[c] \"CoreData\" OR eventMessage CONTAINS[c] \"migration\" OR eventMessage CONTAINS[c] \"persistent store\" OR eventMessage CONTAINS[c] \"fatal\" OR eventMessage CONTAINS[c] \"exception\" OR eventMessage CONTAINS[c] \"abort\")"

  if ! "$XCRUN_BIN" simctl spawn "$SIMULATOR_UDID" log show \
    --style compact \
    --start "$start_time" \
    --predicate "$predicate" >"$raw_file" 2>/dev/null; then
    : >"$raw_file"
    fail "unable to inspect the Simulator unified log"
  fi

  if "$PYTHON_BIN" - "$raw_file" "$scan_file" <<'PY'
import re
import sys

source_path, output_path = sys.argv[1:]
patterns = {
    "fatal-error": re.compile(r"\bfatal error\b", re.IGNORECASE),
    "uncaught-exception": re.compile(r"\buncaught (?:objective-c )?exception\b", re.IGNORECASE),
    "abort": re.compile(r"\b(?:abort|aborted|sigabrt)\b", re.IGNORECASE),
    "migration-failure": re.compile(
        r"\b(?:migration|migrate|mapping model)\b.{0,120}\b(?:fail|error|incompatible|missing|abort)\b",
        re.IGNORECASE,
    ),
    "persistent-store-failure": re.compile(
        r"\b(?:persistent store|addPersistentStore|NSPersistentStore)\b.{0,120}\b(?:fail|error|incompatible|missing|abort)\b",
        re.IGNORECASE,
    ),
    "core-data-failure": re.compile(
        r"\b(?:CoreData|NSCocoaErrorDomain)\b.{0,120}\b(?:fatal|fail|error|exception|abort|incompatible)\b",
        re.IGNORECASE,
    ),
}

with open(source_path, "r", encoding="utf-8", errors="ignore") as source:
    content = source.read()
matched = sorted(name for name, pattern in patterns.items() if pattern.search(content))
ready_count = content.count("FEARLESS_STARTUP_READY")
failure_count = content.count("FEARLESS_STARTUP_FAILED")
if ready_count != 1:
    matched.append("startup-ready-count")
if failure_count != 0:
    matched.append("startup-failure")
matched = sorted(set(matched))

with open(output_path, "w", encoding="utf-8") as destination:
    if matched:
        for name in matched:
            destination.write(name + "\n")
    else:
        destination.write("clean\n")

sys.exit(1 if matched else 0)
PY
  then
    : >"$raw_file"
    return
  fi

  : >"$raw_file"
  fail "startup readiness failed or fatal migration/Core Data marker detected during $phase"
}

terminate_running_app() {
  local pid="$1"
  local attempts=0

  "$XCRUN_BIN" simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" \
    >/dev/null 2>&1 ||
    fail "simctl could not terminate the rehearsed app"
  APP_RUNNING=0

  while process_is_expected_and_alive "$pid"; do
    attempts=$((attempts + 1))
    [[ "$attempts" -le 5 ]] ||
      fail "rehearsed app process remained alive after termination"
    "$SLEEP_BIN" 1
  done
}

capture_target_state() {
  local phase="$1"
  local manifest="$ARTIFACTS_DIR/${phase}-target.sha256"
  local audit_directory="$ARTIFACTS_DIR/audits/$phase"
  local counts_file="$ARTIFACTS_DIR/${phase}-counts.json"

  require_no_unexpected_files "$CORE_DATA_TARGET" ||
    fail "target Core Data directory failed strict file validation"
  write_family_manifest "$CORE_DATA_TARGET" "$manifest" "0"
  mkdir "$audit_directory"
  copy_family "$CORE_DATA_TARGET" "$audit_directory" "0"
  inspect_sqlite_copies "$audit_directory" "$counts_file"
  log_count_summary "$counts_file" "$phase"
}

run_launch_phase() {
  local phase="$1"
  local marker="$ARTIFACTS_DIR/${phase}-launch.marker"
  local launch_output="$ARTIFACTS_DIR/${phase}-launch-output.pending"
  local launch_error="$ARTIFACTS_DIR/${phase}-launch-error.pending"
  local start_time
  local pid

  : >"$marker"
  start_time="$(date -u '+%Y-%m-%d %H:%M:%S%z')"
  if ! "$XCRUN_BIN" simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" \
    >"$launch_output" 2>"$launch_error"; then
    : >"$launch_output"
    : >"$launch_error"
    fail "simctl could not launch the app during $phase"
  fi
  pid="$(parse_launch_pid "$launch_output")" ||
    fail "simctl launch did not return one valid app PID"
  : >"$launch_output"
  : >"$launch_error"
  APP_RUNNING=1

  assert_process_stays_alive "$pid"
  scan_for_new_crash_reports "$marker" "${phase}-while-running"
  scan_unified_log_markers "$start_time" "$phase"
  terminate_running_app "$pid"
  scan_for_new_crash_reports "$marker" "${phase}-after-termination"
  capture_target_state "$phase"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --simulator-udid)
      require_option_value "$1" "$#"
      SIMULATOR_UDID="$2"
      shift 2
      ;;
    --app)
      require_option_value "$1" "$#"
      APP_PATH="$2"
      shift 2
      ;;
    --bundle-id)
      require_option_value "$1" "$#"
      BUNDLE_ID="$2"
      shift 2
      ;;
    --expected-git-sha)
      require_option_value "$1" "$#"
      EXPECTED_GIT_SHA="$2"
      shift 2
      ;;
    --expected-build)
      require_option_value "$1" "$#"
      EXPECTED_BUILD="$2"
      shift 2
      ;;
    --expected-executable-sha256)
      require_option_value "$1" "$#"
      EXPECTED_EXECUTABLE_SHA256="$2"
      shift 2
      ;;
    --fixture-dir)
      require_option_value "$1" "$#"
      FIXTURE_DIR="$2"
      shift 2
      ;;
    --artifacts-dir)
      require_option_value "$1" "$#"
      ARTIFACTS_DIR="$2"
      shift 2
      ;;
    --crash-report-dir)
      require_option_value "$1" "$#"
      CRASH_REPORT_DIR="$2"
      shift 2
      ;;
    --alive-seconds)
      require_option_value "$1" "$#"
      ALIVE_SECONDS="$2"
      shift 2
      ;;
    --confirm-disposable-fixture)
      DISPOSABLE_FIXTURE_CONFIRMED=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "$SIMULATOR_UDID" ]] || fail "--simulator-udid is required"
[[ "$SIMULATOR_UDID" =~ $UUID_PATTERN ]] ||
  fail "--simulator-udid must be a canonical UUID"
[[ -n "$APP_PATH" ]] || fail "--app is required"
[[ "$APP_PATH" == /* ]] || fail "--app must be an absolute path"
[[ -n "$BUNDLE_ID" ]] || fail "--bundle-id is required"
[[ "$BUNDLE_ID" =~ $BUNDLE_ID_PATTERN ]] ||
  fail "--bundle-id is malformed"
[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] ||
  fail "--bundle-id must be the production Fearless identity"
[[ "$EXPECTED_GIT_SHA" =~ ^[0-9A-Fa-f]{40}$ ]] ||
  fail "--expected-git-sha must be an exact 40-hex commit"
[[ "$EXPECTED_BUILD" =~ ^[1-9][0-9]{0,3}(\.[0-9]{1,2}){0,2}$ ]] ||
  fail "--expected-build must be an explicit canonical CFBundleVersion"
[[ "$EXPECTED_EXECUTABLE_SHA256" =~ ^[0-9A-Fa-f]{64}$ ]] ||
  fail "--expected-executable-sha256 must be 64 hex"
[[ -n "$FIXTURE_DIR" ]] || fail "--fixture-dir is required"
[[ "$FIXTURE_DIR" == /* ]] || fail "--fixture-dir must be an absolute path"
[[ -n "$ARTIFACTS_DIR" ]] || fail "--artifacts-dir is required"
[[ "$ARTIFACTS_DIR" == /* ]] || fail "--artifacts-dir must be an absolute path"
[[ "$CRASH_REPORT_DIR" == /* ]] ||
  fail "--crash-report-dir must be an absolute path"
[[ "$ALIVE_SECONDS" =~ ^[0-9]+$ ]] ||
  fail "--alive-seconds must be an integer"
[[ "$ALIVE_SECONDS" -ge 1 && "$ALIVE_SECONDS" -le 30 ]] ||
  fail "--alive-seconds must be between 1 and 30"
[[ "$DISPOSABLE_FIXTURE_CONFIRMED" == "1" ]] ||
  fail "--confirm-disposable-fixture is required"

require_executable "$XCRUN_BIN" "xcrun"
require_executable "$CODESIGN_BIN" "codesign"
require_executable "$PYTHON_BIN" "Python"
require_executable "$SHASUM_BIN" "shasum"
require_executable "$PS_BIN" "ps"
require_executable "$SLEEP_BIN" "sleep"
if [[ -n "$PROCESS_CHECK_BIN" ]]; then
  require_executable "$PROCESS_CHECK_BIN" "process checker"
fi

[[ -d "$APP_PATH" && ! -L "$APP_PATH" ]] ||
  fail "--app must name a real .app directory, not a symlink"
[[ "${APP_PATH##*/}" == *.app ]] ||
  fail "--app must end in .app"
APP_PATH="$(canonical_directory "$APP_PATH")"

[[ -d "$FIXTURE_DIR" && ! -L "$FIXTURE_DIR" ]] ||
  fail "--fixture-dir must name a real directory, not a symlink"
FIXTURE_DIR="$(canonical_directory "$FIXTURE_DIR")"

[[ -d "$CRASH_REPORT_DIR" && ! -L "$CRASH_REPORT_DIR" ]] ||
  fail "--crash-report-dir must name a real directory"
CRASH_REPORT_DIR="$(canonical_directory "$CRASH_REPORT_DIR")"

[[ ! -e "$ARTIFACTS_DIR" && ! -L "$ARTIFACTS_DIR" ]] ||
  fail "--artifacts-dir must not already exist"
artifacts_parent="$(dirname "$ARTIFACTS_DIR")"
artifacts_name="$(basename "$ARTIFACTS_DIR")"
[[ "$artifacts_name" != "." && "$artifacts_name" != ".." ]] ||
  fail "--artifacts-dir has an unsafe basename"
[[ -d "$artifacts_parent" && ! -L "$artifacts_parent" ]] ||
  fail "--artifacts-dir parent must be a real existing directory"
artifacts_parent="$(canonical_directory "$artifacts_parent")"
ARTIFACTS_DIR="$artifacts_parent/$artifacts_name"

if path_is_within "$ARTIFACTS_DIR" "$FIXTURE_DIR" ||
  path_is_within "$FIXTURE_DIR" "$ARTIFACTS_DIR"; then
  fail "artifacts and fixture directories must not overlap"
fi
if path_is_within "$ARTIFACTS_DIR" "$APP_PATH" ||
  path_is_within "$APP_PATH" "$ARTIFACTS_DIR"; then
  fail "artifacts and app directories must not overlap"
fi

mkdir "$ARTIFACTS_DIR"
mkdir "$ARTIFACTS_DIR/staging"
mkdir "$ARTIFACTS_DIR/audits"

[[ -f "$APP_PATH/Info.plist" && ! -L "$APP_PATH/Info.plist" ]] ||
  fail "app Info.plist is missing or unsafe"
actual_bundle_id="$(plist_string "$APP_PATH/Info.plist" "CFBundleIdentifier")" ||
  fail "unable to read CFBundleIdentifier from the app"
[[ "$actual_bundle_id" == "$BUNDLE_ID" ]] ||
  fail "explicit bundle ID does not match the app"

APP_EXECUTABLE_NAME="$(plist_string "$APP_PATH/Info.plist" "CFBundleExecutable")" ||
  fail "unable to read CFBundleExecutable from the app"
[[ "$APP_EXECUTABLE_NAME" =~ ^[A-Za-z0-9._-]+$ ]] ||
  fail "app executable name is unsafe"
APP_EXECUTABLE_PATH="$APP_PATH/$APP_EXECUTABLE_NAME"
[[ -f "$APP_EXECUTABLE_PATH" && ! -L "$APP_EXECUTABLE_PATH" &&
  -x "$APP_EXECUTABLE_PATH" ]] ||
  fail "app executable is missing, non-regular, symlinked, or not executable"

build_platform="$("$XCRUN_BIN" vtool -show-build "$APP_EXECUTABLE_PATH" 2>/dev/null)" ||
  fail "unable to inspect app binary platform"
if ! grep -Eq \
  'platform[[:space:]]+(IOSSIMULATOR|7)([[:space:]]|$)|LC_VERSION_MIN_IPHONESIMULATOR' \
  <<<"$build_platform"; then
  fail "app binary is not an iOS Simulator binary; refusing device app"
fi
if grep -Eq 'platform[[:space:]]+IOS([[:space:]]|$)' <<<"$build_platform"; then
  fail "app binary includes an iOS device platform; refusing it"
fi
printf '%s\n' "iOS Simulator binary verified" \
  >"$ARTIFACTS_DIR/app-platform-verification.txt"
validate_app_signature_contract
validate_release_app_contract

if ! "$XCRUN_BIN" simctl list devices --json \
  >"$ARTIFACTS_DIR/simulator-inventory.pending" 2>/dev/null; then
  fail "unable to obtain Simulator inventory"
fi
validate_simulator_inventory "$ARTIFACTS_DIR/simulator-inventory.pending" ||
  fail "requested destination failed Simulator-only validation"
: >"$ARTIFACTS_DIR/simulator-inventory.pending"
printf '%s\n' "explicit booted iPhone Simulator verified" \
  >"$ARTIFACTS_DIR/simulator-verification.txt"

validate_fixture_directory "$FIXTURE_DIR" ||
  fail "fixture failed exact immutable-family validation"
write_family_manifest \
  "$FIXTURE_DIR" \
  "$ARTIFACTS_DIR/source-before.sha256" \
  "1"

seed_directory="$ARTIFACTS_DIR/staging/seed"
mkdir "$seed_directory"
copy_family "$FIXTURE_DIR" "$seed_directory" "1"
write_family_manifest \
  "$FIXTURE_DIR" \
  "$ARTIFACTS_DIR/source-after-copy.sha256" \
  "1"
cmp -s \
  "$ARTIFACTS_DIR/source-before.sha256" \
  "$ARTIFACTS_DIR/source-after-copy.sha256" ||
  fail "source fixture changed while it was copied"
write_family_manifest \
  "$seed_directory" \
  "$ARTIFACTS_DIR/seed.sha256" \
  "1"
cmp -s "$ARTIFACTS_DIR/source-before.sha256" "$ARTIFACTS_DIR/seed.sha256" ||
  fail "private seed copy does not match the source fixture"

if [[ "$DRY_RUN" == "1" ]]; then
  dry_audit="$ARTIFACTS_DIR/audits/dry-run"
  mkdir "$dry_audit"
  copy_family "$seed_directory" "$dry_audit" "1"
  inspect_sqlite_copies "$dry_audit" "$ARTIFACTS_DIR/dry-run-counts.json"
  log_count_summary "$ARTIFACTS_DIR/dry-run-counts.json" "dry-run"
  write_family_manifest \
    "$FIXTURE_DIR" \
    "$ARTIFACTS_DIR/source-after-run.sha256" \
    "1"
  cmp -s \
    "$ARTIFACTS_DIR/source-before.sha256" \
    "$ARTIFACTS_DIR/source-after-run.sha256" ||
    fail "source fixture changed during dry-run validation"
  log "DRY RUN PASSED: inputs are simulator-only, copied stores are intact, source is unchanged"
  exit 0
fi

if "$XCRUN_BIN" simctl get_app_container \
  "$SIMULATOR_UDID" "$BUNDLE_ID" data \
  >"$ARTIFACTS_DIR/preexisting-data-container.pending" 2>&1; then
  : >"$ARTIFACTS_DIR/preexisting-data-container.pending"
  fail "bundle already has Simulator data; use a fresh dedicated Simulator"
fi
: >"$ARTIFACTS_DIR/preexisting-data-container.pending"

if "$XCRUN_BIN" simctl get_app_container \
  "$SIMULATOR_UDID" "$BUNDLE_ID" app \
  >"$ARTIFACTS_DIR/preexisting-app-container.pending" 2>&1; then
  : >"$ARTIFACTS_DIR/preexisting-app-container.pending"
  fail "bundle is already installed; use a fresh dedicated Simulator"
fi
: >"$ARTIFACTS_DIR/preexisting-app-container.pending"

if ! "$XCRUN_BIN" simctl install "$SIMULATOR_UDID" "$APP_PATH" \
  >"$ARTIFACTS_DIR/install.pending" 2>&1; then
  : >"$ARTIFACTS_DIR/install.pending"
  fail "simctl could not install the app"
fi
: >"$ARTIFACTS_DIR/install.pending"

if ! "$XCRUN_BIN" simctl get_app_container \
  "$SIMULATOR_UDID" "$BUNDLE_ID" data \
  >"$ARTIFACTS_DIR/data-container.pending" 2>/dev/null; then
  fail "unable to obtain the installed app data container"
fi
DATA_CONTAINER="$(tr -d '\r\n' <"$ARTIFACTS_DIR/data-container.pending")"
: >"$ARTIFACTS_DIR/data-container.pending"
[[ "$DATA_CONTAINER" == /* && -d "$DATA_CONTAINER" && ! -L "$DATA_CONTAINER" ]] ||
  fail "simctl returned an unsafe data container"
DATA_CONTAINER="$(canonical_directory "$DATA_CONTAINER")"
[[ "$DATA_CONTAINER" == *"/CoreSimulator/Devices/$SIMULATOR_UDID/data/Containers/Data/Application/"* ]] ||
  fail "data container is not rooted in the requested Simulator"

# A newly installed app is not expected to be running. A successful terminate
# is accepted, as is simctl's documented-style "not running" response.
if ! "$XCRUN_BIN" simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" \
  >"$ARTIFACTS_DIR/preseed-terminate.pending" 2>&1; then
  if ! grep -Eqi 'not running|nothing to terminate|no such process' \
    "$ARTIFACTS_DIR/preseed-terminate.pending"; then
    : >"$ARTIFACTS_DIR/preseed-terminate.pending"
    fail "could not establish a terminated preseed app state"
  fi
fi
: >"$ARTIFACTS_DIR/preseed-terminate.pending"

write_family_manifest \
  "$FIXTURE_DIR" \
  "$ARTIFACTS_DIR/source-before-injection.sha256" \
  "1"
cmp -s \
  "$ARTIFACTS_DIR/source-before.sha256" \
  "$ARTIFACTS_DIR/source-before-injection.sha256" ||
  fail "source fixture changed before Simulator injection"

CORE_DATA_TARGET="$DATA_CONTAINER/Documents/CoreData"
if [[ -e "$CORE_DATA_TARGET" || -L "$CORE_DATA_TARGET" ]]; then
  [[ -d "$CORE_DATA_TARGET" && ! -L "$CORE_DATA_TARGET" ]] ||
    fail "target CoreData path is not a real directory"
  if [[ -n "$(find "$CORE_DATA_TARGET" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    fail "new Simulator app unexpectedly has existing Core Data files"
  fi
else
  mkdir -p "$CORE_DATA_TARGET"
fi
CORE_DATA_TARGET="$(canonical_directory "$CORE_DATA_TARGET")"
path_is_within "$CORE_DATA_TARGET" "$DATA_CONTAINER" ||
  fail "target CoreData directory escaped the Simulator data container"

copy_family "$seed_directory" "$CORE_DATA_TARGET" "1"
require_no_unexpected_files "$CORE_DATA_TARGET" ||
  fail "injected Core Data family failed strict validation"
write_family_manifest \
  "$CORE_DATA_TARGET" \
  "$ARTIFACTS_DIR/prelaunch-target.sha256" \
  "1"
cmp -s \
  "$ARTIFACTS_DIR/source-before.sha256" \
  "$ARTIFACTS_DIR/prelaunch-target.sha256" ||
  fail "injected Simulator store family does not match the source"
capture_target_state "prelaunch"

run_launch_phase "first-launch"
run_launch_phase "relaunch"

validate_preservation \
  "$ARTIFACTS_DIR/prelaunch-counts.json" \
  "$ARTIFACTS_DIR/first-launch-counts.json" \
  "$ARTIFACTS_DIR/relaunch-counts.json" ||
  fail "protected Core Data counts were not preserved"

write_family_manifest \
  "$FIXTURE_DIR" \
  "$ARTIFACTS_DIR/source-after-run.sha256" \
  "1"
cmp -s \
  "$ARTIFACTS_DIR/source-before.sha256" \
  "$ARTIFACTS_DIR/source-after-run.sha256" ||
  fail "source fixture changed during the rehearsal"

log "PASSED: first launch and relaunch each reached a usable startup route with no crash or fatal migration/Core Data marker"
log "PASSED: copied stores remain intact; protected wallet and custom-node topology fingerprints are preserved"
log "PASSED: signed Simulator Release/-O/non-testable artifact, exact commit/version/build/executable hash, 26 managed-object classes, and 29 migration resources verified; source fixture is unchanged"
log "NOTE: device distribution profile, production entitlements, and TestFlight Keychain capability require audit-ios-signed-release-artifact.sh against the exact .xcarchive"
