import Foundation

class OKXDexCrossChainBuildTxParameters: NetworkRequestUrlParameters, Decodable {
    /// Source chain ID (e.g., 1 for Ethereum)
    let fromChainId: String

    /// Destination chain ID (e.g., 1 for Ethereum)
    let toChainId: String

    /// The input amount of a token to be sold (set in minimal divisible units, e.g., 1.00 USDT set as 1000000, 1.00 DAI set as 1000000000000000000), you could get the minimal divisible units from https://www.okx.com/api/v5/dex/aggregator/all-tokens
    let amount: String

    /// The contract address of a token you want to send (e.g.,0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee)
    let fromTokenAddress: String

    /// The contract address of a token you want to receive (e.g.,0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48)
    let toTokenAddress: String

    /// Cross-chain swap routes
    /// 0 is the default route that would get you the most tokens.
    /// 1 is the optimal route after calculating the received amount, network fees, slippage, and cross-chain bridge costs.
    /// 2 is the quickest route with the least swap time.
    let sort: UInt8

    /// The slippage you are willing to accept. If you set 0.5, it means 50% slippage is acceptable. min:0 max:1
    let slippage: String

    /// User's wallet address (e.g.,0x3f6a3f57569358a512ccc0e513f171516b0fd42a)
    let userWalletAddress: String

    /// Receive address of a bought token if not set, the userWalletAddress will receive a bought token. TRON, SUI and other non-EVM chains need to set a receiving address (e.g., 0x3f6a3f57569358a512ccc0e513f171516b0fd42a)
    let receiveAddress: String?

    /// recipient address of a purchased token if not set, userWalletAddress will receive a purchased token (e.g.,0x3f6a3f57569358a512ccc0e513f171516b0fd42a)
    let referrerAddress: String?

    /// The percentage of fromTokenAmount will be sent to the referrer's address, the rest will be set as the input amount to be sold. min percentage：0 max percentage：3
    let feePercent: String?

    /// (Optional. The default is 90%.) The percentage (between 0 - 1.0) of the price impact allowed. When the priceImpactProtectionPercentage is set, if the estimated price impact is above the percentage indicated, an error will be returned. For example, if PriceImpactProtectionPercentage = .25 (25%), any quote with a price impact higher than 25% will return an error. This is an optional feature, and the default value is 0.9. When it’s set to 1.0 (100%), the feature will be disabled, which means that every transaction will be allowed to pass. Note: If we’re unable to calculate the price impact, we’ll return null, and the price impact protection will be disabled.
    let priceImpactProtectionPercentage: String?

    /// You can customize the parameters to be sent on the blockchain in callData by encoding the data into a 128-character 64-bytes hexadecimal string. For example, the string “0x111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111” needs to keep the “0x” at its start.
    let memo: String?

    /// Specify bridge that should be included in routes (e.g.,[211,235])
    let allowBridge: [UInt32]?

    /// Specify bridge that should be excluded in routes (e.g.,[211,235])
    let denyBridge: [UInt32]?

    init(
        fromChainId: String,
        toChainId: String,
        amount: String,
        fromTokenAddress: String,
        toTokenAddress: String,
        sort: UInt8,
        slippage: String,
        userWalletAddress: String,
        receiveAddress: String? = nil,
        referrerAddress: String? = nil,
        feePercent: String? = nil,
        priceImpactProtectionPercentage: String? = nil,
        memo: String? = nil,
        allowBridge: [UInt32]? = nil,
        denyBridge: [UInt32]? = nil
    ) {
        self.fromChainId = fromChainId
        self.toChainId = toChainId
        self.amount = amount
        self.fromTokenAddress = fromTokenAddress
        self.toTokenAddress = toTokenAddress
        self.sort = sort
        self.slippage = slippage
        self.userWalletAddress = userWalletAddress
        self.receiveAddress = receiveAddress
        self.referrerAddress = referrerAddress
        self.feePercent = feePercent
        self.priceImpactProtectionPercentage = priceImpactProtectionPercentage
        self.memo = memo
        self.allowBridge = allowBridge
        self.denyBridge = denyBridge
    }
}
