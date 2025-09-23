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
withEnv(envList) {
  appPipeline.runPipeline('fearless')
}
