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

// Best-effort GitHub status helper; won't fail if plugin isn't installed
def ghNotifySafe(Map args = [:]) {
  try {
    githubNotify args
  } catch (Throwable t) {
    echo "githubNotify not available: ${t.message}"
  }
}

// Ensure SPM and shared-features patches are applied before the main pipeline.
// This resolves Web3 API drift (Data.bytes) and IrohaCrypto modulemap issues prior to archive.
node('mac-fearless') {
  stage('Bootstrap CI deps') {
    checkout scm
    sh label: 'Bootstrap Pods/SPM/LFS + apply shared-features fixes', script: 'bash scripts/ci/bootstrap.sh'
  }
  stage('Git Network Tuning') {
    sh label: 'Increase Git HTTP thresholds to avoid slow fetch termination', script: '''
      git --version
      git config --global http.lowSpeedLimit 0
      git config --global http.lowSpeedTime 999999
      git config --global http.postBuffer 524288000
      git config --global fetch.prune true || true
      git config --global gc.auto 0 || true
      echo "[jenkins] Applied global git configs to tolerate slow networks"
    '''
  }

  stage('Unit Tests') {
    ghNotifySafe context: 'jenkins/ios-tests', status: 'PENDING', description: 'Running iOS unit tests'
    try {
      sh label: 'Run test matrix on simulator', script: '''
        set -eo pipefail
        DESTINATION="${TEST_DESTINATION:-platform=iOS Simulator,name=Any iOS Simulator Device}"
        scripts/test-matrix.sh fearless.tests "$DESTINATION"
      '''
      ghNotifySafe context: 'jenkins/ios-tests', status: 'SUCCESS', description: 'All tests passed'
    } catch (e) {
      ghNotifySafe context: 'jenkins/ios-tests', status: 'FAILURE', description: 'Unit tests failed'
      throw e
    }
  }
}

appPipeline.runPipeline('fearless')
