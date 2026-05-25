#!/usr/bin/env bash
set -euo pipefail

# Runs endpoint-dependent integration tests on demand. Default PR coverage keeps
# those tests skipped so routine CI is deterministic; this script flips the
# explicit env gate and records a separate result bundle.

ROOT="${1:-$(pwd)}"
WORKSPACE="${WORKSPACE:-fearless.xcworkspace}"
SCHEME="${SCHEME:-fearless.tests}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SP_DIR="${SP_DIR:-$ROOT/SourcePackages}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$ROOT/build/test-results/remote-integration.xcresult}"

cd "$ROOT"

if [[ "${SKIP_BOOTSTRAP:-0}" != "1" ]]; then
  SP_DIR="$SP_DIR" bash scripts/ci/bootstrap.sh
fi

HOST_ARCH="$(uname -m)"
DESTINATION="${DESTINATION:-}"

if [[ -z "$DESTINATION" ]]; then
  echo "[remote-integration] Selecting simulator"
  DEV_ID_RAW="$(LOG_PREFIX="[remote-integration]" PREFERRED_NAME="iPhone 16" ALLOW_CREATE=1 BOOT_SIMULATOR=0 "$ROOT/scripts/ci/select-simulator.sh")"
  DEV_ID="$(printf '%s\n' "$DEV_ID_RAW" | awk 'match($0, /[A-Fa-f0-9-]{36}/) { print substr($0, RSTART, RLENGTH); exit }')"
  if [[ -z "$DEV_ID" ]]; then
    echo "[remote-integration] Failed to detect a simulator UDID from: $DEV_ID_RAW" >&2
    exit 1
  fi

  DESTINATION="platform=iOS Simulator,id=${DEV_ID}"
  case "$HOST_ARCH" in
    arm64|x86_64)
      DESTINATION+=",arch=${HOST_ARCH}"
      ;;
  esac
fi

mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"
rm -rf "$RESULT_BUNDLE_PATH"

extra=()
if [[ "$HOST_ARCH" == "arm64" ]]; then
  extra+=("EXCLUDED_ARCHS=x86_64")
fi

echo "[remote-integration] Running ${CONFIGURATION} fearlessIntegrationTests on ${DESTINATION}"
FEARLESS_RUN_REMOTE_INTEGRATION_TESTS=1 xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -clonedSourcePackagesDirPath "$SP_DIR" \
  -disableAutomaticPackageResolution \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -only-testing:fearlessIntegrationTests \
  "${extra[@]}" \
  test

echo "[remote-integration] Result bundle: $RESULT_BUNDLE_PATH"
