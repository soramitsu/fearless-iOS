import Foundation
import os

protocol ApplicationConfigProtocol {
    var termsURL: URL { get }
    var privacyPolicyURL: URL { get }
    var nodes: [URL] { get }
    var supportEmail: String { get }
    var version: String { get }
    var opensourceURL: URL { get }
}

final class ApplicationConfig {
    static let shared: ApplicationConfig! = ApplicationConfig()
}

extension ApplicationConfig: ApplicationConfigProtocol {
    var termsURL: URL {
        // TODO: Replace terms URL
        URL(string: "https://google.com")!
    }

    var privacyPolicyURL: URL {
        // TODO: Replace privacy URL
        URL(string: "https://google.com")!
    }

    var nodes: [URL] {
        [
            URL(string: "wss://kusama-rpc.polkadot.io/")!
        ]
    }

    var supportEmail: String {
        "fearless@soramitsu.co.jp"
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
        URL(string: "https://github.com/soramitsu/fearless")!
    }
}
