#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly GATE="$SCRIPT_DIR/ci/run-coredata-release-gate.sh"
readonly TEMPORARY_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-coredata-gate-tests.XXXXXX")"
trap 'rm -rf "$TEMPORARY_DIR"' EXIT

readonly FIXTURE_ROOT="$TEMPORARY_DIR/repository"
readonly BIN_DIR="$TEMPORARY_DIR/bin"
readonly PHONE_FIXTURE="$TEMPORARY_DIR/SubstrateDataModel.sqlite"
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

run_gate() {
  local label="$1"
  RUN_NUMBER=$((RUN_NUMBER + 1))
  RUN_DIRECTORY="$TEMPORARY_DIR/run-${RUN_NUMBER}-${label}"
  mkdir -p "$RUN_DIRECTORY"

  env \
    FEARLESS_CORE_DATA_ROOT_DIR="$FIXTURE_ROOT" \
    FEARLESS_CORE_DATA_XCODEBUILD_BIN="$BIN_DIR/xcodebuild" \
    FEARLESS_CORE_DATA_XCRUN_BIN="$BIN_DIR/xcrun" \
    FEARLESS_CORE_DATA_PYTHON_BIN="${PYTHON_BIN:-python3}" \
    FAKE_ARGUMENT_LOG="$RUN_DIRECTORY/arguments" \
    FAKE_ENVIRONMENT_LOG="$RUN_DIRECTORY/environment" \
    FAKE_SIMULATOR_UDID="$SIMULATOR_UDID" \
    FAKE_OTHER_SIMULATOR_UDID="$OTHER_SIMULATOR_UDID" \
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
  "$FIXTURE_ROOT/fearless.xcworkspace" \
  "$FIXTURE_ROOT/SourcePackages/checkouts" \
  "$BIN_DIR"
printf '%s\n' '<Workspace version="1.0"></Workspace>' \
  >"$FIXTURE_ROOT/fearless.xcworkspace/contents.xcworkspacedata"
printf '%s\n' 'opaque copied-store fixture; never interpreted by this shell test' >"$PHONE_FIXTURE"
printf '%s\n' 'opaque write-ahead log' >"${PHONE_FIXTURE}-wal"
printf '%s\n' 'opaque shared-memory sidecar' >"${PHONE_FIXTURE}-shm"

cat >"$BIN_DIR/xcodebuild" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

result_bundle=""
printf '%s\n' "$@" >"$FAKE_ARGUMENT_LOG"
if [[ "${FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE+x}" == "x" ]]; then
  printf '%s\n' "set" >"$FAKE_ENVIRONMENT_LOG"
else
  printf '%s\n' "unset" >"$FAKE_ENVIRONMENT_LOG"
fi

while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == "-resultBundlePath" ]]; then
    shift
    result_bundle="${1:-}"
  fi
  shift || true
done

if [[ "${FAKE_MUTATE_FIXTURE:-0}" == "1" ]]; then
  printf '%s\n' "mutation" >>"$FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE"
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
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":true,"name":"iPhone Release Gate","state":"Booted"}
]}}
JSON
      ;;
    none)
      printf '%s\n' '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[]}}'
      ;;
    multiple)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":true,"name":"iPhone One","state":"Booted"},
  {"udid":"$FAKE_OTHER_SIMULATOR_UDID","isAvailable":true,"name":"iPhone Two","state":"Booted"}
]}}
JSON
      ;;
    unavailable)
      cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"udid":"$FAKE_SIMULATOR_UDID","isAvailable":false,"name":"iPhone Unavailable","state":"Booted"}
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

  total="${FAKE_TOTAL_TESTS:-407}"
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
assert_output_contains "exactly 407 Release -O tests" "$RUN_DIRECTORY/stdout"
assert_argument_once "-workspace"
assert_argument_once "$CANONICAL_WORKSPACE"
assert_argument_once "-scheme"
assert_argument_once "fearless.tests"
assert_argument_once "-configuration"
assert_argument_once "Release"
assert_argument_once "SWIFT_OPTIMIZATION_LEVEL=-O"
assert_argument_once "ENABLE_TESTABILITY=YES"
assert_argument_once "ONLY_ACTIVE_ARCH=YES"
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
assert_output_contains "unset" "$RUN_DIRECTORY/environment"
printf '%s\n' "[coredata-release-gate-test] PASS: canonical core contract"

# Explicit canonical simulator destinations remain supported.
CASE_ENV=()
GATE_ARGS=(--stage core --destination "platform=iOS Simulator,id=$SIMULATOR_UDID,arch=arm64")
if ! run_gate "valid-explicit-destination"; then
  sed -n '1,80p' "$RUN_DIRECTORY/stderr" >&2
  fail "valid explicit simulator destination was rejected"
fi
printf '%s\n' "[coredata-release-gate-test] PASS: explicit simulator destination"

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
assert_output_contains "set" "$RUN_DIRECTORY/environment"
assert_output_contains "exactly 2 tests, source fixture unchanged" "$RUN_DIRECTORY/stdout"
printf '%s\n' "[coredata-release-gate-test] PASS: copied-phone exact-two contract"

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
expect_failure "absent-copied-phone-fixture" "readable, regular, non-symlink"

ln -s "$PHONE_FIXTURE" "$TEMPORARY_DIR/symlink.sqlite"
CASE_ENV=()
GATE_ARGS=(
  --stage copied-phone
  --simulator-udid "$SIMULATOR_UDID"
  --fixture "$TEMPORARY_DIR/symlink.sqlite"
)
expect_failure "symlink-copied-phone-fixture" "readable, regular, non-symlink"

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

CASE_ENV=(
  "FAKE_TOTAL_TESTS=407"
  "FAKE_PASSED_TESTS=242"
  "FAKE_FAILED_TESTS=1"
  "FAKE_RESULT=Failed"
  'FAKE_TEST_FAILURES=[{"testName":"redacted fixture failure"}]'
)
GATE_ARGS=(--stage core --simulator-udid "$SIMULATOR_UDID")
expect_failure "failed-summary" "zero-failure/zero-skip"

CASE_ENV=(
  "FAKE_TOTAL_TESTS=407"
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

printf '%s\n' \
  "[coredata-release-gate-test] PASS: 3 positive contracts + 23 negative/adversarial cases"
