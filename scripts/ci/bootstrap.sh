#!/usr/bin/env bash
set -euo pipefail

# CI bootstrap for Fearless iOS: Pods, SPM, LFS, and package-contract preparation

echo "[bootstrap] Starting CI bootstrap"

# Ensure UTF-8 locale for Ruby/CocoaPods
export LANG=${LANG:-en_US.UTF-8}
export LC_ALL=${LC_ALL:-en_US.UTF-8}

WORKSPACE_DIR=${WORKSPACE:-$(pwd)}
pushd "$WORKSPACE_DIR" >/dev/null

# 1) CocoaPods install (with fallbacks)
if [[ -f Podfile ]]; then
  IS_JENKINS_PR=0
  if [[ -n "${CHANGE_ID:-}" ]]; then IS_JENKINS_PR=1; fi

  # Determine token availability from either Jenkins or GitHub Actions
  GH_TOKEN_SRC=""
  if [[ -n "${GH_PAT_READ:-}" ]]; then GH_TOKEN_SRC="$GH_PAT_READ"; fi
  if [[ -z "$GH_TOKEN_SRC" && -n "${GH_READ_TOKEN:-}" ]]; then GH_TOKEN_SRC="$GH_READ_TOKEN"; fi

  # Handle private pods (FearlessKeys) across CI providers
  SHOULD_DISABLE_KEYS=0
  if [[ -z "${INCLUDE_FEARLESS_KEYS:-}" ]]; then
    # Jenkins PRs without explicit opt-in
    if [[ "$IS_JENKINS_PR" == "1" && -z "$GH_TOKEN_SRC" ]]; then SHOULD_DISABLE_KEYS=1; fi
    # GitHub Actions PRs (secrets absent on forks)
    if [[ -n "${GITHUB_ACTIONS:-}" && -z "$GH_TOKEN_SRC" ]]; then SHOULD_DISABLE_KEYS=1; fi
  fi

  if [[ "$SHOULD_DISABLE_KEYS" == "1" ]]; then
    if /usr/bin/grep -q "pod 'FearlessKeys'" Podfile; then
      cp Podfile Podfile.ci.bak
      awk 'BEGIN{done=0} { if(done==0 && $0 ~ /^[[:space:]]*pod '\''FearlessKeys'\''/){ print "# CI: disabled private pod for PR build -> "$0; done=1 } else { print } }' Podfile > Podfile.ci.tmp && mv Podfile.ci.tmp Podfile
      echo "[bootstrap] Disabled FearlessKeys pod (no token available in CI)"
    fi
  else
    # Trusted branch or token provided: enable tokens for private repos
    if [[ -n "$GH_TOKEN_SRC" ]]; then
      git config --global url."https://${GH_TOKEN_SRC}@github.com/".insteadOf "https://github.com/" || true
      echo "[bootstrap] Configured GitHub token for private pods"
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

# pod install may rewrite the workspace and drop committed SwiftPM metadata.
if [[ -x scripts/deps/restore-swiftpm-contract-files.sh ]]; then
  scripts/deps/restore-swiftpm-contract-files.sh "$WORKSPACE_DIR" "[bootstrap]"
fi

# 2) Resolve SPM into a deterministic location (clean + mirrors + enforce SSF pin)
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
  SOURCE_PACKAGES_DIR="$SP_DIR" ALLOW_DERIVEDDATA_FALLBACK=0 STRICT_REQUIRED_PATCHES=1 bash scripts/spm-shared-features-fixes.sh "$WORKSPACE_DIR"
fi

popd >/dev/null
echo "[bootstrap] Completed CI bootstrap"
