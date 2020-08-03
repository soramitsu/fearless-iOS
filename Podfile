platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI', :git => 'https://github.com/soramitsu/UIkit-iOS.git', :commit => '273b80f5a20586c5950033bba826fcbd9f43004d'
  pod 'RobinHood'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '272969f1311f7c9d23621c1e9fa1a05545ad21f9'
  pod 'SoraFoundation', '~> 0.8.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', '~> 4.0.0'

  target 'fearlessTests' do
    pod 'Cuckoo'
    pod 'FireMock'
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
