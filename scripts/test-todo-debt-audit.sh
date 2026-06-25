#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-todo-debt.sh"

fail() {
  echo "[todo-audit-test][error] $*" >&2
  exit 1
}

make_fixture_root() {
  local root="$1"
  mkdir -p "$root/fearless" "$root/config"
}

run_audit() {
  local root="$1"
  TODO_AUDIT_ROOT="$root" TODO_AUDIT_BASELINE="$root/config/todo-debt-baseline.tsv" bash "$AUDIT_SCRIPT"
}

expect_failure() {
  local name="$1"
  local root="$2"
  local expected="$3"
  local output

  set +e
  output="$(run_audit "$root" 2>&1)"
  local status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "$output" >&2
    fail "$name unexpectedly passed"
  fi

  if [[ "$output" != *"$expected"* ]]; then
    echo "$output" >&2
    fail "$name did not report expected text: $expected"
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

pass_root="$tmp_dir/pass"
make_fixture_root "$pass_root"
printf '%s\n' 'final class ExistingDebt { // TODO existing baseline marker' '}' > "$pass_root/fearless/ExistingDebt.swift"
printf '%s\t%s\n' 'fearless/ExistingDebt.swift' 'final class ExistingDebt { // TODO existing baseline marker' > "$pass_root/config/todo-debt-baseline.tsv"
run_audit "$pass_root" >/dev/null
PATH="/usr/bin:/bin:/usr/sbin:/sbin" run_audit "$pass_root" >/dev/null

new_root="$tmp_dir/new-marker"
make_fixture_root "$new_root"
printf '%s\n' 'final class ExistingDebt { // TODO existing baseline marker' '}' > "$new_root/fearless/ExistingDebt.swift"
printf '%s\n' 'final class NewDebt { // FIXME new marker must fail' '}' > "$new_root/fearless/NewDebt.swift"
printf '%s\t%s\n' 'fearless/ExistingDebt.swift' 'final class ExistingDebt { // TODO existing baseline marker' > "$new_root/config/todo-debt-baseline.tsv"
expect_failure "new marker fixture" "$new_root" "New TODO/FIXME/STOPSHIP markers"

stale_root="$tmp_dir/stale-baseline"
make_fixture_root "$stale_root"
printf '%s\n' 'final class CleanSource {}' > "$stale_root/fearless/CleanSource.swift"
printf '%s\t%s\n' 'fearless/OldDebt.swift' 'final class OldDebt { // TODO deleted marker' > "$stale_root/config/todo-debt-baseline.tsv"
expect_failure "stale baseline fixture" "$stale_root" "Baseline entries no longer exist"

crash_root="$tmp_dir/crashing-placeholder"
make_fixture_root "$crash_root"
printf '%s\n' 'final class Crashy {' '    func crash() { fatalError("TODO wire implementation") }' '}' > "$crash_root/fearless/Crashy.swift"
printf '%s\t%s\n' 'fearless/Crashy.swift' 'func crash() { fatalError("TODO wire implementation") }' > "$crash_root/config/todo-debt-baseline.tsv"
expect_failure "crashing placeholder fixture" "$crash_root" "Crashing TODO/FIXME placeholders are forbidden"

echo "[todo-audit-test] all tests passed"
