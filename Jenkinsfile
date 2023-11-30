@Library('jenkins-library@feature/DOPS-2767/change-comments-list-for-jira-tasks') _

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
    effectJiraTasks: true
    )
appPipline.runPipeline('fearless')