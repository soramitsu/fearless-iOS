#!/usr/bin/env bash
set -euo pipefail

echo "[run-pr] Running PR build (simulator build + tests, with device fallback)"

WORKSPACE_DIR=${WORKSPACE:-$(pwd)}
SP_DIR="$WORKSPACE_DIR/SourcePackages"

if [[ -f "$WORKSPACE_DIR/scripts/audit-branch-flow.sh" ]]; then
  echo "[run-pr] Running branch flow audit"
  bash "$WORKSPACE_DIR/scripts/audit-branch-flow.sh"
  bash "$WORKSPACE_DIR/scripts/test-branch-flow-audit.sh"
fi

if [[ -f "$WORKSPACE_DIR/scripts/audit-release-signing-gate.sh" ]]; then
  echo "[run-pr] Running release signing gate audit"
  bash "$WORKSPACE_DIR/scripts/test-release-signing-gate-audit.sh"
  bash "$WORKSPACE_DIR/scripts/test-release-signing-gate.sh"
  bash "$WORKSPACE_DIR/scripts/test-release-signing-bootstrap.sh"
  bash "$WORKSPACE_DIR/scripts/audit-release-signing-gate.sh"
fi

if [[ -f "$WORKSPACE_DIR/scripts/audit-public-artifacts.sh" ]]; then
  echo "[run-pr] Running public artifact audit"
  bash "$WORKSPACE_DIR/scripts/audit-public-artifacts.sh"
fi

if [[ -f "$WORKSPACE_DIR/scripts/audit-todo-debt.sh" ]]; then
  echo "[run-pr] Running TODO debt audit"
  bash "$WORKSPACE_DIR/scripts/test-todo-debt-audit.sh"
  bash "$WORKSPACE_DIR/scripts/audit-todo-debt.sh"
fi

echo "[run-pr] Verifying tracked TestFlight publication evidence"
bash "$WORKSPACE_DIR/scripts/test-testflight-publication-readiness-audit.sh"
bash "$WORKSPACE_DIR/scripts/audit-testflight-publication-readiness.sh"

if [[ -f "$WORKSPACE_DIR/scripts/test-audit-testflight-upgrade-usability-gate.py" ]]; then
  echo "[run-pr] Testing privacy-safe TestFlight upgrade recovery contracts"
  PYTHONDONTWRITEBYTECODE=1 python3 \
    "$WORKSPACE_DIR/scripts/test-filter-startup-syslog.py"
  PYTHONDONTWRITEBYTECODE=1 python3 \
    "$WORKSPACE_DIR/scripts/test-capture-testflight-startup.py"
  PYTHONDONTWRITEBYTECODE=1 python3 \
    "$WORKSPACE_DIR/scripts/test-audit-testflight-upgrade-usability-gate.py"
fi

if [[ -f "$WORKSPACE_DIR/scripts/audit-transaction-builder-tests.sh" ]]; then
  echo "[run-pr] Running transaction builder coverage audit"
  bash "$WORKSPACE_DIR/scripts/test-transaction-builder-tests-audit.sh"
  bash "$WORKSPACE_DIR/scripts/audit-transaction-builder-tests.sh"
fi

if [[ -f "$WORKSPACE_DIR/scripts/test-coredata-release-gate.sh" ]]; then
  echo "[run-pr] Testing Core Data Release gate contract"
  bash "$WORKSPACE_DIR/scripts/test-coredata-release-gate.sh"
fi

if [[ -f "$WORKSPACE_DIR/scripts/audit-ton-production-send-readiness.sh" ]]; then
  echo "[run-pr] Checking blocked TON production-send evidence contract"
  bash "$WORKSPACE_DIR/scripts/test-ton-production-send-readiness-audit.sh"
  bash "$WORKSPACE_DIR/scripts/audit-ton-production-send-readiness.sh"
fi

if [[ -f "$WORKSPACE_DIR/scripts/check-iroha-mobile-sdk-release-assets.sh" ]]; then
  echo "[run-pr] Checking Iroha mobile SDK release asset contract"
  bash "$WORKSPACE_DIR/scripts/test-iroha-production-send-readiness-audit.sh"
  bash "$WORKSPACE_DIR/scripts/audit-iroha-production-send-readiness.sh"
  bash "$WORKSPACE_DIR/scripts/check-iroha-mobile-sdk-release-assets.sh" --self-test
  if [[ -n "${IROHA_MOBILE_SDK_RELEASE_TAG:-}" ]]; then
    bash "$WORKSPACE_DIR/scripts/check-iroha-mobile-sdk-release-assets.sh" --download --tag "$IROHA_MOBILE_SDK_RELEASE_TAG"
  else
    echo "[run-pr] IROHA_MOBILE_SDK_RELEASE_TAG is not set; skipping real release asset validation"
  fi
fi

if [[ -f "$WORKSPACE_DIR/scripts/test-private-overlay-boundary.sh" ]]; then
  echo "[run-pr] Testing private overlay boundary guard"
  bash "$WORKSPACE_DIR/scripts/test-private-overlay-boundary.sh"
fi

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
case "$(uname -m)" in
  arm64|x86_64)
    SIM_DEST+=",arch=$(uname -m)"
    ;;
esac
echo "[run-pr] Using simulator destination: ${SIM_DEST}"

echo "[run-pr] Building Debug on iOS Simulator"
if xcodebuild -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
  -scheme fearless \
  -configuration Debug \
  -destination "$SIM_DEST" \
  -clonedSourcePackagesDirPath "$SP_DIR" \
  -disableAutomaticPackageResolution \
  clean build; then

  echo "[run-pr] Running unit tests on iOS Simulator (scheme: fearless.tests)"
  xcodebuild -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
    -scheme fearless.tests \
    -destination "$SIM_DEST" \
    -clonedSourcePackagesDirPath "$SP_DIR" \
    -disableAutomaticPackageResolution \
    test

  echo "[run-pr] Running optimized Core Data migration/startup gate"
  FEARLESS_CORE_DATA_SOURCE_PACKAGES_DIR="$SP_DIR" \
    bash "$WORKSPACE_DIR/scripts/ci/run-coredata-release-gate.sh" \
      --stage core \
      --simulator-udid "$SIM_UDID"
else
  echo "[run-pr] Simulator build failed; falling back to device build (signing disabled)"
  xcodebuild -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
    -scheme fearless \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -clonedSourcePackagesDirPath "$SP_DIR" \
    -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    clean build
fi

echo "[run-pr] PR build completed"
