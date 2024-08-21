import Foundation

class OKXDexLiquiditySourceRequestParameters: NetworkRequestUrlParameters, Decodable {
    /// Chain ID (e.g., 1 for Ethereum)
    let chainId: String

    init(chainId: String) {
        self.chainId = chainId
    }
}
