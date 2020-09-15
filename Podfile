platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', '~> 0.6.0'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI', '~> 1.9.0'
  pod 'RobinHood'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '412d5f6bd0b15d2fe69e53915195c945142265fd'
  pod 'SoraFoundation', '~> 0.8.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', '~> 4.0.0'

  target 'fearlessTests' do
    pod 'Cuckoo'
    pod 'FireMock'
    pod 'SoraKeystore'
    pod 'RobinHood'
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
