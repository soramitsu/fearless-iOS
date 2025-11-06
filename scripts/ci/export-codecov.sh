#!/usr/bin/env bash
set -euo pipefail

# Export merged coverage artifacts from one or more .xcresult bundles for Codecov upload.
# Usage: scripts/ci/export-codecov.sh [RESULTS_DIR]
# Default RESULTS_DIR: build/coverage

RESULTS_DIR="${1:-build/coverage}"
if [[ ! -d "${RESULTS_DIR}" ]]; then
  echo "[codecov] Results directory '${RESULTS_DIR}' not found; skipping coverage export" >&2
  exit 0
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "[codecov] xcrun not available; cannot export coverage" >&2
  exit 1
fi

shopt -s nullglob
XCRESULTS=("${RESULTS_DIR}"/*.xcresult)
shopt -u nullglob
if ((${#XCRESULTS[@]} == 0)); then
  echo "[codecov] No .xcresult bundles in '${RESULTS_DIR}'; nothing to export" >&2
  exit 0
fi

MERGED_ARCHIVE="${RESULTS_DIR}/merged.xccovarchive"
rm -rf "${MERGED_ARCHIVE}" || true

ARCHIVES=()
for bundle in "${XCRESULTS[@]}"; do
  while IFS= read -r -d '' path; do
    ARCHIVES+=("${path}")
  done < <(find "${bundle}" -type d -name "*.xccovarchive" -print0)
  if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --sequesterRsrc --keepParent "${bundle}" "${bundle}.zip" || true
  elif command -v zip >/dev/null 2>&1; then
    (cd "$(dirname "${bundle}")" && zip -qry "${bundle##*/}.zip" "${bundle##*/}") || true
  fi
done

if ((${#ARCHIVES[@]} == 0)); then
  echo "[codecov] No .xccovarchive files discovered inside ${RESULTS_DIR}" >&2
  exit 1
fi

xcrun xccov merge --output "${MERGED_ARCHIVE}" "${ARCHIVES[@]}"

REPORT_JSON="${RESULTS_DIR}/coverage.json"
REPORT_TXT="${RESULTS_DIR}/coverage.txt"
FILELIST_TXT="${RESULTS_DIR}/covered-files.txt"

xcrun xccov view --report --json "${MERGED_ARCHIVE}" > "${REPORT_JSON}"
xcrun xccov view --report "${MERGED_ARCHIVE}" > "${REPORT_TXT}"
xcrun xccov view --file-list "${MERGED_ARCHIVE}" > "${FILELIST_TXT}"

echo "[codecov] Exported merged coverage to:"
echo "  - ${MERGED_ARCHIVE}"
echo "  - ${REPORT_JSON}"
echo "  - ${REPORT_TXT}"
echo "  - ${FILELIST_TXT}"

exit 0

