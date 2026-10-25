#!/usr/bin/env bash
set -euo pipefail

# CI bootstrap for Fearless iOS: Pods, SPM, LFS, and package-contract preparation

echo "[bootstrap] Starting CI bootstrap"

# Ensure UTF-8 locale for Ruby/CocoaPods
export LANG=${LANG:-en_US.UTF-8}
export LC_ALL=${LC_ALL:-en_US.UTF-8}
if [[ " ${RUBYOPT:-} " != *" -rlogger "* ]]; then
  export RUBYOPT="${RUBYOPT:+$RUBYOPT }-rlogger"
fi

WORKSPACE_DIR=${WORKSPACE:-$(pwd)}
pushd "$WORKSPACE_DIR" >/dev/null
# 1) CocoaPods install (with fallbacks)
if [[ -f Podfile ]]; then
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

# 2) Resolve SPM into a deterministic location (app-owned native source + pinned third-party dependencies)
SP_DIR="${SP_DIR:-$WORKSPACE_DIR/SourcePackages}"
# Clean previous SPM state to avoid sticky duplicates
rm -rf "$SP_DIR" || true
rm -rf "$WORKSPACE_DIR/DerivedData"/*/SourcePackages || true
# Note: SPM mirrors not set here; project pins Web3 to a single source to avoid duplication
mkdir -p "$SP_DIR"
if [[ -f fearless.xcworkspace/contents.xcworkspacedata ]]; then
  python3 scripts/deps/verify-native-source.py "$WORKSPACE_DIR"
  if [[ -x scripts/deps/check-dependency-contracts.sh ]]; then
    scripts/deps/check-dependency-contracts.sh
  fi
  # Hosted runner repository caches can contain missing/stale bare checkouts.
  # Resolve into this job's source directory without consulting that shared cache.
  xcodebuild -resolvePackageDependencies -disablePackageRepositoryCache -workspace fearless.xcworkspace -scheme fearless -clonedSourcePackagesDirPath "$SP_DIR"
else
  echo "[bootstrap] WARNING: Workspace not found; skipping SPM resolve"
fi

# Verify the exact resolved source; never repair dependency contents during a build.
SOURCE_PACKAGES_DIR="$SP_DIR" python3 scripts/deps/verify-native-source.py "$WORKSPACE_DIR"

popd >/dev/null
echo "[bootstrap] Completed CI bootstrap"
