import Foundation

class OKXDexApproveRequestParameters: NetworkRequestUrlParameters, Decodable {
    /// Chain ID (e.g., 1 for Ethereum)
    let chainId: String

    /// Token contract address (e.g., 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48)
    let tokenContractAddress: String

    /// The amount of token that needs to be permitted (set in minimal divisible units, e.g., 1.00 USDT set as 1000000, 1.00 DAI set as 1000000000000000000)
    let approveAmount: String

    init(
        chainId: String,
        tokenContractAddress: String,
        approveAmount: String
    ) {
        self.chainId = chainId
        self.tokenContractAddress = tokenContractAddress
        self.approveAmount = approveAmount
    }
}
