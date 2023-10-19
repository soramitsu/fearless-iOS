@Library('jenkins-library@feature/debug') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
]

def appPipline = new org.ios.AppPipeline(
    steps: this,
    appTests: false,
    appPushNoti: false,
    jobParams: jobParams,
    label: 'mac-ios-2',
    effectJiraTasks: true
    )
appPipline.runPipeline('fearless')
