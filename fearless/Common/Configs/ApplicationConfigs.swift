import Foundation
import os

protocol ApplicationConfigProtocol {
    var termsURL: URL { get }
    var privacyPolicyURL: URL { get }
    var nodes: [URL] { get }
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
}
