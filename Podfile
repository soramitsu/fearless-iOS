platform :ios, '14.1'

source 'https://github.com/soramitsu/SSFSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'SwiftLint'
  pod 'R.swift', '6.1.0', :inhibit_warnings => true
  pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :tag => '1.0.2'
  pod 'SoraUI', '~> 1.10.3', :inhibit_warnings => true
  pod 'SoraFoundation', '~> 1.0.0'
  # Migrated to SPM via Packages/FearlessDependencies
  # pod 'SwiftyBeaver'
  # pod 'ReachabilitySwift'
  # Migrated to SPM via Packages/FearlessDependencies
  # pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  # Migrated to SPM via Packages/FearlessDependencies
  # pod 'Kingfisher', '7.10.2' , :inhibit_warnings => true
  pod 'SVGKit'
  pod 'Charts', '~> 4.1.0'
  pod 'MediaView', :git => 'https://github.com/bnsports/MediaView.git', :branch => 'dev'
  # Guard private pod behind env flag so PR/local builds without credentials succeed.
  # CI/CD can opt-in by exporting INCLUDE_FEARLESS_KEYS=1 so Release builds pull keys.
  if ENV['INCLUDE_FEARLESS_KEYS'] == '1'
    pod 'FearlessKeys', '0.1.4', :configurations => ['Release']
  end

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', '6.1.0', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', :git => 'https://github.com/soramitsu/keystore-iOS.git', :tag => '1.0.2'
    pod 'Sourcery', '~> 1.4'
    # Ensure UI/framework deps are available to the tests as well
    pod 'SoraUI', '~> 1.10.3', :inhibit_warnings => true
    pod 'SVGKit'
    pod 'MediaView', :git => 'https://github.com/bnsports/MediaView.git', :branch => 'dev'

  end

  target 'fearlessIntegrationTests'

  target 'fearless'

end

post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.1'
            config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
            # Force Swift 5 mode for Pods to avoid Swift 6-only diagnostics on CI toolchains
            config.build_settings['SWIFT_VERSION'] = '5.10'
            # Keep concurrency diagnostics lenient in dependencies
            config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'minimal'
            # Do not fail builds for warnings emitted by third-party Pods
            config.build_settings['SWIFT_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
            xcconfig_path = config.base_configuration_reference.real_path
            xcconfig = File.read(xcconfig_path)
            xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
            File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
          end
        # Ensure text payloads in FearlessKeys are not in Compile Sources
        if target.name == 'FearlessKeys'
            target.build_phases.each do |phase|
                if phase.is_a?(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
                    # iterate over a dup to avoid concurrent modification issues
                    phase.files.dup.each do |build_file|
                        ref = build_file.file_ref
                        if ref && ref.path && ref.path.to_s.end_with?('google-keys.txt')
                            phase.remove_file_reference(ref)
                        end
                    end
                end
            end
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
