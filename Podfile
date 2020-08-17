platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :commit => '0f7bdbdf8a759ea33c54d8410dbe82151ca6d963'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI', '~> 1.8.11'
  pod 'RobinHood'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '272969f1311f7c9d23621c1e9fa1a05545ad21f9'
  pod 'SoraFoundation', '~> 0.8.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', '~> 4.0.0'

  target 'fearlessTests' do
    pod 'Cuckoo'
    pod 'FireMock'
    pod 'SoraKeystore'
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
