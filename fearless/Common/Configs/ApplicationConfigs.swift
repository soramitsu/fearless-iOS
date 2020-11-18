import Foundation
import os

protocol ApplicationConfigProtocol {
    var termsURL: URL { get }
    var privacyPolicyURL: URL { get }
    var devStatusURL: URL { get }
    var roadmapURL: URL { get }
    var supportEmail: String { get }
    var websiteURL: URL { get }
    var socialURL: URL { get }
    var version: String { get }
    var opensourceURL: URL { get }
}

final class ApplicationConfig {
    static let shared: ApplicationConfig! = ApplicationConfig()
}

extension ApplicationConfig: ApplicationConfigProtocol {
    var termsURL: URL {
        // TODO: Replace terms URL
        URL(string: "https://soramitsucoltd.aha.io/shared/343e5db57d53398e3f26d0048158c4a2")!
    }

    var privacyPolicyURL: URL {
        // TODO: Replace privacy URL
        URL(string: "https://soramitsucoltd.aha.io/shared/343e5db57d53398e3f26d0048158c4a2")!
    }

    var devStatusURL: URL {
        URL(string: "https://soramitsucoltd.aha.io/shared/343e5db57d53398e3f26d0048158c4a2")!
    }

    var roadmapURL: URL {
        URL(string: "https://soramitsucoltd.aha.io/shared/97bc3006ee3c1baa0598863615cf8d14")!
    }

    var supportEmail: String {
        "fearless@soramitsu.co.jp"
    }

    var websiteURL: URL {
        URL(string: "https://fearlesswallet.io")!
    }

    var socialURL: URL {
        URL(string: "https://t.me/fearlesswallet")!
    }

    //swiftlint:disable force_cast
    var version: String {
        let bundle = Bundle(for: ApplicationConfig.self)

        let mainVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as! String
        let buildNumber = bundle.infoDictionary?["CFBundleVersion"] as! String

        return "\(mainVersion).\(buildNumber)"
    }
    //swiftlint:enable force_cast

    var opensourceURL: URL {
        URL(string: "https://github.com/soramitsu/fearless-iOS")!
    }
}
