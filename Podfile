platform :ios, '11.0'

target 'fearless' do
  use_frameworks!

  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'SoraKeystore'
  pod 'SoraUI'
  pod 'RobinHood'
  pod 'IrohaCrypto/sr25519', '~> 0.4.0'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '7cd987b2c03cdfc83ed6605049e6529c6a59b732'
  pod 'SoraFoundation', '~> 0.8.0'
  pod 'SwiftyBeaver'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'FireMock'
  end

end
