@Library('jenkins-library') _

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
try {
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
      ghStatusFallback('jenkins/ios-tests', 'success', 'All tests passed')
    } catch (e) {
      ghNotifySafe context: 'jenkins/ios-tests', status: 'FAILURE', description: 'Unit tests failed'
      ghStatusFallback('jenkins/ios-tests', 'failure', 'Unit tests failed')
      throw e
    }
  }

  ghNotifySafe context: 'jenkins/ios-release-safety', status: 'PENDING', description: 'Running release safety gates'
  ghStatusFallback('jenkins/ios-release-safety', 'pending', 'Running release safety gates')
  stage('iOS Release Safety Contracts') {
    sh label: 'Run fail-closed release gate contract tests', script: '''
      set -euo pipefail
      bash scripts/test-ios-release-identity-audit.sh
      bash scripts/test-ios-signed-release-artifact-audit.sh
      bash scripts/test-coredata-release-gate.sh
      bash scripts/test-coredata-simulator-rehearsal.sh
      bash scripts/storage/test-user-storage-compatibility-model-audit.sh
      bash scripts/storage/test-substrate-storage-compatibility-model-audit.sh
    '''
  }

  // Jenkins multibranch PR jobs expose BRANCH_NAME as PR-<number>. Bind the
  // gate to both direct release branches and the repository's allowed hotfix /
  // release promotion paths so a PR cannot bypass the exact Release evidence.
  def directReleaseBranch = (
    env.BRANCH_NAME == 'master' ||
    env.BRANCH_NAME?.startsWith('release/') ||
    env.BRANCH_NAME?.startsWith('hotfix/')
  )
  def releasePullRequest = (
    env.CHANGE_ID &&
    (
      (
        env.CHANGE_TARGET == 'develop' &&
        env.CHANGE_BRANCH?.startsWith('hotfix/')
      ) ||
      (
        env.CHANGE_TARGET == 'master' &&
        (
          env.CHANGE_BRANCH == 'develop' ||
          env.CHANGE_BRANCH?.startsWith('release/') ||
          env.CHANGE_BRANCH?.startsWith('hotfix/')
        )
      )
    )
  )
  def releaseBranch = directReleaseBranch || releasePullRequest
  if (releaseBranch) {
    stage('Exact Core Data Release Gate') {
      sh label: 'Require arm64 and exact 424-test Release inventory', script: '''
        set -euo pipefail
        [[ "$(uname -m)" == "arm64" ]] || {
          echo "Exact Release gate requires dispatch to an arm64 macOS agent." >&2
          exit 78
        }
        IOS_EXPECTED_BUILD_NUMBER=2026.8.30 \
          IOS_RELEASE_SOURCE_PACKAGES_DIR="$PWD/SourcePackages" \
          bash scripts/ci/audit-ios-release-identity.sh
        bash scripts/storage/audit-user-storage-compatibility-models.sh
        bash scripts/storage/audit-substrate-storage-compatibility-models.sh
        bash scripts/ci/run-coredata-release-gate.sh --stage core
      '''
    }
  }

  if (env.IOS_RELEASE_CANDIDATE == '1') {
    stage('Copied-phone Release Evidence') {
      sh label: 'Require immutable copied-phone fixture stage', script: '''
        set -euo pipefail
        : "${FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE:?release candidate requires the copied-phone fixture}"
        : "${FEARLESS_CORE_DATA_SIMULATOR_UDID:?release candidate requires an explicit Simulator UDID}"
        bash scripts/ci/run-coredata-release-gate.sh \
          --stage copied-phone \
          --simulator-udid "$FEARLESS_CORE_DATA_SIMULATOR_UDID" \
          --fixture "$FEARLESS_SUBSTRATE_PHONE_STORE_FIXTURE"
      '''
    }
  }
  }

  appPipeline.runPipeline('fearless')

  // A required context must not turn green until every custom gate and the
  // shared application pipeline have completed. The fallback needs a node
  // because it uses curl through the shell.
  ghNotifySafe context: 'jenkins/ios-release-safety', status: 'SUCCESS', description: 'All iOS release safety gates passed'
  ghNotifySafe context: 'continuous-integration/jenkins/pr-merge', status: 'SUCCESS', description: 'Jenkins PR merge build passed'
  node('mac-fearless') {
    stage('Finalize Required GitHub Statuses') {
      ghStatusFallback('jenkins/ios-release-safety', 'success', 'All iOS release safety gates passed')
      ghStatusFallback('continuous-integration/jenkins/pr-merge', 'success', 'Jenkins PR merge build passed')
    }
  }
} catch (e) {
  // Post plugin failures first. If a macOS executor cannot be reacquired for
  // the API fallback, the required contexts remain failed or pending, never
  // stale green.
  ghNotifySafe context: 'jenkins/ios-release-safety', status: 'FAILURE', description: 'iOS release safety or pipeline failed'
  ghNotifySafe context: 'continuous-integration/jenkins/pr-merge', status: 'FAILURE', description: 'Jenkins PR merge build failed'
  try {
    node('mac-fearless') {
      stage('Report Required GitHub Status Failure') {
        ghStatusFallback('jenkins/ios-release-safety', 'failure', 'iOS release safety or pipeline failed')
        ghStatusFallback('continuous-integration/jenkins/pr-merge', 'failure', 'Jenkins PR merge build failed')
      }
    }
  } catch (statusError) {
    echo "Could not run GitHub status API fallback: ${statusError.message}"
  }
  throw e
}
