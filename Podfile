platform :ios, '13.0'

# Uncomment for CI
#source 'https://github.com/soramitsu/SSFSpecs.git'
#source 'https://github.com/CocoaPods/Specs.git'

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

  pod 'SSFXCM', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFXCM/SSFXCM.podspec'
  pod 'SSFExtrinsicKit', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFExtrinsicKit/SSFExtrinsicKit.podspec'
  pod 'SSFCrypto', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFCrypto/SSFCrypto.podspec'
  pod 'SSFSigner', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFSigner/SSFSigner.podspec'
  pod 'SSFModels', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFModels/SSFModels.podspec'
  pod 'SSFEraKit', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFEraKit/SSFEraKit.podspec'
  pod 'SSFLogger', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFLogger/SSFLogger.podspec'
  pod 'SSFRuntimeCodingService', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFRuntimeCodingService/SSFRuntimeCodingService.podspec'
  pod 'SSFStorageQueryKit', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFStorageQueryKit/SSFStorageQueryKit.podspec'
  pod 'SSFChainConnection', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFChainConnection/SSFChainConnection.podspec'
  pod 'SSFNetwork', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFNetwork/SSFNetwork.podspec'
  pod 'SSFUtils', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFUtils/SSFUtils.podspec'
  pod 'SSFChainRegistry', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFChainRegistry/SSFChainRegistry.podspec'
  pod 'SSFHelpers', :podspec => 'https://raw.githubusercontent.com/soramitsu/shared-features-ios/drk/SSFHelpers/SSFHelpers.podspec'

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
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
    end
  end
end
