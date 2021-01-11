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
    var appName: String { get }
    var logoUrl: URL { get }
    var purchaseAppName: String { get }
    var purchaseRedirect: URL { get }
}

final class ApplicationConfig {
    static let shared: ApplicationConfig! = ApplicationConfig()
}

extension ApplicationConfig: ApplicationConfigProtocol {
    var termsURL: URL {
        URL(string: "https://fearlesswallet.io/terms")!
    }

    var privacyPolicyURL: URL {
        URL(string: "https://fearlesswallet.io/privacy")!
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

    //swiftlint:disable force_cast
    var appName: String {
        let bundle = Bundle(for: ApplicationConfig.self)
        return bundle.infoDictionary?["CFBundleDisplayName"] as! String
    }
    //swiftlint:enable force_cast

    //swiftlint:disable line_length
    var logoUrl: URL {
        let logoString = "https://raw.githubusercontent.com/sora-xor/sora-branding/master/Fearless-Wallet-brand/fearless-wallet-logo-ramp.png"
        return URL(string: logoString)!
    }
    //swiftlint:enable line_length

    var purchaseAppName: String {
        return "Fearless Wallet"
    }

    var purchaseRedirect: URL {
        return URL(string: "fearless://fearless.io/redirect")!
    }
}
