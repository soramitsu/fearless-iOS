platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => 'd460c422a57374e595d221baf1a4b12fdba7e60e'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :commit => 'd83984c4742178fc14a009e214d025451d14d315'
  pod 'SoraUI', '~> 1.10.1'
  pod 'RobinHood', '~> 2.6.0'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => 'f0fc834e67a90b3d0186e3978794b9b4c3f58be9'
  pod 'SoraFoundation', :git => 'https://github.com/soramitsu/Foundation-iOS.git', :commit => 'c1a53147c66cebaabf5985be4b895733d0997c46'
  pod 'SwiftyBeaver'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => 'd460c422a57374e595d221baf1a4b12fdba7e60e'
    pod 'SoraFoundation', :git => 'https://github.com/soramitsu/Foundation-iOS.git', :commit => 'c1a53147c66cebaabf5985be4b895733d0997c46'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :commit => 'd83984c4742178fc14a009e214d025451d14d315'
    pod 'RobinHood', '~> 2.6.0'
    pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => 'f0fc834e67a90b3d0186e3978794b9b4c3f58be9'
    pod 'Sourcery', '~> 1.4'

  end

  target 'fearlessIntegrationTests'

  target 'fearless'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
    end
  end
end
