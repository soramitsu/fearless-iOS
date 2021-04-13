platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => '2c14fbf0415f405ee6654ff5de1b82cb0f55762f'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI', '1.10.0'
  pod 'RobinHood', :git => 'https://github.com/soramitsu/robinhood-ios.git', :commit => 'fdeb35605aff21eea17acaa7623c5b84e84e8870'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '5f085c9ba9fc4ae5ce3acfa7a526257a99731d3b'
  pod 'SoraFoundation', '~> 0.9.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'
  pod 'ReachabilitySwift'
  pod 'SwiftGifOrigin', '~> 1.7.0'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => '2c14fbf0415f405ee6654ff5de1b82cb0f55762f'
    pod 'SoraFoundation', '~> 0.9.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore'
    pod 'RobinHood', :git => 'https://github.com/soramitsu/robinhood-ios.git', :commit => 'fdeb35605aff21eea17acaa7623c5b84e84e8870'
    pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '5f085c9ba9fc4ae5ce3acfa7a526257a99731d3b'

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
