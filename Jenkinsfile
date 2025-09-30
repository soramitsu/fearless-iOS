@Library('jenkins-library') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
  string(defaultValue: '', description: 'Additional Jira tasks (comma-separated)', name: 'additionalJiraTasks'),
  booleanParam(defaultValue: false, description: 'Get all Jira tasks specified in the PR', name: 'getAllJiraTasks'),
  booleanParam(defaultValue: false, description: 'run sonarqube scan', name: 'sonar'),
  booleanParam(defaultValue: false, description: 'Upload builds to nexus(master,develop and staging branches upload always)', name: 'upload_to_nexus'),
]

def appPipeline = new org.ios.AppPipeline(
  steps: this,
  appTests: false,
  appPushNoti: true,
  jobParams: jobParams,
  label: 'mac-fearless',
  sonar: false,
  sonarProjectName: 'fearless-ios',
  sonarProjectKey: 'fearless:fearless-ios',
  dojoProductType: 'fearless',
  effectJiraTasks: true,
  uploadToNexusFor: ['master','develop','staging']
)

def envList = []
try {
  def candidates = [
    '/Applications/Xcode_15.4.app/Contents/Developer',
    '/Applications/Xcode_15.3.app/Contents/Developer',
    '/Applications/Xcode_15.2.app/Contents/Developer',
    '/Applications/Xcode_15.1.app/Contents/Developer',
    '/Applications/Xcode_15.0.app/Contents/Developer'
  ]
  def picked = candidates.find { new File(it).exists() }
  if (picked) {
    envList << "DEVELOPER_DIR=${picked}"
    echo "Pinning DEVELOPER_DIR to ${picked} for SPM/IrohaCrypto compatibility."
  } else {
    echo 'No Xcode 15.x found under /Applications. Using default Xcode (may fail with IrohaCrypto on 18.x).'
  }
} catch (Throwable t) {
  echo "Skipping Xcode pin check due to: ${t.message}"
}
node('mac-fearless') {
  withEnv(envList) {
    // Ensure repository is checked out so workspace files exist
    checkout scm
    // Pre-resolve SPM packages, install CocoaPods, and repair IrohaCrypto module map path + stub header
    sh '''
set -euxo pipefail

# Ensure UTF-8 locale for Ruby/CocoaPods
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Determine PR vs trusted branch
IS_PR=0
if [ -n "${CHANGE_ID:-}" ]; then
  IS_PR=1
fi
echo "Build context: IS_PR=${IS_PR} BRANCH_NAME=${BRANCH_NAME:-unknown}"

# Reset SPM caches for a clean resolve (avoid stale builds)
rm -rf "$WORKSPACE/DerivedData/fearless/SourcePackages" || true
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/*; do
  rm -rf "$dd/SourcePackages" || true
done

# Resolve Swift Package dependencies only if the workspace is present (post-checkout)
  if [ -f fearless.xcworkspace/contents.xcworkspacedata ] || [ -f fearless.xcworkspace ]; then
  export SP_DIR="$WORKSPACE/SourcePackages"
  # Clean previous SPM state to avoid sticky duplicates (e.g., Web3 registry vs source)
  rm -rf "$SP_DIR" || true
  rm -f "$WORKSPACE/fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved" || true
  mkdir -p "$SP_DIR" || true
  xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless -clonedSourcePackagesDirPath "$SP_DIR" || true
  # Apply IrohaCrypto module.modulemap umbrella hotfix directly in workspace SourcePackages checkout
  IROHA_MM="$SP_DIR/checkouts/shared-features-spm/Sources/IrohaCrypto/include/module.modulemap"
  if [ -f "$IROHA_MM" ]; then
    echo "Hotfix: patching $IROHA_MM (workspace SPM checkout)"
    sed -i '' 's|umbrella header "../IrohaCrypto-umbrella.h"|umbrella header "IrohaCrypto-umbrella.h"|g' "$IROHA_MM" || true
    inc_dir=$(dirname "$IROHA_MM"); par_dir=$(dirname "$inc_dir")
    [ -f "$inc_dir/IrohaCrypto-umbrella.h" ] || printf '%s\n%s\n' "// Temporary umbrella" "#import <Foundation/Foundation.h>" > "$inc_dir/IrohaCrypto-umbrella.h"
    [ -f "$par_dir/IrohaCrypto-umbrella.h" ] || printf '%s\n%s\n' "// Temporary umbrella (parent)" "#import <Foundation/Foundation.h>" > "$par_dir/IrohaCrypto-umbrella.h"
    echo "[debug] module.modulemap contents:"; sed -n '1,120p' "$IROHA_MM" || true
    echo "[debug] include dir listing:"; ls -la "$inc_dir" || true
  fi
  # Apply manifest fixes for shared-features-spm (e.g., SSFModels -> RobinHood)
  if [ -f scripts/spm-shared-features-fixes.sh ]; then
    bash scripts/spm-shared-features-fixes.sh "$WORKSPACE" || true
  fi
  # Ensure Git LFS binaries within SPM checkouts (e.g., MPQRCoreSDK) are pulled
  if ! command -v git-lfs >/dev/null 2>&1; then
    echo "git-lfs not found; attempting install via Homebrew" || true
    if command -v brew >/dev/null 2>&1; then
      brew install git-lfs || true
    fi
  fi
  for spdir in \
    "$SP_DIR/checkouts/shared-features-spm" \
    "$WORKSPACE/DerivedData"/*/SourcePackages/checkouts/shared-features-spm \
    "$WORKSPACE/DerivedData/fearless/SourcePackages/checkouts/shared-features-spm" \
    "$HOME/Library/Developer/Xcode/DerivedData"/*/SourcePackages/checkouts/shared-features-spm; do
    if [ -d "$spdir" ]; then
      (cd "$spdir" && git lfs install --local || true && git lfs pull || true)
    fi
  done
else
  echo "Skipping SPM resolve: workspace not yet present"
fi

# If a GitHub token is present, configure it so private pods (e.g., FearlessKeys) can be fetched
if [ -n "${GH_PAT_READ:-}" ]; then
  git config --global url."https://${GH_PAT_READ}@github.com/".insteadOf "https://github.com/" || true
fi

# Install CocoaPods dependencies if CocoaPods is available and Podfile exists
  if [ -f Podfile ]; then
  # For PR builds, temporarily disable the private FearlessKeys pod to avoid cloning without secrets
  if [ "$IS_PR" = "1" ]; then
    if /usr/bin/grep -q "pod 'FearlessKeys'" Podfile; then
      cp Podfile Podfile.ci.bak
      # Comment out the FearlessKeys pod line (first match) without relying on sed backrefs
      awk 'BEGIN{done=0} { if(done==0 && $0 ~ /^[[:space:]]*pod '\''FearlessKeys'\''/){ print "# CI PR: disabled "$0; done=1 } else { print } }' Podfile > Podfile.ci.tmp && mv Podfile.ci.tmp Podfile
      echo "Disabled FearlessKeys pod for PR build"
    fi
  else
    # Trusted branches: enable keys and configure GitHub token if provided
    export INCLUDE_FEARLESS_KEYS=1
    if [ -n "${GH_PAT_READ:-}" ]; then
      git config --global url."https://${GH_PAT_READ}@github.com/".insteadOf "https://github.com/" || true
    fi
  fi

  if command -v pod >/dev/null 2>&1; then
    pod install --repo-update || true
  elif command -v bundle >/dev/null 2>&1 && [ -f Gemfile ]; then
    bundle install --path vendor/bundle || true
    bundle exec pod install --repo-update || true
  elif command -v gem >/dev/null 2>&1; then
    echo "CocoaPods not found; attempting user-local install via RubyGems"
    gem install --user-install cocoapods -N || true
    # Prepend the user gem bin dir (accurate for the current Ruby) to PATH
    export GEM_BIN_DIR="$(ruby -e 'require "rubygems"; print Gem.user_dir + "/bin"')"
    export PATH="$GEM_BIN_DIR:$PATH"
    hash -r || true
    # Try invoking pod explicitly from the user gem bin dir if PATH is not picked up
    if [ -x "$GEM_BIN_DIR/pod" ]; then
      "$GEM_BIN_DIR/pod" install --repo-update || true
    elif command -v pod >/dev/null 2>&1; then
      pod install --repo-update || true
    else
      echo "CocoaPods still unavailable after gem install; skipping pod install"
    fi
  else
    echo "Skipping pod install: CocoaPods not available on this agent"
  fi

  # Restore original Podfile if we modified it (so workspace diff stays minimal)
  if [ -f Podfile.ci.bak ]; then
    mv -f Podfile.ci.bak Podfile || true
  fi

  # Verify Pods were installed; fail fast with a clear message if not
  if [ ! -f "Pods/Target Support Files/Pods-fearlessAll-fearless/Pods-fearlessAll-fearless.debug.xcconfig" ]; then
    echo "CocoaPods installation appears incomplete: missing Target Support Files for Pods-fearlessAll-fearless" >&2
    echo "Ensure CocoaPods is available on this agent or allow the Jenkinsfile to install it via RubyGems." >&2
    exit 1
  fi
else
  echo "Skipping pod install: Podfile not found"
fi

# Function to patch module.modulemap and place umbrella header alongside it (in include/)
patch_path() {
  local base="$1"
  local mm="$base/SourcePackages/checkouts/shared-features-spm/Sources/IrohaCrypto/include/module.modulemap"
  if [ -f "$mm" ]; then
    echo "Patching module.modulemap at: $mm"
    # Rewrite umbrella path to a stable path inside include/
    # Replace relative umbrella to point inside include/
    sed -i '' 's|umbrella header "../IrohaCrypto-umbrella.h"|umbrella header "IrohaCrypto-umbrella.h"|g' "$mm" || true
    # Create umbrella header both next to module map (include/) and its parent (to satisfy ../ reference)
    local include_dir="$(dirname "$mm")"
    local parent_dir="$(dirname "$include_dir")"
    local hdr_include="$include_dir/IrohaCrypto-umbrella.h"
    local hdr_parent="$parent_dir/IrohaCrypto-umbrella.h"
    if [ ! -f "$hdr_include" ]; then
      cat > "$hdr_include" <<'EOF'
// Temporary umbrella header to satisfy IrohaCrypto module.modulemap
#import <Foundation/Foundation.h>
EOF
    fi
    if [ ! -f "$hdr_parent" ]; then
      cat > "$hdr_parent" <<'EOF'
// Temporary umbrella header to satisfy IrohaCrypto module.modulemap (parent path)
#import <Foundation/Foundation.h>
EOF
    fi
  fi
}

# Try patching in workspace DerivedData
patch_path "$WORKSPACE/DerivedData/fearless"

# Fallback: patch in default Xcode DerivedData locations (if used by the builder)
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/*; do
  patch_path "$dd" || true
done
'''
    // For PRs, run simulator build + tests only (no ad-hoc archive/signing). For trusted branches, run full pipeline.
if ("${env.CHANGE_ID}"?.trim()) {
      echo "PR detected (CHANGE_ID=${env.CHANGE_ID}). Running simulator build + tests instead of archive."
      sh '''
set -euxo pipefail

# Ensure SPM is resolved
export SP_DIR="${SP_DIR:-$WORKSPACE/SourcePackages}"
if [ -f fearless.xcworkspace/contents.xcworkspacedata ]; then
  # Clear any previous resolution and resolve afresh to pick up mirrors/pins
  rm -f "$WORKSPACE/fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved" || true
  xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless -clonedSourcePackagesDirPath "$SP_DIR" || true
  # Re-apply IrohaCrypto hotfix after resolve (resolve can reset files)
  IROHA_MM="$SP_DIR/checkouts/shared-features-spm/Sources/IrohaCrypto/include/module.modulemap"
  if [ -f "$IROHA_MM" ]; then
    echo "Hotfix (PR step): patching $IROHA_MM"
    sed -i '' 's|umbrella header "../IrohaCrypto-umbrella.h"|umbrella header "IrohaCrypto-umbrella.h"|g' "$IROHA_MM" || true
    inc_dir=$(dirname "$IROHA_MM"); par_dir=$(dirname "$inc_dir")
    [ -f "$inc_dir/IrohaCrypto-umbrella.h" ] || printf '%s\n%s\n' "// Temporary umbrella" "#import <Foundation/Foundation.h>" > "$inc_dir/IrohaCrypto-umbrella.h"
    [ -f "$par_dir/IrohaCrypto-umbrella.h" ] || printf '%s\n%s\n' "// Temporary umbrella (parent)" "#import <Foundation/Foundation.h>" > "$par_dir/IrohaCrypto-umbrella.h"
    echo "[debug] module.modulemap contents (PR step):"; sed -n '1,120p' "$IROHA_MM" || true
    echo "[debug] include dir listing (PR step):"; ls -la "$inc_dir" || true
  fi
  if [ -f scripts/spm-shared-features-fixes.sh ]; then
    bash scripts/spm-shared-features-fixes.sh "$WORKSPACE" || true
  fi
else
  echo "Workspace not found; aborting PR simulator build." >&2
  exit 1
fi

  # Simulator-only builds for PRs (no signing). On failure, surface the raw error and stop.
  mkdir -p build || true
  if ! xcodebuild \
      -workspace fearless.xcworkspace \
      -scheme fearless \
      -configuration Debug \
      -destination "generic/platform=iOS Simulator" \
      -clonedSourcePackagesDirPath "$SP_DIR" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
      clean build | tee build/pr.build.raw.log; then
    echo "\n[PR] Simulator build failed. Tail of raw log:" >&2
    tail -n 300 build/pr.build.raw.log || true
    echo "\n[PR] First matching error lines:" >&2
    (rg -n "\\berror:|Failed frontend command" build/pr.build.raw.log || true) >&2
    exit 65
  fi

  if ! xcodebuild \
      -workspace fearless.xcworkspace \
      -scheme fearless \
      -destination "generic/platform=iOS Simulator" \
      -clonedSourcePackagesDirPath "$SP_DIR" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
      test | tee build/pr.test.raw.log; then
    echo "\n[PR] Simulator tests failed. Tail of raw log:" >&2
    tail -n 300 build/pr.test.raw.log || true
    echo "\n[PR] First matching error lines:" >&2
    (rg -n "\\berror:|Failed frontend command" build/pr.test.raw.log || true) >&2
    exit 65
  fi
'''
    } else {
      appPipeline.runPipeline('fearless')
    }
  }
}
