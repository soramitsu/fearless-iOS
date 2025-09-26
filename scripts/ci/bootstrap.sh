#!/usr/bin/env bash
set -euo pipefail

# CI bootstrap for Fearless iOS: Pods, SPM, LFS, and minor hotfixes

echo "[bootstrap] Starting CI bootstrap"

# Ensure UTF-8 locale for Ruby/CocoaPods
export LANG=${LANG:-en_US.UTF-8}
export LC_ALL=${LC_ALL:-en_US.UTF-8}

WORKSPACE_DIR=${WORKSPACE:-$(pwd)}
pushd "$WORKSPACE_DIR" >/dev/null

# 1) CocoaPods install (with fallbacks)
if [[ -f Podfile ]]; then
  IS_PR=0
  if [[ -n "${CHANGE_ID:-}" ]]; then IS_PR=1; fi

  # Handle private pods (FearlessKeys)
  if [[ "$IS_PR" == "1" && -z "${INCLUDE_FEARLESS_KEYS:-}" ]]; then
    if /usr/bin/grep -q "pod 'FearlessKeys'" Podfile; then
      cp Podfile Podfile.ci.bak
      awk 'BEGIN{done=0} { if(done==0 && $0 ~ /^[[:space:]]*pod '\''FearlessKeys'\''/){ print "# CI PR: disabled "$0; done=1 } else { print } }' Podfile > Podfile.ci.tmp && mv Podfile.ci.tmp Podfile
      echo "[bootstrap] Disabled FearlessKeys pod for PR build"
    fi
  else
    # Trusted branch: enable tokens for private repos if provided
    if [[ -n "${GH_PAT_READ:-}" ]]; then
      git config --global url."https://${GH_PAT_READ}@github.com/".insteadOf "https://github.com/" || true
    fi
    export INCLUDE_FEARLESS_KEYS=1
  fi

  if command -v pod >/dev/null 2>&1; then
    pod install --repo-update
  elif command -v bundle >/dev/null 2>&1 && [[ -f Gemfile ]]; then
    bundle install --path vendor/bundle
    bundle exec pod install --repo-update
  elif command -v gem >/dev/null 2>&1; then
    echo "[bootstrap] CocoaPods missing; installing user-local via RubyGems"
    gem install --user-install cocoapods -N
    GEM_BIN_DIR=$(ruby -e 'require "rubygems"; print Gem.user_dir + "/bin"')
    export PATH="$GEM_BIN_DIR:$PATH"
    hash -r || true
    if [[ -x "$GEM_BIN_DIR/pod" ]]; then
      "$GEM_BIN_DIR/pod" install --repo-update
    else
      echo "[bootstrap] ERROR: CocoaPods still unavailable after gem install" >&2
      exit 1
    fi
  else
    echo "[bootstrap] ERROR: CocoaPods not available on this agent" >&2
    exit 1
  fi

  # Restore original Podfile if modified
  if [[ -f Podfile.ci.bak ]]; then mv -f Podfile.ci.bak Podfile; fi

  # Verify Pods installed
  if [[ ! -f "Pods/Target Support Files/Pods-fearlessAll-fearless/Pods-fearlessAll-fearless.debug.xcconfig" ]]; then
    echo "[bootstrap] ERROR: Missing Pods Target Support Files after pod install" >&2
    exit 1
  fi
else
  echo "[bootstrap] No Podfile found; skipping pod install"
fi

# 2) Resolve SPM into a deterministic location (clean + mirrors)
SP_DIR="${SP_DIR:-$WORKSPACE_DIR/SourcePackages}"
# Clean previous SPM state to avoid sticky duplicates
rm -rf "$SP_DIR" || true
rm -rf "$WORKSPACE_DIR/DerivedData"/*/SourcePackages || true
rm -f "$WORKSPACE_DIR/fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved" || true
# Note: SPM mirrors not set here; project pins Web3 to a single source to avoid duplication
mkdir -p "$SP_DIR"
if [[ -f fearless.xcworkspace/contents.xcworkspacedata ]]; then
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

# 4) IrohaCrypto module.modulemap umbrella hotfix (stale DD cases)
IROHA_MM="$SP_DIR/checkouts/shared-features-spm/Sources/IrohaCrypto/include/module.modulemap"
if [[ -f "$IROHA_MM" ]]; then
  sed -i '' 's|umbrella header "../IrohaCrypto-umbrella.h"|umbrella header "IrohaCrypto-umbrella.h"|g' "$IROHA_MM" || true
  inc_dir=$(dirname "$IROHA_MM")
  par_dir=$(dirname "$inc_dir")
  [[ -f "$inc_dir/IrohaCrypto-umbrella.h" ]] || printf '%s\n%s\n' "// Temporary umbrella" "#import <Foundation/Foundation.h>" > "$inc_dir/IrohaCrypto-umbrella.h"
  [[ -f "$par_dir/IrohaCrypto-umbrella.h" ]] || printf '%s\n%s\n' "// Temporary umbrella (parent)" "#import <Foundation/Foundation.h>" > "$par_dir/IrohaCrypto-umbrella.h"
fi

# Also patch any module maps under DerivedData for Xcode 16+/18 stability
if [[ -x "scripts/spm-iroha-hotfix.sh" ]]; then
  echo "[bootstrap] Applying DerivedData IrohaCrypto hotfix"
  scripts/spm-iroha-hotfix.sh fearless fearless.xcworkspace || true
fi

popd >/dev/null
echo "[bootstrap] Completed CI bootstrap"
