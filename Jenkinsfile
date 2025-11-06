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

  stage('Unit Tests + Codecov Upload') {
    sh label: 'Run test matrix with coverage and upload to Codecov', script: '''
      set -eo pipefail
      COVERAGE_DIR="${RESULTS_DIR:-build/coverage}"
      # Use a generic destination hint and let scripts/test-matrix.sh auto-pick a concrete simulator
      DESTINATION="${TEST_DESTINATION:-platform=iOS Simulator,name=Any iOS Simulator Device}"
      rm -rf "$COVERAGE_DIR"
      CODECOV_EXPORT=1 RESULTS_DIR="$COVERAGE_DIR" scripts/test-matrix.sh fearless.tests "$DESTINATION"
      scripts/ci/export-codecov.sh "$COVERAGE_DIR"
      scripts/ci/upload-codecov.sh "$COVERAGE_DIR"
    '''
  }
}

appPipeline.runPipeline('fearless')
