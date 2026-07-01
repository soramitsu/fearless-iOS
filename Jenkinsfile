@Library('jenkins-library@duty-27.03.2024/update_ios_pipeline') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
  string(defaultValue: '', description: 'Additional Jira tasks (comma-separated)', name: 'additionalJiraTasks'),
  booleanParam(defaultValue: false, description: 'Get all Jira tasks specified in the PR', name: 'getAllJiraTasks'),
  booleanParam(defaultValue: false, description: 'run sonarqube scan', name: 'sonar'),
  booleanParam(defaultValue: false, description: 'Upload builds to nexus(master and develop branches upload always)', name: 'upload_to_nexus'),
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
  uploadToNexusFor: ['master','develop']
)

// Best-effort GitHub status helper; won't fail if plugin isn't installed
def ghNotifySafe(Map args = [:]) {
  try {
    githubNotify args
  } catch (Throwable t) {
    echo "githubNotify not available: ${t.message}"
  }
}

// Fallback to GitHub Statuses API when githubNotify is unavailable or not configured.
def ghStatusFallback(String context, String state, String description) {
  if (!env.GITHUB_STATUS_TOKEN) {
    return
  }
  def sha = env.GIT_COMMIT ?: sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
  sh label: "Set GitHub status via API (${context} - ${state})", script: """
    curl -sS -H 'Authorization: token ${GITHUB_STATUS_TOKEN}' \
      -H 'Accept: application/vnd.github+json' \
      -X POST https://api.github.com/repos/soramitsu/fearless-iOS/statuses/${sha} \
      -d '{"state":"${state}","context":"${context}","description":"${description}"}' || true
  """
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
    // Publish both human-readable and classic Jenkins context for branch protection
    ghNotifySafe context: 'jenkins/ios-tests', status: 'PENDING', description: 'Running iOS unit tests'
    ghNotifySafe context: 'continuous-integration/jenkins/pr-merge', status: 'PENDING', description: 'Jenkins PR merge build running'
    ghStatusFallback('jenkins/ios-tests', 'pending', 'Running iOS unit tests')
    ghStatusFallback('continuous-integration/jenkins/pr-merge', 'pending', 'Jenkins PR merge build running')
    try {
      sh label: 'Run test matrix on simulator', script: '''
        set -eo pipefail
        DESTINATION="${TEST_DESTINATION:-platform=iOS Simulator,name=Any iOS Simulator Device}"
        scripts/test-matrix.sh fearless.tests "$DESTINATION"
      '''
      ghNotifySafe context: 'jenkins/ios-tests', status: 'SUCCESS', description: 'All tests passed'
      ghNotifySafe context: 'continuous-integration/jenkins/pr-merge', status: 'SUCCESS', description: 'Jenkins PR merge build passed'
      ghStatusFallback('jenkins/ios-tests', 'success', 'All tests passed')
      ghStatusFallback('continuous-integration/jenkins/pr-merge', 'success', 'Jenkins PR merge build passed')
    } catch (e) {
      ghNotifySafe context: 'jenkins/ios-tests', status: 'FAILURE', description: 'Unit tests failed'
      ghNotifySafe context: 'continuous-integration/jenkins/pr-merge', status: 'FAILURE', description: 'Jenkins PR merge build failed'
      ghStatusFallback('jenkins/ios-tests', 'failure', 'Unit tests failed')
      ghStatusFallback('continuous-integration/jenkins/pr-merge', 'failure', 'Jenkins PR merge build failed')
      throw e
    }
  }
}

appPipeline.runPipeline('fearless')
