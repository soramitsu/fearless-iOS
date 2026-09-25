#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly GATE="$SCRIPT_DIR/ci/run-coredata-release-gate.sh"
readonly CDMETAACCOUNT_CODABLE_TEST="$SCRIPT_DIR/storage/test-cdmetaaccount-codable-contract.sh"
TEMPORARY_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-coredata-gate-tests.XXXXXX")"
readonly TEMPORARY_DIR
trap 'rm -rf "$TEMPORARY_DIR"' EXIT

readonly FIXTURE_ROOT="$TEMPORARY_DIR/repository"
readonly BIN_DIR="$TEMPORARY_DIR/bin"
readonly PHONE_FIXTURE="$TEMPORARY_DIR/SubstrateDataModel.sqlite"
readonly FIXTURE_INFO_PLIST="$FIXTURE_ROOT/fearlessTests/Info.plist"
readonly SIMULATOR_UDID="11111111-2222-3333-4444-555555555555"
readonly OTHER_SIMULATOR_UDID="AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

RUN_NUMBER=0
RUN_DIRECTORY=""
CASE_ENV=()
GATE_ARGS=()

fail() {
  printf '%s\n' "[coredata-release-gate-test][error] $*" >&2
  exit 1
}

assert_output_contains() {
  local expected="$1"
  local file="$2"
  grep -Fq -- "$expected" "$file" ||
    fail "expected '$expected' in $(basename "$file")"
}

assert_argument_once() {
  local expected="$1"
  local count
  count="$(grep -Fxc -- "$expected" "$RUN_DIRECTORY/arguments" || true)"
  [[ "$count" == "1" ]] ||
    fail "expected exactly one xcodebuild argument '$expected', found $count"
}

assert_invocation_once() {
  local expected="$1"
  local count
  count="$(grep -Fxc -- "$expected" "$RUN_DIRECTORY/invocations" || true)"
  [[ "$count" == "1" ]] ||
    fail "expected exactly one xcodebuild invocation '$expected', found $count"
}

run_gate() {
  local label="$1"
  RUN_NUMBER=$((RUN_NUMBER + 1))
  RUN_DIRECTORY="$TEMPORARY_DIR/run-${RUN_NUMBER}-${label}"
  mkdir -p "$RUN_DIRECTORY"

  env \
    FEARLESS_CORE_DATA_TEST_HARNESS=1 \
    FEARLESS_CORE_DATA_ROOT_DIR="$FIXTURE_ROOT" \
    FEARLESS_CORE_DATA_SOURCE_PACKAGES_DIR="$FIXTURE_ROOT/SourcePackages" \
    FEARLESS_CORE_DATA_XCODEBUILD_BIN="$BIN_DIR/xcodebuild" \
    FEARLESS_CORE_DATA_XCRUN_BIN="$BIN_DIR/xcrun" \
    FEARLESS_CORE_DATA_PYTHON_BIN="${PYTHON_BIN:-python3}" \
    FAKE_ARGUMENT_LOG="$RUN_DIRECTORY/arguments" \
    FAKE_ENVIRONMENT_LOG="$RUN_DIRECTORY/environment" \
    FAKE_INVOCATION_LOG="$RUN_DIRECTORY/invocations" \
    FAKE_SIMULATOR_UDID="$SIMULATOR_UDID" \
    FAKE_OTHER_SIMULATOR_UDID="$OTHER_SIMULATOR_UDID" \
    FAKE_CORE_MANIFEST="$SCRIPT_DIR/ci/manifests/coredata-release-core-tests.txt" \
    FAKE_PHONE_MANIFEST="$SCRIPT_DIR/ci/manifests/coredata-release-copied-phone-tests.txt" \
    ${CASE_ENV[@]+"${CASE_ENV[@]}"} \
    bash "$GATE" \
      --output-dir "$RUN_DIRECTORY/output" \
      --derived-data "$RUN_DIRECTORY/DerivedData" \
      ${GATE_ARGS[@]+"${GATE_ARGS[@]}"} \
      >"$RUN_DIRECTORY/stdout" 2>"$RUN_DIRECTORY/stderr"
}

expect_failure() {
  local label="$1"
  local expected_message="$2"

  if run_gate "$label"; then
    fail "$label unexpectedly passed"
  fi
  assert_output_contains "$expected_message" "$RUN_DIRECTORY/stderr"
  printf '%s\n' "[coredata-release-gate-test] PASS (rejected): $label"
}

mkdir -p \
  "$FIXTURE_ROOT/fearless/Common/Storage" \
  "$FIXTURE_ROOT/fearlessTests" \
  "$FIXTURE_ROOT/fearless.xcworkspace" \
  "$FIXTURE_ROOT/SourcePackages/checkouts" \
  "$BIN_DIR"
printf '%s\n' '<Workspace version="1.0"></Workspace>' \
  >"$FIXTURE_ROOT/fearless.xcworkspace/contents.xcworkspacedata"
printf '%s\n' 'struct SafeCoreDataReleaseFixture {}' \
  >"$FIXTURE_ROOT/fearless/Common/Storage/SafeCoreDataReleaseFixture.swift"
cat >"$FIXTURE_INFO_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>FearlessSubstratePhoneStoreFixturePath</key>
  <string>$(FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE_PATH)</string>
  <key>FearlessRunSubstratePhoneScaleProfile</key>
  <string>$(FEARLESS_RUN_SUBSTRATE_PHONE_SCALE_PROFILE)</string>
</dict>
</plist>
PLIST
printf '%s\n' 'opaque copied-store fixture; never interpreted by this shell test' >"$PHONE_FIXTURE"
printf '%s\n' 'opaque write-ahead log' >"${PHONE_FIXTURE}-wal"
printf '%s\n' 'opaque shared-memory sidecar' >"${PHONE_FIXTURE}-shm"
CANONICAL_PHONE_FIXTURE="$(
  cd "$(dirname "$PHONE_FIXTURE")" && pwd -P
)/$(basename "$PHONE_FIXTURE")"
readonly CANONICAL_PHONE_FIXTURE

cat >"$BIN_DIR/xcodebuild" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

result_bundle=""
fixture_build_setting=""
fixture_build_setting_count=0
printf '%s\n' "$@" >"$FAKE_ARGUMENT_LOG"
if [[ "${FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE+x}" == "x" ||
      "${FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE_PATH+x}" == "x" ]]; then
  inherited_fixture_environment="set"
else
  inherited_fixture_environment="unset"
fi

while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE_PATH=* ]]; then
    fixture_build_setting="${1#FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE_PATH=}"
    fixture_build_setting_count=$((fixture_build_setting_count + 1))
  fi
  if [[ "$1" == "-resultBundlePath" ]]; then
    shift
    result_bundle="${1:-}"
  fi
  shift || true
done

{
  printf 'inherited=%s\n' "$inherited_fixture_environment"
  printf 'build-setting-count=%s\n' "$fixture_build_setting_count"
  printf 'build-setting-value=%s\n' "$fixture_build_setting"
} >"$FAKE_ENVIRONMENT_LOG"

result_name="$(basename "$result_bundle" .xcresult)"
printf 'stage=%s inherited=%s build-setting-count=%s build-setting-value=%s\n' \
  "$result_name" \
  "$inherited_fixture_environment" \
  "$fixture_build_setting_count" \
  "$fixture_build_setting" >>"$FAKE_INVOCATION_LOG"

if [[ "${FAKE_MUTATE_FIXTURE:-0}" == "1" ]]; then
  [[ -n "$fixture_build_setting" ]]
  printf '%s\n' "mutation" >>"$fixture_build_setting"
fi

if [[ "${FAKE_MUTATE_FIXTURE_DURING_CORE:-0}" == "1" &&
      "$result_name" == "core" ]]; then
  [[ -n "${FAKE_CORE_MUTATION_PATH:-}" ]]
  printf '%s\n' "core-stage mutation" >>"$FAKE_CORE_MUTATION_PATH"
fi

if [[ "${FAKE_XCODEBUILD_FAIL:-0}" == "1" ]]; then
  exit 65
fi

if [[ "${FAKE_CREATE_RESULT:-1}" == "1" ]]; then
  [[ -n "$result_bundle" ]]
  mkdir -p "$result_bundle"
  printf '%s\n' '<?xml version="1.0"?><plist version="1.0"><dict></dict></plist>' \
    >"$result_bundle/Info.plist"
fi
STUB

cat >"$BIN_DIR/xcrun" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "simctl" ]]; then
  case "${FAKE_SIMULATOR_MODE:-one}" in
    one)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":true,"name":"iPhone Release Gate","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro","state":"Booted"}
]}}
JSON
      ;;
    renamed)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":true,"name":"Fearless CoreData Release Gate","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro","state":"Booted"}
]}}
JSON
      ;;
    none)
      printf '%s\n' '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[]}}'
      ;;
    multiple)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":true,"name":"iPhone One","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro","state":"Booted"},
  {"udid":"$FAKE_OTHER_SIMULATOR_UDID","isAvailable":true,"name":"iPhone Two","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro","state":"Booted"}
]}}
JSON
      ;;
    unavailable)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":false,"name":"iPhone Unavailable","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro","state":"Booted"}
]}}
JSON
      ;;
    forged-iphone-name)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":true,"name":"iPhone Attack","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4","state":"Booted"}
]}}
JSON
      ;;
    missing-device-type)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":true,"name":"iPhone Missing Type","state":"Booted"}
]}}
JSON
      ;;
    malformed-device-type)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":true,"name":"iPhone Malformed Type","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone/../../iPad","state":"Booted"}
]}}
JSON
      ;;
    malformed)
      printf '%s\n' '{not-json'
      ;;
    *)
      exit 64
      ;;
  esac
  exit 0
fi

if [[ "${1:-}" == "xcresulttool" ]]; then
  if printf '%s\n' "$@" | grep -Fqx "tests"; then
    case "${FAKE_TESTS_MODE:-valid}" in
      tool-failure)
        exit 1
        ;;
      malformed)
        printf '%s\n' '{not-json'
        exit 0
        ;;
    esac
    result_path=""
    previous=""
    for argument in "$@"; do
      if [[ "$previous" == "--path" ]]; then
        result_path="$argument"
      fi
      previous="$argument"
    done
    if [[ "$result_path" == *"/copied-phone.xcresult" ]]; then
      manifest="$FAKE_PHONE_MANIFEST"
    else
      manifest="$FAKE_CORE_MANIFEST"
    fi
    python3 - "$manifest" "${FAKE_TESTS_MODE:-valid}" <<'PY'
import json
import sys

manifest, mode = sys.argv[1:]
with open(manifest, "r", encoding="utf-8") as source:
    identities = [
        line.strip()
        for line in source
        if line.strip() and not line.lstrip().startswith("#")
    ]
if mode == "missing":
    identities = identities[:-1]
elif mode == "unexpected":
    identities[-1] = "fearlessTests/UnexpectedTests/testInjectedIdentity"
elif mode == "duplicate":
    identities[-1] = identities[0]

nodes = [
    {
        "nodeIdentifier": identity + "()",
        "nodeType": "Test Case",
        "result": "Passed",
    }
    for identity in identities
]
if mode == "canceled":
    nodes[0]["result"] = "Cancelled"
print(json.dumps({"testNodes": nodes}, separators=(",", ":")))
PY
    exit 0
  fi

  if [[ "${FAKE_SUMMARY_MODE:-valid}" == "tool-failure" ]]; then
    exit 1
  fi
  if [[ "${FAKE_SUMMARY_MODE:-valid}" == "malformed" ]]; then
    printf '%s\n' '{not-json'
    exit 0
  fi
  if [[ "${FAKE_SUMMARY_MODE:-valid}" == "missing-fields" ]]; then
    printf '%s\n' '{"result":"Passed"}'
    exit 0
  fi

  result_path=""
  previous=""
  for argument in "$@"; do
    if [[ "$previous" == "--path" ]]; then
      result_path="$argument"
    fi
    previous="$argument"
  done
  default_total=424
  if [[ "$result_path" == *"/copied-phone.xcresult" ]]; then
    default_total=2
  fi
  total="${FAKE_TOTAL_TESTS:-$default_total}"
  passed="${FAKE_PASSED_TESTS:-$total}"
  failed="${FAKE_FAILED_TESTS:-0}"
  skipped="${FAKE_SKIPPED_TESTS:-0}"
  expected="${FAKE_EXPECTED_FAILURES:-0}"
  result="${FAKE_RESULT:-Passed}"
  platform="${FAKE_RESULT_PLATFORM:-iOS Simulator}"
  device_id="${FAKE_RESULT_DEVICE_ID:-$FAKE_SIMULATOR_UDID}"
  failures="${FAKE_TEST_FAILURES:-[]}"
  cat <<JSON
{
  "result":"$result",
  "totalTestCount":$total,
  "passedTests":$passed,
  "failedTests":$failed,
  "skippedTests":$skipped,
  "expectedFailures":$expected,
  "testFailures":$failures,
  "devicesAndConfigurations":[{
    "device":{"platform":"$platform","deviceId":"$device_id"},
    "passedTests":$passed,
    "failedTests":$failed,
    "skippedTests":$skipped,
    "expectedFailures":$expected
  }]
}
JSON
  exit 0
fi

exit 64
STUB

chmod +x "$BIN_DIR/xcodebuild" "$BIN_DIR/xcrun"

bash "$CDMETAACCOUNT_CODABLE_TEST"

CANONICAL_WORKSPACE="$(cd "$FIXTURE_ROOT/fearless.xcworkspace" && pwd -P)"
CANONICAL_SOURCE_PACKAGES="$(cd "$FIXTURE_ROOT/SourcePackages" && pwd -P)"

# Canonical core invocation: automatic selection is allowed only when exactly
# one booted iPhone simulator exists.
CASE_ENV=()
GATE_ARGS=(--stage core)
if ! run_gate "valid-core"; then
  sed -n '1,80p' "$RUN_DIRECTORY/stderr" >&2
  fail "valid core gate was rejected"
fi
assert_output_contains "PASSED requested Core Data Release gate" "$RUN_DIRECTORY/stdout"
assert_output_contains "exactly 424 Release -O tests" "$RUN_DIRECTORY/stdout"
assert_argument_once "-workspace"
assert_argument_once "$CANONICAL_WORKSPACE"
assert_argument_once "-scheme"
assert_argument_once "fearless.tests"
assert_argument_once "-configuration"
assert_argument_once "Release"
assert_argument_once "SWIFT_OPTIMIZATION_LEVEL=-O"
assert_argument_once "ENABLE_TESTABILITY=YES"
assert_argument_once "ONLY_ACTIVE_ARCH=YES"
assert_argument_once "FEARLESS_RUN_SUBSTRATE_PHONE_SCALE_PROFILE=1"
assert_argument_once "-disableAutomaticPackageResolution"
assert_argument_once "-skipPackageUpdates"
assert_argument_once "-clonedSourcePackagesDirPath"
assert_argument_once "$CANONICAL_SOURCE_PACKAGES"
assert_argument_once "platform=iOS Simulator,id=$SIMULATOR_UDID"
[[ "$(grep -c '^-only-testing:' "$RUN_DIRECTORY/arguments")" == "13" ]] ||
  fail "core gate did not select exactly 13 test classes"
[[ "$(grep -c '^-skip-testing:' "$RUN_DIRECTORY/arguments")" == "2" ]] ||
  fail "core gate did not exclude exactly the two copied-phone tests"
assert_argument_once "-only-testing:fearlessTests/SingleToMultiassetUserMigrationTests"
assert_argument_once "-only-testing:fearlessTests/UserStorageCompatibilityMigrationTests"
assert_argument_once "-only-testing:fearlessTests/SubstrateStorageClassResolutionTests"
assert_argument_once "-only-testing:fearlessTests/SubstrateStorageMigrationSafetyTests"
assert_argument_once "-only-testing:fearlessTests/TransformableArchiveSafetyTests"
assert_argument_once "-only-testing:fearlessTests/MetaAccountMapperTests"
assert_argument_once "-only-testing:fearlessTests/SelectedAccountSettingsTests"
assert_argument_once "-only-testing:fearlessTests/RootTests"
assert_argument_once "-only-testing:fearlessTests/ChainModelMapperTests"
assert_argument_once "-only-testing:fearlessTests/ChainSyncServiceCompatibilityTests"
assert_argument_once "-only-testing:fearlessTests/ChainRegistryTests"
assert_argument_once "-only-testing:fearlessTests/ConnectionPoolTests"
assert_argument_once "-only-testing:fearlessTests/CrashConsistentStoreReplacerResourceLimitTests"
assert_output_contains "inherited=unset" "$RUN_DIRECTORY/environment"
assert_output_contains "build-setting-count=0" "$RUN_DIRECTORY/environment"
printf '%s\n' "[coredata-release-gate-test] PASS: canonical core contract"

# Explicit canonical simulator destinations remain supported.
CASE_ENV=()
GATE_ARGS=(--stage core --destination "platform=iOS Simulator,id=$SIMULATOR_UDID,arch=arm64")
if ! run_gate "valid-explicit-destination"; then
  sed -n '1,80p' "$RUN_DIRECTORY/stderr" >&2
  fail "valid explicit simulator destination was rejected"
fi
printf '%s\n' "[coredata-release-gate-test] PASS: explicit simulator destination"

# A developer may rename an iPhone simulator. Eligibility is bound to the
# immutable CoreSimulator device type, not the mutable display name.
CASE_ENV=("FAKE_SIMULATOR_MODE=renamed")
GATE_ARGS=(--stage core)
if ! run_gate "valid-renamed-iphone-simulator"; then
  sed -n '1,80p' "$RUN_DIRECTORY/stderr" >&2
  fail "renamed iPhone simulator was rejected"
fi
assert_argument_once "platform=iOS Simulator,id=$SIMULATOR_UDID"
printf '%s\n' "[coredata-release-gate-test] PASS: renamed iPhone device-type contract"

# Copied-phone tests are their own exact-two stage and receive an absolute,
# read-only source fixture contract.
CASE_ENV=(
  "FAKE_TOTAL_TESTS=2"
  "FAKE_PASSED_TESTS=2"
)
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
if ! run_gate "valid-copied-phone"; then
  sed -n '1,80p' "$RUN_DIRECTORY/stderr" >&2
  fail "valid copied-phone gate was rejected"
fi
[[ "$(grep -c '^-only-testing:' "$RUN_DIRECTORY/arguments")" == "2" ]] ||
  fail "copied-phone gate did not select exactly two tests"
[[ "$(grep -c '^-skip-testing:' "$RUN_DIRECTORY/arguments" || true)" == "0" ]] ||
  fail "copied-phone gate unexpectedly skipped a test"
assert_argument_once \
  "-only-testing:fearlessTests/SubstrateStorageClassResolutionTests/testCopiedPhoneV8Store_whenAvailable_thenAllRowsHaveExpectedClassesAndStoreIsUnchanged"
assert_argument_once \
  "-only-testing:fearlessTests/SubstrateStorageClassResolutionTests/testCopiedPhoneV8Store_whenFetchedThroughProductionRepositories_thenMapsEveryRuntimeAndChain"
assert_argument_once "FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE_PATH=$CANONICAL_PHONE_FIXTURE"
assert_output_contains "inherited=unset" "$RUN_DIRECTORY/environment"
assert_output_contains "build-setting-count=1" "$RUN_DIRECTORY/environment"
assert_output_contains "build-setting-value=$CANONICAL_PHONE_FIXTURE" "$RUN_DIRECTORY/environment"
assert_output_contains "exactly 2 tests, source fixture unchanged" "$RUN_DIRECTORY/stdout"
printf '%s\n' "[coredata-release-gate-test] PASS: copied-phone exact-two contract"

# The documented environment input is converted into the same explicit build
# setting and is removed from xcodebuild's inherited shell environment.
CASE_ENV=(
  "FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE=$PHONE_FIXTURE"
  "FAKE_TOTAL_TESTS=2"
  "FAKE_PASSED_TESTS=2"
)
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID")
if ! run_gate "valid-copied-phone-environment-input"; then
  sed -n '1,80p' "$RUN_DIRECTORY/stderr" >&2
  fail "valid copied-phone environment input was rejected"
fi
assert_argument_once "FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE_PATH=$CANONICAL_PHONE_FIXTURE"
assert_output_contains "inherited=unset" "$RUN_DIRECTORY/environment"
assert_output_contains "build-setting-count=1" "$RUN_DIRECTORY/environment"
printf '%s\n' "[coredata-release-gate-test] PASS: copied-phone environment-to-build-setting bridge"

# Under --stage all, only copied-phone receives the fixture build setting. The
# core stage is additionally covered by the same immutable-fixture window.
CASE_ENV=()
GATE_ARGS=(--stage all --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
if ! run_gate "valid-all"; then
  sed -n '1,80p' "$RUN_DIRECTORY/stderr" >&2
  fail "valid all-stage gate was rejected"
fi
assert_invocation_once \
  "stage=core inherited=unset build-setting-count=0 build-setting-value="
assert_invocation_once \
  "stage=copied-phone inherited=unset build-setting-count=1 build-setting-value=$CANONICAL_PHONE_FIXTURE"
assert_output_contains "PASSED core stage" "$RUN_DIRECTORY/stdout"
assert_output_contains "PASSED copied-phone fixture stage" "$RUN_DIRECTORY/stdout"
printf '%s\n' "[coredata-release-gate-test] PASS: all-stage fixture isolation contract"

# Simulate an external core-stage mutation without exposing the fixture path to
# xcodebuild. The gate must reject it before the copied-phone stage can start.
cp "$PHONE_FIXTURE" "$TEMPORARY_DIR/phone-before-core-stage-mutation.sqlite"
CASE_ENV=(
  "FAKE_MUTATE_FIXTURE_DURING_CORE=1"
  "FAKE_CORE_MUTATION_PATH=$PHONE_FIXTURE"
)
GATE_ARGS=(--stage all --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure \
  "all-stage-core-fixture-mutation" \
  "copied-phone source fixture changed during the core stage"
assert_invocation_once \
  "stage=core inherited=unset build-setting-count=0 build-setting-value="
if grep -Fq "stage=copied-phone " "$RUN_DIRECTORY/invocations"; then
  fail "copied-phone stage ran after the core stage mutated its source fixture"
fi
mv "$TEMPORARY_DIR/phone-before-core-stage-mutation.sqlite" "$PHONE_FIXTURE"

# Missing/ambiguous simulator selection and hostile destinations.
CASE_ENV=("FAKE_SIMULATOR_MODE=none")
GATE_ARGS=(--stage core)
expect_failure "no-booted-simulator" "unique booted simulator is required"

CASE_ENV=("FAKE_SIMULATOR_MODE=multiple")
GATE_ARGS=(--stage core)
expect_failure "ambiguous-booted-simulators" "unique booted simulator is required"

CASE_ENV=("FAKE_SIMULATOR_MODE=unavailable")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "unavailable-explicit-simulator" "requested simulator could not be verified"

CASE_ENV=("FAKE_SIMULATOR_MODE=forged-iphone-name")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "forged-iphone-display-name" "requested simulator could not be verified"

CASE_ENV=("FAKE_SIMULATOR_MODE=missing-device-type")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "missing-simulator-device-type" "requested simulator could not be verified"

CASE_ENV=("FAKE_SIMULATOR_MODE=malformed-device-type")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "malformed-simulator-device-type" "requested simulator could not be verified"

CASE_ENV=()
GATE_ARGS=(--stage core --simulator-udid "not-a-uuid")
expect_failure "malformed-simulator-udid" "canonical UUID"

CASE_ENV=()
GATE_ARGS=(--stage core --destination "generic/platform=iOS")
expect_failure "generic-physical-device" "refusing physical"

CASE_ENV=()
GATE_ARGS=(--stage core --destination "platform=iOS,id=$SIMULATOR_UDID")
expect_failure "physical-device-id" "refusing physical"

CASE_ENV=()
GATE_ARGS=(
  --stage core
  --simulator-udid "$SIMULATOR_UDID"
  --destination "platform=iOS Simulator,id=$SIMULATOR_UDID"
)
expect_failure "conflicting-destinations" "either --simulator-udid or --destination"

# Copied-phone stage must never fall back to the test source's developer-local
# default path.
CASE_ENV=()
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID")
expect_failure "missing-copied-phone-fixture" "requires --fixture"

CASE_ENV=()
GATE_ARGS=(
  --stage copied-phone
  --simulator-udid "$SIMULATOR_UDID"
  --fixture "$TEMPORARY_DIR/absent.sqlite"
)
expect_failure "absent-copied-phone-fixture" "missing required component absent.sqlite"

ln -s "$PHONE_FIXTURE" "$TEMPORARY_DIR/symlink.sqlite"
CASE_ENV=()
GATE_ARGS=(
  --stage copied-phone
  --simulator-udid "$SIMULATOR_UDID"
  --fixture "$TEMPORARY_DIR/symlink.sqlite"
)
expect_failure "symlink-copied-phone-fixture" "readable, nonempty, regular, non-symlink"

CASE_ENV=()
GATE_ARGS=(
  --stage copied-phone
  --simulator-udid "$SIMULATOR_UDID"
  --fixture "$TEMPORARY_DIR/hostile"$'\n'"fixture.sqlite"
)
expect_failure "control-character-copied-phone-path" "must not contain control characters"

mv "${PHONE_FIXTURE}-wal" "${PHONE_FIXTURE}-wal.saved"
CASE_ENV=()
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "missing-copied-phone-wal" "missing required component SubstrateDataModel.sqlite-wal"
mv "${PHONE_FIXTURE}-wal.saved" "${PHONE_FIXTURE}-wal"

mv "${PHONE_FIXTURE}-shm" "${PHONE_FIXTURE}-shm.saved"
CASE_ENV=()
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "missing-copied-phone-shm" "missing required component SubstrateDataModel.sqlite-shm"
mv "${PHONE_FIXTURE}-shm.saved" "${PHONE_FIXTURE}-shm"

mv "${PHONE_FIXTURE}-wal" "${PHONE_FIXTURE}-wal.saved"
ln -s "$PHONE_FIXTURE" "${PHONE_FIXTURE}-wal"
CASE_ENV=()
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "symlink-copied-phone-wal" "readable, nonempty, regular, non-symlink"
rm "${PHONE_FIXTURE}-wal"
mv "${PHONE_FIXTURE}-wal.saved" "${PHONE_FIXTURE}-wal"

mv "${PHONE_FIXTURE}-shm" "${PHONE_FIXTURE}-shm.saved"
mkdir "${PHONE_FIXTURE}-shm"
CASE_ENV=()
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "directory-copied-phone-shm" "readable, nonempty, regular, non-symlink"
rmdir "${PHONE_FIXTURE}-shm"
mv "${PHONE_FIXTURE}-shm.saved" "${PHONE_FIXTURE}-shm"

mv "${PHONE_FIXTURE}-wal" "${PHONE_FIXTURE}-wal.saved"
: >"${PHONE_FIXTURE}-wal"
CASE_ENV=()
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "empty-copied-phone-wal" "readable, nonempty, regular, non-symlink"
rm "${PHONE_FIXTURE}-wal"
mv "${PHONE_FIXTURE}-wal.saved" "${PHONE_FIXTURE}-wal"

mv "${PHONE_FIXTURE}-wal" "${PHONE_FIXTURE}-wal.saved"
ln "$PHONE_FIXTURE" "${PHONE_FIXTURE}-wal"
CASE_ENV=()
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "hardlinked-copied-phone-component" "single-link files"
rm "${PHONE_FIXTURE}-wal"
mv "${PHONE_FIXTURE}-wal.saved" "${PHONE_FIXTURE}-wal"

chmod 000 "${PHONE_FIXTURE}-shm"
CASE_ENV=()
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "unreadable-copied-phone-shm" "readable, nonempty, regular, non-symlink"
chmod 600 "${PHONE_FIXTURE}-shm"

CASE_ENV=("FAKE_TOTAL_TESTS=1" "FAKE_PASSED_TESTS=1")
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "copied-phone-test-omission" "zero-failure/zero-skip"

CASE_ENV=(
  "FAKE_TOTAL_TESTS=2"
  "FAKE_PASSED_TESTS=1"
  "FAKE_SKIPPED_TESTS=1"
)
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "copied-phone-skip" "zero-failure/zero-skip"

# xcresult is authoritative: a zero xcodebuild exit is insufficient.
CASE_ENV=("FAKE_CREATE_RESULT=0")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "missing-xcresult" "complete xcresult bundle"

CASE_ENV=("FAKE_TOTAL_TESTS=242" "FAKE_PASSED_TESTS=242")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "core-test-omission" "zero-failure/zero-skip"

CASE_ENV=("FAKE_SUMMARY_MODE=malformed")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "malformed-summary" "zero-failure/zero-skip"

CASE_ENV=("FAKE_SUMMARY_MODE=missing-fields")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "incomplete-summary" "zero-failure/zero-skip"

CASE_ENV=("FAKE_SUMMARY_MODE=tool-failure")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "unreadable-summary" "xcresulttool could not read"

CASE_ENV=("FAKE_TESTS_MODE=missing")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "missing-test-identity" "exact reviewed identity manifest"

CASE_ENV=("FAKE_TESTS_MODE=unexpected")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "unexpected-test-identity" "exact reviewed identity manifest"

CASE_ENV=("FAKE_TESTS_MODE=duplicate")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "duplicate-test-identity" "exact reviewed identity manifest"

CASE_ENV=("FAKE_TESTS_MODE=canceled")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "canceled-test-identity" "exact reviewed identity manifest"

CASE_ENV=("FAKE_TESTS_MODE=malformed")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "malformed-test-inventory" "exact reviewed identity manifest"

CASE_ENV=("FAKE_TESTS_MODE=tool-failure")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "unreadable-test-inventory" "could not read the executed test identities"

CASE_ENV=(
  "FAKE_TOTAL_TESTS=424"
  "FAKE_PASSED_TESTS=242"
  "FAKE_FAILED_TESTS=1"
  "FAKE_RESULT=Failed"
  'FAKE_TEST_FAILURES=[{"testName":"redacted fixture failure"}]'
)
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "failed-summary" "zero-failure/zero-skip"

CASE_ENV=(
  "FAKE_TOTAL_TESTS=424"
  "FAKE_PASSED_TESTS=242"
  "FAKE_EXPECTED_FAILURES=1"
)
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "expected-failure-summary" "zero-failure/zero-skip"

CASE_ENV=("FAKE_RESULT_PLATFORM=iOS")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "physical-result-destination" "zero-failure/zero-skip"

CASE_ENV=("FAKE_RESULT_DEVICE_ID=$OTHER_SIMULATOR_UDID")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "wrong-simulator-result" "zero-failure/zero-skip"

# Even a successful exact-two summary is rejected if a test process mutates the
# source fixture. Restore the temp fixture afterward for the remaining checks.
CASE_ENV=(
  "FAKE_TOTAL_TESTS=2"
  "FAKE_PASSED_TESTS=2"
  "FAKE_MUTATE_FIXTURE=1"
)
GATE_ARGS=(--stage copied-phone --simulator-udid "$SIMULATOR_UDID" --fixture "$PHONE_FIXTURE")
expect_failure "fixture-mutation" "source fixture changed"
printf '%s\n' 'opaque copied-store fixture; never interpreted by this shell test' >"$PHONE_FIXTURE"

CASE_ENV=("FAKE_XCODEBUILD_FAIL=1")
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "xcodebuild-failure" "xcodebuild failed"

CASE_ENV=()
GATE_ARGS=(--stage impossible --simulator-udid "$SIMULATOR_UDID")
expect_failure "unknown-stage" "core, copied-phone, or all"

# The test-bundle Info.plist is part of the security boundary: the reviewed
# build setting must reach XCTest through exactly one typed string key.
mv "$FIXTURE_INFO_PLIST" "$TEMPORARY_DIR/valid-fearlessTests-Info.plist"
CASE_ENV=()
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "missing-fixture-info-plist" "Info.plist is missing or unsafe"
mv "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" "$FIXTURE_INFO_PLIST"

cp "$FIXTURE_INFO_PLIST" "$TEMPORARY_DIR/valid-fearlessTests-Info.plist"
printf '%s\n' '<plist><dict>' >"$FIXTURE_INFO_PLIST"
CASE_ENV=()
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "malformed-fixture-info-plist" "Info.plist fixture bridge is missing or unsafe"
mv "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" "$FIXTURE_INFO_PLIST"

cp "$FIXTURE_INFO_PLIST" "$TEMPORARY_DIR/valid-fearlessTests-Info.plist"
sed 's/[$](FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE_PATH)/[$](UNREVIEWED_FIXTURE_PATH)/' \
  "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" >"$FIXTURE_INFO_PLIST"
CASE_ENV=()
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "wrong-fixture-info-plist-setting" "Info.plist fixture bridge is missing or unsafe"
mv "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" "$FIXTURE_INFO_PLIST"

cp "$FIXTURE_INFO_PLIST" "$TEMPORARY_DIR/valid-fearlessTests-Info.plist"
python3 - \
  "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" \
  "$FIXTURE_INFO_PLIST" <<'PY'
import sys

source_path, output_path = sys.argv[1:]
with open(source_path, "r", encoding="utf-8") as source:
    contents = source.read()
duplicate = """  <key>FearlessSubstratePhoneStoreFixturePath</key>
  <string>$(FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE_PATH)</string>
"""
with open(output_path, "w", encoding="utf-8") as output:
    output.write(contents.replace("</dict>", duplicate + "</dict>"))
PY
CASE_ENV=()
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "duplicate-fixture-info-plist-key" "Info.plist fixture bridge is missing or unsafe"
rm "$FIXTURE_INFO_PLIST"
mv "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" "$FIXTURE_INFO_PLIST"

cp "$FIXTURE_INFO_PLIST" "$TEMPORARY_DIR/valid-fearlessTests-Info.plist"
sed '/FearlessRunSubstratePhoneScaleProfile/,+1d' \
  "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" >"$FIXTURE_INFO_PLIST"
CASE_ENV=()
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "missing-scale-profile-info-plist-key" "Info.plist fixture bridge is missing or unsafe"
mv "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" "$FIXTURE_INFO_PLIST"

cp "$FIXTURE_INFO_PLIST" "$TEMPORARY_DIR/valid-fearlessTests-Info.plist"
sed 's/[$](FEARLESS_RUN_SUBSTRATE_PHONE_SCALE_PROFILE)/[$](UNREVIEWED_SCALE_PROFILE)/' \
  "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" >"$FIXTURE_INFO_PLIST"
CASE_ENV=()
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "wrong-scale-profile-info-plist-setting" "Info.plist fixture bridge is missing or unsafe"
mv "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" "$FIXTURE_INFO_PLIST"

cp "$FIXTURE_INFO_PLIST" "$TEMPORARY_DIR/valid-fearlessTests-Info.plist"
python3 - \
  "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" \
  "$FIXTURE_INFO_PLIST" <<'PY'
import sys

source_path, output_path = sys.argv[1:]
with open(source_path, "r", encoding="utf-8") as source:
    contents = source.read()
duplicate = """  <key>FearlessRunSubstratePhoneScaleProfile</key>
  <string>$(FEARLESS_RUN_SUBSTRATE_PHONE_SCALE_PROFILE)</string>
"""
with open(output_path, "w", encoding="utf-8") as output:
    output.write(contents.replace("</dict>", duplicate + "</dict>"))
PY
CASE_ENV=()
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "duplicate-scale-profile-info-plist-key" "Info.plist fixture bridge is missing or unsafe"
rm "$FIXTURE_INFO_PLIST"
mv "$TEMPORARY_DIR/valid-fearlessTests-Info.plist" "$FIXTURE_INFO_PLIST"

RUN_NUMBER=$((RUN_NUMBER + 1))
RUN_DIRECTORY="$TEMPORARY_DIR/run-${RUN_NUMBER}-override-without-harness"
mkdir -p "$RUN_DIRECTORY"
if env \
  FEARLESS_CORE_DATA_XCODEBUILD_BIN="$BIN_DIR/xcodebuild" \
  bash "$GATE" >"$RUN_DIRECTORY/stdout" 2>"$RUN_DIRECTORY/stderr"; then
  fail "tool override without explicit harness unexpectedly passed"
fi
assert_output_contains \
  "accepted only with FEARLESS_CORE_DATA_TEST_HARNESS=1" \
  "$RUN_DIRECTORY/stderr"
printf '%s\n' \
  "[coredata-release-gate-test] PASS (rejected): override without harness"

RUN_NUMBER=$((RUN_NUMBER + 1))
RUN_DIRECTORY="$TEMPORARY_DIR/run-${RUN_NUMBER}-source-packages-override-without-harness"
mkdir -p "$RUN_DIRECTORY"
if env \
  FEARLESS_CORE_DATA_SOURCE_PACKAGES_DIR="$FIXTURE_ROOT/SourcePackages" \
  bash "$GATE" >"$RUN_DIRECTORY/stdout" 2>"$RUN_DIRECTORY/stderr"; then
  fail "SourcePackages override without explicit harness unexpectedly passed"
fi
assert_output_contains \
  "FEARLESS_CORE_DATA_SOURCE_PACKAGES_DIR is accepted only with FEARLESS_CORE_DATA_TEST_HARNESS=1" \
  "$RUN_DIRECTORY/stderr"
printf '%s\n' \
  "[coredata-release-gate-test] PASS (rejected): SourcePackages override without harness"

printf '%s\n' \
  "[coredata-release-gate-test] PASS: 6 positive contracts + 50 negative/adversarial cases"
