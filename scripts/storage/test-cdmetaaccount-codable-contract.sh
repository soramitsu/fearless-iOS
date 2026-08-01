#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly AUDIT_SCRIPT="$SCRIPT_DIR/audit-cdmetaaccount-codable-contract.sh"
readonly TEMPORARY_DIR="$(
  mktemp -d "${TMPDIR:-/private/tmp}/fearless-cdmetaaccount-codable-tests.XXXXXX"
)"
trap 'rm -rf "$TEMPORARY_DIR"' EXIT

fail() {
  printf '%s ERROR: %s\n' "[cdmetaaccount-codable-audit-test]" "$*" >&2
  exit 1
}

new_fixture() {
  local name="$1"
  local fixture="$TEMPORARY_DIR/$name"
  mkdir -p "$fixture/fearless"
  printf '%s\n' "$fixture"
}

run_audit() {
  local fixture="$1"
  FEARLESS_CDMETAACCOUNT_CODABLE_ROOT="$fixture" \
    bash "$AUDIT_SCRIPT" 2>&1
}

expect_success() {
  local label="$1"
  local fixture="$2"
  local output

  if ! output="$(run_audit "$fixture")"; then
    fail "$label unexpectedly failed: $output"
  fi
  [[ "$output" == *"PASS: explicit MetaAccountMapper boundary preserved"* ]] ||
    fail "$label did not emit the success contract: $output"
  printf '%s\n' "[cdmetaaccount-codable-audit-test] PASS: $label"
}

expect_failure() {
  local label="$1"
  local expected_message="$2"
  local fixture="$3"
  local output
  local status

  set +e
  output="$(run_audit "$fixture")"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "$label unexpectedly passed"
  [[ "$output" == *"$expected_message"* ]] ||
    fail "$label failed without '$expected_message': $output"
  printf '%s\n' "[cdmetaaccount-codable-audit-test] PASS (rejected): $label"
}

bash "$AUDIT_SCRIPT" >/dev/null
printf '%s\n' "[cdmetaaccount-codable-audit-test] PASS: canonical source"

[[ -x /usr/bin/python3 ]] ||
  fail "macOS system Python is required for the compatibility self-test"
FEARLESS_CDMETAACCOUNT_CODABLE_PYTHON_BIN=/usr/bin/python3 \
  bash "$AUDIT_SCRIPT" >/dev/null
printf '%s\n' "[cdmetaaccount-codable-audit-test] PASS: macOS system Python"

fixture="$(new_fixture safe-boundaries)"
cat >"$fixture/fearless/Safe.swift" <<'SWIFT'
struct CDMetaAccountSnapshot: CoreDataCodable {}
let mapper: CodableCoreDataMapper<Model, CDMetaAccountSnapshot>

// extension CDMetaAccount: CoreDataCodable {}
/*
 let dormantExample: CodableCoreDataMapper<Model, CDMetaAccount>
 */
SWIFT
expect_success "token boundaries and comments" "$fixture"

fixture="$(new_fixture direct-extension)"
cat >"$fixture/fearless/Dangerous.swift" <<'SWIFT'
extension CDMetaAccount: CoreDataCodable {}
SWIFT
expect_failure \
  "direct empty-codec extension" \
  "CDMetaAccount must not directly conform to CoreDataCodable" \
  "$fixture"

fixture="$(new_fixture adversarial-extension)"
cat >"$fixture/fearless/Dangerous.swift" <<'SWIFT'
extension
    SSFAccountManagmentStorage
        .CDMetaAccount
    : Sendable,
      /* whitespace and comments must not hide the conformance */
      CoreDataCodable
{}
SWIFT
expect_failure \
  "qualified multiline conformance" \
  "CDMetaAccount must not directly conform to CoreDataCodable" \
  "$fixture"

fixture="$(new_fixture direct-class-conformance)"
cat >"$fixture/fearless/Dangerous.swift" <<'SWIFT'
final class CDMetaAccount: NSManagedObject, CoreDataCodable {}
SWIFT
expect_failure \
  "direct class conformance" \
  "CDMetaAccount must not directly conform to CoreDataCodable" \
  "$fixture"

fixture="$(new_fixture direct-codable-mapper)"
cat >"$fixture/fearless/Dangerous.swift" <<'SWIFT'
let mapper: CodableCoreDataMapper<MetaAccountModel, CDMetaAccount>
SWIFT
expect_failure \
  "direct CodableCoreDataMapper" \
  "CodableCoreDataMapper must not target CDMetaAccount" \
  "$fixture"

fixture="$(new_fixture adversarial-codable-mapper)"
cat >"$fixture/fearless/Dangerous.swift" <<'SWIFT'
let mapper: RobinHood.CodableCoreDataMapper<
    Dictionary<String, (Int, Int)>,
    /* the explicit wallet mapper remains mandatory */
    SSFAccountManagmentStorage
        .CDMetaAccount
>
SWIFT
expect_failure \
  "qualified multiline nested-generic CodableCoreDataMapper" \
  "CodableCoreDataMapper must not target CDMetaAccount" \
  "$fixture"

fixture="$(new_fixture wrapped-codable-mapper)"
cat >"$fixture/fearless/Dangerous.swift" <<'SWIFT'
let mapper: CodableCoreDataMapper<Model, Optional<CDMetaAccount>>
SWIFT
expect_failure \
  "wrapped CDMetaAccount CodableCoreDataMapper" \
  "CodableCoreDataMapper must not target CDMetaAccount" \
  "$fixture"

printf '%s\n' \
  "[cdmetaaccount-codable-audit-test] PASS: 3 positive + 6 negative/adversarial cases"
