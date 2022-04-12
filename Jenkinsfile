@Library('jenkins-library') _

def appPipline = new org.ios.AppPipeline(steps: this, appTests: false, label: 'mac-ios-1')
appPipline.runPipeline('fearless')