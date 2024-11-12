import Foundation

final class OKXDexCrossChainStatusParameters: NetworkRequestUrlParameters, Decodable {
    /// Chain ID (e.g., 1 for Ethereum)
    let hash: String
    let chainId: String?

    init(hash: String, chainId: String?) {
        self.hash = hash
        self.chainId = chainId
    }
}
