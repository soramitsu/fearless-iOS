#!/usr/bin/env bash
set -euo pipefail

# Local developer setup script to get a clean build running on simulator.
# - Resolves SPM packages with a stable checkout location
# - Prepares the native crypto checkout against the repo-owned contract
# - Prints next-step build/test commands

SCHEME="${1:-fearless}"
DEST="${2:-platform=iOS Simulator,name=Any iOS Simulator Device}"
WORKSPACE="fearless.xcworkspace"

echo "==> Using scheme: ${SCHEME}"
echo "==> Destination: ${DEST}"

SINGLE_VALUE_CACHE_MANUAL_CLASS=0
if [[ "$DEST" == *"Simulator"* ]]; then
  SINGLE_VALUE_CACHE_MANUAL_CLASS=1
fi

# Apply mirrors (if configured), enforce SSF pin, and resolve SPM to workspace-local SourcePackages (for deterministic paths)
if [ -f scripts/deps/apply-mirrors.sh ]; then
  echo "==> Applying mirrors configuration (if any)"
  bash scripts/deps/apply-mirrors.sh || true
fi
SP_DIR="${SP_DIR:-$(pwd)/SourcePackages}"
mkdir -p "$SP_DIR"
echo "==> Resolving SwiftPM packages to $SP_DIR"
if [ -x scripts/deps/restore-swiftpm-contract-files.sh ]; then
  echo "==> Restoring committed SwiftPM contract files (if needed)"
  scripts/deps/restore-swiftpm-contract-files.sh "$(pwd)" "[dev-setup]"
fi
if [ -f scripts/deps/enforce-ssf-pin.sh ]; then
  echo "==> Enforcing shared-features-spm pinned revision"
  bash scripts/deps/enforce-ssf-pin.sh || true
fi
if [ -x scripts/deps/check-dependency-contracts.sh ]; then
  echo "==> Validating dependency contracts"
  scripts/deps/check-dependency-contracts.sh
fi
if ! xcodebuild -resolvePackageDependencies -workspace "$WORKSPACE" -scheme "$SCHEME" -clonedSourcePackagesDirPath "$SP_DIR"; then
  echo "ERROR: Swift Package resolution failed during local setup" >&2
  exit 1
fi

# 3) Ensure Git LFS assets for shared-features-spm (MPQRCoreSDK, etc.) are present
if ! command -v git-lfs >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "==> Installing git-lfs via Homebrew"
    brew install git-lfs || true
  else
    echo "WARNING: git-lfs not found and Homebrew unavailable; binary SPM targets may be missing"
  fi
fi
if command -v git-lfs >/dev/null 2>&1; then
  # Prefer workspace-local checkout; otherwise, search DerivedData locations
  CANDIDATES=(
    "${SP_DIR}/checkouts/shared-features-spm"
    "$(pwd)/DerivedData"/*/SourcePackages/checkouts/shared-features-spm
    "$HOME/Library/Developer/Xcode/DerivedData"/*/SourcePackages/checkouts/shared-features-spm
  )
  FOUND=""
  for d in "${CANDIDATES[@]}"; do
    [ -d "$d" ] || continue
    FOUND="$d"
    break
  done
  if [ -n "$FOUND" ]; then
    echo "==> Pulling Git LFS assets in $FOUND"
    (cd "$FOUND" && git lfs install --local && git lfs fetch --all && git lfs checkout) || true
    if [ ! -d "$FOUND/Binaries/MPQRCoreSDK.xcframework" ]; then
      echo "WARNING: MPQRCoreSDK.xcframework not present after git lfs in $FOUND/Binaries" >&2
    fi
  else
    echo "WARNING: shared-features-spm checkout not found yet. Did resolve succeed?"
  fi
fi

# 4) Apply native crypto contracts to the resolved SourcePackages checkout
if [ -x scripts/deps/prepare-native-crypto-checkout.sh ]; then
  echo "==> Preparing native crypto checkout"
  if ! SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages" STRICT_REQUIRED_PATCHES=1 scripts/deps/prepare-native-crypto-checkout.sh "$(pwd)" "$WORKSPACE" "$SCHEME"; then
    echo "ERROR: Native crypto checkout preparation failed during local setup" >&2
    exit 1
  fi
fi

# 5) Apply required shared-features-spm compatibility fixes
if [ -f scripts/spm-shared-features-fixes.sh ]; then
  echo "==> Applying required shared-features-spm compatibility fixes"
  if ! SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 SSF_SINGLE_VALUE_CACHE_MANUAL_CLASS="$SINGLE_VALUE_CACHE_MANUAL_CLASS" bash scripts/spm-shared-features-fixes.sh "$(pwd)"; then
    echo "ERROR: shared-features-spm compatibility fixes failed during local setup" >&2
    exit 1
  fi
fi

# 6) Apply third-party source compatibility patches
if [ -x scripts/deps/apply-charts-swift6-compat.sh ]; then
  echo "==> Applying Charts Swift compatibility fixes"
  if ! SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-charts-swift6-compat.sh "$(pwd)"; then
    echo "ERROR: Charts Swift compatibility fixes failed during local setup" >&2
    exit 1
  fi
fi

if [ -x scripts/deps/apply-svgkit-umbrella-contract.sh ]; then
  echo "==> Applying SVGKit umbrella header contract"
  if ! SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-svgkit-umbrella-contract.sh "$(pwd)"; then
    echo "ERROR: SVGKit umbrella header contract failed during local setup" >&2
    exit 1
  fi
fi

if [ -x scripts/deps/apply-tonapi-http-types-contract.sh ]; then
  echo "==> Applying TonAPI HTTPTypes dependency contract"
  if ! SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-tonapi-http-types-contract.sh "$(pwd)"; then
    echo "ERROR: TonAPI HTTPTypes dependency contract failed during local setup" >&2
    exit 1
  fi
fi

if [ -x scripts/deps/apply-reown-signer-contract.sh ]; then
  echo "==> Applying Reown signer dependency contract"
  if ! SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-reown-signer-contract.sh "$(pwd)"; then
    echo "ERROR: Reown signer dependency contract failed during local setup" >&2
    exit 1
  fi
fi

if [ -x scripts/deps/apply-web3-nio-ssl-contract.sh ]; then
  echo "==> Applying Web3 NIOSSL dependency contract"
  if ! SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 scripts/deps/apply-web3-nio-ssl-contract.sh "$(pwd)"; then
    echo "ERROR: Web3 NIOSSL dependency contract failed during local setup" >&2
    exit 1
  fi
fi

echo "==> Refreshing SwiftPM resolved state after package patches"
if ! xcodebuild -resolvePackageDependencies -workspace "$WORKSPACE" -scheme "$SCHEME" -clonedSourcePackagesDirPath "$SP_DIR"; then
  echo "ERROR: Swift Package resolution failed after local package patches" >&2
  exit 1
fi
if [ -f scripts/deps/enforce-ssf-pin.sh ]; then
  echo "==> Normalizing SwiftPM resolved contracts after package patches"
  bash scripts/deps/enforce-ssf-pin.sh
fi
if [ -x scripts/deps/check-swiftpm-consistency.sh ]; then
  scripts/deps/check-swiftpm-consistency.sh
fi

cat <<EOF

==> Next steps
- Build (Debug):
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Debug -destination '$DEST' build
- Tests (Debug+Release):
  bash scripts/test-matrix.sh "$SCHEME" "$DEST"

Tip: If you switch Xcode versions, clear SPM caches and re-run this script:
  rm -rf DerivedData/SourcePackages && rm -rf ~/Library/Developer/Xcode/DerivedData/*/SourcePackages

If you see "Missing package product 'MPQRCoreSDK'":
- Ensure git-lfs is installed: brew install git-lfs; git lfs install
- Re-run this script to fetch LFS assets. If the checkout isn't under SourcePackages, it will search DerivedData and patch there.
EOF
