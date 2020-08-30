plugin 'cocoapods-binary'

platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', '~> 0.6.0'
  pod 'SwiftLint', :binary => true
  pod 'R.swift', :inhibit_warnings => true, :binary => true
  pod 'FireMock', :inhibit_warnings => true, :binary => true
  pod 'SoraKeystore'
  pod 'SoraUI', '~> 1.8.11'
  pod 'RobinHood', :binary => true
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '272969f1311f7c9d23621c1e9fa1a05545ad21f9'
  pod 'SoraFoundation', '~> 0.8.0'
  pod 'SwiftyBeaver', :binary => true
  pod 'Starscream', '~> 4.0.0', :binary => true

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
