@Library('jenkins-library@feature/DOPS-2841/sonar-apple') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
  string(defaultValue: '', description: 'Additional Jira tasks (comma-separated)', name: 'additionalJiraTasks')
  booleanParam(defaultValue: false, description: 'run sonarqube scan', name: 'sonar'),
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
  effectJiraTasks: true
)

appPipeline.runPipeline('fearless')