#!/usr/bin/env bash
set -euo pipefail

# Contract tests for scripts/ci/select-simulator.sh, run against a fake
# `xcrun simctl` so they need neither Xcode nor CoreSimulator.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SELECTOR="$SCRIPT_DIR/ci/select-simulator.sh"

fail() {
  echo "[select-simulator-test][error] $*" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/xcrun" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "simctl" ]] || exit 64
shift
case "$*" in
  "list devices available") cat "$FAKE_SIMCTL_DEVICES" ;;
  "list runtimes available") cat "$FAKE_SIMCTL_RUNTIMES" ;;
  "list devicetypes") cat "$FAKE_SIMCTL_DEVICETYPES" ;;
  create*)
    printf '%s\n' "$*" >> "$FAKE_SIMCTL_CREATE_LOG"
    echo "CCCCCCCC-0000-0000-0000-000000000001"
    ;;
  *) exit 64 ;;
esac
FAKE
chmod +x "$fake_bin/xcrun"

export FAKE_SIMCTL_RUNTIMES="$tmp_dir/runtimes.txt"
export FAKE_SIMCTL_DEVICETYPES="$tmp_dir/devicetypes.txt"
export FAKE_SIMCTL_CREATE_LOG="$tmp_dir/create.log"
cat > "$FAKE_SIMCTL_RUNTIMES" <<'EOF'
== Runtimes ==
iOS 9.3 (9.3 - 13E233) - com.apple.CoreSimulator.SimRuntime.iOS-9-3
iOS 18.1 (18.1 - 22B81) - com.apple.CoreSimulator.SimRuntime.iOS-18-1
iOS 27.0 (27.0 - 24A434) - com.apple.CoreSimulator.SimRuntime.iOS-27-0
EOF
cat > "$FAKE_SIMCTL_DEVICETYPES" <<'EOF'
== Device Types ==
iPhone 16 (com.apple.CoreSimulator.SimDeviceType.iPhone-16)
EOF

select_with() {
  local devices="$1"
  shift
  FAKE_SIMCTL_DEVICES="$devices" PATH="$fake_bin:$PATH" env "$@" bash "$SELECTOR" 2>/dev/null
}

expect_udid() {
  local name="$1"
  local expected="$2"
  local devices="$3"
  shift 3
  local actual
  actual="$(select_with "$devices" "$@")" || fail "$name: selector failed"
  [[ "$actual" == "$expected" ]] || fail "$name: expected $expected, got $actual"
}

# Old runtimes list first. CI used to get iPhone 16 on iOS 18.1 even with a newer runtime installed.
multi_runtime="$tmp_dir/multi-runtime.txt"
cat > "$multi_runtime" <<'EOF'
== Devices ==
-- iOS 9.3 --
    iPhone 16 (00000000-0000-0000-0000-000000000093) (Shutdown)
-- iOS 18.1 --
    iPhone 16 Pro (00000000-0000-0000-0000-000000001810) (Shutdown)
    iPhone 16 (00000000-0000-0000-0000-000000001811) (Shutdown)
-- iOS 26.5 --
    iPhone 16 (00000000-0000-0000-0000-000000002651) (Shutdown)
    iPhone 16 (00000000-0000-0000-0000-000000002652) (Booted)
-- iOS 27.0 --
    iPhone 18 Pro (00000000-0000-0000-0000-000000002700) (Shutdown)
    iPhone 16 Pro (00000000-0000-0000-0000-000000002701) (Shutdown)
-- tvOS 28.0 --
    iPhone 16 (00000000-0000-0000-0000-000000002800) (Shutdown)
    Apple TV 4K (3rd generation) (00000000-0000-0000-0000-000000002801) (Shutdown)
EOF

expect_udid "exact name on several runtimes uses the newest iOS runtime (numeric, first listed)" \
  "00000000-0000-0000-0000-000000002651" "$multi_runtime" PREFERRED_NAME="iPhone 16" ALLOW_CREATE=0
expect_udid "pattern match uses the newest iOS runtime" \
  "00000000-0000-0000-0000-000000002701" "$multi_runtime" PREFERRED_NAME="iPhone 16 P" ALLOW_CREATE=0
expect_udid "any-iPhone fallback uses the newest iOS runtime and ignores other platforms" \
  "00000000-0000-0000-0000-000000002700" "$multi_runtime" PREFERRED_NAME="Apple TV" ALLOW_CREATE=0

single_runtime="$tmp_dir/single-runtime.txt"
cat > "$single_runtime" <<'EOF'
== Devices ==
-- iOS 18.1 --
    iPhone 16 Pro (00000000-0000-0000-0000-000000001810) (Shutdown)
    iPhone 16 (00000000-0000-0000-0000-000000001811) (Shutdown)
EOF
expect_udid "exact name still wins over a pattern match listed before it" \
  "00000000-0000-0000-0000-000000001811" "$single_runtime" PREFERRED_NAME="iPhone 16" ALLOW_CREATE=0

no_iphone="$tmp_dir/no-iphone.txt"
cat > "$no_iphone" <<'EOF'
== Devices ==
-- iOS 27.0 --
    iPad Pro 13-inch (M5) (00000000-0000-0000-0000-000000002799) (Shutdown)
EOF
set +e
select_with "$no_iphone" PREFERRED_NAME="iPhone 16" ALLOW_CREATE=0 >/dev/null
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "no iPhone with ALLOW_CREATE=0 must fail"
[[ ! -e "$FAKE_SIMCTL_CREATE_LOG" ]] || fail "ALLOW_CREATE=0 must not create a simulator"

expect_udid "no iPhone with ALLOW_CREATE=1 creates one" \
  "CCCCCCCC-0000-0000-0000-000000000001" "$no_iphone" PREFERRED_NAME="iPhone 16" ALLOW_CREATE=1
grep -Fxq 'create Codex CI iPhone com.apple.CoreSimulator.SimDeviceType.iPhone-16 com.apple.CoreSimulator.SimRuntime.iOS-27-0' \
  "$FAKE_SIMCTL_CREATE_LOG" || fail "simulator must be created on the newest iOS runtime: $(cat "$FAKE_SIMCTL_CREATE_LOG")"

echo "[select-simulator-test] PASS: 6 selection cases"
