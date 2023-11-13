@Library('jenkins-library@feature/DOPS-2841/sonar-apple') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
]

def appPipline = new org.ios.AppPipeline(
    steps: this,
    appTests: false,
    appPushNoti: true,
    jobParams: jobParams,
    label: 'mac-fearless',
    sonar: true,
    sonarProjectName: 'fearless-ios',
    sonarProjectKey: 'fearless:fearless-ios',
    dojoProductType: 'fearless',
    effectJiraTasks: true
)

appPipline.runPipeline('fearless')
