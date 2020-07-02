platform :ios, '11.0'

target 'fearless' do
  use_frameworks!

  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI'
  pod 'RobinHood'
  pod 'IrohaCrypto/sr25519', '= 0.4.3'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '7cd987b2c03cdfc83ed6605049e6529c6a59b732'
  pod 'SoraFoundation', '~> 0.8.0'
  pod 'SwiftyBeaver'
  pod 'BigInt', '~> 5.0'
  pod 'xxHash-Swift'
  pod 'Starscream', '~> 4.0.0'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'FireMock'
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
