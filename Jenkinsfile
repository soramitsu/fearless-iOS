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
  appTests: true,
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

withEnv([
  "DEVELOPER_DIR=/Applications/Xcode_15.4.app/Contents/Developer",
  // Ensure native gem builds find a compiler
  "CC=xcrun clang",
  "CXX=xcrun clang++",
  // Point builds at the macOS SDK headers and libs for mkmf
  "SDKROOT=/Applications/Xcode_15.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk",
  "CPATH=/Applications/Xcode_15.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include",
  "LIBRARY_PATH=/Applications/Xcode_15.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib",
  "MACOSX_DEPLOYMENT_TARGET=13.0",
  // Help bundler compile the json gem against the SDK
  "BUNDLE_BUILD__JSON=--with-cflags='-std=c99 -isysroot $SDKROOT' --with-ldflags='-Wl,-syslibroot,$SDKROOT'",
  // Do not override PATH to avoid shell lookup issues in Jenkins
]) {
  appPipeline.runPipeline('fearless')
}
