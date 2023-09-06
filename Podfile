platform :ios, '13.0'

# Uncomment for CI
source 'https://github.com/soramitsu/SSFSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'SwiftLint'
  pod 'R.swift', '6.1.0', :inhibit_warnings => true
  pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :tag => '1.0.1'
  pod 'SoraUI', '~> 1.10.3'
  pod 'IrohaCrypto'
  pod 'RobinHood', '~> 2.6.7'
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
  pod 'SoraUIKit', :git => 'https://github.com/soramitsu/ios-ui.git', :tag => '1.0.2'
  pod 'IdensicMobileSDK', :http => 'https://github.com/PayWings/PayWingsOnboardingKycSDK-iOS-IdensicMobile/archive/v2.2.1.tar.gz'
  pod 'SCard', :git => 'https://github.com/sora-xor/sora-card-ios', :branch => 'release/1.1.0'

  def pods_with_configurations
      if %r{^true$}i.match ENV['F_DEV']
          pod 'SSFXCM', :configurations => ['DEBUG']
      else
          pod 'SSFXCM'
          pod 'SSFExtrinsicKit'
          pod 'SSFCrypto'
          pod 'SSFSigner'
          pod 'SSFModels', '0.1.2'
          pod 'SSFEraKit'
          pod 'SSFLogger'
          pod 'SSFRuntimeCodingService'
          pod 'SSFStorageQueryKit'
          pod 'SSFChainConnection', '0.1.4'
          pod 'SSFNetwork'
          pod 'SSFUtils'
          pod 'SSFChainRegistry', '0.1.4'
          pod 'SSFHelpers', '0.1.2'
          pod 'SSFCloudStorage'
      end
  end

  pods_with_configurations
  
  # Development pods
#  pod 'SSFXCM', :path => '../soramitsu-shared-features-ios/SSFXCM'
#  pod 'SSFExtrinsicKit', :path => '../soramitsu-shared-features-ios/SSFExtrinsicKit'
#  pod 'SSFCrypto', :path => '../soramitsu-shared-features-ios/SSFCrypto'
#  pod 'SSFSigner', :path => '../soramitsu-shared-features-ios/SSFSigner'
#  pod 'SSFModels', :path => '../soramitsu-shared-features-ios/SSFModels'
#  pod 'SSFEraKit', :path => '../soramitsu-shared-features-ios/SSFEraKit'
#  pod 'SSFLogger', :path => '../soramitsu-shared-features-ios/SSFLogger'
#  pod 'SSFRuntimeCodingService', :path => '../soramitsu-shared-features-ios/SSFRuntimeCodingService'
#  pod 'SSFStorageQueryKit', :path => '../soramitsu-shared-features-ios/SSFStorageQueryKit'
#  pod 'SSFChainConnection', :path => '../soramitsu-shared-features-ios/SSFChainConnection'
#  pod 'SSFNetwork', :path => '../soramitsu-shared-features-ios/SSFNetwork'
#  pod 'SSFUtils', :path => '../soramitsu-shared-features-ios/SSFUtils'
#  pod 'SSFChainRegistry', :path => '../soramitsu-shared-features-ios/SSFChainRegistry'
#  pod 'SSFHelpers', :path => '../soramitsu-shared-features-ios/SSFHelpers'
#  pod 'SSFCloudStorage', :path => '../soramitsu-shared-features-ios/SSFCloudStorage'
#  pod 'SSFKeyPair', :path => '../soramitsu-shared-features-ios/SSFKeyPair'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', '6.1.0', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :tag => '1.0.1'
    pod 'IrohaCrypto'
    pod 'RobinHood', '~> 2.6.7'
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
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
          end
        if target.name == 'SSFXCM'
            target.build_configurations.each do |config|
                if config.name == 'Dev'
                    config.build_settings['OTHER_SWIFT_FLAGS'] = '-DF_DEV -D COCOAPODS'
                    else
                    config.build_settings['OTHER_SWIFT_FLAGS'] = '-D COCOAPODS'
                end
            end
        end
    end
end
