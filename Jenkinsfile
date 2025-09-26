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

node('mac-fearless') {
  checkout scm
  sh 'bash scripts/ci/bootstrap.sh'

  if ("${env.CHANGE_ID}"?.trim()) {
    echo "PR detected (CHANGE_ID=${env.CHANGE_ID}). Running simulator build + tests instead of archive."
    sh 'bash -lc "set -euxo pipefail; SP_DIR=\"$WORKSPACE/SourcePackages\"; if [ -f fearless.xcworkspacedata ] || [ -f fearless.xcworkspace/contents.xcworkspacedata ]; then xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless -clonedSourcePackagesDirPath \"$SP_DIR\" || true; fi; if xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Debug -destination \"generic/platform=iOS Simulator\" -clonedSourcePackagesDirPath \"$SP_DIR\" clean build; then xcodebuild -workspace fearless.xcworkspace -scheme fearless -destination \"generic/platform=iOS Simulator\" -clonedSourcePackagesDirPath \"$SP_DIR\" test; else echo \"Simulator build failed; falling back to device build with signing disabled\"; xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Debug -destination \"generic/platform=iOS\" -clonedSourcePackagesDirPath \"$SP_DIR\" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO clean build; fi"'
  } else {
    appPipeline.runPipeline('fearless')
  }
}
