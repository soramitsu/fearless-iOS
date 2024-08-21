import Foundation

class OKXDexQuotesRequestParameters: NetworkRequestUrlParameters, Decodable {
    /// Chain ID (e.g., 1 for Ethereum)
    let chainId: String

    /// The input amount of a token to be sold (set in minimal divisible units, e.g., 1.00 USDT set as 1000000, 1.00 DAI set as 1000000000000000000), you could get the minimal divisible units from https://www.okx.com/api/v5/dex/aggregator/all-tokens
    let amount: String

    /// The contract address of a token to be sold (e.g., 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee)
    let fromTokenAddress: String

    /// The contract address of a token to be bought (e.g., 0xa892e1fef8b31acc44ce78e7db0a2dc610f92d00)
    let toTokenAddress: String

    /// DexId of the liquidity pool for limited quotes, multiple combinations separated by , (e.g.,1,50,180, see liquidity list for more)
    let dexIds: String?

    /// (Optional. The default is 90%.) The percentage (between 0 - 1.0) of the price impact allowed.  When the priceImpactProtectionPercentage is set, if the estimated price impact is above the percentage indicated, an error will be returned. For example, if PriceImpactProtectionPercentage = .25 (25%), any quote with a price impact higher than 25% will return an error. This is an optional feature, and the default value is 0.9. When it’s set to 1.0 (100%), the feature will be disabled, which means that every transaction will be allowed to pass. Note: If we’re unable to calculate the price impact, we’ll return null, and the price impact protection will be disabled.
    let priceImpactProtectionPercentage: String?

    /// The percentage of fromTokenAmount will be sent to the referrer's address, the rest will be set as the input amount to be sold. min percentage：0 max percentage：3
    let feePercent: String?

    init(
        chainId: String,
        amount: String,
        fromTokenAddress: String,
        toTokenAddress: String,
        dexIds: String? = nil,
        priceImpactProtectionPercentage: String? = nil,
        feePercent: String? = nil
    ) {
        self.chainId = chainId
        self.amount = amount
        self.fromTokenAddress = fromTokenAddress
        self.toTokenAddress = toTokenAddress
        self.dexIds = dexIds
        self.priceImpactProtectionPercentage = priceImpactProtectionPercentage
        self.feePercent = feePercent
    }
}
