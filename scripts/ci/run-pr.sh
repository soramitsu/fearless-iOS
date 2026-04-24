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

pick_simulator_udid() {
  local preferred_name="$1"
  xcrun simctl list devices available | awk -v name="$preferred_name" '
    index($0, name) > 0 {
      if (match($0, /[A-Fa-f0-9-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

pick_any_iphone_udid() {
  xcrun simctl list devices available | awk '
    /iPhone/ {
      if (match($0, /[A-Fa-f0-9-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

SIM_UDID="$(pick_simulator_udid "iPhone 16" || true)"
if [[ -z "${SIM_UDID}" ]]; then
  SIM_UDID="$(pick_any_iphone_udid || true)"
fi

if [[ -z "${SIM_UDID}" ]]; then
  echo "[run-pr] ERROR: No concrete available iPhone simulator found for test execution" >&2
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
