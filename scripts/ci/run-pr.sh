#!/usr/bin/env bash
set -euo pipefail

echo "[run-pr] Running PR build (simulator build + tests, with device fallback)"

WORKSPACE_DIR=${WORKSPACE:-$(pwd)}
SP_DIR="$WORKSPACE_DIR/SourcePackages"

if [[ -f "$WORKSPACE_DIR/fearless.xcworkspace/contents.xcworkspacedata" ]]; then
  if [[ -x "$WORKSPACE_DIR/scripts/deps/restore-swiftpm-contract-files.sh" ]]; then
    "$WORKSPACE_DIR/scripts/deps/restore-swiftpm-contract-files.sh" "$WORKSPACE_DIR" "[run-pr]"
  fi
  # Clean previous SPM state to prevent duplicate Web3 sources
  rm -rf "$SP_DIR" || true
  if [[ -x "$WORKSPACE_DIR/scripts/deps/check-dependency-contracts.sh" ]]; then
    "$WORKSPACE_DIR/scripts/deps/check-dependency-contracts.sh" "$WORKSPACE_DIR"
  fi
  xcodebuild -resolvePackageDependencies \
    -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
    -scheme fearless \
    -clonedSourcePackagesDirPath "$SP_DIR"

  if [[ -x "scripts/deps/prepare-native-crypto-checkout.sh" ]]; then
    echo "[run-pr] Preparing native crypto checkout"
    SOURCE_PACKAGES_DIR="$SP_DIR" STRICT_REQUIRED_PATCHES=1 scripts/deps/prepare-native-crypto-checkout.sh "$WORKSPACE_DIR" "$WORKSPACE_DIR/fearless.xcworkspace" fearless
  fi
  if [[ -f "scripts/spm-shared-features-fixes.sh" ]]; then
    echo "[run-pr] Applying required shared-features-spm compatibility fixes"
    SOURCE_PACKAGES_DIR="$SP_DIR" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 bash scripts/spm-shared-features-fixes.sh "$WORKSPACE_DIR"
  fi
else
  echo "[run-pr] ERROR: Workspace not found at $WORKSPACE_DIR/fearless.xcworkspace" >&2
  exit 1
fi

SIM_UDID_RAW="$(
  LOG_PREFIX="[run-pr]" PREFERRED_NAME="iPhone 16" ALLOW_CREATE=1 BOOT_SIMULATOR=0 \
    "$WORKSPACE_DIR/scripts/ci/select-simulator.sh"
)"
SIM_UDID="$(printf '%s\n' "$SIM_UDID_RAW" | awk 'match($0, /[A-Fa-f0-9-]{36}/) { print substr($0, RSTART, RLENGTH); exit }')"
if [[ -z "$SIM_UDID" ]]; then
  echo "[run-pr] ERROR: Failed to parse simulator UDID from selector output: $SIM_UDID_RAW" >&2
  exit 1
fi

SIM_DEST="platform=iOS Simulator,id=${SIM_UDID}"
echo "[run-pr] Using simulator destination: ${SIM_DEST}"

echo "[run-pr] Building Debug on iOS Simulator"
if xcodebuild -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
  -scheme fearless \
  -configuration Debug \
  -destination "$SIM_DEST" \
  -clonedSourcePackagesDirPath "$SP_DIR" \
  clean build; then

  echo "[run-pr] Running unit tests on iOS Simulator (scheme: fearless.tests)"
  xcodebuild -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
    -scheme fearless.tests \
    -destination "$SIM_DEST" \
    -clonedSourcePackagesDirPath "$SP_DIR" \
    test
else
  echo "[run-pr] Simulator build failed; falling back to device build (signing disabled)"
  xcodebuild -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
    -scheme fearless \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -clonedSourcePackagesDirPath "$SP_DIR" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    clean build
fi

echo "[run-pr] PR build completed"
