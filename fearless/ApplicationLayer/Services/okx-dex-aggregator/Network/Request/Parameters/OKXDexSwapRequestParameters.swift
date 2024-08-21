import Foundation

class OKXDexSwapRequestParameters: NetworkRequestUrlParameters, Decodable {
    /// Chain ID (e.g., 1 for Ethereum)
    let chainId: String

    /// The input amount of a token to be sold (set in minimal divisible units, e.g., 1.00 USDT set as 1000000, 1.00 DAI set as 1000000000000000000), you could get the minimal divisible units from https://www.okx.com/api/v5/dex/aggregator/all-tokens
    let amount: String

    /// The contract address of a token you want to send (e.g.,0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee)
    let fromTokenAddress: String

    /// The contract address of a token you want to receive (e.g.,0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48)
    let toTokenAddress: String

    /// The slippage you are willing to accept. If you set 0.5, it means 50% slippage is acceptable. min:0 max:1
    let slippage: String

    /// User's wallet address (e.g.,0x3f6a3f57569358a512ccc0e513f171516b0fd42a)
    let userWalletAddress: String

    /// Referrer address (Supports SOL or SPL-Token commissions. SOL commissions use wallet address, and SPL-Token commissions use token account.) The fromToken address that receives the commission. When using the API, the fee rate can be adjusted by adding feePercent. Note: This doesn’t support transactions involving wrapped tokens such as those between SOL and WSOL. In a single transaction, either a fromToken commission or a toToken commission can be selected.
    let swapReceiverAddress: String?

    /// recipient address of a purchased token if not set, userWalletAddress will receive a purchased token (e.g.,0x3f6a3f57569358a512ccc0e513f171516b0fd42a)
    let referrerAddress: String?

    /// The percentage of fromTokenAmount will be sent to the referrer's address, the rest will be set as the input amount to be sold. min percentage：0 max percentage：3
    let feePercent: String?

    /// (Optional, The gas (in wei) for the swap transaction. If the value is too low to achieve the quote, an error will be returned
    let gaslimit: String?

    /// (Optional, defaults to average) The target gas price level for the swap transaction,set to average or fast or slow
    let gasLevel: String?

    /// DexId of the liquidity pool for limited quotes, multiple combinations separated by , (e.g., 1,50,180, see liquidity list for more)
    let dexIds: String?

    /// Account address for toToken in solana transactions, Get method https://www.okx.com/ru/web3/build/docs/waas/dex-use-swap-solana-quick-start
    let solTokenAccountAddress: String?

    /// (Optional. The default is 90%.) The percentage (between 0 - 1.0) of the price impact allowed. When the priceImpactProtectionPercentage is set, if the estimated price impact is above the percentage indicated, an error will be returned. For example, if PriceImpactProtectionPercentage = .25 (25%), any quote with a price impact higher than 25% will return an error. This is an optional feature, and the default value is 0.9. When it’s set to 1.0 (100%), the feature will be disabled, which means that every transaction will be allowed to pass. Note: If we’re unable to calculate the price impact, we’ll return null, and the price impact protection will be disabled.
    let priceImpactProtectionPercentage: String?

    /// You can customize the parameters to be sent on the blockchain in callData by encoding the data into a 128-character 64-bytes hexadecimal string. For example, the string “0x111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111” needs to keep the “0x” at its start.
    let callDataMemo: String?

    /// toToken referrer address (Only supports SPL-Token commissions which use token account.) The toToken address that receives the commission. When using the API, the fee rate can be adjusted by adding feePercent. Note: This doesn’t support transactions involving wrapped tokens such as those between SOL and WSOL. In a single transaction, either a fromToken commission or a toToken commission can be selected.
    let toTokenReferrerAddress: String?

    /// Used for transactions on the Solana network and similar to gasPrice on Ethereum. This price determines the priority level of the transaction. The higher the price, the more likely that the transaction can be processed faster.
    let computeUnitPrice: String?

    /// Used for transactions on the Solana network and analogous to gasLimit on Ethereum, which ensures that the transaction won’t take too much computing resource.
    let computeUnitLimit: String?

    init(
        chainId: String,
        amount: String,
        fromTokenAddress: String,
        toTokenAddress: String,
        slippage: String,
        userWalletAddress: String,
        swapReceiverAddress: String? = nil,
        referrerAddress: String? = nil,
        feePercent: String? = nil,
        gaslimit: String? = nil,
        gasLevel: String? = nil,
        dexIds: String? = nil,
        solTokenAccountAddress: String? = nil,
        priceImpactProtectionPercentage: String? = nil,
        callDataMemo: String? = nil,
        toTokenReferrerAddress: String? = nil,
        computeUnitPrice: String? = nil,
        computeUnitLimit: String? = nil
    ) {
        self.chainId = chainId
        self.amount = amount
        self.fromTokenAddress = fromTokenAddress
        self.toTokenAddress = toTokenAddress
        self.slippage = slippage
        self.userWalletAddress = userWalletAddress
        self.swapReceiverAddress = swapReceiverAddress
        self.referrerAddress = referrerAddress
        self.feePercent = feePercent
        self.gaslimit = gaslimit
        self.gasLevel = gasLevel
        self.dexIds = dexIds
        self.solTokenAccountAddress = solTokenAccountAddress
        self.priceImpactProtectionPercentage = priceImpactProtectionPercentage
        self.callDataMemo = callDataMemo
        self.toTokenReferrerAddress = toTokenReferrerAddress
        self.computeUnitPrice = computeUnitPrice
        self.computeUnitLimit = computeUnitLimit
    }
}
