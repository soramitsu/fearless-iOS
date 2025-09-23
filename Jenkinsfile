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
    // Pre-resolve SPM packages and repair IrohaCrypto module map path + stub header
    sh '''
set -euxo pipefail

# Reset SPM caches for a clean resolve (avoid stale builds)
rm -rf "$WORKSPACE/DerivedData/fearless/SourcePackages" || true
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/*; do
  rm -rf "$dd/SourcePackages" || true
done

# Resolve Swift Package dependencies up-front to materialize the checkout
xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless || true

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

    appPipeline.runPipeline('fearless')
  }
}
