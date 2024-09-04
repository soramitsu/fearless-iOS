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
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', '7.10.2' , :inhibit_warnings => true
  pod 'SVGKit'
  pod 'Charts', '~> 4.1.0'
  pod 'MediaView', :git => 'https://github.com/bnsports/MediaView.git', :branch => 'dev'
  pod 'FearlessKeys', '0.1.4'

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
    end
end
