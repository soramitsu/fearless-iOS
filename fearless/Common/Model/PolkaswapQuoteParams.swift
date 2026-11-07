import Foundation

struct PolkaswapQuoteParams: Equatable {
    let requestId: UUID
    /// Increases with every request the swap screen sends, so replies can be ordered.
    let issueOrder: UInt64
    let fromAssetId: String
    let toAssetId: String
    let amount: String
    let swapVariant: SwapVariant
    let liquiditySources: [String]
    let filterMode: PolkaswapLiquidityFilterMode

    init(
        requestId: UUID = UUID(),
        issueOrder: UInt64 = 0,
        fromAssetId: String,
        toAssetId: String,
        amount: String,
        swapVariant: SwapVariant,
        liquiditySources: [String],
        filterMode: PolkaswapLiquidityFilterMode
    ) {
        self.requestId = requestId
        self.issueOrder = issueOrder
        self.fromAssetId = fromAssetId
        self.toAssetId = toAssetId
        self.amount = amount
        self.swapVariant = swapVariant
        self.liquiditySources = liquiditySources
        self.filterMode = filterMode
    }

    /// True when both requests ask the node the same question: same pair, amount, direction and market.
    func asksSameQuote(as other: PolkaswapQuoteParams) -> Bool {
        fromAssetId == other.fromAssetId &&
            toAssetId == other.toAssetId &&
            amount == other.amount &&
            swapVariant.rawValue == other.swapVariant.rawValue &&
            liquiditySources == other.liquiditySources &&
            filterMode.rawValue == other.filterMode.rawValue
    }

    static func == (lhs: PolkaswapQuoteParams, rhs: PolkaswapQuoteParams) -> Bool {
        lhs.requestId == rhs.requestId &&
            lhs.issueOrder == rhs.issueOrder &&
            lhs.asksSameQuote(as: rhs)
    }
}
