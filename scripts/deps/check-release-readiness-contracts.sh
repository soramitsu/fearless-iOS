#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="${1:-$(pwd)}"
release_script="$ROOT/scripts/ci/release-readiness.sh"
archive_smoke="$ROOT/scripts/ci/archive-smoke.sh"
agents_doc="$ROOT/AGENTS.md"

fail() {
  echo "[check-release-readiness-contracts] ERROR: $*" >&2
  exit 1
}

require_file() {
  local file="$1"

  [[ -f "$file" ]] || fail "Missing file: $file"
}

require_line() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  require_file "$file"
  grep -Fq -- "$pattern" "$file" ||
    fail "${description} missing from ${file#"$ROOT"/}: $pattern"
}

require_file "$release_script"
[[ -x "$release_script" ]] || fail "Release readiness helper is not executable: ${release_script#"$ROOT"/}"

require_line "$archive_smoke" 'PRECHECK_ONLY="${PRECHECK_ONLY:-0}"' "archive-smoke precheck-only default"
require_line "$archive_smoke" 'if [[ "$PRECHECK_ONLY" == "1" ]]; then' "archive-smoke precheck-only branch"
require_line "$archive_smoke" 'Precheck OK for ${CONFIGURATION} archive' "archive-smoke precheck success diagnostic"

require_line "$release_script" 'MODE="${RELEASE_READINESS_MODE:-${MODE:-preflight}}"' "preflight default mode"
require_line "$release_script" 'REQUIRE_DEVICE="${REQUIRE_DEVICE:-0}"' "opt-in physical device preflight"
require_line "$release_script" 'DEVICE_TIMEOUT_SECONDS="${DEVICE_TIMEOUT_SECONDS:-30}"' "device preflight timeout"
require_line "$release_script" 'failures=0' "preflight failure aggregation"
require_line "$release_script" 'run_gate()' "non-fatal preflight gate runner"
require_line "$release_script" 'failures=$((failures + 1))' "preflight failure counting"
require_line "$release_script" 'preflight | archive | install)' "supported release readiness modes"
require_line "$release_script" 'REQUIRE_DEVICE=1' "install mode requires physical device preflight"
require_line "$release_script" 'bash scripts/deps/check-dependency-contracts.sh "$ROOT"' "dependency contract gate"
require_line "$release_script" 'env STRICT_RUNTIME_KEYS=1 scripts/secrets/validate-runtime-keys.sh "$ROOT"' "strict runtime key gate"
require_line "$release_script" 'REQUIRE_SIGNED_ARCHIVE=1' "signed archive requirement"
require_line "$release_script" 'EXPORT_METHOD="$EXPORT_METHOD"' "release export method handoff"
require_line "$release_script" 'SIGNING_MODE="$SIGNING_MODE"' "signing mode handoff"
require_line "$release_script" 'PRECHECK_ONLY=1 REQUIRE_RUNTIME_KEYS=0 bash scripts/ci/archive-smoke.sh "$ROOT"' "archive-smoke signing preflight"
require_line "$release_script" 'if [[ "$REQUIRE_DEVICE" == "1" ]]; then' "conditional physical device preflight"
require_line "$release_script" 'scripts/ci/check-device-ready.sh' "physical device preflight helper"
require_line "$release_script" 'TIMEOUT_SECONDS="$DEVICE_TIMEOUT_SECONDS"' "physical device preflight timeout handoff"
require_line "$release_script" 'if ((failures > 0)); then' "preflight failure stop before archive"
require_line "$release_script" 'preflight gate(s) failed' "preflight aggregate failure diagnostic"
require_line "$release_script" 'bash scripts/ci/archive-smoke.sh "$ROOT"' "archive-smoke archive/export gate"
require_line "$release_script" 'INSTALL_EXPORTED_IPA="$INSTALL_EXPORTED_IPA"' "archive-smoke install handoff"
require_line "$release_script" 'DEVICE_ID=<device udid|serial|name>' "device id usage documentation"

require_line "$agents_doc" 'scripts/ci/release-readiness.sh' "AGENTS release readiness documentation"

echo "[check-release-readiness-contracts] OK"
