#!/usr/bin/env bash
set -euo pipefail

# Upload coverage artifacts in build/coverage to Codecov using the universal uploader.
# Usage: scripts/ci/upload-codecov.sh [RESULTS_DIR]

RESULTS_DIR="${1:-build/coverage}"
if [[ ! -d "${RESULTS_DIR}" ]]; then
  echo "[codecov] Coverage directory '${RESULTS_DIR}' not found; skipping upload" >&2
  exit 0
fi

REPORT_JSON="${RESULTS_DIR}/coverage.json"
MERGED_ARCHIVE="${RESULTS_DIR}/merged.xccovarchive"

if [[ ! -f "${REPORT_JSON}" && ! -f "${MERGED_ARCHIVE}" ]]; then
  echo "[codecov] No coverage artifacts detected under ${RESULTS_DIR}; skipping upload" >&2
  exit 0
fi

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo "[codecov] Neither curl nor wget available to download Codecov uploader" >&2
  exit 1
fi

OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
case "${OS_NAME}" in
  darwin*)
    UPLOADER_URL="https://uploader.codecov.io/latest/macos/codecov"
    ;;
  linux*)
    UPLOADER_URL="https://uploader.codecov.io/latest/linux/codecov"
    ;;
  *)
    echo "[codecov] Unsupported OS '${OS_NAME}' for Codecov uploader" >&2
    exit 1
    ;;
esac

UPLOADER_BIN="${RESULTS_DIR}/codecov"
rm -f "${UPLOADER_BIN}" || true

if command -v curl >/dev/null 2>&1; then
  curl -sSfL "${UPLOADER_URL}" -o "${UPLOADER_BIN}"
else
  wget -q -O "${UPLOADER_BIN}" "${UPLOADER_URL}"
fi

chmod +x "${UPLOADER_BIN}"

ARGS=(
  -R "$(pwd)"
  -s "${RESULTS_DIR}"
  -F ios
)

if [[ -f "${REPORT_JSON}" ]]; then
  ARGS+=(-f "${REPORT_JSON}")
fi
if [[ -f "${MERGED_ARCHIVE}" ]]; then
  ARGS+=(-f "${MERGED_ARCHIVE}")
fi

if [[ -n "${CODECOV_TOKEN:-}" ]]; then
  ARGS+=(-t "${CODECOV_TOKEN}")
fi

"${UPLOADER_BIN}" "${ARGS[@]}"

echo "[codecov] Coverage upload completed"

