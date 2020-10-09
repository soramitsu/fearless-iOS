platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', '~> 0.6.0'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI'
  pod 'RobinHood'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => 'b3b5efb1cfc455a5ece75a1b722bf1783345e764'
  pod 'SoraFoundation', '~> 0.8.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'FearlessUtils', '~> 0.6.0'
    pod 'SoraFoundation', '~> 0.8.0'
    pod 'FireMock'
    pod 'SoraKeystore'
    pod 'RobinHood'
    pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => 'b3b5efb1cfc455a5ece75a1b722bf1783345e764'

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
