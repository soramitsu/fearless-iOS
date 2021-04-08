platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => '2c14fbf0415f405ee6654ff5de1b82cb0f55762f'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI', '1.10.0'
  pod 'RobinHood'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => 'cdf9e58d4e8e7557320cd8188fac65ef632ed105'
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
    pod 'RobinHood'
    pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => 'cdf9e58d4e8e7557320cd8188fac65ef632ed105'

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
