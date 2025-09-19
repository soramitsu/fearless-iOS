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

def xcode154 = "/Applications/Xcode_15.4.app/Contents/Developer"
def envList = []
try {
  if (new File(xcode154).exists()) {
    envList << "DEVELOPER_DIR=${xcode154}"
  } else {
    echo "Xcode 15.4 not found at ${xcode154}; using default Xcode."
  }
} catch (Throwable t) {
  echo "Skipping Xcode pin check due to: ${t.message}"
}
withEnv(envList) {
  appPipeline.runPipeline('fearless')
}
