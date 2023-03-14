platform :ios, '13.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :tag => '0.14.1'
  pod 'SwiftLint'
  pod 'R.swift', '6.1.0', :inhibit_warnings => true
  pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :tag => '1.0.1'
  pod 'SoraUI', '~> 1.10.3'
  pod 'IrohaCrypto'
  pod 'RobinHood', '~> 2.6.2'
  pod 'CommonWallet/Core'
  pod 'SoraFoundation', '~> 1.0.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', :git => 'https://github.com/soramitsu/fearless-starscream.git' , :tag => '4.0.8'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'SVGKit'
  pod 'keccak.c'
  pod 'Charts', '~> 4.1.0'
  pod 'XNetworking', :podspec => 'https://raw.githubusercontent.com/soramitsu/x-networking/0.0.37/AppCommonNetworking/XNetworking/XNetworking.podspec'
  pod 'PayWingsOAuthSDK', :http => 'https://github.com/PayWings/PayWingsOAuthSDK-iOS/archive/v1.2.1.tar.gz'
  pod 'PayWingsOnboardingKYC', :http => 'https://github.com/PayWings/PayWingsOnboardingKycSDK-iOS/archive/v5.1.2.tar.gz'
  pod 'IdensicMobileSDK', :http => 'https://github.com/paywings/PayWingsOnboardingKycSDK-iOS-IdensicMobile/archive/v2.0.0.tar.gz'
  pod 'SoraSwiftUI', :path => './SoraSwiftUI'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'FearlessUtils', :git => 'https://github.com/soramitsu/fearless-utils-iOS.git', :tag => '0.14.1'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', '6.1.0', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :tag => '1.0.1'
    pod 'IrohaCrypto'
    pod 'RobinHood', '~> 2.6.2'
    pod 'CommonWallet/Core'
    pod 'Sourcery', '~> 1.4'
    pod 'keccak.c'

  end

  target 'fearlessIntegrationTests'

  target 'fearless'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
    end
  end
end
