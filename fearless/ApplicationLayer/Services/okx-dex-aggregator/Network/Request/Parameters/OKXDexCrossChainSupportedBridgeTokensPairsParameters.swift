import Foundation

class OKXDexCrossChainSupportedBridgeTokensPairsParameters: NetworkRequestUrlParameters, Decodable {
    /// Chain ID (e.g., 1 for Ethereum)
    let fromChainId: String

    init(fromChainId: String) {
        self.fromChainId = fromChainId
    }
}
