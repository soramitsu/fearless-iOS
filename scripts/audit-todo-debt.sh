#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${TODO_AUDIT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BASELINE_FILE="${TODO_AUDIT_BASELINE:-$ROOT_DIR/config/todo-debt-baseline.tsv}"

log() { echo "[todo-audit] $*"; }
fail() {
  echo "[todo-audit][error] $*" >&2
  exit 1
}

if [[ ! -d "$ROOT_DIR" ]]; then
  fail "Root directory does not exist: $ROOT_DIR"
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
  fail "Baseline file does not exist: $BASELINE_FILE"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

current="$tmp_dir/current.tsv"
baseline_raw="$tmp_dir/baseline-raw.tsv"
baseline="$tmp_dir/baseline.tsv"
duplicate_baseline="$tmp_dir/duplicate-baseline.tsv"
new_markers="$tmp_dir/new.tsv"
stale_markers="$tmp_dir/stale.tsv"
crashing_placeholders="$tmp_dir/crashing_placeholders.txt"

grep_source_files() {
  local pattern="$1"

  (
    cd "$ROOT_DIR"
    find . \
      \( -path './Pods' -o -path './Pods/*' \
        -o -path './PrivatePods' -o -path './PrivatePods/*' \
        -o -path './SourcePackages' -o -path './SourcePackages/*' \
        -o -path './DerivedData' -o -path './DerivedData/*' \
        -o -path './build' -o -path './build/*' \
        -o -path './.build' -o -path './.build/*' \
        -o -path '*/.build' -o -path '*/.build/*' \
        -o -path './.git' -o -path './.git/*' \) -prune \
      -o -type f \
      \( -name '*.swift' -o -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name '*.plist' -o -name '*.pbxproj' \) \
      -print0 |
      xargs -0 grep -HInEi "$pattern" || true
  )
}

scan_marker_debt() {
  if command -v rg >/dev/null 2>&1; then
    (
      cd "$ROOT_DIR"
      rg -n --no-heading -i '\b(todo|fixme|stopship)\b' \
        --glob '*.swift' \
        --glob '*.m' \
        --glob '*.mm' \
        --glob '*.h' \
        --glob '*.plist' \
        --glob '*.pbxproj' \
        --glob '!Pods/**' \
        --glob '!PrivatePods/**' \
        --glob '!SourcePackages/**' \
        --glob '!DerivedData/**' \
        --glob '!build/**' \
        --glob '!.build/**' \
        --glob '!**/.build/**' \
        --glob '!**/.git/**' \
        . || true
    )
  else
    grep_source_files '(^|[^[:alnum:]_])(todo|fixme|stopship)([^[:alnum:]_]|$)'
  fi | awk -F: '
    {
      line = $0
      sub(/^[^:]+:[0-9]+:/, "", line)
      path = $1
      sub(/^\.\//, "", path)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print path "\t" line
    }
  ' | LC_ALL=C sort -u
}

scan_crashing_placeholders() {
  if command -v rg >/dev/null 2>&1; then
    (
      cd "$ROOT_DIR"
      rg -n --no-heading -i '(fatalError|preconditionFailure)[[:space:]]*\([^)]*(TODO|FIXME|STOPSHIP)' \
        --glob '*.swift' \
        --glob '!Pods/**' \
        --glob '!PrivatePods/**' \
        --glob '!SourcePackages/**' \
        --glob '!DerivedData/**' \
        --glob '!build/**' \
        --glob '!.build/**' \
        --glob '!**/.build/**' \
        --glob '!**/.git/**' \
        . || true
    )
  else
    grep_source_files '(fatalError|preconditionFailure)[[:space:]]*\([^)]*(TODO|FIXME|STOPSHIP)'
  fi
}

awk 'NF && $0 !~ /^#/' "$BASELINE_FILE" > "$baseline_raw"
LC_ALL=C sort "$baseline_raw" > "$baseline"
LC_ALL=C sort "$baseline_raw" | uniq -d > "$duplicate_baseline"
scan_marker_debt > "$current"
scan_crashing_placeholders > "$crashing_placeholders"

if [[ -s "$duplicate_baseline" ]]; then
  echo "Duplicate TODO debt baseline entries are forbidden:" >&2
  sed -n '1,40p' "$duplicate_baseline" >&2
  fail "Remove duplicate entries from config/todo-debt-baseline.tsv."
fi

if [[ -s "$crashing_placeholders" ]]; then
  echo "Crashing TODO/FIXME placeholders are forbidden:" >&2
  sed -n '1,40p' "$crashing_placeholders" >&2
  fail "Remove fatalError/preconditionFailure TODO placeholders instead of baselining them."
fi

comm -23 "$current" "$baseline" > "$new_markers"
comm -13 "$current" "$baseline" > "$stale_markers"

if [[ -s "$new_markers" ]]; then
  echo "New TODO/FIXME/STOPSHIP markers found outside the baseline:" >&2
  sed -n '1,80p' "$new_markers" >&2
  fail "Resolve the markers or intentionally update config/todo-debt-baseline.tsv."
fi

if [[ -s "$stale_markers" ]]; then
  echo "Baseline entries no longer exist in source:" >&2
  sed -n '1,80p' "$stale_markers" >&2
  fail "Remove stale entries from config/todo-debt-baseline.tsv."
fi

log "TODO/FIXME debt matches baseline."
