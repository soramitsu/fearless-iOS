platform :ios, '14.1'

source 'https://github.com/soramitsu/SSFSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'SwiftLint'
  pod 'R.swift', '6.1.0', :inhibit_warnings => true
  pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :tag => '1.0.1'
  pod 'SoraUI', '~> 1.10.3'
  pod 'SoraFoundation', '~> 1.0.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', :git => 'https://github.com/soramitsu/fearless-starscream.git' , :tag => '4.0.8'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', '7.10.2' , :inhibit_warnings => true
  pod 'SVGKit'
  pod 'Charts', '~> 4.1.0'
  pod 'XNetworking', :podspec => 'https://raw.githubusercontent.com/soramitsu/x-networking/0.0.37/AppCommonNetworking/XNetworking/XNetworking.podspec'
  pod 'MediaView', :git => 'https://github.com/bnsports/MediaView.git', :branch => 'dev'
  pod 'FearlessKeys', '0.1.3'
  pod 'MPQRCoreSDK', :configurations => ['Release']

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', '6.1.0', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :tag => '1.0.1'
    pod 'Sourcery', '~> 1.4'

  end

  target 'fearlessIntegrationTests'

  target 'fearless'

end

post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
            config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
            xcconfig_path = config.base_configuration_reference.real_path
            xcconfig = File.read(xcconfig_path)
            xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
            File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
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
