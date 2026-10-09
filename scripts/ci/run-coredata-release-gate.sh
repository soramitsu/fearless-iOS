#!/usr/bin/env bash
set -euo pipefail

# Runs the migration/startup Core Data unit-test gate with Release optimization.
#
# The normal stage deliberately excludes the two copied-phone fixture tests. Run
# those separately with:
#
#   FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE=/absolute/path/to/SubstrateDataModel.sqlite \
#     bash scripts/ci/run-coredata-release-gate.sh --stage copied-phone \
#       --simulator-udid <SIMULATOR_UDID>
#
# This script never accepts a physical-device destination, never opens the source
# fixture itself, and keeps xcodebuild output in a private local log.

umask 077

readonly LOG_PREFIX="[coredata-release-gate]"
readonly SCHEME="fearless.tests"
readonly UUID_PATTERN='^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
readonly SIMULATOR_DESTINATION_PATTERN='^platform=iOS Simulator,id=([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})(,arch=(arm64|x86_64))?$'
SIMULATOR_INVENTORY_FILE=""

log() {
  printf '%s %s\n' "$LOG_PREFIX" "$*"
}

fail() {
  printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${SIMULATOR_INVENTORY_FILE:-}" && -e "$SIMULATOR_INVENTORY_FILE" ]]; then
    rm "$SIMULATOR_INVENTORY_FILE"
  fi
}

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/ci/run-coredata-release-gate.sh [options]

Options:
  --stage core|copied-phone|all
      Run the hermetic class gate (default), the two copied-phone tests, or both.
  --simulator-udid UUID
      Use an available iPhone simulator. If omitted, exactly one booted,
      available iPhone simulator must be discoverable.
  --destination DESTINATION
      Accepted only in the exact form "platform=iOS Simulator,id=UUID", with an
      optional ",arch=arm64" or ",arch=x86_64". Physical/generic destinations
      are refused.
  --fixture ABSOLUTE_SQLITE_PATH
      Source fixture for --stage copied-phone/all. The environment variable
      FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE is also accepted.
  --output-dir DIRECTORY
      New result/log directory. Defaults beneath build/test-results.
  --derived-data DIRECTORY
      DerivedData directory. Defaults beneath build.
  --help

Environment overrides intended for controlled CI/test harnesses:
  FEARLESS_CORE_DATA_ROOT_DIR
  FEARLESS_CORE_DATA_SOURCE_PACKAGES_DIR
  FEARLESS_CORE_DATA_XCODEBUILD_BIN
  FEARLESS_CORE_DATA_XCRUN_BIN
  FEARLESS_CORE_DATA_PYTHON_BIN
  FEARLESS_CORE_DATA_SHASUM_BIN
USAGE
}

require_option_value() {
  local option="$1"
  local remaining="$2"
  [[ "$remaining" -ge 2 ]] || fail "$option requires a value"
}

require_executable() {
  local executable="$1"
  local label="$2"

  if [[ "$executable" == */* ]]; then
    [[ -x "$executable" ]] || fail "$label is not executable"
  else
    command -v "$executable" >/dev/null 2>&1 || fail "$label is unavailable"
  fi
}

canonical_directory() {
  local directory="$1"
  (cd "$directory" && pwd -P)
}

resolve_simulator_from_json() {
  local mode="$1"
  local requested_udid="${2:-}"
  local json_file="$3"

  "$PYTHON_BIN" - "$mode" "$requested_udid" "$json_file" <<'PY'
import json
import re
import sys

mode, requested, json_path = sys.argv[1:]
uuid_pattern = re.compile(
    r"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
)

try:
    with open(json_path, "r", encoding="utf-8") as source:
        payload = json.load(source)
except (OSError, json.JSONDecodeError):
    print("simulator inventory was not valid JSON", file=sys.stderr)
    sys.exit(2)

runtime_devices = payload.get("devices")
if not isinstance(runtime_devices, dict):
    print("simulator inventory did not contain a devices object", file=sys.stderr)
    sys.exit(2)

eligible = []
for devices in runtime_devices.values():
    if not isinstance(devices, list):
        continue
    for device in devices:
        if not isinstance(device, dict):
            continue
        udid = device.get("udid")
        name = device.get("name")
        is_available = device.get("isAvailable", True)
        if (
            isinstance(udid, str)
            and uuid_pattern.fullmatch(udid)
            and isinstance(name, str)
            and name.startswith("iPhone")
            and is_available is True
        ):
            eligible.append(device)

if mode == "explicit":
    matches = [device for device in eligible if device.get("udid", "").lower() == requested.lower()]
    if len(matches) != 1:
        print("requested UDID is not one available iPhone simulator", file=sys.stderr)
        sys.exit(3)
    print(matches[0]["udid"])
    sys.exit(0)

booted = [device for device in eligible if device.get("state") == "Booted"]
if len(booted) == 0:
    print("no booted available iPhone simulator was found; pass --simulator-udid", file=sys.stderr)
    sys.exit(4)
if len(booted) > 1:
    print("multiple booted iPhone simulators were found; pass --simulator-udid", file=sys.stderr)
    sys.exit(5)

print(booted[0]["udid"])
PY
}

fixture_fingerprint() {
  local fixture="$1"
  local suffix
  local candidate
  local digest

  for suffix in "" "-wal" "-shm"; do
    candidate="${fixture}${suffix}"
    if [[ -e "$candidate" ]]; then
      [[ -f "$candidate" && ! -L "$candidate" ]] ||
        fail "copied-phone fixture components must be regular, non-symlink files"
      digest="$("$SHASUM_BIN" -a 256 "$candidate" | awk '{print $1}')"
      [[ "$digest" =~ ^[0-9A-Fa-f]{64}$ ]] ||
        fail "unable to fingerprint copied-phone fixture safely"
      printf '%s=%s\n' "$suffix" "$digest"
    else
      printf '%s=%s\n' "$suffix" "absent"
    fi
  done
}

validate_result_summary() {
  local result_bundle="$1"
  local expected_total="$2"
  local summary_file="$3"

  [[ -d "$result_bundle" && -f "$result_bundle/Info.plist" ]] ||
    fail "xcodebuild succeeded without a complete xcresult bundle"

  if ! "$XCRUN_BIN" xcresulttool get test-results summary \
    --path "$result_bundle" --compact >"$summary_file" 2>/dev/null; then
    fail "xcresulttool could not read the test summary"
  fi

  if ! "$PYTHON_BIN" - "$summary_file" "$expected_total" "$SIMULATOR_UDID" <<'PY'
import json
import sys

summary_path, expected_total_text, expected_device_id = sys.argv[1:]

def reject(message):
    print(f"invalid xcresult summary: {message}", file=sys.stderr)
    raise SystemExit(1)

try:
    with open(summary_path, "r", encoding="utf-8") as source:
        summary = json.load(source)
except (OSError, json.JSONDecodeError):
    reject("malformed or missing JSON")

if not isinstance(summary, dict):
    reject("root is not an object")

def count(container, key):
    value = container.get(key)
    if type(value) is not int or value < 0:
        reject(f"{key} is missing or is not a nonnegative integer")
    return value

if summary.get("result") != "Passed":
    reject("result is not Passed")

total = count(summary, "totalTestCount")
passed = count(summary, "passedTests")
failed = count(summary, "failedTests")
skipped = count(summary, "skippedTests")
expected = count(summary, "expectedFailures")

if total <= 0:
    reject("no tests executed")
if failed != 0:
    reject("failedTests is not zero")
if skipped != 0:
    reject("skippedTests is not zero")
if expected != 0:
    reject("expectedFailures is not zero")
if passed != total:
    reject("passedTests does not equal totalTestCount")

failures = summary.get("testFailures")
if not isinstance(failures, list) or failures:
    reject("testFailures is missing or nonempty")

configurations = summary.get("devicesAndConfigurations")
if not isinstance(configurations, list) or not configurations:
    reject("devicesAndConfigurations is missing or empty")

configuration_passed = 0
configuration_failed = 0
configuration_skipped = 0
configuration_expected = 0
for configuration in configurations:
    if not isinstance(configuration, dict):
        reject("configuration entry is not an object")
    device = configuration.get("device")
    if not isinstance(device, dict):
        reject("configuration device is missing")
    if device.get("platform") != "iOS Simulator":
        reject("a test destination was not iOS Simulator")
    device_id = device.get("deviceId")
    if not isinstance(device_id, str) or device_id.lower() != expected_device_id.lower():
        reject("test destination does not match the selected simulator")
    configuration_passed += count(configuration, "passedTests")
    configuration_failed += count(configuration, "failedTests")
    configuration_skipped += count(configuration, "skippedTests")
    configuration_expected += count(configuration, "expectedFailures")

if configuration_passed != passed:
    reject("configuration passed count disagrees with summary")
if configuration_failed != failed:
    reject("configuration failed count disagrees with summary")
if configuration_skipped != skipped:
    reject("configuration skipped count disagrees with summary")
if configuration_expected != expected:
    reject("configuration expected-failure count disagrees with summary")

if expected_total_text != "any":
    try:
        required_total = int(expected_total_text)
    except ValueError:
        reject("internal expected total is invalid")
    if total != required_total:
        reject(f"expected exactly {required_total} tests, found {total}")
PY
  then
    fail "test result did not satisfy the zero-failure/zero-skip Release contract"
  fi
}

run_stage() {
  local stage="$1"
  local result_name
  local expected_total
  local fixture_before=""
  local fixture_after=""
  local xcodebuild_status
  local -a selectors

  if [[ "$stage" == "core" ]]; then
    result_name="core"
    # The selected source cohort contains 409 test methods. Two copied-phone
    # fixtures are intentionally handled by the separate device/store stage,
    # so the simulator core stage must execute exactly 407 tests.
    expected_total="407"
    selectors=(
      "-only-testing:fearlessTests/SingleToMultiassetUserMigrationTests"
      "-only-testing:fearlessTests/UserStorageCompatibilityMigrationTests"
      "-only-testing:fearlessTests/SubstrateStorageClassResolutionTests"
      "-only-testing:fearlessTests/SubstrateStorageMigrationSafetyTests"
      "-only-testing:fearlessTests/TransformableArchiveSafetyTests"
      "-only-testing:fearlessTests/MetaAccountMapperTests"
      "-only-testing:fearlessTests/SelectedAccountSettingsTests"
      "-only-testing:fearlessTests/RootTests"
      "-only-testing:fearlessTests/ChainModelMapperTests"
      "-only-testing:fearlessTests/ChainSyncServiceCompatibilityTests"
      "-only-testing:fearlessTests/ChainRegistryTests"
      "-only-testing:fearlessTests/ConnectionPoolTests"
      "-only-testing:fearlessTests/CrashConsistentStoreReplacerResourceLimitTests"
      "-skip-testing:fearlessTests/SubstrateStorageClassResolutionTests/testCopiedPhoneV8Store_whenAvailable_thenAllRowsHaveExpectedClassesAndStoreIsUnchanged"
      "-skip-testing:fearlessTests/SubstrateStorageClassResolutionTests/testCopiedPhoneV8Store_whenFetchedThroughProductionRepositories_thenMapsEveryRuntimeAndChain"
    )
  else
    result_name="copied-phone"
    expected_total="2"
    selectors=(
      "-only-testing:fearlessTests/SubstrateStorageClassResolutionTests/testCopiedPhoneV8Store_whenAvailable_thenAllRowsHaveExpectedClassesAndStoreIsUnchanged"
      "-only-testing:fearlessTests/SubstrateStorageClassResolutionTests/testCopiedPhoneV8Store_whenFetchedThroughProductionRepositories_thenMapsEveryRuntimeAndChain"
    )
    fixture_before="$(fixture_fingerprint "$PHONE_FIXTURE")"
  fi

  local result_bundle="$OUTPUT_DIR/${result_name}.xcresult"
  local xcodebuild_log="$OUTPUT_DIR/${result_name}.xcodebuild.log"
  local summary_file="$OUTPUT_DIR/${result_name}.summary.json"
  [[ ! -e "$result_bundle" ]] ||
    fail "refusing to overwrite an existing xcresult bundle"

  local -a xcodebuild_arguments=(
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -configuration Release
    -destination "$SIMULATOR_DESTINATION"
    -derivedDataPath "$DERIVED_DATA_DIR"
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR"
    -disableAutomaticPackageResolution
    -skipPackageUpdates
    -parallel-testing-enabled NO
    -maximum-parallel-testing-workers 1
    -resultBundlePath "$result_bundle"
    "SWIFT_OPTIMIZATION_LEVEL=-O"
    "ENABLE_TESTABILITY=YES"
    "ONLY_ACTIVE_ARCH=YES"
    "${selectors[@]}"
    test
  )

  log "Running ${stage} Release test stage; detailed output is private in the gate log"
  set +e
  if [[ "$stage" == "core" ]]; then
    env -u FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE \
      "$XCODEBUILD_BIN" "${xcodebuild_arguments[@]}" >"$xcodebuild_log" 2>&1
    xcodebuild_status=$?
  else
    FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE="$PHONE_FIXTURE" \
      "$XCODEBUILD_BIN" "${xcodebuild_arguments[@]}" >"$xcodebuild_log" 2>&1
    xcodebuild_status=$?
  fi
  set -e

  if [[ "$stage" == "copied-phone" ]]; then
    fixture_after="$(fixture_fingerprint "$PHONE_FIXTURE")"
    [[ "$fixture_after" == "$fixture_before" ]] ||
      fail "copied-phone source fixture changed during the test stage"
  fi

  [[ "$xcodebuild_status" -eq 0 ]] ||
    fail "xcodebuild failed for the ${stage} stage; inspect the private gate log"

  validate_result_summary "$result_bundle" "$expected_total" "$summary_file"
  if [[ "$stage" == "copied-phone" ]]; then
    log "PASSED copied-phone fixture stage: exactly 2 tests, source fixture unchanged"
  else
    log "PASSED core stage: exactly 407 Release -O tests, zero failures, skips, or expected failures"
  fi
}

main() {
  local stage="core"
  local requested_udid="${FEARLESS_CORE_DATA_SIMULATOR_UDID:-}"
  local requested_destination=""
  local fixture_argument=""
  local output_argument=""
  local derived_data_argument=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --stage)
        require_option_value "$1" "$#"
        stage="$2"
        shift 2
        ;;
      --simulator-udid)
        require_option_value "$1" "$#"
        requested_udid="$2"
        shift 2
        ;;
      --destination)
        require_option_value "$1" "$#"
        requested_destination="$2"
        shift 2
        ;;
      --fixture)
        require_option_value "$1" "$#"
        fixture_argument="$2"
        shift 2
        ;;
      --output-dir)
        require_option_value "$1" "$#"
        output_argument="$2"
        shift 2
        ;;
      --derived-data)
        require_option_value "$1" "$#"
        derived_data_argument="$2"
        shift 2
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

  case "$stage" in
    core|copied-phone|all) ;;
    *) fail "--stage must be core, copied-phone, or all" ;;
  esac

  if [[ -n "$requested_udid" && -n "$requested_destination" ]]; then
    fail "pass either --simulator-udid or --destination, not both"
  fi

  if [[ -n "$requested_destination" ]]; then
    if [[ "$requested_destination" =~ $SIMULATOR_DESTINATION_PATTERN ]]; then
      requested_udid="${BASH_REMATCH[1]}"
    else
      fail "refusing physical, generic, named, or otherwise non-canonical simulator destination"
    fi
  fi

  if [[ -n "$requested_udid" && ! "$requested_udid" =~ $UUID_PATTERN ]]; then
    fail "simulator UDID must be a canonical UUID"
  fi

  readonly ROOT_DIR="$(
    cd "${FEARLESS_CORE_DATA_ROOT_DIR:-$(dirname "${BASH_SOURCE[0]}")/../..}" &&
      pwd -P
  )"
  readonly WORKSPACE_INPUT="${FEARLESS_CORE_DATA_WORKSPACE:-$ROOT_DIR/fearless.xcworkspace}"
  [[ -d "$WORKSPACE_INPUT" && -f "$WORKSPACE_INPUT/contents.xcworkspacedata" ]] ||
    fail "fearless.xcworkspace is missing or incomplete"
  [[ "$(basename "$WORKSPACE_INPUT")" == "fearless.xcworkspace" ]] ||
    fail "the Core Data gate requires fearless.xcworkspace"
  readonly WORKSPACE="$(canonical_directory "$WORKSPACE_INPUT")"

  readonly SOURCE_PACKAGES_INPUT="${FEARLESS_CORE_DATA_SOURCE_PACKAGES_DIR:-$ROOT_DIR/SourcePackages}"
  [[ -d "$SOURCE_PACKAGES_INPUT" && -d "$SOURCE_PACKAGES_INPUT/checkouts" ]] ||
    fail "prepared canonical SourcePackages/checkouts is required"
  readonly SOURCE_PACKAGES_DIR="$(canonical_directory "$SOURCE_PACKAGES_INPUT")"

  readonly XCODEBUILD_BIN="${FEARLESS_CORE_DATA_XCODEBUILD_BIN:-xcodebuild}"
  readonly XCRUN_BIN="${FEARLESS_CORE_DATA_XCRUN_BIN:-xcrun}"
  readonly PYTHON_BIN="${FEARLESS_CORE_DATA_PYTHON_BIN:-python3}"
  readonly SHASUM_BIN="${FEARLESS_CORE_DATA_SHASUM_BIN:-shasum}"
  require_executable "$XCODEBUILD_BIN" "xcodebuild"
  require_executable "$XCRUN_BIN" "xcrun"
  require_executable "$PYTHON_BIN" "python3"
  if [[ "$stage" == "copied-phone" || "$stage" == "all" ]]; then
    require_executable "$SHASUM_BIN" "shasum"
  fi

  SIMULATOR_INVENTORY_FILE="$(
    mktemp "${TMPDIR:-/private/tmp}/fearless-coredata-simulators.XXXXXX"
  )"
  trap cleanup EXIT

  if [[ -n "$requested_udid" ]]; then
    if ! "$XCRUN_BIN" simctl list devices available -j \
      >"$SIMULATOR_INVENTORY_FILE" 2>/dev/null; then
      fail "unable to query available iOS simulators"
    fi
    if ! SIMULATOR_UDID="$(
      resolve_simulator_from_json "explicit" "$requested_udid" "$SIMULATOR_INVENTORY_FILE"
    )"; then
      fail "the requested simulator could not be verified"
    fi
  else
    if ! "$XCRUN_BIN" simctl list devices booted -j \
      >"$SIMULATOR_INVENTORY_FILE" 2>/dev/null; then
      fail "unable to query booted iOS simulators"
    fi
    if ! SIMULATOR_UDID="$(
      resolve_simulator_from_json "automatic" "" "$SIMULATOR_INVENTORY_FILE"
    )"; then
      fail "a unique booted simulator is required"
    fi
  fi
  readonly SIMULATOR_UDID
  readonly SIMULATOR_DESTINATION="platform=iOS Simulator,id=${SIMULATOR_UDID}"

  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  readonly OUTPUT_DIR_INPUT="${output_argument:-$ROOT_DIR/build/test-results/CoreDataReleaseGate-$timestamp}"
  [[ ! -e "$OUTPUT_DIR_INPUT" ]] ||
    fail "output directory must not already exist"
  mkdir -p "$OUTPUT_DIR_INPUT"
  readonly OUTPUT_DIR="$(canonical_directory "$OUTPUT_DIR_INPUT")"

  readonly DERIVED_DATA_DIR="${derived_data_argument:-$ROOT_DIR/build/DerivedData-CoreDataReleaseGate}"

  readonly PHONE_FIXTURE="${fixture_argument:-${FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE:-}}"
  if [[ "$stage" == "copied-phone" || "$stage" == "all" ]]; then
    [[ -n "$PHONE_FIXTURE" ]] ||
      fail "copied-phone stage requires --fixture or FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE"
    [[ "$PHONE_FIXTURE" == /* ]] ||
      fail "copied-phone fixture path must be absolute"
    [[ -r "$PHONE_FIXTURE" && -f "$PHONE_FIXTURE" && ! -L "$PHONE_FIXTURE" ]] ||
      fail "copied-phone fixture must be a readable, regular, non-symlink file"
  fi

  log "Using fearless.xcworkspace, scheme fearless.tests, Release optimization -O"
  if [[ "$stage" == "core" || "$stage" == "all" ]]; then
    run_stage "core"
  fi
  if [[ "$stage" == "copied-phone" || "$stage" == "all" ]]; then
    run_stage "copied-phone"
  fi
  log "PASSED requested Core Data Release gate"
}

main "$@"
