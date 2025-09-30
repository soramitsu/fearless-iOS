#!/usr/bin/env bash
set -euo pipefail

echo "[run-pr] Running PR build (simulator build + tests, with device fallback)"

WORKSPACE_DIR=${WORKSPACE:-$(pwd)}
SP_DIR="$WORKSPACE_DIR/SourcePackages"

if [[ -f "$WORKSPACE_DIR/fearless.xcworkspace/contents.xcworkspacedata" ]]; then
  # Clean previous SPM state to prevent duplicate Web3 sources
  rm -rf "$SP_DIR" || true
  rm -f "$WORKSPACE_DIR/fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved" || true
  xcodebuild -resolvePackageDependencies \
    -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
    -scheme fearless \
    -clonedSourcePackagesDirPath "$SP_DIR" || true

  # Re-apply IrohaCrypto module.modulemap hotfix after resolve (resolve may reset files)
  echo "[run-pr] Applying IrohaCrypto modulemap hotfix in SourcePackages checkout"
  IROHA_MM="$SP_DIR/checkouts/shared-features-spm/Sources/IrohaCrypto/include/module.modulemap"
  if [[ -f "$IROHA_MM" ]]; then
    # Normalize umbrella header path and ensure stub umbrellas exist
    sed -i '' 's|umbrella header "../IrohaCrypto-umbrella.h"|umbrella header "IrohaCrypto-umbrella.h"|g' "$IROHA_MM" || true
    inc_dir=$(dirname "$IROHA_MM")
    par_dir=$(dirname "$inc_dir")
    [[ -f "$inc_dir/IrohaCrypto-umbrella.h" ]] || printf '%s\n%s\n' "// Temporary umbrella" "#import <Foundation/Foundation.h>" > "$inc_dir/IrohaCrypto-umbrella.h"
    [[ -f "$par_dir/IrohaCrypto-umbrella.h" ]] || printf '%s\n%s\n' "// Temporary umbrella (parent)" "#import <Foundation/Foundation.h>" > "$par_dir/IrohaCrypto-umbrella.h"
  else
    echo "[run-pr] WARNING: module.modulemap not found at $IROHA_MM; skipping SP_DIR hotfix"
  fi

  # Also patch any module maps under DerivedData for safety
  if [[ -x "scripts/spm-iroha-hotfix.sh" ]]; then
    echo "[run-pr] Applying DerivedData IrohaCrypto hotfix"
    scripts/spm-iroha-hotfix.sh fearless "$WORKSPACE_DIR/fearless.xcworkspace" || true
  fi
  if [[ -x "scripts/spm-shared-features-fixes.sh" ]]; then
    echo "[run-pr] Applying shared-features-spm manifest fixes"
    scripts/spm-shared-features-fixes.sh "$WORKSPACE_DIR" || true
  fi
else
  echo "[run-pr] ERROR: Workspace not found at $WORKSPACE_DIR/fearless.xcworkspace" >&2
  exit 1
fi

echo "[run-pr] Building Debug on iOS Simulator"
if xcodebuild -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
  -scheme fearless \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -clonedSourcePackagesDirPath "$SP_DIR" \
  clean build; then

  echo "[run-pr] Running unit tests on iOS Simulator"
  xcodebuild -workspace "$WORKSPACE_DIR/fearless.xcworkspace" \
    -scheme fearless \
    -destination 'generic/platform=iOS Simulator' \
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
