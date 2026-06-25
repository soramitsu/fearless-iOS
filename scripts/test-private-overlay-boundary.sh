#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT_SCRIPT="$ROOT_DIR/scripts/audit-private-overlay-boundary.sh"

fail() {
  echo "[private-overlay-audit-test][error] $*" >&2
  exit 1
}

write_file() {
  local repo="$1"
  local path="$2"
  local content="$3"

  mkdir -p "$(dirname "$repo/$path")"
  printf '%s\n' "$content" > "$repo/$path"
}

init_repo() {
  local repo="$1"
  git init -q "$repo"
  git -C "$repo" config user.email "overlay-audit@example.invalid"
  git -C "$repo" config user.name "Overlay Audit Test"
}

track_all() {
  local repo="$1"
  git -C "$repo" add .
}

run_audit() {
  local public_repo="$1"
  local private_repo="$2"
  PUBLIC_REPO_DIR="$public_repo" PRIVATE_REPO_DIR="$private_repo" bash "$AUDIT_SCRIPT"
}

run_audit_with_report() {
  local public_repo="$1"
  local private_repo="$2"
  local report="$3"
  shift 3

  PUBLIC_REPO_DIR="$public_repo" PRIVATE_REPO_DIR="$private_repo" PRIVATE_OVERLAY_REPORT="$report" "$@" bash "$AUDIT_SCRIPT"
}

make_pair() {
  local dir="$1"
  local public_repo="$dir/public"
  local private_repo="$dir/private"

  mkdir -p "$public_repo" "$private_repo"
  init_repo "$public_repo"
  init_repo "$private_repo"

  write_file "$public_repo" "fearless/Common/Model/PublicFeature.swift" "public feature"
  write_file "$public_repo" "README.md" "public readme"
  write_file "$private_repo" "README.md" "private release readme"

  track_all "$public_repo"
  track_all "$private_repo"

  printf '%s\n' "$public_repo"
  printf '%s\n' "$private_repo"
}

test_allows_release_overlay_paths() {
  local dir="$1/allowed"
  local repos
  repos="$(make_pair "$dir")"
  local public_repo
  public_repo="$(printf '%s\n' "$repos" | sed -n '1p')"
  local private_repo
  private_repo="$(printf '%s\n' "$repos" | sed -n '2p')"

  write_file "$private_repo" "fearless/CIKeys.stencil" "struct CIKeys {}"
  write_file "$private_repo" "fearless/fearless.entitlements" "<plist/>"
  write_file "$private_repo" "fearless/Configs/fearless.release.xcconfig" "RELEASE=1"
  write_file "$private_repo" "scripts/secrets/app-store-connect.json" '{"release":true}'
  track_all "$private_repo"

  run_audit "$public_repo" "$private_repo" >/dev/null
}

test_rejects_private_only_product_code() {
  local dir="$1/private-only-product"
  local repos
  repos="$(make_pair "$dir")"
  local public_repo
  public_repo="$(printf '%s\n' "$repos" | sed -n '1p')"
  local private_repo
  private_repo="$(printf '%s\n' "$repos" | sed -n '2p')"
  local output="$dir/output.txt"

  write_file "$private_repo" "fearless/Modules/Send/PrivateTransfer.swift" "private product code"
  track_all "$private_repo"

  if run_audit "$public_repo" "$private_repo" > "$output" 2>&1; then
    fail "expected private-only product code to fail"
  fi

  grep -q $'A\tfearless/Modules/Send/PrivateTransfer.swift' "$output" ||
    fail "expected added product path in audit output"
}

test_rejects_tracked_public_product_code() {
  local dir="$1/tracked-public-product"
  local repos
  repos="$(make_pair "$dir")"
  local public_repo
  public_repo="$(printf '%s\n' "$repos" | sed -n '1p')"
  local private_repo
  private_repo="$(printf '%s\n' "$repos" | sed -n '2p')"
  local output="$dir/output.txt"

  write_file "$private_repo" "fearless/Common/Model/PublicFeature.swift" "public feature"
  track_all "$private_repo"

  if run_audit "$public_repo" "$private_repo" > "$output" 2>&1; then
    fail "expected tracked public product code to fail"
  fi

  grep -q $'T\tfearless/Common/Model/PublicFeature.swift' "$output" ||
    fail "expected tracked public product path in audit output"
}

test_rejects_modified_public_product_code() {
  local dir="$1/modified-product"
  local repos
  repos="$(make_pair "$dir")"
  local public_repo
  public_repo="$(printf '%s\n' "$repos" | sed -n '1p')"
  local private_repo
  private_repo="$(printf '%s\n' "$repos" | sed -n '2p')"
  local output="$dir/output.txt"

  write_file "$private_repo" "fearless/Common/Model/PublicFeature.swift" "modified private feature"
  track_all "$private_repo"

  if run_audit "$public_repo" "$private_repo" > "$output" 2>&1; then
    fail "expected modified public product code to fail"
  fi

  grep -q $'M\tfearless/Common/Model/PublicFeature.swift' "$output" ||
    fail "expected modified product path in audit output"
}

test_writes_full_report_when_output_is_truncated() {
  local dir="$1/full-report"
  local repos
  repos="$(make_pair "$dir")"
  local public_repo
  public_repo="$(printf '%s\n' "$repos" | sed -n '1p')"
  local private_repo
  private_repo="$(printf '%s\n' "$repos" | sed -n '2p')"
  local output="$dir/output.txt"
  local report="$dir/private-overlay-report.tsv"

  local i
  for i in 1 2 3 4 5; do
    write_file "$private_repo" "fearless/Modules/Send/PrivateTransfer$i.swift" "private product code $i"
  done
  track_all "$private_repo"

  if run_audit_with_report "$public_repo" "$private_repo" "$report" env MAX_REPORT_LINES=2 > "$output" 2>&1; then
    fail "expected many private-only product paths to fail"
  fi

  grep -q "Output truncated at 2 paths" "$output" ||
    fail "expected truncated console output notice"
  grep -q "Full report: $report" "$output" ||
    fail "expected full report path in audit output"
  [[ -f "$report" ]] || fail "expected full report file"

  local report_count
  report_count="$(wc -l < "$report" | tr -d '[:space:]')"
  [[ "$report_count" == "5" ]] ||
    fail "expected full report to include all 5 failures, got $report_count"
  grep -q $'A\tfearless/Modules/Send/PrivateTransfer5.swift' "$report" ||
    fail "expected full report to include entries omitted from console output"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

test_allows_release_overlay_paths "$tmpdir"
test_rejects_private_only_product_code "$tmpdir"
test_rejects_tracked_public_product_code "$tmpdir"
test_rejects_modified_public_product_code "$tmpdir"
test_writes_full_report_when_output_is_truncated "$tmpdir"

echo "[private-overlay-audit-test] iOS overlay audit self-test passed."
