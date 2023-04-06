
Pod::Spec.new do |spec|

  spec.name         = "SoraSwiftUI"
  spec.version      = "0.0.1"
  spec.summary      = "A short description of SoraSwiftUI."
  spec.description  = "Soramitsu Swift UI framework"
  spec.homepage     = "http://EXAMPLE/SoraSwiftUI"

  spec.license      = "MIT"
  spec.author    = "Ivan Shlyapkin"
  spec.platform     = :ios, "13.0"
  spec.ios.deployment_target  = '13.0'
  spec.swift_version = '5.0'
  spec.source       = { :git => "https://github.com/soramitsu/ios-ui.git", :tag => "0.0.2" }

  spec.source_files  = "SoraSwiftUI", "SoraSwiftUI/**/*.{h,m,swift}"
  spec.exclude_files = "Classes/Exclude"
end
