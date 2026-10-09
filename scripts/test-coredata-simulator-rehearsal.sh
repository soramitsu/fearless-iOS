#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REHEARSAL="$SCRIPT_DIR/ci/run-coredata-simulator-rehearsal.sh"
readonly TEMPORARY_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-simulator-rehearsal-tests.XXXXXX")"
readonly SIMULATOR_UDID="11111111-2222-3333-4444-555555555555"
readonly BUNDLE_ID="jp.co.soramitsu.fearlesswallet"

CASE_NUMBER=0
CASE_DIR=""
APP_DIR=""
FIXTURE_DIR=""
ARTIFACTS_DIR=""
CRASH_DIR=""
COMMAND_LOG=""
INSTALL_STATE=""
PID_FILE=""
CASE_ENV=()
CASE_ARGS=()

cleanup() {
  local pid

  if [[ -f "$TEMPORARY_DIR/all-pids" ]]; then
    while IFS= read -r pid; do
      if [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
        kill "$pid" >/dev/null 2>&1 || true
      fi
    done <"$TEMPORARY_DIR/all-pids"
  fi
  chmod -R u+w "$TEMPORARY_DIR" >/dev/null 2>&1 || true
  rm -r "$TEMPORARY_DIR"
}

trap cleanup EXIT

fail() {
  printf '%s\n' "[coredata-simulator-rehearsal-test][error] $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  local path="$2"
  grep -Fq -- "$expected" "$path" ||
    fail "expected '$expected' in $(basename "$path")"
}

assert_command_count() {
  local expected="$1"
  local count="$2"
  local actual

  actual="$(grep -Fxc -- "$expected" "$COMMAND_LOG" || true)"
  [[ "$actual" == "$count" ]] ||
    fail "expected command '$expected' $count time(s), found $actual"
}

canonical_directory() {
  local directory="$1"
  (cd "$directory" && pwd -P)
}

create_sqlite_fixture() {
  local directory="$1"

  python3 - "$directory" <<'PY'
import os
import sqlite3
import sys

directory = sys.argv[1]
definitions = {
    "CacheDataModel.sqlite": (
        "CREATE TABLE ZCACHE (Z_PK INTEGER PRIMARY KEY, ZVALUE TEXT)",
        "INSERT INTO ZCACHE (ZVALUE) VALUES ('opaque')",
    ),
    "SubstrateDataModel.sqlite": (
        "CREATE TABLE ZCDCHAIN (Z_PK INTEGER PRIMARY KEY)",
        "CREATE TABLE ZCDRUNTIMEMETADATAITEM (Z_PK INTEGER PRIMARY KEY)",
        "INSERT INTO ZCDCHAIN DEFAULT VALUES",
        "INSERT INTO ZCDCHAIN DEFAULT VALUES",
        "INSERT INTO ZCDRUNTIMEMETADATAITEM DEFAULT VALUES",
        "INSERT INTO ZCDRUNTIMEMETADATAITEM DEFAULT VALUES",
    ),
    "UserDataModel.sqlite": (
        """
        CREATE TABLE ZCDMETAACCOUNT (
          Z_PK INTEGER PRIMARY KEY,
          ZMETAID TEXT,
          ZSUBSTRATEACCOUNTID TEXT,
          ZSUBSTRATEPUBLICKEY BLOB,
          ZSUBSTRATECRYPTOTYPE INTEGER,
          ZETHEREUMADDRESS TEXT,
          ZETHEREUMPUBLICKEY BLOB,
          ZTONADDRESS BLOB,
          ZTONPUBLICKEY BLOB
        )
        """,
        """
        CREATE TABLE ZCDCHAINACCOUNT (
          Z_PK INTEGER PRIMARY KEY,
          ZACCOUNTID TEXT,
          ZCHAINID TEXT,
          ZPUBLICKEY BLOB,
          ZCRYPTOTYPE INTEGER,
          ZMETAACCOUNT INTEGER
        )
        """,
        """
        INSERT INTO ZCDMETAACCOUNT (
          ZMETAID, ZSUBSTRATEACCOUNTID, ZSUBSTRATEPUBLICKEY,
          ZSUBSTRATECRYPTOTYPE, ZETHEREUMADDRESS, ZETHEREUMPUBLICKEY,
          ZTONADDRESS, ZTONPUBLICKEY
        ) VALUES (
          'wallet-a', 'substrate-a', X'0102', 0, 'ethereum-a', X'0304',
          X'0506', X'0708'
        )
        """,
        """
        INSERT INTO ZCDMETAACCOUNT (
          ZMETAID, ZSUBSTRATEACCOUNTID, ZSUBSTRATEPUBLICKEY,
          ZSUBSTRATECRYPTOTYPE, ZETHEREUMADDRESS, ZETHEREUMPUBLICKEY,
          ZTONADDRESS, ZTONPUBLICKEY
        ) VALUES (
          'wallet-b', 'substrate-b', X'1112', 1, 'ethereum-b', X'1314',
          X'1516', X'1718'
        )
        """,
        """
        INSERT INTO ZCDCHAINACCOUNT (
          ZACCOUNTID, ZCHAINID, ZPUBLICKEY, ZCRYPTOTYPE, ZMETAACCOUNT
        ) VALUES ('account-a', 'chain-a', X'2122', 0, 1)
        """,
        """
        INSERT INTO ZCDCHAINACCOUNT (
          ZACCOUNTID, ZCHAINID, ZPUBLICKEY, ZCRYPTOTYPE, ZMETAACCOUNT
        ) VALUES ('account-b', 'chain-b', X'3132', 1, 2)
        """,
    ),
}

for filename, statements in definitions.items():
    connection = sqlite3.connect(os.path.join(directory, filename))
    try:
        for statement in statements:
            connection.execute(statement)
        connection.commit()
    finally:
        connection.close()

    open(os.path.join(directory, filename + "-shm"), "wb").close()
    open(os.path.join(directory, filename + "-wal"), "wb").close()
PY
}

prepare_case() {
  local label="$1"

  CASE_NUMBER=$((CASE_NUMBER + 1))
  CASE_DIR="$TEMPORARY_DIR/case-${CASE_NUMBER}-${label}"
  APP_DIR="$CASE_DIR/fearless.app"
  FIXTURE_DIR="$CASE_DIR/disposable-fixture"
  ARTIFACTS_DIR="$CASE_DIR/artifacts"
  CRASH_DIR="$CASE_DIR/DiagnosticReports"
  COMMAND_LOG="$CASE_DIR/commands"
  INSTALL_STATE="$CASE_DIR/installed"
  PID_FILE="$CASE_DIR/running-pid"

  mkdir -p "$APP_DIR" "$FIXTURE_DIR" "$CRASH_DIR"
  : >"$COMMAND_LOG"
  : >"$PID_FILE"
  create_sqlite_fixture "$FIXTURE_DIR"

  cat >"$APP_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key>
  <string>fearless</string>
  <key>FearlessBuildConfiguration</key>
  <string>Release</string>
  <key>FearlessSwiftOptimizationLevel</key>
  <string>-O</string>
  <key>FearlessEnableTestability</key>
  <string>NO</string>
</dict>
</plist>
PLIST
  cat >"$APP_DIR/fearless" <<'APP'
#!/usr/bin/env bash
exit 0
APP
  chmod +x "$APP_DIR/fearless"
  mkdir -p \
    "$APP_DIR/Modules_SSFAccountManagmentStorage.bundle/UserDataModel.momd" \
    "$APP_DIR/SubstrateDataModel.momd"
  local resource
  local -a resources=(
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
  for resource in "${resources[@]}"; do
    : >"$APP_DIR/$resource"
  done

  CASE_ENV=()
  CASE_ARGS=(
    --simulator-udid "$SIMULATOR_UDID"
    --app "$APP_DIR"
    --bundle-id "$BUNDLE_ID"
    --fixture-dir "$FIXTURE_DIR"
    --artifacts-dir "$ARTIFACTS_DIR"
    --crash-report-dir "$CRASH_DIR"
    --alive-seconds 1
    --confirm-disposable-fixture
  )
}

run_case() {
  local label="$1"

  env \
    FEARLESS_REHEARSAL_XCRUN_BIN="$TEMPORARY_DIR/bin/xcrun" \
    FEARLESS_REHEARSAL_CODESIGN_BIN="$TEMPORARY_DIR/bin/codesign" \
    FEARLESS_REHEARSAL_PROCESS_CHECK_BIN="$TEMPORARY_DIR/bin/process-check" \
    FAKE_SIMULATOR_UDID="$SIMULATOR_UDID" \
    FAKE_BUNDLE_ID="$BUNDLE_ID" \
    FAKE_CORE_SIM_ROOT="$CASE_DIR/Library/Developer" \
    FAKE_COMMAND_LOG="$COMMAND_LOG" \
    FAKE_INSTALL_STATE="$INSTALL_STATE" \
    FAKE_PID_FILE="$PID_FILE" \
    FAKE_ALL_PIDS="$TEMPORARY_DIR/all-pids" \
    FAKE_CRASH_DIR="$CRASH_DIR" \
    FAKE_FIXTURE_DIR="$FIXTURE_DIR" \
    ${CASE_ENV[@]+"${CASE_ENV[@]}"} \
    bash "$REHEARSAL" \
      "${CASE_ARGS[@]}" \
      >"$CASE_DIR/stdout" 2>"$CASE_DIR/stderr"
}

expect_failure() {
  local label="$1"
  local expected="$2"

  if run_case "$label"; then
    fail "$label unexpectedly passed"
  fi
  assert_contains "$expected" "$CASE_DIR/stderr"
  printf '%s\n' "[coredata-simulator-rehearsal-test] PASS (rejected): $label"
}

mkdir -p "$TEMPORARY_DIR/bin"
: >"$TEMPORARY_DIR/all-pids"

cat >"$TEMPORARY_DIR/bin/codesign" <<'CODESIGN'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--verify" ]]; then
  [[ "${FAKE_CODESIGN_VERIFY_FAIL:-0}" != "1" ]]
  exit
fi

[[ "${1:-}" == "-dv" && "${2:-}" == "--verbose=4" ]] ||
  exit 64

identifier="$FAKE_BUNDLE_ID"
case "${FAKE_CODESIGN_IDENTIFIER_MODE:-valid}" in
  valid)
    ;;
  missing)
    identifier=""
    ;;
  spoofed)
    identifier="evil${FAKE_BUNDLE_ID}"
    ;;
  duplicate)
    printf '%s\n' "Identifier=$FAKE_BUNDLE_ID"
    ;;
  *)
    exit 64
    ;;
esac

printf '%s\n' "Executable=/private/tmp/fearless.app/fearless"
if [[ -n "$identifier" ]]; then
  printf '%s\n' "Identifier=$identifier"
fi
printf '%s\n' "Signature=adhoc"
CODESIGN

cat >"$TEMPORARY_DIR/bin/process-check" <<'CHECKER'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${FAKE_PROCESS_CHECK_FAIL:-0}" == "1" ]]; then
  exit 1
fi
kill -0 "$1" 2>/dev/null
CHECKER

cat >"$TEMPORARY_DIR/bin/xcrun" <<'XCRUN'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$FAKE_COMMAND_LOG"

if [[ "${1:-}" == "nm" ]]; then
  classes=(
    CDAsset CDChain CDChainNode CDChainStorageItem CDChainXcmConfig
    CDContact CDContactItem CDExternalApi CDPhishingItem CDPolkaswapDex
    CDPolkaswapRemoteSettings CDPriceData CDPriceProvider
    CDRuntimeMetadataItem CDScamInfo CDStashItem CDTransactionHistoryItem
    CDXcmAvailableAsset CDXcmAvailableDestination CDAccountInfo
    CDAssetVisibility CDChainAccount CDChainSettings CDCurrency
    CDCustomChainNode CDMetaAccount
  )
  for class_name in "${classes[@]}"; do
    if [[ "$class_name" != "${FAKE_MISSING_MANAGED_CLASS:-}" ]]; then
      printf '%s\n' "_OBJC_CLASS_\$_$class_name"
    fi
  done
  exit 0
fi

if [[ "${1:-}" == "vtool" ]]; then
  if [[ "${FAKE_APP_PLATFORM:-simulator}" == "device" ]]; then
    printf '%s\n' "platform IOS"
  else
    printf '%s\n' "platform IOSSIMULATOR"
  fi
  exit 0
fi

[[ "${1:-}" == "simctl" ]] || exit 64
shift

case "${1:-}" in
  list)
    state="${FAKE_SIMULATOR_STATE:-Booted}"
    available="${FAKE_SIMULATOR_AVAILABLE:-true}"
    name="${FAKE_SIMULATOR_NAME:-iPhone Rehearsal}"
    cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[{
  "udid":"$FAKE_SIMULATOR_UDID",
  "isAvailable":$available,
  "name":"$name",
  "state":"$state"
}]}}
JSON
    ;;
  get_app_container)
    if [[ ! -e "$FAKE_INSTALL_STATE" ]]; then
      printf '%s\n' "No such app" >&2
      exit 2
    fi
    container="$FAKE_CORE_SIM_ROOT/CoreSimulator/Devices/$FAKE_SIMULATOR_UDID/data/Containers/Data/Application/APP-DATA"
    mkdir -p "$container"
    if [[ "${4:-}" == "data" ]]; then
      printf '%s\n' "$container"
    else
      printf '%s\n' "$container/Installed.app"
    fi
    ;;
  install)
    if [[ "${FAKE_MUTATE_FIXTURE:-0}" == "1" ]]; then
      printf '%s\n' "mutation" >>"$FAKE_FIXTURE_DIR/UserDataModel.sqlite"
    fi
    : >"$FAKE_INSTALL_STATE"
    container="$FAKE_CORE_SIM_ROOT/CoreSimulator/Devices/$FAKE_SIMULATOR_UDID/data/Containers/Data/Application/APP-DATA"
    mkdir -p "$container"
    ;;
  terminate)
    if [[ -s "$FAKE_PID_FILE" ]]; then
      pid="$(cat "$FAKE_PID_FILE")"
      kill "$pid" >/dev/null 2>&1 || true
      : >"$FAKE_PID_FILE"
      exit 0
    fi
    printf '%s\n' "found nothing to terminate; app is not running" >&2
    exit 3
    ;;
  launch)
    sleep 300 &
    pid=$!
    printf '%s\n' "$pid" >"$FAKE_PID_FILE"
    printf '%s\n' "$pid" >>"$FAKE_ALL_PIDS"
    if [[ "${FAKE_CREATE_CRASH:-0}" == "1" ]]; then
      cat >"$FAKE_CRASH_DIR/fearless-test.ips" <<CRASH
{"bundleID":"$FAKE_BUNDLE_ID","device":"$FAKE_SIMULATOR_UDID","procName":"fearless"}
CRASH
    fi
    if [[ "${FAKE_CREATE_CRASH_WITHOUT_DEVICE:-0}" == "1" ]]; then
      cat >"$FAKE_CRASH_DIR/fearless-test-no-device.ips" <<CRASH
{"bundleID":"$FAKE_BUNDLE_ID","procName":"fearless"}
CRASH
    fi
    container="$FAKE_CORE_SIM_ROOT/CoreSimulator/Devices/$FAKE_SIMULATOR_UDID/data/Containers/Data/Application/APP-DATA"
    core_data="$container/Documents/CoreData"
    if [[ "${FAKE_MUTATE_USER_KEY:-0}" == "1" ]]; then
      python3 - "$core_data/UserDataModel.sqlite" <<'PY'
import sqlite3
import sys
connection = sqlite3.connect(sys.argv[1])
connection.execute("UPDATE ZCDMETAACCOUNT SET ZSUBSTRATEPUBLICKEY = X'FFFF' WHERE Z_PK = 1")
connection.commit()
connection.close()
PY
    fi
    if [[ "${FAKE_MUTATE_USER_RELATIONSHIP:-0}" == "1" ]]; then
      python3 - "$core_data/UserDataModel.sqlite" <<'PY'
import sqlite3
import sys
connection = sqlite3.connect(sys.argv[1])
connection.execute("UPDATE ZCDCHAINACCOUNT SET ZMETAACCOUNT = 2 WHERE Z_PK = 1")
connection.commit()
connection.close()
PY
    fi
    if [[ "${FAKE_DROP_ONE_SUBSTRATE_ROW:-0}" == "1" ]]; then
      python3 - "$core_data/SubstrateDataModel.sqlite" <<'PY'
import sqlite3
import sys
connection = sqlite3.connect(sys.argv[1])
connection.execute("DELETE FROM ZCDCHAIN WHERE Z_PK = (SELECT MAX(Z_PK) FROM ZCDCHAIN)")
connection.commit()
connection.close()
PY
    fi
    printf '%s: %s\n' "$FAKE_BUNDLE_ID" "$pid"
    ;;
  spawn)
    printf '%s\n' "${FAKE_LOG_CONTENT:-FEARLESS_STARTUP_READY}"
    ;;
  *)
    exit 64
    ;;
esac
XCRUN

chmod +x \
  "$TEMPORARY_DIR/bin/codesign" \
  "$TEMPORARY_DIR/bin/xcrun" \
  "$TEMPORARY_DIR/bin/process-check"

# A dry-run validates all immutable inputs and copied SQLite stores without any
# install, launch, termination, or container mutation.
prepare_case "dry-run"
CASE_ARGS+=(--dry-run)
if ! run_case "dry-run"; then
  sed -n '1,120p' "$CASE_DIR/stderr" >&2
  fail "valid dry-run was rejected"
fi
assert_contains "DRY RUN PASSED" "$CASE_DIR/stdout"
assert_command_count "simctl install $SIMULATOR_UDID $APP_DIR" "0"
assert_command_count "simctl launch $SIMULATOR_UDID $BUNDLE_ID" "0"
cmp -s "$ARTIFACTS_DIR/source-before.sha256" "$ARTIFACTS_DIR/source-after-run.sha256" ||
  fail "dry-run source manifests differ"
printf '%s\n' "[coredata-simulator-rehearsal-test] PASS: immutable dry-run"

# The fully stubbed happy path exercises install, first launch, bounded liveness,
# sanitized logs/crash scans, terminate, copied SQLite inspection, and relaunch.
prepare_case "full-rehearsal"
if ! run_case "full-rehearsal"; then
  sed -n '1,160p' "$CASE_DIR/stderr" >&2
  fail "valid full rehearsal was rejected"
fi
assert_contains "PASSED: first launch and relaunch each reached a usable startup route" "$CASE_DIR/stdout"
canonical_app_dir="$(canonical_directory "$APP_DIR")"
assert_command_count "simctl install $SIMULATOR_UDID $canonical_app_dir" "1"
assert_command_count "simctl launch $SIMULATOR_UDID $BUNDLE_ID" "2"
[[ "$(grep -c '^simctl terminate ' "$COMMAND_LOG")" == "3" ]] ||
  fail "full rehearsal did not terminate before seeding and after both launches"
[[ "$(grep -c '^simctl uninstall ' "$COMMAND_LOG" || true)" == "0" ]] ||
  fail "rehearsal attempted an uninstall"
cmp -s "$ARTIFACTS_DIR/source-before.sha256" "$ARTIFACTS_DIR/source-after-run.sha256" ||
  fail "full-rehearsal source manifests differ"
printf '%s\n' "[coredata-simulator-rehearsal-test] PASS: full first-launch/relaunch contract"

prepare_case "missing-acknowledgement"
CASE_ARGS=(
  --simulator-udid "$SIMULATOR_UDID"
  --app "$APP_DIR"
  --bundle-id "$BUNDLE_ID"
  --fixture-dir "$FIXTURE_DIR"
  --artifacts-dir "$ARTIFACTS_DIR"
  --crash-report-dir "$CRASH_DIR"
  --dry-run
)
expect_failure "missing acknowledgement" "--confirm-disposable-fixture is required"

prepare_case "malformed-udid"
CASE_ARGS[1]="not-a-device"
CASE_ARGS+=(--dry-run)
expect_failure "malformed UDID" "must be a canonical UUID"

prepare_case "device-binary"
CASE_ENV=("FAKE_APP_PLATFORM=device")
CASE_ARGS+=(--dry-run)
expect_failure "device binary" "refusing device app"

prepare_case "invalid-signature"
CASE_ENV=("FAKE_CODESIGN_VERIFY_FAIL=1")
CASE_ARGS+=(--dry-run)
expect_failure "invalid signature" "failed strict code-signature verification"

prepare_case "missing-code-signing-identifier"
CASE_ENV=("FAKE_CODESIGN_IDENTIFIER_MODE=missing")
CASE_ARGS+=(--dry-run)
expect_failure "missing code-signing identifier" "does not exactly match the requested bundle"

prepare_case "spoofed-code-signing-identifier"
CASE_ENV=("FAKE_CODESIGN_IDENTIFIER_MODE=spoofed")
CASE_ARGS+=(--dry-run)
expect_failure "spoofed code-signing identifier" "does not exactly match the requested bundle"

prepare_case "duplicate-code-signing-identifiers"
CASE_ENV=("FAKE_CODESIGN_IDENTIFIER_MODE=duplicate")
CASE_ARGS+=(--dry-run)
expect_failure "duplicate code-signing identifiers" "does not exactly match the requested bundle"

prepare_case "debug-configuration"
plutil -replace FearlessBuildConfiguration -string Debug "$APP_DIR/Info.plist"
CASE_ARGS+=(--dry-run)
expect_failure "Debug configuration" "not built with the Release configuration"

prepare_case "unoptimized-swift"
plutil -replace FearlessSwiftOptimizationLevel -json '"-Onone"' "$APP_DIR/Info.plist"
CASE_ARGS+=(--dry-run)
expect_failure "unoptimized Swift" "not built with Swift -O optimization"

prepare_case "testability-enabled"
plutil -replace FearlessEnableTestability -string YES "$APP_DIR/Info.plist"
CASE_ARGS+=(--dry-run)
expect_failure "testability enabled" "built with testability enabled"

prepare_case "missing-managed-class"
CASE_ENV=("FAKE_MISSING_MANAGED_CLASS=CDChain")
CASE_ARGS+=(--dry-run)
expect_failure "missing managed-object runtime class" "missing a required managed-object runtime class"

prepare_case "missing-migration-resource"
rm "$APP_DIR/SubstrateV3toV4.cdm"
CASE_ARGS+=(--dry-run)
expect_failure "missing migration resource" "missing or symlinking a required Core Data migration resource"

prepare_case "shutdown-simulator"
CASE_ENV=("FAKE_SIMULATOR_STATE=Shutdown")
CASE_ARGS+=(--dry-run)
expect_failure "shutdown simulator" "must already be Booted"

prepare_case "unavailable-simulator"
CASE_ENV=("FAKE_SIMULATOR_AVAILABLE=false")
CASE_ARGS+=(--dry-run)
expect_failure "unavailable simulator" "Simulator is unavailable"

prepare_case "non-iphone-simulator"
CASE_ENV=("FAKE_SIMULATOR_NAME=iPad Pro")
CASE_ARGS+=(--dry-run)
expect_failure "non-iPhone simulator" "must be an iPhone"

prepare_case "extra-fixture-file"
printf '%s\n' "unexpected" >"$FIXTURE_DIR/notes.txt"
CASE_ARGS+=(--dry-run)
expect_failure "extra fixture file" "exactly the nine expected"

prepare_case "symlink-fixture-component"
mv "$FIXTURE_DIR/UserDataModel.sqlite-wal" "$CASE_DIR/real-wal"
ln -s "$CASE_DIR/real-wal" "$FIXTURE_DIR/UserDataModel.sqlite-wal"
CASE_ARGS+=(--dry-run)
expect_failure "symlink fixture component" "regular non-symlink"

prepare_case "overlapping-artifacts"
ARTIFACTS_DIR="$FIXTURE_DIR/artifacts"
CASE_ARGS=(
  --simulator-udid "$SIMULATOR_UDID"
  --app "$APP_DIR"
  --bundle-id "$BUNDLE_ID"
  --fixture-dir "$FIXTURE_DIR"
  --artifacts-dir "$ARTIFACTS_DIR"
  --crash-report-dir "$CRASH_DIR"
  --confirm-disposable-fixture
  --dry-run
)
expect_failure "overlapping artifacts" "must not overlap"
[[ ! -e "$ARTIFACTS_DIR" ]] ||
  fail "overlap rejection wrote into the source fixture"

prepare_case "already-installed"
: >"$INSTALL_STATE"
expect_failure "already installed" "already has Simulator data"
assert_command_count "simctl install $SIMULATOR_UDID $APP_DIR" "0"

prepare_case "source-mutated"
CASE_ENV=("FAKE_MUTATE_FIXTURE=1")
expect_failure "source mutation" "source fixture changed before Simulator injection"

prepare_case "dead-process"
CASE_ENV=("FAKE_PROCESS_CHECK_FAIL=1")
expect_failure "dead process" "did not remain alive"

prepare_case "missing-startup-ready"
CASE_ENV=("FAKE_LOG_CONTENT=ordinary application log")
expect_failure "missing startup-ready marker" "startup readiness failed"

prepare_case "startup-failure-marker"
CASE_ENV=("FAKE_LOG_CONTENT=FEARLESS_STARTUP_FAILED")
expect_failure "startup-failure marker" "startup readiness failed"

prepare_case "duplicate-startup-ready"
CASE_ENV=("FAKE_LOG_CONTENT=FEARLESS_STARTUP_READY FEARLESS_STARTUP_READY")
expect_failure "duplicate startup-ready marker" "startup readiness failed"

prepare_case "fatal-coredata-log"
CASE_ENV=("FAKE_LOG_CONTENT=CoreData persistent store migration failed with an incompatible model")
expect_failure "fatal Core Data log" "fatal migration/Core Data marker"

prepare_case "wallet-key-mutated"
CASE_ENV=("FAKE_MUTATE_USER_KEY=1")
expect_failure "wallet key mutation" "changed protected wallet identities, keys, or relationships"

prepare_case "wallet-relationship-mutated"
CASE_ENV=("FAKE_MUTATE_USER_RELATIONSHIP=1")
expect_failure "wallet relationship mutation" "changed protected wallet identities, keys, or relationships"

prepare_case "substrate-nonzero-row-loss"
CASE_ENV=("FAKE_DROP_ONE_SUBSTRATE_ROW=1")
expect_failure "nonzero Substrate row loss" "changed the protected ZCDCHAIN row count"

prepare_case "matching-crash-report"
CASE_ENV=("FAKE_CREATE_CRASH=1")
expect_failure "matching crash report" "new crash report matched"

prepare_case "matching-crash-without-device-id"
CASE_ENV=("FAKE_CREATE_CRASH_WITHOUT_DEVICE=1")
expect_failure "matching crash report without device ID" "new crash report matched"

printf '%s\n' \
  "[coredata-simulator-rehearsal-test] PASS: 2 positive + 30 negative/adversarial contracts"
