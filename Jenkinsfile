@Library('jenkins-library@feature/DOPS-2406-limit-the-execution-time') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
]

def appPipline = new org.ios.AppPipeline(
    steps: this, 
    appTests: false,
    appPushNoti: true,
    jobParams: jobParams,
    label: 'macos-ios-1-2')
    timeoutOption: '2'
appPipline.runPipeline('fearless')
