import Foundation

final class OKXDexCrossChainStatusParameters: NetworkRequestUrlParameters, Decodable {
    /// Chain ID (e.g., 1 for Ethereum)
    let hash: String

    init(hash: String) {
        self.hash = hash
    }
}
