platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => '1814f0c17bde805549eb1b90977ce81909730684'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI', '1.9.3'
  pod 'RobinHood'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '29518e70c1a386405c19f2f335eaeef6d500c4ad'
  pod 'SoraFoundation', '~> 0.8.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'
  pod 'ReachabilitySwift'
  pod 'SwiftGifOrigin', '~> 1.7.0'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => '1814f0c17bde805549eb1b90977ce81909730684'
    pod 'SoraFoundation', '~> 0.8.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore'
    pod 'RobinHood'
    pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '29518e70c1a386405c19f2f335eaeef6d500c4ad'

  end

  target 'fearlessIntegrationTests'

  target 'fearless'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
