#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
MODE="${RELEASE_READINESS_MODE:-${MODE:-preflight}}"
RUN_DEPENDENCY_CONTRACTS="${RUN_DEPENDENCY_CONTRACTS:-1}"
RUN_RUNTIME_KEYS="${RUN_RUNTIME_KEYS:-1}"
SKIP_BOOTSTRAP="${SKIP_BOOTSTRAP:-1}"
EXPORT_METHOD="${EXPORT_METHOD:-release-testing}"
SIGNING_MODE="${SIGNING_MODE:-manual}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/fearless-release-readiness.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/build/fearless-release-readiness-export}"
INSTALL_EXPORTED_IPA="${INSTALL_EXPORTED_IPA:-0}"
REQUIRE_DEVICE="${REQUIRE_DEVICE:-0}"
DEVICE_TIMEOUT_SECONDS="${DEVICE_TIMEOUT_SECONDS:-30}"
failures=0

usage() {
  cat <<EOF
Usage:
  RELEASE_READINESS_MODE=preflight|archive|install $0 [repo-root]

Modes:
  preflight  Run dependency contracts, strict runtime key validation, and signing precheck only.
  archive    Run preflight plus signed release-testing archive/export verification.
  install    Run archive mode and install/launch the exported IPA on a trusted connected device.

Common environment:
  SIGNING_MODE=manual|automatic
  EXPORT_METHOD=release-testing
  ENV_FILE=.env.local
  DEVICE_ID=<device udid|serial|name>       # required for install mode when multiple devices exist
  REQUIRE_DEVICE=1                          # require a trusted connected device during preflight
  APP_STORE_CONNECT_API_KEY_CONTENT=...     # for automatic signing with ASC API key
  APP_STORE_CONNECT_API_KEY_ID=...
  APP_STORE_CONNECT_API_KEY_ISSUER_ID=...
EOF
}

fail() {
  echo "[release-readiness] ERROR: $*" >&2
  exit 1
}

run_gate() {
  local label="$1"
  shift

  echo "[release-readiness] ${label}"
  if "$@"; then
    return 0
  fi

  echo "[release-readiness] ERROR: ${label} failed" >&2
  failures=$((failures + 1))
}

run_step() {
  local label="$1"
  shift

  echo "[release-readiness] ${label}"
  "$@"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

cd "$ROOT"

case "$MODE" in
  preflight | archive | install)
    ;;
  *)
    fail "RELEASE_READINESS_MODE must be preflight, archive, or install; got '$MODE'."
    ;;
esac

if [[ "$MODE" == "install" ]]; then
  INSTALL_EXPORTED_IPA=1
  REQUIRE_DEVICE=1
fi

if [[ "$RUN_DEPENDENCY_CONTRACTS" == "1" ]]; then
  run_gate "Checking dependency and release contracts" \
    bash scripts/deps/check-dependency-contracts.sh "$ROOT"
fi

if [[ "$RUN_RUNTIME_KEYS" == "1" ]]; then
  run_gate "Validating strict runtime keys" \
    env STRICT_RUNTIME_KEYS=1 scripts/secrets/validate-runtime-keys.sh "$ROOT"
fi

archive_smoke_env=(
  SKIP_BOOTSTRAP="$SKIP_BOOTSTRAP"
  REQUIRE_SIGNED_ARCHIVE=1
  EXPORT_METHOD="$EXPORT_METHOD"
  SIGNING_MODE="$SIGNING_MODE"
  ARCHIVE_PATH="$ARCHIVE_PATH"
  EXPORT_PATH="$EXPORT_PATH"
)

run_gate "Checking release signing preflight" \
  env "${archive_smoke_env[@]}" PRECHECK_ONLY=1 REQUIRE_RUNTIME_KEYS=0 bash scripts/ci/archive-smoke.sh "$ROOT"

if [[ "$REQUIRE_DEVICE" == "1" ]]; then
  run_gate "Checking trusted physical device availability" \
    env DEVICE_ID="${DEVICE_ID:-}" TIMEOUT_SECONDS="$DEVICE_TIMEOUT_SECONDS" scripts/ci/check-device-ready.sh
fi

if ((failures > 0)); then
  echo "[release-readiness] ${failures} preflight gate(s) failed." >&2
  exit 1
fi

case "$MODE" in
  preflight)
    ;;
  archive)
    run_step "Running signed archive and export verification" \
      env "${archive_smoke_env[@]}" bash scripts/ci/archive-smoke.sh "$ROOT"
    ;;
  install)
    run_step "Running signed archive, export verification, device install, and launch" \
      env "${archive_smoke_env[@]}" INSTALL_EXPORTED_IPA="$INSTALL_EXPORTED_IPA" bash scripts/ci/archive-smoke.sh "$ROOT"
    ;;
esac

echo "[release-readiness] OK: ${MODE} mode completed."
