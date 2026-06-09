#!/usr/bin/env bash
set -euo pipefail

# CI bootstrap for Fearless iOS: SPM, LFS, and package-contract preparation

echo "[bootstrap] Starting CI bootstrap"

# Ensure UTF-8 locale for tooling
export LANG=${LANG:-en_US.UTF-8}
export LC_ALL=${LC_ALL:-en_US.UTF-8}

WORKSPACE_DIR=${WORKSPACE:-$(pwd)}
pushd "$WORKSPACE_DIR" >/dev/null

# Restore committed SwiftPM metadata if local tooling changed it.
if [[ -x scripts/deps/restore-swiftpm-contract-files.sh ]]; then
  scripts/deps/restore-swiftpm-contract-files.sh "$WORKSPACE_DIR" "[bootstrap]"
fi

# Resolve SPM into a deterministic location (clean + mirrors + enforce SSF pin)
SP_DIR="${SP_DIR:-$WORKSPACE_DIR/SourcePackages}"
# Clean previous SPM state to avoid sticky duplicates
rm -rf "$SP_DIR" || true
rm -rf "$WORKSPACE_DIR/DerivedData"/*/SourcePackages || true
# Note: SPM mirrors not set here; project pins Web3 to a single source to avoid duplication
mkdir -p "$SP_DIR"
if [[ -f fearless.xcworkspace/contents.xcworkspacedata ]]; then
  # Enforce the known-good shared-features-spm revision before resolving
  if [[ -f scripts/deps/enforce-ssf-pin.sh ]]; then
    bash scripts/deps/enforce-ssf-pin.sh || true
  fi
  if [[ -x scripts/deps/check-dependency-contracts.sh ]]; then
    scripts/deps/check-dependency-contracts.sh
  fi
  xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless -clonedSourcePackagesDirPath "$SP_DIR"
else
  echo "[bootstrap] WARNING: Workspace not found; skipping SPM resolve"
fi

# 3) Pull Git LFS assets for shared-features-spm (for MPQRCoreSDK)
if ! command -v git-lfs >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "[bootstrap] Installing git-lfs via Homebrew"
    brew install git-lfs || true
  fi
fi
if command -v git-lfs >/dev/null 2>&1; then
  TARGET_CHECKOUT=""
  for spdir in \
    "$SP_DIR/checkouts/shared-features-spm" \
    "$WORKSPACE_DIR/DerivedData"/*/SourcePackages/checkouts/shared-features-spm \
    "$HOME/Library/Developer/Xcode/DerivedData"/*/SourcePackages/checkouts/shared-features-spm; do
    [[ -d "$spdir" ]] || continue
    TARGET_CHECKOUT="$spdir"
    (cd "$spdir" && git lfs install --local && git lfs fetch --all && git lfs checkout) || true
  done
  if [[ -n "$TARGET_CHECKOUT" ]]; then
    if [[ ! -d "$TARGET_CHECKOUT/Binaries/MPQRCoreSDK.xcframework" ]]; then
      echo "[bootstrap] ERROR: MPQRCoreSDK.xcframework not present after git lfs. Checked: $TARGET_CHECKOUT/Binaries/MPQRCoreSDK.xcframework" >&2
      echo "[bootstrap] Ensure git-lfs is installed on the agent and repo bandwidth allows LFS pulls." >&2
      exit 1
    fi
  else
    echo "[bootstrap] WARNING: shared-features-spm checkout not found under $SP_DIR or DerivedData; SPM may resolve elsewhere"
  fi
else
  echo "[bootstrap] WARNING: git-lfs not available; MPQRCoreSDK may be missing"
fi

# 4) Apply repo-owned native crypto contracts
if [[ -f "scripts/deps/prepare-native-crypto-checkout.sh" ]]; then
  echo "[bootstrap] Preparing native crypto checkout"
  SOURCE_PACKAGES_DIR="$SP_DIR" STRICT_REQUIRED_PATCHES=1 bash scripts/deps/prepare-native-crypto-checkout.sh "$WORKSPACE_DIR" fearless.xcworkspace fearless
fi

# Apply required shared-features-spm compatibility fixes (manifest + Web3 API drift)
if [[ -f "scripts/spm-shared-features-fixes.sh" ]]; then
  echo "[bootstrap] Applying required shared-features-spm compatibility fixes"
  SOURCE_PACKAGES_DIR="$SP_DIR" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 SSF_SINGLE_VALUE_CACHE_MANUAL_CLASS=1 bash scripts/spm-shared-features-fixes.sh "$WORKSPACE_DIR"
fi

if [[ -x "scripts/deps/apply-tonapi-http-types-contract.sh" ]]; then
  echo "[bootstrap] Applying TonAPI HTTPTypes dependency contract"
  SOURCE_PACKAGES_DIR="$SP_DIR" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-tonapi-http-types-contract.sh "$WORKSPACE_DIR"
fi

if [[ -x "scripts/deps/apply-reown-signer-contract.sh" ]]; then
  echo "[bootstrap] Applying Reown signer dependency contract"
  SOURCE_PACKAGES_DIR="$SP_DIR" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-reown-signer-contract.sh "$WORKSPACE_DIR"
fi

if [[ -x "scripts/deps/apply-web3-nio-ssl-contract.sh" ]]; then
  echo "[bootstrap] Applying Web3 NIOSSL dependency contract"
  SOURCE_PACKAGES_DIR="$SP_DIR" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-web3-nio-ssl-contract.sh "$WORKSPACE_DIR"
fi

if [[ -x "scripts/deps/apply-charts-swift6-compat.sh" ]]; then
  echo "[bootstrap] Applying Charts Swift compatibility fixes"
  SOURCE_PACKAGES_DIR="$SP_DIR" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-charts-swift6-compat.sh "$WORKSPACE_DIR"
fi

if [[ -x "scripts/deps/apply-svgkit-umbrella-contract.sh" ]]; then
  echo "[bootstrap] Applying SVGKit umbrella header contract"
  SOURCE_PACKAGES_DIR="$SP_DIR" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-svgkit-umbrella-contract.sh "$WORKSPACE_DIR"
fi

if [[ -f fearless.xcworkspace/contents.xcworkspacedata ]]; then
  echo "[bootstrap] Refreshing SwiftPM resolved state after package patches"
  xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless -clonedSourcePackagesDirPath "$SP_DIR"
  if [[ -f scripts/deps/enforce-ssf-pin.sh ]]; then
    echo "[bootstrap] Normalizing SwiftPM resolved contracts after package patches"
    bash scripts/deps/enforce-ssf-pin.sh
  fi
  if [[ -x scripts/deps/check-swiftpm-consistency.sh ]]; then
    scripts/deps/check-swiftpm-consistency.sh
  fi
fi

popd >/dev/null
echo "[bootstrap] Completed CI bootstrap"
