@Library('jenkins-library@feature/FLW-3696/automation-flow-github-jira') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
]

def appPipline = new org.ios.AppPipeline(
    steps: this, 
    appTests: false,
    appPushNoti: true,
    jobParams: jobParams,
    label: 'macos-ios-1-2',
    effectJiraTasks: true 
    )
appPipline.runPipeline('fearless')
