#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CHECK="$SCRIPT_DIR/check-availability.sh"
readonly FIXTURES="$(mktemp -d "${TMPDIR:-/tmp}/fearless-availability-tests.XXXXXX")"
trap 'rm -rf "$FIXTURES"' EXIT

mkdir -p "$FIXTURES/bin"
cat > "$FIXTURES/bin/xcrun" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CASE_ROOT/xcrun-access.txt"
exit 99
MOCK
cat > "$FIXTURES/bin/xcodebuild" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CASE_ROOT/build-args.txt"
printf '%s\n' 'compiler stdout'
printf '%s\n' 'compiler stderr' >&2
if [[ "${MOCK_DIAGNOSTIC:-0}" = 1 ]]; then
  printf '%s\n' "error: 'newAPI()' is only available in iOS 18.0 or newer" >&2
fi
exit "${MOCK_BUILD_EXIT:-0}"
MOCK
chmod +x "$FIXTURES/bin/xcrun" "$FIXTURES/bin/xcodebuild"

fail() { printf '[availability-test] %s\n' "$*" >&2; exit 1; }
pass_count=0

run_case() {
  local name="$1" expected_exit="$2" build_exit="$3" diagnostic="$4" destination="$5"
  shift 5
  local case_root="$FIXTURES/$name" rc=0
  mkdir -p "$case_root"
  (
    cd "$case_root"
    PATH="$FIXTURES/bin:$PATH" CASE_ROOT="$case_root" \
      MOCK_BUILD_EXIT="$build_exit" MOCK_DIAGNOSTIC="$diagnostic" \
      bash "$CHECK" "$@"
  ) > "$case_root/output.txt" 2>&1 || rc=$?
  [[ "$rc" = "$expected_exit" ]] || fail "$name: exit $rc, wanted $expected_exit"
  [[ ! -e "$case_root/xcrun-access.txt" ]] || fail "$name: queried simulator state"
  [[ -f "$case_root/build-args.txt" ]] || fail "$name: did not invoke compiler"
  local actual_destination
  actual_destination=$(awk 'previous == "-destination" { print; exit } { previous=$0 }' "$case_root/build-args.txt")
  [[ "$actual_destination" = "$destination" ]] || fail "$name: wrong destination: $actual_destination"
  grep -Fxq 'compiler stdout' "$case_root/build/availability.raw.log" || fail "$name: stdout not retained"
  grep -Fxq 'compiler stderr' "$case_root/build/availability.raw.log" || fail "$name: stderr not retained"
  if [[ "$diagnostic" = 1 ]]; then
    grep -Fq '[availability] Potential availability violations detected:' "$case_root/output.txt" || fail "$name: stderr diagnostic missed"
  fi
  if [[ "$expected_exit" = 0 ]]; then
    grep -Fq 'Availability check passed' "$case_root/output.txt" || fail "$name: success not reported"
  elif grep -Fq 'Availability check passed' "$case_root/output.txt"; then
    fail "$name: reported success after failure"
  fi
  pass_count=$((pass_count + 1))
  printf '[availability-test] PASS %s\n' "$name"
}

unset AVAILABILITY_DESTINATION
run_case generic-success 0 0 0 'generic/platform=iOS Simulator'
run_case compiler-failure 65 65 0 'generic/platform=iOS Simulator'
run_case stderr-diagnostic 2 0 1 'generic/platform=iOS Simulator'
run_case compiler-failure-with-diagnostic 65 65 1 'generic/platform=iOS Simulator'
AVAILABILITY_DESTINATION='platform=iOS Simulator,id=explicit-env' \
  run_case environment-destination 0 0 0 'platform=iOS Simulator,id=explicit-env'
AVAILABILITY_DESTINATION='platform=iOS Simulator,id=overridden' \
  run_case argument-destination 0 0 0 'platform=iOS Simulator,id=explicit-argument' \
    'Custom Scheme' 'Custom Workspace.xcworkspace' 'platform=iOS Simulator,id=explicit-argument'
grep -Fxq 'Custom Scheme' "$FIXTURES/argument-destination/build-args.txt" || fail 'scheme argument was split'
grep -Fxq 'Custom Workspace.xcworkspace' "$FIXTURES/argument-destination/build-args.txt" || fail 'workspace argument was split'

printf '[availability-test] PASS %s cases; no Xcode build or simulator access\n' "$pass_count"
