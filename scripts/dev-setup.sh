#!/usr/bin/env bash
set -euo pipefail

# Local developer setup script to get a clean build running on simulator.
# - Installs CocoaPods (if needed), runs pod install
# - Resolves SPM packages with a stable checkout location
# - Prepares the native crypto checkout against the repo-owned contract
# - Prints next-step build/test commands

SCHEME="${1:-fearless}"
DEST="${2:-platform=iOS Simulator,name=Any iOS Simulator Device}"
WORKSPACE="fearless.xcworkspace"

echo "==> Using scheme: ${SCHEME}"
echo "==> Destination: ${DEST}"

# 1) CocoaPods
if [ -f Podfile ]; then
  if command -v pod >/dev/null 2>&1; then
    echo "==> Running pod install"
    pod install --repo-update
  else
    echo "==> CocoaPods not found. Installing to user gems..."
    if command -v gem >/dev/null 2>&1; then
      gem install --user-install cocoapods -N
      GEM_BIN_DIR="$(ruby -e 'require "rubygems"; print Gem.user_dir + "/bin"')"
      export PATH="$GEM_BIN_DIR:$PATH"
      hash -r || true
      if command -v pod >/dev/null 2>&1; then
        pod install --repo-update
      else
        echo "ERROR: pod still not available in PATH after install" >&2
        exit 1
      fi
    else
      echo "ERROR: RubyGems not available; install CocoaPods manually (brew install cocoapods)" >&2
      exit 1
    fi
  fi
else
  echo "==> Podfile not found; skipping CocoaPods"
fi

# 2) Apply mirrors (if configured), enforce SSF pin, and resolve SPM to workspace-local SourcePackages (for deterministic paths)
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
if [ -x scripts/deps/enforce-ssf-pin.sh ]; then
  echo "==> Enforcing shared-features-spm pinned revision"
  scripts/deps/enforce-ssf-pin.sh
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

# 4) Verify the exact resolved dependency source.
SOURCE_PACKAGES_DIR="$(pwd)/SourcePackages" python3 scripts/deps/verify-shared-features-source.py "$(pwd)"

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
