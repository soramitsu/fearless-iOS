import Foundation

/// Opens WalletConnect pairing links: `wc:` URIs (EIP-1328) and `fearless://wc?uri=<wc: URI>`, the form dApps
/// use to open a specific wallet. The pairing itself goes through `WalletConnectServiceImpl.pairFromLink(uri:)`,
/// which waits for the service to start when the app was opened from the link.
final class WalletConnectURLHandler: URLHandlingServiceProtocol {
    static let shared = WalletConnectURLHandler()

    private let pair: (String) -> Void

    init(pair: @escaping (String) -> Void = { WalletConnectServiceImpl.shared.pairFromLink(uri: $0) }) {
        self.pair = pair
    }

    func handle(url: URL) -> Bool {
        guard let link = Self.link(from: url) else {
            return false
        }

        switch link {
        case let .pairing(uri):
            DispatchQueue.main.async { [pair] in
                pair(uri)
            }
        case .openWallet:
            // A dApp that is already paired opens the wallet so the user sees its request; there is nothing to pair.
            break
        }
        return true
    }

    enum Link: Equatable {
        /// A pairing URI with its key: pairs with the dApp.
        case pairing(String)
        /// `wc:<topic>@2` without a key, which dApps send to bring the wallet forward for a request.
        case openWallet
    }

    static func link(from url: URL) -> Link? {
        guard let uri = pairingURI(from: url) else {
            return nil
        }
        return uri.contains("symKey=") ? .pairing(uri) : .openWallet
    }

    /// The `wc:` URI a link carries, if it is a WalletConnect link.
    static func pairingURI(from url: URL) -> String? {
        switch url.scheme?.lowercased() {
        case "wc":
            // The scheme is case-insensitive; the client reads the lowercase `wc:` prefix.
            return "wc:" + url.absoluteString.dropFirst("wc:".count)
        case "fearless":
            guard url.host?.lowercased() == "wc", let query = url.query else {
                return nil
            }
            // `uri=` holds the whole pairing URI. dApps percent-encode it, but some send it raw, so it is taken up to
            // the end of the query instead of being split at its own `&`.
            guard query.hasPrefix("uri="),
                  let uri = String(query.dropFirst("uri=".count)).removingPercentEncoding,
                  uri.lowercased().hasPrefix("wc:")
            else {
                return nil
            }
            return "wc:" + uri.dropFirst("wc:".count)
        default:
            return nil
        }
    }
}
